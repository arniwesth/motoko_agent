# 2026-07-03 Phase B phase-results implementation

Implemented `PLAN-phase-b-phase-results.md` WI-0 through WI-8 on branch
`arniwesth/mot-27-phased-core-architecture`.

## Commit sequence

- `fd933b6` WI-0 Phase B parity instruments
- `06ddc78` WI-1 Complete ledger vocabulary projection
- `203e84c` WI-2a Migrate summary and session events to ledger
- `98d4bac` WI-2b Migrate model events to ledger
- `2e9427c` WI-2c Migrate tool events to ledger
- `ba80e89` WI-3 Route stream deltas through ledger
- `5e1cd1e` WI-4 Add provider call prepared ledger event
- `a329c13` WI-5 Hide system prefix from compactors
- `7168fb0` WI-6 Chain extension compactors
- `9f9711e` WI-7a Export core compaction substrate
- `6db77c6` WI-7b Add structural compaction package
- `8361e36` WI-7c-d Relocate structural compaction
- `a9616ad` WI-8 Add Phase B final gates

## What landed

- Added deterministic Phase B parity instruments: fixture extension, stream smoke,
  inventory baseline, TUI unknown-event test, and harness strip/new-event handling.
- Completed the sealed `LedgerEvent` vocabulary and golden byte projection coverage.
- Migrated all v2 JSONL event emission behind `ledger_emit`, leaving `emit_event` at
  zero uses and `emit_json` at two uses.
- Routed stream deltas through the ledger projection.
- Added `provider_call_prepared` and harness assertions for message count, system-prefix
  count, and payload digest.
- Hid system-prefix messages from compactor hook inputs while re-pinning them after
  compaction.
- Replaced first-compact-wins pre-step dispatch with a fold-through compactor chain and
  per-stage validation; invalid stages emit `ext_compaction_rejected`.
- Fixed the compactor-output pair-preservation validator by comparing against the full
  output transcript rather than the shrinking recursion tail.
- Added `packages/motoko-ext-compaction-structural`, registered it last in all profiles,
  and retired the core structural compaction shim. Core now performs only the post-chain
  exhaustion check.
- Added `scripts/phase_b_projection_gate.sh` for the final emitted-type subset gate.

## Baselines and gates

- Final blessed parity baseline: `/tmp/phase_b_blessed`.
- Strict final parity passed:
  `PARITY_BASELINE=/tmp/phase_b_blessed make smoke_parity`.
- Projection subset gate passed:
  `./scripts/phase_b_projection_gate.sh /tmp/phase_b_blessed`.
- Streaming sequence assertion passed against `smoke_v2_stream_parity.jsonl`.
- Fixture compactor assertion passed: four `fixture_prestep sys=0` lines.
- Counts verified: `emit_event(` = `0`, `emit_json(` = `2`.
- `ailang --version` verified: v0.26.0, commit `3b52a24`.

## Verification run

Passed:

- `make check_core`
- `make test_core`
- `make test_integration`
- `make build`
- `ailang test src/core/phase_vocab.ail`
- `ailang test src/core/ext/runtime.ail`
- `AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-structural/compaction_structural.ail`
- `ailang check scripts/probe_phase_vocab_sealed.ail` failed with `IMP010` as expected
- `ailang verify packages/motoko-ext-compaction-structural/compaction_structural.ail`

TUI residual:

- `cd src/tui && npm test` still fails before executing tests with the pre-existing
  Bun/Jest error: `TypeError: Attempted to assign to readonly property` across all suites.

## Implementation findings

Recorded in `.agent/projects/004_phase_core_refactor/NOTE-phase-b-implementation-findings.md`:

- WI-5/WI-6 validator narrowing and fix for pair-preservation identity failure.
- WI-7 registered root package could not import mirrored `motoko_core` without MOD011
  because the mirror declares the same `src/core/compaction` module name as the root.
  The structural package keeps its tiny token/usage helper self-contained for this
  in-repo path dependency.

## Final worktree note

The only remaining untracked item after the implementation was the pre-existing
`oh-my-pi/` directory, which was intentionally left untouched.
