# Handoff: implement Track 2 — DST code consolidation

Date: 2026-07-12  
Audience: a fresh agent session implementing
.agent/projects/007_dst_consolidation/PLAN-dst-code-consolidation.md.

## Mission

Implement the reviewed Track 2 plan: extract the duplicated in-repo DST scenario runner into
src/core/test/dst_harness.ail, normalize gate IDs, move Makefile-backed DST entrypoints under
scripts/dst/, add make dst, and keep Track 1 green after every migration commit.

This is a behavior-preserving refactor. Do not add scenarios, alter invariant wording or logic,
change thresholds/policies, change provider payloads or wire behavior, modify production modules,
retire smoke_v2_* files, or modify the ABI-versioned conformance kit.

The plan is normative. Read it completely before editing:

~~~text
.agent/projects/007_dst_consolidation/PLAN-dst-code-consolidation.md
~~~

After the final implementation commit, write:
.agent/projects/007_dst_consolidation/HANDOFF-write-dst-as-built-doc.md

That Track 3 handoff must describe the actual consolidated end state, not this plan.

## Current checkout and source baseline

The current checkout at handoff authoring is:

~~~text
HEAD: 52de4a9 — Plan reviewed
source baseline: 3ee3667 — Implemented Track 1
~~~

The commits after 3ee3667 are plan/handoff changes only. Re-ground every source anchor at the
implementation HEAD; source wins if the checkout has moved again. Do not reset or discard existing
work.

The worktree should contain only the plan/handoff changes before implementation. Preserve unrelated
user changes if any appear.

## Read in this order

1. .agent/projects/007_dst_consolidation/NOTE-dst-consolidation-scope-and-sequence.md
   — Track ordering, operator-confirmed blocking CI floor, smoke_v2_* deferral, and Track 3
   requirement.
2. .agent/projects/007_dst_consolidation/PLAN-dst-code-consolidation.md
   — normative decisions, complete ID map, baseline counts, commit sequence, and acceptance
   checks.
3. .agent/projects/001_DST/ADR-001-deterministic-simulation-testing-architecture.md
   — especially Core Components (scenario ID and failure-report contract) and Layers.
4. .github/workflows/verify-extensions.yml
   — confirm Track 1 invokes Make targets only and does not need path edits.
5. Makefile
   — current gate recipes, caps, dependency graph, hydration, and dst_l2.
6. src/core/test/stub_step.ail, scripted_ports.ail, and ext_fixture.ail
   — existing shared test seams; dst_harness.ail belongs beside them.
7. The runner-bearing scripts and gate entrypoints named in the plan.
8. packages/motoko_ext_conformance/harness.ail,
   packages/motoko_ext_conformance/invariants.ail, fixtures, and ailang.toml
   — package-side Scenario is distinct and ABI-versioned at 4.0.0; do not merge it.

## Current ground truth

The duplicated in-repo runner machinery currently exists in:

- scripts/phase_c2_wiring_scenarios.ail
- scripts/long_qwen_compaction_dst.ail
- scripts/runtime_status_tool_dst.ail
- scripts/phase_c_l1_scenarios.ail
- scripts/compaction_policy_dst.ail

The first two contain the byte-identical ScenarioFailure/Scenario/run_one/run_all/reporting
block. The other three contain variants. scripts/phase_f_pipeline_wiring.ail also has an
unrelated CheckResult aggregator named run_all; rename that helper to run_checks so the final
structural audit does not mistake it for a remaining DST runner.

Baseline counts to preserve:

~~~text
compaction_policy_dst       3 scenarios
compaction_catalog_dst      1 catalog probe
runtime_status_tool_dst     2 scenarios
long_qwen_compaction_dst    8 scenarios
compaction_dst              14 aggregate checks

phase_c_l1_scenarios        15 scenarios
phase_c_approval_protocol   7 approval cases
phase_c2_wiring_scenarios   18 scenarios

conformance_selftest        4 package scenarios x 5 hook cases = 20 invocations
conformance_registry_probe  4 package scenarios x 13 registry hooks = 52 invocations
dst_l2                       7 Bun tests
~~~

phase_c_l1 depends on compaction_dst, so that dependency must execute the 14 compaction checks
once, not twice.

Track 1's current workflow contract is target-only:

~~~text
verify_extensions:
  make CI=1 sync_packages
  make check_core
  make smoke_no_delegated_storm
  make --keep-going compaction_dst conformance phase_c_l1
  make smoke_parity
  make verify_core              # advisory

dst_l2:
  make dst_l2
~~~

Do not put scripts/dst/... paths in GitHub Actions. Make absorbs all script moves.

## Required design

### Shared harness

Add src/core/test/dst_harness.ail with one exported in-repo type:

~~~ailang
export type ScenarioFailure = {
  failed_invariant: string,
  trace: [string]
}

export type Scenario = {
  id: string,
  seed: string,
  run: () -> Result[(), ScenarioFailure]
    ! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream, Trace}
}
~~~

Export the shared print_trace, run_one, run_all, and failure-construction/reporting helpers.
Preserve scenario order, recursive failure accumulation, and pass/failure reporting. Fixed migrated
scenarios use seed="fixed"; no seeded generation is being added.

Expected in-repo reporting:

~~~text
scenario=<id> ok
scenario=<id> seed=<seed> invariant=<failed_invariant>
trace <line>
~~~

The package conformance harness has a different run signature:
its Scenario.run accepts ExtensionHooks. Keep the package Scenario, ScenarioFailure, run_scenario,
run_conformance, fixtures, invariants, and version unchanged. The selftest may use a small shared
failure-reporting adapter, but it must not replace or structurally merge the package harness.

### Effect-row decision

Use the one maximal effect row above. The reviewed probe at the source baseline passed both:

~~~bash
ailang check src/core/test/dst_harness_probe.ail
ailang run --caps IO --entry main src/core/test/dst_harness_probe.ail
~~~

The temporary probe was removed. Repeat the equivalent check against the real dst_harness before
deleting any local runner. Then run the IO-only gates with their original caps; the maximal type
must not introduce an unavailable runtime capability.

### Layout

Move exactly these ten Makefile-backed gate entrypoints to scripts/dst/:

~~~text
compaction_catalog_dst.ail
compaction_policy_dst.ail
conformance_registry_probe.ail
conformance_selftest.ail
long_qwen_compaction_dst.ail
phase_a_event_parity.sh
phase_c2_wiring_scenarios.ail
phase_c_approval_protocol.ail
phase_c_l1_scenarios.ail
runtime_status_tool_dst.ail
~~~

Update each moved AILANG module declaration if required by ailang check. Update Makefile paths
atomically with each move.

Keep scripts/smoke_v2_* and their fixtures flat and unchanged. Do not move or retire them.
Keep probes, spikes, long_qwen_catalog_fixture_probe.ail, and manual phase_b_projection_gate.sh
outside scripts/dst/. phase_a_event_parity.sh is the DST gate runner; it may move while retaining
its existing references to scripts/smoke_v2_* and scripts/setup_dp7_smoke_workdirs.sh. Make calls
it from the repository root, so do not accidentally change its relative-path behavior.

## ID contract

Apply the complete old-to-new map in the plan. The important groups are:

- phase_c.c2.* for all 18 Phase-C2 IDs.
- phase_c.l1.* for all 15 Phase-C L1 IDs.
- phase_c.approval.* for the seven approval case IDs.
- compaction.catalog_limit_qwen for the catalog probe.
- compaction.strict_provider_orphaned_toolcall for the one bare long-Qwen ID.
- Existing compaction.*, runtime_status.*, conformance.compactor.*, and harness.* IDs stay
  unchanged.

Do not rename package-owned conformance IDs. Do not omit the map entries that are already dotted:
they are part of the no-drop inventory.

Before and after ID edits, audit both output and consumers:

~~~bash
rg --hidden -n 'scenario=' --glob '!.git/**' --glob '!**/.ailang/**' --glob '!node_modules/**' .
rg --hidden -n --glob '!.git/**' --glob '!**/.ailang/**' --glob '!node_modules/**' \
  'scripts/(phase_a_event_parity|compaction_(catalog|policy)_dst|conformance_(selftest|registry_probe)|long_qwen_compaction_dst|phase_c2_wiring_scenarios|phase_c_approval_protocol|phase_c_l1_scenarios|runtime_status_tool_dst)\.(ail|sh)' .
~~~

Update executable/current operational consumers, especially Makefile, in the same move commit.
Classify historical ADRs, completed handoffs, generated diagrams, and superseded plans rather than
bulk-rewriting their historical paths. Track 3 owns the authoritative as-built documentation.

## Required commit sequence

Keep the migration reviewable and CI-safe. Harness first, then one script/helper per commit.
A moved file, module declaration, Makefile path, and its ID edits belong in one commit. Never leave
a Make target pointing at a missing path.

1. Add and check dst_harness.ail. No existing gate paths change.
2. Rename phase_f_pipeline_wiring.ail's local CheckResult run_all to run_checks. Preserve its
   two checks, output, and direct IO-only behavior.
3. Move/migrate compaction_policy_dst.ail; preserve --caps IO and count 3.
4. Move compaction_catalog_dst.ail; rename its output ID and preserve --caps IO,Env,FS.
5. Move/migrate runtime_status_tool_dst.ail; preserve two IDs, broad caps, --ai-stub, and
   /dev/null input.
6. Move/migrate long_qwen_compaction_dst.ail; preserve all seven dotted IDs, add the fixed seed
   metadata to all eight records, rename the one bare ID, fixture catalog, broad caps, stub, and
   /dev/null input.
7. Move/migrate phase_c_l1_scenarios.ail; add fixed seed to 15 records and preserve IO-only
   execution.
8. Move phase_c_approval_protocol.ail; prefix its seven case IDs and preserve all cases.
9. Move/migrate phase_c2_wiring_scenarios.ail; add fixed seed to 18 records and preserve its
   original caps/order/scripted provider behavior.
10. Move/adapt conformance_selftest.ail; keep package-owned Scenario/run_scenario and the 20-call
    accepted/rejected matrix. Only shared reporting may be reused.
11. Move conformance_registry_probe.ail; do not alter registry order or package calls.
12. Move phase_a_event_parity.sh; update only the Makefile runner path, not its subordinate smoke
    files or parity assertions.
13. Add .PHONY dst with one recursive Make invocation:

~~~make
.PHONY: dst
dst:
	+$(MAKE) --keep-going compaction_dst conformance phase_c_l1 smoke_parity dst_l2
~~~

Keep compaction_dst, conformance, and phase_c_l1 as stable component entrypoints. They must not
expand into the umbrella. Do not add verify_core, test_core, test_integration, live targets, or
manual probes to dst.

After each commit, wait for the Track 1 CI workflow or run the equivalent local blocking set.
A red result blocks the next migration commit; do not defer failures to the final commit.

## Verification checklist

Run from a hydrated checkout. Before gate verification, use the existing hydration contract:

~~~bash
make CI=1 sync_packages
~~~

This must complete package synchronization and root ailang lock before any gate command. Do not
replace it with direct script-path calls in CI; the workflow remains Make-target-only.

Per changed gate:

~~~bash
ailang check <moved-file>
git diff --check
~~~

At every migration commit:

~~~bash
make --keep-going compaction_dst conformance phase_c_l1
make smoke_parity
make dst_l2
~~~

For the phase_f helper commit also run:

~~~bash
ailang check scripts/phase_f_pipeline_wiring.ail
ailang run --caps IO --entry main scripts/phase_f_pipeline_wiring.ail
~~~

Final structural checks:

~~~bash
rg -n 'func run_all|type ScenarioFailure|type Scenario|println\("scenario=' scripts src/core/test packages/motoko_ext_conformance
rg -n '^func run_all' scripts
rg -n 'ScenarioFailure|Scenario|run_all|run_one|print_trace' scripts/dst
~~~

The second command must be empty. The only in-repo runner implementation must be
src/core/test/dst_harness.ail. Package harness run_all is expected outside scripts/. Moved scripts
may call shared helpers but may not define local Scenario/ScenarioFailure/runner copies.

Confirm output inventories:

- compaction policy 3, catalog 1, runtime 2, long-Qwen 8;
- Phase-C L1 15, approval 7, Phase-C2 18;
- conformance's four dotted IDs and registry probe;
- seven Layer-2 Bun tests.

Confirm:

~~~bash
make -n dst
make dst
git diff -- packages/motoko_ext_conformance
git diff -- 'scripts/smoke_v2_*.ail'
git diff --check
git status --short
~~~

make -n dst must show all five component gates and compaction only once through the dependency
graph. make dst must pass the complete deterministic set. The package and smoke diffs must be
empty for this track, apart from pre-existing changes that must be preserved rather than amended.

## Guardrails and stop conditions

Stop and report before continuing if:

- an operator rejects or changes the proposed scripts/dst layout, maximal-row harness, namespace
  map, or make dst chain;
- any scenario count, order, invariant, trace, threshold, policy, or provider wire shape changes;
- ailang check requires per-capability types after the real harness probe;
- package conformance source/version/ABI changes appear necessary;
- a moved gate fails because of a path/module/capability issue and the fix would alter scenario
  behavior;
- a required CI target becomes red;
- a smoke_v2_* file, live target, phase_b_projection_gate.sh, or Track 3 doc would need to change.

Rollback is per migration commit: restore the moved file, module declaration, Makefile path, and
ID edits together. Track 1 workflow changes are not part of this implementation and should not be
reverted.

## Completion handoff

Before declaring implementation complete:

1. Run the final full verification and record exact counts, final paths, and CI result.
2. Confirm no local runner definitions remain under scripts, including the phase_f helper collision.
3. Confirm no package or smoke_v2_* changes.
4. Write .agent/projects/007_dst_consolidation/HANDOFF-write-dst-as-built-doc.md for Track 3.
5. Include the final Make graph, scripts/dst listing, shared harness API, ID inventory, baseline
   comparison, conformance ABI boundary, and verification evidence in that Track 3 handoff.
