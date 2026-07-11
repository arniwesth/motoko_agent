# Ephemeral re-derivation is now the dominant compaction cost (post strategy-fix live datapoint)

## Status
open — source-grounded against prior art (2026-07-11); plan drafted
(`../projects/006_compactor_strategy/PLAN-rederivation-context-strategy.md`). Residual of Consequence 1
of [`ephemeral-compaction-and-ai-noop-thrash.md`](ephemeral-compaction-and-ai-noop-thrash.md), which the
already-scoped [`PLAN-compactor-strategy.md`](../projects/006_compactor_strategy/PLAN-compactor-strategy.md)
explicitly excludes.

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

## Prior art — how other agents avoid this (read from source, 2026-07-11)

Surveyed Claude Code / Codex CLI / OpenCode / Amp (secondary sources) and **read the source verbatim**
for `little-coder` (`itayinbarr/little-coder`) + its engine `pi` (`earendil-works/pi`,
`@earendil-works/pi-coding-agent`). little-coder is the load-bearing datapoint: it is a small-model-first
harness whose **primary tuning target is Qwen3.6-35B-A3B — the exact model this issue's runs use.**

**The field never hits this cost, because compaction is a rare, persistent, incremental event — not a
per-step transform.** Verbatim from `pi/packages/coding-agent/src/core/compaction/compaction.ts`:
- **Trigger on real usage.** `shouldCompact = contextTokens > contextWindow - reserveTokens` (`:209`,
  `reserveTokens` 16384). `contextTokens` (`estimateContextTokens`, `:176`) is the **last assistant
  message's actual provider `usage`** plus an estimate of only the *trailing* messages — ground truth,
  not a from-scratch calibrated estimate of a growing shadow. After a persistent compaction it drops and
  *stays* down, so compaction fires seldom.
- **Incremental / memoized by boundary.** `prepareCompaction` (`:633`) sets
  `previousSummary = prevCompaction.summary` and `boundaryStart = prevCompaction.firstKeptEntryId`, so
  only messages **since the last compaction** are summarized, folded into the prior summary via
  `UPDATE_SUMMARIZATION_PROMPT` (`:474`). Bounded delta input per compaction — memoization via
  persistence + a boundary id, not content-addressed chunks.
- **Big verbatim tail.** `findCutPoint` (`:377`) keeps ~`keepRecentTokens` (20000) verbatim; cuts only
  at valid points (never a `toolResult`).
- **Structured summary schema as a fidelity contract** (`:441`): Goal / Constraints / Progress
  (Done/In-Progress/Blocked) / Key Decisions / Next Steps / Critical Context, "preserve exact file
  paths, function names, error messages". Plus a **separate cumulative file-op channel** appended to
  every summary (`readFiles`/`modifiedFiles`, `:812`) — kept *out* of the lossy prose.
- **Cancellable summarizer.** `signal?: AbortSignal` threaded through `generateSummary` (`:546`) — the
  reference has exactly the per-call timeout Motoko's `ai_step` lacks (ties to
  `compaction-summarizer-hang-and-degrade.md`).

little-coder layers *around* that engine (all verbatim-read):
- `context-watchdog/index.ts` — fires `ctx.compact()` on `turn_start` **only when live
  `getContextUsage()` ≥ 80%** with an in-flight `compacting` lock; `ctx.compact()` is persistent
  ("summarizes, then reconnects the agent"), resumed via a `RESUME_MESSAGE`.
- `read-guard/index.ts` — replaces a `read` **tool_result** with its first `HEAD_LINES` (30) + a
  "search instead (grep/offset-limit)" directive **only when `currentTokens + est > contextWindow`**
  (`est = ceil(chars/3.5)`); keeps oversized files out of context at the source.
- `evidence/index.ts` + `evidence-compact/index.ts` — a model-controlled durable store
  (`EvidenceAdd/Get/List`, 1 KB snippet cap) held in **extension-state, outside the message array**, so
  it survives compaction automatically; after `session_compact` the model gets only a **pointer** back
  (`N entries … via EvidenceList/EvidenceGet`), not the payload.

**Corrections to earlier framing in this file:** the field is *persistent*, and it *does* memoize —
just via persistence + a boundary pointer + incremental `previousSummary` merge, not the
"digest of the stable prefix" chunk cache this note first floated. Motoko's existing digest cache
(`compaction_ai.ail:315` `cached_summary`) misses every step precisely because it keys on the whole
*growing* old-span; pi keys on a *fixed* boundary and folds only the delta.

## Recommended direction (within the ephemeral model — no persistence change)

Port pi's cost profile into the ephemeral model by caching the rolling summary + boundary in the
cross-step **artifacts** channel (audit log in `st.msgs` untouched — `session.ail:1722`). Sequenced by
leverage:

1. **Trigger on real usage, not the growing shadow (highest leverage, cheapest).** Gate the AI pass on
   *actual* current context usage crossing a threshold with an in-flight guard, instead of
   `pct < threshold` against the ephemeral shadow that is *always* over threshold
   (`compaction_ai.ail:361`; the rate-limit at `:362` is additionally bypassed at
   `pct ≥ hard_override_pct`, which is why it fired every step at 638%). Removes most re-derivations and
   shrinks the summarizer-hang surface — independent of the engine choice.
2. **Cached incremental fold + big verbatim tail (engine).** Cache `{summary, boundary}` in artifacts;
   each pass folds prior summary + only the turns past the boundary (pi's `previousSummary` merge,
   moved to ext-state); raise `keep_recent` to a **token budget** (≈20k), not 6–10 messages. Adopt the
   structured summary schema + a cumulative file-op line so lossy summaries stay safe. *(This is the
   incremental-fold "Option A"; content-addressed chunk memoization is the fallback if merge-drift
   degrades quality.)*
3. **Durability layer.** A model-controlled evidence store (Motoko's `scratchpad` ≈ this) surfaced
   after compaction with a **pointer, not payload** — cheaper than the current re-inject-the-data
   runtime-status capsule, and it lets the summary be lossier/cheaper safely.
4. **Input bounding.** A `read-guard`-style truncation of oversized tool reads gated on live usage, so
   the shadow rarely grows large in the first place. **ABI note (investigated 2026-07-11):** pi's
   `read-guard` uses a *post-execution* `tool_result` hook; Motoko's ABI has none, and builtins
   (`ReadFile`) bypass the pre-execution tool hooks entirely (`tool_phase.ail:318` builtin-first;
   `ExtensionHooks` at `motoko-ext-abi/types.ail:147` has only `on_tool_policy`/`on_tool_handle`). So the
   pi port is **not** extension-only. Do it ABI-natively by capping oversized single tool-results inside
   `compaction_structural`'s existing `on_pre_step` elision (which already trims tool-result content but
   keeps the last N verbatim); a faithful in-turn hook is a separate ABI change (004/ADR-001 D9). See the
   plan's WS4.

**Separate ADR-level fork (out of scope here):** adopt pi's *persistent* model (summary replaces
history) and delete re-derivation outright. 3 of 4 surveyed agents chose persistent; whether doc:52's
audit/replay guarantee is load-bearing enough to keep is its own decision, not this note's to make.

Plan: `../projects/006_compactor_strategy/PLAN-rederivation-context-strategy.md`.

## Notes
- This note is deliberately separate from `ephemeral-compaction-and-ai-noop-thrash.md` (whose two
  sub-issues are marked *implemented*): it records the **post-fix** live behavior and reframes the
  remaining cost as re-derivation, not tier over-escalation or drip no-ops.
- Cross-refs: `check-design-docs-before-proposing-adr` memory (ephemeral is decided, doc:52);
  `004_phase_core_refactor/ADR-001` D9 (compaction strategy is extension-resident);
  `silent-empty-stop-finalize.md` and the progress-contract guard (this run is the non-failure case
  those guards are meant to backstop).
