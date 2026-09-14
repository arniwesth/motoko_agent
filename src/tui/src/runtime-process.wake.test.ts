import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { interruptRuntime, journalExitReason, RuntimeProcess, type AgentEvent } from "./runtime-process.js";
import type { WakeReply, WakeRequest, WakeWaiterFactory } from "./wake-waiter.js";

// PLAN-002 W4 gate 6, host protocol: `wake_request` / `wake_reply` over a real child (a shell script
// standing in for the AILANG runtime, as `runtime-process.unexplained-exit.test.ts` does).

const RID = "s.r0.1.p1";
const wakeRequest = (waits: unknown[], attempt = 1) =>
  JSON.stringify({ type: "wake_request", request_id: RID, step: 3, attempt, waits });
const wakeReceived = JSON.stringify({ type: "wake_received", request_id: RID, wait_id: "", outcome: "operator_input", detail: "hi" });

/** A waiter factory that never observes anything, and records starts and cancels. */
function recordingFactory() {
  const started: WakeRequest[] = [];
  const onReadys: Array<(r: WakeReply) => void> = [];
  let cancels = 0;
  const factory: WakeWaiterFactory = (req, onReady) => {
    started.push(req);
    onReadys.push(onReady);
    let finished = false;
    return {
      cancel: () => {
        if (!finished) cancels++;
        finished = true;
      },
      get finished() {
        return finished;
      },
    };
  };
  return { factory, started, onReadys, cancels: () => cancels };
}

describe("RuntimeProcess park and wake", () => {
  let workdir: string;
  let savedBin: string | undefined;
  let stdinLog: string;

  beforeEach(() => {
    workdir = fs.mkdtempSync(path.join(os.tmpdir(), "wake-protocol-"));
    stdinLog = path.join(workdir, "stdin.jsonl");
    savedBin = process.env.AILANG_BIN;
  });

  afterEach(() => {
    if (savedBin === undefined) delete process.env.AILANG_BIN;
    else process.env.AILANG_BIN = savedBin;
    fs.rmSync(workdir, { recursive: true, force: true });
  });

  /** `READ` in a script appends the next stdin line to the log. */
  const READ = () => `IFS= read -r line; printf '%s\\n' "$line" >> '${stdinLog}'`;
  const emit = (json: string) => `printf '%s\\n' '${json}'`;

  function run(
    script: string,
    onEvent: (rp: RuntimeProcess, e: AgentEvent) => void = () => {},
    factory?: WakeWaiterFactory,
  ): Promise<{ events: AgentEvent[]; stdin: Record<string, unknown>[]; rp: RuntimeProcess }> {
    const bin = path.join(workdir, "fake-ailang.sh");
    fs.writeFileSync(bin, `#!/bin/sh\n${script}\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    const events: AgentEvent[] = [];
    return new Promise((resolve) => {
      let rp: RuntimeProcess;
      // eslint-disable-next-line prefer-const
      rp = new RuntimeProcess(
        "task", "http://127.0.0.1:1", "test-model", workdir, "default", 1, "", "", "",
        (e) => {
          events.push(e);
          onEvent(rp, e);
        },
        () => {
          const stdin = fs.existsSync(stdinLog)
            ? fs.readFileSync(stdinLog, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as Record<string, unknown>)
            : [];
          resolve({ events, stdin, rp });
        },
        undefined,
        factory,
      );
    });
  }

  const errors = (events: AgentEvent[]) => events.filter((e) => e.type === "error");

  it("round trip: a wake_request is forwarded, the waiter's reply goes down stdin as wake_reply", async () => {
    const { events, stdin, rp } = await run(
      [emit(wakeRequest([{ id: "t1", deadline_ms: 0 }])), READ(),
       emit(JSON.stringify({ type: "wake_received", request_id: RID, wait_id: "t1", outcome: "timed_out", detail: "" })),
       emit('{"type":"done","step":4,"output":"ok"}')].join("\n"),
    );
    expect(events.map((e) => e.type)).toEqual(["wake_request", "wake_received", "done"]);
    expect(stdin).toEqual([{ type: "wake_reply", request_id: RID, wait_id: "t1", outcome: "timed_out", detail: "" }]);
    expect(rp.wakeRequest).toBeNull();
    expect(errors(events)).toHaveLength(0);
  });

  it("drops late replies by request_id and cancels the waiter on wake", async () => {
    const rec = recordingFactory();
    const sent: boolean[] = [];
    const { stdin } = await run(
      [emit(wakeRequest([{ id: "op" }])), READ(), emit(wakeReceived), READ(), "exit 0"].join("\n"),
      (rp, e) => {
        if (e.type === "wake_request") {
          expect(rp.wakeRequest?.request_id).toBe(RID);
          sent.push(rp.sendWakeReply({ request_id: "s.r0.1.p0", wait_id: "", outcome: "operator_input", detail: "stale park" }));
          rec.onReadys[0]({ request_id: RID, wait_id: "d0", outcome: "settled", detail: "answer" });
          expect(rec.cancels()).toBe(1);
          sent.push(rp.sendWakeReply({ request_id: RID, wait_id: "d0", outcome: "settled", detail: "twice" }));
          rec.onReadys[0]({ request_id: RID, wait_id: "d0", outcome: "lost", detail: "late waiter" });
        }
        if (e.type === "wake_received") {
          sent.push(rp.sendWakeReply({ request_id: RID, wait_id: "", outcome: "operator_input", detail: "after resolve" }));
          rp.sendUserMessage("marker");
        }
      },
      rec.factory,
    );
    expect(sent).toEqual([false, false, false]);
    expect(stdin).toEqual([
      { type: "wake_reply", request_id: RID, wait_id: "d0", outcome: "settled", detail: "answer" },
      { type: "user_message", content: "marker" },
    ]);
  });

  it("a re-issue of the same request (attempt+1) is tracked and answerable again", async () => {
    const rec = recordingFactory();
    const { stdin } = await run(
      [emit(wakeRequest([{ id: "op" }], 1)), READ(), emit(wakeRequest([{ id: "op" }], 2)), READ(), "exit 0"].join("\n"),
      (rp, e) => {
        if (e.type === "wake_request") {
          expect(rp.wakeRequest?.attempt).toBe((e as WakeRequest).attempt);
          rp.sendWakeReply({ request_id: RID, wait_id: "", outcome: "operator_input", detail: `a${(e as WakeRequest).attempt}` });
        }
      },
      rec.factory,
    );
    expect(rec.started.map((r) => r.attempt)).toEqual([1, 2]);
    expect(stdin.map((l) => l.detail)).toEqual(["a1", "a2"]);
  });

  it("defers setModel while parked and flushes it once the request resolves", async () => {
    const rec = recordingFactory();
    const { stdin } = await run(
      [emit(wakeRequest([{ id: "op" }])), READ(), emit(wakeReceived), READ(), "exit 0"].join("\n"),
      (rp, e) => {
        if (e.type === "wake_request") {
          rp.setModel("model-2");
          rp.sendWakeReply({ request_id: RID, wait_id: "", outcome: "operator_input", detail: "hi" });
        }
      },
      rec.factory,
    );
    expect(stdin).toEqual([
      { type: "wake_reply", request_id: RID, wait_id: "", outcome: "operator_input", detail: "hi" },
      { type: "model_change", model: "model-2" },
    ]);
  });

  it("does not defer setModel when no park is open", async () => {
    const { stdin } = await run([emit('{"type":"thinking","step":1,"text":""}'), READ(), "exit 0"].join("\n"), (rp, e) => {
      if (e.type === "thinking") rp.setModel("model-3");
    });
    expect(stdin).toEqual([{ type: "model_change", model: "model-3" }]);
  });

  for (const code of [0, 2]) {
    it(`ESC during a park sends abort, does not kill, and a child exit with code ${code} synthesizes no error`, async () => {
      const rec = recordingFactory();
      const actions: string[] = [];
      const { events, stdin } = await run(
        [emit(wakeRequest([{ id: "op" }])), READ(), `exit ${code}`].join("\n"),
        (rp, e) => {
          if (e.type === "wake_request") actions.push(interruptRuntime(rp));
        },
        rec.factory,
      );
      expect(actions).toEqual(["abort"]);
      // The script only records the line because it was NOT killed.
      expect(stdin).toEqual([{ type: "abort" }]);
      expect(errors(events)).toHaveLength(0);
      expect(rec.cancels()).toBe(1);
      // index.ts's exit handler: ESC set `interrupted`, no restart pending.
      expect(journalExitReason(undefined, true)).toBe("abort");
    });
  }

  it("control: the same abort and non-zero exit with no park open still reports the exit", async () => {
    const { events, stdin } = await run(
      [emit('{"type":"thinking","step":1,"text":""}'), READ(), "exit 2"].join("\n"),
      (rp, e) => {
        if (e.type === "thinking") rp.abort();
      },
    );
    expect(stdin).toEqual([{ type: "abort" }]);
    expect(errors(events)).toHaveLength(1);
  });

  it("quit (exit) and restart while parked cancel the request and exit without a synthesized error", async () => {
    const quit = recordingFactory();
    const q = await run([emit(wakeRequest([{ id: "op" }])), READ(), "exit 1"].join("\n"),
      (rp, e) => { if (e.type === "wake_request") rp.exit(); }, quit.factory);
    expect(q.stdin).toEqual([{ type: "exit" }]);
    expect(errors(q.events)).toHaveLength(0);
    expect(quit.cancels()).toBe(1);
    fs.rmSync(stdinLog, { force: true });

    const restart = recordingFactory();
    const r = await run(
      [emit(wakeRequest([{ id: "op" }])), READ(), emit('{"type":"session_suspend","target_profile":"p2"}'), "exit 1"].join("\n"),
      (rp, e) => { if (e.type === "wake_request") rp.restart("p2"); }, restart.factory);
    expect(r.stdin).toEqual([{ type: "restart", profile: "p2" }]);
    expect(errors(r.events)).toHaveLength(0);
    expect(restart.cancels()).toBe(1);
    expect(r.rp.restartPending).toBe("p2");
    expect(journalExitReason(r.rp.restartPending, false)).toBe("restart");
  });

  it("cancels the waiter when the runtime exits mid-park", async () => {
    const rec = recordingFactory();
    const { rp } = await run([emit(wakeRequest([{ id: "op" }])), "exit 0"].join("\n"), () => {}, rec.factory);
    expect(rec.started).toHaveLength(1);
    expect(rec.cancels()).toBe(1);
    expect(rp.wakeRequest).toBeNull();
    expect(rp.sendWakeReply({ request_id: RID, wait_id: "", outcome: "operator_input", detail: "x" })).toBe(false);
  });

  it("ESC with no park kills, as before", () => {
    const calls: string[] = [];
    const fakeRp = { isParked: false, abort: () => calls.push("abort"), kill: () => calls.push("kill") };
    expect(interruptRuntime(fakeRp)).toBe("kill");
    expect(interruptRuntime({ ...fakeRp, isParked: true })).toBe("abort");
    expect(interruptRuntime(undefined)).toBe("none");
    expect(calls).toEqual(["kill", "abort"]);
    expect(journalExitReason(undefined, false)).toBe("child_exit");
  });
});
