import { describe, it, expect, afterEach } from "@jest/globals";
import {
  ownedPaneIds,
  reapOwnedPanes,
  buildPaneCloseArgs,
  REAP_LIMIT,
  __setRunnerForTests,
} from "./herdr-reap.js";
import { __setSessionMsForTests } from "./herdr-owner-token.js";

// The exit-time reaper is the one rung of F-5 that DESTROYS work, so the tests are mostly about
// what it refuses to touch. P2-6 is the measured instance of an ownership rule going wrong — a
// pane closed because its name matched a prefix that two concurrent Motokos both use — and every
// case below is that failure written down as an assertion.

const SESSION = 1756000000000;
const MINE = `w1:p1:${SESSION}`;

function paneList(panes: Array<{ pane_id: string; tokens?: Record<string, string> }>): string {
  return JSON.stringify({ id: "cli:pane:list", result: { panes, type: "pane_list" } });
}

afterEach(() => {
  __setRunnerForTests(null);
  __setSessionMsForTests(null);
});

describe("ownedPaneIds: positive proof of ownership, nothing else", () => {
  it("claims a pane whose token equals this session's", () => {
    const json = paneList([
      { pane_id: "w1:p1" },
      { pane_id: "w1:pA", tokens: { "mot-owner": MINE } },
    ]);
    expect(ownedPaneIds(json, "w1:p1", SESSION)).toEqual(["w1:pA"]);
  });

  // The session half is the whole reason the token is not just a pane id: a Motoko restarted in
  // the same pane must not inherit the previous run's delegates.
  it("refuses a pane tagged by an earlier run in the same pane", () => {
    const json = paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": "w1:p1:1755000000000" } }]);
    expect(ownedPaneIds(json, "w1:p1", SESSION)).toEqual([]);
  });

  it("refuses another session's delegate outright", () => {
    const json = paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": `w1:p7:${SESSION}` } }]);
    expect(ownedPaneIds(json, "w1:p1", SESSION)).toEqual([]);
  });

  // herdr writes its own tokens — the sidebar pane carries herdr-sidebar-* — so "has tokens" was
  // never the test.
  it("refuses untagged panes and panes carrying only herdr's own tokens", () => {
    const json = paneList([
      { pane_id: "w1:p2", tokens: { "herdr-sidebar-git": "1788204924" } },
      { pane_id: "w1:p3" },
    ]);
    expect(ownedPaneIds(json, "w1:p1", SESSION)).toEqual([]);
  });

  it("never claims its own pane, whatever it carries", () => {
    const json = paneList([{ pane_id: "w1:p1", tokens: { "mot-owner": MINE } }]);
    expect(ownedPaneIds(json, "w1:p1", SESSION)).toEqual([]);
  });

  it("yields nothing from output it cannot parse", () => {
    expect(ownedPaneIds("not json", "w1:p1", SESSION)).toEqual([]);
    expect(ownedPaneIds("", "w1:p1", SESSION)).toEqual([]);
    expect(ownedPaneIds(JSON.stringify({ error: { code: "server_not_running" } }), "w1:p1", SESSION)).toEqual([]);
  });
});

describe("reapOwnedPanes: opt-in, by pane id, bounded", () => {
  function capture(listJson: string): string[][] {
    const calls: string[][] = [];
    __setRunnerForTests((_bin, args) => {
      calls.push(args);
      return args[1] === "list" ? listJson : "";
    });
    return calls;
  }

  // The default matters more than the feature: quitting Motoko must not destroy in-flight work
  // that the answer-file gate would otherwise have delivered to the next session.
  it("does nothing at all without HERDR_REAP_ON_EXIT=1", () => {
    const calls = capture(paneList([{ pane_id: "w1:pA", tokens: { "mot-owner": MINE } }]));
    expect(reapOwnedPanes({}, "herdr", "w1:p1")).toEqual([]);
    expect(reapOwnedPanes({ HERDR_REAP_ON_EXIT: "0" }, "herdr", "w1:p1")).toEqual([]);
    expect(calls).toEqual([]);
  });

  it("closes owned panes by explicit id when the operator opted in", () => {
    __setSessionMsForTests(SESSION);
    const calls = capture(
      paneList([
        { pane_id: "w1:pA", tokens: { "mot-owner": MINE } },
        { pane_id: "w1:pB", tokens: { "mot-owner": `w1:p7:${SESSION}` } },
      ]),
    );
    expect(reapOwnedPanes({ HERDR_REAP_ON_EXIT: "1" }, "herdr", "w1:p1")).toEqual(["w1:pA"]);
    expect(calls).toEqual([["pane", "list"], buildPaneCloseArgs("w1:pA")]);
  });

  it("caps how many panes one exit may close", () => {
    __setSessionMsForTests(SESSION);
    const many = Array.from({ length: REAP_LIMIT + 5 }, (_v, i) => ({
      pane_id: `w1:p${100 + i}`,
      tokens: { "mot-owner": MINE },
    }));
    capture(paneList(many));
    expect(reapOwnedPanes({ HERDR_REAP_ON_EXIT: "1" }, "herdr", "w1:p1")).toHaveLength(REAP_LIMIT);
  });
});
