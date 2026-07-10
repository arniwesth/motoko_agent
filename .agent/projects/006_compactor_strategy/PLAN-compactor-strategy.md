# PLAN: compactor-strategy refinement

**Status**: Plan (not started). PLAN-level, not an ADR — refines an already-extension-resident
strategy without overturning any documented decision (`../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`
§Non-goals; `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` D9).
**Branch**: `arniwesth/mot-35-fix-context-size-estimation`
**Grounded at**: HEAD `aeb8a69` (all `file:line` anchors below verified at this commit).
**Source issue (normative)**: `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — the two
sections' Consequences + Fix lists are the acceptance criteria.

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
Introduce a pure helper (extension-side):

```
-- candidates, gentlest first (largest keep_last kept). Monotone & terminating.
tiers = [ (elide_keep_last(), "tier1")       -- 10
        , (elide_hard_keep_last(), "hard")   -- 5
        , (emergency_keep_last(), "emergency")       -- 3
        , (emergency_final_keep_last(), "emergency") ] -- 1

select_by_result(ctx, msgs):
  for (k, tier) in tiers:                      -- gentlest → tightest
    cand = elide_old_tool_results(msgs, k)
    if same_msgs(msgs, cand): continue-as-fits -- nothing left to elide at this k
    pct  = calibrated_usage_percent_with_limit(cand, ctx.context_limit,
             ctx.telemetry.last_input_tokens, ctx.telemetry.last_estimated_input_tokens)
    if pct < result_target_pct(): return Compacted(cand, note(tier, k))
  -- none fit: preserve today's exhaustion behavior (see 2.4)
  return exhausted-or-passthrough
```

Key points, each tied to existing code:
- **Measure candidates with the *same* function and anchor** as the current gate
  (`compaction_structural.ail:58` + `:149` anchor). This is the WS1 correctness pin: the fit test
  must match how the live gate reads size (§1.3). Do **not** use the non-calibrated
  `usage_percent_with_limit` (`:39`) here.
- **Gentlest-first + first-fit** gives "least elision that fits." Per issue evidence
  (`keep_last=3` → sent ~12.7k ≈ 5%), `keep_last=10` already lands far under 70% on a 300+ message
  history, so tier1 is selected — emergency is never reached unless it genuinely must be.
- **Monotone & terminating:** four fixed candidates, strictly tightening; the loop is bounded.
- **`same_msgs` no-op preservation:** if a candidate equals the input (nothing to elide at that `k`),
  it trivially "fits at this tier" in the today-sense — keep the existing `PassThrough`-when-unchanged
  semantics (`:161,:165` today) so we never emit a `Compacted` that changed nothing.

### 2.3 Boundary with the emergency/exhaustion path
- Today `pct >= emergency_pct` routes to `try_emergency_compaction_with_limit` (`:109,:123`) which can
  return `Err(compaction_exhausted…)`. Under by-result selection, "exhausted" becomes: **even
  `keep_last=1` does not fit `target_pct`.** Two sub-cases, and we must decide deliberately:
  1. `keep_last=1` fits under the **hard limit (100%)** but not under `target_pct (70)`: return the
     `keep_last=1` `Compacted` (best effort — send the smallest window, don't error). This is gentler
     than today and avoids a spurious `CompactionExhausted`.
  2. `keep_last=1` does not fit even under the hard limit: preserve **today's exhaustion** — emit the
     `compaction_exhausted` `Err` so `seal_compacted_payload` raises `SealExhausted`
     (`session.ail:1635`). Do not regress the exhaustion contract the DST asserts.
- Net: the ladder stays `tier1 → hard → emergency(3) → final(1) → exhausted`, monotone and
  terminating, but tier is chosen by *fit*, and exhaustion is now defined against the hard limit,
  not against the uncompacted pct.

### 2.4 Confined blast radius
- Change **only** the *selection* logic inside `compact_for_pre_step` (`:148-168`) plus the new
  `select_by_result` / `result_target_pct` helpers.
- Do **not** touch the elision mechanics: `elide_old_tool_results` (`:103`), `elide_walk` (`:83`),
  `elide_content` (`:73`) are unchanged.
- `compact_step_with_limit` (`:121`, non-calibrated, used only by the unit test at `:214-223`) can be
  left as-is or re-expressed over the shared helper; if touched, keep `test_single_tier_ladder_selects_correctly`
  green. Prefer leaving it untouched to keep the diff minimal.

---

## 3. Workstream 2 — AI compactor: batch + pre-call no-op guard + rate-limit

All three levers are distinct and all three are needed. They compose inside `compact_with_ai`
(`compaction_ai.ail:167`).

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
- Reconcile tool pairing: a tool_call and its matching tool_result must land on the **same side**. So
  `has_tool_result_for` must be scoped to **`recent`** (would the result be in the kept tail?), not
  to the whole tail. If the boundary would cut a pair, nudge it so both the call and its result stay
  together (either pull the call into `recent`, or extend `old` to include the result — pick one and
  keep it deterministic; pulling the trailing call into `recent` is simplest and keeps `recent`
  self-consistent). Pairs wholly inside `old` are summarized together — which is the whole point.
- Preserve the system-prefix split (`split_prefix`, `:80-89`) unchanged — the prefix never enters
  `old`.
- **Invariant to keep green:** `validate_compactor_output` / `conformance.compactor.tool_pairing_preserved`
  (`packages/motoko_ext_conformance/harness.ail:237`, `invariants.ail:133`). The batched split must
  never emit a tool_result whose call was dropped or vice-versa. Note the chain already *validates*
  each stage's output (`runtime.ail:170`), so a pairing violation would be rejected at runtime — but
  we want it correct, not rejected.

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

### 3.3 Rate-limit successful passes (bound cost in steady state)
Even with §3.1+§3.2, once over threshold every step's batch = "everything older than `keep_recent`,"
which grows by ~1 turn/step, so the projection keeps clearing `min_relief` and we'd re-summarize a
nearly-identical span **every step** — real relief, but a fresh AI call each time (ephemeral: the
summary isn't persisted, so it must be recomputed to have any effect — §1.1). Rate-limit that.

**Design:**
- **State**: store `last_ran_step` (and optionally `last_relief_pct`) in the `compaction_ai` artifacts
  node (§1.2). Extend `cache_artifact` (`:158`) so the node carries `segment_digest`, `summary`,
  **and** `last_ran_step`; write it on **every** `Compacted` return. Read it at entry via a
  `last_ran_step` accessor over `ctx.artifacts` (mirror `cached_summary`, `:144`).
- **Rule** at entry, after the threshold check but before batching/AI:
  ```
  gap = ctx.step - last_ran_step        -- ctx.step = step_idx (session.ail:1623)
  if last_ran_step >= 0
     && gap < min_gap_steps
     && pct < hard_override_pct          -- safety valve
  then PassThrough
  ```
  - `min_gap_steps` proposal: **3** (one real compaction buys ~3 steps of no AI call; tune against
    the DST).
  - `hard_override_pct` proposal: **emergency_pct (95)** — if the uncompacted window has climbed back
    to the danger zone during the gap, **override** the rate-limit and compact anyway. This keeps the
    rate-limit from ever letting the window explode; structural (WS1) is still eliding every step
    regardless, so the sent window is protected, but this is the belt-and-suspenders.
- **Why this is sound under ephemerality and the PassThrough/artifacts constraint (§1.2):**
  - We only ever *write* state on the `Compacted` path, which does carry artifacts. ✔
  - A rate-limited step returns `PassThrough`, which *inherits* the incoming artifacts unchanged
    (`runtime.ail:166`), so `last_ran_step` persists and the gap is measured from the last *actual*
    compaction. ✔ No no-op state needs writing (the thing we cannot write, §1.2).
  - The pre-call guard (§3.2) and the rate-limit are independent gates: guard = "is this pass worth
    it at all?"; rate-limit = "did we just do one?". They do not need to share state.

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
  artifact_cache_effective}` (`packages/motoko_ext_conformance/harness.ail:225,237,250,…`).
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
Two extension scenarios:
- *Drip case*: a transcript where only ~1 turn is older than `keep_recent` ⇒ assert `PassThrough`
  and **no** AI-stub call spent (assert `compaction_ai_applied` does not increment — the DST already
  projects `TraceStageApplied` counts, `long_qwen_compaction_dst.ail:378,517`).
- *Batch case*: a long transcript with many old paired turns ⇒ assert one `Compacted` with `old`
  turns ≫ 1 and `new_pct` meaningfully below `pct` (relief ≥ `min_relief_pct`), tool pairing intact.
- *Rate-limit case*: two consecutive steps over threshold with `gap < min_gap_steps` and
  `pct < hard_override_pct` ⇒ assert step N is `Compacted` (writes `last_ran_step`) and step N+1 is
  `PassThrough`. Then a step at `pct ≥ hard_override_pct` ⇒ assert it compacts despite the gap.
  Note the existing DST asserts *≥3 AI stages applied* (`scenario_multiple_compactions`, `:548-559`)
  — **the rate-limit will reduce the applied count on the current fixture**; that assertion must be
  re-tuned (raise the transcript length / spread compactions across more steps, or relax the `< 3`
  bound) so it reflects the new bounded cadence rather than the old every-step thrash. Call this out
  as an expected, intended DST delta, not a regression.

**WS3 — context-window fields are unambiguous.**
In `runtime_status_tool_dst.ail`, assert the emitted status contains the `"last_sent"` and
`"uncompacted_pending"` sub-objects and the `"note"`, and that `last_sent.usage_pct` tracks the
provider tokens while `uncompacted_pending.calibrated_pct` can differ — proving the two-window reading
is explicit. Update `test_runtime_status_reports_actual_context_window` per §4.3.

**Regression guard for the exhaustion contract:** keep a scenario where even `keep_last=1` exceeds the
hard limit and assert `CompactionExhausted` still fires (`session.ail:1635`), so WS1's gentler
selection does not silently swallow a genuinely-exhausted window.

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
   is load-bearing for reasoning about combined behavior in the DST — flagged so it is verified, not
   assumed, during implementation.

6. **WS3 ripple to check, not assumed clean:** grep TS/web/deploy consumers of the flat
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
3. **WS2** last (largest; batch + guard + rate-limit; re-tune the `scenario_multiple_compactions`
   applied-count assertion as an intended delta).

Each step: keep `make compaction_dst` + `make conformance` green before moving on.
