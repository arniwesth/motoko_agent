# Compaction is ephemeral: unbounded shadow history + over-escalation to emergency tier

## Status
open

## Branch
arniwesth/mot-34-layer-2-harness-boundary

## Description
Under the compaction stress task (`make live_qwen36_compaction_heavy_headless`, model `openrouter/qwen/qwen3.6-35b-a3b`), compaction is applied **ephemerally per step and never persisted into the conversation history**. Each step the compactor chain runs on the full, ever-growing uncompacted history to produce a compacted payload *for sending only*; the persisted next-state history is the full uncompacted history plus the new assistant turn.

Evidence — `.motoko/logfile/session_2026-07-09T20-50-38-105Z.jsonl` (affine-calibration build):
- `provider_call_prepared.msg_count` grows unbounded: 139 (step 39) → 197 (54) → 243 (68) → 299 (91) → 329 (106) → 371 (127).
- The uncompacted estimate grows with it: `estimated_input_tokens` 106,025 → 234,393.
- But the **sent** window (`estimated_input_tokens` on the compacted payload once compaction is active) collapses to 12,707–28,296 — i.e. structural `keep_last=3` elides ~360 of ~371 messages to `...[elided N chars]` stubs.

### Confirming terminal state (manual stop at step 127)
The run was manually stopped at step 127 (target was 200; `max_steps=200`). It did **not** silently die — it kept emitting real tool calls and compacting actively the whole way — but it was stuck in a permanent no-progress thrash, which is why it was killed:
- `step 125: AI-summarized 1 turns (142% -> 141%)` / `structural: tier=emergency keep_last=3`
- `step 126: AI-summarized 1 turns (142% -> 142%)` / `structural: tier=emergency keep_last=3`
- `step 127: AI-summarized 1 turns (142% -> 142%)` / `structural: tier=emergency keep_last=3`
- Final `provider_call_prepared` step 127: `msg_count=371`, `sent_est=12,707` — the model was running on ~13K tokens (~5% of the 262K limit) while the uncompacted shadow reached 371 messages / 142% calibrated.

This cleanly separates the two concerns: the affine-calibration fix held (accurate numbers, no bogus 200–245%, no collapse into an empty-stop finalize as in the earlier step-96 run), while the **compactor strategy** stayed pinned at emergency tier with the AI summarizer no-oping every step — endless thrash with a gutted working window and no forward progress.

### Wiring (why it's ephemeral)
- `src/core/session.ail:1627` seals `chain.msgs` (compacted) → `compacted_msgs = payload_messages(payload)` (`:1643`), used only for `dispatch_step(...)` (`:1659`) and the sent-window estimate (`:1651`, `:1697`).
- The persisted history that flows into the next `c2_loop` state is `msgs_with_assistant = st.msgs ++ [assistant_msg]` — the **full uncompacted** history. `chain.msgs` / `compacted_msgs` are never written back to `st.msgs`.
- `c2_pending_context(st)` (used by the status tool and the pre-step compactor input) therefore returns the ever-growing uncompacted shadow.

### Consequences
1. **Unbounded memory / rework.** `st.msgs` grows without bound; the full history is re-elided from scratch every step.
2. **Over-escalation to emergency tier → context gutted.** The structural ladder (`compact_for_pre_step`) picks its tier from the *uncompacted* calibrated pct: `>= emergency_pct (95)` → `keep_last=3`. Because the uncompacted shadow keeps climbing (calibrated 94% → 114% → 133% in this run), it pins to emergency and the **sent** window is gutted to ~15K — the model runs on ~6% of the 262K limit it actually has. This is the same context-gutting that produced the step-96 empty-stop "silent death" (`silent-empty-stop-finalize.md`).
3. **Wrong question for tier selection.** The ladder asks "how full is the uncompacted window?" (133%) rather than "what is the least elision that puts the *sent* window under the limit?" At `keep_last=10` (tier1) a 300-message history is already far under limit, so emergency `keep_last=3` is unnecessary over-compaction.
4. **Misleading observability.** With ephemeral compaction, `MotokoRuntimeStatus.context_window.calibrated_usage_pct` (uncompacted shadow, 114%) and `.actual_usage_pct` (last sent window, 10%) measure *different windows*, so the metric reads as self-contradictory once compaction is active.

## Location
- `src/core/session.ail:1627,1643,1659,1697` — compacted payload used only for send; `msgs_with_assistant = st.msgs ++ [assistant_msg]` persists the uncompacted history.
- `src/core/session.ail:1267` — `c2_pending_context` returns the uncompacted shadow.
- `packages/motoko-ext-compaction-structural/compaction_structural.ail` — `compact_for_pre_step` tier ladder keyed off uncompacted pct; no "minimal elision to get under limit" check.

## Fix (options)
- **Persist compaction into history** so `st.msgs` is replaced by the compacted result once a tier fires (bounded memory; the shadow stops growing; calibrated pct then reflects the real working window). This is the larger, more correct change; must preserve tool-call/tool-result pairing and the system prefix, and interact correctly with the AI summary cache.
- **Or** select the structural tier by *result*, not by uncompacted pct: pick the gentlest `keep_last` whose resulting sent window is under a target pct (e.g. binary-search / try tier1 → hard → emergency and stop at the first that fits), instead of jumping to emergency because the uncompacted shadow is >95%.
- Either way, make the status tool's `est`/`calib` measure the same window as `actual` (the sent window) once compaction is active, or clearly label them as "uncompacted pending" vs "last sent."

---

# AI compactor no-op thrash: summarizes 1 turn for 0% relief, every step

## Status
open

## Branch
arniwesth/mot-34-layer-2-harness-boundary

## Description
Once the AI compaction threshold is crossed, `compact_with_ai` fires **every step** but summarizes exactly **one** old turn and achieves **~0% relief**, burning an AI summarizer call per step for no benefit.

Evidence — same session:
- `AI-summarized 1 turns (75% -> 75%)` (step 61), `... (131% -> 131%)` (step 110), `... (133% -> 133%)` (step 112) — the before/after calibrated pct is identical, and it is always "1 turns."
- `compaction.compaction_ai_applied` reached 32 by step 92 — i.e. an AI call on ~every step past the threshold.

Two compounding causes:
1. **Only 1 turn is ever eligible.** `split_body(body, keep_recent)` walks from the front and stops at the first turn that is protected (fewer than `keep_recent` messages remain, or a message whose tool_calls have a matching tool result in the tail). On this transcript that yields a single "old" turn per step, so each summary replaces one turn out of ~300 — negligible.
2. **Ephemeral, like structural (see above).** Even the 1-turn summary is not persisted; next step the full history is back, so the AI compactor re-does the same no-op. The `0% -> 0%` relief also reflects that summarizing 1 of 300 turns barely moves the calibrated total.

Net: an AI request (latency + tokens + cost) every step that changes nothing.

## Location
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:159` — `compact_with_ai`: `usage_percent(...) >= threshold` fires every step once over threshold.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:99` — `split_body`: front-anchored split yields ~1 eligible old turn on a long tool-heavy transcript.
- `compaction_ai.ail:176` — `new_pct` recomputed but relief is ~0, yet `Compacted(...)` is still emitted (an AI call was spent).

## Fix (options)
- **Batch, don't drip.** Summarize a meaningful span of old turns (e.g. everything older than `keep_recent`, in one pass) rather than a single turn, so each AI call yields real relief.
- **Guard against no-op summaries.** If the projected/actual relief is below a threshold (e.g. `pct - new_pct < min_relief`), return `PassThrough` instead of spending an AI call and emitting a `Compacted` with 0% change.
- **Persist the summary** (see the ephemeral-compaction issue) so the work compounds across steps instead of being repeated.
- **Rate-limit** AI compaction (don't run on consecutive steps once it just ran and achieved little).

## Notes
- Both issues were masked before the affine-calibration fix on this branch: the multiplicative-ratio bug reported bogus 200–245% usage, so the pathology looked like "calibration wrong." With accurate affine numbers (94–133%), the residual problems are shown to be in the **compactor strategy** (ephemeral application, tier over-escalation, drip summarization), not in the measurement.
- Related: `silent-empty-stop-finalize.md` (the gutted context these issues produce is what drove the step-96 empty-stop finalize).
