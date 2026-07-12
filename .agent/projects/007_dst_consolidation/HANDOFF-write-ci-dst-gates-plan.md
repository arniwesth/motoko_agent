# Handoff: write the Track 1 plan — DST gates blocking in CI

Date: 2026-07-12 (written by the scope-holding session)
Audience: a fresh session that will **author `PLAN-ci-dst-gates.md`** in this directory.
You write the plan; implementation may be the same or a later session.

## Mission

Plan the wiring of the existing deterministic DST gates into GitHub Actions as **blocking checks
on every PR** (operator-confirmed 2026-07-12). No new tests are written in this track; the gates
exist and are green locally. The deliverable is a plan for CI changes plus the one missing make
target (L2 bun test).

## Reading order

1. `NOTE-dst-consolidation-scope-and-sequence.md` (this directory) — the confirmed scope and the
   track boundary. Track 1 is independent of Tracks 2/3, with one coupling rule: **CI invokes make
   targets only, never script paths** (Track 2 will move scripts; the Makefile absorbs it).
2. `.github/workflows/verify-extensions.yml` — the existing workflow. Note: it builds AILANG from
   the `ailang.toml` floor constraint (the expensive step, already paid), runs `ailang lock` +
   `sync-extension-packages.sh`, then `make check_core` and `make smoke_no_delegated_storm`.
   15-minute job timeout at this writing.
3. `Makefile` — the gate targets. At this writing: `compaction_dst` (three scripts, one with
   `--ai-stub` and broad caps), `conformance` (kit checks/tests + selftest + registry probe),
   `phase_c_l1` (depends on `compaction_dst`, adds phase_c_l1 + approval protocol + phase_c2
   wiring), `smoke_parity` (drives `scripts/phase_a_event_parity.sh`), `test_core`,
   `test_integration`, `verify_core` (Z3).
4. `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` §"Decision Drivers" —
   "CI must not hide failures behind missing AILANG package-cache state" is a decided driver, and
   the hydration constraint ("dependency hydration is a hard precondition") governs job ordering.

## Ground truth to re-establish at your HEAD

Re-verify every anchor above — Makefile line numbers and target contents may have moved.
(`.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`.)

- Time each gate locally before budgeting the job. On 2026-07-12 hardware all of
  `compaction_dst`, `conformance`, `phase_c_l1`, and the compaction_ai package tests completed
  in single-digit minutes combined, but CI runners are slower.
- **The bun runner landmine** (from `../001_DST/HANDOFF-implement-harness-boundary-dst.md`):
  the L2 test is `src/tui/src/harness-dst.test.ts` and must run via bun-native
  `bun test <explicit path>`. `bun run test` (the npm script, jest-under-bun) is broken
  repo-wide; bare `bun test` does not discover the `src/*.test.ts` family. The full `src/tui`
  suite is NOT green — gate on the DST file (and any explicitly green slice), not the suite.
- There is **no make target** for the L2 test today; the plan must add one (e.g. `dst_l2`) so CI
  never references the path directly.
- CI has no bun setup step today; `oven-sh/setup-bun` or equivalent is needed for the L2 gate.

## Decisions the plan must close (with operator sign-off where marked)

1. **Job layout**: extend the existing `verify_extensions` job vs. a parallel job in the same
   workflow vs. a new workflow. Consider: the AILANG build is the dominant cost (favors same job);
   a separate job re-pays it unless artifacts are shared; the L2 bun gate needs no AILANG at all
   (favors a tiny independent job).
2. **Exact blocking gate set** (operator sign-off): recommended floor is `compaction_dst`,
   `conformance`, `phase_c_l1`, `smoke_parity`, L2 bun test. Decide whether `test_core` /
   `test_integration` join (they may already be implied by other targets) and whether
   `verify_core` (Z3) joins as advisory-only.
3. **Disposition of `scripts/phase_b_projection_gate.sh`** — referenced by no Makefile target.
   Wire it, retire it, or record why it stays manual.
4. **Timeout budget** — measure, then set; don't inherit 15 minutes blindly.

## Acceptance criteria for the plan you write

- A PR that reintroduces the ABI 4.0 class of miss (an exhaustive-match surface not updated,
  a stale conformance kit, a broken DST scenario) fails CI.
- Green path adds bounded time to PR CI (state the measured budget).
- CI references make targets only; no script paths in the workflow file.
- Rollback is trivial (workflow-file revert; no source coupling).

## Guardrails

- Do not modify any DST scenario, invariant, or the conformance kit in this track.
- Do not "fix" the broken jest npm script as a side quest — out of scope (note it as follow-up
  if it blocks something).
- Do not add live-provider or network-dependent targets to CI (`live_*` targets are explicitly
  out — supplemental smokes per ADR-001).
