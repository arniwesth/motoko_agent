# PLAN: re-derivation & context strategy (pi-grounded)

**Status**: Plan (not started). PLAN-level within the ephemeral model — no persistence change, no ADR.
Refines an already-extension-resident strategy (`../004_phase_core_refactor/ADR-001-phase-oriented-core.md`
D9; `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` §Non-goals).
**Branch**: `arniwesth/mot-38-progress-contract-finalize-guard-extension`
**Grounded at**: HEAD `af615cb` (key anchors re-verified at this commit after the summarizer-hang/degrade
fix landed as `550b8bb`). The sibling `PLAN-compactor-strategy.md` is **already implemented** (`7a8177c`),
so its result-based structural tiering + AI no-op guard are live — but it shipped with different symbol
names than that plan proposed (e.g. `compaction_structural.ail:155` `calibrated_ctx_usage(...) <
result_target_pct()`, not `select_by_result`). Re-grep symbols before trusting any inherited anchor.
**Source issue (normative)**: `../../issues/compaction-rederive-cost-dominates-after-strategy-fixes.md` —
its Recommended-direction list is the acceptance criteria.
**Sibling plan (disjoint)**: `PLAN-compactor-strategy.md` fixes the *strategy* defects (structural
over-escalation, AI drip/no-op, status labeling) and **explicitly excludes** re-derivation, persistence,
and history-bounding. This plan is the residual it parked. **Land that plan first** — its no-op guard and
result-based tier selection are assumed here.

---

## Governance — what this needs to proceed

**The core plan needs no ADR and no ABI change.** WS1+WS2, WS3 (FS-backed), and WS4a are **all
extension-resident** (`compaction_ai.ail`, `types.ail`, `motoko_scratchpad`/new ext,
`compaction_structural.ail`) and touch **zero** core/ABI files — they stay inside the ephemeral doc:52
contract (emit send-only `Compacted`, `st.msgs` untouched) and are pre-authorized by `004/ADR-001` **D9**
(*compaction policy is extension-resident*). The **only** prerequisite is landing the sibling
`PLAN-compactor-strategy.md` first (also a plan, not an ADR).

Two things this plan mentions are **optional and gated behind measurement**, each with a no-decision
fallback already in the core plan — so neither is needed to ship value:

| Optional move | Needs | Fallback that ships without it |
|---|---|---|
| `ADR-001-compaction-persistence.md` (persistent engine) | an **ADR** — it's the *alternative* to WS1/WS2, would **supersede** them, not enable them | WS1/WS2 (ephemeral cache) — the core plan |
| WS4b (faithful in-turn read-guard) | an **ABI note** (addition #1, `on_tool_result`) under D9 — *not* the persistence ADR | WS4a (structural single-result cap) |
| In-band WS3 (artifacts-backed store) | an **ABI note** (addition #2, tool-hook state-write) under D9 | WS3 FS-backed |

Net: **implement WS1+WS2 → WS4a + WS3(FS-backed) with zero decision records.** Revisit the ADR / ABI notes
only if the post-implementation residual justifies them. Trade-off: this is the *more-code* path
(ephemeral-port machinery); the ADR would be less machinery but requires making the doc:52 decision now —
which this plan is deliberately structured to defer.

---

## TL;DR

After the strategy fixes, compaction *works* every step but the run's cost is dominated by
**re-deriving an ever-growing summary from scratch, every step**. A live qwen36 datapoint:
**4.2M billed input tokens** for 20K output — almost entirely re-summarization of history that is
discarded each step (`session.ail:1660` compacted payload is send-only; `:1722`
`msgs_with_assistant = st.msgs ++ [assistant_msg]` keeps the full uncompacted history). On the free-tier
hunyuan run the same mechanism re-summarized ~1,880 turns *per step* from ~step 300 on, and multiplied
the summarizer-hang surface (`../../issues/compaction-summarizer-hang-and-degrade.md`).

The reference small-model harness — **little-coder** (`itayinbarr/little-coder`, primary target
**Qwen3.6-35B-A3B, the exact model these runs use**) on engine **pi** (`earendil-works/pi`) — never pays
this, and the source shows why: compaction is a **rare, persistent, incremental** event, not a per-step
transform. This plan ports pi's cost profile **into the ephemeral model** (audit log untouched) as
extension-resident workstreams:

1. **WS1+WS2 — the compaction engine** (one deliverable): a **cached incremental fold** whose **trigger**
   gates the AI *call* (refresh vs. reuse the cache) on real usage, while still emitting a bounded
   `Compacted` payload every step. Big verbatim tail; pi's `previousSummary`-style merge, cached in
   `artifacts`. This is the core cost fix.
2. **WS3 — Durability layer** (model-controlled evidence store; re-surface a *pointer*, not payload).
3. **WS4 — Input bounding** (read-guard-style truncation of oversized tool reads, gated on live usage).

WS1+WS2 are the core; WS3+WS4 are force-multipliers that let the summary be lossier/cheaper safely.
WS2's engine has **two co-primary variants** — rolling fold (A, pi's mechanism, best for interactive
lengths) and frozen chunk memoization (B, the earlier "Option B", best for long-horizon runs like the
1000-step stress target); build A first, let a drift measurement pick the long-horizon engine (§WS2).
Adopting pi's *persistent* model is a **separate ADR** (see §Decision fork), not this plan.

---

## Prior art, verified from source (2026-07-11)

Read verbatim: `pi/packages/coding-agent/src/core/compaction/compaction.ts` +
`branch-summarization.ts` + `utils.ts`; little-coder `.pi/extensions/{context-watchdog,evidence,
evidence-compact,read-guard}/index.ts`. Decisive mechanics (external `file:line`):

| Mechanism | pi/little-coder source | Motoko today |
|---|---|---|
| Trigger | `compaction.ts:209` `contextTokens > window - reserveTokens(16384)`, `contextTokens` from **real last-assistant `usage`** + trailing estimate (`:176`) | `compaction_ai.ail:361` `pct < threshold` on the **ephemeral calibrated shadow** — always over |
| Frequency | `context-watchdog:96` fires only at `usage ≥ 80%` w/ in-flight lock; persistent → usage drops after | pre-step chain **every step** (`session.ail:1641`) |
| Reuse | `compaction.ts:633` `previousSummary` + `firstKeptEntryId` boundary → fold only new turns (`UPDATE_SUMMARIZATION_PROMPT:474`) | digest cache (`compaction_ai.ail:315`) keyed on the **growing** old-span → misses every step |
| Verbatim tail | `findCutPoint:377` keeps ~`keepRecentTokens(20000)` | `keep_recent` 6–10 **messages** |
| Fidelity | structured schema (`:441`) + cumulative file-op channel (`:812`) + durable evidence store | runtime-status capsule re-injects **data** every summary |
| Timeout | `generateSummary` takes `signal: AbortSignal` (`:546`) | `ai_step` has none (substrate gap) |

**Correction carried from the issue note:** the field is *persistent* and *does* memoize — via a fixed
boundary + incremental merge, not the stable-prefix digest cache first floated here.

---

## Scope, in one screen

All four workstreams stay **within the deliberately-ephemeral per-step model** (`st.msgs` keeps the full
history — `design_docs/planned/m-motoko-conversation-compaction.md:52`; wiring `session.ail:1722`). The
port is: cache the rolling `{summary, boundary}` in the cross-step **artifacts** channel (already the AI
compactor's state channel — `compaction_ai.ail:315` `cached_summary` / `cache_artifact`), keep the audit
log intact.

| WS | Change | Where | Kind |
|---|---|---|---|
| WS1+WS2 | One engine: emit a bounded `Compacted(prefix+summary+tail)` **every** over-threshold step; gate the AI *refresh call* on real `last_sent` usage (reuse cache otherwise); fold only the delta past the boundary; `keep_recent` as a **token budget** (~20k) | `compaction_ai.ail` `compact_with_ai:359` / `split_msgs:206` / `cache_artifact` / `types.ail` | extension |
| WS3 | Model-controlled durable evidence store; re-surface a **pointer** after compaction | new `packages/motoko-ext-*` (or extend `scratchpad`) + capsule at `compaction_ai.ail` `finalize_compaction:351` | extension |
| WS4a | Cap oversized single tool-results in `on_pre_step` (pi's post-exec hook has no ABI equivalent — see WS4) | `compaction_structural.ail` `compact_for_pre_step:158` | extension |

**Out of scope (guardrails — any plan touching these is wrong):**
- Persisting compaction into history / mutating `st.msgs` (`session.ail:1722`). Ephemeral is documented
  (audit / DST replay / un-compaction). The persistent fork is a **separate ADR** (§Decision fork).
- Re-opening token calibration (`src/core/compaction.ail` `affine_calibrate` — shipped, correct; we
  *use* it).
- The strategy defects owned by `PLAN-compactor-strategy.md` (structural tier selection, drip/no-op,
  status labeling). Land that first; this plan assumes its no-op guard.

---

## Pre-step chain composition (ground truth — read before WS1/WS2)

Verified at HEAD: `fold_pre_step_chain_rec` (`src/core/ext/runtime.ail:152`) folds the hooks **in order**,
threading each `Compacted` output into the next hook's input; a `PassThrough` passes `msgs` unchanged.
Live extension order (`config.json`): `… compaction_ai … compaction_structural` — so **`compaction_ai`
runs before `compaction_structural`**, and structural sees whatever AI produced (or the raw msgs if AI
passed through).

Two consequences that constrain this plan:

1. **Structural is not a long-run backstop.** `compaction_structural.elide_walk`
   (`compaction_structural.ail:85`) elides only `role == "tool"` message *content*; **old user /
   assistant / thinking turns pass through untouched** (`:100`). So if `compaction_ai` `PassThrough`s,
   the sent window still accumulates every old prose turn — bounded for tool output, **unbounded for
   conversation**. Over a long run that overflows regardless of structural.
2. **Therefore the AI summary is the only thing that collapses old prose turns** — and in the ephemeral
   model it is discarded every step. So once over threshold the AI compactor must **return a `Compacted`
   payload every step** (`prefix + summary + recent tail`); it must **never `PassThrough` to the raw
   history**. The division of labor is: **`compaction_ai` collapses old prose** (via summary),
   **`compaction_structural` caps tool-result bloat** (via elision). Both are load-bearing.

This is why WS1 (trigger) and WS2 (cache+fold) are **one engine, not two independent steps** — see WS1.

---

## Workstreams

### WS1 — Trigger: gate the AI *refresh call*, not the compaction (ships with WS2)

**Problem.** `compact_with_ai` re-summarizes whenever `pct ≥ threshold` (`compaction_ai.ail:361`), where
`pct` is the calibrated estimate of the ephemeral shadow — which only grows, so it is *always* over
threshold once crossed → a fresh AI fold every step. (In the hunyuan run `rate_limit_enabled` was `false`
by default, so the only gate was the threshold; note also that even with rate-limit *on*, its gate at
`:362` is bypassed once `pct ≥ hard_override_pct`, so a growing shadow defeats it either way.) This is the
frequency half of the cost.

**Key correction (see §Pre-step chain composition).** The trigger does **not** decide "compact or not" —
in the ephemeral model a `PassThrough` sends the raw growing history (structural only trims tool results,
not prose), which overflows on a long run. The compactor must return a `Compacted` payload **every step**
once over threshold; the trigger only decides whether that payload is built from a **fresh AI fold** or by
**reusing the cached summary** (WS2). So WS1 is the *policy* half of one engine whose *mechanism* half is
WS2 — **they ship together; WS1 has no standalone value.**

**Change.** On each over-threshold step, return `Compacted(prefix + cached_summary + tail)` where the
`tail` is **contiguous from the boundary** — `tail = turns after boundary_marker`, recomputed from
current msgs each step (cheap, no AI). This is the key to gaplessness: `cached_summary` covers
`[0..boundary]`, `tail` covers `[boundary+1..now]`, so nothing is ever dropped. Then:
- **Reuse** the cached summary (no AI call) while the `tail` still fits the token budget (~20k) — the tail
  just grows as new turns arrive;
- **Refresh** (one AI fold, WS2 engine) when the `tail` exceeds the budget: fold the oldest slice of the
  tail into the summary, advance `boundary_marker`, shrink the tail back under budget, update the cache.

So the refresh trigger is "the contiguous tail overflowed its budget" (mirrors pi's `findCutPoint` keeping
`keepRecentTokens` back to the last cut point), **not** the shadow `pct`. `ctx.telemetry.last_input_tokens`
/ `ctx.context_limit` (the sibling plan's `last_sent` usage) is a secondary safety check — force a refresh
if the last actual send was over target even when the tail-budget heuristic said reuse.

**Acceptance.** On the qwen36 stress log shape, **AI calls** drop from ~every step (40→99) to
O(evicted-turns / refresh-budget), while the **sent window stays bounded every step** (Compacted-from-cache
on non-refresh steps — never the raw history). DST-checkable via `scripts/long_qwen_compaction_dst.ail`
(assert AI-call cadence *and* that every over-threshold step emits a bounded Compacted payload).

### WS2 — Cached incremental fold + big verbatim tail (engine)

**Problem.** Even when it should fold, `compact_with_ai` re-summarizes the whole old-span from scratch,
and the digest cache (`:315`) misses because the old-span grows each step.

**Common to both engines** (shared by A and B below):
- Make `keep_recent` a **token budget** (~20k, config-driven) rather than a message count — walk the
  tail accumulating calibrated tokens to a cut point that never splits a tool_call from its result
  (Motoko's `split_msgs:206` already respects this; extend it to a token budget).
- Adopt a **structured summary schema** (Goal / Constraints / Progress / Key Decisions / Next Steps /
  Critical Context; preserve exact paths/names) and append a **cumulative file-op line**.
- Cache lives in the `artifacts` channel (extend `cache_artifact`); config via `CompactionAiConfig`
  (`types.ail`) with `keep_recent_tokens` + schema/prompt opt-ins, fallback-safe defaults so existing
  `.motoko` configs still parse.

Two engines produce the cached summary. **They are workload-split co-primaries, not primary/fallback**
(the earlier "A leads, B is the fallback" framing undersold B — see the drift analysis below). **Build A
first** (simpler, and validated on the target model by pi); the drift measurement decides which is the
long-horizon engine.

**Engine A — rolling fold (pi's `previousSummary` mechanism).**
- Store `{summary, boundary_marker, covered_upto}` in artifacts. `boundary_marker` is a stable id/index
  of the last summarized turn (analog of pi's `firstKeptEntryId`).
- Each fold summarizes **only turns after `boundary_marker`**, merged into the cached `summary` via an
  update prompt (analog of `UPDATE_SUMMARIZATION_PROMPT`) — bounded delta input, O(new turns).
- **Best for** typical / interactive-length sessions (pi's workload). **Weakness:** every fold
  re-processes the *whole prior summary* ("PRESERVE all existing… ADD new"), so over a long run the
  oldest information is folded hundreds of times → **cumulative decay**; and it makes an AI call on
  *every* fold event.

**Engine B — frozen chunk memoization (the earlier "Option B"; co-primary for long horizons).**
- Partition the old span into fixed ~20-turn **chunks**; summarize each chunk **once** from source,
  cache by its own content digest; the compacted summary is the concatenation of chunk summaries + tail.
- A completed chunk's digest never changes → it is **never re-summarized**. **No cumulative drift**
  (turn-1's chunk is frozen after one pass) and **~zero steady-state AI cost** (one call per completed
  chunk, ≈1 per 20 steps; pure cache hits otherwise — which also shrinks #3's hang surface further).
- **Best for** Motoko's actual stress target — **1000-step autonomous runs** — where A's decay and
  per-fold cost compound. Cost: more machinery (a chunk map, not one summary) and concatenated summaries
  may read less coherently than A's single evolving one.

**Engine A+B — hybrid (if both weaknesses bite).** Freeze the stable prefix as B-style chunks (no drift,
cached) and rolling-fold only the newest not-yet-frozen span into a single coherent head. Best of both;
most machinery. Note as an option; don't build unless A's coherence *and* B's readability both prove
necessary.

**Acceptance.** Per-fold summarizer *input* is bounded to the delta (not the full history). Cache hits
across steps (the current cross-step miss is gone). Sent window stays under limit. Summarizer-hang
surface shrinks in proportion to fold frequency (WS1) × input size (WS2) — directly relieves
`compaction-summarizer-hang-and-degrade.md`.

### WS3 — Durability layer (evidence store + pointer bridge)

**Problem.** The runtime-status capsule (`finalize_compaction:351` via `latest_runtime_status_result`)
re-injects *data* into every summary; and there is no model-controlled channel for findings the model
wants to keep, so the summary must carry everything → lossy compaction is riskier and the summary is
bigger.

**Change (little-coder's pattern).** Add a model-controlled durable store (tools `EvidenceAdd/Get/List`,
snippet-capped) in **ext-state / artifacts, outside the message array** — Motoko's `scratchpad`
extension is the natural host, so this may be a `scratchpad` extension rather than a new package. After a
fold, re-surface only a **pointer** (`N entries … via EvidenceList/EvidenceGet`), not the payload
(cheaper than the current capsule). Keep the harness-controlled control-state capsule for step
budget/task, but shrink it toward a pointer where possible.

**ABI gap (investigated 2026-07-11).** The `artifacts` state channel is **write-only from
`on_pre_step`**: `PreStepDecision.Compacted(msgs, note, artifacts)` is the *only* hook return that
carries `artifacts` back (`types.ail:143`); `on_tool_handle` returns `Handled | Delegate` with **no**
state-write channel. So a model-controlled `EvidenceAdd` tool **cannot persist into `artifacts` across
steps** today — extension-only, it must be **FS-backed** (write a scratchpad file via the `FS` effect,
which `on_tool_handle` has), then read back in `on_pre_step`. That works but is out-of-band and not
DST-deterministic. A clean, in-band store needs ABI addition #2 (§ABI additions). **WS3 ships FS-backed
by default; upgrade to the artifacts-backed store if #2 lands.**

**Acceptance.** Findings survive compaction without living in the summarizable window; post-fold
re-injection cost is a pointer line, not the data. Deterministic bridge string (replay-stable), tested in
the extension's `_smoke.ail`.

### WS4 — Input bounding (read-guard)

**Problem.** Nothing stops a large tool read from entering the window, so the shadow reaches 638% and
forces heavy folds. The stress task reads big files in full every phase; real workloads do too.

**ABI investigation (resolved 2026-07-11 — see `../../issues/compaction-rederive-cost-dominates-after-strategy-fixes.md`).**
pi's `read-guard` hooks a **post-execution** `tool_result` event to observe-and-replace a read's output.
Motoko's ABI has **no such hook** and cannot get one extension-only:
- `ExtensionHooks` (`packages/motoko-ext-abi/types.ail:147`) exposes only *pre-execution* tool hooks —
  `on_tool_policy` (Allow/Deny) and `on_tool_handle` (`Handled` = the extension *produces* the whole
  result / `Delegate` = never sees it). Neither observes a harness-produced result to trim it.
- Builtins bypass the hook layer entirely: `dispatch_tool_entries_with_builtin`
  (`src/core/tool_phase.ail:318`) tries `builtin(call)` **first** and short-circuits on `Some`;
  `ReadFile` is a builtin (`tool_runtime.ail:167` `run_read_file`), so it never reaches
  `on_tool_policy`/`on_tool_handle`.

So the literal pi port is **not** extension-only. Two options:

- **WS4a (recommended — ABI-native, no core change).** `on_pre_step` sees the whole `[Msg]` and can
  return a trimmed `Compacted` payload — and `compaction_structural` already elides tool-result content
  there (`compact_for_pre_step:158` → `elide_old_tool_results` → `elide_content`). Extend it to also cap
  **any single** tool-result over a token threshold, *even inside* the `keep_last` verbatim window
  (currently 10/5/3/1 recent results are kept whole, so one huge recent read still lands full),
  replacing the overflow with head + "search instead (grep / offset+limit); do not re-read in full".
  A few lines in `elide_walk`/`compact_for_pre_step`, reusing `elide_content`; deterministic (no AI).
  **Difference from pi:** trim is applied at *send time* (model sees it next step), not in the same
  turn. Acceptable for context bounding.
- **WS4b (faithful port — needs ABI + core change).** ABI addition **#1** (§ABI additions): an
  `on_tool_result` hook giving the in-turn trim + directive pi has. Escalate WS4a→WS4b only if the
  next-step delay of WS4a is measured to matter — but note #1 is worth landing on its own merits
  (it unlocks a whole extension family, not just read-guard), so if #1 lands for other reasons, WS4b
  becomes the default read-guard implementation.

**Change (WS4a).** Cap oversized single tool-results in `compaction_structural.compact_for_pre_step`,
using **Motoko's own** per-message size estimate (`compaction.ail`'s char/4 estimator / the module's
`calibrated_usage_percent_with_limit` — **not** little-coder's 3.5 ratio) against `ctx.context_limit`.
Uniform harness-intervention-style note in the elision.

**Acceptance.** An oversized read never lands whole in the *sent* window (even when recent); small reads
pass untouched. DST scenario: a big-file read at high usage is trimmed to head+directive on the next
send; at low usage it is not.

---

## Blast radius — every file touched

| File | WS | Kind | Change |
|------|----|------|--------|
| `packages/motoko-ext-compaction-ai/compaction_ai.ail` | 1,2 | extension | Real-usage trigger + in-flight/min-gap guard in `compact_with_ai:359`; `{summary,boundary}` cache via `cache_artifact`; delta-only fold + update prompt; token-budget tail via `split_msgs:206`; structured schema + file-op line in `finalize_compaction:351`. New WS1/WS2 unit tests. |
| `packages/motoko-ext-compaction-ai/types.ail` | 1,2 | extension | `keep_recent_tokens`, schema/update-prompt opt-ins, trigger tunables on `CompactionAiConfig` + `default_config` (fallback-safe). |
| `packages/motoko_scratchpad/*` (or new `motoko-ext-evidence`) | 3 | extension | `EvidenceAdd/Get/List` durable store + post-fold pointer bridge; `_smoke.ail`. |
| `packages/motoko-ext-compaction-structural/compaction_structural.ail` | 4a | extension | Cap any single oversized tool-result in `compact_for_pre_step:158` / `elide_walk`, reusing `elide_content`. New unit test. **No new package** (pi's post-exec hook has no ABI equivalent — see WS4). |
| *(WS4b only)* `packages/motoko-ext-abi/types.ail` + `src/core/tool_phase.ail` + all ext hook records + conformance | 4b | **ABI + CORE** | New `on_tool_result` hook. Separate ABI note (004/ADR-001 D9). Only if WS4a's next-step delay is measured to matter. |
| `scripts/long_qwen_compaction_dst.ail` | 1,2 | test | Fold-cadence + bounded-input + cache-hit-across-steps scenarios. |
| `.motoko/config/*/compaction_ai.json` | 1,2 | config | Set `keep_recent_tokens` etc. for the live profiles (esp. hunyuan3/qwen36). |

**Does NOT touch (WS1/WS2/WS3/WS4a):** `src/core/compaction.ail` (calibration — frozen), `st.msgs` /
history persistence (`session.ail:1722` — the ephemeral guarantee), the `ExtensionHooks` /
`PreStepDecision` ABI (`packages/motoko-ext-abi/types.ail`). **WS4a is deliberately routed through
`on_pre_step` inside `compaction_structural` precisely because the ABI has no post-execution
tool-result hook and builtins bypass the pre-execution ones** (`tool_phase.ail:318` builtin-first) — so
WS4a needs no ABI change. Only the optional **WS4b** touches the ABI/core, and it is gated behind its own
note.

---

## Verification

- **Offline/deterministic:** `make compaction_dst` + new `long_qwen_compaction_dst.ail` scenarios
  (fold cadence, delta-bounded input, cross-step cache hit, read-guard trim/pass). `make conformance`
  for ABI. Per-package `_smoke.ail` for WS3/WS4 boot + behavior.
- **Live corroboration:** re-run `make live_qwen36_compaction_heavy_headless` and confirm the
  **summarizer input** collapses (delta-only folds instead of re-reading the full growing history) and
  **AI-fold count** drops from ~every-step to O(run/tail-budget) — the two components that made up most of
  the 4.2M-input datapoint. Total billed input also drops but is floored by the per-step main-model send
  (~compacted payload × steps), so expect a large drop, not necessarily a full order of magnitude. Sent
  window stays under limit and the model stays productive (`finish_reason:"tool_calls"` per step). Re-run
  `live_hunyuan3_free_compaction_heavy_headless` and confirm folds are rare and no summarizer hang
  recurs.
- **Gate the slice:** `AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail`
  and `MOTOKO_CONFIG=hunyuan3-free-compaction-live make verify_extensions`.

---

## ABI additions (if an ABI change is allowed)

WS1/WS2 (the compaction engine) are **extension-only regardless** — WS1 gates on real usage via
`ctx.telemetry` + `ctx.context_limit` (already in `ExtCtx`), WS2 caches in `artifacts` (already threaded
through `on_pre_step`). An ABI change does **not** simplify them and they should stay extension-resident.
Where an ABI change *does* pay off is the **input-bounding and durability** layers — the little-coder
"prevent growth upstream" family that Motoko's ABI currently cannot express at all. Three candidate
additions, ranked:

| # | Addition | Unlocks | Blast radius | Governed by |
|---|---|---|---|---|
| **1** | `on_tool_result: (ExtCtx, ToolResultEnvelope) -> Keep \| Replace(ToolResultEnvelope)`, fired after `builtin(call)` / `execute_allowed_tool_call` in `dispatch_tool_entries_with_builtin` (`tool_phase.ail:314-357`) | **WS4b** + the whole read-guard / write-guard / output-parser / retention family (little-coder builds ~4 extensions on this surface) | ABI type + core dispatch (**must envelope builtin results** — they emit a `Message` directly at `:320`, so core does result→envelope→hook→message) + every ext hook record + conformance + noop ports | `004/ADR-001` D9 |
| **2** | State-write for tool hooks: let `on_tool_handle` (and #1's `on_tool_result`) return updated `artifacts` (or a dedicated per-ext state channel) | Clean, DST-deterministic model-controlled store (**WS3** in-band instead of FS-backed); any stateful ext tool | ABI decision types + core threading; same hook records | `004/ADR-001` D9 |
| **3** | `on_post_compaction` event (or fold into #2) | Cross-extension pointer bridge after a fold (evidence ext ≠ compaction ext) | small; avoidable if evidence+compaction coordinate via shared `artifacts` | — |

**#1 is the highest-leverage single addition** — general, and the thing little-coder proves matters most
(rare compaction + aggressive upstream bounding). **#2** is a smaller complementary fix that de-risks WS3.
Both are ABI-boundary changes → each needs its own note under `004/ADR-001` D9 before implementation.
Recommendation: land **#1** on its own merits (independent of WS4a↔WS4b); do **#2** if WS3 is in scope;
**#3** only if the bridge can't be coordinated via `artifacts`.

**What an ABI change does *not* do:** it removes the *mechanical* blocker for persistent compaction (a
`st.msgs` write-back) but does **not** resolve the doc:52 decision — see below.

---

## Decision fork — persistence (separate ADR)

3 of 4 surveyed agents (Claude Code, Codex, OpenCode) are **persistent**; pi is persistent too. A new
`PreStepDecision` variant that the core writes back to `st.msgs` (instead of send-only) would let Motoko
adopt pi's model directly and **retire WS1/WS2's ephemeral-specific machinery** — the per-step
Compacted-from-cache reconstruction and boundary bookkeeping that exist *only* because ephemeral discards
the result. (The trigger and the incremental fold themselves remain — that's what pi does — so persistence
simplifies, it doesn't delete, the engine.) That is the cheapest long-term engine.

But it overturns doc:52's ephemeral guarantee (*"the returned `msgs` replaces the input for this step
only — the session log is unchanged"*; audit / DST replay / un-compaction). An ABI change makes it
*implementable*; whether doc:52's guarantee is load-bearing enough to keep is a **decision on its own
merits**, not a free win. Tracked as `ADR-001-compaction-persistence.md` (Proposed). This plan delivers
value **without** forcing that decision; the ADR can supersede WS1/WS2 later if it lands persistent.

---

## Sequencing

1. Land `PLAN-compactor-strategy.md` (no-op guard, result-based tiering) — prerequisite.
2. **WS1+WS2 together** (the engine — WS1 is not viable alone; see §Pre-step chain composition). The
   cache/trigger must land as one change: emit a bounded `Compacted` every over-threshold step, AI-fold
   only on refresh. Build **Engine A** (rolling fold) first (simpler, pi-validated); measure summary
   drift over a long (≥several-hundred-step) run → keep A for interactive lengths, switch to **Engine B**
   (frozen chunks) for the long-horizon path if decay shows (hybrid only if both bite).
4. **WS4a** (structural single-result cap) and **WS3** (evidence, FS-backed) in parallel —
   force-multipliers; independent of WS1/WS2.
5. **Re-measure live.** Then decide two independent things against the residual:
   - **ABI additions** (§ABI additions) — land #1 (`on_tool_result`) if the upstream-bounding family is
     wanted (promotes WS4a→WS4b, WS3→in-band via #2). Each needs its own note under `004/ADR-001` D9.
   - **Persistence** — `ADR-001-compaction-persistence.md` (Proposed stub). Resolve *is doc:52
     load-bearing?* first; if not (esp. if the append-only ledger already affords the audit side-channel),
     persistent supersedes WS1/WS2. Open only if the post-WS1/WS2 residual justifies a core change.
