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
});
