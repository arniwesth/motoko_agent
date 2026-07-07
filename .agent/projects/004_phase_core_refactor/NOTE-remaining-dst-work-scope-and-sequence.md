# Note: scope, boundaries, and sequence of the remaining DST work (3 plans, no new ADR)

Date: 2026-07-07
Status: Operator-confirmed scope; plans to be authored fresh (see below)
Provenance: authored in the session that produced the DST status map
(`mmd/dst-status.svg`) and re-grounded the "designed" band against HEAD. This note is the
context-heavy scope decision; the three plans it frames are source-heavy and are authored in
fresh sessions per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`.

Illustrated by `mmd/remaining-dst-plans.svg`.

## Why no new ADR

The three "designed but not built" items on `dst-status` are all already decided by existing
ADRs — conformance kit in **ADR-001 §6/§6.1**, ABI v3 in **ADR-001 §6**, checkpoint mechanics
in **ADR-001 D7** (with the send-gate context from **ADR-002**). Decided-but-unbuilt,
source-dense work is *implementation-plan* material, not a new ADR; writing one would
re-litigate settled questions. The one genuinely-open decision (the checkpoint *trigger*
policy) is closed **inside** its plan with operator sign-off and amended back into ADR-001 —
the established D9 / D-B5 pattern.

## The three plans and their boundaries

**Plan 2 · ABI v3 rollout** *(the dependency root — authored first)*
- In: ABI `2.2.0 → 3.0` (`ExtCtx += ports, artifacts, telemetry`; `Compacted += artifacts`);
  `compaction_ai` 0.3.0 (ports-native); re-cert of the bundled `motoko_ext_compaction_structural`
  on 3.0; folding in the typed-`LedgerTrace` consumption wiring that closes the dst-status
  "partial" (L1 scenarios assert over a captured ledger, not just pure fns).
- Carries decisions: ADR-001 **Open Q2** (artifacts raw `Json` vs typed record) and **Open Q3**
  (exact `ExtPorts` field list) — ADR-001 says freeze these *during the `compaction_ai` v0.3.0
  migration*, which is this plan.
- Spec: ADR-001 §6.

**Plan 1 · Conformance kit** *(depends on Plan 2)*
- In: `packages/motoko_ext_conformance` (`invariants.ail`, `harness.ail`); the four compactor
  scenarios (`system_prefix_preserved`, `tool_pairing_preserved`, `deterministic_replay`,
  `artifact_cache_effective`); the registry probe in core CI.
- Execution only — ADR-001 §6.1 is effectively the spec. No open decisions.
- Spec: ADR-001 §6.1.

**Plan 3 · Checkpoint trigger** *(confirmed in scope 2026-07-07; largely independent)*
- In: wire emission of `TakeCheckpoint` into the live loop (machinery + `session.ail:1293`
  handler already built); a `StepPolicy` gate; a termination guard; the ADR-001 D7 amendment.
- Carries the open decision: trigger condition · **emission site (`project` pre-check vs the
  effectful `seal` gate — the ADR-002 project-vs-seal tension)** · summary source · policy flag
  default · post-checkpoint termination guard.
- Spec: ADR-001 D7 + ADR-002.

## Dependency order and sequence

1. **ABI v3 first** — it is the root. The kit certifies ABI v3 (lockstep majors), and its
   acceptance fixture (`compaction_ai` 0.3.0) is *produced by* the ABI plan. Scoping the kit
   before ABI v3's `ExtCtx`/`ExtPorts` surface is frozen would build on a moving target
   (exactly what Open Q3 defers into this plan).
2. **Kit second** — needs both ABI v3's surface and the 0.3.0 fixture.
3. **Checkpoint** — code-surface-independent of ABI/kit (touches `step_machine`, `session`'s
   seal handler, `phase_vocab`, the scenarios), so it may run in parallel. Its *only* link to
   ABI is soft: the summary-source sub-decision *may* delegate to a compactor extension using
   ABI telemetry; v1 can instead use a trivial structural summary and stay independent. Decide
   that sub-question inside Plan 3.

## Session placement (per the meta-decision discipline)

Each plan is authored in a **fresh session grounded at HEAD**, with a **handoff written from
the current context-holding session** carrying: reading order (this note → the cited ADR
sections), the deliverable list with its gate as acceptance criteria, the enumerated open
decisions to close, and the mandatory *re-verify-every-cited-anchor-at-HEAD* instruction
(`re-ground-inherited-anchors-before-building.md`). First handoff to write:
`HANDOFF-write-abi-v3-plan.md`.
