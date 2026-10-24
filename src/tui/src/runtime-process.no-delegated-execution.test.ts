import { describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { RuntimeProcess, type AgentEvent } from "./runtime-process.js";

describe("legacy delegated events have no execution path", () => {
  const sourcePath = new URL("./runtime-process.ts", import.meta.url);
  const source = fs.readFileSync(sourcePath, "utf8");

  it("has no dormant executor helpers or execution branch", () => {
    expect(source).not.toContain("runDelegatedCall");
    expect(source).not.toContain("handleToolCalls");
    expect(source).not.toContain("runDelegatedCallsSequential");
    expect(source).not.toContain("resolveDelegatedSpawn");
    expect(source).not.toContain("dispatchOhMyPiTool");
    expect(source).not.toContain('if (event.type === "tool_calls")');
  });

  it("retains legacy wire types for scoped presentation cleanup, not execution", () => {
    expect(source).toContain('| { type: "tool_calls"; request_id: string; tool_calls: DelegatedCall[] }');
    expect(source).toContain("their protocol");
    expect(source).toContain("cleanup is separate");
  });

  it("forwards a legacy event but never spawns its command or answers tool_results", async () => {
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "no-delegated-exec-"));
    const savedBin = process.env.AILANG_BIN;
    const marker = path.join(workdir, "must-not-exist");
    const bin = path.join(workdir, "fake-ailang.sh");
    const event = JSON.stringify({
      type: "tool_calls", request_id: "legacy-1",
      tool_calls: [{ id: "x", tool: "BashExec", exec: { cmd: `touch '${marker}'` } }],
    });
    const script = `#!/bin/sh\nprintf '%s\\n' '${event}'\nexit 0\n`;
    fs.writeFileSync(bin, script, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    try {
      const events: AgentEvent[] = [];
      await new Promise<void>((resolve) => {
        new RuntimeProcess(
          "task", "local", "test-model", workdir, "default", 1, "", "", "",
          (event) => events.push(event), () => resolve(),
        );
      });
      expect(events.filter((event) => event.type === "tool_calls")).toHaveLength(1);
      expect(fs.existsSync(marker)).toBe(false);
      // The fake child exits after emitting the legacy event. No delegated
      // process is available to create the marker or consume a reply.
    } finally {
      if (savedBin === undefined) delete process.env.AILANG_BIN;
      else process.env.AILANG_BIN = savedBin;
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });
});
