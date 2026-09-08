# Note: scope, boundaries, and sequence of the DST consolidation (3 tracks, no new ADR)

Date: 2026-07-12
Status: Operator-confirmed scope; plans to be authored fresh per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`
Provenance: authored in the session that closed out the ABI 4.0 observability work item
(`../004_phase_core_refactor/NOTE-abi-pre-step-observability-closeout.md`) and re-surveyed the
DST surface at that branch's HEAD.

## Why this project exists

The DST framework envisioned by `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md`
has landed piece by piece across two projects: L0 invariants and the conformance kit, L1 scenario
scripts over `src/core/test/{stub_step,scripted_ports,ext_fixture}`, the L2 harness-boundary bun
test, the typed `LedgerTrace` oracle, and ABI-lockstep conformance versioning (now 4.0). The
architecture is coherent; everything around it is fragmented:

1. **Copy-pasted scenario runners.** `scripts/phase_c2_wiring_scenarios.ail` and
   `scripts/long_qwen_compaction_dst.ail` carry byte-identical `Scenario`/`ScenarioFailure`/
   `run_all`/report machinery; `scripts/runtime_status_tool_dst.ail` and
   `scripts/phase_c_l1_scenarios.ail` carry variants. Every scenario function repeats the full
   ten-effect row.
2. **No DST gate runs in CI.** `.github/workflows/verify-extensions.yml` runs only `check_core` +
   `smoke_no_delegated_storm`. `compaction_dst`, `conformance`, `phase_c_l1`, `smoke_parity`, and
   the L2 bun test are local-Makefile-only, despite being deterministic and network-free. The
   ABI 4.0 rollout had eight exhaustive-match surfaces with zero CI coverage.
3. **`scripts/` is an attic.** 30+ `smoke_v2_*` scripts, probes, spikes, phase gates, and DST
   scenarios sit flat with no convention separating load-bearing gates from one-offs.
   `scripts/phase_b_projection_gate.sh` is referenced by no Makefile target.
4. **No as-built documentation.** The framework exists only as a delta chain of ADRs/plans across
   `001_DST` and `004_phase_core_refactor` (with colliding ADR numbers). `design_docs/` has nothing
   on DST. The status map (`../004_phase_core_refactor/mmd/dst-status.mmd`, verified 2026-07-06)
   predates the conformance kit, ABI v3/v4, checkpoint trigger, and Layer 2 all landing.
5. **Inconsistent scenario IDs.** `long_qwen` uses dotted namespaced ids
   (`compaction.long_qwen_ai_replay_deterministic`); `phase_c2` uses bare ids
   (`traced_prose_decisions`). ADR-001 makes scenario ids the stable public contract.

## Why no new ADR

Everything here executes decisions ADR-001 (001_DST) already made — scenario ids as contract,
layered gates, deterministic CI ("CI must not hide failures behind missing AILANG package-cache
state" is a stated decision driver). Consolidation is execution and documentation, not a new
decision. Per the `../004_phase_core_refactor/NOTE-remaining-dst-work-scope-and-sequence.md`
precedent, decided-but-unbuilt work is plan material; the small open choices (job layout in CI,
`scripts/` layout) close inside their plans with operator sign-off.

## Operator-confirmed scope (2026-07-12)

All three tracks confirmed in scope. Confirmed sub-decisions:

- **DST gates are blocking on every PR**, not nightly-only. They are deterministic; the expensive
  CI step (building AILANG from the `ailang.toml` floor) is already paid in the existing workflow.
- **The `smoke_v2_*` retirement audit is deferred** to a follow-up item. Track 2 stays low-churn
  (runner + IDs + layout). The audit — which smokes are subsumed by L1 scenarios — is recorded
  below as follow-up, not scoped into any track.

## The three tracks and their boundaries

**Track 1 · CI wiring** *(first — protect the surface before moving it)*
- In: extend `.github/workflows/verify-extensions.yml` (or add a sibling job) to run
  `make compaction_dst`, `make conformance`, `make phase_c_l1` (chains compaction_dst + c2 +
  approval protocol), `make smoke_parity`, and the L2 bun test (`cd src/tui && bun test
  src/harness-dst.test.ts` — needs a new make target and bun setup in CI; bun-native runner only,
  the npm `test` script is broken repo-wide).
- Constraint that keeps tracks decoupled: **CI invokes make targets only, never script paths** —
  Track 2 may move scripts, and the Makefile absorbs the moves.
- Carries decisions: same job vs. separate job (timeout budget), disposition of the orphaned
  `phase_b_projection_gate.sh`, whether `verify_core` (Z3) joins as advisory.
- Independent of Tracks 2 and 3.

**Track 2 · Code consolidation** *(second; one plan)*
- In: extract the shared scenario runner into `src/core/test/dst_harness.ail` (`Scenario`,
  `ScenarioFailure`, `run_all`, uniform failure report: scenario id + failed invariant + trace);
  migrate the four L1 scenario scripts and the conformance selftest onto it; normalize all
  scenario IDs to the dotted namespace (`compaction.*`, `phase_c.*`, `runtime_status.*`,
  `conformance.*` — already dotted — plus `harness.*` for L2); add a `make dst` umbrella target;
  reorganize `scripts/` so DST gates are distinguishable from spikes/probes/smokes.
- Carries decisions: `scripts/dst/` subdirectory vs. naming-prefix convention; whether the
  ten-effect row can be centralized in the harness's `Scenario` type.
- Out: smoke retirement (deferred), any behavior change to scenarios, any change to the
  conformance kit's ABI-lockstep contract.
- Gate: every migrated script produces the same scenario ids and pass counts as before migration
  (compaction_dst 8, phase_c_l1 15, phase_c2 18, conformance 4 + probe), and Track 1's CI stays
  green through the move.

**Track 3 · As-built framework doc** *(last — documents the consolidated end state)*
- In: one DST framework reference in `design_docs/implemented/motoko_agent/` describing the
  framework as-built: the layers, ports/fakes seams, ledger-as-trace oracle, conformance kit and
  ABI lockstep, scenario-id contract, gate inventory, and how to add a scenario. Cross-linked to
  the six ADRs across `001_DST`/`004_phase_core_refactor` per the "cross-link, don't move"
  principle in `.agent/issues/docs-split-across-agent-and-design-docs.md` — this dissolves the
  ADR-numbering collision without renumbering. Plus a refreshed `dst-status` map replacing the
  stale 2026-07-06 one.
- Its handoff is **not written yet**: it consumes Track 2's end state, so authoring it now would
  bake in stale anchors (`re-ground-inherited-anchors-before-building.md`). The session that lands
  Track 2 writes `HANDOFF-write-dst-as-built-doc.md`.

## Sequence

1. **Track 1 first** — independent, cheapest, and the guard for everything after it.
2. **Track 2 second** — moves code under CI protection; Makefile absorbs path changes.
3. **Track 3 last** — documents what exists after consolidation, not before.

## Follow-ups recorded, not scoped

- `smoke_v2_*` subsumption audit and retirement (operator-deferred 2026-07-12).
- The broader docs-split remediation stays with
  `.agent/issues/docs-split-across-agent-and-design-docs.md`; Track 3 implements its
  cross-link-and-index pattern for the DST topic only.

## Session placement

Each plan is authored in a fresh session grounded at HEAD, from a handoff written by this
context-holding session. Handoffs written now: `HANDOFF-write-ci-dst-gates-plan.md` (Track 1),
`HANDOFF-write-dst-code-consolidation-plan.md` (Track 2). Both carry the mandatory
re-verify-every-cited-anchor-at-HEAD instruction.
