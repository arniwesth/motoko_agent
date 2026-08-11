# AI compaction summary loses task-control state

## Status
implemented

## Branch
arniwesth/mot-36-compactor-strategy-refinement

## Description
After the compactor-strategy refinement, `make live_qwen36_compaction_heavy_headless` no longer
collapses via structural emergency over-elision. The latest run
`.motoko/logfile/session_2026-07-10T10-35-14-469Z.jsonl` instead shows a different failure mode:
AI compaction preserves enough semantic history to continue reading files, but not enough
task-control state to keep the model bound to the original stress task.

Terminal evidence:
- Step 38: structural compaction applied gently: `structural: tier=tier1 keep_last=10`.
- Steps 39-47: AI compaction summarized large batches, e.g. `AI-summarized 158 turns (94% -> 20%)`
  and finally `AI-summarized 178 turns (86% -> 3%)`.
- Step 47 sent only `msg_count:12` / `estimated_input_tokens:9333`.
- The model then returned `finish_reason:"stop"` with:
  `"I see we're in a new context window... What would you like to work on?"`
- `run_summary` reported clean `finish_reason:"stop"` at `steps_executed:48`.

This is not the same defect as `.agent/issues/silent-empty-stop-finalize.md`. That issue covers the
core/finalize behavior once the model stops. This issue is upstream: the AI compactor's replacement
message lets the model interpret compaction as a fresh handoff instead of as a continuation of the
original task.

## Location
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:53` `summarization_prompt` asks for generic
  "Current task state" but does not require original task, stop conditions, status cadence, or
  "not a fresh session" semantics.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:170` `summary_msg` wraps the model-produced
  prose as `[CONTEXT SUMMARY] ...` with no deterministic runtime capsule.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:224` halves `keep_recent` at high pressure,
  which can discard the latest control/status context exactly when compaction becomes severe.
- `.motoko/config/qwen36-compaction-live/config.json:5` sets `max_steps:100` while the stress task
  asks for 200 steps. This is a separate config mismatch, but it makes control-state preservation
  more important because the model is already operating under contradictory constraints.

## Fix
- Add a deterministic control capsule around AI compaction summaries. It must include the original
  task (`ctx.task`), current step, a clear statement that compaction is not a new session/request,
  and active continuation/stop obligations.
- Tighten the summarizer prompt so the AI summary also extracts task state, stop conditions, latest
  status/progress, and next required action. Correctness must not depend on the summarizer complying.
- Preserve or mirror the latest runtime status/control fields when available, so `current_step`,
  `step_budget`, and compaction progress survive even if the latest `MotokoRuntimeStatus` result is
  outside the protected recent tail.
- Add deterministic tests with a hostile/weak summarizer that omits the control obligations; the
  compacted payload must still contain the deterministic capsule.

## Non-goals
- Do not change core's unconditional stop/finalize semantics here; that belongs to
  `.agent/issues/silent-empty-stop-finalize.md`.
- Do not persist compaction into `st.msgs`.
- Do not change token calibration.
- Do not bound retained history growth.
