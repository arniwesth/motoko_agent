# Vocabulary sketch — pre-ADR substrate validation

Date: 2026-07-02. Toolchain: AILANG v0.26.0 (commit `3b52a24`).
Companion to `../RESEARCH-phase-core-dst-design.md`. These files are **validation
artifacts, not implementation** — the deliverable is that they check/run and that the
four pre-ADR questions below have empirical answers.

## Run

```bash
cd .agent/projects/004_phase_core_refactor/sketch
ailang check sketch_vocabulary.ail                       # passes
ailang run --caps IO --entry main sketch_vocabulary.ail  # demo: decide + checkpoint
ailang test sketch_vocabulary.ail                        # inline pure tests
ailang run --caps IO --entry main probe_opacity_legal.ail
ailang check probe_opacity_forge.ail                     # PASSES (see Q1 — export type exports ctors)
ailang check probe_sealed_forge.ail                      # FAILS with IMP010 (opacity enforced)
ailang run --caps IO --entry main probe_sealed_name.ail  # FAILS with IMP010 (type name not importable)
ailang run --caps IO --entry main probe_rec_structural.ail # runs (records forgeable)
```

## Q1 — Is D7's opacity assumption real? YES, with a co-location constraint

- `export type T = C(...)` exports the constructor too → forgeable (`probe_opacity_forge`
  checks clean). Do NOT export sealed types this way.
- An **unexported** variant type with exported ops is truly sealed: consumers can hold and
  thread values, but importing the constructor fails with `IMP010`
  (`probe_sealed_forge`).
- The unexported **type name** is also not importable (`probe_sealed_name` fails IMP010),
  so consumers cannot write signatures or record fields naming the type. Consequence:
  **records embedding `History` (i.e. `StepState`) must be co-located in the defining
  module.** The phase-core needs a single vocabulary module (working name
  `src/core/phase_vocab.ail`; final home decided in the ADR — could be `transcript.ail`).
- Exported **record** types are structurally forgeable (`probe_rec_structural`: a literal
  of the same shape passes without importing the type). Records can never be opaque —
  sealed types must be single-constructor **variants** (`MkHistory([Message])`).
- D7's self-auditing checkpoint shape — `checkpoint(h, plan) -> {history, event}` as the
  only rebuild op — type-checks and runs end-to-end (`sketch_vocabulary.ail` demo).

## Q2 — Can one LedgerEvent type serve both event vocabularies? YES

`LedgerEvent` is a typed variant; `to_schema_v1 : (LedgerEvent) -> Json` projects onto the
existing production wire contract. The 28 production schema-v1 event types are inventoried
in `sketch_vocabulary.ail`'s comment block (from `agent_loop_v2.ail` emit sites,
2026-07-02); the sketch proves the projection pattern on a representative 11-constructor
subset, including cases where one constructor maps to different legacy names by payload
(`ToolPolicyDecided` → `native_tool_denied` | `tool_pending`). **Full 28-name coverage is a
Phase B ship gate**, not a sketch goal. ADR-001 canonical names map 1:1 to constructors.

## Q3 — How is state_delta expressed? Patch-record with one application point

`StateDelta` = record of `Option` fields (absent = unchanged), applied ONLY by
`apply_state_delta` — the state mirror of single-point event emission, and itself a DST
invariant site. Checks and is ergonomic on v0.26.0; the alternative (full-state returns)
was rejected because the delta IS the observation DST wants to record.

## Q4 — Do StepDecision variants carry what they need? YES

Variants with named record payloads (`CallModel(ProviderPayload)`, `RunTools(ToolPlan)`,
`AwaitApproval(ApprovalRequest)`, `TakeCheckpoint(CheckpointPlan)`, ...) all check; the
pure `decide(StepState, StepPolicy) -> StepDecision` skeleton composes with the sealed
projection pipeline and runs. `PhaseResult` carries no `continuation` field — the step
machine re-derives the next decision from applied state, which is simpler and keeps all
control flow in `decide`.
