import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { SessionLogger } from "./session-logger.js";

// M-MOTOKO-EVAL-HARNESS-HARDENING M4c (gap #4): regression tests for the
// session_id filename unification. Three IDs MUST converge when the AILANG
// adapter sets MOTOKO_SESSION_ID — the JSONL filename must equal the env
// var (modulo .jsonl extension), so the adapter's findSessionJSONL search
// hits the exact-match branch instead of the newest-in-dir fallback.
describe("SessionLogger filename unification (M4a)", () => {
  let projectRoot: string;
  let savedEnv: string | undefined;

  beforeEach(() => {
    projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "session-logger-test-"));
    savedEnv = process.env.MOTOKO_SESSION_ID;
  });

  afterEach(async () => {
    if (savedEnv === undefined) {
      delete process.env.MOTOKO_SESSION_ID;
    } else {
      process.env.MOTOKO_SESSION_ID = savedEnv;
    }
    // Give pending WriteStream open()/close() callbacks a chance to drain
    // before we yank their parent directory out from under them. Without
    // this, ENOENT errors from the streams' open() calls leak into the
    // node event loop after Jest finishes, producing scary-looking "throw
    // er; // Unhandled 'error' event" trailers in CI logs.
    await new Promise((resolve) => setTimeout(resolve, 50));
    fs.rmSync(projectRoot, { recursive: true, force: true });
  });

  it("uses MOTOKO_SESSION_ID for the filename when set", () => {
    process.env.MOTOKO_SESSION_ID = "session_abc-123-deterministic";
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    try {
      const want = path.join(
        projectRoot,
        ".motoko",
        "logfile",
        "session_abc-123-deterministic.jsonl",
      );
      expect(logger.filePath).toBe(want);
      // The .motoko/logfile dir must exist immediately (mkdirSync in
      // ctor); the file itself is opened by createWriteStream which is
      // lazy until first write — only assert dir presence here.
      expect(fs.existsSync(path.dirname(want))).toBe(true);
    } finally {
      void logger.close();
    }
  });

  it("falls back to ISO timestamp when MOTOKO_SESSION_ID is unset", () => {
    delete process.env.MOTOKO_SESSION_ID;
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    try {
      // Filename should match session_<ISO timestamp>.jsonl pattern. Avoid
      // pinning the exact timestamp — just verify the shape.
      const base = path.basename(logger.filePath);
      expect(base).toMatch(/^session_\d{4}-\d{2}-\d{2}T.*\.jsonl$/);
    } finally {
      void logger.close();
    }
  });

  it("falls back to ISO timestamp when MOTOKO_SESSION_ID is empty string", () => {
    process.env.MOTOKO_SESSION_ID = "";
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    try {
      const base = path.basename(logger.filePath);
      expect(base).toMatch(/^session_\d{4}-\d{2}-\d{2}T.*\.jsonl$/);
    } finally {
      void logger.close();
    }
  });

  it("sanitizes path-traversal attempts", () => {
    process.env.MOTOKO_SESSION_ID = "../etc/passwd";
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    try {
      // Should be sanitized — no slash should reach the filename. We don't
      // pin the exact replacement (could be _etc_passwd) but the directory
      // depth must stay flat.
      const dir = path.dirname(logger.filePath);
      expect(dir).toBe(path.join(projectRoot, ".motoko", "logfile"));
      expect(path.basename(logger.filePath)).not.toContain("/");
      expect(path.basename(logger.filePath)).not.toContain("..");
    } finally {
      void logger.close();
    }
  });

  it("rejects degenerate inputs ('.', '..', '...', '___') with a session_<timestamp> sentinel", () => {
    // The empty-string case is handled separately above (constructor short-
    // circuits to the ISO-timestamp branch before ever calling sanitize).
    // The ones in this list all reach sanitize and trigger the sentinel.
    for (const evilID of [".", "..", "...", "___"]) {
      process.env.MOTOKO_SESSION_ID = evilID;
      const logger = new SessionLogger(projectRoot, "test-tui-version");
      try {
        const base = path.basename(logger.filePath);
        // Should fall back to session_<digits>.jsonl sentinel.
        expect(base).toMatch(/^session_\d+\.jsonl$/);
      } finally {
        void logger.close();
      }
    }
  });

  it("'/' and '\\\\' alone become a safe single-char filename (not a sentinel, but flat in-dir)", () => {
    // These DON'T trigger the sentinel — they sanitize to "_" which is a
    // valid (if odd) flat filename. The important guarantee is that the
    // file lands inside the configured dir, with no path traversal.
    for (const evilID of ["/", "\\"]) {
      process.env.MOTOKO_SESSION_ID = evilID;
      const logger = new SessionLogger(projectRoot, "test-tui-version");
      try {
        const dir = path.dirname(logger.filePath);
        expect(dir).toBe(path.join(projectRoot, ".motoko", "logfile"));
      } finally {
        void logger.close();
      }
    }
  });

  // The transcript half of the guard ui.ts has carried since the banner was
  // added: session_start is re-emitted once per user turn without the version
  // fields, and an unguarded banner writes "AILANG built undefined | Core
  // Runtime vundefined" into the transcript for every turn after the first.
  it("writes the version banner only for the session_start that carries versions", async () => {
    process.env.MOTOKO_SESSION_ID = "version-banner-transcript";
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    logger.log({
      type: "session_start",
      task: "t",
      model: "m",
      mode: "v2",
      ailangBuilt: "unknown",
      brainVersion: "0.2.0",
    } as never);
    logger.log({
      type: "session_start",
      task: "t",
      model: "m",
      mode: "v2",
      ailangBuilt: null,
      brainVersion: null,
    } as never);
    await logger.close();

    const markdown = fs.readFileSync(logger.markdownPath, "utf8");
    expect(markdown).toContain("AILANG built unknown | Core Runtime v0.2.0 | TUI vtest-tui-version");
    expect(markdown).not.toContain("undefined");
    expect(markdown.match(/AILANG built /g) ?? []).toHaveLength(1);
  });

  it("writes scratchpad_result summaries to the markdown transcript", async () => {
    process.env.MOTOKO_SESSION_ID = "scratchpad-result-transcript";
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    logger.log({
      type: "scratchpad_result",
      tool_call_id: "call_scratchpad",
      request_id: "step-1",
      step: 1,
      cells_json: JSON.stringify([
        {
          index: 0,
          language: "ail",
          title: "tri_step",
          code: "export func main() -> () ! {IO} {\n  println(show(tri_step(10, 55)))\n}",
          exit_code: 0,
          stdout: "66\n",
          stderr: "",
          displays: [
            {
              type: "status",
              mime: "text/plain",
              data: "[ailang] check: passed | verify: verified | committed: yes | ran: yes\n  - tri_step: verified",
            },
          ],
          executionCount: 1,
          cancelled: false,
          truncated: false,
          metadata: {
            ailang: {
              check: "passed",
              verify: "verified",
              verifyAvailable: true,
              committed: true,
              ran: true,
            },
          },
          durationMs: 12,
        },
      ]),
    });
    await logger.close();

    const markdown = fs.readFileSync(logger.markdownPath, "utf8");
    expect(markdown).toContain("SCRATCHPAD | 1 cell | ok 1 failed 0 | 12ms");
    expect(markdown).toContain("OK [1/1] tri_step (12ms)");
    expect(markdown).toContain("ailang: check passed | verify verified | committed yes | ran yes");
    expect(markdown).toContain("export func main() -> () ! {IO}");
    expect(markdown).toContain("  66");
    expect(markdown).toContain("[ailang] check: passed | verify: verified | committed: yes | ran: yes");
  });
});

// ADR-003 v6.1 D2 / PLAN-003 P1 Part 6. Two facts about the suspension the host has to keep, and
// the second is the one a literal reading of the plan would have broken.
describe("SessionLogger and the run_suspended record", () => {
  let projectRoot: string;

  beforeEach(() => {
    projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "session-logger-suspend-"));
  });

  afterEach(async () => {
    await new Promise((resolve) => setTimeout(resolve, 50));
    fs.rmSync(projectRoot, { recursive: true, force: true });
  });

  it("writes a transcript line that is not an error line", async () => {
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    logger.log({
      type: "run_suspended",
      session_id: "session_0",
      run_id: "session_0.r0.0",
      reason: "budget_exhausted",
      step: 5,
    });
    await logger.close();

    const markdown = fs.readFileSync(logger.markdownPath, "utf8");
    expect(markdown).toContain("Run suspended: budget_exhausted at step 5");
    expect(markdown).toContain("session_0.r0.0");
    // The whole point of D2 is that reaching the budget is no longer a failure. A transcript that
    // said "Error:" here would be the old story told in a new place.
    expect(markdown).not.toContain("Error:");
  });

  // THE REGRESSION THIS PINS. index.ts's non-TTY path drains the streams on `run_suspended` before
  // handing the event to the logger UI. It must drain WITHOUT closing: in P1 the headless wire is
  // `run_suspended`, `run_summary`, `error`, and `log()` returns early once `closed` is set — so a
  // `close()` there would drop the `run_summary`, which is exactly the tail
  // M-MOTOKO-EVAL-HARNESS-HARDENING gap #1 added the drain to protect.
  it("flush() puts the record on disk and still accepts the run_summary that follows", async () => {
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    logger.log({
      type: "run_suspended",
      session_id: "session_0",
      run_id: "session_0.r0.0",
      reason: "budget_exhausted",
      step: 5,
    });
    await logger.flush();

    // Everything written before the flush is on the fd, with the stream still open.
    const afterFlush = fs.readFileSync(logger.filePath, "utf8");
    expect(afterFlush).toContain('"type":"run_suspended"');

    logger.log({ type: "run_summary", finish_reason: "max_steps", steps_executed: 5 } as never);
    await logger.close();

    const lines = fs
      .readFileSync(logger.filePath, "utf8")
      .split("\n")
      .filter((l) => l.trim() !== "")
      .map((l) => JSON.parse(l) as { type: string });
    expect(lines.map((l) => l.type)).toEqual(["run_suspended", "run_summary"]);
  });
});
