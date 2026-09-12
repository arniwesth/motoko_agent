/**
 * THE SESSION LEASE — ADR-003 v6.1 D3, host-only.
 *
 * `.motoko/sessions/<session_id>/lease`, holding `{ owner_pid, session_id, acquired_at_ms }`,
 * written with an atomic rename and held for the whole session — across every respawn, because a
 * `/restart` and a model switch are the same session with the same journal.
 *
 * WHAT IT PROTECTS. D3's design has exactly ONE writer for a journal. Two Motokos on one session
 * id would both append to `journal.jsonl` with their own in-memory `seq` and leaf, and the result
 * is not a corrupt file — it is a PLAUSIBLE file with two interleaved chains, which folds to a
 * history neither process ever had. The lease is what makes "one writer" checkable before the
 * first byte instead of inferable after the fact.
 *
 * THE CHILD NEVER TOUCHES IT (PLAN-003 §0.8). The child writes no file in any phase; hostless runs
 * — `rpc.main` directly, the eval harness, the PLAN-003 probe — take no lease, exactly as they
 * keep no log today.
 *
 * WHY THE SIGNAL HANDLERS DO NOT RE-RAISE, unlike `herdr-agent-state.ts`'s, which deliberately do.
 * The herdr reporter re-raises so that handing lifecycle authority back does not CHANGE how Motoko
 * dies. This one is registered before it and must not: re-raising here kills the process before
 * the herdr release, the exit-actions dispatch and the journal's `exit` entry have run, and a
 * SIGINT would then leave both a stale lease's siblings and a journal with no boundary. Releasing
 * and returning lets the listeners registered after this one do their work, and the LAST of them
 * re-raises. One handler in the chain owns the disposition; it is not this one.
 */

import * as fs from "fs";
import * as path from "path";

export interface LeaseRecord {
  owner_pid: number;
  session_id: string;
  acquired_at_ms: number;
}

export type LeaseOutcome =
  | { kind: "acquired"; lease: SessionLease }
  | { kind: "refused"; heldBy: LeaseRecord };

/**
 * The Linux process state letter from `/proc/<pid>/stat` (`R`, `S`, `Z`, …), or null where there is
 * no procfs or no such process. The state follows the LAST `)`, because the command name between
 * the parentheses may itself contain spaces and parentheses.
 */
export function readProcState(pid: number): string | null {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
    const state = stat.slice(stat.lastIndexOf(")") + 1).trim().charAt(0);
    return state === "" ? null : state;
  } catch {
    return null;
  }
}

/**
 * Is a pid a live process that could still write the journal? Signal 0 tests existence without
 * delivering one — and a ZOMBIE EXISTS: it answers signal 0 until something reaps it.
 *
 * THAT IS NOT HYPOTHETICAL HERE. This container's PID 1 is `sleep infinity`, which reaps nothing, so
 * a Motoko whose parent chain is gone when it dies stays `<defunct>` forever (200 of them on
 * 2026-09-12). Closing the pane of a running Motoko did exactly that: the TUI died without its exit
 * hooks, its lease stayed, and every restart on that session id was refused as "already held by"
 * a process that could never write again — the crash the stale-lease rule exists to recover from,
 * made unrecoverable. A zombie or dead (`Z`/`X`) owner is gone. Where there is no procfs the state
 * is unknown and signal 0 decides, as before.
 */
function pidAlive(
  pid: number,
  kill: (pid: number, signal: number) => void,
  procState: (pid: number) => string | null = readProcState,
): boolean {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  let exists: boolean;
  try {
    kill(pid, 0);
    exists = true;
  } catch (e) {
    // EPERM means the process EXISTS and belongs to someone else — a live owner this process may
    // not signal is still a live owner, and reading it as "gone" is how a second writer gets in.
    exists = (e as NodeJS.ErrnoException)?.code === "EPERM";
  }
  if (!exists) return false;
  const state = procState(pid);
  return state !== "Z" && state !== "X";
}

export function readLease(leasePath: string): LeaseRecord | null {
  let raw: string;
  try {
    raw = fs.readFileSync(leasePath, "utf8");
  } catch {
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as Partial<LeaseRecord>;
    if (typeof parsed?.owner_pid !== "number" || typeof parsed?.session_id !== "string") return null;
    return {
      owner_pid: parsed.owner_pid,
      session_id: parsed.session_id,
      acquired_at_ms: typeof parsed.acquired_at_ms === "number" ? parsed.acquired_at_ms : 0,
    };
  } catch {
    // An unparseable lease is a lease whose owner cannot be established. It is treated as STALE
    // rather than as held: a file this process cannot read the pid out of would otherwise lock the
    // session out forever, and the thing being protected is a live writer, not a file.
    return null;
  }
}

export class SessionLease {
  readonly filePath: string;
  readonly sessionId: string;
  /** The pid written into the record. Carried rather than read from `process` so the release's
   *  ownership check compares against what was actually acquired — a test that injects a pid would
   *  otherwise acquire as one owner and refuse to release as another. */
  readonly ownerPid: number;
  private released = false;

  constructor(leasePath: string, sessionId: string, ownerPid: number) {
    this.filePath = leasePath;
    this.sessionId = sessionId;
    this.ownerPid = ownerPid;
  }

  /** Idempotent: several exit paths reach it, and a second release could unlink a successor's. */
  release(): void {
    if (this.released) return;
    this.released = true;
    // Only unlink a lease this process still owns. Between the acquire and the exit a `kill -9`
    // and a forced takeover can have handed the session to someone else, and deleting THEIR lease
    // is the failure this guard exists for.
    const held = readLease(this.filePath);
    if (held && held.owner_pid !== this.ownerPid) return;
    try {
      fs.rmSync(this.filePath, { force: true });
    } catch {
      // A stale lease is recovered by the next acquire's liveness check. Never fail an exit.
    }
  }

  get isReleased(): boolean {
    return this.released;
  }
}

export interface AcquireOptions {
  /** Take the lease even when a live owner holds it. `--resume-force`'s reach, D5. */
  force?: boolean;
  now?: () => number;
  pid?: number;
  kill?: (pid: number, signal: number) => void;
  /** The owner's process state letter; `readProcState` by default. A `Z`/`X` owner is gone. */
  procState?: (pid: number) => string | null;
}

/**
 * Acquire the session's lease, or refuse.
 *
 * The refusal is the `Leased` half of D5's compatibility rows: a second TUI on one session id
 * finds a live owner and is told whose. A STALE lease — the owner is gone, which is what `kill -9`
 * leaves — is taken over silently, because refusing there would mean a crashed session could never
 * be resumed, and resuming a crashed session is the second judging number.
 *
 * Written tmp-then-renamed for the same reason every other publish in this tree is: a reader
 * either sees the previous owner or this one, never a half-written record with no pid.
 */
export function acquireLease(
  dir: string,
  sessionId: string,
  options: AcquireOptions = {},
): LeaseOutcome {
  const leasePath = path.join(dir, "lease");
  const pid = options.pid ?? process.pid;
  const kill = options.kill ?? ((p, s) => process.kill(p, s));
  const held = readLease(leasePath);
  if (
    held &&
    held.owner_pid !== pid &&
    pidAlive(held.owner_pid, kill, options.procState ?? readProcState) &&
    options.force !== true
  ) {
    return { kind: "refused", heldBy: held };
  }
  const record: LeaseRecord = {
    owner_pid: pid,
    session_id: sessionId,
    acquired_at_ms: (options.now ?? Date.now)(),
  };
  const tmp = `${leasePath}.${pid}.tmp`;
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  fs.writeFileSync(tmp, `${JSON.stringify(record)}\n`, { mode: 0o600 });
  fs.renameSync(tmp, leasePath);
  return { kind: "acquired", lease: new SessionLease(leasePath, sessionId, pid) };
}

/** What `registerLeaseHooks` needs of `process`. A fake supplies exactly this and nothing else. */
export interface SignalTarget {
  on(event: string, listener: (...args: unknown[]) => void): unknown;
}

export interface LeaseHookRegistration {
  /** In registration order, which is the order Node runs them in. */
  events: string[];
}

/**
 * Register the lease's OWN `exit`, `SIGINT` and `SIGTERM` listeners, in that order.
 *
 * `proc` IS A PARAMETER rather than `process` read from the module, and that is the whole test
 * mechanism (PLAN-003 P3 Part 4). What has to be asserted about these handlers is behaviour a real
 * process cannot be asked for without ending the test run: that they are registered in the right
 * order relative to the exit-actions dispatch and the herdr release; that the `SIGINT` handler
 * RETURNS instead of re-raising, so the listeners after it still run; and that the `exit` handler
 * starts no asynchronous work, because an async write inside an `exit` listener never runs. A fake
 * emitter records the first, calls the handlers for the second, and lets the third be asserted by
 * watching what the handler did by the time it returned.
 *
 * `onExit` runs before the release — the journal's `exit` entry is written while the session is
 * still this process's, which is also the order an operator would expect to read them back in.
 */
export function registerLeaseHooks(
  proc: SignalTarget,
  lease: SessionLease,
  onExit?: (reason: string) => void,
): LeaseHookRegistration {
  const events: string[] = [];
  const finish = (reason: string): void => {
    try {
      if (onExit) onExit(reason);
    } catch {
      // The release must happen even if the journal could not be written. A held lease outlives a
      // missing entry: the first blocks the next session, the second only costs it a boundary.
    }
    lease.release();
  };
  proc.on("exit", () => finish("host_exit"));
  events.push("exit");
  for (const signal of ["SIGINT", "SIGTERM"]) {
    proc.on(signal, () => {
      finish(signal === "SIGINT" ? "abort" : "host_exit");
      // NO RE-RAISE. See the file header: the listeners registered after this one still have work
      // to do, and the herdr reporter's handler is the one that owns how Motoko dies.
    });
    events.push(signal);
  }
  return { events };
}
