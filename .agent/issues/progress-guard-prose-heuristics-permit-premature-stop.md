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

## Second occurrence (2026-09-05): the same prose heuristic in the other direction — a busy-poll

The guard's stop-permission logic is prose-driven, and prose cuts both ways. In the PLAN-001 live
run (`.motoko/logfile/session_2026-09-05T16-06-34-724Z.jsonl`, orchestrator turn "Launch it",
session `1788636426215`) the orchestrator delegated a task, ended its answer with *"I'll settle it
when the answer lands"*, and stopped. That is the correct behaviour: the work is in another pane
and nothing the orchestrator can do advances it. The guard read the sentence as an incomplete task
(steps 6 and 76):

> You stopped while your own response indicates the task is still in progress. Continue the
> existing task now.

So the orchestrator continued, and the only thing it could do was poll. That turn ran 193 steps:
55 `DelegateCheck` calls (each "has not written its answer yet … waited 20 s"), ~60
`herdr pane read`, two `send-text` nudges into the worker, one bare `sleep 90`, then a takeover.
The user's verdict: *"The polling does not seem to work."*

This is the same defect as above. The guard consults the model's sentences instead of runtime
state. Here the runtime state that would have settled it is "a delegate this session owns is
`working` and no answer file exists", which the herdr extension knows and the guard does not ask.

Addition to the fix list:

- The guard should treat "waiting on a delegate" as an allowed stop. Either the herdr extension
  exposes an in-flight count the guard can read from `ctx`, or the `Delegate` tool result's
  *"this call did not wait for it"* sentence becomes a structured flag the guard honours. A model
  that has open delegates and says it is waiting is not stopping early.
- Deterministic test: a candidate ending "I'll settle it when the answer lands" with one open
  delegate in the history slice must produce `NoDecision`; the same sentence with zero open
  delegates must still produce `ContinueWithFeedback`.

Context: `.agent/projects/021_herdr_delegation/MEASUREMENTS-2026-09-05-plan001-live-run.md`
finding 5.

## Progress (2026-09-06)

Status stays **open**: only the "Second occurrence" addition is fixed. The four
compaction-era fix items above (the runtime counter, the stale compaction-mention
overrides, the broadened incomplete detection, and `qwen36-compaction-live`'s
`max_steps`) are untouched.

Commit `PLAN-001 live-run fix 5: waiting on a delegate is an allowed stop` on
`arniwesth/013-dst-architecture-adr`.

`progress_contract_guard.ail` now carries `has_open_delegate(ctx)`, and
`decide_with_budget` will not nudge while it is true. The signal is the cheapest
truthful one available: `ExtCtx` has no in-flight delegate count — the herdr
extension knows one and the ABI has no slot for it — so the guard reads the
sentences the herdr extension itself wrote into **tool-role** messages of
`ctx.history_slice`. Those strings are produced by deterministic code in
`packages/motoko-ext-herdr/herdr.ail`, not by the model, which is what makes this
a runtime-state read and not one more prose rule. The last delegate signal in the
slice wins, so a collected delegate stops being open and a second launch reopens.

Three judgements the issue did not settle:

- **`BLOCKED` is not open.** A delegate waiting for someone to answer a prompt on
  its screen will not progress on its own, so stopping on it is a thing to report,
  not work in flight. The guard keeps nudging.
- **Assistant messages are excluded**, for `history_has_contract`'s trap-#1
  reason: a candidate quoting the tool result back would otherwise write its own
  permission to stop.
- **Re-wording the herdr result strings degrades this to a nudge**, not to a wrong
  allowance. That is the safe direction, and it is why a structured flag on
  `ExtCtx` is still the better long-term shape.

Four deterministic tests, the first two as the section names them:
`test_open_delegate_makes_waiting_an_allowed_stop` (waiting candidate + one open
delegate → `NoDecision`), `test_no_open_delegate_still_nudges` (same candidate,
empty slice → `ContinueWithFeedback`), plus `test_settled_delegate_is_not_open`
and `test_assistant_prose_cannot_open_a_delegate`.
