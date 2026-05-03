import { describe, it, expect } from "@jest/globals";
import type { DelegatedCall, DelegatedResult } from "./runtime-process.js";
import { runDelegatedCallsSequential, resolveDelegatedSpawn } from "./runtime-process.js";

describe("runDelegatedCallsSequential", () => {
  it("emits progress in call order and returns all results", () => {
    const calls: DelegatedCall[] = [
      { id: "a", tool: "BashExec", exec: { cmd: "echo" } },
      { id: "b", tool: "BashExec", exec: { cmd: "echo" } },
      { id: "c", tool: "BashExec", exec: { cmd: "echo" } },
    ];
    const seen: string[] = [];
    const runner = (call: DelegatedCall): DelegatedResult => ({
      tool_call_id: call.id,
      stdout: "",
      stderr: "",
      exit_code: call.id === "b" ? 1 : 0,
      truncated: false,
    });

    const results = runDelegatedCallsSequential(calls, runner, (result) => {
      seen.push(`${result.tool_call_id}:${result.exit_code}`);
    });

    expect(seen).toEqual(["a:0", "b:1", "c:0"]);
    expect(results.map((r) => `${r.tool_call_id}:${r.exit_code}`)).toEqual(["a:0", "b:1", "c:0"]);
  });
});

describe("resolveDelegatedSpawn", () => {
  it("uses direct spawn for simple executable commands", () => {
    const out = resolveDelegatedSpawn({ cmd: "ls", args: ["-la"] });
    expect(out).toEqual({ cmd: "ls", args: ["-la"] });
  });

  it("uses bash -lc for shell-style commands", () => {
    const out = resolveDelegatedSpawn({ cmd: "echo hi && ls -la" });
    expect(out.cmd).toBe("bash");
    expect(out.args[0]).toBe("-lc");
    expect(out.args[1]).toContain("echo hi && ls -la");
  });
});
