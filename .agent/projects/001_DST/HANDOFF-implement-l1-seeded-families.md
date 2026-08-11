# Handoff: implement the L1 seeded families plan

Date: 2026-07-18 (written by the planning/review session with the operator)
Audience: a fresh agent session that will **implement** `PLAN-l1-seeded-families.md`
(this directory).

## Mission

Implement ADR-001 Phase 4 v2 per `PLAN-l1-seeded-families.md` — the plan is the normative
spec. Two steps: (1) the new gate `scripts/dst/phase_c_seeded_dst.ail` with four
`phase_c.gen.*` families, (2) one added line under the `dst_seeded` Makefile target.
The operator decisions (family set, wiring) and design decisions D1–D4 are settled — do
not re-open them. No CI changes, no shared-file changes.

## Reading order

1. `PLAN-l1-seeded-families.md` — **the spec.** Especially the per-family draw ranges,
   assertion sets, and the Non-Goals (what NOT to generate).
2. `scripts/dst/compaction_seeded_dst.ail` — **the implemented L0 template.** Copy its
   skeleton: config block, per-seed loop shape, `report_failure` usage, output contract.
   It is green and verified; deviate only where the plan says L1 differs.
3. `scripts/dst/phase_c_l1_scenarios.ail` — the fixed L1 gate whose fixture builders
   (`msg`, `policy`, `policy_with_checkpoint`, `state_from_msgs`) and scenario shapes the
   families mirror.
4. `HANDOFF-implement-seeded-scenario-generation.md` — the L0 handoff; its traps 2, 7, 8,
   10 (draw-all-params-immediately, effect rows vs caps, loud config errors, exit-code
   discipline) apply unchanged.

## Ground truth to re-establish before touching code

- **Toolchain pin: AILANG v0.26.0 (`3b52a24`).** `ailang --version`; mismatch ⇒ STOP.
- **Plan anchors grounded at branch `arniwesth/mot-41-dts-consolidation`, HEAD `5d01f22`
  ("Implemented").** If commits have since landed on `src/core/phase_vocab.ail`,
  `src/core/step_machine.ail`, `src/core/hook_phase.ail`, `src/core/ext/runtime.ail`,
  `src/core/compaction.ail`, or the seeded/L1 gates, re-verify the plan's `file:line`
  claims first.
- **Baseline green:** `make dst_seeded` and
  `make --keep-going compaction_dst phase_c_l1` pass before you start.

## What was already verified this session (trust it; don't re-derive)

- `src/core/compaction.ail` exports `estimate_tokens_messages` (line 17),
  `usage_percent_with_limit` (25), `exhaustion_pct` (30) — all `pure`.
- `phase_vocab.ail` exports everything the families need: `history_from_seed` (28),
  `history_len` (55), `history_digest` (63), `history_valid_transcript` (71),
  `split_for_compaction` (135), `SealError` variants (143), `seal_compacted_payload`
  (145), `checkpoint` (263), `apply_checkpoint` (349), `checkpoint_would_relieve` (391),
  `validate_checkpoint_chain` (593), `payload_messages` (124), `system_prefix_chars`
  (~93).
- **Seal semantics** (`phase_vocab.ail:145-155`): empty-prompt check keys on
  `system_prefix_chars(split.pinned) == 0` (**chars, not message count**) and fires
  BEFORE the exhaustion check; exhaustion is `usage_percent_with_limit(pinned ++
  chain_msgs, limit) >= exhaustion_pct()`; `Ok(MkPayload(pinned ++ chain_msgs))`.
- **`system_is_head_prefix([]) == true`** (`phase_vocab.ail:75-83`) — the empty-history
  corner in split_prefix is legal; do not clamp draws to avoid it.
- **`decide` path** (`step_machine.ail:91-129`): a fresh state (no pending tool calls,
  fresh finish reason, `step_idx` 0, zero cost) reaches `call_model_or_fail`;
  `should_checkpoint` (83-89) requires `checkpoint_enabled` AND calibrated usage ≥
  `checkpoint_pct` AND `checkpoint_would_relieve` — hence the plan's one-sided
  assertions.
- **Calibration fallback**: with zero telemetry (`last_input_tokens` and
  `last_estimated_input_tokens` = 0) calibrated usage equals the raw `Σchars/4` estimate,
  so drawn usage targets are computable via the L0 `limit_for_pct` trick.
- The fixed L1 gate runs everything needed at `--caps IO`; the seeded gate needs exactly
  `--caps IO,Env,Rand` (Env for seed config, Rand for generation). Nothing here needs
  FS/Clock/AI.

## The traps that will waste your time if you miss them

1. **Two `Message` types, two estimator sets.** L1 uses the core `Message`
   (`phase_vocab`) and `src/core/compaction` token math. The L0 gate uses the abi `Msg`
   and the `pkg/sunholo/motoko_ext_compaction_structural` estimators. Do NOT copy the L0
   gate's imports wholesale — copy its *structure* and take types/estimators from the
   core modules. If you need `validate_compactor_output` (abi `Msg`) against core
   `Message` lists, mirror how the fixed L1 gate handles the conversion — check its
   `checkpoint_output_is_valid_transcript` scenario before inventing anything.
2. **`state_from_msgs` in the fixed gate sets `last_input_tokens = context_limit`** —
   copying it verbatim silently engages calibration and breaks the computable usage
   targets. The seeded gate's state builder must zero all telemetry fields (plan
   Non-Goals).
3. **Above-threshold does NOT imply `TakeCheckpoint`** (`checkpoint_would_relieve` can
   veto). Only assert: policy-off ⇒ never; below-threshold ⇒ never; and IF
   `TakeCheckpoint` THEN the post-checkpoint invariant set (valid transcript, digest
   chain, `history_len == n_systems + 1`, next `decide` is `CallModel`). Do not tighten.
4. **Seal expectations must be recomputed from actual values**, not from the drawn target
   pct — integer division means actual usage ≥ target. Use the exported
   `usage_percent_with_limit`/`exhaustion_pct`/`system_prefix_chars` on the same inputs
   you pass to seal. Include the exactly-at-95 point (`>=` boundary).
5. **`rand_seed(seed)` then draw ALL params immediately** in every family function —
   global RNG state (L0 trap 2). Different families draw different ranges from the same
   seed; that is by design (D3) — do not add per-family seed offsets.
6. **Do not duplicate phase_c2.** No scripted model steps, no
   `dispatch_pre_step_chain`, no decision-sequence assertions. stage_records generates
   literal `PreStepStage` lists against `stage_record` only.
7. **No second RNG canary** — the L0 gate's canary already guards the `dst_seeded`
   target. Duplicating it would double-fail on an algorithm change.
8. **Output contract**: reuse the L0 line shapes with `phase_c_seeded_dst` as the gate
   name and `families=4`. Do not print the fixed gates' `PASS count=N` shape. The
   family summary line prints only when that family had zero failures.
9. **Makefile**: add the second `ailang run` line under the existing `dst_seeded` target
   — no new target, no `.PHONY` addition, no aggregate/CI edits. Lines run sequentially;
   first failure stops the target (same as `compaction_dst`).
10. **Exit-code discipline** (004 note): read each command's own exit status directly;
    never `$?` through a pipe.

## Out of scope (do not touch)

- Telemetry/calibration draw axes, `StageObserved`, illegal-input generation
  (`history_from_seed` `Err` cases), step/cost-budget families — all deferred (plan
  Non-Goals / Follow-ups).
- The fixed gates, `dst_harness.ail`, `dst_gen.ail`, the L0 seeded gate, CI workflow.
- Editing the plan or ADR-001 (report drift as a finding).

## Definition of done

The plan's Verification section, all six items green: (1) `ailang check` clean + fixed
gates green; (2) `make dst_seeded` runs both gates, twice byte-identical; (3) single-seed
replay (`DST_BASE_SEED=7 DST_SEEDS=1`) twice identical with `phase_c.gen.*` lines
present; (4) per-family broken-invariant scratchpad test shows the full failure contract
(`scenario=phase_c.gen.<family> seed=<s> invariant=...` + `trace param ...` + nonzero
exit); (5) boundary-reach confirmed at `DST_SEEDS=200` on a scratchpad copy (all three
seal outcomes, both checkpoint paths); (6) 200-seed smoke green in reasonable time.

## Suggested order

split_prefix first (smallest, no policy/state machinery — proves the gate skeleton) →
seal_boundary (exact oracle, the highest-value family) → checkpoint_pressure (the
subtlest; mind traps 2–3) → stage_records → Makefile line → full verification. Each step
leaves the tree `ailang check`-green.
