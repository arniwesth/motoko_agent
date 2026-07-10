# Ephemeral re-derivation is now the dominant compaction cost (post strategy-fix live datapoint)

## Status
open — documented tradeoff, not yet actioned (Consequence 1 of
[`ephemeral-compaction-and-ai-noop-thrash.md`](ephemeral-compaction-and-ai-noop-thrash.md))

## Branch
arniwesth/mot-38-progress-contract-finalize-guard-extension

## Description
Follow-up live datapoint from a `make live_qwen36_compaction_heavy_headless` run captured while
validating the progress-contract finalize guard. It is **not a new defect** — it is confirmation
that the two *actionable* problems in `ephemeral-compaction-and-ai-noop-thrash.md` no longer
reproduce, which leaves the **every-step re-derivation of an ever-growing history** (that issue's
Consequence 1, explicitly parked as out-of-scope) as the salient remaining cost.

The surprising-on-first-read symptom: AI compaction fires on essentially **every step from 40 to
99** even though each pass reduces the window "significantly" (76% → 2–4%). That makes sense only
once you internalise that compaction is **ephemeral by design**
(`design_docs/planned/m-motoko-conversation-compaction.md:52` — the compacted `msgs` replace the
input *for that step only*; the session log is unchanged). The compacted payload feeds
`dispatch_step(...)` and is then discarded; the persisted `st.msgs` keeps the full append-only
history and grows by one turn every step. The compaction **trigger** re-evaluates against that
growing uncompacted history, which is always over threshold, so a fresh summary is recomputed
every step. The large per-pass reduction buys **zero** headroom for the next step.

## Evidence
Log: `.motoko/logfile/session_2026-07-10T13-34-50-052Z.jsonl`
(model `openrouter/qwen/qwen3.6-35b-a3b`, profile `qwen36-compaction-live`,
`finish_reason:"max_steps"`, 100 steps, 430s).

**Ephemeral re-derivation, every step.** 61 `compaction_extension` events; AI compaction on
essentially every step 40→99. The compactor input grows without bound while the sent window stays
flat — proof the input is the un-persisted history each time:

| | turns summarized | before % | sent to provider (billed input) |
|---|---|---|---|
| step 40 | 171 | 76% | ~17K → 22K tok |
| step 44 | 191 | 78% | ~6K → 9K tok |
| step 78 | 281 | 100% | ~7K → 9K tok |
| step 99 | 336 | 118% | ~4K → 7K tok |

`before %` marches 76% → 118% (the raw history now exceeds one context window) while the **sent**
window holds at ~9K tokens (~3% of the 262K limit). Total billed input for the run:
**4,238,117 tokens** for 20,490 output tokens — i.e. the run's cost is almost entirely
re-summarization of history that is thrown away each step.

**The two actionable defects from the prior issue did NOT reproduce here:**
- *No emergency over-escalation.* Structural stayed at `tier1 keep_last=10` (steps 39/41/43); it
  did not pin to `emergency keep_last=3`. The sent window is gutted far less than the prior run
  (~9K here vs the ~13K-at-emergency thrash in `session_2026-07-09T20-50-38-105Z.jsonl`).
- *No 1-turn no-op drip.* AI compaction batched **real** spans (171, 185, 191 … 336 turns) with
  **real** relief (76% → 2–4%), not the earlier `AI-summarized 1 turns (142% -> 142%)` 0%-relief
  pattern. The batch/no-op-guard fixes appear to have landed.

**Run health (separate concern).** Every one of the 100 steps ended `finish_reason:"tool_calls"`
(1–6 calls) — no bare stop candidate — so neither the empty-stop nor progress-contract guard was
ever consulted (`ext_solver_feedback=0`). The run terminated cleanly on the step budget
(`max_steps:100`), which is **half** the task's 200-turn target, so it was always going to hit the
budget wall barring a premature give-up. So: heavy sustained compaction, model stayed productive
under it, guards correctly silent. This is the healthy counterpart to
[`silent-empty-stop-finalize.md`](silent-empty-stop-finalize.md).

## Location
- `src/core/session.ail:1640` — pre-step compactor `ctx` is built from full `st.msgs`.
- `src/core/session.ail:1641,1660,1676` — `chain.msgs` → `compacted_msgs` used **only** for
  `dispatch_step(...)` and the sent-window estimate.
- `src/core/session.ail:1686,1794` — next-state `msgs` is `st.msgs` / `st.msgs ++ [assistant]`
  (full uncompacted history); `compacted_msgs` is never written back.
- `packages/motoko-ext-compaction-ai/compaction_ai.ail` — AI compactor re-runs on the full growing
  history each step (now batched + effective, but still re-derived from scratch).

## Consequences
1. **Cost, not correctness.** The window stays sendable every step (compaction *works*); the
   pathology is purely economic — an effective AI-summarizer call per step, and a ~4.2M-input-token
   run dominated by re-summarizing discarded history. Latency and $ scale with step count on any
   long tool-heavy session.
2. **Unbounded retained history.** `st.msgs` grows to 336 turns / 118% and is re-elided from
   scratch every step. This follows directly from the documented "session log is unchanged"
   decision and is **not** fixable without revisiting that decision.

## Possible directions (none in scope without a decision)
- **Memoize the ephemeral compaction** across steps: cache the summary of the stable prefix keyed
  by a digest of the turns it covers, so an unchanged prefix isn't re-summarized every step. This
  keeps the persisted log unchanged (audit/replay intact) while removing the redundant AI calls —
  it is a *cache*, not persistence. Likely the highest-leverage option.
- **Rate-limit / relief-guard** consecutive AI passes (already contemplated in the prior issue's
  section 2) so the compactor doesn't pay for a full re-summary every single step once the prefix
  hasn't materially changed.
- **Revisit retained-history growth** as a separate decision (bounded working set + seed replay)
  only if long-session cost/rework becomes a real constraint — this overturns the "session log
  unchanged" tradeoff and must be argued on its own merits, not slipped in here.

## Notes
- This note is deliberately separate from `ephemeral-compaction-and-ai-noop-thrash.md` (whose two
  sub-issues are marked *implemented*): it records the **post-fix** live behavior and reframes the
  remaining cost as re-derivation, not tier over-escalation or drip no-ops.
- Cross-refs: `check-design-docs-before-proposing-adr` memory (ephemeral is decided, doc:52);
  `004_phase_core_refactor/ADR-001` D9 (compaction strategy is extension-resident);
  `silent-empty-stop-finalize.md` and the progress-contract guard (this run is the non-failure case
  those guards are meant to backstop).
