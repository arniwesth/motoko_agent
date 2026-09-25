# Handoff: implement the functional-core pipeline wiring fix

Audience: a fresh implementer session executing
`PLAN-wire-functional-core-pipeline.md`. **The plan is the spec.** This handoff is
intentionally narrow: it tells you where things stand, what to do first, and the
hazards that will silently break parity if you miss them.

## Current state

- Branch: `arniwesth/mot-27-phased-core-architecture`.
- HEAD at handoff: `6bfe608 Reviewed plan`.
- Committed and current:
  - `fed914c` — the ISSUE (independently verified & corrected).
  - `1d0b63d`, `6bfe608` — `PLAN-wire-functional-core-pipeline.md` (four review
    iterations; converged). The plan was **verified against `fed914c`**; HEAD moved
    only by doc commits, so all `file:line` anchors still hold — but re-confirm the
    key ones (below) before editing, per house discipline.
- Worktree dirt (pre-existing, unrelated — **do not touch**):
  - `M ailang.lock`
  - `?? oh-my-pi/` (predates this project; leave it alone)
- `ailang --version` must report **v0.26.0 / `3b52a24`** before you start.

## Scope is fixed: WI-F0 → WI-F1 → WI-F2 → WI-F4

**WI-F3 is deferred** (operator, 2026-07-05) to the ABI v3 track — do not implement it.
Your entire scope is the required series, all byte-neutral:

```
WI-F0 (baseline) → WI-F1 (delete dead cluster) → WI-F2 (project prep + ModelRequest) → WI-F4 (gate)
```

**One decision is still open — confirm before WI-F1:**

- **D-F2 — the dead `SessionSnapshot` cluster.** Recommendation: **delete**. If the
  operator instead wants it kept as a future `SessionSnapshot` harness, WI-F1 becomes
  "leave in place + add a test," not a deletion. Everything else is unaffected either
  way.

## Do this, in order

Follow the plan's work items verbatim. The short version:

### WI-F0 — Baseline + instruments (do this first, no code change)
- The prior `/tmp/phase_c_blessed` is **gone** (ephemeral across sessions).
  **Regenerate** the parity baseline from the current HEAD and record the exact bless
  command in your first commit message or a scratch note. Use that path consistently
  as `<baseline>` everywhere below.
- Create `scripts/phase_f_pipeline_wiring.ail` as a checkable stub (the no-phantom-gates
  rule). Fill it in as WI-F1/F2 land.
- Confirm green *before* touching source:
  `PARITY_BASELINE=<baseline> make smoke_parity` and
  `./scripts/phase_b_projection_gate.sh <baseline>`.

### WI-F1 — Delete the dead `SessionSnapshot` cluster (finding 5)
- Re-confirm 0 callers first: `grep -rn` across `src/`, `scripts/` and
  `cgq.py q callers` for each of `apply_phase_result`, `session_from_messages`,
  `next_decision`, `SessionSnapshot`. If any caller has appeared since `fed914c`, stop
  and reconcile — do not delete a live symbol.
- Remove the four symbols (`session.ail:2061-2103`).
- Byte-neutral: parity must be unchanged.

### WI-F2 — Honest `project()` prep + shrink `ModelRequest` (findings 1, 2-residue)
- Re-confirm anchors: `project()` stub at `phase_vocab.ail:160-171`; `ModelRequest` at
  `:139`; the sole `CallModel({payload,…})` construction at `step_machine.ail:74`;
  `CallModel(_)` (payload already ignored) at `session.ail:1382`.
- Give `project()` an honest pure-prep body (pin system prefix + build
  `CompactableSegment` via `split_for_compaction`). **It must NOT make a Fail/exhaustion
  decision** — that is the effectful seal's job (`seal_compacted_payload`,
  `session.ail:1393`), and any early Fail skips events ⇒ parity break. This is the single
  most important constraint in the whole plan.
- Shrink `ModelRequest` to `{model}`; update `step_machine.ail:74` to `CallModel({model})`.
- Rewrite the stale stub comment so the "no Fail here; exhaustion is the seal; pre-gate
  is deferred to ABI v3" constraint is explicit in-code (stops a future reader
  re-adding the Fail).
- Byte-neutral: parity must be unchanged.

### WI-F4 — Closing gate
- Run the verification block (below) as a unit.
- Update `ISSUE-functional-core-pipeline-not-wired.md` → Resolved, with the per-finding
  dispositions from the plan's adjudication table (2 = not-a-defect/residue-only;
  3-totals/finish = not defects; 3-telemetry + 4 = deferred to ABI v3; 5 = fixed;
  6 = optional WI-F3).

## Verification block (run as a unit at WI-F4)

```bash
ailang --version                                   # v0.26.0 / 3b52a24
git status --short
PARITY_BASELINE=<baseline> make smoke_parity
./scripts/phase_b_projection_gate.sh <baseline>
make check_core && make test_core && make test_integration
ailang test src/core/step_machine.ail
ailang test src/core/phase_vocab.ail
ailang test src/core/session.ail
# (WI-F3 deferred — no model_phase test in scope)
ailang run --caps IO --entry main scripts/phase_c_approval_protocol.ail
ailang run --caps IO --entry main scripts/phase_f_pipeline_wiring.ail
(cd .agent/projects/004_phase_core_refactor/sketch && ailang check probe_consumer_decide.ail)
```

Because the required scope is byte-neutral, **there is no re-bless** — if
`smoke_parity` shows any diff against `<baseline>`, you have a real regression, not an
expected change. Stop and find it.

## Hazards to preserve (these are where parity silently dies)

- **`project()` must never Fail.** Re-adding the actual-token exhaustion check the stub
  had is the classic trap: it fails *before* compaction, skips `ProviderCallPrepared`
  and stage events, and breaks parity. Exhaustion is the effectful seal's job.
- **Do not thread telemetry.** `c2_step_state:406`'s hardcoded `telemetry: 0` stays as
  is. The consumer is `ExtCtx.telemetry` (ABI v3), which the operator has barred
  starting (`HANDOFF-continue-phase-c.md`). Threading it now adds unconsumed state and
  a 14-site `C2LoopState` edit for zero benefit.
- **Do not "fix" `totals` or `last_finish_reason`.** The delta carries no `totals`
  (accumulation is driver-owned) and `last_finish_reason` is a driver control signal
  `decide` branches on (`step_machine.ail:79,83`). Routing them through the delta is a
  regression, not a cleanup.
- **Do not touch the driver's inline compaction.** It is correct (the compactor chain
  is effectful; `decide` is pure and cannot run it). Only the optional WI-F3 relocates
  it, and only after resolving the `session ↔ model_phase` import cycle.
- **Do not start ABI v3, the conformance kit, `compaction_ai` 0.3.0, or the structural
  compactor.** Same boundary as the prior handoff.
- **Never read `$?` after a pipeline.** Capture command rc adjacent to the command,
  especially around the sketch/negative probes — the `ailang-run-exit-code` false alarm
  came from exactly this. The sketch sealing probe is *negative*: `IMP010` is the pass
  condition.
- **Leave `oh-my-pi/` and `ailang.lock` alone.**

## If you're tempted to do more

The ISSUE reads like a large "pipeline not wired" problem with three CRITICALs. The
plan's four-iteration review established that most of it is not-a-defect, deferred by
the ADR's own D9 design, or cosmetic — and that production compaction already works via
the effectful seal. Resist re-expanding the scope. If you believe a finding needs more
than the plan prescribes, write it up against source and take it to the operator; do
not quietly broaden the diff.
