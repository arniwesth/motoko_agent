# ISSUE: Phase C driver runs the functional-core pipeline only partially

Date: 2026-07-05 (originally filed); independently verified & corrected 2026-07-05
Status: Open
Verified against: branch `arniwesth/mot-27-phased-core-architecture`, commit `fed914c`
  (original filing verified `64262d1`; the `64262d1→fed914c` diff on `session.ail`
  is header-comment-only — no behavioral change in the reviewed region, so line
  numbers below are re-anchored to `fed914c` and every claim is judged as written)
Graph profile: `core` (extracted 2026-07-05, not stale)
ADR under review: `ADR-001-phase-oriented-core.md` (D1, D3, D5, D9)

## Summary

The Phase C driver (`src/core/session.ail:c2_loop`) wraps the pure `decide`
call and threads *some* of the functional-core pipeline live — `apply_state_delta`
runs and feeds `pending_tool_calls`, `last_response_text`, and `nudges_used`
into the next state — but keeps the load-bearing work (compaction, telemetry,
totals, transcript building, cost) in its own `C2LoopState`-shaped data flow.
The compaction sub-pipeline in particular (`project()` → `ProviderPayload`) is a
stub whose output the driver discards, running its own compaction instead.

So the ADR's pipeline (`StepState` → `decide` → `StepDecision` → `PhaseResult` →
`StateDelta` → `apply_state_delta`) is **partially** the live path: state-delta
threading of tool-calls/response-text is real; compaction, telemetry, totals,
transcript-append, and cost are not. The earlier framing ("exists as types but
is not the live execution path", "PhaseResult.delta is a no-op") was too strong —
see the correction under §3.

Six findings, listed by severity. All claims re-verified against source and
code-graph at `fed914c`.

---

## 1. `project()` is an unimplemented Phase A scaffold (CRITICAL)

**ADR claim** (D3/D9): `project()` is the core compaction scaffold — pin
system prefix → `CompactableSegment` → normalize → compactor chain → exhaustion
decision → seal into `ProviderPayload`.

**Source reality** (`src/core/phase_vocab.ail:160-171`): `project()` is a stub.
Its own comment says *"Scaffold only: Phase B replaces this body with the real
pin -> normalize -> compactor-chain -> tiers projection. It is not called from
production in Phase A."* Phase B landed (commits `99458c4`–`a73c6a8`), but
`project()` was never replaced. It wraps ALL messages (including system
messages) into `MkPayload(xs)` with no segment splitting, no compactor chain, no
system-prefix pinning (`system_prefix_count: 0` hardcoded), and no exhaustion
check beyond a raw token-count comparison (`t.last_input_tokens >= pol.context_limit`).

**Correction to the stub's own comment:** `project()` *is* called from
production — `decide` calls it via `call_model_or_fail` (`step_machine.ail:72`),
and `decide` runs live (`session.ail:1249`). But it is **inert**: its `Ok`
payload is discarded by the driver (see §2) and it can never reach its `Err`
branch (see §4). So it executes every step and gates nothing.

## 2. The driver discards `decide`'s `CallModel` payload and runs its own compaction (CRITICAL)

**ADR claim** (D1): `decide` returns `CallModel(ProviderPayload)`; the driver
executes the decision. The payload is the sealed output of the compaction
chain.

**Source reality** (`src/core/session.ail:1382`): `CallModel(_) =>` — the
payload is bound to `_` and discarded. The driver then runs its own compaction
at lines 1385–1393:

```
split_for_compaction → dispatch_pre_step_chain → seal_compacted_payload
```

This is the real compaction path. `decide`/`project()` produce a payload that is
never used. The compactor chain runs in the driver, not inside `project()` as
the ADR prescribes.

## 3. `apply_state_delta` is wired for some fields, bypassed for others (HIGH — was miscategorized CRITICAL "no-op")

**ADR claim** (D5): `PhaseResult` carries a `StateDelta` patch; the driver
applies it through `apply_state_delta` to produce the next state.

**Correction of the original finding.** The original issue claimed *"`applied`
is never referenced again"* and *"every field in `phase.delta` … is computed …
and then discarded"* — **both are false, and were false at the filing commit
`64262d1`.** In current source `applied` is read at six sites
(`session.ail:1485, 1498, 1505, 1506, 1537, 1563`), feeding
`applied.pending_tool_calls`, `applied.last_response_text`, and
`applied.nudges_used` into the next `C2LoopState`. `result_delta`
(`model_phase.ail:14`) sets `pending_tool_calls` and `last_response_text` to
real model-derived values, and `apply_state_delta` (`phase_vocab.ail:356-358`)
carries them through — so genuine delta values flow into the live loop. The
delta is **not** a no-op.

**What is actually wrong** (`src/core/session.ail:1456`):

```
let applied = apply_state_delta(step_state, phase.delta);
```

The driver reads `applied` for `pending_tool_calls` / `last_response_text` /
`nudges_used`, but **bypasses three delta fields**:

- `totals` — next_state uses the driver's own `new_totals`
  (`c2_add_step_totals`, `session.ail:1455`), not `applied.totals`.
- `last_finish_reason` — set to branch-specific literals
  (`"intercept_handled"`, `"stream_error"`, …), not `applied.last_finish_reason`.
- `telemetry` — `applied.telemetry` **does** hold the real per-step token counts
  after the delta is applied, but it is never read, and `C2LoopState` has no
  telemetry field to hold it. (This is the mechanism behind §4.)

Consequence: the state-threading half of the pipeline is live; the
compaction/telemetry/totals half is duplicated in the driver's own `C2LoopState`
flow.

## 4. Telemetry never persists across steps — `project()` can never detect exhaustion (HIGH; moot given §1–§2)

**ADR claim** (D9): `telemetry` carries per-step usage numbers so compactor
extensions can implement actual-token-gated policy.

**Source reality**: `c2_step_state` (`src/core/session.ail:406`) hardcodes
`telemetry: { last_input_tokens: 0, last_output_tokens: 0 }` on every step, and
`C2LoopState` (`c2_initial_state`, `session.ail:417-434`) has no telemetry
field, so real per-step tokens never persist across the loop. `project()` checks
`t.last_input_tokens >= pol.context_limit` — since `last_input_tokens` is always
0, this check **never triggers**.

**Two corrections to the original finding:**

- **Attribution.** The original blamed §3 ("that delta is applied to a discarded
  `StepState`"). That is wrong — `applied` *is* used. The real reason telemetry
  is lost is narrower: `applied.telemetry` after `apply_state_delta` *does* hold
  the real tokens (`result_delta` sets it, `model_phase.ail:15`), but the driver
  never reads it and `C2LoopState` has nowhere to store it.
- **Impact.** This is moot for production behavior: because `project()`'s output
  is discarded (§2), its exhaustion check gates nothing. Real exhaustion
  detection happens in `seal_compacted_payload` inside the driver
  (`session.ail:1393-1398`). The finding matters for the *design* (the ADR's
  actual-token-gated compactor story has no live telemetry to consume), not for
  a live regression.

## 5. `apply_phase_result` is dead code (MEDIUM)

**ADR claim** (diagram §1): the driver applies state through
`apply_phase_result`.

**Source reality**: `apply_phase_result` (`src/core/session.ail:2086`) has
**0 callers** (verified: `grep` across `src/core/**/*.ail` finds only the
definition; code-graph `q callers apply_phase_result` empty). The driver calls
`apply_state_delta` directly. `apply_phase_result` and its `SessionSnapshot`
type exist but are never used in production.

## 6. `PhaseResult.transcript_append` and `cost_delta_millicents` are unused (MEDIUM)

**ADR claim** (D5): `PhaseResult = { delta, transcript_append, events,
cost_delta_millicents }` — the driver applies all fields.

**Source reality** (`src/core/session.ail`): only `phase.events` (emitted via
`c2_emit_events`) and `phase.delta` (applied via `apply_state_delta`, then
partially consumed per §3) are read. `phase.transcript_append` (the assistant
message) is never read — the driver builds `assistant_msg` directly from
`step_result_to_message(result)` at line 1457. `phase.cost_delta_millicents` is
never read — the driver computes `step_cost` independently at line 1449.
(Confirmed: `transcript_append` and `cost_delta_millicents` appear nowhere in
`session.ail`.)

---

## Root cause

The driver (`c2_loop`) was built pragmatically during Phase C inversion: it
wraps the pure `decide` call and threads the cheap parts of the delta
(`pending_tool_calls` / `last_response_text` / `nudges_used`) live, but keeps the
expensive work — compaction, telemetry, totals, transcript building, cost — in
its own `C2LoopState`-shaped data flow. The `project()` → `ProviderPayload`
compaction sub-pipeline and telemetry threading were never wired; the driver
duplicates them. So the ADR's functional-core design is the live path for state
threading but not for compaction/telemetry/transcript/cost.

## Verification method

- `tools/code-graph/extract.sh` (profile=core, 34 modules, 591 funcs)
- `cgq.py q callers <fn>` for call-site reachability
- `cgq.py sql` for purity/effect-row cross-checks
- Direct source reads of `session.ail`, `phase_vocab.ail`, `step_machine.ail`,
  `model_phase.ail`, `compaction.ail`
- Independent re-verification (2026-07-05) at `fed914c`: cross-checked `applied`
  usage against the filing commit `64262d1` (`git show 64262d1:…`), confirmed the
  `64262d1→fed914c` `session.ail` diff is header-comment-only, and re-anchored
  all line numbers. This pass overturned the original §3 ("no-op") and corrected
  the §4 attribution.
- `ailang check src/core/session.ail` — typechecks clean (the inconsistencies
  are behavioral, not type errors)

## Independent-verification verdicts (2026-07-05, commit `fed914c`)

| # | Original claim | Verdict |
|---|---|---|
| 1 | `project()` unimplemented scaffold | CONFIRMED (stub's "not called" comment itself stale — it is called but inert) |
| 2 | driver discards `CallModel` payload, runs own compaction | CONFIRMED |
| 3 | `apply_state_delta` result discarded, delta is a no-op (CRITICAL) | REFUTED as written; corrected to "partially wired" (HIGH) |
| 4 | telemetry always 0, `project()` can't detect exhaustion (HIGH) | CONFIRMED mechanism; moot for prod (§2); §3 attribution corrected |
| 5 | `apply_phase_result` dead code | CONFIRMED |
| 6 | `transcript_append` / `cost_delta_millicents` unused | CONFIRMED |

## Related

- `ADR-001-phase-oriented-core.md` — D1 (pure decide), D3 (sealed types +
  project), D5 (PhaseResult + StateDelta), D9 (compactor chain)
- `DIAGRAM-phase-core-architecture.md` §1 (main loop), §3 (compaction)
- `HANDOFF-implement-phase-c2.md` — Phase C2 closeout
