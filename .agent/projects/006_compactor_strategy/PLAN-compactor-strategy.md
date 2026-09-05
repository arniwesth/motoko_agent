# PLAN: compactor-strategy refinement

**Status**: Plan (not started). PLAN-level, not an ADR — refines an already-extension-resident
strategy without overturning any documented decision (`../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`
§Non-goals; `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` D9).
**Branch**: `arniwesth/mot-35-fix-context-size-estimation`
**Grounded at**: HEAD `aeb8a69` (all `file:line` anchors below verified at this commit).
**Source issue (normative)**: `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — the two
sections' Consequences + Fix lists are the acceptance criteria.

---

## TL;DR

The compactor works *ephemerally by design* (send-only payload; full history retained) — that stays.
Three strategy bugs *within* that model:

1. **Structural over-escalates.** It picks the elision tier from the *uncompacted* window's calibrated
   pct (which reads 114-133% because the anchor is the last compacted window), so it pins to emergency
   `keep_last=3` and guts the sent window to ~5% of the limit. **Fix:** pick the **gentlest**
   `keep_last` whose *resulting* window lands under **70%**, measured with the same affine calibration
   — so a 300-message history compacts to `keep_last=10`, not emergency. Extension-only.
2. **AI compactor thrashes.** It summarizes ~1 old turn for ~0% relief *every step*, spending an AI
   call each time. **Fix (load-bearing):** **batch** (summarize everything older than `keep_recent`,
   pairs intact) + **pre-call no-op guard** (project relief before spending the call; `PassThrough` if
   trivial). **Plus an optional** **rate-limit** (skip re-summarizing for a few *later* steps after a
   real pass, `95%` override) — state in the cross-step **artifacts** channel, `gap > 0` guard
   required to keep the `artifact_cache_effective` invariant green. Ship it behind a flag.
   Extension-only.
3. **Status tool lies.** `context_window` mixes the uncompacted-pending window (`calibrated 114%`)
   with the last-sent window (`actual 10%`), reading as self-contradictory. **Fix:** **relabel** into
   `last_sent` vs `uncompacted_pending` sub-objects + a `note`. The only **core** touch; pure
   presentation.

Verification is offline/deterministic via the existing `make compaction_dst` + `make conformance`
harnesses plus new scripted-provider scenarios. See [Blast radius](#blast-radius--every-file-touched)
for the exact file list.

---

## Blast radius — every file touched

| File | WS | Kind | Change |
|------|----|------|--------|
| `packages/motoko-ext-compaction-structural/compaction_structural.ail` | 1 | **extension** | New `select_by_result` + `result_target_pct` helpers; rewrite **selection** inside `compact_for_pre_step` (`:148-168`). Elision mechanics (`elide_old_tool_results:103`, `elide_walk:83`, `elide_content:73`) **untouched**. Add a WS1 unit test. |
| `packages/motoko-ext-compaction-ai/compaction_ai.ail` | 2 | **extension** | Batch `split_body` (`:107`); pre-call no-op guard + post-call growth check around `summarize_with_ai`/`new_pct` (`:181-185`); *(optional)* rate-limit read/write via `last_ran_step` with a `gap > 0` guard; extend `cache_artifact` (`:158`) to carry it. Add WS2 unit tests. |
| `packages/motoko-ext-compaction-ai/types.ail` | 2 | **extension** | Add `min_relief_pct` (+ optional `min_gap_steps` / `hard_override_pct` / rate-limit on/off) to `CompactionAiConfig` + `default_config`, keeping fallback-safe defaults so existing `.motoko` configs still parse. |
| `src/core/session.ail` | 3 | **CORE** | Regroup the `context_window` object in `runtime_status_json` (`:468-476`) into `last_sent` / `uncompacted_pending` + `note`. **No computation change.** Update `test_runtime_status_reports_actual_context_window` (`:2451`). |
| `scripts/runtime_status_tool_dst.ail` | 3 | test | Add assertions for the new `context_window` labels (`first_tool_status_ok`, `:198`). |
| `scripts/long_qwen_compaction_dst.ail` | 1,2 | test | Add WS1 "not-emergency" + WS2 drip/batch/rate-limit scenarios; **re-tune** `scenario_multiple_compactions`'s `applied ≥ 3` assertion (`:548-559`) to the new bounded cadence (intended delta, not a regression). |

**Reaches beyond these files?** One risk only: TS/web/deploy consumers of the flat
`context_window.*_usage_pct` keys (WS3). **Grep `actual_usage_pct` / `calibrated_usage_pct` across
`src/tui`, `web/`, `deploy/` before committing**; if any read the flat keys, keep flat aliases
alongside the nested block or update the consumer in the same PR. Nothing else in core changes —
WS1/WS2 are entirely extension-resident (004 `ADR-001` D9).

**Does NOT touch:** `src/core/compaction.ail` (calibration — frozen), `st.msgs` / history persistence
(`session.ail:1705` — the ephemeral guarantee), the elision mechanics, the `ExtensionHooks` /
`PreStepDecision` ABI (`packages/motoko-ext-abi/types.ail`), and the summary cache.

---

## Code-graph grounding

Grounded against `tools/code-graph` (`AGENTS.md`), re-extracted this session at **`--profile=all`**
(169 modules — the default `core` profile excludes `packages/**` where WS1/WS2 live). Call edges are
**source-parsed approximations** (`approximate=true`); effect rows carry coverage caveats (see the
last row). Each row below is a plan claim checked against the graph.

| Plan claim | Graph evidence (`invokes` / `effect_edges`) | Verdict |
|---|---|---|
| WS1/WS2 change surface is a single hook function reached by **dynamic dispatch**, not a static core edge | `compact_for_pre_step` and `compact_with_ai` have **no production static caller** — only their own in-module tests. Production entry is `src/core/session#c2_loop → dispatch_pre_step_chain` (`runtime.ail` fold), which invokes the `on_pre_step` **function-value**. | ✅ Confirms the ephemeral hook-dispatch model (§1.1–1.2); no other module statically depends on either function. |
| Leaving elision mechanics untouched keeps WS1 inside the structural module | `elide_old_tool_results` callers are **all** in `compaction_structural`: `compact_for_pre_step`, `compact_step_with_limit`, `try_emergency_compaction_with_limit`, +2 tests. Nothing external. | ✅ §2.4 holds — mechanics have no cross-module dependents. |
| `compact_step_with_limit` is test-only, can be left as-is | Single caller: `test_single_tier_ladder_selects_correctly`. | ✅ §2.4 holds. |
| The calibration fn I reuse for candidate measurement has one prod site | `calibrated_usage_percent_with_limit` prod caller = **only** `compact_for_pre_step` (+1 test). | ✅ §2.2 reuse is consistent — no other prod semantics to preserve. |
| Extending `cache_artifact` for `last_ran_step` is safe | `cache_artifact` and `cached_summary` each have a **single** caller: `compact_with_ai`. `split_body → split_msgs → compact_with_ai` all in-module. | ✅ §3.3 — one writer, one reader; contained to the AI module. |
| WS3 relabel affects exactly one AILANG test | `runtime_status_json` callers: `c2_loop` (prod) + two tests. Only `test_runtime_status_reports_actual_context_window` (`:2451`) asserts `context_window` fields; `test_runtime_status_includes_prior_conversation_counts` (`:2369`) asserts only `provider_calls_*` / `steps_executed_so_far`. | ✅ §4.3 names the right test; the second caller is **unaffected**. |
| The two-window story is real in the call graph | `c2_pending_context` callers = `c2_loop` + `runtime_status_json`; the status block's est/calib flow from it while `actual` flows from `st.telemetry`. | ✅ Grounds §1.4 / WS3. |
| No AILANG consumer parses the `context_window` fields (so the only field-shape risk is external) | `runtime_status_json`'s single prod consumer `c2_loop` encodes it to a **string** tool-result; no AILANG caller reads the keys. TS/web/deploy consumers are **outside this graph** (AILANG-only). | ✅ Confirms the WS3 ripple caveat (§4.3 / Blast radius) is the correct **external** check — the graph cannot see it, so grep it manually. |
| Effect claims for the two extension functions | **Coverage gap:** the typed/effect pass covers `src/core/**` (1170 effect rows) but **not** the package logic modules — `compaction_ai#compact_with_ai` / `compaction_structural#compact_for_pre_step` have **zero** effect rows (only their `register`/`_smoke` modules are covered). Per `AGENTS.md`, `incomplete`→"unknown", not "no". | ⚠️ Effects/purity for these two taken from **source declarations** (`pure func compact_for_pre_step`; `compact_with_ai … ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream}`), **not** the graph. `runtime_status_json` purity **is** graph-confirmed (core covered, no effect edges) and matches its `pure func` decl. |

**Net:** the graph corroborates the plan's containment claims — WS1 and WS2 are single hook
functions with no external static dependents, their helpers are module-local, and WS3 touches one
core function with one affected test and zero in-graph field consumers. The one thing the graph
**cannot** confirm is the TS/web/deploy consumers of the status JSON (out of profile) — which is
exactly why the Blast-radius section flags a manual grep there rather than relying on the graph.

---

## 0. Scope, in one screen

Three defects, **all within the deliberately-ephemeral per-step compaction model** (the returned
`msgs` replaces the send-payload *for this step only*; `st.msgs` keeps the full uncompacted history —
`design_docs/planned/m-motoko-conversation-compaction.md:52`, and the wiring at
`src/core/session.ail:1705` `msgs_with_assistant = st.msgs ++ [assistant_msg]`):

| # | Defect | Where it lives | Kind of change |
|---|--------|----------------|----------------|
| WS1 | Structural ladder picks the tier from the *uncompacted* pct → over-escalates to emergency `keep_last=3`, gutting the sent window to ~5% of the limit | `packages/motoko-ext-compaction-structural/compaction_structural.ail:148` `compact_for_pre_step` | extension-only |
| WS2 | AI compactor summarizes ~1 turn for ~0% relief **every step** (drip + no-op + no rate-limit) | `packages/motoko-ext-compaction-ai/compaction_ai.ail:167` `compact_with_ai` | extension-only |
| WS3 | Status tool's `context_window` conflates two windows (uncompacted-pending vs last-sent) → 114%-vs-10% reads as self-contradictory | `src/core/session.ail:434` `runtime_status_json` | **one small core touch** |

**Out of scope (guardrails — any plan touching these is wrong):**
- Persisting compaction into history / mutating `st.msgs`. Ephemeral is documented and intentional
  (audit / DST replay / un-compaction). Overturning it is a separate NOTE, not this plan.
- Bounding retained-history growth (issue Consequence 1 — a separate revisit of the "session log
  unchanged" tradeoff).
- Re-opening token calibration. The affine model (`src/core/compaction.ail:60` `affine_calibrate`,
  `:37` `delta_token_density_permille`, mirrored at
  `compaction_structural.ail:58` `calibrated_usage_percent_with_limit`) already shipped and is
  correct. We **use** it; we don't change it.

---

## 1. How the pieces actually wire (verified at HEAD — read before designing)

This section is the ground truth the three workstreams depend on. Every claim carries a verified
anchor.

### 1.1 The pre-step chain and the ephemeral send-only payload
- `src/core/session.ail:1619-1624`: on `CallModel`, the core splits the full history
  (`split_for_compaction(st.msgs)`) into a **pinned** prefix (system prompt) and a **compactable
  segment**, builds `pre_ctx` with `st.msgs`, `ext_context_limit = context_limit − pinned_tokens`
  (`:1622`), the current `st.ext_artifacts`, and `st.telemetry`, then runs
  `dispatch_pre_step_chain(rt, pre_ctx, messages_to_msgs(compactable_msgs))` (`:1624`). **The hooks
  see the segment only — the system prefix is pinned out.**
- `src/core/ext/runtime.ail:152-184` `fold_pre_step_chain_rec`: hooks run **in registry order**,
  each receiving the previous stage's output. Registry order ships **AI before structural**
  (`src/core/ext/registry_generated.ail:17` `compaction_ai` vs `:19` `compaction_structural`; the DST
  builds the same order, `scripts/long_qwen_compaction_dst.ail:304`
  `[compaction_ai_hook(), structural_hook(), long_tool_hook()]`). **Consequence: structural WS1 sees
  the post-AI window as its input.**
- `src/core/session.ail:1627` `seal_compacted_payload` re-attaches the pinned prefix; `:1643`
  `compacted_msgs = payload_messages(payload)` is used **only** for `dispatch_step` (`:1659`) and the
  sent-window estimate (`:1651`). The next state persists `msgs_with_assistant = st.msgs ++ [assistant_msg]`
  (`:1705`) — the **full uncompacted** history. This is the ephemeral guarantee in code.

### 1.2 The artifacts channel is the only durable cross-step state under ephemerality
This is the load-bearing discovery for WS2's rate-limit.
- `PreStepDecision` (`packages/motoko-ext-abi/types.ail:143-146`):
  `PassThrough | Compacted(msgs, note, artifacts: Json)`. **`Compacted` carries an `artifacts` Json;
  `PassThrough` carries nothing.**
- The chain threads artifacts: a `Compacted` stage's `next_artifacts` flows forward
  (`runtime.ail:169-173`); a `PassThrough` stage forwards the incoming `artifacts` **unchanged**
  (`:166-167`). The chain result's `artifacts` is written into the next state's `ext_artifacts`
  (`session.ail:1706` `post_ctx` uses `chain.artifacts`; the retry/tool paths at `:1672,:1723,…` do
  the same), and `mk_v2_ext_ctx(… st.ext_artifacts …)` (`:1623`) feeds it back into `ctx.artifacts`
  next step.
- So: **`ctx.artifacts` is a per-session key/value store that survives across steps, and the only way
  a hook writes to it is by returning `Compacted(…, artifacts)`.** The AI extension already uses it
  for the summary cache (`compaction_ai.ail:144-165` `cached_summary` / `cache_artifact`, keyed
  under the `compaction_ai` JSON node).
- **Hard constraint this imposes on WS2:** a hook that returns `PassThrough` **cannot** record "I
  just ran / I no-op'd." Any rate-limit or no-op state must be written on the `Compacted` path and
  read back next step. (An ABI change to let `PassThrough` carry artifacts is possible but is an
  `ExtensionHooks` major bump — explicitly *not* in this plan; see §6 Gaps.)

### 1.3 The calibration measurement (reused verbatim, not changed)
- `compaction_structural.ail:58` `calibrated_usage_percent_with_limit(msgs, limit, anchor_actual, anchor_estimate)`
  = affine-calibrate `estimate_tokens_messages(msgs)` against the anchor, floored at raw, `×100/limit`.
- `compact_for_pre_step:149` calls it with `anchor_actual = ctx.telemetry.last_input_tokens`,
  `anchor_estimate = ctx.telemetry.last_estimated_input_tokens` — i.e. the **last *sent* window's**
  real/estimated tokens (`packages/motoko-ext-abi/types.ail:69-76` `TokenTelemetry`).
- **Why the ladder currently reads 114-133% (the mechanism, verified by construction):** the hooks
  measure the **uncompacted segment** (`raw` large), but the anchor is the **last *compacted* sent
  window** (`anchor_estimate` small). So `raw − anchor_estimate` is large-positive and
  `scaled = anchor_real + 1.235·(raw − anchor_estimate)` inflates far above the limit. This is
  *correct* calibration of "how big would this window be if sent raw" — it is not a bug. WS1 exploits
  exactly this: measuring a **candidate-compacted** window with the *same* function and *same* anchor
  gives an accurate "what would the sent window be if we elided to `keep_last=k`."

### 1.4 The status block's two windows
`runtime_status_json` (`session.ail:434-476`):
- `actual_*` (`:444,:471`) ← `st.telemetry.last_input_tokens` = real provider tokens of the **last
  sent (compacted) window**.
- `estimated_*` / `calibrated_*` (`:446-449,:472-475`) ← `context_msgs = c2_pending_context(st)`
  (`:440`, defn `:1267` = `st.pending_tool_context` or `st.msgs`) = the **uncompacted pending**
  window.
- These are genuinely different message lists. **The status tool does not retain the last sent
  window's message list** — only its token count (telemetry). This rules out one of the issue's two
  options (see WS3).

---

## 2. Workstream 1 — structural: select tier by *result*, not by uncompacted pct

### 2.1 Target decision (the choice the issue leaves open — made here)
**Pick the gentlest `keep_last` whose *calibrated resulting* window is `< target_pct`, where
`target_pct = elide_tier_pct()` (70).**

Rationale:
- 70% is already the constant at which the ladder decides compaction is worth doing
  (`compaction_structural.ail:16`). Using it as the *fit* target makes the rule read cleanly:
  *"elide just enough that the sent window drops back under the level where we'd start compacting"* —
  it leaves ~30% headroom for the model's response and next-turn growth, so we do not re-cross the
  threshold on the very next step.
- It reuses an existing, reviewed constant instead of inventing a new magic number, and it keeps the
  three-way relationship intact: below 70 we don't compact at all (today's behavior for a small
  window is preserved), at/above 70 we compact to *land under* 70.
- Not "under the hard limit (100%)": that would still permit a barely-fitting sent window with no
  room to answer — the same brittleness the issue calls out. Not a tiny target either — over-eliding
  is the exact defect.

Add a named accessor so the target is legible and tunable, e.g.
`export pure func result_target_pct() -> int { elide_tier_pct() }`.

### 2.2 Selection algorithm (replaces the pct-keyed cascade in `compact_for_pre_step`)
Introduce a pure helper (extension-side). **Two corrections over a naive "loop the tiers" sketch,
both required to match today's behavior** (verified against `compact_for_pre_step:148-168`):

```
-- candidates, gentlest first (largest keep_last kept). Monotone & terminating.
tiers = [ (elide_keep_last(), "tier1")            -- 10
        , (elide_hard_keep_last(), "hard")        -- 5
        , (emergency_keep_last(), "emergency")    -- 3
        , (emergency_final_keep_last(), "emergency") ] -- 1

calib(m) = calibrated_usage_percent_with_limit(m, ctx.context_limit,
             ctx.telemetry.last_input_tokens, ctx.telemetry.last_estimated_input_tokens)

select_by_result(ctx, msgs):
  -- (A) SHORT-CIRCUIT: if the uncompacted input already fits, do NOT compact.
  --     Preserves today's `else PassThrough` at :167 (below 70% today = no-op).
  if calib(msgs) < result_target_pct(): return PassThrough

  best_changed = None                         -- tightest candidate that changed anything
  for (k, tier) in tiers:                     -- gentlest → tightest
    cand = elide_old_tool_results(msgs, k)
    if same_msgs(msgs, cand): continue        -- this k elides nothing; try tighter
    best_changed = Some(cand, tier, k)
    if calib(cand) < result_target_pct(): return Compacted(cand, note(tier, k))

  -- (B) FALLBACK: no tier reached the target. Hand the seal the smallest window we
  --     produced (best effort) — the extension does NOT decide exhaustion (see 2.3).
  --     Use a DISTINCT note ("floor", not "emergency") so observability never reads a
  --     best-effort floor as a *satisfied* emergency selection.
  match best_changed {
    Some(cand, _tier, k) => Compacted(cand, note("floor", k)),  -- tightest that changed (keep_last=1)
    None                 => PassThrough                          -- nothing tool-role to elide
  }
```

Key points, each tied to existing code:
- **(A) base short-circuit is mandatory.** Today the whole function is gated behind
  `pct >= elide_tier_pct()` and otherwise `PassThrough` (`:167`). Without checking the *uncompacted*
  input first, the loop would elide an already-fine window with >10 tool results down to
  `keep_last=10` — an unnecessary `Compacted`. (A) restores the no-op-below-target behavior.
- **Measure candidates with the *same* function and anchor** as the current gate
  (`compaction_structural.ail:58` + `:149` anchor). This is the WS1 correctness pin: the fit test
  must match how the live gate reads size (§1.3). Do **not** use the non-calibrated
  `usage_percent_with_limit` (`:39`) here.
- **`calib` is monotone in `keep_last`.** More kept ⇒ larger `raw` ⇒ larger `calib` (affine is
  monotone increasing in `raw`, floored at `raw`). So gentlest-first, first-fit yields the *least*
  elision that fits. Four fixed candidates, strictly tightening ⇒ bounded & terminating.
- **Gentlest-first + first-fit** gives "least elision that fits." Per issue evidence
  (`keep_last=3` → sent ~12.7k ≈ 5%), `keep_last=10` lands far under 70% on a 300+ message history,
  so tier1 is selected — emergency is never reached unless it genuinely must be.
- **Elision only touches `role == "tool"` messages** (`elide_walk:87`) — assistant/user text is
  **never** shortened at any `keep_last`. So "fit under target" is reachable by structural alone only
  when tool-result bytes dominate. On a prose-heavy window even `keep_last=1` may not reach 70% (all
  tiers change little); the bulk is handled instead by the **AI compactor, which runs first**
  (§1.1) and collapses old assistant/user/tool turns into one summary. If neither reaches the limit,
  core's seal exhausts (§2.3) — same as today.
- **Intended minor divergence from today (call out in the PR):** for a window *just* over target with
  only a few tool results, gentle tiers change nothing and the fallback (2.2-B) elides the single
  oldest tool result — where today's `pct >= elide_tier_pct` branch, finding `same_msgs`, would
  `PassThrough`. This is a strictly-more-helpful, low-churn change (it hands seal a smaller window),
  and the `"floor"` note keeps it from reading as an emergency. Accept it; assert it in the WS1 test.

### 2.3 Exhaustion is core's decision at seal — the extension never errors
Correction over an earlier draft: `compact_for_pre_step` returns `PreStepDecision`
(`PassThrough | Compacted`) — **there is no `Err` variant**, so the extension *cannot* "emit
compaction_exhausted." (The `Err(...)` at `:117` lives in `try_emergency_compaction_with_limit`, used
only by the **test-only** `compact_step_with_limit:121`.) Exhaustion is decided in **core** by
`seal_compacted_payload` (`src/core/phase_vocab.ail`): it re-measures the *full sealed window*
(`split.pinned ++ chain_msgs`) with the **raw** `usage_percent_with_limit` and returns
`Err(SealExhausted)` when `pct >= exhaustion_pct()` (95), which surfaces at `session.ail:1635`.

Consequences for WS1:
- The fallback (2.2-B) hands seal the **smallest window it could build** (`keep_last=1` elided) as a
  best-effort `Compacted`; seal then independently decides pass/exhaust. If even `keep_last=1` leaves
  raw usage ≥ 95%, `SealExhausted` fires — **unchanged** behavior. WS1 adds no new error path.
- **Measurement asymmetry (safe):** the extension selects tiers on **calibrated** pct (an
  over-estimate, floored at raw), while seal exhausts on **raw** pct. Since `calibrated ≥ raw`, the
  extension is *stricter* than seal — it compacts at least as much as seal needs, never less, so it
  cannot cause a seal exhaustion that today's logic would have avoided.
- Net ladder: `tier1 → hard → emergency(3) → final(1) → (best-effort keep_last=1) → seal decides`.
  Monotone, terminating, and the exhaustion boundary (raw ≥ 95% at seal) is untouched.

### 2.4 Confined blast radius
- Change **only** the *selection* logic inside `compact_for_pre_step` (`:148-168`) plus the new
  `select_by_result` / `result_target_pct` helpers.
- Do **not** touch the elision mechanics: `elide_old_tool_results` (`:103`), `elide_walk` (`:83`),
  `elide_content` (`:73`) are unchanged.
- Do **not** touch `try_emergency_compaction_with_limit` (`:109`) or `seal_compacted_payload`
  (core) — exhaustion stays exactly where it is (§2.3).
- `compact_step_with_limit` (`:121`, non-calibrated, used only by the unit test at `:214-223`) can be
  left as-is or re-expressed over the shared helper; if touched, keep `test_single_tier_ladder_selects_correctly`
  green. Prefer leaving it untouched to keep the diff minimal.
- **Measurement domain note:** `pre_ctx.context_limit = ext_context_limit = context_limit − pinned_tokens`
  (`session.ail:1622`), and the hooks receive the *segment* (prefix pinned out, §1.1). So `calib` in
  2.2 tests `segment` against `limit − pinned` — i.e. the budget left after the system prefix. This
  makes the whole-window target ≈ 70% (off by the prefix's share); it matches how the AI compactor's
  gate already measures, and is the same domain the live structural gate uses today, so no drift is
  introduced.

---

## 3. Workstream 2 — AI compactor: batch + pre-call no-op guard (+ optional rate-limit)

Three levers, composing inside `compact_with_ai` (`compaction_ai.ail:167`). **Batch (§3.1) and the
no-op guard (§3.2) are the load-bearing correctness fixes** — together they turn "1 turn / 0% / every
step" into "meaningful span or nothing spent." The **rate-limit (§3.3) is an optional optimization**
with a real tradeoff; ship it behind a flag. They are independent gates and do not share state.

### 3.1 Batch, don't drip
**Defect** (`compaction_ai.ail:107-121` `split_body`): the front-anchored walk stops at the **first**
message that either leaves `< keep_recent` behind **or** is a tool_call whose result is anywhere in
the tail (`:114` `has_tool_result_for(m.tool_calls, rest)`). On a tool-heavy transcript the very
first old turn is usually a paired call → the walk bails immediately → `old` = ~1 turn (issue cause
1).

**Fix**: summarize **everything older than the last `keep_recent` messages** in one pass, protecting
tool pairs **only when the pair would be split across the old/recent boundary**, not when the pair is
wholly inside `old`.
- Compute the boundary at `n − keep_recent`. Everything before it is a batch candidate for `old`;
  the last `keep_recent` are `recent`.
- Reconcile tool pairing **symmetrically** — a straddling pair is a bug in *either* direction, and
  summarizing `old` into one prose `summary_msg` **drops** every `old` message (both calls and
  results). So the old/recent boundary must satisfy **both**:
  1. no `old` assistant-with-tool_calls has its result in `recent` (would orphan a call), **and**
  2. `recent` must not *begin* with a tool-role message whose call is in `old` (would orphan a
     result → provider 422). Equivalently: place the boundary at a **turn start** — `recent` begins
     with a user/assistant message, never a dangling tool result.
  Deterministic rule: scope `has_tool_result_for` to **`recent`**, and if the boundary would straddle
  a pair, move it **earlier** (pull the whole straddling turn — assistant-with-calls *and* its
  results — into `recent`). Moving earlier (never later) keeps it monotone and guarantees `recent`
  starts clean. Pairs wholly inside `old` are summarized together — the whole point.
- Preserve the system-prefix split (`split_prefix`, `:80-89`) unchanged — the prefix never enters
  `old`.
- **Invariant to keep green:** `validate_compactor_output` / `conformance.compactor.tool_pairing_preserved`
  (`packages/motoko_ext_conformance/harness.ail:237`, `invariants.ail:133`). It tolerates orphans
  already present in the *input* (identity — `test_validate_compactor_output_accepts_orphan_identity`,
  `invariants.ail:181`) but rejects **newly introduced** orphans. The chain drops a rejected stage
  (`runtime.ail:170`), so a pairing bug wouldn't crash — it would **silently disable compaction**,
  which is worse than a crash. Get it correct, not merely rejected.

### 3.2 Pre-call no-op guard (do not spend the AI call to discover 0% relief)
**Defect** (`compaction_ai.ail:181-185`): `summarize_with_ai` (the AI call, `:181`) is spent
**before** `new_pct` is known (`:184`), and `Compacted` is emitted even when `pct == new_pct` (0%
relief) — an AI request every step that changes nothing.

**Fix — project relief *without* calling the model, and bail early:**
- After computing the batch `old_turns` / `recent_turns`, build an **optimistic** projected window
  `projected = prefix ++ recent_turns` (i.e. treat the summary as ~empty — an *upper bound* on
  relief).
- `projected_pct = usage_percent(ctx, projected, ctx.context_limit)` (reuse `usage_percent`, `:30`,
  which is the same anchored calibration — no AI call).
- If `pct − projected_pct < min_relief_pct` → **`PassThrough`** (no AI call, no `Compacted`, no
  `compaction_ai_applied` increment). Because `projected` is the *most* relief obtainable (real
  summary only adds bytes back), clearing this bound is necessary for any pass to be worthwhile —
  conservative in the safe direction (we may skip a borderline pass; we never skip a big win).
- This alone kills the "1 turn / 0%" drip: 1 old turn ⇒ `projected_pct ≈ pct` ⇒ `PassThrough` with
  no call. Combined with batching (§3.1), the guard only lets through passes that collapse a
  meaningful span.
- Keep a **post-call** sanity check too: if, after summarizing, `pct − new_pct < min_relief_pct`
  (summary came back unexpectedly large), still emit the `Compacted` (the call is already spent, use
  its result) but this should be rare given the pre-call bound. Do **not** emit a `Compacted` that
  *grows* the window — if `new_pct > pct`, return `PassThrough` and discard.
- Pick `min_relief_pct` as a small constant (proposal: **5**). Justify in code comment relative to
  `threshold_pct` (default 75, `types.ail`): a pass that doesn't recover ≥5% of the limit isn't worth
  a summarizer round-trip.
- **Preserve the existing `keep_recent` halving** (`compaction_ai.ail:171`: `keep_recent/2` when
  `pct >= 90`). Under batching it still helps — a smaller protected tail means a larger `old` batch
  and more relief under pressure — so keep it; the guard and batch compose with it unchanged.

### 3.3 Rate-limit re-summarization (lowest-priority lever — ship behind a flag)
**Framing / relationship to the issue.** The issue's literal rate-limit — *"don't run on consecutive
steps once it just ran and **achieved little**"* — is almost entirely **subsumed by the pre-call
no-op guard (§3.2)**: a low-relief pass is now a stateless `PassThrough` that spends nothing, so
there is nothing to "back off" from. What actually remains is a *different*, ephemerality-specific
cost: once over threshold, each step's batch (= everything older than `keep_recent`) grows by ~1
turn/step, so the projection keeps clearing `min_relief` and we'd re-summarize a **nearly-identical
span every step, each a real AI call** (ephemeral ⇒ the summary isn't persisted, so it's recomputed
to have any effect — §1.1). Rate-limiting throttles *that*.

**This is the weakest of the three levers and has a genuine tradeoff — treat it as optional:**
- **Cost of the gap:** on the steps we skip, the AI summary is absent, so the sent window is
  **structural-only** (WS1 still elides tool results every step). That is *cheap when tool bytes
  dominate* (the pathological workload — structural alone drops it to ~5%) but *expensive on a
  prose-heavy window* where structural can't shrink assistant/user text (§2.2). So the rate-limit is
  a net win mainly on tool-heavy transcripts; on prose-heavy ones it trades summarizer calls for
  larger provider inputs. Because of this it should ship **behind a config flag, default conservative**
  (a large `min_gap_steps`, or off), not as unconditional behavior.
- Do **not** claim the sent window is "protected" during the gap — it is only *bounded* by
  structural + the override below.

**Design:**
- **State**: store `last_ran_step` in the `compaction_ai` artifacts node (§1.2). Extend
  `cache_artifact` (`:158`) so the node carries `segment_digest`, `summary`, **and** `last_ran_step`;
  write it on **every** `Compacted` return. Read at entry via a `last_ran_step` accessor over
  `ctx.artifacts` (mirror `cached_summary`, `:144`); **default to `-1` when the field is absent.**
- **Rule** at entry, after the threshold check but before batching/AI:
  ```
  gap = ctx.step - last_ran_step        -- ctx.step = step_idx (session.ail:1623)
  if last_ran_step >= 0
     && gap > 0                          -- MANDATORY: strictly a *later* step (see below)
     && gap < min_gap_steps
     && pct < hard_override_pct          -- safety valve
  then PassThrough
  ```
- **`gap > 0` is mandatory, and here is exactly why (verified).** The conformance invariant
  `conformance.compactor.artifact_cache_effective` (`harness.ail:264`) runs the **real AI compactor**
  (`scripts/conformance_selftest.ail` imports `register_ai`): it calls `on_pre_step` once with empty
  artifacts (→ `d1`, which now writes `last_ran_step = ctx.step`), then **again with `d1`'s artifacts
  and poisoned AI ports**, and asserts `same_msgs(out1, out2)`. Both ctxs use `step: 1`
  (`mk_conformance_ctx:88`). Without `gap > 0`, run 2 sees `gap = 1 − 1 = 0 < min_gap` → rate-limits →
  `PassThrough` ≠ `out1` → **invariant breaks.** With `gap > 0`, `gap = 0` is *not* a later step, so
  run 2 falls through to the **cache hit** (poisoned ports never called) → `Compacted` == `out1`.
  Semantically correct too: the rate-limit throttles *subsequent* steps, and a same-step re-evaluation
  is a cache concern, not a cadence concern. `conformance.compactor.deterministic_replay`
  (`harness.ail:250`, two fresh ctxs, both `step: 1`, no threaded artifacts ⇒ `last_ran_step = -1`
  both) is unaffected.
  - `min_gap_steps` proposal: **3** (tune against the DST).
  - `hard_override_pct` proposal: **emergency_pct (95)** — if the uncompacted window climbs back to the
    danger zone during the gap, **override** and compact anyway, so the rate-limit can never let the
    window run away.
- **Soundness under the PassThrough/artifacts constraint (§1.2):**
  - State is written only on the `Compacted` path (which carries artifacts). ✔
  - A rate-limited step returns `PassThrough`, which *inherits* the incoming artifacts unchanged
    (`runtime.ail:166`), so `last_ran_step` persists; the gap is measured from the last *actual*
    compaction. ✔ No no-op state needs writing (the thing we cannot write, §1.2).
  - Pre-call guard (§3.2) and rate-limit are independent gates: guard = "is this pass worth it?";
    rate-limit = "did a *prior* step just do one?".

### 3.4 Confined blast radius
- All edits inside `packages/motoko-ext-compaction-ai/compaction_ai.ail` (+ possibly a field in the
  `compaction_ai` artifacts JSON). No core change. No `CompactionAiConfig` shape change is required,
  but `min_relief_pct` / `min_gap_steps` / `hard_override_pct` **may** be added to
  `packages/motoko-ext-compaction-ai/types.ail` `CompactionAiConfig` + `default_config` if we want
  them profile-tunable (recommended; keep sane defaults so existing `.motoko` configs still parse via
  the `read_compaction_ai_config` fallback in `register.ail`).
- The existing summary **cache** (`cached_summary`/`segment_digest`, `:140-156`) stays — it keeps DST
  replay deterministic and is orthogonal to the rate-limit.

---

## 4. Workstream 3 — observability (the one small core touch)

### 4.1 Decision: relabel, do not "measure the same window"
The issue offers two options; **choose relabel**, and here is the disqualifier for the other:
"measure `est`/`calib` on the same window as `actual`" is **not implementable** in `runtime_status_json`
because the status tool only has `c2_pending_context` (uncompacted) plus `st.telemetry`
(the last sent window's *token count*, not its *message list*, §1.4). The compacted last-sent
messages are not retained anywhere the status tool can reach (they are the ephemeral `compacted_msgs`
at `session.ail:1643`, discarded after `dispatch_step`). So there is no message list to recompute
`est`/`calib` over. Relabel is the correct and only clean option.

### 4.2 Change (labeling/field only — no new policy)
Restructure the `context_window` object (`session.ail:468-476`) so the two windows are named:
```
"context_window": {
  "context_limit": <limit>,
  "last_sent":            { "input_tokens": <actual>, "usage_pct": <actual_pct> },
  "uncompacted_pending":  { "estimated_tokens": …, "estimated_pct": …,
                            "calibrated_tokens": …, "calibrated_pct": … },
  "note": "last_sent = real provider tokens of the previous compacted request; uncompacted_pending = the full retained history before this step's ephemeral compaction. They measure different windows by design."
}
```
- No computation changes — same four numbers (`actual_*`, `estimated_*`, `calibrated_*`), just grouped
  and named so a `114%` pending next to a `10%` sent reads as *legible*, not *alarming*.
- This is the **only** core edit in the plan. It is pure presentation; it introduces no policy and
  does not touch the compaction path.

### 4.3 Test fallout to fix in the same change
- `src/core/session.ail:2451` `test_runtime_status_reports_actual_context_window` asserts flat
  `"actual_usage_pct":50` / `"actual_input_tokens":500`. Update its `contains` assertions to the new
  nested path (e.g. assert `"last_sent"` block carries `"usage_pct":50` and `"input_tokens":500`).
- `src/core/session.ail:2369` `test_runtime_status_includes_prior_conversation_counts` — the graph's
  *other* `runtime_status_json` caller — asserts only `provider_calls_*` / `steps_executed_so_far`,
  **not** `context_window`, so it is **unaffected** by the regrouping (verified in Code-graph
  grounding). No change needed there.
- `scripts/runtime_status_tool_dst.ail` `first_tool_status_ok` (`:198-211`) checks
  `current_step` / `provider_calls_*` / `system_prefix.digest` but **not** the `context_window`
  fields — so the DST is unaffected by the regrouping. Add a positive assertion for the new labels
  here (see §5).
- Any TS-side consumer of `context_window.*` must be checked. Grep `actual_usage_pct` /
  `calibrated_usage_pct` across `src/tui`, `web/`, `deploy/` before finalizing the field shape; if a
  consumer reads the flat keys, either keep flat aliases alongside the nested block or update the
  consumer in the same PR. (Flag: this is the one place WS3 could ripple beyond core.)

---

## 5. Verification (deterministic, offline)

Baseline must stay green throughout:
- `make compaction_dst` → `scripts/runtime_status_tool_dst.ail` + `scripts/long_qwen_compaction_dst.ail`
  (both `--ai-stub`, offline; `Makefile:60-66`).
- `make conformance` → compactor invariants
  `conformance.compactor.{system_prefix_preserved, tool_pairing_preserved, deterministic_replay,
  artifact_cache_effective}` (`packages/motoko_ext_conformance/harness.ail:225,237,250,264`), run
  against the **real AI compactor** (`conformance_selftest.ail` imports `register_ai`). **WS2's
  `gap > 0` guard (§3.3) is what keeps `artifact_cache_effective` green** — treat that invariant as a
  gate on the rate-limit change, not an afterthought.
- The in-file `tests [((), true)]` unit tests in both extensions and in `compaction.ail`.

New scenarios proving the fixes (all via the scripted-provider / `--ai-stub` path so they are offline
and deterministic — model `stub_step.Scripted`, as the existing DSTs do):

**WS1 — gentle tier is chosen, emergency is not over-selected.**
Add a scenario (extension unit test in `compaction_structural.ail`, and/or a `long_qwen_compaction_dst`
assertion) with a large uncompacted segment whose calibrated *uncompacted* pct is well over 95%, but
where `keep_last=10` calibrated *result* is under `target_pct`. Assert the `Compacted` note is
`tier=tier1 keep_last=10` (or at least **not** `tier=emergency`). This is the direct regression test
for issue Consequence 2/3. Construct the telemetry anchor (small `last_estimated_input_tokens`, real
`last_input_tokens`) so the calibration inflates exactly as in §1.3.

**WS2 — the compactor either yields real relief or returns `PassThrough` (never `Compacted` at ~0%).**
Extension **unit** tests (`tests [((), true)]` in `compaction_ai.ail`, matching the `PreStepDecision`
directly — no counters):
- *Drip case*: a ctx where only ~1 turn is older than `keep_recent` ⇒ assert the decision is
  `PassThrough` (the projection clears no relief). Use a stub `ai_step` that **fails if called** to
  prove no AI call is spent (mirrors `poison_ports`).
- *Batch case*: a ctx with many old paired turns ⇒ assert `Compacted` with `old` turns ≫ 1, tool
  pairing intact (`validate_compactor_output` on the output), and projected relief ≥ `min_relief_pct`.
- *Rate-limit case*: run the hook twice threading artifacts, with `ctx.step` **strictly increasing**
  (step N `Compacted` writes `last_ran_step=N`; step N+1 with `gap=1 < min_gap` and
  `pct < hard_override_pct` ⇒ `PassThrough`). Add the `gap = 0` case (same step, threaded artifacts) ⇒
  assert **not** rate-limited (this is the `artifact_cache_effective` shape, §3.3). Then a step at
  `pct ≥ hard_override_pct` ⇒ assert it compacts despite the gap.

**DST-level (`long_qwen_compaction_dst.ail`).** The existing `scenario_multiple_compactions`
(`:548-559`) asserts *≥3 AI stages applied* by counting `TraceStageApplied` (`:378,:517`).
- With **batch + no-op guard only** (rate-limit off — the recommended default), each step's batch on
  this fixture still yields real relief → still `Compacted` each step → the `≥3` assertion likely
  **holds unchanged**. (Verify; if batching now collapses everything in one early pass and later steps
  legitimately `PassThrough`, relax `≥3` to "≥1 applied and **0** no-op `Compacted`s".)
- If a scenario **enables the rate-limit** to test it, the applied count **drops by design** — give
  that scenario its own config and assertion (bounded cadence: applied every ~`min_gap_steps`), rather
  than bending `scenario_multiple_compactions`.
- Either way, ensure `compaction_segment()` still triggers a real `Compacted` under batch+guard, so
  the `deterministic_replay` / `artifact_cache_effective` scenarios don't pass **vacuously** (a
  `PassThrough` on both runs also satisfies `same_msgs`, testing nothing).

**WS3 — context-window fields are unambiguous.**
In `runtime_status_tool_dst.ail`, assert the emitted status contains the `"last_sent"` and
`"uncompacted_pending"` sub-objects and the `"note"`, and that `last_sent.usage_pct` tracks the
provider tokens while `uncompacted_pending.calibrated_pct` can differ — proving the two-window reading
is explicit. Update `test_runtime_status_reports_actual_context_window` per §4.3.

**Regression guard for the exhaustion contract (seal-side, session/DST — not an extension test).**
Exhaustion is core's decision in `seal_compacted_payload` (§2.3), so this must be exercised through
`run_v2_session_traced`, not by calling `compact_for_pre_step` directly (which cannot error).
Construct a session whose window, even after WS1 hands seal the `keep_last=1` best-effort payload,
leaves **raw** `usage_percent_with_limit(pinned ++ segment)` ≥ 95% (e.g. large non-tool / assistant
content that elision cannot shrink), and assert `CompactionExhausted` still surfaces
(`session.ail:1635`). This proves WS1's gentler selection does not silently swallow a genuinely
exhausted window.

---

## 6. Gaps found

Per the handoff's freshness test, the two flagged gaps and what I found beyond them:

1. **WS1 target pct — the issue leaves it open; chosen here.** `target_pct = elide_tier_pct() (70)`,
   justified in §2.1 (reuses the existing "start compacting" constant as the "land back under"
   target, leaving ~30% response headroom; avoids both a barely-fitting 100% target and an
   over-eliding tiny target). This is a design choice, not derivable from the issue alone — recorded
   as such.

2. **WS2 rate-limit "last ran" state has a home: the artifacts channel.** Not a dead end. `ctx.artifacts`
   survives across steps (§1.2), is already used by the AI cache, and `Compacted` is the write path.
   `last_ran_step` lives in the `compaction_ai` JSON node, written on every `Compacted`, read at
   entry. No history mutation, fully within the ephemeral model.

3. **New constraint surfaced (not in the issue): `PreStepDecision.PassThrough` cannot carry
   artifacts** (`packages/motoko-ext-abi/types.ail:143-146`). This *shapes* WS2: we cannot record "I
   just no-op'd," so the rate-limit is measured from the last *successful* compaction and the no-op
   guard is stateless (cheap to re-evaluate every step). Working around it fully (persisting no-op
   state) would need an `ExtensionHooks` ABI major bump — **out of scope**; noted so a future ADR can
   pick it up if a stateful no-op backoff is ever wanted.

4. **New finding (not in the issue): the hooks measure the *segment*, and calibration inflates
   because the anchor is the last *compacted* sent window** (§1.3). This is the mechanism behind the
   114-133% reading and the reason candidate measurement with the same function/anchor is exactly
   right. Any implementer who measured candidates a different way (e.g. non-calibrated
   `usage_percent_with_limit`, or a fresh anchor) would get a subtly wrong fit test — hence pinned
   explicitly in §2.2.

5. **New finding (not in the issue): chain order is AI-then-structural** (§1.1). WS1's structural
   selection sees the *post-AI* window as input, and WS2's projection is computed before structural
   runs. Both workstreams are correct under this order (each measures its own input), but the order
   is load-bearing: because `elide_old_tool_results` only touches tool-role messages (§2.2), it is
   the *AI* stage that collapses prose bulk — so the two levers are complementary, not redundant.
   Flagged so it is verified, not assumed.

6. **Correction found during review: exhaustion is core's, not the extension's.** An earlier draft had
   `compact_for_pre_step` "emit compaction_exhausted." It can't — `PreStepDecision` has no `Err`
   variant; `seal_compacted_payload` (core, raw char/4 ≥ 95%) owns exhaustion (§2.3). WS1 only hands
   seal the smallest best-effort window. Corrected in §2.2-B / §2.3 / §5.

7. **Correction found during review: WS2's rate-limit must guard `gap > 0`, or it breaks
   `artifact_cache_effective`.** The conformance self-test re-runs the real AI compactor with the
   prior decision's artifacts (now carrying `last_ran_step`) at the *same* `step: 1`; a naive
   `gap < min_gap` rate-limit fires on the re-run and diverges from the cached output. `gap > 0`
   (only *later* steps) is both semantically right and the exact condition that keeps the invariant
   green (§3.3) — treat `artifact_cache_effective` as a gate on the rate-limit change.

8. **Judgment call surfaced: the rate-limit (§3.3) is the weakest lever.** The issue's literal
   "achieved little" rate-limit is subsumed by the no-op guard; what remains is an ephemerality cost
   with a workload-dependent tradeoff (structural-only sent windows during the gap). Recommend
   shipping it **behind a flag, default conservative** — the batch + no-op guard are the load-bearing
   fixes; the rate-limit is an optimization, not a correctness fix.

9. **WS3 ripple to check, not assumed clean:** grep TS/web/deploy consumers of the flat
   `context_window.*_usage_pct` keys before committing the regrouping (§4.3). If any exist, keep flat
   aliases or update them in the same PR. This is the only place the plan's "one small core touch"
   could grow.

Everything else in the issue's two Fix lists was plannable from the issue + design doc + code without
guessing.

---

## 7. Suggested implementation order

1. **WS3** first (smallest, isolates the one core touch; makes the DST status output legible for the
   WS1/WS2 assertions that read it).
2. **WS1** (extension-only, pure; unblocks the "not emergency" regression scenario).
3. **WS2** last (largest; batch + guard, then the optional rate-limit behind a flag). Land batch +
   no-op guard first and confirm `scenario_multiple_compactions` still holds; add the rate-limit and
   its own scenario after, treating `artifact_cache_effective` as the gate (§3.3).

Each step: keep `make compaction_dst` + `make conformance` green before moving on.
