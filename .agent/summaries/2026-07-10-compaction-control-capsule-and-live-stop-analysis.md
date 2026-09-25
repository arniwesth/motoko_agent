# 2026-07-10 Compaction Control Capsule and Live Stop Analysis

## Context

This session implemented the reviewed plan in
`.agent/projects/006_compactor_strategy/PLAN-compaction-control-capsule.md`.
The source issue was `.agent/issues/compaction-summary-loses-task-control-state.md`.

The previous live Qwen compaction-heavy run ended around step 47 because Qwen interpreted
`[CONTEXT SUMMARY]` as a fresh-session handoff and asked what to work on next. The goal here was
to make the AI compactor's replacement message preserve task-control state deterministically before
the model is called.

## Implementation

Committed:

- `b961ac6 Add compaction control capsule`

Files changed in the commit:

- `packages/motoko-ext-compaction-ai/compaction_ai.ail`
- `scripts/long_qwen_compaction_dst.ail`
- `.agent/issues/compaction-summary-loses-task-control-state.md`
- `ailang.lock`

Main changes:

- Replaced the old `[CONTEXT SUMMARY]` assistant message with a deterministic
  `[RUNTIME COMPACTION SUMMARY]` capsule.
- The capsule includes:
  - `ctx.task` verbatim as `ORIGINAL TASK`
  - current step, model, context limit, and compaction state
  - explicit obligations that this is not a fresh session and not permission to stop
  - explicit continue/status-cadence obligations
  - AI summary prose under `AI SUMMARY OF OLDER CONTEXT`
- Kept the artifact cache scoped to AI prose only. The request-local capsule is rebuilt on each
  `Compacted` decision so cached summaries do not replay stale step/task/status fields.
- Added runtime status extraction:
  - preferred path correlates assistant `tool_calls` named `MotokoRuntimeStatus` with matching
    tool messages by `tool_call_id`
  - legacy marker fallback is used only if no correlated status result exists
  - status content is bounded before insertion into the capsule
- Hardened the summarizer prompt so it asks for original objective, stop conditions, status/progress,
  next action, and no fresh-session/handoff framing.
- Added direct module tests for hostile summary prose and correlated runtime-status extraction.
- Updated `scripts/long_qwen_compaction_dst.ail`:
  - assertions now expect `[RUNTIME COMPACTION SUMMARY]`
  - artifact-cache scenario verifies cached AI prose reuse while the deterministic capsule is rebuilt
    from current context
  - added hostile summarizer scenario using `What would you like to work on?`
  - validation is run against the compactor segment, not a sealed payload with system messages
- Updated `.agent/issues/compaction-summary-loses-task-control-state.md` status to `implemented`.

## Verification

Passed:

```bash
ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail
make compaction_dst
make conformance
```

After `ailang lock`, the gates passed without dependency hash warnings.

## Follow-up Live Run Analysis

User then ran:

```bash
make live_qwen36_compaction_heavy_headless
```

Latest log inspected:

- `.motoko/logfile/session_2026-07-10T11-30-14-854Z.jsonl`

Key ending:

- Step 45 `MotokoRuntimeStatus` reported:
  - `current_step:45`
  - `step_budget:100`
  - `finish_reason_so_far:"tool_calls"`
  - `stage_applied_total:15`
  - `compaction_ai_applied:13`
  - uncompacted pending calibrated usage around `94%`
- Step 46 compaction applied:
  - `AI-summarized 256 turns (94% -> 3%)`
- Step 46 provider payload:
  - `msg_count:8`
  - `estimated_input_tokens:8596`
- Step 46 model reasoning explicitly retained the task:
  - it said it needed to continue the compaction stress calibration
  - it said it needed to reach at least 200 steps
  - it said it should keep calling `MotokoRuntimeStatus`
  - it said it should continue reading/searching
- But the final step result was:
  - `finish_reason:"stop"`
  - `tool_calls:0`
  - non-empty prose: `Phase 46 continuing. Reading more source files and running searches.`
- Core finalized immediately:
  - `run_summary finish_reason:"stop" steps_executed:47`

Conclusion: the capsule fixed the original fresh-session control-loss symptom. The new live run did
not end with "What would you like to work on?" or "new context window" behavior. Qwen knew it should
continue, but still emitted a non-empty `stop` instead of tool calls. Core accepted that stop as final.

## Remaining Issue

The remaining failure is downstream of compaction: premature model stop finalization.

Relevant existing issue:

- `.agent/issues/silent-empty-stop-finalize.md`

That issue was written for empty stops, but this run shows the same boundary must handle non-empty
premature stops too. The model can say "I will continue" in prose while returning `finish_reason:"stop"`
and zero tool calls. With no finalize guard loaded, core treats this as completion.

Relevant code:

- `src/core/step_machine.ail`: `finish_reason == "stop"` maps to `Finalize({ reason: "model_stop", ... })`
- `src/core/session.ail`: finalize path dispatches solver-candidate hooks, but loaded live extensions
  do not veto this stop
- `packages/motoko-ext-abi/types.ail`: `FinalizeDecision = Accept | ContinueWithFeedback | NoDecision`
  already provides the extension seam for a guard

Live profile detail:

- `.motoko/config/qwen36-compaction-live/config.json` has `agent.max_steps = 100`
- `QWEN36_COMPACTION_HEAVY_TASK` asks for at least 200 phases/steps
- This mismatch is not why the run stopped at 46, but it makes the task internally inconsistent and
  should be corrected for future live calibration.

## Current Worktree Notes

At the end of the session:

- `HEAD` was `b961ac6`
- `ailang.lock` was modified only by `generated_at` timestamp after a subsequent run/build path:
  no package content hash changed from the committed lock
- Untracked handoff file remained:
  `.agent/projects/006_compactor_strategy/HANDOFF-implement-compaction-control-capsule.md`

