# Handoff: implement Track 1 — DST gates blocking in CI

Date: 2026-07-12
Audience: a fresh agent session implementing
`PLAN-ci-dst-gates.md` in this directory.

## Mission

Implement the plan that wires the existing deterministic DST gates into GitHub Actions as
blocking checks on every PR. The implementation changes CI wiring and adds the missing
Layer-2 Make target. It must not add tests or change DST scenarios, invariants, the
conformance kit, production behavior, or the broken repository-wide Jest runner.

The plan is normative. Re-read it completely before editing:

```text
.agent/projects/007_dst_consolidation/PLAN-ci-dst-gates.md
```

## Read in this order

1. `NOTE-dst-consolidation-scope-and-sequence.md` — Track 1 boundary and the operator-confirmed
   every-PR blocking floor.
2. `PLAN-ci-dst-gates.md` — decisions, exact job layout, timing, acceptance mapping, and the
   known `smoke_parity` precondition.
3. `.github/workflows/verify-extensions.yml` — current AILANG build, hydration, required job,
   15-minute timeout, and every-PR trigger.
4. `Makefile` — current `sync_packages`, gate targets, dependencies, and test targets.
5. `.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md` —
   especially Decision Drivers, dependency hydration, CI Shape, and the advisory Z3 decision.
6. `.agent/projects/001_DST/HANDOFF-implement-harness-boundary-dst.md` — Bun runner landmine and
   the exact Layer-2 test slice.

Re-ground any file/line anchor at the implementation HEAD before editing. The source baseline
used by the plan is `83e0262`; the later plan-only commit does not change source anchors, but
source wins if the checkout has moved.

## Required implementation

### 1. Preserve hydration and remove workflow script-path invocation

In the existing `sync_packages` recipe, add the existing workflow's AILANG floor/install-pin
comparison before sync, but guard it with the Make variable `$(CI)` so ordinary local
`make build` callers do not acquire a new precondition. The workflow will invoke it as:

```yaml
run: make CI=1 sync_packages
```

The recipe must always continue to run package synchronization and root `ailang lock`.
Delete the workflow-local `script_ref` comparison block after moving it; otherwise the
workflow retains a direct `scripts/install-prerequisites.sh` path and duplicates validation.

Keep hydration before `make check_core` and every DST gate. The conformance registry probe is
the execution-level import-resolution proof; `ailang lock` alone is not sufficient.

### 2. Add the only new gate target

Add this Make target, preferably near the existing test targets:

```make
.PHONY: dst_l2
dst_l2:
	cd src/tui && bun test src/harness-dst.test.ts
```

Use Bun-native `bun test` with the explicit path. Do not use `bun run test`, bare `bun test`,
Jest, or the full `src/tui` suite.

### 3. Extend the existing AILANG job

Keep the current trigger, concurrency, checkout, AILANG floor build, version confirmation,
hydration, `make check_core`, and `make smoke_no_delegated_storm`.

Change the existing AILANG job timeout from 15 to 20 minutes. After core verification, add:

```yaml
- name: DST AILANG gates
  run: make --keep-going compaction_dst conformance phase_c_l1

- name: smoke_parity
  run: make smoke_parity

- name: verify_core (advisory)
  continue-on-error: true
  run: make verify_core
```

The first command deliberately passes `compaction_dst`, `conformance`, and `phase_c_l1` in
one invocation: `phase_c_l1` depends on `compaction_dst`, so compaction runs once. No
blocking step may use `continue-on-error`. `verify_core` is advisory and not a required
branch-protection check.

Do not rename the existing required job context unnecessarily. Add the new `dst_l2` check
as a required PR status check alongside the existing AILANG job.

### 4. Add the independent Bun job

Add a sibling job in the same workflow, with no AILANG or Go setup:

```yaml
dst_l2:
  name: dst_l2
  runs-on: ubuntu-latest
  timeout-minutes: 5
  steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Set up Bun
      uses: oven-sh/setup-bun@v2
      with:
        bun-version: '1.3.14'
    - name: Install TUI dependencies
      working-directory: src/tui
      run: bun install --frozen-lockfile
    - name: Layer-2 DST
      run: make dst_l2
```

The workflow must reference Make targets for gates, never script paths. Do not add a path
filter; the workflow must continue to run on every PR.

## Known blocker — do not hide it

At the implementation review HEAD, `make smoke_parity` is red locally:

- it exits after 4.063s because the parity runner requests AI-capable execution without an
  `--ai` model in this environment;
- `scripts/phase_a_event_parity.sh:18,69-81` uses full `Net,AI,...` capabilities and neither
  `--ai` nor `--ai-stub`;
- a read-only temporary `--ai-stub` substitution reaches the replay but fails on
  `SystemPromptEmpty` because the current fixtures provide an empty system prefix while
  `src/core/phase_vocab.ail:145-148` requires one.

Do not solve this by adding provider credentials, a real `--ai` model, a live target, or by
silently making `smoke_parity` advisory. Do not edit a DST scenario, invariant, or
conformance kit in this track. Before enabling the required CI check, obtain a successful
deterministic, network-free `make smoke_parity` result through an authorized fix outside
this Track 1 implementation, or obtain an explicit revision of the operator-confirmed
blocking floor. If the blocker remains, stop and report it rather than landing a permanently
red required check.

## Explicit non-goals

- No new tests or DST scenarios.
- No changes to DST invariants or conformance ABI behavior.
- No `make dst` umbrella target; Track 2 owns that.
- No `scripts/` consolidation or `smoke_v2_*` retirement audit.
- Leave `scripts/phase_b_projection_gate.sh` manual; do not add it to CI.
- Do not add `test_core` or `test_integration` to the blocking floor.
- Keep `verify_core` advisory-only.
- No `live_*` or provider/network-dependent target.
- Do not fix the broken Jest-under-Bun npm script or gate on the full TUI suite.

## Verification checklist

Re-run the exact commands after implementation, after normal hydration:

```bash
make --keep-going compaction_dst conformance phase_c_l1
make smoke_parity
make dst_l2
make verify_core                 # advisory; may be non-blocking
```

Also verify:

```bash
make -n compaction_dst conformance phase_c_l1
rg -n 'scripts/' .github/workflows/verify-extensions.yml
git diff --check
git status --short
```

Expected results:

- the dry run lists each compaction scenario command once;
- the workflow `scripts/` search is empty;
- the five blocking gates have no `continue-on-error`;
- `dst_l2` runs exactly `bun test src/harness-dst.test.ts` after frozen-lockfile install;
- no live provider, full TUI suite, or Jest npm script appears in the workflow;
- `make smoke_parity` is green before the required CI check is enabled.

Measured local reference from the plan: combined AILANG DST gates 7.444s, Layer 2 0.067s,
`verify_core` 7.831s advisory, and the optional `compaction_ai` package smoke 0.377s.
The current parity command is measured only to its failure at 4.063s, so record a successful
runner wall time before finalizing the CI budget.

## Acceptance and rollback

The existing AILANG job must fail on `check_core`, conformance/registry drift, compaction or
Phase-C scenario failures, and parity failures. The independent required `dst_l2` job must
fail on the harness-boundary regression. Dependency hydration must precede all of them.

Rollback is a workflow revert. The additive `dst_l2` target may remain as a harmless local
command or be reverted with the workflow; no production or scenario source coupling is
introduced.
