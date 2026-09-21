import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { describeUnexplainedExit, RuntimeProcess, type AgentEvent } from "./runtime-process.js";

// The OOM kills of 2026-09-08 and 2026-09-12 (.agent/issues/a-killed-motoko-process-exits-silently.md):
// a runtime child that dies without a terminal event must be reported, not mistaken for a finish.
describe("describeUnexplainedExit", () => {
  it("names SIGKILL as the likely OOM killer", () => {
    const msg = describeUnexplainedExit(null, "SIGKILL");
    expect(msg).toContain("SIGKILL");
    expect(msg).toContain("memory.events");
  });

  it("reports other signals and non-zero codes", () => {
    expect(describeUnexplainedExit(null, "SIGSEGV")).toContain("SIGSEGV");
    expect(describeUnexplainedExit(2, null)).toContain("code 2");
  });

  it("says nothing about a clean exit", () => {
    expect(describeUnexplainedExit(0, null)).toBeNull();
  });
});

describe("RuntimeProcess child exit", () => {
  let workdir: string;
  let savedBin: string | undefined;

  beforeEach(() => {
    workdir = fs.mkdtempSync(path.join(os.tmpdir(), "unexplained-exit-"));
    savedBin = process.env.AILANG_BIN;
  });

  afterEach(() => {
    if (savedBin === undefined) delete process.env.AILANG_BIN;
    else process.env.AILANG_BIN = savedBin;
    fs.rmSync(workdir, { recursive: true, force: true });
  });

  /** Spawn a RuntimeProcess whose "ailang" is `script`; resolve with its events once it has exited. */
  function run(script: string, act?: (rp: RuntimeProcess) => void): Promise<AgentEvent[]> {
    const bin = path.join(workdir, "fake-ailang.sh");
    fs.writeFileSync(bin, `#!/bin/sh\n${script}\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    const events: AgentEvent[] = [];
    return new Promise((resolve) => {
      const rp = new RuntimeProcess(
        "task", "http://127.0.0.1:1", "test-model", workdir, "default", 1, "", "", "",
        (e) => events.push(e),
        () => resolve(events),
      );
      act?.(rp);
    });
  }

  const errors = (events: AgentEvent[]) => events.filter((e) => e.type === "error");

  it("reports a SIGKILLed child before onExit", async () => {
    const events = await run("kill -9 $$");
    expect(errors(events)).toHaveLength(1);
    expect((errors(events)[0] as { message: string }).message).toContain("SIGKILL");
  });

  it("reports a kill that comes after a finished turn", async () => {
    const events = await run(`echo '{"type":"done","step":1,"output":"ok"}'; echo '{"type":"thinking","step":2}'; kill -9 $$`);
    expect(errors(events)).toHaveLength(1);
  });

  it("adds nothing when the child already said why", async () => {
    const events = await run(`echo '{"type":"error","message":"boom"}'; exit 1`);
    expect(errors(events)).toEqual([{ type: "error", message: "boom" }]);
    const refused = await run(`echo '{"type":"session_resume_refused","journal":"j","refusal":"header","message":"m"}'; exit 3`);
    expect(errors(refused)).toHaveLength(0);
  });

  it("adds nothing for a clean exit or a kill the host asked for", async () => {
    expect(errors(await run("exit 0"))).toHaveLength(0);
    expect(errors(await run("exec sleep 5",(rp) => setTimeout(() => rp.kill(), 50)))).toHaveLength(0);
  });
});
