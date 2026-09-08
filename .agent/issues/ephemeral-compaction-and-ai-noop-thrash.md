# Structural compaction over-escalates to emergency tier under sustained overflow (ephemeral model is by-design)

## Status
implemented

## Branch
arniwesth/mot-34-layer-2-harness-boundary

## Description
> **Framing correction (2026-07-10):** an earlier version of this issue framed *ephemeral
> compaction* itself as the defect and proposed "persist compaction into history" as a fix. That
> is wrong. Ephemeral compaction is a **deliberate, documented decision**:
> `design_docs/planned/m-motoko-conversation-compaction.md:52` — *"the returned `msgs` replaces the
> input **for this step only** — the session log is unchanged."* It is consistent with the
> phase-core design (history reconstructed from a seed via `history_from_seed`; append-only ledger).
> So the retained full history is intentional (audit / session-log fidelity / DST replay), and the
> actual defects here are **within** the ephemeral model: the structural tier ladder over-escalates,
> the AI compactor no-ops (second section), and the observability conflates two windows. "Persist
> into history" would overturn a documented decision and is **out of scope** unless the
> retained-history-growth tradeoff is separately revisited (see Consequence 1).

Under the compaction stress task (`make live_qwen36_compaction_heavy_headless`, model `openrouter/qwen/qwen3.6-35b-a3b`), compaction is applied **ephemerally per step (by design)**: each step the compactor chain runs on the full, ever-growing uncompacted history to produce a compacted payload *for sending only*; the persisted next-state history is the full uncompacted history plus the new assistant turn. The problem is not the ephemerality — it is how the structural tier is *selected* against that ever-growing uncompacted window.

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
1. **Unbounded retained history (documented tradeoff, not a defect to fix here).** `st.msgs` grows without bound and the full history is re-elided from scratch every step. This follows directly from the "session log is unchanged" decision above, so it is **not** in scope for this issue. If long-session memory/rework becomes a real problem, it should be revisited via a NOTE/decision grounded against *why* the log-unchanged choice was made (audit / replay / un-compaction) — not by silently mutating persisted history here.
2. **Over-escalation to emergency tier → context gutted.** The structural ladder (`compact_for_pre_step`) picks its tier from the *uncompacted* calibrated pct: `>= emergency_pct (95)` → `keep_last=3`. Because the uncompacted shadow keeps climbing (calibrated 94% → 114% → 133% in this run), it pins to emergency and the **sent** window is gutted to ~15K — the model runs on ~6% of the 262K limit it actually has. This is the same context-gutting that produced the step-96 empty-stop "silent death" (`silent-empty-stop-finalize.md`).
3. **Wrong question for tier selection.** The ladder asks "how full is the uncompacted window?" (133%) rather than "what is the least elision that puts the *sent* window under the limit?" At `keep_last=10` (tier1) a 300-message history is already far under limit, so emergency `keep_last=3` is unnecessary over-compaction.
4. **Misleading observability.** With ephemeral compaction, `MotokoRuntimeStatus.context_window.calibrated_usage_pct` (uncompacted shadow, 114%) and `.actual_usage_pct` (last sent window, 10%) measure *different windows*, so the metric reads as self-contradictory once compaction is active.

## Location
- `src/core/session.ail:1627,1643,1659,1697` — compacted payload used only for send; `msgs_with_assistant = st.msgs ++ [assistant_msg]` persists the uncompacted history.
- `src/core/session.ail:1267` — `c2_pending_context` returns the uncompacted shadow.
- `packages/motoko-ext-compaction-structural/compaction_structural.ail` — `compact_for_pre_step` tier ladder keyed off uncompacted pct; no "minimal elision to get under limit" check.

## Fix (all within the ephemeral model — no persistence change)
- **Select the structural tier by *result*, not by uncompacted pct.** Pick the gentlest `keep_last` whose resulting *sent* window is under a target pct (e.g. try tier1 → hard → emergency and stop at the first that fits), instead of jumping to emergency because the uncompacted shadow reads >95%. This directly fixes the over-escalation: at `keep_last=10` a 300-message history is already far under limit, so emergency `keep_last=3` is unnecessary. Purely a change to `compact_for_pre_step`'s selection logic (extension-side, per 004 `ADR-001` D9).
- **Fix the observability** so the metric is not self-contradictory: make the status tool's `est`/`calib` measure the same window as `actual` (the sent window) once compaction is active, **or** relabel them explicitly as "uncompacted pending" vs "last sent" so a 114%-vs-10% reading is legible rather than alarming.
- **Explicitly out of scope:** persisting compaction into history (overturns the documented ephemeral decision) and bounding retained-history growth (a separate revisit of the "session log unchanged" tradeoff — see Consequence 1).

This is **PLAN-level work, not an ADR** — it refines an already-extension-resident strategy without changing any documented decision. Tracked in `../projects/006_compactor_strategy/` (`HANDOFF-write-compactor-strategy-plan.md` → `PLAN-compactor-strategy.md`).

---

# AI compactor no-op thrash: summarizes 1 turn for 0% relief, every step

## Status
implemented

## Branch
arniwesth/mot-34-layer-2-harness-boundary

## Description
Once the AI compaction threshold is crossed, `compact_with_ai` fires **every step** but summarizes exactly **one** old turn and achieves **~0% relief**, burning an AI summarizer call per step for no benefit.

Evidence — same session:
- `AI-summarized 1 turns (75% -> 75%)` (step 61), `... (131% -> 131%)` (step 110), `... (133% -> 133%)` (step 112) — the before/after calibrated pct is identical, and it is always "1 turns."
- `compaction.compaction_ai_applied` reached 32 by step 92 — i.e. an AI call on ~every step past the threshold.

Two compounding causes:
1. **Only 1 turn is ever eligible.** `split_body(body, keep_recent)` walks from the front and stops at the first turn that is protected (fewer than `keep_recent` messages remain, or a message whose tool_calls have a matching tool result in the tail). On this transcript that yields a single "old" turn per step, so each summary replaces one turn out of ~300 — negligible.
2. **Re-run from scratch each step (by design).** Because compaction is ephemeral (see section 1 — this is intentional), the 1-turn summary is recomputed every step; the `0% -> 0%` relief reflects that summarizing 1 of ~300 turns barely moves the total. The fix is *not* to persist the summary (that would overturn the documented ephemeral decision) but to make each ephemeral pass actually effective (batch) and to stop paying for passes that aren't (no-op guard, rate-limit).

Net: an AI request (latency + tokens + cost) every step that changes nothing.

## Location
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:159` — `compact_with_ai`: `usage_percent(...) >= threshold` fires every step once over threshold.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail:99` — `split_body`: front-anchored split yields ~1 eligible old turn on a long tool-heavy transcript.
- `compaction_ai.ail:176` — `new_pct` recomputed but relief is ~0, yet `Compacted(...)` is still emitted (an AI call was spent).

## Fix (options — all within the ephemeral model)
- **Batch, don't drip.** Summarize a meaningful span of old turns (e.g. everything older than `keep_recent`, in one pass) rather than a single turn, so each AI call yields real relief.
- **Guard against no-op summaries.** If the projected/actual relief is below a threshold (e.g. `pct - new_pct < min_relief`), return `PassThrough` instead of spending an AI call and emitting a `Compacted` with 0% change.
- **Rate-limit** AI compaction (don't run on consecutive steps once it just ran and achieved little).
- **Out of scope:** persisting the summary into history — overturns the documented ephemeral decision (see section 1). The fixes above make each ephemeral pass effective instead.

## Notes
- Both issues were masked before the affine-calibration fix on this branch: the multiplicative-ratio bug reported bogus 200–245% usage, so the pathology looked like "calibration wrong." With accurate affine numbers (94–133%), the residual problems are shown to be in the **compactor strategy** (tier over-escalation, drip summarization) — *within* the deliberately-ephemeral model — not in the measurement and not in the persistence decision.
- Related: `silent-empty-stop-finalize.md` (the gutted context these issues produce is what drove the step-96 empty-stop finalize).
