/**
 * wake-waiter — the host's observations for one outstanding `wake_request` (ADR-002 D2, PLAN-002
 * W4 Part 5).
 *
 * The core parks on `[WaitDescriptor]` and asks the host which one is ready. This module races one
 * observer per wait, and the first ready one is sent back as a `wake_reply`. It implements the
 * ADR's observations and nothing more:
 *
 *   - DelegateWait, answer: a FILE observation. Initial read, subscribe, re-read, so an answer
 *     published before the subscription cannot be missed. First non-empty content is `settled`
 *     (sound only because D1 publishes atomically).
 *   - DelegateWait, state: a REGISTERED-START observation. Wait for the herdr agent row to exist
 *     (the extension returns before it does), then:
 *       - claude/codex: `herdr agent wait <target> --until idle --until done --until blocked`.
 *         A default-wait success is NEVER an answer: it only triggers an answer re-read.
 *       - motoko one-shot: the row disappearing AFTER it was seen, then an answer re-read
 *         (content -> `settled`, none -> `lost`).
 *   - A herdr transport failure (spawn error, non-zero exit other than `agent_not_found`,
 *     unparseable output) is `host_error`, NEVER `lost` — the extension separates these at
 *     `herdr.ail`'s `means_agent_gone`, and the host does too.
 *   - TimerWait: a timer to `deadline_ms` -> `timed_out`.
 *   - OperatorWait: nothing here. Only the TUI's parked input route answers it.
 *
 * Readiness is collected per macrotask and reported in `waits` order, so two handles ready at once
 * resolve to the earlier one; the rest stay open in the core. Cancelling the handle (on wake, abort,
 * runtime exit) kills every herdr child, clears every timer and closes every subscription.
 *
 * Everything with a side effect is injected (`WaiterDeps`), so tests need neither herdr nor a clock.
 */

import { spawn, type ChildProcess } from "child_process";
import * as fs from "fs";
import * as path from "path";

export interface DelegateWait {
  id: string;
  delegate_kind: string;
  locator: { pane: string };
  answer_path: string;
  run_key: string;
}
export interface OperatorWait {
  id: string;
}
export interface TimerWait {
  id: string;
  deadline_ms: number;
}
export type WaitDescriptor = DelegateWait | OperatorWait | TimerWait;

/** The core's `wake_request` line (not a ledger event). */
export interface WakeRequest {
  type: "wake_request";
  request_id: string;
  step: number;
  attempt: number;
  waits: WaitDescriptor[];
}

export type WakeOutcomeName = "settled" | "lost" | "operator_input" | "timed_out" | "host_error";

/** The host's `wake_reply` line, minus its `type`. */
export interface WakeReply {
  request_id: string;
  wait_id: string;
  outcome: WakeOutcomeName;
  detail: string;
}

export type WaitKind = "delegate" | "operator" | "timer";

export function waitKind(w: WaitDescriptor): WaitKind {
  const rec = w as unknown as Record<string, unknown>;
  if (typeof rec.deadline_ms === "number") return "timer";
  if (typeof rec.answer_path === "string" || typeof rec.delegate_kind === "string") return "delegate";
  return "operator";
}

/** One herdr CLI call's result. `spawnError` is set when the binary could not be run at all. */
export interface HerdrResult {
  code: number;
  stdout: string;
  stderr: string;
  spawnError?: string;
}

export type HerdrRunner = (argv: string[], signal: AbortSignal) => Promise<HerdrResult>;

export interface WaiterDeps {
  herdr: HerdrRunner;
  /** The answer file's content, or null when it is absent, unreadable or empty. */
  readAnswer: (answerPath: string) => string | null;
  /** Subscribe to changes of the answer file; returns the unsubscribe. */
  watchAnswer: (answerPath: string, onChange: () => void) => () => void;
  now: () => number;
  setTimer: (fn: () => void, ms: number) => () => void;
  /** Schedules the readiness flush; batching per macrotask is what makes `waits` order hold. */
  defer: (fn: () => void) => void;
  /** Interval between `agent get` polls while waiting for a row to appear or disappear. */
  pollMs: number;
}

export interface WakeWaiterHandle {
  cancel(): void;
  readonly finished: boolean;
}

export type WakeWaiterFactory = (req: WakeRequest, onReady: (reply: WakeReply) => void) => WakeWaiterHandle;

// ------------------------------------------------------------------------------------------------
// herdr failure vocabulary — the TS twin of `types.ail`'s `failure_code` / `means_agent_gone`.
// ------------------------------------------------------------------------------------------------

/** herdr's JSON `error.code` from stderr, "" on success, `herdr_cli_rejected` when stderr is not herdr JSON. */
export function herdrFailureCode(r: HerdrResult): string {
  if (r.spawnError !== undefined) return "spawn_error";
  if (r.code === 0) return "";
  if (r.code === 2) return "cli_syntax";
  try {
    const parsed = JSON.parse(r.stderr.trim()) as { error?: { code?: unknown } };
    const c = parsed?.error?.code;
    return typeof c === "string" && c !== "" ? c : "herdr_json_undecodable";
  } catch {
    return "herdr_cli_rejected";
  }
}

export function herdrMeansAgentGone(r: HerdrResult): boolean {
  return herdrFailureCode(r) === "agent_not_found";
}

/** True when `agent get` stdout is herdr's agent_info shape. */
export function herdrAgentRowPresent(stdout: string): boolean {
  try {
    const parsed = JSON.parse(stdout.trim()) as { result?: { agent?: unknown } };
    return !!parsed?.result?.agent && typeof parsed.result.agent === "object";
  } catch {
    return false;
  }
}

export function argvAgentGet(target: string): string[] {
  return ["agent", "get", target];
}

/**
 * `--until` REPEATED, not comma-joined. ADR/PLAN spell it `--until idle,done,blocked`; herdr's CLI
 * takes one state per flag ("repeat for more than one state") and rejects the comma form with exit 2
 * (measured against the installed herdr 2026-09-14). No `--timeout`: cancellation kills the child.
 */
export function argvAgentWaitSettled(target: string): string[] {
  return ["agent", "wait", target, "--until", "idle", "--until", "done", "--until", "blocked"];
}

function describeHerdrFailure(argv: string[], r: HerdrResult): string {
  if (r.spawnError !== undefined) return `herdr ${argv.join(" ")} could not be run: ${r.spawnError}`;
  const err = r.stderr.trim();
  return `herdr ${argv.join(" ")} failed (exit ${r.code}, code ${herdrFailureCode(r)})${err ? `: ${err}` : ""}`;
}

// ------------------------------------------------------------------------------------------------
// The waiter
// ------------------------------------------------------------------------------------------------

interface Candidate {
  index: number;
  reply: WakeReply;
}

export function startWakeWaiter(
  req: WakeRequest,
  deps: WaiterDeps,
  onReady: (reply: WakeReply) => void,
): WakeWaiterHandle {
  const controller = new AbortController();
  const cleanups: Array<() => void> = [];
  const candidates: Candidate[] = [];
  let finished = false;
  let flushQueued = false;

  const cancel = (): void => {
    if (!controller.signal.aborted) controller.abort();
    finished = true;
    for (const c of cleanups.splice(0)) {
      try {
        c();
      } catch {
        // cleanup is best-effort
      }
    }
  };

  const flush = (): void => {
    flushQueued = false;
    if (finished || candidates.length === 0) return;
    candidates.sort((a, b) => a.index - b.index);
    const winner = candidates[0];
    cancel();
    onReady(winner.reply);
  };

  const ready = (index: number, outcome: WakeOutcomeName, waitId: string, detail: string): void => {
    if (finished) return;
    candidates.push({ index, reply: { request_id: req.request_id, wait_id: waitId, outcome, detail } });
    if (!flushQueued) {
      flushQueued = true;
      deps.defer(flush);
    }
  };

  const sleep = (ms: number): Promise<void> =>
    new Promise((resolve) => {
      const clear = deps.setTimer(resolve, ms);
      cleanups.push(() => {
        clear();
        resolve();
      });
    });

  req.waits.forEach((wait, index) => {
    switch (waitKind(wait)) {
      case "operator":
        return;
      case "timer":
        armTimer(wait as TimerWait, index);
        return;
      case "delegate":
        observeAnswer(wait as DelegateWait, index);
        void observeState(wait as DelegateWait, index);
        return;
    }
  });

  function armTimer(w: TimerWait, index: number): void {
    // setTimeout clamps delays above 2^31-1 ms to 1 ms; re-arm in bounded chunks instead.
    const MAX = 2 ** 31 - 1;
    const arm = (): void => {
      if (finished) return;
      const remaining = w.deadline_ms - deps.now();
      if (remaining <= 0) {
        ready(index, "timed_out", w.id, "");
        return;
      }
      cleanups.push(deps.setTimer(arm, Math.min(remaining, MAX)));
    };
    arm();
  }

  function observeAnswer(w: DelegateWait, index: number): void {
    const check = (): void => {
      if (finished) return;
      const content = deps.readAnswer(w.answer_path);
      if (content !== null) ready(index, "settled", w.id, content);
    };
    check(); // initial read
    if (finished) return;
    cleanups.push(deps.watchAnswer(w.answer_path, check)); // subscribe
    check(); // re-read
  }

  async function herdr(argv: string[]): Promise<HerdrResult> {
    try {
      return await deps.herdr(argv, controller.signal);
    } catch (err) {
      return { code: -1, stdout: "", stderr: "", spawnError: String((err as Error)?.message ?? err) };
    }
  }

  /** The row went away after it was seen: re-read the answer; content -> settled, none -> lost. */
  function rowGone(w: DelegateWait, index: number, target: string): void {
    const content = deps.readAnswer(w.answer_path);
    if (content !== null) ready(index, "settled", w.id, content);
    else ready(index, "lost", w.id, `herdr reports agent_not_found for ${target} and no answer file was written to ${w.answer_path}`);
  }

  async function observeState(w: DelegateWait, index: number): Promise<void> {
    const target = w.locator?.pane || w.id;
    const hostError = (argv: string[], r: HerdrResult): void =>
      ready(index, "host_error", "", describeHerdrFailure(argv, r));

    // Phase 1: wait for the row to exist. `agent_not_found` here means "not registered yet".
    for (;;) {
      if (finished) return;
      const argv = argvAgentGet(target);
      const r = await herdr(argv);
      if (finished) return;
      if (r.spawnError === undefined && r.code === 0) {
        if (!herdrAgentRowPresent(r.stdout)) {
          ready(index, "host_error", "", `herdr ${argv.join(" ")} returned unparseable output: ${r.stdout.slice(0, 200)}`);
          return;
        }
        break;
      }
      if (!herdrMeansAgentGone(r)) return hostError(argv, r);
      await sleep(deps.pollMs);
    }

    // Phase 2 (claude/codex): the settled-state wait. Its success is not an answer.
    if (w.delegate_kind !== "motoko") {
      for (;;) {
        if (finished) return;
        const argv = argvAgentWaitSettled(target);
        const r = await herdr(argv);
        if (finished) return;
        if (r.spawnError === undefined && r.code === 0) {
          const content = deps.readAnswer(w.answer_path);
          if (content !== null) {
            ready(index, "settled", w.id, content);
            return;
          }
          // Settled with no answer on disk: not an answer, and not lost (the row is there). Fall
          // through to watching the row, while the file observation stays live.
          break;
        }
        if (herdrMeansAgentGone(r)) return rowGone(w, index, target);
        if (herdrFailureCode(r) === "timeout") continue;
        return hostError(argv, r);
      }
    }

    // Phase 3: the row disappearing after it was seen (the motoko one-shot's exit).
    for (;;) {
      if (finished) return;
      await sleep(deps.pollMs);
      if (finished) return;
      const argv = argvAgentGet(target);
      const r = await herdr(argv);
      if (finished) return;
      if (r.spawnError === undefined && r.code === 0) continue;
      if (herdrMeansAgentGone(r)) return rowGone(w, index, target);
      return hostError(argv, r);
    }
  }

  return {
    cancel,
    get finished() {
      return finished;
    },
  };
}

// ------------------------------------------------------------------------------------------------
// Production deps
// ------------------------------------------------------------------------------------------------

const liveChildren = new Set<ChildProcess>();
let reapHooksInstalled = false;

function reapAll(): void {
  for (const child of liveChildren) {
    try {
      child.kill("SIGTERM");
    } catch {
      // already gone
    }
  }
  liveChildren.clear();
}

/**
 * Reap herdr children on the exit paths herdr-agent-state's reporter handles: `exit`, SIGINT,
 * SIGTERM. The signal listeners re-raise only when they are the last listener, so installing them
 * never changes how the process dies (the reporter's own handler re-raises when it is installed).
 */
function installReapHooks(): void {
  if (reapHooksInstalled) return;
  reapHooksInstalled = true;
  process.on("exit", reapAll);
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    const handler = (): void => {
      reapAll();
      if (process.listenerCount(signal) === 1) {
        process.removeListener(signal, handler);
        process.kill(process.pid, signal);
      }
    };
    process.on(signal, handler);
  }
}

/** Test seam: how many herdr children the production runner still holds. */
export function __liveHerdrChildrenForTests(): number {
  return liveChildren.size;
}

export function createHerdrRunner(bin: string = process.env.HERDR_BIN_PATH || "herdr"): HerdrRunner {
  return (argv, signal) =>
    new Promise((resolve) => {
      if (signal.aborted) {
        resolve({ code: -1, stdout: "", stderr: "", spawnError: "cancelled" });
        return;
      }
      installReapHooks();
      let child: ChildProcess;
      try {
        child = spawn(bin, argv, { stdio: ["ignore", "pipe", "pipe"] });
      } catch (err) {
        resolve({ code: -1, stdout: "", stderr: "", spawnError: String((err as Error)?.message ?? err) });
        return;
      }
      liveChildren.add(child);
      let stdout = "";
      let stderr = "";
      let done = false;
      const finish = (r: HerdrResult): void => {
        if (done) return;
        done = true;
        liveChildren.delete(child);
        signal.removeEventListener("abort", onAbort);
        resolve(r);
      };
      const onAbort = (): void => {
        try {
          child.kill("SIGTERM");
        } catch {
          // gone
        }
      };
      signal.addEventListener("abort", onAbort);
      child.stdout?.on("data", (c: Buffer) => (stdout += c.toString("utf8")));
      child.stderr?.on("data", (c: Buffer) => (stderr += c.toString("utf8")));
      child.on("error", (err) => finish({ code: -1, stdout, stderr, spawnError: String(err.message ?? err) }));
      child.on("close", (code, sig) =>
        finish({ code: typeof code === "number" ? code : -1, stdout, stderr: sig ? `${stderr}killed by ${sig}` : stderr }),
      );
    });
}

export function readAnswerFile(answerPath: string): string | null {
  try {
    const content = fs.readFileSync(answerPath, "utf8");
    return content !== "" ? content : null;
  } catch {
    return null;
  }
}

/** fs.watch on the answer's directory (the file may not exist yet), plus a poll as the fallback. */
export function watchAnswerFile(answerPath: string, onChange: () => void, pollMs = 500): () => void {
  let watcher: fs.FSWatcher | null = null;
  try {
    const base = path.basename(answerPath);
    watcher = fs.watch(path.dirname(answerPath), (_event, name) => {
      if (name === null || name === undefined || String(name) === base) onChange();
    });
    watcher.on("error", () => {});
  } catch {
    watcher = null;
  }
  const poll = setInterval(onChange, pollMs);
  return () => {
    clearInterval(poll);
    try {
      watcher?.close();
    } catch {
      // closed
    }
  };
}

export function defaultWaiterDeps(): WaiterDeps {
  return {
    herdr: createHerdrRunner(),
    readAnswer: readAnswerFile,
    watchAnswer: (p, onChange) => watchAnswerFile(p, onChange),
    now: () => Date.now(),
    setTimer: (fn, ms) => {
      const t = setTimeout(fn, ms);
      return () => clearTimeout(t);
    },
    defer: (fn) => {
      setImmediate(fn);
    },
    pollMs: 1000,
  };
}

export const defaultWakeWaiterFactory: WakeWaiterFactory = (req, onReady) =>
  startWakeWaiter(req, defaultWaiterDeps(), onReady);
