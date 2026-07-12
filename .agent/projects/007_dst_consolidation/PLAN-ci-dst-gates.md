# Plan: wire deterministic DST gates as blocking PR checks

Date: 2026-07-12  
Status: proposed; operator-confirmed Track 1 scope retained  
Grounded HEAD: `83e0262`

This plan changes GitHub Actions wiring and adds the one missing Make target for the
Layer-2 Bun test. It does not change a DST scenario, invariant, conformance fixture, or
the broken repository-wide Jest runner.

## Decision summary

Use the existing `.github/workflows/verify-extensions.yml` workflow, with two jobs:

1. Extend the existing `verify_extensions` job. Its AILANG build and dependency hydration
   are already paid for, so it runs the AILANG DST gates after `make check_core`.
2. Add a small independent `dst_l2` job. It checks out the repository, installs the pinned
   Bun toolchain and `src/tui` dependencies, then runs `make dst_l2`. It must not rebuild
   AILANG.

The blocking DST floor is exactly:

- `make compaction_dst`
- `make conformance`
- `make phase_c_l1`
- `make smoke_parity`
- `make dst_l2`

The first three AILANG targets should be passed to one Make invocation:

```bash
make --keep-going compaction_dst conformance phase_c_l1
```

`phase_c_l1` depends on `compaction_dst`; one invocation lets Make satisfy that dependency
once instead of paying for a second compaction run. `--keep-going` preserves independent
failure output while still returning nonzero if any gate fails. The workflow must not use
`continue-on-error` for these five blocking gates.

Keep `make verify_core` as an explicitly advisory step (`continue-on-error: true`) in the
AILANG job. ADR-001 still defines Z3 as advisory until proof health is deliberately
promoted; the fact that this checkout's local run is currently green does not change that
decision. It is not a required branch-protection check.

Do not add `test_core` or `test_integration` to the blocking floor in this track. They are
useful local targets, but neither is a dependency of the DST gates and neither is needed
for the stated ABI-4.0/conformance/DST acceptance. Adding them would broaden the contract
without operator sign-off. Do not add any `live_*` target.

Leave `scripts/phase_b_projection_gate.sh` manual. It is an event-vocabulary projection
check over an already-produced parity directory, has no Make target, and is not required
to catch an exhaustive-match, ABI-kit, or DST-scenario regression. Wiring it would require
choosing and preserving a baseline/output contract that this track does not define. Track
2 may revisit its placement or retirement after the script inventory is consolidated.

## Ground truth at authoring HEAD

The inherited anchors were re-observed rather than trusted:

- The workflow runs on every `pull_request` without a path filter (`.github/workflows/verify-extensions.yml:17-29`), uses one `ubuntu-latest` job (`:36-40`), and currently has a 15-minute timeout (`:40`).
- It builds AILANG from the `ailang.toml` floor (`:46-92`), then directly invokes package sync and `ailang lock` (`:94-98`) before `make check_core` (`:100-101`). The existing `make smoke_no_delegated_storm` remains in scope (`:103-104`).
- `Makefile:17-19` already has `sync_packages`, which runs the package-sync script and root `ailang lock`.
- `Makefile:44-53` defines `smoke_parity`; `Makefile:55-58` defines `phase_c_l1` and its three additional scripts; `Makefile:60-66` defines the four-command `compaction_dst`; and `Makefile:68-75` defines conformance checks, tests, selftest, and registry probe.
- `Makefile:200-210` defines `test_core` and `test_integration`; `Makefile:218-237` defines `verify_core`.
- `packages/motoko_ext_conformance/ailang.toml:1-18` is conformance kit 4.0.0. The registry probe imports the generated registry and exercises the 13-hook order including `compaction_ai` (`scripts/conformance_registry_probe.ail:5-10`).
- The ADR decision driver requires CI not to hide failures behind missing package-cache state (`.agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md:42-49`). Its constraint says dependency hydration is a hard precondition (`:51-56`), and its CI guidance keeps `verify_core` advisory (`:273-287`).
- The Layer-2 file is `src/tui/src/harness-dst.test.ts`. Bun-native `bun test` with an explicit path is required; `bun run test` is the broken Jest-under-Bun script and bare `bun test` does not discover this family.
- There is no current Make target for that Layer-2 file.

### HEAD discrepancy that must stay visible

The handoff says the gates are green locally, but the current HEAD observation contradicts
that for `smoke_parity`:

- `make smoke_parity` exits 1 after 4.063s because the parity runner invokes AI-capable
  programs without an `--ai` model in this environment.
- A read-only temporary substitution of `--ai-stub` reaches the actual replay and exits 1
  on `SystemPromptEmpty`; the current fixtures pass an empty system prefix while
  `src/core/phase_vocab.ail:145-148` requires one.

This is recorded as a preflight condition, not silently fixed in this plan. The blocking
CI implementation must not be merged while `make smoke_parity` is red, and Track 1 must not
edit scenarios, invariants, or the conformance kit to make it green. An owner must either
land an already-authorized fix outside this track or obtain an explicit revision of the
operator-confirmed blocking floor. The workflow must not mark this gate advisory merely to
get a green rollout.

## Work items

### WI-0 — Re-establish the blocking precondition

Before enabling the required CI check, run the exact current Make target after the normal
hydration sequence and capture a successful result for `make smoke_parity`. Record the
reason for any fix in its owning work item. Do not alter a scenario or invariant in this
Track 1 plan.

The other blocking gates are green at HEAD, so this is a narrow readiness check rather than
a reason to redesign the gate set.

### WI-1 — Keep hydration and pin validation behind Make

Files: `Makefile`, `.github/workflows/verify-extensions.yml`.

Preserve the existing AILANG floor/install-pin sanity check, but move its shell logic into
the existing `sync_packages` recipe before package sync. The recipe should continue to:

1. compare the version parsed from `ailang.toml` with the pinned installer ref;
2. run the package synchronization; and
3. run root `ailang lock`.

Then replace the workflow's direct sync step and separate `ailang lock` step with:

```yaml
- name: Hydrate extension packages
  run: make sync_packages
```

This preserves the dependency-hydration barrier while ensuring the workflow does not invoke
a script path. Keep `make sync_packages` before `make check_core` and before all DST gates.
The later `conformance` registry probe remains the execution-level proof that generated
registry imports resolve; a successful lock alone is not treated as sufficient.

### WI-2 — Add the Layer-2 Make target

File: `Makefile`.

Add one target, preferably near the existing test targets:

```make
.PHONY: dst_l2
dst_l2:
	cd src/tui && bun test src/harness-dst.test.ts
```

The explicit path and Bun-native runner are intentional. Do not use `bun run test`, bare
`bun test`, a Jest command, the full `src/tui` suite, or a direct script path from CI.
This target is the only new gate target required by Track 1. The path may move in Track 2;
Track 2 must update this Make target, not the workflow.

### WI-3 — Extend the existing AILANG job

File: `.github/workflows/verify-extensions.yml`.

Keep the existing trigger, concurrency, checkout, AILANG floor build, version confirmation,
hydration barrier, `make check_core`, and `make smoke_no_delegated_storm`. After hydration
and core verification, add these steps:

```yaml
- name: DST AILANG gates
  run: make --keep-going compaction_dst conformance phase_c_l1

- name: smoke_parity
  run: make smoke_parity

- name: verify_core (advisory)
  continue-on-error: true
  run: make verify_core
```

Use stable step/job names so the existing required check does not churn unnecessarily. The
existing `verify_extensions` job remains required; the job fails on any blocking step. The
advisory Z3 step may display failure but must not make the job fail.

Set the existing AILANG job timeout to `20` minutes. This is a measured re-budget, not an
inheritance of 15 minutes: the AILANG build is the dominant pre-existing cost, while the
new post-hydration gate envelope is small and deterministic. Keep the workflow's every-PR
trigger unchanged.

After this edit, the workflow file must contain no direct script-path invocation. In
particular, `sync-extension-packages.sh` is reached only through `make sync_packages`, and
the new DST steps mention Make targets only.

### WI-4 — Add the independent Layer-2 job

File: `.github/workflows/verify-extensions.yml`.

Add a sibling job with a stable required check name:

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

The job is intentionally independent: it does not pay for Go or AILANG, and it does not
run the broken npm test script or the full TUI suite. Add `dst_l2` to the repository's
required PR status checks alongside the existing AILANG job. No path filter may be added.

## Timing and budget

Measured locally on 2026-07-12 with AILANG v0.26.0 and Bun 1.3.14:

| Command | Result | Wall time |
|---|---:|---:|
| `make compaction_dst` | pass | 3.002s |
| `make conformance` | pass | 2.783s |
| `make phase_c_l1` (including its compaction dependency) | pass | 4.794s |
| `make compaction_dst conformance phase_c_l1` (compaction once) | pass | 7.444s |
| `cd src/tui && bun test src/harness-dst.test.ts` | 7 pass | 0.067s |
| `make verify_core` | pass; advisory | 7.831s |
| `make test_core` | pass; not in floor | 3.452s |
| `make test_integration` | pass; not in floor | 1.725s |
| `compaction_ai/_smoke.ail` with `--ai-stub` | pass; local probe only | 0.377s |
| `make smoke_parity` | red at current HEAD | 4.063s to failure |

The measured successful blocking subset is 7.511s locally (combined AILANG DST group plus
Layer 2), excluding the currently red parity target. Budget five minutes for all
post-hydration deterministic gate steps on a GitHub runner and 20 minutes for the existing
AILANG job including its build. Budget five minutes for the independent Bun job. The first
green CI run must record actual wall time for `smoke_parity`; adjust only from that evidence.

## Verification plan

Before implementation handoff:

1. Re-run the hydration sequence, then `make --keep-going compaction_dst conformance phase_c_l1`,
   `make smoke_parity`, `make dst_l2`, and advisory `make verify_core`.
2. Verify `make -n compaction_dst conformance phase_c_l1` lists the compaction commands once.
3. Verify the workflow's only gate invocations are Make targets; grep the workflow for
   direct `scripts/` paths and fail the review if any remain.
4. Confirm the required status checks are the existing AILANG job and `dst_l2`; the advisory
   Z3 step is not required.
5. Confirm no live provider, network-dependent `live_*` target, full TUI suite, or Jest npm
   script is run.

Acceptance mapping:

- An ABI-4.0 exhaustive-match miss is caught by existing `make check_core`, the conformance
  checks, or the registry probe before the job can pass.
- A stale ABI/conformance kit fails `make conformance` (kit 4.0.0 plus its invariant tests,
  selftest, and registry-wide probe).
- A broken compaction or Phase-C DST scenario fails the blocking AILANG group.
- A parity regression fails `make smoke_parity` once its current HEAD precondition is green.
- A Layer-2 harness regression fails the independent `dst_l2` required check.
- Package hydration happens before all these checks, so missing cache state cannot turn into
  a false green.

## Rollback and scope boundaries

The operational rollback is a revert of the workflow change: it removes the required CI
invocations and the `dst_l2` job. The additive `dst_l2` Make target can remain as a harmless
local command or be reverted with the workflow; no scenario, invariant, or production
source coupling is introduced.

Out of scope: moving or consolidating scripts, adding a `make dst` umbrella (Track 2),
retiring `smoke_v2_*`, fixing the Jest-under-Bun npm script, changing parity fixtures,
changing conformance ABI behavior, adding live-provider checks, or adding new tests.

