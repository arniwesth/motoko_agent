import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import {
  HERDR_AGENT_LABEL,
  HERDR_SOURCE,
  buildReleaseArgs,
  buildReportArgs,
  buildSessionArgs,
  initHerdrReporter,
  mapRunState,
  readHerdrEnvironment,
  releaseHerdrReporter,
  reportRunState,
  reportSessionPath,
  __resetForTests,
  __setSpawnHookForTests,
  type MotokoRunState,
} from "./herdr-agent-state.js";

const IN_HERDR = {
  HERDR_ENV: "1",
  HERDR_PANE_ID: "w1:p2",
  HERDR_BIN_PATH: "/usr/local/bin/herdr",
} as NodeJS.ProcessEnv;

describe("herdr environment detection", () => {
  it("recognises a herdr pane", () => {
    expect(readHerdrEnvironment(IN_HERDR)).toEqual({
      paneId: "w1:p2",
      bin: "/usr/local/bin/herdr",
    });
  });

  // Each of these is a real context Motoko runs in: a plain terminal, the operator's devcontainer,
  // CI. Reporting in any of them would spawn a process that does not exist.
  it("returns null outside herdr, and for every partial environment", () => {
    expect(readHerdrEnvironment({})).toBeNull();
    expect(readHerdrEnvironment({ ...IN_HERDR, HERDR_ENV: undefined })).toBeNull();
    expect(readHerdrEnvironment({ ...IN_HERDR, HERDR_ENV: "0" })).toBeNull();
    expect(readHerdrEnvironment({ ...IN_HERDR, HERDR_PANE_ID: undefined })).toBeNull();
    expect(readHerdrEnvironment({ ...IN_HERDR, HERDR_BIN_PATH: undefined })).toBeNull();
    expect(readHerdrEnvironment({ ...IN_HERDR, HERDR_PANE_ID: "" })).toBeNull();
  });
});

describe("run-state mapping", () => {
  it("maps every Motoko run state to a herdr state", () => {
    // Exhaustive by construction: the array is typed as the full union, so adding a RunState
    // member without extending mapRunState fails to compile here as well as at the ui.ts call site.
    const all: MotokoRunState[] = ["idle", "thinking", "tools_wait", "tools_run", "error"];
    expect(all.map((s) => mapRunState(s).state)).toEqual([
      "idle",
      "working",
      "working",
      "working",
      "blocked",
    ]);
  });

  it("carries a message only for the blocked state", () => {
    expect(mapRunState("error").message).toMatch(/error/);
    for (const s of ["idle", "thinking", "tools_wait", "tools_run"] as MotokoRunState[]) {
      expect(mapRunState(s).message).toBeUndefined();
    }
  });
});

describe("argv construction", () => {
  it("builds a report herdr will accept", () => {
    expect(buildReportArgs("w1:p2", { state: "working" }, 7)).toEqual([
      "pane", "report-agent", "w1:p2",
      "--source", HERDR_SOURCE,
      "--agent", HERDR_AGENT_LABEL,
      "--state", "working",
      "--seq", "7",
    ]);
  });

  it("appends --message when there is one", () => {
    const args = buildReportArgs("w1:p2", { state: "blocked", message: "boom" }, 1);
    expect(args.slice(-2)).toEqual(["--message", "boom"]);
  });

  it("builds session and release argv against the same source", () => {
    expect(buildSessionArgs("w1:p2", "/tmp/s.jsonl", 2)).toContain("report-agent-session");
    expect(buildSessionArgs("w1:p2", "/tmp/s.jsonl", 2)).toContain("/tmp/s.jsonl");
    expect(buildReleaseArgs("w1:p2", 3)).toEqual([
      "pane", "release-agent", "w1:p2",
      "--source", HERDR_SOURCE,
      "--agent", HERDR_AGENT_LABEL,
      "--seq", "3",
    ]);
  });

  // herdr constrains both identifiers, and a violation is rejected by the server rather than
  // reported — i.e. it would fail silently in production.
  it("uses identifiers herdr accepts", () => {
    expect(HERDR_AGENT_LABEL).toMatch(/^[a-z][a-z0-9_-]{0,31}$/);
    expect(HERDR_SOURCE).toMatch(/^[A-Za-z0-9:._-]{1,80}$/);
  });
});

describe("reporter lifecycle", () => {
  let fired: string[][] = [];

  beforeEach(() => {
    __resetForTests();
    fired = [];
    __setSpawnHookForTests((args) => fired.push(args));
  });

  afterEach(() => {
    __setSpawnHookForTests(null);
    __resetForTests();
  });

  it("does nothing at all outside a herdr pane", () => {
    __setSpawnHookForTests(null);
    expect(initHerdrReporter({})).toBe(false);
    // With no hook and no environment these must be silent no-ops rather than throwing or
    // spawning: this is the path every non-herdr run takes.
    expect(() => {
      reportRunState("thinking");
      reportSessionPath("/tmp/s.jsonl");
      releaseHerdrReporter();
    }).not.toThrow();
  });

  it("increases the sequence number on every report", () => {
    reportRunState("thinking");
    reportRunState("idle");
    reportSessionPath("/tmp/s.jsonl");
    const seqs = fired.map((a) => Number(a[a.indexOf("--seq") + 1]));
    expect(seqs).toEqual([1, 2, 3]);
  });

  it("releases once, however many times it is called", () => {
    releaseHerdrReporter();
    releaseHerdrReporter();
    releaseHerdrReporter();
    expect(fired.filter((a) => a[1] === "release-agent")).toHaveLength(1);
  });
});
