# 2026-07-06 Compaction DST Scenarios Implementation

## Context

Implemented `.agent/projects/001_DST/PLAN-compaction-dst-scenarios.md`, covering the five "now" ADR-002 compaction DST scenarios and their build-gate wiring. The three gated ABI-v3 scenarios were intentionally left unimplemented and unregistered.

Toolchain was verified before implementation:

- `AILANG v0.26.0`
- commit `3b52a24`

Baseline was verified before edits:

- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` passed with 12 scenarios.
- `ailang check src/core/test/integration_tests.ail` passed.
- `scripts/smoke_catalog_compaction.ail` was red on the stale `src/core/compaction` import, as expected by the plan.

## Changes Made

- Fixed `scripts/smoke_catalog_compaction.ail` by repointing `compact_step_with_limit` to `pkg/sunholo/motoko_ext_compaction_structural/compaction_structural`.
- Extended `scripts/phase_c_l1_scenarios.ail` with `segment_excludes_system_prefix`, asserting that `split_for_compaction` pins the system prefix and `segment_messages` exposes only non-system compactable messages.
- Added `scripts/compaction_policy_dst.ail` with the three pure policy scenarios:
  - `compaction.estimate_tier_ladder`
  - `compaction.tool_shape_preserved_by_elision`
  - `compaction.emergency_recovery_or_defer`
- Added `scripts/compaction_catalog_dst.ail` with `catalog_limit_qwen`, asserting `catalog_context_limit_for("ollama/qwen3.6:35b-a3b-mxfp8") == 262144`.
- Added `compaction_dst` to `Makefile`.
- Wired `phase_c_l1` to depend on `compaction_dst`, so the new DST scripts run with the existing L1 gate.

The implementation was committed as:

- `4786355 Implemented plan`

## Verification

Final green checks run during the session:

```sh
ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail
ailang run --caps IO --entry main scripts/compaction_policy_dst.ail
ailang run --caps IO,Env,FS --entry main scripts/compaction_catalog_dst.ail
make compaction_dst
make phase_c_l1
ailang check scripts/smoke_catalog_compaction.ail
ailang check src/core/phase_vocab.ail
ailang check src/core/context_usage.ail
```

Acceptance grep checks also passed:

- No hardcoded `70`, `85`, or `95` threshold comparisons in `scripts/compaction_policy_dst.ail`.
- `scripts/compaction_policy_dst.ail` targets `compact_for_pre_step`, not `compact_step_with_limit`.
- `262144` does not appear in the pure policy or phase-C L1 scenario files.
- No provider mocking, recorder hooks, `run_v2`, `scripted_ports`, `dispatch_step`, `LiveAI`, or AI/Net cap dependency in the new DST scripts.
- Gated scenarios remain unregistered:
  - `actual_tokens_drive_next_step`
  - `actual_tokens_small_context_fail_open`
  - `summarizer_uses_agent_model`

## Teeth Checks

Temporary negative checks were performed and then reverted:

- Changed the segment scenario expected pinned count from `2` to `3`; `phase_c_l1_scenarios` failed with scenario id `segment_excludes_system_prefix` and invariant `compactable segment excludes the system prefix`.
- Changed the tier ladder expected keep-last constant from `elide_keep_last()` to `elide_hard_keep_last()`; `compaction_policy_dst` failed with scenario id `compaction.estimate_tier_ladder` and invariant `elide tier keeps imported keep-last`.

Both confirmed the scenarios fail with the required reporting shape.

## Notes

The policy scenarios use small injected `ctx.context_limit` values and imported tier constants. The qwen `262144` catalog value is asserted only in the catalog DST script, matching ADR-002's qwen-agnostic tier decision.

Current worktree at summary time had an unrelated untracked file:

- `.agent/projects/004_phase_core_refactor/HANDOFF-write-harness-boundary-dst-adr.md`
