import { describe, it, expect, afterEach, beforeEach } from "@jest/globals";
import { createHash } from "crypto";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  EXIT_ACTION_LIMIT,
  EXIT_BUDGET_MS,
  EXIT_MANIFEST_VERSION,
  EXIT_PUBLISH_ROOT_VAR,
  parseExitManifest,
  paneProofHolds,
  paneTokens,
  performExitActions,
  resolvePublishRoot,
  __setRunnerForTests,
} from "./exit-actions.js";

// The host half of ABI 7.0's ExitIntent.
//
// These are the assertions `herdr-reap.test.ts` used to make, moved to the generic dispatcher that
// replaced it, plus one case per finding from the 7.0 review. Nothing here mentions
// HERDR_REAP_ON_EXIT or a delegate: the token key and value arrive in the manifest, written by
// whichever extension claims the panes, and the EXECUTABLE never does — it is a parameter supplied
// by the caller from its own environment.

const TOKEN = "w1:p1:1756000000000";
const BIN = "/usr/local/bin/herdr";

function manifest(actions: unknown[], overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    version: EXIT_MANIFEST_VERSION,
    count: 1,
    intents: [{ ext: "herdr#0", label: "delegate-panes", enabled: true, actions }],
    ...overrides,
  });
}

function closeAction(pane: string): Record<string, unknown> {
  return { kind: "close_pane", pane, token_key: "mot-owner", token_value: TOKEN };
}

function paneList(rows: Array<{ pane_id: string; tokens?: Record<string, string> }>): string {
  return JSON.stringify({ result: { panes: rows } });
}

afterEach(() => __setRunnerForTests(null));

describe("parseExitManifest: fail closed, never guess", () => {
  it("reads the actions of an enabled intent in order", () => {
    const actions = parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB")]));
    // Narrowed rather than cast: since 7.1 `ExitAction` is a union, and a test that assumed one
    // variant would go on compiling while asserting nothing about which variant it got.
    expect(actions.map((a) => (a.kind === "close_pane" ? a.pane : a.kind))).toEqual(["w1:pA", "w1:pB"]);
  });

  it("refuses a manifest whose version it does not know", () => {
    expect(parseExitManifest(manifest([closeAction("w1:pA")], { version: "exit-actions/2" }))).toEqual([]);
  });

  // `enabled: false` is DISCLOSURE, not a suggestion. Honouring it here too means the manifest
  // cannot be made to act by hand-editing only the action list.
  it("skips a disabled intent even when it carries actions", () => {
    const json = JSON.stringify({
      version: EXIT_MANIFEST_VERSION,
      count: 1,
      intents: [{ ext: "herdr#0", label: "l", enabled: false, actions: [closeAction("w1:pA")] }],
    });
    expect(parseExitManifest(json)).toEqual([]);
  });

  // REVIEW FINDING 2. The first draft read a missing `token_key` as "" and then treated "" as
  // "close any pane that exists", so the escape hatch documented as deliberate was also what
  // malformed input decayed to. A close request that lost its proof must be REFUSED.
  it("refuses a close that is missing any part of its proof", () => {
    expect(parseExitManifest(manifest([{ kind: "close_pane", pane: "w1:pA" }]))).toEqual([]);
    expect(parseExitManifest(manifest([{ kind: "close_pane", pane: "w1:pA", token_key: "mot-owner" }]))).toEqual([]);
    expect(parseExitManifest(manifest([{ kind: "close_pane", pane: "w1:pA", token_key: "", token_value: TOKEN }]))).toEqual([]);
    expect(parseExitManifest(manifest([{ kind: "close_pane", token_key: "k", token_value: "v" }]))).toEqual([]);
  });

  it("refuses a non-string field rather than coercing it", () => {
    expect(parseExitManifest(manifest([{ kind: "close_pane", pane: 7, token_key: "k", token_value: "v" }]))).toEqual([]);
  });

  // REVIEW FINDING 1. `run_argv` is gone for good, and no action names an executable. 7.1 brought
  // `publish_file` back with a payload the 7.0 draft did not have — so the case that used to prove
  // "publish_file parses to nothing" now proves the two things that replaced it: an executable
  // still cannot be smuggled, and an INCOMPLETE publish is still nothing.
  it("names no executable, and refuses run_argv outright", () => {
    const json = manifest([
      { kind: "run_argv", bin: "/bin/sh", args: ["-c", "touch /tmp/pwned"] },
      { kind: "publish_file", tmp: "/etc/passwd", dest: "/etc/passwd.bak" },
      { kind: "close_pane", bin: "/bin/sh", pane: "w1:pA", token_key: "mot-owner", token_value: TOKEN },
    ]);
    const actions = parseExitManifest(json);
    // `run_argv` refused; the publish refused for want of `expect_bytes`; the close keeps no `bin`.
    expect(actions).toHaveLength(1);
    expect(actions[0]).toEqual({ kind: "close_pane", pane: "w1:pA", tokenKey: "mot-owner", tokenValue: TOKEN });
    expect(JSON.stringify(actions)).not.toContain("/bin/sh");
  });

  it("refuses a publish whose generation precondition is missing or nonsense", () => {
    const good = "a".repeat(64);
    const bad = [
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json" },
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: "" },
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: "any" },
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: good.slice(1) },
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: good.toUpperCase() },
      { kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: 12 },
      { kind: "publish_file", tmp: "", dest: "/r/a.json", expect_sha256: good },
    ];
    expect(parseExitManifest(manifest(bad))).toEqual([]);
    expect(
      parseExitManifest(manifest([{ kind: "publish_file", tmp: "/r/a.tmp", dest: "/r/a.json", expect_sha256: good }])),
    ).toHaveLength(1);
  });

  it("yields nothing for unparseable or empty input", () => {
    expect(parseExitManifest("not json")).toEqual([]);
    expect(parseExitManifest("")).toEqual([]);
    expect(parseExitManifest("{}")).toEqual([]);
  });
});

describe("the proof, not the pane id, is what licenses a close", () => {
  const action = { kind: "close_pane", pane: "w1:pA", tokenKey: "mot-owner", tokenValue: TOKEN } as const;

  it("accepts a pane still presenting the token the action named", () => {
    expect(paneProofHolds(paneTokens(paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": TOKEN } }])), action)).toBe(true);
  });

  // The staleness this exists for: the manifest was rendered at turn end, the close happens at
  // exit, and a pane id can be recycled in between.
  it("refuses another session's token, an untagged pane, and a pane that is gone", () => {
    expect(paneProofHolds(paneTokens(paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": "w9:p9:1" } }])), action)).toBe(false);
    expect(paneProofHolds(paneTokens(paneList([{ pane_id: "w1:pA" }])), action)).toBe(false);
    expect(paneProofHolds(paneTokens(paneList([{ pane_id: "w1:pZ", tokens: { "mot-owner": TOKEN } }])), action)).toBe(false);
  });

  it("yields no tokens at all from output it cannot read", () => {
    expect(paneTokens("not json").size).toBe(0);
    expect(paneTokens(JSON.stringify({ error: { code: "server_not_running" } })).size).toBe(0);
  });
});

describe("performExitActions: host-resolved binary, bounded, best-effort", () => {
  it("closes only the proven panes, by explicit id, with the caller's binary", () => {
    const calls: string[][] = [];
    __setRunnerForTests((bin, args) => {
      calls.push([bin, ...args]);
      return args[1] === "list"
        ? paneList([
            { pane_id: "w1:pA", tokens: { "mot-owner": TOKEN } },
            { pane_id: "w1:pB", tokens: { "mot-owner": "someone-else" } },
          ])
        : "";
    });

    const report = performExitActions(parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB")])), BIN);

    expect(report.performed).toHaveLength(1);
    expect(report.unproven).toBe(1);
    expect(calls).toContainEqual([BIN, "pane", "close", "w1:pA"]);
    expect(calls).not.toContainEqual([BIN, "pane", "close", "w1:pB"]);
    // Every call used the binary the CALLER supplied.
    expect(calls.every((c) => c[0] === BIN)).toBe(true);
  });

  it("does nothing when the caller has no binary to offer", () => {
    let called = false;
    __setRunnerForTests(() => {
      called = true;
      return "";
    });

    const report = performExitActions(parseExitManifest(manifest([closeAction("w1:pA")])), "");

    expect(called).toBe(false);
    expect(report.performed).toEqual([]);
  });

  it("enumerates panes exactly once for the whole manifest", () => {
    let lists = 0;
    __setRunnerForTests((_bin, args) => {
      if (args[1] === "list") {
        lists += 1;
        return paneList(["w1:pA", "w1:pB", "w1:pC"].map((pane_id) => ({ pane_id, tokens: { "mot-owner": TOKEN } })));
      }
      return "";
    });

    const report = performExitActions(
      parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB"), closeAction("w1:pC")])),
      BIN,
    );

    expect(lists).toBe(1);
    expect(report.performed).toHaveLength(3);
  });

  it("stops at the action cap and reports what it left undone", () => {
    __setRunnerForTests((_bin, args) =>
      args[1] === "list"
        ? paneList(
            Array.from({ length: EXIT_ACTION_LIMIT + 5 }, (_v, i) => ({
              pane_id: `w1:p${i}`,
              tokens: { "mot-owner": TOKEN },
            })),
          )
        : "",
    );
    const many = Array.from({ length: EXIT_ACTION_LIMIT + 5 }, (_v, i) => closeAction(`w1:p${i}`));

    const report = performExitActions(parseExitManifest(manifest(many)), BIN);

    expect(report.performed).toHaveLength(EXIT_ACTION_LIMIT);
    expect(report.truncated).toBe(5);
  });

  // REVIEW FINDING 6. A per-call timeout is not a deadline: the cap alone permitted an exit that
  // took the cap times the per-call bound. The budget is checked between actions, so a slow server
  // costs one in-flight call and then stops.
  it("abandons the rest of the manifest once the aggregate budget is spent", () => {
    __setRunnerForTests((_bin, args) =>
      args[1] === "list"
        ? paneList(["w1:pA", "w1:pB", "w1:pC"].map((pane_id) => ({ pane_id, tokens: { "mot-owner": TOKEN } })))
        : "",
    );
    // A clock that jumps past the budget after the first close.
    let t = 0;
    const clock = () => {
      t += EXIT_BUDGET_MS;
      return t;
    };

    const report = performExitActions(
      parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB"), closeAction("w1:pC")])),
      BIN,
      clock,
    );

    expect(report.performed.length).toBeLessThan(3);
    expect(report.overBudget).toBeGreaterThan(0);
    expect(report.performed.length + report.overBudget + report.unproven).toBe(3);
  });

  it("does nothing, and calls nothing, for an empty manifest", () => {
    let called = false;
    __setRunnerForTests(() => {
      called = true;
      return "";
    });

    const report = performExitActions(parseExitManifest(manifest([])), BIN);

    expect(report.performed).toEqual([]);
    expect(called).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// ABI 7.1's publish verb. Real files, because every property under test is a
// filesystem property: what the grant contains, what a symlink resolves to,
// what already exists, and which of two files is newer.
// ---------------------------------------------------------------------------
describe("publish_file: the operator's grant is the whole authorization", () => {
  let root: string;
  let outside: string;

  function pub(tmp: string, dest: string, expectSha256: string) {
    return { kind: "publish_file" as const, tmp, dest, expectSha256 };
  }

  /** The digest of what is at `p` right now — what an extension records when it renders. */
  function digest(p: string): string {
    return createHash("sha256").update(fs.readFileSync(p)).digest("hex");
  }

  // `realpathSync` because macOS hands out /var/... and resolves it to /private/var/..., which is
  // exactly the mismatch the containment check would otherwise trip over.
  beforeEach(() => {
    root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "motoko-grant-")));
    outside = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "motoko-outside-")));
  });
  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true });
    fs.rmSync(outside, { recursive: true, force: true });
  });

  /** A settled tmp and the dest it will replace, with the tmp deliberately the newer of the two. */
  function pair(destBody: string, tmpBody: string): { tmp: string; dest: string } {
    const dest = path.join(root, "run.json");
    const tmp = path.join(root, "run.json.tmp");
    fs.writeFileSync(dest, destBody);
    fs.writeFileSync(tmp, tmpBody);
    const old = new Date(Date.now() - 60_000);
    fs.utimesSync(dest, old, old);
    return { tmp, dest };
  }

  it("renames tmp onto dest when the grant, the digest and the freshness all hold", () => {
    const { tmp, dest } = pair("old", "settled");
    const report = performExitActions([pub(tmp, dest, digest(dest))], "", Date.now, root);
    expect(report.performed).toHaveLength(1);
    expect(report.refused).toBe(0);
    expect(fs.readFileSync(dest, "utf8")).toBe("settled");
    expect(fs.existsSync(tmp)).toBe(false);
  });

  // THE DEFAULT. Nothing published, nothing said, and the same manifest that works above.
  it("refuses every publish when the operator granted no root", () => {
    const { tmp, dest } = pair("old", "settled");
    const report = performExitActions([pub(tmp, dest, digest(dest))], "", Date.now, null);
    expect(report.performed).toHaveLength(0);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(dest, "utf8")).toBe("old");
  });

  it("refuses a destination outside the granted root", () => {
    const { tmp } = pair("old", "settled");
    const victim = path.join(outside, "victim");
    fs.writeFileSync(victim, "untouched");
    const report = performExitActions([pub(tmp, victim, digest(victim))], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(victim, "utf8")).toBe("untouched");
  });

  // The containment check resolves the PARENT, so a directory symlink cannot walk out of the grant.
  it("refuses a path that leaves the root through a symlinked directory", () => {
    const { tmp } = pair("old", "settled");
    const victim = path.join(outside, "victim");
    fs.writeFileSync(victim, "untouched");
    fs.symlinkSync(outside, path.join(root, "escape"));
    const report = performExitActions([pub(tmp, path.join(root, "escape", "victim"), digest(victim))], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(victim, "utf8")).toBe("untouched");
  });

  it("refuses a tmp that is a symlink rather than following it", () => {
    const { dest } = pair("old", "settled");
    const secret = path.join(outside, "secret");
    fs.writeFileSync(secret, "sec");
    const link = path.join(root, "link.tmp");
    fs.symlinkSync(secret, link);
    const report = performExitActions([pub(link, dest, digest(dest))], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(dest, "utf8")).toBe("old");
  });

  // No publish-if-absent mode: a manifest cannot bring a file into existence.
  it("will not create a file that is not already there", () => {
    const tmp = path.join(root, "run.json.tmp");
    fs.writeFileSync(tmp, "settled");
    const dest = path.join(root, "never-existed.json");
    const report = performExitActions([pub(tmp, dest, "b".repeat(64))], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.existsSync(dest)).toBe(false);
  });

  // The gap a byte count left open: `dest` was rewritten to something the SAME LENGTH.
  it("refuses a dest whose content is not the one the extension hashed", () => {
    const { tmp, dest } = pair("old", "settled");
    const stale = digest(dest);
    fs.writeFileSync(dest, "OLD");
    const report = performExitActions([pub(tmp, dest, stale)], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(dest, "utf8")).toBe("OLD");
  });

  // The host's own guard, which the manifest cannot influence: somebody rewrote dest AFTER the
  // extension rendered its action, and the sizes happen to agree.
  it("refuses a dest that was rewritten after the action was rendered", () => {
    const { tmp, dest } = pair("old", "new");
    const future = new Date(Date.now() + 60_000);
    fs.utimesSync(dest, future, future);
    const report = performExitActions([pub(tmp, dest, digest(dest))], "", Date.now, root);
    expect(report.refused).toBe(1);
    expect(fs.readFileSync(dest, "utf8")).toBe("old");
  });

  // A publish is a rename. Nothing to enumerate, nothing to close, nothing to spawn.
  it("needs no multiplexer: a publish-only manifest runs no subprocess", () => {
    const { tmp, dest } = pair("old", "settled");
    let calls = 0;
    __setRunnerForTests(() => {
      calls += 1;
      return "";
    });
    const report = performExitActions([pub(tmp, dest, digest(dest))], "", Date.now, root);
    expect(report.performed).toHaveLength(1);
    expect(calls).toBe(0);
  });

  describe("resolvePublishRoot", () => {
    it("accepts an absolute existing directory and resolves it", () => {
      expect(resolvePublishRoot({ [EXIT_PUBLISH_ROOT_VAR]: root })).toBe(root);
    });
    it("yields null for unset, relative, missing, and not-a-directory", () => {
      const file = path.join(root, "a-file");
      fs.writeFileSync(file, "x");
      expect(resolvePublishRoot({})).toBeNull();
      expect(resolvePublishRoot({ [EXIT_PUBLISH_ROOT_VAR]: "" })).toBeNull();
      expect(resolvePublishRoot({ [EXIT_PUBLISH_ROOT_VAR]: "relative/dir" })).toBeNull();
      expect(resolvePublishRoot({ [EXIT_PUBLISH_ROOT_VAR]: path.join(root, "nope") })).toBeNull();
      expect(resolvePublishRoot({ [EXIT_PUBLISH_ROOT_VAR]: file })).toBeNull();
    });
  });
});
