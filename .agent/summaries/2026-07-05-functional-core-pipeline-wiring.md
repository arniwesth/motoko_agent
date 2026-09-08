# 2026-07-05 Functional Core Pipeline Wiring

## Context

Executed `PLAN-wire-functional-core-pipeline.md` on branch
`arniwesth/mot-27-phased-core-architecture`, scoped exactly to:

```
WI-F0 -> WI-F1 -> WI-F2 -> WI-F4
```

WI-F3 was not implemented. ABI v3, telemetry threading, conformance kit work,
`compaction_ai` 0.3.0, and structural compactor work were left untouched.

Toolchain verified:

```
AILANG v0.26.0
Commit: 3b52a24
```

## Baseline

Regenerated the parity baseline into:

```
/tmp/phase_f_pipeline_blessed
```

Exact command:

```bash
./scripts/phase_a_event_parity.sh /tmp/phase_f_pipeline_blessed
```

No re-bless was done after implementation. All final parity checks diffed
against that baseline and passed byte-identically.

## Changes Made

### WI-F0

- Added `scripts/phase_f_pipeline_wiring.ail`.
- Started it as a checkable harness, then filled it in after WI-F2.
- Initial gates passed:
  - `PARITY_BASELINE=/tmp/phase_f_pipeline_blessed make smoke_parity`
  - `./scripts/phase_b_projection_gate.sh /tmp/phase_f_pipeline_blessed`
  - `ailang check scripts/phase_f_pipeline_wiring.ail`

### WI-F1

Deleted the dead `SessionSnapshot` cluster from `src/core/session.ail`:

- `SessionSnapshot`
- `session_from_messages`
- `apply_phase_result`
- `next_decision`

Caller proof:

- `rg` across `src/` and `scripts/` returned no references after deletion.
- Refreshed `tools/code-graph/extract.sh`; fresh non-stale `cgq.py q callers`
  returned empty for all four symbols.

### WI-F2

Updated `src/core/phase_vocab.ail`:

- `ModelRequest` is now `{ model: string }`.
- `project()` is now `export pure func`.
- `project()` returns structural prep:
  - `split: PinnedSplit`
  - existing event-shape metadata
- The code comment explicitly preserves the boundary:
  - no `Fail` in `project()`
  - exhaustion belongs to `seal_compacted_payload`
  - actual-token pre-gate is deferred to ABI v3
  - live driver consumes the prep directly only after optional WI-F3

Updated `src/core/step_machine.ail`:

- `CallModel({ payload: projection.payload, model: pol.model })`
  became `CallModel({ model: pol.model })`.
- The old early-exhaustion test was replaced with a test asserting actual-token
  pressure still returns `CallModel`.

Updated `scripts/phase_c_l1_scenarios.ail`:

- The old payload-pressure scenario now checks projected pinned and compactable
  prep.
- The old zero-compactor early-exhaustion scenario now asserts actual-token
  pressure defers to the effectful seal and still produces `CallModel`.

Updated `scripts/phase_f_pipeline_wiring.ail`:

- Added focused checks that `project()` does not fail under token pressure.
- Added focused checks that `decide()` returns `CallModel({model})` under token
  pressure.

### WI-F4

Updated `.agent/projects/004_phase_core_refactor/ISSUE-functional-core-pipeline-not-wired.md`:

- Status set to resolved.
- Added the baseline command note.
- Added per-finding dispositions:
  - finding 1 fixed
  - finding 2 not a correctness defect, residue fixed
  - finding 3 totals and finish reason not defects
  - finding 3 telemetry deferred to ABI v3
  - finding 4 deferred to ABI v3
  - finding 5 fixed
  - finding 6 deferred with optional WI-F3 / ABI v3

## Verification

Final verification passed:

```bash
ailang --version
git status --short
PARITY_BASELINE=/tmp/phase_f_pipeline_blessed make smoke_parity
./scripts/phase_b_projection_gate.sh /tmp/phase_f_pipeline_blessed
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail
ailang test src/core/phase_vocab.ail
ailang test src/core/session.ail
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang run --caps IO --entry main scripts/phase_f_pipeline_wiring.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

Additional verification:

```bash
tools/code-graph/extract.sh
python3 tools/code-graph/query/cgq.py q callers apply_phase_result
python3 tools/code-graph/query/cgq.py q callers session_from_messages
python3 tools/code-graph/query/cgq.py q callers next_decision
python3 tools/code-graph/query/cgq.py q callers SessionSnapshot
rg -n '\b(apply_phase_result|session_from_messages|next_decision|SessionSnapshot)\b' src scripts
```

The `cgq.py` caller queries were non-stale and empty. The final `rg` returned no
references.

## Final Worktree State

Expected work from this session:

- `M .agent/projects/004_phase_core_refactor/ISSUE-functional-core-pipeline-not-wired.md`
- `M scripts/phase_c_l1_scenarios.ail`
- `M src/core/phase_vocab.ail`
- `M src/core/session.ail`
- `M src/core/step_machine.ail`
- `?? scripts/phase_f_pipeline_wiring.ail`

Pre-existing or unrelated dirt left untouched:

- `M .agent/projects/004_phase_core_refactor/PLAN-wire-functional-core-pipeline.md`
- `M ailang.lock`
- `?? .agent/projects/004_phase_core_refactor/HANDOFF-implement-pipeline-wiring.md`
- `?? oh-my-pi/`

No commit was made.
