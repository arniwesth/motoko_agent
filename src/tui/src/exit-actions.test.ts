import { describe, it, expect, afterEach } from "@jest/globals";
import {
  EXIT_ACTION_LIMIT,
  EXIT_MANIFEST_VERSION,
  parseExitManifest,
  paneProofHolds,
  paneTokens,
  performExitActions,
  __setRunnerForTests,
  __setRenamerForTests,
} from "./exit-actions.js";

// The host half of ABI 7.0's ExitIntent, and the contract it has to keep.
//
// These assertions are the ones `herdr-reap.test.ts` used to make, moved to the generic
// dispatcher that replaced it — with one difference that is the whole point of the move: nothing
// here mentions `mot-owner`, `HERDR_REAP_ON_EXIT`, or a delegate. The token key and value arrive
// in the manifest, written by whichever extension claims the panes; this side verifies the proof
// it was handed and performs three kinds of action.

const TOKEN = "w1:p1:1756000000000";

function manifest(actions: unknown[], overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    version: EXIT_MANIFEST_VERSION,
    count: 1,
    intents: [{ ext: "herdr#0", label: "delegate-panes", enabled: true, actions }],
    ...overrides,
  });
}

function closeAction(pane: string): Record<string, unknown> {
  return {
    kind: "close_pane",
    bin: "herdr",
    pane,
    token_key: "mot-owner",
    token_value: TOKEN,
  };
}

function paneList(rows: Array<{ pane_id: string; tokens?: Record<string, string> }>): string {
  return JSON.stringify({ result: { panes: rows } });
}

afterEach(() => {
  __setRunnerForTests(null);
  __setRenamerForTests(null);
});

describe("parseExitManifest: fail closed, never guess", () => {
  it("reads the actions of an enabled intent in order", () => {
    const actions = parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB")]));
    expect(actions).toHaveLength(2);
    expect(actions.map((a) => (a.kind === "close_pane" ? a.pane : ""))).toEqual(["w1:pA", "w1:pB"]);
  });

  // A version this build does not know may mean fields moved. Executing the subset we recognise
  // while reporting a completed sweep is the failure worth engineering against.
  it("refuses a manifest whose version it does not know", () => {
    expect(parseExitManifest(manifest([closeAction("w1:pA")], { version: "exit-actions/2" }))).toEqual([]);
  });

  // `enabled: false` is DISCLOSURE, not a suggestion: the extension published the intent and said
  // its operator knob is off. Honouring it here too means the manifest cannot be made to act by
  // hand-editing only the action list.
  it("skips a disabled intent even when it carries actions", () => {
    const json = JSON.stringify({
      version: EXIT_MANIFEST_VERSION,
      count: 1,
      intents: [{ ext: "herdr#0", label: "delegate-panes", enabled: false, actions: [closeAction("w1:pA")] }],
    });
    expect(parseExitManifest(json)).toEqual([]);
  });

  it("drops an action of an unknown kind, and keeps the ones around it", () => {
    const actions = parseExitManifest(
      manifest([closeAction("w1:pA"), { kind: "launch_missiles", bin: "sh" }, closeAction("w1:pB")]),
    );
    expect(actions).toHaveLength(2);
  });

  it("drops an action missing a field it needs rather than filling one in", () => {
    expect(parseExitManifest(manifest([{ kind: "close_pane", bin: "herdr" }]))).toEqual([]);
    expect(parseExitManifest(manifest([{ kind: "publish_file", tmp: "/a.tmp" }]))).toEqual([]);
  });

  it("yields nothing for unparseable or empty input", () => {
    expect(parseExitManifest("not json")).toEqual([]);
    expect(parseExitManifest("")).toEqual([]);
    expect(parseExitManifest("{}")).toEqual([]);
  });
});

describe("the proof, not the pane id, is what licenses a close", () => {
  it("accepts a pane still presenting the token the action named", () => {
    const tokens = paneTokens(paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": TOKEN } }]));
    expect(paneProofHolds(tokens, parseExitManifest(manifest([closeAction("w1:pA")]))[0] as never)).toBe(true);
  });

  // The staleness this exists for: the manifest was rendered at turn end, the close happens at
  // exit, and a pane id can be recycled in between. Another session's pane presents another
  // session's token and is left alone.
  it("refuses a pane carrying a different session's token", () => {
    const tokens = paneTokens(paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": "w9:p9:1" } }]));
    expect(paneProofHolds(tokens, parseExitManifest(manifest([closeAction("w1:pA")]))[0] as never)).toBe(false);
  });

  it("refuses an untagged pane and a pane that is gone", () => {
    const untagged = paneTokens(paneList([{ pane_id: "w1:pA" }]));
    const gone = paneTokens(paneList([{ pane_id: "w1:pZ", tokens: { "mot-owner": TOKEN } }]));
    const action = parseExitManifest(manifest([closeAction("w1:pA")]))[0] as never;
    expect(paneProofHolds(untagged, action)).toBe(false);
    expect(paneProofHolds(gone, action)).toBe(false);
  });

  it("yields no tokens at all from output it cannot read", () => {
    expect(paneTokens("not json").size).toBe(0);
    expect(paneTokens(JSON.stringify({ error: { code: "server_not_running" } })).size).toBe(0);
  });
});

describe("performExitActions: bounded, best-effort, one enumeration", () => {
  it("closes only the proven panes, by explicit id", () => {
    const calls: string[][] = [];
    __setRunnerForTests((bin, args) => {
      calls.push([bin, ...args]);
      return args[0] === "pane" && args[1] === "list"
        ? paneList([
            { pane_id: "w1:pA", tokens: { "mot-owner": TOKEN } },
            { pane_id: "w1:pB", tokens: { "mot-owner": "someone-else" } },
          ])
        : "";
    });

    const report = performExitActions(parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB")])));

    expect(report.performed).toHaveLength(1);
    expect(report.unproven).toBe(1);
    expect(calls).toContainEqual(["herdr", "pane", "close", "w1:pA"]);
    expect(calls).not.toContainEqual(["herdr", "pane", "close", "w1:pB"]);
  });

  // The exit budget is the reason: twenty closes must cost one enumeration, not twenty.
  it("enumerates panes once per binary, however many closes there are", () => {
    let lists = 0;
    __setRunnerForTests((_bin, args) => {
      if (args[1] === "list") {
        lists += 1;
        return paneList([
          { pane_id: "w1:pA", tokens: { "mot-owner": TOKEN } },
          { pane_id: "w1:pB", tokens: { "mot-owner": TOKEN } },
          { pane_id: "w1:pC", tokens: { "mot-owner": TOKEN } },
        ]);
      }
      return "";
    });

    const report = performExitActions(
      parseExitManifest(manifest([closeAction("w1:pA"), closeAction("w1:pB"), closeAction("w1:pC")])),
    );

    expect(lists).toBe(1);
    expect(report.performed).toHaveLength(3);
  });

  // A wedged server must not be able to hold the process open indefinitely, and the truncation is
  // announced rather than silent.
  it("stops at the cap and reports what it left undone", () => {
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

    const report = performExitActions(parseExitManifest(manifest(many)));

    expect(report.performed).toHaveLength(EXIT_ACTION_LIMIT);
    expect(report.truncated).toBe(5);
  });

  it("publishes a file by renaming it, and survives a rename that fails", () => {
    const renames: Array<[string, string]> = [];
    __setRenamerForTests((tmp, dest) => {
      if (tmp.includes("doomed")) throw new Error("ENOENT");
      renames.push([tmp, dest]);
    });

    const report = performExitActions(
      parseExitManifest(
        manifest([
          { kind: "publish_file", tmp: "/w/.dagr/run.json.tmp", dest: "/w/.dagr/run.json" },
          { kind: "publish_file", tmp: "/w/doomed.tmp", dest: "/w/doomed.json" },
        ]),
      ),
    );

    expect(renames).toEqual([["/w/.dagr/run.json.tmp", "/w/.dagr/run.json"]]);
    expect(report.performed).toHaveLength(1);
  });

  it("runs an argv action verbatim, with no shell and no interpolation", () => {
    const calls: string[][] = [];
    __setRunnerForTests((bin, args) => {
      calls.push([bin, ...args]);
      return "";
    });

    performExitActions(parseExitManifest(manifest([{ kind: "run_argv", bin: "herdr", args: ["agent", "stop", "x"] }])));

    expect(calls).toEqual([["herdr", "agent", "stop", "x"]]);
  });

  it("does nothing, and calls nothing, for an empty manifest", () => {
    let called = false;
    __setRunnerForTests(() => {
      called = true;
      return "";
    });

    const report = performExitActions(parseExitManifest(manifest([])));

    expect(report.performed).toEqual([]);
    expect(called).toBe(false);
  });
});
