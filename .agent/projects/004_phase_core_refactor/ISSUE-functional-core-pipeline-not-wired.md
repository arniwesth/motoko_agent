# ISSUE: Phase C driver does not run on the functional-core pipeline

Date: 2026-07-05
Status: Open
Verified against: branch `arniwesth/mot-27-phased-core-architecture`, commit `64262d1`
Graph profile: `core` (extracted 2026-07-05, not stale)
ADR under review: `ADR-001-phase-oriented-core.md` (D1, D3, D5, D9)

## Summary

The Phase C driver (`src/core/session.ail:c2_loop`) wraps the pure `decide`
call but keeps the real work — compaction, state threading, telemetry tracking —
in its own `C2LoopState`-shaped data flow. The ADR's functional-core pipeline
(`StepState` → `decide` → `StepDecision` → `PhaseResult` → `StateDelta` →
`apply_state_delta`) exists as types and typechecks, but is not the live
execution path. It is exercised only by `step_machine` unit tests against
synthetic states.

Six inconsistencies, listed by severity. All claims verified against source and
code-graph.

---

## 1. `project()` is an unimplemented Phase A scaffold (CRITICAL)

**ADR claim** (D3/D9): `project()` is the core compaction scaffold — pin
system prefix → `CompactableSegment` → normalize → compactor chain → exhaustion
decision → seal into `ProviderPayload`.

**Source reality** (`src/core/phase_vocab.ail:157-171`): `project()` is a stub.
Its own comment says *"Scaffold only: Phase B replaces this body with the real
pin -> normalize -> compactor-chain -> tiers projection. It is not called from
production in Phase A."* Phase B landed (commits `99458c4`–`a73c6a8`), but
`project()` was never replaced. It wraps ALL messages (including system
messages) into `MkPayload(xs)` with no segment splitting, no compactor chain, no
system-prefix pinning, and no exhaustion check beyond a raw token-count
comparison.

## 2. The driver discards `decide`'s `CallModel` payload and runs its own compaction (CRITICAL)

**ADR claim** (D1): `decide` returns `CallModel(ProviderPayload)`; the driver
executes the decision. The payload is the sealed output of the compaction
chain.

**Source reality** (`src/core/session.ail:1382`): `CallModel(_) =>` — the
payload is bound to `_` and discarded. The driver then runs its own compaction
at lines 1385–1402:

```
split_for_compaction → dispatch_pre_step_chain → seal_compacted_payload
```

This is the real compaction path. `decide`/`project()` produce a payload that is
never used. The compactor chain runs in the driver, not inside `project()` as
the ADR prescribes.

## 3. `apply_state_delta` result is discarded — `PhaseResult.delta` is a no-op (CRITICAL)

**ADR claim** (D5): `PhaseResult` carries a `StateDelta` patch; the driver
applies it through `apply_state_delta` to produce the next state.

**Source reality** (`src/core/session.ail:1456`):

```
let applied = apply_state_delta(step_state, phase.delta);
```

`applied` is never referenced again. The `next_state: C2LoopState`
(line 1472+) is built from `st.*` fields and `new_totals`, not from `applied`.
The `StepState` with applied telemetry/totals/nudges is thrown away.
Consequence: every field in `phase.delta` — `telemetry`, `totals`,
`nudges_used`, `pending_tool_calls`, `last_finish_reason`,
`last_response_text` — is computed by `phase_from_result` and then discarded.

## 4. Telemetry is always zero — `project()` can never detect context exhaustion (HIGH)

**ADR claim** (D9): `telemetry` carries per-step usage numbers so compactor
extensions can implement actual-token-gated policy.

**Source reality**: `c2_step_state` (`src/core/session.ail:406`) hardcodes
`telemetry: { last_input_tokens: 0, last_output_tokens: 0 }` on every step.
`project()` checks `t.last_input_tokens >= pol.context_limit` — since
`last_input_tokens` is always 0, this check **never triggers**. The model-result
telemetry IS computed by `phase_from_result` (`src/core/model_phase.ail:17`:
`Some({ last_input_tokens: result.input_tokens, ...})`), but because of issue
#3, that delta is applied to a discarded `StepState` and never reaches
`C2LoopState`.

## 5. `apply_phase_result` is dead code (MEDIUM)

**ADR claim** (diagram §1): the driver applies state through
`apply_phase_result`.

**Source reality**: `apply_phase_result` (`src/core/session.ail:2086`) has
**0 callers** (verified via code-graph `q callers apply_phase_result`). The
driver calls `apply_state_delta` directly (and even that result is discarded,
per #3). `apply_phase_result` and its `SessionSnapshot` type exist but are never
used in production.

## 6. `PhaseResult.transcript_append` and `cost_delta_millicents` are unused (MEDIUM)

**ADR claim** (D5): `PhaseResult = { delta, transcript_append, events,
cost_delta_millicents }` — the driver applies all fields.

**Source reality** (`src/core/session.ail:1450-1460`): only `phase.events`
(emitted via `c2_emit_events`) and `phase.delta` (applied via
`apply_state_delta`, then discarded per #3) are read.
`phase.transcript_append` (the assistant message) is never read — the driver
builds `assistant_msg` directly from `step_result_to_message(result)` at line
1457. `phase.cost_delta_millicents` is never read — the driver computes
`step_cost` independently at line 1449.

---

## Root cause

The driver (`c2_loop`) was built pragmatically during Phase C inversion: it
wraps the pure `decide` call but keeps the real work (compaction, state
threading, telemetry tracking) in its own `C2LoopState`-shaped data flow. The
`StepState` / `PhaseResult` / `StateDelta` pipeline exists and typechecks but is
not wired into the live data path. The ADR's functional-core design is
implemented as types but not as the live execution path.

## Verification method

- `tools/code-graph/extract.sh` (profile=core, 34 modules, 591 funcs)
- `cgq.py q callers <fn>` for call-site reachability
- `cgq.py sql` for purity/effect-row cross-checks
- Direct source reads of `session.ail`, `phase_vocab.ail`, `step_machine.ail`,
  `model_phase.ail`, `compaction.ail`
- `ailang check src/core/session.ail` — typechecks clean (the inconsistencies
  are behavioral, not type errors)

## Related

- `ADR-001-phase-oriented-core.md` — D1 (pure decide), D3 (sealed types +
  project), D5 (PhaseResult + StateDelta), D9 (compactor chain)
- `DIAGRAM-phase-core-architecture.md` §1 (main loop), §3 (compaction)
- `HANDOFF-implement-phase-c2.md` — Phase C2 closeout
