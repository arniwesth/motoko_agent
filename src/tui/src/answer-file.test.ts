import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  ANSWER_UNPUBLISHED_EXIT_CODE,
  finishOneShot,
  formatUnpublished,
  oneShotExitCode,
  publishAnswer,
  unpublishedOnExit,
  type OneShotFinish,
} from "./answer-file.js";
import { HeadlessOutcome } from "./headless-outcome.js";
import { SessionLogger } from "./session-logger.js";
import { __setSessionIdentityForTests } from "./session-identity.js";
import type { AgentEvent } from "./runtime-process.js";

// ADR-002 v4.2 D1.2 / PLAN-002 W1b: host-owned answer publication.
const done = (output: string): AgentEvent => ({ type: "done", step: 3, output });
const errored: AgentEvent = { type: "error", message: "provider refused" };

describe("publishAnswer", () => {
  let dir: string;
  let target: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "answer-file-test-"));
    target = path.join(dir, "answer-x.md");
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it("writes a non-empty done atomically, leaving no temp file behind", () => {
    const p = publishAnswer(target, done("the answer\n"), false);
    expect(p).toEqual({ ok: true, wrote: true, path: target });
    expect(fs.readFileSync(target, "utf8")).toBe("the answer\n");
    expect(fs.readdirSync(dir)).toEqual(["answer-x.md"]);
  });

  it("lets an existing non-empty file win, and does not touch it", () => {
    fs.writeFileSync(target, "written by the model");
    const p = publishAnswer(target, done("the host's copy"), false);
    expect(p).toEqual({ ok: true, wrote: false, path: target });
    expect(fs.readFileSync(target, "utf8")).toBe("written by the model");
  });

  it("lets an existing report win even over a blank done", () => {
    fs.writeFileSync(target, "written by the model");
    expect(publishAnswer(target, done("  \n"), false).ok).toBe(true);
  });

  it("treats a whitespace-only existing file as absent", () => {
    fs.writeFileSync(target, " \n");
    expect(publishAnswer(target, done("real"), false)).toMatchObject({ ok: true, wrote: true });
    expect(fs.readFileSync(target, "utf8")).toBe("real");
  });

  it("writes nothing for an empty done", () => {
    const p = publishAnswer(target, done("   "), false);
    expect(p.ok).toBe(false);
    expect(fs.existsSync(target)).toBe(false);
    if (!p.ok) expect(p.reason).toMatch(/empty `done`/);
  });

  it("writes nothing for a runtime error", () => {
    const p = publishAnswer(target, errored, false);
    expect(p.ok).toBe(false);
    expect(fs.existsSync(target)).toBe(false);
    if (!p.ok) expect(p.reason).toContain("provider refused");
  });

  it("writes nothing for an aborted run, even with a non-empty done", () => {
    const p = publishAnswer(target, done("partial"), true);
    expect(p.ok).toBe(false);
    expect(fs.existsSync(target)).toBe(false);
  });

  it("reports an unwritable destination as a publication failure and writes nothing", () => {
    const missing = path.join(dir, "no-such-dir", "answer.md");
    const p = publishAnswer(missing, done("the answer"), false);
    expect(p.ok).toBe(false);
    if (!p.ok) expect(p.reason).toMatch(/^publication failed/);
    expect(fs.existsSync(path.dirname(missing))).toBe(false);
    expect(fs.readdirSync(dir)).toEqual([]);
  });

  it("puts the reason on one stderr line", () => {
    const p = unpublishedOnExit(target, true);
    expect(p.ok).toBe(false);
    if (!p.ok) expect(formatUnpublished(p)).toBe(`[answer-file] nothing published to ${target}: the run was aborted\n`);
  });
});

describe("one-shot exit codes", () => {
  it("exits 0 only when the answer is on disk, or none was asked for", () => {
    expect(oneShotExitCode(done("x"), { ok: true, wrote: true, path: "/a" })).toBe(0);
    expect(oneShotExitCode(done("x"), null)).toBe(0);
    expect(oneShotExitCode(done(""), { ok: false, reason: "empty", path: "/a" })).toBe(ANSWER_UNPUBLISHED_EXIT_CODE);
    expect(oneShotExitCode(errored, { ok: false, reason: "error", path: "/a" })).toBe(1);
    expect(oneShotExitCode(errored, null)).toBe(1);
    expect(ANSWER_UNPUBLISHED_EXIT_CODE).not.toBe(0);
  });

  // The plain/JSONL loggers: `done` exits with `doneExitCode`, the runtime's exit with `exitCode`.
  it("records an unpublished answer on the headless outcome", () => {
    const outcome = new HeadlessOutcome();
    expect(outcome.doneExitCode).toBe(0);
    outcome.refuseAnswer();
    expect(outcome.doneExitCode).toBe(ANSWER_UNPUBLISHED_EXIT_CODE);
    expect(outcome.exitCode).toBe(ANSWER_UNPUBLISHED_EXIT_CODE);
  });

  it("does not let a refused answer mask a suspension's exit", () => {
    const outcome = new HeadlessOutcome();
    outcome.observe({ type: "run_suspended", session_id: "s", run_id: "s.r0.0", reason: "budget_exhausted", step: 1 });
    outcome.refuseAnswer();
    expect(outcome.exitCode).toBe(1);
  });
});

describe("finishOneShot (interactive one-shot, TTY)", () => {
  let dir: string;
  let target: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "oneshot-test-"));
    target = path.join(dir, "answer.md");
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  function recorder(closeGate: Promise<void>) {
    const calls: string[] = [];
    let exitCode: number | null = null;
    let stderr = "";
    const deps: OneShotFinish = {
      forward: (e) => calls.push(`forward:${e.type}:${fs.existsSync(target) ? "published" : "absent"}`),
      close: () => {
        calls.push("close");
        return closeGate.then(() => {
          calls.push("drained");
        });
      },
      stopUi: () => calls.push("stopUi"),
      stderr: (line) => {
        stderr += line;
        calls.push("stderr");
      },
      // The exit is where the exit actions and the herdr reporter's release run (both are `exit`
      // listeners), so whatever is on disk here is what they see.
      exit: (code) => {
        exitCode = code;
        calls.push(`exit:${code}:${fs.existsSync(target) ? "published" : "absent"}`);
      },
    };
    return { calls, deps, exitCode: () => exitCode, stderr: () => stderr };
  }

  it("publishes before forwarding, and exits only after the logger drains", async () => {
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const r = recorder(gate);
    const finished = finishOneShot(done("final"), target, false, r.deps);
    await new Promise((res) => setTimeout(res, 10));
    expect(r.calls).toEqual(["forward:done:published", "close"]);
    expect(r.exitCode()).toBeNull();
    release();
    await finished;
    expect(r.calls).toEqual(["forward:done:published", "close", "drained", "stopUi", "exit:0:published"]);
  });

  it("keeps an existing report and exits 0", async () => {
    fs.writeFileSync(target, "the model's report");
    const r = recorder(Promise.resolve());
    await finishOneShot(done("host copy"), target, false, r.deps);
    expect(fs.readFileSync(target, "utf8")).toBe("the model's report");
    expect(r.exitCode()).toBe(0);
  });

  it("exits non-zero with the reason on stderr for an unwritable destination", async () => {
    const bad = path.join(dir, "missing", "answer.md");
    const r = recorder(Promise.resolve());
    await finishOneShot(done("final"), bad, false, r.deps);
    expect(r.exitCode()).toBe(ANSWER_UNPUBLISHED_EXIT_CODE);
    expect(r.stderr()).toMatch(/publication failed/);
    expect(r.calls.indexOf("stderr")).toBeGreaterThan(r.calls.indexOf("stopUi"));
  });

  it("exits non-zero for an empty done and for an error, and writes no file", async () => {
    const a = recorder(Promise.resolve());
    await finishOneShot(done(""), target, false, a.deps);
    expect(a.exitCode()).toBe(ANSWER_UNPUBLISHED_EXIT_CODE);
    const b = recorder(Promise.resolve());
    await finishOneShot(errored, target, false, b.deps);
    expect(b.exitCode()).toBe(1);
    expect(b.stderr()).toContain("provider refused");
    expect(fs.existsSync(target)).toBe(false);
  });

  it("without --answer-file publishes nothing and exits 0 on done", async () => {
    const r = recorder(Promise.resolve());
    await finishOneShot(done("final"), null, false, r.deps);
    expect(r.exitCode()).toBe(0);
    expect(r.stderr()).toBe("");
    expect(fs.existsSync(target)).toBe(false);
  });
});

// R4, against the real logger: `run_summary` and `done` are both in the session log file when the
// one-shot exits. `logger.log` is synchronous and buffers; only `close()` drains.
describe("one-shot drain against a real SessionLogger", () => {
  let projectRoot: string;
  let savedEnv: string | undefined;

  beforeEach(() => {
    projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "oneshot-drain-test-"));
    savedEnv = process.env.MOTOKO_SESSION_ID;
    __setSessionIdentityForTests(null);
    process.env.MOTOKO_SESSION_ID = "session_oneshot-drain";
  });

  afterEach(async () => {
    if (savedEnv === undefined) delete process.env.MOTOKO_SESSION_ID;
    else process.env.MOTOKO_SESSION_ID = savedEnv;
    __setSessionIdentityForTests(null);
    await new Promise((resolve) => setTimeout(resolve, 50));
    fs.rmSync(projectRoot, { recursive: true, force: true });
  });

  it("has run_summary and done on disk at exit", async () => {
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    const answer = path.join(projectRoot, "answer.md");
    const summary = { type: "run_summary", finish_reason: "stop" } as unknown as AgentEvent;
    const final = done("final answer");
    let atExit = "";
    let code: number | null = null;
    logger.log(summary);
    logger.log(final);
    await finishOneShot(final, answer, false, {
      forward: () => {},
      close: () => logger.close(),
      stopUi: () => {},
      stderr: () => {},
      exit: (c) => {
        code = c;
        atExit = fs.readFileSync(logger.filePath, "utf8");
      },
    });
    expect(code).toBe(0);
    const types = atExit.trim().split("\n").map((l) => (JSON.parse(l) as { type?: string }).type);
    expect(types).toContain("run_summary");
    expect(types).toContain("done");
    expect(types.indexOf("run_summary")).toBeLessThan(types.lastIndexOf("done"));
    expect(fs.readFileSync(answer, "utf8")).toBe("final answer");
  });
});
