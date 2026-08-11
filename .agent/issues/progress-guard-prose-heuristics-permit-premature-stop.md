# Progress-contract guard permits premature stop after compaction (prose heuristics, no step-count check)

## Status
open

## Branch
arniwesth/mot-40-observable-pre-step-pass-through (surfaced here; not yet scheduled)

## Description
Once AI compaction actually works, `make live_qwen36_compaction_heavy_headless` and
`make deepseekv4_flash_compaction_heavy_headless` both finalize (`finish_reason:"stop"`) around
step 48-52 despite the heavy task saying *"Do not stop early… continue until you have made at least
1000 model turns."* This is a run-length regression **in effect**, but it is not caused by the recent
retry / finish_reason fixes — those are provably neutral here (every step in both runs was
`finish=tool_calls` or `finish=stop, n_calls=0`; neither hit the changed branch, neither errored).

The actual trigger is that **AI compaction now functions** (model-ID + `keep_recent_tokens` fixes).
Baseline proof, same qwen36 config:

| AI compaction | Run length |
|---|---|
| broken (0 folds, 46 summarizer_failed) — `session_2026-07-11T11-05-05` | 100 steps, `finish=max_steps` |
| working (26 folds, cache-reused 332 turns) — `session_2026-07-12T08-25-25` | 48 steps, `finish=stop` |

Both new runs stop exactly where AI compaction goes heavy (qwen: cache-reuse 332 turns at 163%→14%;
deepseek: folding 244→264 turns at 98%→11%). After compaction the model emits a wrap-up "Final
Summary", and the progress-contract guard lets it finalize.

Two guard weaknesses combine to allow the premature stop:

1. **Prose-only continue/stop decision.** `decide_with_budget` nudges only when
   `candidate_self_reports_incomplete && not candidate_claims_complete_or_allowed_stop`. A post-compaction
   wrap-up ("## Final Summary: … the calibration was interrupted after 44 steps …") is past-tense summary
   prose that matches *neither* the "still going" patterns (`continuing`, `next phase`, `step N/…`) *nor*
   strongly the "complete" patterns, so the guard falls through to `NoDecision` and finalizes. The decision
   never consults the authoritative runtime counter: `MotokoRuntimeStatus.current_step` vs `step_budget`.
   deepseek stopped at **52/1010** — the budget was nowhere near reached, but the guard had no idea.

2. **Stale compaction-mention allowed-stop overrides.** `candidate_claims_complete_or_allowed_stop`
   treats `runtime compacted` / `compaction occurred` / `compaction has occurred` as *allowed stops*.
   Its own comment says this was tuned to a task variant that "allows stopping after runtime compaction
   (trap #2)". But the current `QWEN36_COMPACTION_HEAVY_TASK` says the opposite — *"If context pressure or
   compaction occurs, **continue** the task and explicitly report that you continued after it."* So a model
   that dutifully reports "compaction occurred, I continued" can be read by the guard as permission to stop.

Contributing config issue: `qwen36-compaction-live` has `max_steps:100` while the task asks for 1000; the
model cites this ("step_budget: 100 … target of 1000 not reached") as justification to wrap up. The free
profiles are already at `max_steps:1010`.

## Location
- `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:71` `candidate_self_reports_incomplete`
  — narrow prose whitelist; misses past-tense wrap-up summaries.
- `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:89-108`
  `candidate_claims_complete_or_allowed_stop` — lines 97-100 make bare `compaction occurred` / `runtime
  compacted` an allowed stop, contradicting the current continue-after-compaction task.
- `packages/motoko-ext-progress-contract-guard/progress_contract_guard.ail:110-117` `decide_with_budget`
  — the whole continue/stop decision is prose-only; no `current_step`/`step_budget` input.
- The guard receives `ctx.history_slice`, which contains `MotokoRuntimeStatus` tool results
  (`current_step`, `step_budget`) — so the authoritative counter is available but unused.
- `Makefile` `QWEN36_COMPACTION_HEAVY_TASK` — "continue … after [compaction]" is the intended contract.
- `.motoko/config/qwen36-compaction-live/config.json` `agent.max_steps:100` vs task target 1000.

## Fix
- Make the guard authoritative on the runtime counter, not prose: parse the latest `MotokoRuntimeStatus`
  from `ctx.history_slice` and refuse to allow a stop while `current_step < step_budget` (and below the
  task's stated target). A prose completion/wrap-up claim must be corroborated by the actual counter.
- Remove or tighten the compaction-mention allowed-stop overrides (lines 97-100): under a
  continue-after-compaction task, "compaction occurred" is a progress report, not permission to stop.
- Broaden `candidate_self_reports_incomplete` (or invert the logic) so a wrap-up summary emitted while the
  step budget is unmet still triggers a continue nudge — but only if the counter agrees, so genuine
  budget-reached completions still finalize.
- Align `qwen36-compaction-live` `max_steps` with the task (1010) so the model does not see a `step_budget`
  that contradicts the instruction.
- Deterministic tests: a past-tense "Final Summary" candidate with `current_step << step_budget` in
  `history_slice` must produce `ContinueWithFeedback`; the same summary with `current_step == step_budget`
  must produce `NoDecision`.

## Non-goals
- Do not remove genuine-completion detection — a real "task complete" at the target step must still finalize.
- Do not change compaction, the retry policy, or the tool-call/finalize branching.
- Do not weaken `empty_stop_guard`'s ownership of the blank-candidate case.
- Related but distinct: `.agent/issues/compaction-summary-loses-task-control-state.md` addresses the
  compaction *summary/capsule* steering the model toward wrap-up; this issue is about the *guard's*
  stop-permission logic once the model does try to wrap up.
