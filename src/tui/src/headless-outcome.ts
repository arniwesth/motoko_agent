import type { AgentEvent } from "./runtime-process.js";
import { formatResumedHistory } from "./ui.js";

/**
 * What the two non-TTY loggers (`PlainLogger`, `JsonlLogger` in `index.ts`) make of the events
 * that end a headless run WITHOUT a `done` — PLAN-003 P3 Part 6, ADR-003 v6.1 D2's "the plain and
 * JSON loggers exit non-zero on `run_suspended` with the reason on stderr".
 *
 * A suspension is not a failure, but headless has no operator to send the `continue` that would
 * resume it (the conversation loop returns before reading anything under `MOTOKO_HEADLESS=1`), so
 * the task did not finish and the exit must say so. Before this part only the wire `error` decided
 * the exit, and it still does when it arrives: THE HEADLESS `error` AFTER `run_suspended` IS KEPT.
 * The eval harness ends its drain on `error` and nothing else (`benchmarks/motoko_rpc.py`), so
 * removing it would classify a budget-exhausted benchmark run as neither done nor error — PLAN-003
 * §5, "P3 Part 6: the eval-harness finding". The logger therefore does NOT exit on `run_suspended`:
 * `run_summary` and that `error` follow it on the same stdout, and an exit here would drop both.
 * It records the exit code the run has earned, and `exitCode` is applied when the runtime exits
 * without an `error` to exit on.
 *
 * `session_resume_refused` is the child saying which rule refused a `--resume` journal, right
 * before it exits 3; its reason goes to stderr beside the same non-zero exit.
 */
export const SUSPENDED_EXIT_CODE = 1;
export const RESUME_REFUSED_EXIT_CODE = 3;

export class HeadlessOutcome {
  private code = 0;

  /** The stderr line this event calls for, or null; records the non-zero exit it implies. */
  observe(event: AgentEvent): string | null {
    switch (event.type) {
      case "run_suspended":
        if (this.code === 0) this.code = SUSPENDED_EXIT_CODE;
        return (
          `[suspended] ${event.reason} at step ${event.step} (run ${event.run_id}): ` +
          `headless has no operator to continue it, so this run exits non-zero\n`
        );
      case "session_resume_refused":
        this.code = RESUME_REFUSED_EXIT_CODE;
        return `[resume refused] ${event.refusal}: ${event.message} (journal ${event.journal})\n`;
      default:
        return null;
    }
  }

  /** 0 unless a `run_suspended` or `session_resume_refused` was seen. */
  get exitCode(): number {
    return this.code;
  }
}

/** The plain logger's one line for `session_resume_view`: D6's marker, without the history. */
export function formatResumeViewLine(view: Extract<AgentEvent, { type: "session_resume_view" }>): string {
  return `[resume] ${formatResumedHistory([], view).marker}\n`;
}
