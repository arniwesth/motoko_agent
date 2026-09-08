# Hitting the step budget starts a FRESH session — the previous run's history is silently discarded

## Status

**Repaired in memory; on the journal at P3.**

Repaired by PLAN-003 P1 (ADR-003 v6.1 D2/D5/D6) on branch `arniwesth/013-plan003-and-herdr`.
The repairing commit is P1 Part 6, `ADR-003 D2: P1 Part 6 — the host's run_suspended case, and
the first judging number`, whose parent is `fdfd34a`; it is named by subject, parent and branch
rather than by hash for the reason P1 Part 2 gave when it closed
`max-steps-termination-discriminated-by-error-message-string.md`: this part is one commit and a
commit cannot contain its own hash. The hash is recorded in that commit's report.

WHAT IS REPAIRED, AND WHAT IS NOT. Reaching the step budget is now a typed suspension, not an
`Internal` failure: the run carries its history out as a `Continuation`, the conversation loop
HOLDS it between turns, and the operator's next line is appended to the exhausted turn's history
and resumes THAT run. Measured live — this issue's own symptom, inverted:

    run 0: provider payloads [2, 4, 6]    -> run_suspended(r0.0, budget_exhausted, 3), max_steps
    run 1: provider payloads [9, 11, 13]  -> run_suspended(r0.1, budget_exhausted, 3), max_steps
    run 2: provider payloads [16, 18, 20] -> stop

Each `continue` opens on the exhausted history plus the operator's message (8+1, then 15+1)
instead of restarting at a fresh payload, no `error` event is emitted, and the model's closing
summary names every command across all three runs. The `steps_executed_so_far` this issue's
"Expected behaviour" asks about is carried as the continuation's `cumulative`, seeded into the
resumed run's `prior_counts` — so `MotokoRuntimeStatus` reports the carried-over counts rather
than 0.

IN MEMORY ONLY. The continuation lives in the conversation loop's process. `restart`, `abort`
and `exit` still drop it, and so does a crash — the second of ADR-003's judging numbers ("a run
that dies at step N resumes with N steps of history") is P3's, on the journal the host writes
from the wire. The two `session_id`s this issue's evidence shows also remain two in P1: each
traced run derives its own, and one id across a resume is P3's identity work.

The `error` this issue quotes is also gone from the interactive path — outside `MOTOKO_HEADLESS`
the outer loops match `suspended` before `result` and emit no `ErrorEvent`. Headless still
receives it until PLAN-003 P3 Part 6 switches the plain and JSON loggers.

## Branch

`arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded` (surfaced during the `dst_*.ail` survey)

## Description

The v2 loop enforces a step budget (default 100). When that budget is exhausted the loop
terminates with `Error: v2 loop: step budget exhausted`. Hitting that stop should be a
**pausable/resumable** boundary at which the run's history is still intact — the user should be
able to `continue` and pick up the same session with the same conversation context.

It is not. Reaching the budget kills the run, and the next interaction starts a brand-new session
at step 0 with **zero prior context**. The two log files below were the *same conversation* from the
user's point of view (the survey task, then a follow-up `continue`), but they are recorded as two
separate sessions, and the second one had no memory of the first.

## Evidence

Two session log files that should have been the same session:

- `.motoko/logfile/session_2026-08-17T16-41-59-609Z.jsonl`
- `.motoko/logfile/session_2026-08-17T17-24-04-233Z.jsonl`

The first file contains **two** `session_id`s (it itself split mid-way):

- `session_1786984939024` — the survey run, 100 steps. Ends
  `{"type":"run_summary", ... "finish_reason":"max_steps", "steps_executed":100,
  "error":"v2 loop: step budget exhausted"}` followed by
  `{"type":"error","source":"agent_loop_v2","code":"Internal","message":"v2 loop: step budget exhausted"}`.
- `session_1786987390500` — a `[17:23:10] > continue` turn. Restarts at step 0 with a fresh
  `thinking` at `step:0`, and the model (having no context) replies "Let me get line counts for all
  modules" — i.e. it re-ran the whole task from scratch instead of resuming.

The second file records yet another session id, `session_1786987445996`, started by
`[17:24:04.234] > Wait a sec. Don't you have context for the last 100 steps?`. Its
`MotokoRuntimeStatus` shows `current_step: 0`, `steps_executed_so_far: 1`, `compaction applied: 0`,
`context_window usage ~0%` — a genuinely empty history. The model answered correctly that this was a
fresh session with no prior context, which is the bug: the user expected the 100-step history to
still be there.

So the sequence is: run to budget exhausted → `continue` opens a NEW session with empty context →
whole survey redone from zero. The history should have been retained and resumed.

## Root cause (hypothesis, from the log shape)

The `max_steps` termination is emitted as a terminal `run_summary` + `error` and the process/session
is torn down. Whatever persistence/resume mechanism is intended for `continue` is not receiving the
conversation history from the exhausted run — the continuation starts a fresh `session_*` and a fresh
provider conversation with an empty payload. Relatedly, note the existing issue
`max-steps-termination-discriminated-by-error-message-string.md` already flags that the budget
termination is discriminated only by matching the `error` message string `"v2 loop: step budget
exhausted"` in `session.ail` / `step_machine.ail` — which is exactly the path that terminates this
run and (apparently) discards the session.

## Expected behaviour

Reaching the step budget should be a resumable pause, not a history-erasing stop:

- All 100 steps (provider conversation, tool results, the full trace) survive in the same session.
- A subsequent `continue` resumes *that* session with its context intact, at the budget boundary.
- `MotokoRuntimeStatus` on the continued session should report the carried-over step counts /
  context rather than `0`.

## Non-goals

- Not about `max-recursion-depth` (#160 / the depth_canary work) — that is a separate mechanism that
  was already fixed.
- Not about abort (Esc) — though `#15 Aborting (Esc) flushes the context window` and
  `#14 Errors likely flush the context window` look like the same class of "a stop path loses
  history" bug and should be linked/verified together.

## Files

- `.motoko/logfile/session_2026-08-17T16-41-59-609Z.jsonl` (line ~3269: the `run_summary` with
  `finish_reason:"max_steps"`; line ~3270: the `error`; then `session_1786987390500` restarts at 0)
- `.motoko/logfile/session_2026-08-17T17-24-04-233Z.jsonl` (fresh session, empty context)
- `src/core/step_machine.ail` / `src/core/session.ail` — the budget-termination and resume path
