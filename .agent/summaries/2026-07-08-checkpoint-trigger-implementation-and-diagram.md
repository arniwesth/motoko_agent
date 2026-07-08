# 2026-07-08 checkpoint trigger implementation and diagram

Implemented Plan 3 (`.agent/projects/004_phase_core_refactor/PLAN-checkpoint-trigger.md`) and committed it as:

- `c611a78 Implement checkpoint trigger guard`

## Implementation

- Added `checkpoint_enabled` and `checkpoint_pct` to `StepPolicy`.
- Added pure helper surface in `src/core/phase_vocab.ail`:
  - `history_usage_percent`
  - `checkpoint_would_relieve`
  - `history_messages`
- Wired the checkpoint trigger inside `call_model_or_fail` in `src/core/step_machine.ail`, after step/cost failures and before `project`/`CallModel`.
- Added structural checkpoint plan/summary helpers in `step_machine.ail`.
- Retargeted the old never-emit tests to “never emits by default” and added positive pressure/no-spin coverage.
- Updated checkpoint output validation to use:
  - `validate_compactor_output` on the non-system segment
  - `history_valid_transcript` on the full checkpointed history
- Amended ADR-001 D7 with default-off emission, `checkpoint_would_relieve`, the no-escape seal-exhaustion terminal, and the split validation obligation.

## Important Drift Found

The plan claimed the live `TakeCheckpoint` handler already threaded the checkpointed state. HEAD actually emitted the checkpoint event but kept `msgs: st.msgs`, which would have re-entered the loop with the old history. Recorded this as G5 in the plan and fixed it by adding `history_messages(History) -> [Message]` and using:

```ailang
msgs: history_messages(cp.state.history)
```

in `src/core/session.ail`.

## Verification

Baseline before edits:

- `make check_core`: green
- `phase_c_l1_scenarios`: `PASS count=13`

Final gates:

- `ailang check src/core/step_machine.ail src/core/phase_vocab.ail`: `No errors found`
- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail`: `phase_c_l1_scenarios PASS count=15`
- `make check_core`: `src/core/ type-check: 34 passed, 0 failed`
- ADR grep found both `checkpoint_enabled` and `never emits by default`

Behavioral repro added at `scratchpad/verify_guard.ail`:

```text
pressured before=TakeCheckpoint
pressured after=CallModel
degenerate decision=CallModel
verify_guard PASS
```

## Diagram Work

Created the actual implemented end-state diagram:

- `.agent/projects/004_phase_core_refactor/mmd/checkpoint-trigger-implemented-end-state.mmd`
- `.agent/projects/004_phase_core_refactor/mmd/checkpoint-trigger-implemented-end-state.svg`

Also updated:

- `.agent/projects/004_phase_core_refactor/mmd/README.md`

Grounding used refreshed code graph:

- `tools/code-graph/extract.sh`: core graph clean, `34 modules, 601 funcs, 810 invokes`, stale false.
- `tools/code-graph/extract.sh --profile=all`: source index refreshed, `166 modules, 1691 funcs, 2170 invokes`.

The all-profile typed extraction reported unrelated existing iface failures in packages/examples, so the diagram labels scenario/package nodes as fresh source-index grounded and core control-flow nodes as clean core-graph grounded.
