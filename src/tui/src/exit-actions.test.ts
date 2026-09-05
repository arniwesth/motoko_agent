import { describe, it, expect, afterEach } from "@jest/globals";
import {
  EXIT_ACTION_LIMIT,
  EXIT_BUDGET_MS,
  EXIT_MANIFEST_VERSION,
  parseExitManifest,
  paneProofHolds,
  paneTokens,
  performExitActions,
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
    expect(actions.map((a) => a.pane)).toEqual(["w1:pA", "w1:pB"]);
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

  // REVIEW FINDING 1. run_argv and publish_file are gone, and a manifest asking for them gets
  // nothing — no shell, no rename, no executable named by the file at all.
  it("performs no action kind other than close_pane", () => {
    const json = manifest([
      { kind: "run_argv", bin: "/bin/sh", args: ["-c", "touch /tmp/pwned"] },
      { kind: "publish_file", tmp: "/etc/passwd", dest: "/etc/passwd.bak" },
      { kind: "close_pane", bin: "/bin/sh", pane: "w1:pA", token_key: "mot-owner", token_value: TOKEN },
    ]);
    const actions = parseExitManifest(json);
    expect(actions).toHaveLength(1);
    expect(actions[0]).toEqual({ kind: "close_pane", pane: "w1:pA", tokenKey: "mot-owner", tokenValue: TOKEN });
    // The `bin` the file tried to smuggle in is not carried anywhere.
    expect(JSON.stringify(actions)).not.toContain("/bin/sh");
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
