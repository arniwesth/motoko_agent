import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { parseAgentEventLine } from "./runtime-process.js";
import { SessionLogger } from "./session-logger.js";

describe("unknown agent events", () => {
  let projectRoot: string;
  let savedSession: string | undefined;

  beforeEach(() => {
    projectRoot = fs.mkdtempSync(path.join(os.tmpdir(), "unknown-agent-events-"));
    savedSession = process.env.MOTOKO_SESSION_ID;
    process.env.MOTOKO_SESSION_ID = "unknown-event-test";
  });

  afterEach(async () => {
    if (savedSession === undefined) {
      delete process.env.MOTOKO_SESSION_ID;
    } else {
      process.env.MOTOKO_SESSION_ID = savedSession;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
    fs.rmSync(projectRoot, { recursive: true, force: true });
  });

  it("parses Phase-B additive event types as generic agent events", () => {
    for (const type of ["provider_call_prepared", "ext_compaction_rejected"]) {
      const event = parseAgentEventLine(JSON.stringify({ type, step: 1, note: "ok" }));
      expect(event).not.toBeNull();
      expect(event?.type).toBe(type);
    }
  });

  it("logs unknown types without throwing and preserves them in JSONL", async () => {
    const logger = new SessionLogger(projectRoot, "test-tui-version");
    expect(() => {
      logger.log({ type: "provider_call_prepared", step: 1, msg_count: 2 } as never);
      logger.log({ type: "ext_compaction_rejected", step: 1, note: "bad output" } as never);
    }).not.toThrow();
    await logger.close();

    const jsonl = fs.readFileSync(logger.filePath, "utf8");
    expect(jsonl).toContain('"type":"provider_call_prepared"');
    expect(jsonl).toContain('"type":"ext_compaction_rejected"');
  });
});
