import { afterEach, beforeEach, describe, expect, it } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { abortSuspendedChild, installSuspendedWake, interruptRuntime, journalExitReason, RuntimeProcess, type AgentEvent, type SuspendedChild } from "./runtime-process.js";
import { isJournalClass, SessionJournal } from "./session-journal.js";
import { acquireLease, registerLeaseHooks, type SessionLease, type SignalTarget } from "./session-lease.js";
import type { WakeOutcomeName, WakeReply, WakeRequest, WakeWaiterFactory } from "./wake-waiter.js";

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
  // ------------------------------------------------------------------------------------------------
  // PLAN-003 P4 Part 4 (ADR-003 D7, P4-Q3): SUSPENDED-CHILD under `--park-exits`. A first issue of a
  // `wake_request` ends the child with `kill()` once the `park` entry is on disk; the park outlives
  // the child. Red at 2c0fa52: the exit handler cancelled the waiter (`resolvePark`), and index.ts
  // wrote an `exit` entry after the park.
  // ------------------------------------------------------------------------------------------------
  describe("suspended-child under --park-exits (PLAN-003 P4 Part 4)", () => {
    const H1 = { id: "h1", delegate_kind: "claude", locator: { pane: "p1" }, answer_path: "/tmp/answer.md", run_key: "k1" };
    const parkEntered = JSON.stringify({ type: "park_entered", request_id: RID, step: 3, waits: [H1] });
    const settled = (detail: string): WakeReply => ({ request_id: RID, wait_id: "h1", outcome: "settled", detail });
    /** The child, blocked on the reply it will never get: only `kill()` ends this script. */
    const parkedChild = [emit(parkEntered), emit(wakeRequest([H1])), READ()].join("\n");

    interface HostRun {
      events: AgentEvent[];
      stdin: Record<string, unknown>[];
      rp: RuntimeProcess;
      suspended: SuspendedChild | null;
      entries: Record<string, unknown>[];
      leaf: string;
    }

    /**
     * The TTY host's side of the harness. Journal-class events are routed as `SessionLogger.log`
     * does (the `park` is appended synchronously, before the `wake_request` line is read), and the
     * exit callback is index.ts's: its FIRST branch, above `restartPending`, is the suspended-child
     * one and writes NO `exit` entry (row 6); every other exit writes `journalExitReason`'s.
     */
    function runHost(
      script: string,
      onEvent: (rp: RuntimeProcess, e: AgentEvent) => void,
      factory: WakeWaiterFactory,
      parkExits: boolean,
    ): Promise<HostRun> {
      const journal = new SessionJournal(workdir, "sess-p4", { now: () => 1, onError: (m) => { throw new Error(m); } });
      journal.writeHeader({ sessionId: "sess-p4", workdir, profile: "p", model: "m" });
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
            if (isJournalClass(e.type)) journal.record(e as unknown as Record<string, unknown>);
            onEvent(rp, e);
          },
          () => {
            const suspended = rp.suspendedChild;
            if (suspended === null) journal.writeExit(journalExitReason(rp.restartPending, false));
            const entries = fs.readFileSync(journal.filePath, "utf8").split("\n").filter(Boolean)
              .map((l) => JSON.parse(l) as Record<string, unknown>);
            const stdin = fs.existsSync(stdinLog)
              ? fs.readFileSync(stdinLog, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as Record<string, unknown>)
              : [];
            resolve({ events, stdin, rp, suspended, entries, leaf: journal.currentLeaf });
          },
          undefined,
          factory,
          parkExits,
        );
      });
    }

    const types = (entries: Record<string, unknown>[]) => entries.map((e) => e.type);

    it("a first issue ends the child; the request and the RUNNING waiter go to the owner; no error; the journal's leaf is the park", async () => {
      const rec = recordingFactory();
      const parkedInside: boolean[] = [];
      const r = await runHost(parkedChild, (rp, e) => { if (e.type === "wake_request") parkedInside.push(rp.isParked); }, rec.factory, true);
      expect(r.events.map((e) => e.type)).toEqual(["park_entered", "wake_request"]);
      expect(errors(r.events)).toHaveLength(0);
      // Forwarded before the kill: a consumer sees the park tracked, on a live child.
      expect(parkedInside).toEqual([true]);
      // Killed while blocked on its reply: the child read nothing.
      expect(r.stdin).toEqual([]);
      // The waiter is STILL RUNNING. At the base the exit handler cancelled it (`resolvePark`).
      expect(rec.started).toHaveLength(1);
      expect(rec.cancels()).toBe(0);
      expect(r.suspended).not.toBeNull();
      expect(r.suspended!.request.request_id).toBe(RID);
      expect(r.suspended!.waiter.finished).toBe(false);
      expect(r.suspended!.reply).toBeNull();
      // The process no longer holds the park; the owner does. Nothing asked for a respawn.
      expect(r.rp.wakeRequest).toBeNull();
      expect(r.rp.isParked).toBe(false);
      expect(r.rp.restartPending).toBeUndefined();
      // The leaf IS the park entry: no `exit` after it (row 6), and no `wake` — that is Part 5's.
      expect(types(r.entries)).toEqual(["header", "park"]);
      const park = r.entries[r.entries.length - 1];
      expect(park.request_id).toBe(RID);
      expect(park.id).toBe(r.leaf);
    });

    it("kill-then-reply writes nothing: a reply between kill() and the exit is dropped, the leaf stays the park, no respawn", async () => {
      const rec = recordingFactory();
      const sent: boolean[] = [];
      const deadAtReply: boolean[] = [];
      const r = await runHost(
        parkedChild,
        (rp, e) => {
          if (e.type !== "wake_request") return;
          // After onWakeRequest has returned — after its kill() — and before the child's exit event.
          queueMicrotask(() => {
            deadAtReply.push(rp.isDead);
            rec.onReadys[0](settled("early answer"));
            sent.push(rp.sendWakeReply(settled("typed early")));
          });
        },
        rec.factory,
        true,
      );
      expect(deadAtReply).toEqual([false]);
      // The request died with the child: nothing down stdin, nothing in the journal, nothing to respawn.
      expect(sent).toEqual([false]);
      expect(r.stdin).toEqual([]);
      expect(errors(r.events)).toHaveLength(0);
      expect(types(r.entries)).toEqual(["header", "park"]);
      expect(r.suspended).not.toBeNull();
      expect(r.suspended!.reply).toBeNull();
      expect(r.rp.restartPending).toBeUndefined();
      expect(rec.cancels()).toBe(0);
    });

    it("a reply the owner receives after the exit is held once, by request_id, for Part 5's consumer", async () => {
      const rec = recordingFactory();
      const r = await runHost(parkedChild, () => {}, rec.factory, true);
      const owner = r.suspended!;
      expect(owner.deliver({ request_id: "s.r0.1.p0", wait_id: "", outcome: "operator_input", detail: "stale park" })).toBe(false);
      // The waiter's reply now reaches the owner, not a dead stdin.
      rec.onReadys[0](settled("answer"));
      expect(owner.reply).toEqual(settled("answer"));
      expect(owner.deliver(settled("twice"))).toBe(false);
      expect(r.rp.sendWakeReply(settled("dead"))).toBe(false);
      // A consumer installed after the reply was held gets it at once: Part 5 installs after the branch.
      const got: WakeReply[] = [];
      owner.onReply((reply) => got.push(reply));
      expect(got).toEqual([settled("answer")]);
      // Part 4 writes nothing on it: no `wake` (Part 5's), no `exit` (row 6).
      expect(types(r.entries)).toEqual(["header", "park"]);
    });

    it("a consumer that aborts from inside onEvent cancels the park; the flag does not then kill", async () => {
      const rec = recordingFactory();
      const r = await runHost(
        [emit(parkEntered), emit(wakeRequest([H1])), READ(), "exit 0"].join("\n"),
        (rp, e) => { if (e.type === "wake_request") interruptRuntime(rp); },
        rec.factory,
        true,
      );
      // The child read the abort and exited by itself: an ordinary exit, with its `exit` entry.
      expect(r.stdin).toEqual([{ type: "abort" }]);
      expect(errors(r.events)).toHaveLength(0);
      expect(rec.cancels()).toBe(1);
      expect(r.suspended).toBeNull();
      expect(types(r.entries)).toEqual(["header", "park", "exit"]);
    });

    it("control: with --park-exits off nothing here runs — the exit cancels the waiter and `exit` follows the park", async () => {
      const rec = recordingFactory();
      const r = await runHost([emit(parkEntered), emit(wakeRequest([H1])), "exit 0"].join("\n"), () => {}, rec.factory, false);
      expect(errors(r.events)).toHaveLength(0);
      expect(rec.cancels()).toBe(1);
      expect(r.suspended).toBeNull();
      expect(types(r.entries)).toEqual(["header", "park", "exit"]);
      expect(r.entries[r.entries.length - 1].reason).toBe("child_exit");
    });
  });
  // The harness Parts 5 and 6 share: a session parked and suspended under `--park-exits`, and
  // index.ts's `respawnForRestart` as far as a test can hold it.
  const H1 = { id: "h1", delegate_kind: "claude", locator: { pane: "p1" }, answer_path: "/tmp/answer.md", run_key: "k1" };
  const parkEntered = JSON.stringify({ type: "park_entered", request_id: RID, step: 3, waits: [H1] });
  const settled = (detail: string): WakeReply => ({ request_id: RID, wait_id: "h1", outcome: "settled", detail });
  const typed = (detail: string): WakeReply => ({ request_id: RID, wait_id: "", outcome: "operator_input", detail });
  /** The child, blocked on the reply it will never get: only `kill()` ends this script. */
  const parkedChild = [emit(parkEntered), emit(wakeRequest([H1])), READ()].join("\n");
  const types = (entries: Record<string, unknown>[]) => entries.map((e) => e.type);

  interface Suspended {
    journal: SessionJournal;
    owner: SuspendedChild;
    rec: ReturnType<typeof recordingFactory>;
    entries: () => Record<string, unknown>[];
    /** The dead `RuntimeProcess` the owner came from — what index.ts still holds in `runtimeProcess`. */
    rp: RuntimeProcess;
  }

  /**
   * A session parked and suspended under `--park-exits`, on Part 4's harness. The journal is
   * SEEDED — an empty seed is enough for `canResume`, which is what `respawnForRestart` reads —
   * journal-class events are routed as `SessionLogger.log` does, the child exits on its first
   * issue, the mirrored exit callback writes no `exit`, and the owner holds the request and the
   * running waiter. Part 4's tests pin all of that; this harness only reaches the owner. Part 6's
   * tests suspend more than once per test: the journal adopts an existing file, so each gets its own id.
   */
  function suspend(sessionId = "sess-p5"): Promise<Suspended> {
    const journal = new SessionJournal(workdir, sessionId, { now: () => 1, onError: (m) => { throw new Error(m); } });
    journal.writeHeader({ sessionId, workdir, profile: "p", model: "m" });
    journal.record({ type: "history_seeded", run_id: `${sessionId}.r0.0`, messages: [], digest: "", digests: [] });
    expect(journal.canResume).toBe(true);
    const bin = path.join(workdir, "fake-ailang.sh");
    fs.writeFileSync(bin, `#!/bin/sh\n${parkedChild}\n`, { mode: 0o755 });
    process.env.AILANG_BIN = bin;
    const rec = recordingFactory();
    const entries = () =>
      fs.readFileSync(journal.filePath, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as Record<string, unknown>);
    return new Promise((resolve) => {
      let rp: RuntimeProcess;
      // eslint-disable-next-line prefer-const
      rp = new RuntimeProcess(
        "task", "http://127.0.0.1:1", "test-model", workdir, "default", 1, "", "", "",
        (e) => { if (isJournalClass(e.type)) journal.record(e as unknown as Record<string, unknown>); },
        () => {
          const owner = rp.suspendedChild;
          if (owner === null) journal.writeExit(journalExitReason(rp.restartPending, false));
          expect(owner).not.toBeNull();
          resolve({ journal, owner: owner!, rec, entries, rp });
        },
        undefined,
        rec.factory,
        true,
      );
    });
  }

  /**
   * index.ts's `respawnForRestart`, as far as a test can hold it: it records that `canResume` held
   * and what was on disk when it was called, and spawns a REAL second `RuntimeProcess` with
   * `{ journalPath }` — whose child is a script that writes the argv it was handed, so the
   * `--resume` assertion is on the argv the child received (harness-dst.test.ts's shape, on a
   * live spawn rather than on `buildSupervisorArgs` alone). `profile` is what `respawnForRestart`
   * reads from the host's `profile` — the `restart` row (Part 6) sets it before respawning.
   */
  function resumeRespawn(journal: SessionJournal, profile = "default") {
    const argvLog = path.join(workdir, "argv.log");
    const bin = path.join(workdir, "fake-resume.sh");
    fs.writeFileSync(bin, `#!/bin/sh\nprintf '%s\\n' "$@" > '${argvLog}'\n`, { mode: 0o755 });
    const calls: { canResume: boolean; onDisk: unknown[] }[] = [];
    let exited: Promise<void> = Promise.resolve();
    const respawn = (): void => {
      const onDisk = fs.readFileSync(journal.filePath, "utf8").split("\n").filter(Boolean)
        .map((l) => (JSON.parse(l) as Record<string, unknown>).type);
      calls.push({ canResume: journal.canResume, onDisk });
      process.env.AILANG_BIN = bin;
      exited = new Promise((resolve) => {
        new RuntimeProcess(
          "", "http://127.0.0.1:1", "test-model", workdir, profile, 1, "", "", "",
          () => {},
          () => resolve(),
          { journalPath: journal.filePath },
        );
      });
    };
    /** The argv the resumed child received; the last element is the (empty) task. */
    const argv = (): string[] => {
      const lines = fs.readFileSync(argvLog, "utf8").split("\n");
      lines.pop(); // the trailing newline
      return lines;
    };
    return { respawn, calls, argv, exited: () => exited };
  }

  // ------------------------------------------------------------------------------------------------
  // PLAN-003 P4 Part 5 (ADR-003 D7, row 6): THE WAKE ENTRY AS THE PARK'S CHILD, AND THE RESPAWN. On
  // the owner's reply the host records `wake_received` — Part 1's routing appends a `wake` whose
  // `parent_id` is the leaf, i.e. the `park` — and respawns through `respawnForRestart`, which
  // passes `--resume <journal>`. Late and duplicate replies are dropped by `request_id`
  // (`sendWakeReply`'s rule, moved with the request to the owner). Red at b660b55: no consumer
  // exists; the owner holds the reply and nothing else happens.
  // ------------------------------------------------------------------------------------------------
  describe("the wake entry and the respawn (PLAN-003 P4 Part 5)", () => {
    it("the waiter's reply: exactly one `wake`, the park's child; the waiter stopped; the respawn carries --resume <journal>", async () => {
      const s = await suspend();
      expect(types(s.entries())).toEqual(["header", "park"]);
      const r = resumeRespawn(s.journal);
      const notified: [WakeReply, boolean][] = [];
      installSuspendedWake(s.owner, {
        stillCurrent: () => true,
        journal: s.journal,
        respawn: r.respawn,
        notify: (reply, written) => notified.push([reply, written]),
      });
      // Installing the consumer writes nothing: no reply is held yet.
      expect(types(s.entries())).toEqual(["header", "park"]);
      expect(r.calls).toHaveLength(0);
      // The waiter replies, to the owner (Part 4).
      s.rec.onReadys[0](settled("answer"));
      await r.exited();
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      const park = entries[1];
      const wake = entries[2];
      // Row 6: the wake is the park's CHILD — `parent_id` is the leaf, and nothing was appended between.
      expect(wake.parent_id).toBe(park.id);
      expect(wake).toMatchObject({ request_id: RID, wait_id: "h1", outcome: "settled", detail: "answer" });
      expect(s.journal.currentLeaf).toBe(wake.id);
      expect(notified).toEqual([[settled("answer"), true]]);
      // The park is answered: the waiter is stopped, as `sendWakeReply` stops it on a live child.
      expect(s.rec.cancels()).toBe(1);
      expect(s.owner.waiter.finished).toBe(true);
      // The respawn: once, AFTER the wake was on disk, while `canResume` held.
      expect(r.calls).toEqual([{ canResume: true, onDisk: ["header", "park", "wake"] }]);
      // Its argv carries `--resume <journal>` (harness-dst.test.ts:132–145's assertion), unforced, task last.
      const argv = r.argv();
      const i = argv.indexOf("--resume");
      expect(i).toBeGreaterThanOrEqual(0);
      expect(argv[i + 1]).toBe(s.journal.filePath);
      expect(argv.indexOf("--resume-force")).toBe(-1);
      expect(argv[argv.length - 1]).toBe("");
      // A second reply — the waiter's again, or a typed line — writes nothing and respawns nothing.
      expect(s.owner.deliver(settled("twice"))).toBe(false);
      s.rec.onReadys[0](settled("again"));
      expect(s.owner.deliver(typed("late line"))).toBe(false);
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(s.journal.currentLeaf).toBe(wake.id);
      expect(r.calls).toHaveLength(1);
      // The fold gate (a small AILANG script, P3 Part 4's shape) reads the file this test wrote:
      //   MOTOKO_P4_JOURNAL_OUT=/tmp/p4-part5.jsonl bun node_modules/.bin/jest src/runtime-process.wake.test.ts
      //   ailang run --caps IO,FS,Env --entry main scripts/fold_parked_journal.ail -- /tmp/p4-part5.jsonl
      const out = process.env.MOTOKO_P4_JOURNAL_OUT;
      if (out) fs.copyFileSync(s.journal.filePath, out);
    });

    it("the operator's line: a `wake(operator_input)` as the park's child, then the respawn", async () => {
      const s = await suspend();
      const r = resumeRespawn(s.journal);
      installSuspendedWake(s.owner, { stillCurrent: () => true, journal: s.journal, respawn: r.respawn });
      // The parked input route delivers to the owner when no child holds the request (Part 4, ui.ts).
      expect(s.owner.deliver(typed("go on"))).toBe(true);
      await r.exited();
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      expect(entries[2].parent_id).toBe(entries[1].id);
      expect(entries[2]).toMatchObject({ request_id: RID, wait_id: "", outcome: "operator_input", detail: "go on" });
      // The delegate's waiter is stopped: the resumed run re-parks on its delegates with a waiter of its own.
      expect(s.rec.cancels()).toBe(1);
      expect(r.calls).toHaveLength(1);
      expect(r.argv().indexOf("--resume")).toBeGreaterThanOrEqual(0);
      // The delegate settling afterwards is a late reply: dropped by the owner, nothing written.
      s.rec.onReadys[0](settled("too late"));
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(r.calls).toHaveLength(1);
    });

    it("a reply held before the consumer is installed is consumed once, at install", async () => {
      const s = await suspend();
      s.rec.onReadys[0](settled("early"));
      expect(s.owner.reply).toEqual(settled("early"));
      // Held, not written: Part 4 writes nothing on it.
      expect(types(s.entries())).toEqual(["header", "park"]);
      const r = resumeRespawn(s.journal);
      installSuspendedWake(s.owner, { stillCurrent: () => true, journal: s.journal, respawn: r.respawn });
      await r.exited();
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      expect(entries[2].parent_id).toBe(entries[1].id);
      expect(entries[2]).toMatchObject({ outcome: "settled", detail: "early" });
      expect(r.calls).toHaveLength(1);
      expect(r.argv()[r.argv().indexOf("--resume") + 1]).toBe(s.journal.filePath);
    });

    it("a reply after a later spawn ended the suspended-child is late: nothing written, no respawn", async () => {
      const s = await suspend();
      const r = resumeRespawn(s.journal);
      // index.ts's guard: the owner is no longer the session's `suspendedChild` (a spawn cleared it).
      // A `wake` written now would follow the new child's entries — a wake answering no open park,
      // which the fold refuses — so the reply is dropped instead.
      installSuspendedWake(s.owner, { stillCurrent: () => false, journal: s.journal, respawn: r.respawn });
      s.rec.onReadys[0](settled("late"));
      await r.exited();
      expect(s.owner.reply).toEqual(settled("late"));
      expect(types(s.entries())).toEqual(["header", "park"]);
      expect(r.calls).toHaveLength(0);
    });
  });

  // ------------------------------------------------------------------------------------------------
  // PLAN-003 P4 Part 6 (ADR-003 D7, row 4; P4-Q5): THE NAMED STATES AND THEIR EXITS. One host test
  // per row of the suspended-child command table, each on the shared harness (a fake child, a
  // recording waiter) with Part 5's consumer installed as index.ts installs it — guarded on the
  // owner being the host's current `suspendedChild`, which the host clears BEFORE it cancels a park
  // (ESC, `restart`) and which a spawn clears. Red at ab9c47e: `abortSuspendedChild`,
  // `SuspendedChild.close`/`isClosed` and `interruptRuntime`'s second parameter do not exist, so the
  // suite does not compile; in the harness shape (the surface present but inert: `close()` returns
  // true and ends nothing, `abortSuspendedChild` writes nothing) rows 3, 4 and 5 are red — ESC
  // returns "none" not "wake_aborted", the restart's abort returns false, quit's cancel count is 0 —
  // and rows 1, 2 and 6 are green, since they pin what Part 5's consumer and the lease hook already do.
  // ------------------------------------------------------------------------------------------------
  describe("the named states and their exits (PLAN-003 P4 Part 6)", () => {
    /** index.ts's installation of Part 5's consumer: the owner is current until the host clears it. */
    function installAsHost(s: Suspended, r: ReturnType<typeof resumeRespawn>) {
      const host = { current: s.owner as SuspendedChild | null };
      installSuspendedWake(s.owner, { stillCurrent: () => host.current === s.owner, journal: s.journal, respawn: r.respawn });
      return host;
    }
    const reply = (outcome: WakeOutcomeName, wait_id: string, detail: string): WakeReply => ({ request_id: RID, wait_id, outcome, detail });

    /** `registerLeaseHooks`'s emitter, as session-lease.test.ts fakes it: `on`, and `fire` by name. */
    class FakeProc implements SignalTarget {
      private readonly handlers = new Map<string, Array<(...a: unknown[]) => void>>();
      on(event: string, listener: (...args: unknown[]) => void): this {
        const list = this.handlers.get(event) ?? [];
        list.push(listener);
        this.handlers.set(event, list);
        return this;
      }
      fire(event: string): void {
        for (const h of this.handlers.get(event) ?? []) h();
      }
    }

    /** index.ts at boot: the lease taken on the session directory, its hooks writing the journal's `exit`. */
    function leaseHooks(s: Suspended, sessionId: string): FakeProc {
      const out = acquireLease(s.journal.dir, sessionId, { pid: process.pid });
      if (out.kind !== "acquired") throw new Error("expected the lease");
      const lease: SessionLease = out.lease;
      const proc = new FakeProc();
      registerLeaseHooks(proc, lease, (reason) => s.journal.writeExit(reason));
      return proc;
    }

    it("row 1 — the waiter replies settled / lost / timed_out / host_error: a wake with that outcome, the park's child, then the respawn", async () => {
      const rows: [WakeOutcomeName, string, string][] = [
        ["settled", "h1", "answer"],
        ["lost", "h1", "pane gone"],
        ["timed_out", "h1", ""],
        ["host_error", "", "wake_read: herdr failed"],
      ];
      for (const [outcome, wait_id, detail] of rows) {
        const s = await suspend(`sess-p6-${outcome}`);
        const r = resumeRespawn(s.journal);
        installAsHost(s, r);
        s.rec.onReadys[0](reply(outcome, wait_id, detail));
        await r.exited();
        const entries = s.entries();
        expect(types(entries)).toEqual(["header", "park", "wake"]);
        expect(entries[2]).toMatchObject({ request_id: RID, wait_id, outcome, detail, parent_id: entries[1].id });
        expect(r.calls).toEqual([{ canResume: true, onDisk: ["header", "park", "wake"] }]);
        expect(r.argv()[r.argv().indexOf("--resume") + 1]).toBe(s.journal.filePath);
        expect(s.rec.cancels()).toBe(1);
        // Answered, not cancelled: ESC after this has no park to cancel and writes nothing.
        expect(s.owner.isClosed).toBe(false);
        expect(abortSuspendedChild(s.owner, s.journal, "abort")).toBe(false);
        expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      }
    });

    it("row 2 — a line at the parked prompt: wake(operator_input), then the respawn; ESC after it cancels nothing", async () => {
      const s = await suspend("sess-p6-op");
      const r = resumeRespawn(s.journal);
      const host = installAsHost(s, r);
      // ui.ts's parked input route delivers to the owner when no child holds the request (Part 4).
      expect(s.owner.deliver(typed("go on"))).toBe(true);
      host.current = null; // the respawn's spawn cleared the host's `suspendedChild`
      await r.exited();
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      expect(entries[2]).toMatchObject({ request_id: RID, wait_id: "", outcome: "operator_input", detail: "go on", parent_id: entries[1].id });
      expect(r.calls).toHaveLength(1);
      expect(s.rec.cancels()).toBe(1);
      // The two typed-input rows differ by entry condition alone: this park is answered, so an ESC
      // reaching the owner now (it cannot, index.ts cleared it — the control is on the function)
      // finds nothing to cancel.
      expect(interruptRuntime(s.rp, { owner: s.owner, journal: s.journal })).toBe("none");
      expect(s.owner.isClosed).toBe(false);
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(r.calls).toHaveLength(1);
    });

    it("row 3 — ESC: exactly one wake(aborted, \"abort\") as the park's child; the waiter stopped; NO respawn; later replies dropped; the next prompt resumes", async () => {
      const s = await suspend("sess-p6-esc");
      const r = resumeRespawn(s.journal);
      const host = installAsHost(s, r);
      // index.ts's onInterrupt: the owner is cleared FIRST, then ESC goes through interruptRuntime
      // with it; `interrupted` is not set (no child exits on this row).
      host.current = null;
      expect(interruptRuntime(s.rp, { owner: s.owner, journal: s.journal })).toBe("wake_aborted");
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      const park = entries[1];
      const wake = entries[2];
      expect(wake.parent_id).toBe(park.id);
      expect(wake).toMatchObject({ request_id: RID, wait_id: "abort", outcome: "aborted", detail: "" });
      expect(s.journal.currentLeaf).toBe(wake.id);
      // The park is closed on the host's side: the waiter is stopped, the owner accepts nothing more.
      expect(s.owner.isClosed).toBe(true);
      expect(s.rec.cancels()).toBe(1);
      expect(s.owner.waiter.finished).toBe(true);
      // NO respawn — not Part 5's consumer's (its owner is no longer current), not anyone's.
      expect(r.calls).toHaveLength(0);
      // A second ESC, the waiter's late reply and a typed line: all dropped, nothing written.
      expect(interruptRuntime(s.rp, { owner: s.owner, journal: s.journal })).toBe("none");
      s.rec.onReadys[0](settled("late"));
      expect(s.owner.deliver(typed("late line"))).toBe(false);
      expect(s.owner.reply).toBeNull();
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(s.journal.currentLeaf).toBe(wake.id);
      expect(r.calls).toHaveLength(0);
      // ESC without an owner is HEAD's ESC: a kill, which a dead child ignores. Nothing written.
      expect(interruptRuntime(s.rp)).toBe("kill");
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      // The session stays resumable, and the next prompt's `onInitialTask` respawns through
      // `respawnForRestart` with `--resume <journal>`: the child folds `park, wake(aborted)` to
      // `Open("wake:aborted")` (P4-Q4; the fold gate below) and reads the prompt as its next turn.
      expect(s.journal.canResume).toBe(true);
      r.respawn();
      await r.exited();
      expect(r.calls).toEqual([{ canResume: true, onDisk: ["header", "park", "wake"] }]);
      expect(r.argv()[r.argv().indexOf("--resume") + 1]).toBe(s.journal.filePath);
      // The fold gate (Part 5's script) on this file prints `NOT PARKED last=open:wake:aborted`:
      //   MOTOKO_P4_JOURNAL_OUT_ESC=/tmp/p4-part6-esc.jsonl bun node_modules/.bin/jest src/runtime-process.wake.test.ts
      //   ailang run --caps IO,FS,Env --entry main scripts/fold_parked_journal.ail -- /tmp/p4-part6-esc.jsonl
      const out = process.env.MOTOKO_P4_JOURNAL_OUT_ESC;
      if (out) fs.copyFileSync(s.journal.filePath, out);
    });

    it("row 4 — restart to profile q: wake(aborted, \"restart:q\") as the park's child; the waiter stopped; then the respawn on the new profile with --resume", async () => {
      const s = await suspend("sess-p6-restart");
      const r5 = resumeRespawn(s.journal); // Part 5's consumer's respawn: must not fire on this row
      const host = installAsHost(s, r5);
      // index.ts's onRestart: the owner cleared, the profile set, the cancel written, then
      // `respawnForRestart` on the new profile.
      host.current = null;
      expect(abortSuspendedChild(s.owner, s.journal, "restart:q")).toBe(true);
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "wake"]);
      expect(entries[2]).toMatchObject({ request_id: RID, wait_id: "restart:q", outcome: "aborted", detail: "", parent_id: entries[1].id });
      expect(s.owner.isClosed).toBe(true);
      expect(s.rec.cancels()).toBe(1);
      expect(r5.calls).toHaveLength(0);
      const r6 = resumeRespawn(s.journal, "q");
      r6.respawn();
      await r6.exited();
      expect(r6.calls).toEqual([{ canResume: true, onDisk: ["header", "park", "wake"] }]);
      const argv = r6.argv();
      expect(argv[argv.indexOf("--profile") + 1]).toBe("q");
      expect(argv[argv.indexOf("--resume") + 1]).toBe(s.journal.filePath);
      expect(argv.indexOf("--resume-force")).toBe(-1);
      // The delegate settling afterwards is late: dropped by the closed owner, nothing written,
      // and Part 5's consumer still never respawned.
      s.rec.onReadys[0](settled("too late"));
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(r5.calls).toHaveLength(0);
    });

    it("row 5 — quit: NO wake; the waiter ended; the lease hook writes exit(host_exit) after the park; the session stays resumable", async () => {
      const s = await suspend("sess-p6-quit");
      const r = resumeRespawn(s.journal);
      installAsHost(s, r);
      const proc = leaseHooks(s, "sess-p6-quit");
      // index.ts's onAbort with a dead runtime: end the owner's waiter, stop the UI, process.exit(0)
      // — whose `exit` listener is the lease hook's, registered at boot with the journal's writeExit.
      expect(s.owner.close()).toBe(true);
      expect(s.rec.cancels()).toBe(1);
      expect(types(s.entries())).toEqual(["header", "park"]);
      proc.fire("exit");
      const entries = s.entries();
      expect(types(entries)).toEqual(["header", "park", "exit"]);
      expect(entries[2]).toMatchObject({ reason: "host_exit", parent_id: entries[1].id });
      expect(r.calls).toHaveLength(0);
      // Row 5: `park → exit` folds to `Parked(req, None)` and is re-observed on resume — so the
      // journal still resumes, and it is the RESUMED child's waiter that wakes `lost` if the
      // delegates were reaped meanwhile. This host writes nothing after its exit.
      expect(s.journal.canResume).toBe(true);
      s.rec.onReadys[0](settled("never"));
      expect(s.owner.deliver(typed("never"))).toBe(false);
      expect(types(s.entries())).toEqual(["header", "park", "exit"]);
      expect(r.calls).toHaveLength(0);
      // The fold gate on this file prints `PARKED(p, None) -- no wake: re-observed on resume`:
      //   MOTOKO_P4_JOURNAL_OUT_QUIT=/tmp/p4-part6-quit.jsonl bun node_modules/.bin/jest src/runtime-process.wake.test.ts
      const out = process.env.MOTOKO_P4_JOURNAL_OUT_QUIT;
      if (out) fs.copyFileSync(s.journal.filePath, out);
    });

    it("row 6 — host death: SIGINT writes exit(abort), SIGTERM exit(host_exit); no wake; as quit", async () => {
      for (const [signal, reason] of [["SIGINT", "abort"], ["SIGTERM", "host_exit"]] as const) {
        const id = `sess-p6-${signal.toLowerCase()}`;
        const s = await suspend(id);
        const r = resumeRespawn(s.journal);
        installAsHost(s, r);
        const proc = leaseHooks(s, id);
        proc.fire(signal);
        // ui.ts also routes SIGINT to onAbort, which ends in process.exit(0): a second, consecutive
        // `exit` is suppressed by the journal, so the boundary carries the SIGNAL's reason.
        proc.fire("exit");
        const entries = s.entries();
        expect(types(entries)).toEqual(["header", "park", "exit"]);
        expect(entries[2]).toMatchObject({ reason, parent_id: entries[1].id });
        expect(r.calls).toHaveLength(0);
        expect(s.journal.canResume).toBe(true);
      }
    });
  });

  // ------------------------------------------------------------------------------------------------
  // PLAN-003 P4 Part 7 (ADR-003 D7): NO WAKE FILE, NO GENERATION. T0 — after Part 5's flow, run
  // under the lease the host takes (`acquireLease(journal.dir, sessionId)`, index.ts), the session
  // directory holds `journal.jsonl` and `lease` and nothing else, at every point: parked and
  // suspended, after the wake, after the `--resume` respawn, and after the lease is released. The
  // wake travels as the `park`'s child entry; the resumed child folds it once, because the
  // `run_started` that follows it closes the park (the `park_resume` target's second-resume rows).
  // The other half of T0 is the shell check the plan names and §5 records: a case-insensitive
  // `git grep` over `src/core` and `src/tui/src` for the generation type's name, its field's name
  // and the name of a file that would hold a wake finds nothing. (None is spelled here, so this file is not
  // the grep's one hit.)
  // ------------------------------------------------------------------------------------------------
  describe("no wake file, no generation (PLAN-003 P4 Part 7, T0)", () => {
    /** Every name under `dir`, recursively, relative to it. */
    function walk(dir: string, prefix = ""): string[] {
      const out: string[] = [];
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const rel = path.join(prefix, entry.name);
        out.push(rel);
        if (entry.isDirectory()) out.push(...walk(path.join(dir, entry.name), rel));
      }
      return out.sort();
    }

    it("the session directory is journal.jsonl + lease — parked, woken, respawned, released", async () => {
      const id = "sess-p7";
      const s = await suspend(id);
      const dir = s.journal.dir;
      const listing = () => fs.readdirSync(dir).sort();
      // Suspended-child, before the host's lease: the journal alone (the harness takes none).
      expect(listing()).toEqual(["journal.jsonl"]);
      const outcome = acquireLease(dir, id);
      expect(outcome.kind).toBe("acquired");
      const lease = (outcome as { kind: "acquired"; lease: SessionLease }).lease;
      expect(listing()).toEqual(["journal.jsonl", "lease"]);
      // Part 5's flow: the reply, the wake as the park's child, the `--resume` respawn.
      const r = resumeRespawn(s.journal);
      installSuspendedWake(s.owner, { stillCurrent: () => true, journal: s.journal, respawn: r.respawn, notify: () => {} });
      expect(listing()).toEqual(["journal.jsonl", "lease"]);
      s.rec.onReadys[0](settled("answer"));
      await r.exited();
      expect(types(s.entries())).toEqual(["header", "park", "wake"]);
      expect(r.calls).toEqual([{ canResume: true, onDisk: ["header", "park", "wake"] }]);
      expect(listing()).toEqual(["journal.jsonl", "lease"]);
      // The whole sessions tree: this session, and no name that says wake or generation.
      const sessions = path.join(workdir, ".motoko", "sessions");
      expect(fs.readdirSync(sessions)).toEqual([id]);
      const names = walk(sessions);
      expect(names).toEqual([id, path.join(id, "journal.jsonl"), path.join(id, "lease")]);
      expect(names.filter((n) => /wake|generation/i.test(n))).toEqual([]);
      // The lease goes with the host; the journal is what the next `--resume` reads.
      lease.release();
      expect(listing()).toEqual(["journal.jsonl"]);
      expect(s.journal.canResume).toBe(true);
    });
  });
});
