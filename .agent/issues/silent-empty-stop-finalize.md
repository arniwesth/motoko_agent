# Session finalizes silently on an empty model response ("silent death")

## Status
open

## Branch
arniwesth/mot-34-layer-2-harness-boundary

## Description
Running `make live_qwen36_compaction_heavy_headless` (config `qwen36-compaction-live`, model `openrouter/qwen/qwen3.6-35b-a3b`), the session `.motoko/logfile/session_2026-07-09T20-16-49-594Z.jsonl` ended at step 96 with **no error and no useful output**. It did not crash — it *finalized*:

```
{"type":"thinking","step":96,"finish_reason":"stop","tool_calls":0,"text":""}
{"type":"run_summary","finish_reason":"stop","steps_executed":97, ...}
{"type":"done","step":96,"output":""}
```

The model returned `finish_reason: "stop"` with **empty content and zero tool calls**. The step machine treats any `"stop"` as `Finalize({reason: "model_stop", output: last_response_text})`, so the loop finalized with `output: ""` and emitted a `done` event with an empty string. From the operator's point of view the run "died silently": a clean success with nothing produced, well before the 100-step budget.

There is currently **no empty-response guard** anywhere in the finalize path. A grep of `src/core/session.ail` and `src/core/step_machine.ail` for `content == ""` / empty-response / empty-stop handling returns nothing. The harness treats an empty `"stop"` as a legitimate completion.

### Why the model emitted an empty stop (root cause chain)
The step-96 `provider_call_prepared` shows `msg_count: 655` but only `estimated_input_tokens: 22312` (~34 tokens/message). Structural elision keeps the *message* but replaces its content with an `...[elided N chars]` stub, so by step 96 the model was looking at **655 messages, ~650 of them empty stubs**. That context was gutted by ~40 consecutive steps of spurious emergency-tier compaction (`keep_last=3`), which was itself caused by a since-fixed multiplicative-calibration bug in the compactors (the char/4→real ratio exploded to ~2.6x when anchored on a compacted window, inflating calibrated usage to ~200% and forcing emergency tier every step; fixed by switching to an affine `density*est + overhead` model in `src/core/compaction.ail` `affine_calibrate`). A reasoning model handed an incoherent 650-stub context burns its reasoning budget and returns an empty stop — the step-96 trace shows exactly that (many `reasoning_delta`, then an empty `thinking`).

The affine calibration fix reduces the *cause* (less context destruction), but it does **not** close this gap: an empty stop from *any* source (degraded context, provider hiccup, reasoning exhaustion) still finalizes silently.

### Why the existing persist-nudge did not catch it
`persist_retries` (the persist-nudge budget) is the only anti-premature-stop mechanism, and it did not apply:
1. **Disabled by default.** `session_policy_init` reads `MOTOKO_PERSIST_RETRIES` (default `"0"`), and the `qwen36-compaction-live` target does not set it. With budget 0, `should_inject_persist_nudge` is always false, so any `"stop"` finalizes immediately.
2. **WriteFile/coding-specific.** Even with a budget, the nudge is gated on `not any_writefile_attempt(...)` and its message hardcodes *"use the WriteFile tool to save your complete solution"* (`recovery.ail:48`). This is a read/search task with no solution file — the wrong intent and the wrong message.
3. **Wrong symptom.** It targets "model answered in prose instead of persisting a file," not "model returned genuinely empty output."

## Location
- `src/core/session.ail:1828-1857` — `NoDecision` finalize branch: on a stop, checks `should_inject_persist_nudge(...)`; else finalizes. No empty-content check.
- `src/core/step_machine.ail` (`decide`) — `finish_reason == "stop" | "dp7_approved" | "dp7_fail_open"` → `Finalize({reason: "model_stop", output: last_response_text})`, with no guard for empty `last_response_text`.
- `src/core/recovery.ail:44-55` — `should_inject_persist_nudge` + `persist_nudge_message` (WriteFile-specific; budget from `MOTOKO_PERSIST_RETRIES`, default 0).
- Evidence: `.motoko/logfile/session_2026-07-09T20-16-49-594Z.jsonl` (step-96 empty `thinking`/`done`; step-96 `provider_call_prepared` `msg_count:655 estimated_input_tokens:22312`).

## Fix (design: guard-as-extension + thin core floor)
Do **not** add more policy to core. The finalize seam already exists and is the right home for this.

### The seam
`on_solver_candidate(ctx, candidate_text) -> FinalizeDecision` runs at the finalize gate (only reached when the model wants to stop — no tool calls). `FinalizeDecision = Accept(string) | ContinueWithFeedback(string) | NoDecision` (`packages/motoko-ext-abi/types.ail:133`). `ContinueWithFeedback(msg)` means "don't finalize — inject this and keep going"; core already loops on it (`ContinueWithFeedback` → `solver_feedback` finish_reason → `InjectUserMessage` → next model call, `session.ail:1819`). `merge_finalize_decisions` gives `ContinueWithFeedback` precedence over `Accept` over `NoDecision` (`ext/runtime.ail:314`). The hook receives the candidate text, so empty text ⟺ empty stop; no `finish_reason` plumbing is needed.

### 1. Extension: `finalize_guard` / `empty_stop_guard` (policy)
A small extension implementing `on_solver_candidate`:
```
on_solver_candidate(ctx, candidate) =
  if is_blank(candidate) && under_budget(ctx)
  then ContinueWithFeedback("You returned an empty response. Continue the task…")
  else NoDecision
```
- **Loop safety / budget lives in the extension.** A guard that always continues on empty would spin forever if the model keeps stalling. Carry a bounded budget the same way persist-nudge does: count the extension's own marker messages in `ctx.history_slice` and cap at N (the transcript IS the state; no core counter).
- **Task-agnostic message** (not WriteFile-specific).
- Needs **zero core changes** for the reactive behavior — works today if the extension is in the profile's `extensions.order`.

### 2. Core floor: never finalize an empty stop *silently* (invariant, not policy)
The risk of moving this entirely to an extension is "loaded-ness": if the guard is not in the profile, silent deaths return. Treat "an empty-stop finalize is never silent" as a **safety invariant** that must hold with zero extensions loaded. So keep a thin, policy-free floor in core: when finalizing on an empty `"stop"` (blank content, no tool calls), emit a **distinct ledger event** (e.g. `EmptyStopFinalize`) and/or mark `run_summary` so the outcome is always visible. ~One event emission, no task-specific logic. The *reactive* part (retry/nudge/continue, wording, budget) stays in the extension.

Split: **core = "empty stop is always observable" + the existing finalize-veto seam; extension = "what to do about it."**

### 3. Follow-up: migrate the existing persist-nudge to the same seam
`session.ail`'s persist-nudge is hardcoded coding-task policy (WriteFile-gated, WriteFile-specific message) living in core. It is the same shape of decision as the empty-stop guard. Once the finalize-guard-as-extension pattern exists, persist-nudge should migrate to `on_solver_candidate` too, removing that domain-specific policy from `session.ail`/`recovery.ail` entirely. Larger change; separate follow-up.

## Notes
- Also consider the **task/budget mismatch** in `QWEN36_COMPACTION_HEAVY_TASK`: it instructs "at least 200 sequential phases" while `agent.max_steps = 100`. The task can never be satisfied, so the model is structurally pushed toward stopping early. This is a config issue, not the silent-death cause (a budget-exhaustion stop is a non-silent `Fail`/`run_summary`), but it aggravates premature stops.
- Related: the over-compaction that gutted the context was the multiplicative-calibration bug, fixed on this branch by the affine model (`src/core/compaction.ail` `affine_calibrate` / `delta_token_density_permille`, mirrored in the compaction_ai and compaction_structural extensions). That fix reduces the frequency of gutted-context stalls but does not remove the silent-finalize gap this issue tracks.
