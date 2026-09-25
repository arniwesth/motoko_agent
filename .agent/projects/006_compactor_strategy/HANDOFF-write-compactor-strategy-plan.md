# Handoff: write the compactor-strategy refinement plan

Audience: a fresh agent session. You are deliberately fresh — see
`../004_phase_core_refactor/NOTE-plan-authoring-session-choice.md`. Freshness is a test: **if you
cannot plan this from the issue + the design doc + the code alone, there is a gap — record it in a
"gaps found" section, don't guess around it.**

## Mission

Write `PLAN-compactor-strategy.md` in this directory (`006_compactor_strategy/`): the implementation
plan for the compactor-strategy defects in `../../issues/ephemeral-compaction-and-ai-noop-thrash.md`.
Three workstreams, all **within the deliberately-ephemeral compaction model**:

1. **Structural: select tier by *result*, not by uncompacted pct** — stop over-escalating to the
   emergency `keep_last=3` tier when a gentler tier already fits.
2. **AI compactor: batch + no-op guard + rate-limit** — stop the "summarize 1 turn for 0% relief,
   every step" thrash.
3. **Observability** — make the status tool's context-window metrics legible once compaction is
   active (uncompacted-pending vs last-sent are different windows).

Do NOT start implementing. Plan only.

## Hard scope guardrails (read before anything else)

These are **out of scope** and any plan that touches them is wrong:

- **Do NOT persist compaction into history**, and **do NOT bound the retained history.** Ephemeral
  per-step compaction with the full session log retained is a **documented decision**:
  `design_docs/planned/m-motoko-conversation-compaction.md:52` — *"the returned `msgs` replaces the
  input **for this step only** — the session log is unchanged."* Consistent with the phase-core
  seed/append-only history (`history_from_seed`). Overturning it is a separate decision (a NOTE
  grounded against *why* it was chosen), not this plan. The issue's Consequence 1 says the same.
- **Do NOT re-open token calibration.** The affine model (`src/core/compaction.ail`
  `affine_calibrate` / `delta_token_density_permille`, mirrored in the two compaction extensions)
  already shipped and is correct; you *use* it, you don't change it.
- **Stay extension-side where possible.** Compaction policy is extension-resident (004 `ADR-001`
  D9). Workstreams 1–2 live entirely in the compaction extensions. Only workstream 3 (the status
  tool) is a small **core** touch — call that out explicitly.

## Reading order

1. `../../issues/ephemeral-compaction-and-ai-noop-thrash.md` — **normative**; your acceptance
   criteria are its two sections' Consequences + Fix lists (post the 2026-07-10 framing correction).
2. `design_docs/planned/m-motoko-conversation-compaction.md` — the compaction design (the tier ladder
   table, the ephemeral statement at :52). Note it is mis-filed under `planned/` though it shipped.
3. `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` §Non-goals — records that this
   work is PLAN-level, not an ADR, and why.
4. The code (re-verify at HEAD — see discipline):
   - `packages/motoko-ext-compaction-structural/compaction_structural.ail` —
     `compact_for_pre_step` (the live tier ladder, keyed off `calibrated_usage_percent_with_limit`
     of the uncompacted window), the tier constants (`elide_tier_pct` 70 / `elide_hard_tier_pct` 85 /
     `emergency_pct` 95) and `keep_last` values (10/5/3/1), `elide_old_tool_results`,
     `try_emergency_compaction_with_limit`.
   - `packages/motoko-ext-compaction-ai/compaction_ai.ail` — `compact_with_ai` (fires when
     `usage_percent(...) >= threshold_pct`), `split_body`/`split_msgs` (yields ~1 old turn),
     `new_pct` recompute (relief is ~0 but `Compacted` is still emitted), config `threshold_pct` /
     `keep_recent`.
   - `src/core/compaction.ail` — `affine_calibrate` / `calibrated_usage_percent_anchored`: the
     measurement you reuse to test candidate compactions.
   - `src/core/session.ail` — `runtime_status_json` (the `context_window` block: `actual_*` from
     `telemetry.last_input_tokens` = last **sent** window vs `estimated_*`/`calibrated_*` from
     `c2_pending_context` = **uncompacted** shadow), and `c2_pending_context`.
5. `../005_harness_policy_boundary/HANDOFF-write-empty-stop-guard-plan.md` — house style for a HANDOFF
   in this lineage; and any `../001_DST/PLAN-*.md` for DST-plan style.

## Non-negotiable discipline (verify at HEAD; anchors WILL have moved)

Grounded at branch `arniwesth/mot-35-fix-context-size-estimation`, HEAD `6d5c5de`. `session.ail`
line numbers drift (it grew 2455→2523 during recent work). So:
- `git log --oneline -20 -- src/core/ packages/` first; anything newer than `6d5c5de` touching the
  files above → re-check every inherited anchor.
- Every source claim in YOUR plan carries a `file:line` you verified yourself at HEAD.

## What the plan must specify

### Workstream 1 — structural tier-by-result
- Replace "pick tier from uncompacted `pct`" with "pick the **gentlest** `keep_last` whose
  **resulting** window fits a target." Decide the **target**: under the hard limit? under a working
  headroom (e.g. leave the model real room, not `keep_last=3` at 5% utilization)? State it and why.
- Decide how to measure a candidate's resulting size: apply the same affine calibration
  (`affine_calibrate`) to each candidate-compacted window (`anchor_real + D·(candidate_est −
  anchor_est)`), so the fit test matches how the gate measures. Note the anchor is the last **sent**
  window's real/est from `ctx.telemetry`.
- Keep the ladder monotone and terminating (tier1 → hard → emergency → final); if even the tightest
  fits nothing, preserve today's exhaustion behavior.
- Confirm this changes only `compact_for_pre_step` selection — not the elision mechanics.

### Workstream 2 — AI compactor
- **Batch:** summarize a meaningful span (e.g. everything older than `keep_recent` in one pass), not
  one turn. Reconcile with `split_body`'s tool-call/tool-result pairing protection so batched spans
  don't split a call from its result.
- **No-op guard:** if projected/actual relief `< min_relief`, return `PassThrough` and **do not**
  emit `Compacted` or spend an AI call.
- **Rate-limit:** don't run on consecutive steps after a low-relief pass. Decide where the "last ran"
  state lives (this is ephemeral compaction — probably an artifact/`ctx` field, not history).
- Explicitly out of scope: persisting the summary (guardrail above).

### Workstream 3 — observability (small core touch)
- Make `runtime_status_json`'s `context_window` unambiguous: either measure `est`/`calib` on the same
  window as `actual` once compaction is active, or **relabel** so it is obvious that
  `estimated`/`calibrated` = *uncompacted pending* and `actual` = *last sent* (a 114%-vs-10% reading
  must read as legible, not alarming). Note this is the one **core** change; keep it a labeling/field
  change, not new policy.

### Verification (make it deterministic and offline)
- Reuse the existing compaction harnesses: `make compaction_dst` (`scripts/long_qwen_compaction_dst.ail`,
  `scripts/runtime_status_tool_dst.ail`) and `make conformance` (the compactor invariants:
  `system_prefix_preserved`, `tool_pairing_preserved`, `deterministic_replay`,
  `artifact_cache_effective`). Every change must keep these green.
- Add scenarios that prove the fixes: (1) an over-full uncompacted window where a gentle tier fits →
  assert the ladder does **not** pick emergency; (2) a long transcript where the AI compactor either
  yields real relief or returns `PassThrough` (no `Compacted` with ~0% relief); (3) the status tool's
  context-window fields are unambiguous. Prefer the stub-step / scripted-provider path so they are
  offline and deterministic.

## Gaps found

Add this section. Likely gaps: the "target" for tier-by-result is a design choice the issue leaves
open (pick it, justify it); and the rate-limit "last ran" state has nowhere obviously durable under
ephemeral compaction (name where it should live). If the issue + design doc were enough to plan every
item without guessing, say so.
