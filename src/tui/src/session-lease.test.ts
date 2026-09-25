import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  acquireLease,
  readLease,
  registerLeaseHooks,
  SessionLease,
  type SignalTarget,
} from "./session-lease.js";
import { SessionJournal } from "./session-journal.js";

// ADR-003 v6.1 D3's lease, host-only.
//
// The handlers are the part that cannot be tested against a real `process` without ending the test
// run, and they are also the part where a mistake is silent: a lease released too eagerly hands the
// session to a second writer, one released too late locks the next session out, and a signal
// handler that re-raises kills the process before the listeners registered after it have run. So
// `registerLeaseHooks` takes its emitter as a PARAMETER and a fake supplies it.

let root: string;

beforeEach(() => {
  root = fs.mkdtempSync(path.join(os.tmpdir(), "motoko-lease-"));
});

afterEach(() => {
  fs.rmSync(root, { recursive: true, force: true });
});

/**
 * The fake emitter. It records registration ORDER — which is the order Node runs listeners in, and
 * therefore the whole content of "registered between `initExitActions()` and `initHerdrReporter()`"
 * — and it lets a handler be fired by name.
 */
class FakeProc implements SignalTarget {
  readonly registered: string[] = [];
  private readonly handlers = new Map<string, Array<(...a: unknown[]) => void>>();
  /** Anything a handler did that a real process would have found fatal. */
  readonly killed: Array<{ pid: number; signal: string }> = [];

  on(event: string, listener: (...args: unknown[]) => void): this {
    this.registered.push(event);
    const list = this.handlers.get(event) ?? [];
    list.push(listener);
    this.handlers.set(event, list);
    return this;
  }

  fire(event: string): unknown {
    let last: unknown;
    for (const h of this.handlers.get(event) ?? []) last = h();
    return last;
  }

  kill(pid: number, signal: string): void {
    this.killed.push({ pid, signal });
  }
}

describe("acquiring and refusing the lease", () => {
  it("writes owner_pid, session_id and acquired_at_ms, and leaves no temporary file", () => {
    const out = acquireLease(root, "sess-1", { pid: 4242, now: () => 1756000000000 });
    expect(out.kind).toBe("acquired");
    expect(readLease(path.join(root, "lease"))).toEqual({
      owner_pid: 4242,
      session_id: "sess-1",
      acquired_at_ms: 1756000000000,
    });
    // Atomic via rename (D3), asserted through its consequence: no reader can be handed a
    // half-written record with no pid, because no such file ever exists at a name.
    expect(fs.readdirSync(root).filter((f) => f.endsWith(".tmp"))).toEqual([]);
  });

  // D5's `Leased` row. Two Motokos on one session id would both append to one `journal.jsonl` with
  // their own `seq` and leaf, and the result is not a corrupt file but a PLAUSIBLE one that folds
  // to a history neither process ever had.
  it("refuses a second holder while the first is alive, and names it", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    const second = acquireLease(root, "sess-1", { pid: 1002, kill: () => {} });
    expect(second.kind).toBe("refused");
    if (second.kind === "refused") expect(second.heldBy.owner_pid).toBe(1001);
  });

  // A STALE lease is the shape `kill -9` leaves, and refusing there would mean a crashed session
  // could never be resumed — which is the second judging number.
  it("takes over a lease whose owner is gone", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    const second = acquireLease(root, "sess-1", {
      pid: 1002,
      kill: () => {
        const e = new Error("no such process") as NodeJS.ErrnoException;
        e.code = "ESRCH";
        throw e;
      },
    });
    expect(second.kind).toBe("acquired");
    expect(readLease(path.join(root, "lease"))!.owner_pid).toBe(1002);
  });

  // A ZOMBIE answers signal 0 until something reaps it, and this container's PID 1 (`sleep infinity`)
  // reaps nothing. A Motoko whose pane was closed died as a zombie on 2026-09-12 and its session
  // could not be resumed: every restart was refused as "already held by" the dead pid.
  it("takes over a lease whose owner is a zombie, even though signal 0 still finds it", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    const second = acquireLease(root, "sess-1", { pid: 1002, kill: () => {}, procState: () => "Z" });
    expect(second.kind).toBe("acquired");
    expect(readLease(path.join(root, "lease"))!.owner_pid).toBe(1002);
    acquireLease(root, "sess-2", { pid: 2001 });
    expect(acquireLease(root, "sess-2", { pid: 2002, kill: () => {}, procState: () => "X" }).kind).toBe("acquired");
  });

  it("still refuses a running or sleeping owner, and falls back to signal 0 without procfs", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    for (const state of ["R", "S", "D", null]) {
      expect(acquireLease(root, "sess-1", { pid: 1002, kill: () => {}, procState: () => state }).kind).toBe("refused");
    }
  });

  // EPERM means the process EXISTS and belongs to someone else. Reading that as "gone" is exactly
  // how a second writer gets in.
  it("treats a live owner it may not signal as live", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    const second = acquireLease(root, "sess-1", {
      pid: 1002,
      kill: () => {
        const e = new Error("operation not permitted") as NodeJS.ErrnoException;
        e.code = "EPERM";
        throw e;
      },
    });
    expect(second.kind).toBe("refused");
  });

  // `--resume-force`'s reach, D5: it overrides the extension set and the system prompt, and it
  // overrides NEITHER the workdir NOR the lease — except where the operator asks for the lease
  // itself, which is the kill-the-first-TUI recovery the manual gate exercises.
  it("takes a live owner's lease when forced", () => {
    acquireLease(root, "sess-1", { pid: 1001 });
    const forced = acquireLease(root, "sess-1", { pid: 1002, force: true, kill: () => {} });
    expect(forced.kind).toBe("acquired");
    expect(readLease(path.join(root, "lease"))!.owner_pid).toBe(1002);
  });

  // A file this process cannot read a pid out of would otherwise lock the session out forever, and
  // what is being protected is a LIVE WRITER, not a file.
  it("treats an unparseable lease as stale", () => {
    fs.writeFileSync(path.join(root, "lease"), "not json at all\n");
    expect(acquireLease(root, "sess-1", { pid: 7 }).kind).toBe("acquired");
  });

  it("re-acquires its own lease without refusing itself", () => {
    acquireLease(root, "sess-1", { pid: 99 });
    expect(acquireLease(root, "sess-1", { pid: 99, kill: () => {} }).kind).toBe("acquired");
  });
});

describe("releasing the lease", () => {
  it("removes the file, and is idempotent", () => {
    const out = acquireLease(root, "sess-1", { pid: 4242 });
    if (out.kind !== "acquired") throw new Error("expected the lease");
    out.lease.release();
    expect(fs.existsSync(path.join(root, "lease"))).toBe(false);
    expect(() => out.lease.release()).not.toThrow();
  });

  // Between the acquire and the exit a `kill -9` and a forced takeover can have handed the session
  // to someone else. Deleting THEIR lease is the failure this guard exists for — and it is the one
  // an idempotency flag alone would not catch, because this process really does release once.
  it("does not remove a lease a successor has taken", () => {
    const out = acquireLease(root, "sess-1", { pid: process.pid });
    if (out.kind !== "acquired") throw new Error("expected the lease");
    acquireLease(root, "sess-1", { pid: process.pid + 1, force: true, kill: () => {} });
    out.lease.release();
    expect(readLease(path.join(root, "lease"))!.owner_pid).toBe(process.pid + 1);
  });
});

describe("registerLeaseHooks, against a fake emitter", () => {
  const lease = (): SessionLease => {
    const out = acquireLease(root, "sess-1", { pid: process.pid });
    if (out.kind !== "acquired") throw new Error("expected the lease");
    return out.lease;
  };

  // REGISTRATION ORDER IS THE CONTRACT. Node runs listeners in registration order, so "between
  // `initExitActions()` and `initHerdrReporter()`" means: the exit-actions dispatch has already
  // run, and the herdr release — whose own signal handler RE-RAISES — has not. Three listeners,
  // `exit` first.
  it("registers exit, SIGINT and SIGTERM, in that order", () => {
    const proc = new FakeProc();
    const reg = registerLeaseHooks(proc, lease());
    expect(proc.registered).toEqual(["exit", "SIGINT", "SIGTERM"]);
    expect(reg.events).toEqual(["exit", "SIGINT", "SIGTERM"]);
  });

  // NOT RE-RAISING is the difference from `herdr-agent-state.ts`, which deliberately does. Re-raise
  // here and the process dies before the herdr release, the exit-actions dispatch and the journal's
  // `exit` entry have run — a SIGINT would leave a journal with no boundary.
  it("returns from SIGINT without killing the process", () => {
    const proc = new FakeProc();
    const l = lease();
    registerLeaseHooks(proc, l);
    proc.fire("SIGINT");
    expect(proc.killed).toEqual([]);
    expect(l.isReleased).toBe(true);
  });

  it("returns from SIGTERM without killing the process", () => {
    const proc = new FakeProc();
    const l = lease();
    registerLeaseHooks(proc, l);
    proc.fire("SIGTERM");
    expect(proc.killed).toEqual([]);
    expect(l.isReleased).toBe(true);
  });

  // THE EXIT HANDLER DOES NO ASYNCHRONOUS WORK. An async write started inside an `exit` listener
  // never runs — the event loop is already closed — which is why the journal's append is
  // `appendFileSync` and the herdr release is `spawnSync`. Asserted two ways, because "returns
  // undefined" alone would pass for a handler that started a write and forgot it: the handler
  // returns no thenable, and the entry it wrote is ON DISK the moment it returns.
  it("writes the exit entry synchronously and returns nothing to await", () => {
    const proc = new FakeProc();
    const journal = new SessionJournal(root, "sess-1", { now: () => 1, onError: () => {} });
    journal.writeHeader({ sessionId: "sess-1", workdir: "/w", profile: "p", model: "m" });
    journal.record({ type: "session_start", run_id: "r0" });
    registerLeaseHooks(proc, lease(), (reason) => journal.writeExit(reason));

    const returned = proc.fire("exit");
    expect(returned).toBeUndefined();
    const written = fs.readFileSync(journal.filePath, "utf8").trim().split("\n").map((l) => JSON.parse(l));
    expect(written.pop()).toMatchObject({ type: "exit", reason: "host_exit" });
  });

  // SIGINT is the operator's interrupt, and D1 gives it its own reason. `abort` and `restart` are
  // the same entry with their reason — that is what replaced v4.1's two metadata rewrites.
  it("names a SIGINT exit abort and an exit-listener exit host_exit", () => {
    const reasons: string[] = [];
    const proc = new FakeProc();
    registerLeaseHooks(proc, lease(), (r) => reasons.push(r));
    proc.fire("SIGINT");
    proc.fire("exit");
    expect(reasons).toEqual(["abort", "host_exit"]);
  });

  // The release must happen even when the journal could not be written. A held lease outlives a
  // missing entry: the first blocks the next session, the second only costs it a boundary.
  it("releases the lease even when the exit entry throws", () => {
    const proc = new FakeProc();
    const l = lease();
    registerLeaseHooks(proc, l, () => {
      throw new Error("disk full");
    });
    expect(() => proc.fire("exit")).not.toThrow();
    expect(l.isReleased).toBe(true);
    expect(fs.existsSync(path.join(root, "lease"))).toBe(false);
  });
});
