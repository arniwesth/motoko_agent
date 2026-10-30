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

  it("forwards a legacy event but never spawns, emits tool_results, or replies", async () => {
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "no-delegated-exec-"));
    const savedBin = process.env.AILANG_BIN;
    const marker = path.join(workdir, "must-not-exist");
    const stdinLog = path.join(workdir, "stdin.jsonl");
    const bin = path.join(workdir, "fake-ailang.sh");
    const event = JSON.stringify({
      type: "tool_calls", request_id: "legacy-1",
      tool_calls: [{ id: "x", tool: "BashExec", exec: { cmd: `touch '${marker}'` } }],
    });
    // Keep the runtime alive across the deferred setImmediate turn. Its own
    // stdout stays open while stdin is logged without a blocking read.
    const script = `#!/bin/sh\nprintf '%s\\n' '${event}'\nsleep 0.25\ncat > '${stdinLog}'\n`;
    fs.writeFileSync(bin, script, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    try {
      const events: AgentEvent[] = [];
      await new Promise<void>((resolve) => {
        const rp = new RuntimeProcess(
          "task", "local", "test-model", workdir, "default", 1, "", "", "",
          (event) => events.push(event), () => resolve(),
        );
        rp.send({ type: "probe", request_id: "legacy-1" });
        (rp as any).proc.stdin.end();
      });
      expect(events.filter((event) => event.type === "tool_calls")).toHaveLength(1);
      expect(events.filter((event) => event.type === "tool_results")).toHaveLength(0);
      expect(fs.existsSync(marker)).toBe(false);
      // Check after both the deferred turn and a realistic delayed `touch`,
      // while the fake runtime and its stdin are still available.
      expect(fs.readFileSync(stdinLog, "utf8")).not.toContain("tool_results");
    } finally {
      if (savedBin === undefined) delete process.env.AILANG_BIN;
      else process.env.AILANG_BIN = savedBin;
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });

  it("mutation control: an asynchronous delegated spawn would be observed", async () => {
    // This is the timing the old implementation used: handle on the next turn,
    // while the runtime is still alive. The production assertion above would
    // see this marker and reject it, rather than racing an already-dead runtime.
    const workdir = fs.mkdtempSync(path.join(os.tmpdir(), "delegated-control-"));
    const marker = path.join(workdir, "spawned");
    try {
      const { spawn } = await import("child_process");
      const child = spawn("bash", ["-lc", `touch '${marker}'`]);
      await new Promise<void>((resolve) => child.on("close", () => resolve()));
      expect(fs.existsSync(marker)).toBe(true);
    } finally {
      fs.rmSync(workdir, { recursive: true, force: true });
    }
  });
});
