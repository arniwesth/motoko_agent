# Hitting the step budget starts a FRESH session — the previous run's history is silently discarded

## Status

open

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
