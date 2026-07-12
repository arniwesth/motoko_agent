# Plan: consolidate deterministic DST runners and gate layout

Date: 2026-07-12  
Status: proposed; implementation-ready after the operator signs off the marked choices  
Grounded source HEAD: 3ee3667 (Implemented Track 1)  
Review changes are plan-only.

This is Track 2 of the DST consolidation. Track 1 is already landed and must remain the guard
while this refactor is applied. Track 3 is deliberately not part of this plan; the session that
implements this plan must write HANDOFF-write-dst-as-built-doc.md for the as-built doc session.

## TL;DR

Add src/core/test/dst_harness.ail with the one maximal-effect Scenario and ScenarioFailure
records, the recursive runner, and the common failure reporter. Migrate the four full-row L1
runners plus the IO-only compaction-policy runner to it, and let the conformance selftest reuse
only the shared reporting adapter while retaining the package-owned conformance Scenario type and
run_scenario semantics.

The proposed operator choice is a visible scripts/dst/ directory for every Makefile-backed DST
gate entrypoint. The existing compaction_dst, conformance, phase_c_l1, smoke_parity, and dst_l2
targets remain stable; add make dst as an umbrella that invokes all five. Rename bare scenario IDs
to phase_c.c2.*, phase_c.l1.*, phase_c.approval.*, and compaction.*; already-dotted compaction.*,
runtime_status.*, conformance.*, and harness.* IDs stay unchanged.

No scenario body, invariant, threshold, policy, provider payload, extension behavior, conformance
kit source, or ABI-lockstep version changes are in scope.

## Scope and invariants

In scope:

- src/core/test/dst_harness.ail, beside stub_step.ail, scripted_ports.ail, and ext_fixture.ail.
- The four full-row scenario runners: phase_c2_wiring_scenarios.ail,
  long_qwen_compaction_dst.ail, runtime_status_tool_dst.ail, and phase_c_l1_scenarios.ail.
- The IO-only compaction_policy_dst.ail, because it contains the same runner machinery and is
  part of the compaction_dst gate.
- The gate-only entrypoints compaction_catalog_dst.ail, phase_c_approval_protocol.ail,
  conformance_selftest.ail, conformance_registry_probe.ail, and phase_a_event_parity.sh, for the
  scripts/dst/ layout.
- Makefile path updates and the new dst umbrella.
- Updating consumers of renamed output IDs found by the scenario= audit.

Out of scope:

- All scenario logic, invariant predicates, thresholds, policy tables, effectful production
  code, and wire payload construction.
- The smoke_v2_* retirement/subsumption audit. Existing smoke files remain where they are;
  phase_a_event_parity.sh remains a gate runner that consumes them.
- packages/motoko_ext_conformance/harness.ail, its fixtures/invariants, its ABI semantics, and
  version 4.0.0. The in-repo runner must not replace or merge with that package harness.
- Live calibration targets, probes, spikes, orphaned phase_b_projection_gate.sh, and non-gate
  smoke scripts, except that the parity gate runner itself is placed under scripts/dst/.
- Track 3 documentation. The implementation handoff must be written after the final consolidated
  state exists.

The allowed output changes are the explicitly approved scenario-ID normalization and the shared
failure line's fixed seed marker. Pass counts, scenario order, invariant names, traces, scripted
inputs, capability invocations, and provider wire observations must otherwise remain unchanged.
Existing fixed scenarios have no seed generator; every migrated scenario records seed=fixed, which
adds metadata without adding seeded behavior. Future generated scenarios must replace that marker
with their actual seed and remain deterministic.

## Decisions requiring operator sign-off

### 1. Layout: use scripts/dst/

Proposed choice: create scripts/dst/ and move only the Makefile-backed DST gate entrypoints there.
This makes the load-bearing set visible with ls scripts/dst; a filename suffix alone would still
leave gates mixed with probes and smokes in a single attic.

The resulting gate directory is:

~~~text
scripts/dst/
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

scripts/smoke_v2_*.ail and the smoke fixtures consumed by phase_a_event_parity.sh stay in the
existing flat location. They are dependencies of the parity gate, not independently classified
as DST gate entrypoints, and the operator-deferred retirement audit must not be smuggled into this
move. scripts/long_qwen_catalog_fixture_probe.ail, probe_*, spike_*, phase_b_projection_gate.sh,
and other non-Make probes remain outside scripts/dst/.

Each moved AILANG file gets the matching module scripts/dst/... declaration if required by
ailang check. The parity shell runner is still invoked from the repository root by Make, so its
existing scripts/smoke_v2_* and scripts/setup_dp7_smoke_workdirs.sh paths remain unchanged.

### 2. Harness shape: one maximal-effect Scenario type

Proposed choice: use one exported type in src/core/test/dst_harness.ail:

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

The module exports the shared print_trace, run_one, run_all, and pure ok_or_failure helpers.
run_all preserves the existing list order, recursion, failure accumulation, and lines:

~~~text
scenario=<id> ok
scenario=<id> seed=<seed> invariant=<failed_invariant>
trace <line>
~~~

The effect-row decision was probed at this HEAD rather than assumed. A temporary probe with both
an IO-only callback and a maximal-row callback passed:

~~~bash
ailang check src/core/test/dst_harness_probe.ail
ailang run --caps IO --entry main src/core/test/dst_harness_probe.ail
~~~

Both commands succeeded; the probe was deleted afterward. This establishes that the IO-only
compaction_policy_dst scenarios can inhabit the maximal record and execute under their existing
--caps IO invocation, while the full-row L1 scenarios use the same type. The implementation must
repeat the probe against the real dst_harness.ail before deleting any local runner and must run
each migrated gate with its original caps. A type annotation must not cause a new capability to be
requested at runtime.

The package-side conformance type cannot be unified with this record: its run field accepts an
ExtensionHooks argument and is part of the ABI-versioned package surface. conformance_selftest
therefore keeps importing pkg/sunholo/motoko_ext_conformance/harness (Scenario, run_scenario, ...)
and only imports the new harness's failure-reporting adapter. It constructs no replacement
package scenarios and makes no package source or version change.

### 3. Scenario ID namespace: dotted, layer-prefixed

Proposed final namespace, subject to operator sign-off:

- compaction.* for compaction policy, catalog, long-Qwen, and structural compaction gates.
- phase_c.l1.* for Phase C L1 scenarios.
- phase_c.c2.* for Phase C2 wiring scenarios.
- phase_c.approval.* for approval protocol case IDs, which are CaseResult IDs rather than
  Scenario records but already appear in failure output as scenario=....
- runtime_status.* for runtime-status scenarios (already compliant).
- conformance.compactor.* for package-owned conformance scenarios (already compliant).
- harness.* for the Layer-2 Bun test descriptions (already compliant).

The catalog probe, approval cases, and package registry probe are not in-repo Scenario records;
their existing direct/CaseResult/package reporters therefore do not gain the shared seed field.
They retain their current failure envelope while receiving the dotted IDs mapped below. The
shared id/seed/trace contract applies to the extracted in-repo Scenario runner and the selftest
adapter, without changing the ABI-versioned package reporter.

The full rename map is below. No scenario may be omitted from a migration commit; the old and new
lists are review manifests as well as documentation.

#### phase_c2_wiring_scenarios.ail — baseline 18

| Current ID | Final ID |
|---|---|
| decision_record_append_name_round_trip | phase_c.c2.decision_record_append_name_round_trip |
| traced_prose_decisions | phase_c.c2.traced_prose_decisions |
| traced_tool_decisions | phase_c.c2.traced_tool_decisions |
| tool_call_with_stop_finish_still_runs | phase_c.c2.tool_call_with_stop_finish_still_runs |
| traced_persist_nudge_decisions | phase_c.c2.traced_persist_nudge_decisions |
| traced_approval_default_deny | phase_c.c2.traced_approval_default_deny |
| traced_stage_records | phase_c.c2.traced_stage_records |
| compactor_chain_order_is_registry_order | phase_c.c2.compactor_chain_order_is_registry_order |
| empty_stop_guard_loops_within_budget | phase_c.c2.empty_stop_guard_loops_within_budget |
| empty_stop_guard_budget_exhaustion_floors | phase_c.c2.empty_stop_guard_budget_exhaustion_floors |
| empty_stop_floor_without_guard | phase_c.c2.empty_stop_floor_without_guard |
| progress_contract_catches_failure_shape | phase_c.c2.progress_contract_catches_failure_shape |
| progress_contract_budget_exhaustion_finalizes | phase_c.c2.progress_contract_budget_exhaustion_finalizes |
| progress_contract_ignores_blank | phase_c.c2.progress_contract_ignores_blank |
| progress_contract_combined_chain_blank_owned_by_empty_stop | phase_c.c2.progress_contract_combined_chain_blank_owned_by_empty_stop |
| progress_contract_completion_passes | phase_c.c2.progress_contract_completion_passes |
| progress_contract_allowed_compaction_passes | phase_c.c2.progress_contract_allowed_compaction_passes |
| progress_contract_no_contract_passes | phase_c.c2.progress_contract_no_contract_passes |

#### phase_c_l1_scenarios.ail — baseline 15

| Current ID | Final ID |
|---|---|
| harness_self_test | phase_c.l1.harness_self_test |
| segment_excludes_system_prefix | phase_c.l1.segment_excludes_system_prefix |
| project_prep_vs_uncompacted_history_pressure | phase_c.l1.project_prep_vs_uncompacted_history_pressure |
| empty_system_prompt_rejected | phase_c.l1.empty_system_prompt_rejected |
| oversized_payload_rejected | phase_c.l1.oversized_payload_rejected |
| ext_compaction_invalid_rejected | phase_c.l1.ext_compaction_invalid_rejected |
| summary_cache_replay_stable | phase_c.l1.summary_cache_replay_stable |
| history_rewrite_requires_checkpoint_event | phase_c.l1.history_rewrite_requires_checkpoint_event |
| checkpoint_never_emitted_when_policy_off | phase_c.l1.checkpoint_never_emitted_when_policy_off |
| checkpoint_emitted_under_pressure | phase_c.l1.checkpoint_emitted_under_pressure |
| checkpoint_terminates_not_spins | phase_c.l1.checkpoint_terminates_not_spins |
| checkpoint_output_is_valid_transcript | phase_c.l1.checkpoint_output_is_valid_transcript |
| compactor_chain_order_is_registry_order | phase_c.l1.compactor_chain_order_is_registry_order |
| invalid_stage_skipped_chain_continues | phase_c.l1.invalid_stage_skipped_chain_continues |
| actual_token_pressure_defers_to_seal | phase_c.l1.actual_token_pressure_defers_to_seal |

#### Compaction and approval gates

| File | Current ID | Final ID |
|---|---|---|
| compaction_policy_dst.ail | compaction.estimate_tier_ladder | unchanged |
| compaction_policy_dst.ail | compaction.tool_shape_preserved_by_elision | unchanged |
| compaction_policy_dst.ail | compaction.emergency_recovery_or_defer | unchanged |
| compaction_catalog_dst.ail | catalog_limit_qwen | compaction.catalog_limit_qwen |
| runtime_status_tool_dst.ail | runtime_status.basic | unchanged |
| runtime_status_tool_dst.ail | runtime_status.mixed_pending | unchanged |
| long_qwen_compaction_dst.ail | compaction.long_qwen_ai_multiple_compactions | unchanged |
| long_qwen_compaction_dst.ail | compaction.long_qwen_ai_replay_deterministic | unchanged |
| long_qwen_compaction_dst.ail | compaction.compaction_ai_output_shape_valid | unchanged |
| long_qwen_compaction_dst.ail | compaction.compaction_ai_artifact_cache_stable | unchanged |
| long_qwen_compaction_dst.ail | compaction.compaction_ai_hostile_summary_control_capsule | unchanged |
| long_qwen_compaction_dst.ail | compaction.compaction_ai_terminal_observations | unchanged |
| long_qwen_compaction_dst.ail | compaction.structural_seal_side_exhaustion | unchanged |
| long_qwen_compaction_dst.ail | strict_provider_orphaned_toolcall | compaction.strict_provider_orphaned_toolcall |
| phase_c_approval_protocol.ail | approve | phase_c.approval.approve |
| phase_c_approval_protocol.ail | deny_with_reason | phase_c.approval.deny_with_reason |
| phase_c_approval_protocol.ail | deny_default_reason | phase_c.approval.deny_default_reason |
| phase_c_approval_protocol.ail | eof_default_allow | phase_c.approval.eof_default_allow |
| phase_c_approval_protocol.ail | eof_default_deny | phase_c.approval.eof_default_deny |
| phase_c_approval_protocol.ail | unparseable_default_deny | phase_c.approval.unparseable_default_deny |
| phase_c_approval_protocol.ail | unknown_default_deny | phase_c.approval.unknown_default_deny |

#### Conformance and Layer 2 (already compliant)

The package-owned conformance scenario inventory remains exactly:

- conformance.compactor.system_prefix_preserved
- conformance.compactor.tool_pairing_preserved
- conformance.compactor.deterministic_replay
- conformance.compactor.artifact_cache_effective

The Layer-2 Bun descriptions remain exactly:

- harness.child_env_sandbox_and_prompt_by_reference
- harness.external_system_md_materialized
- harness.workspace_system_md_not_rewritten
- harness.out_of_sandbox_or_missing_system_md_yields_empty

The long_qwen_catalog_fixture_probe already reports compaction.long_qwen_catalog_fixture and is
a probe, not a Makefile gate; it is not moved.

Before changing any ID, run this audit over tracked source and documentation:

~~~bash
rg -n 'scenario=' --glob '!**/.ailang/**' --glob '!node_modules/**' .
~~~

Update only real consumers of the old IDs. At this HEAD there are no CI greps or docs parsers
that consume the bare IDs; the output sites are the gate scripts and the package harness, whose
four IDs are already dotted. The implementation must repeat the audit after every rename and must
not mistake the old-to-new table in this plan for a live consumer.

## Re-established baseline

The baseline was run at 3ee3667 after Track 1 hydration and before this plan changes any source.
The direct runner counts are the migration oracle:

| Gate or runner | Baseline checks |
|---|---:|
| compaction_policy_dst | 3 scenarios |
| compaction_catalog_dst | 1 catalog scenario probe |
| runtime_status_tool_dst | 2 scenarios |
| long_qwen_compaction_dst | 8 scenarios |
| compaction_dst aggregate | 14 checks (3 + 1 + 2 + 8) |
| phase_c_l1_scenarios | 15 scenarios |
| phase_c_approval_protocol | 7 approval cases |
| phase_c2_wiring_scenarios | 18 scenarios |
| conformance_selftest | 4 canonical scenarios exercised across 5 hook cases (20 invocations; 3 expected-reject fixtures plus 2 accepted implementations) |
| conformance_registry_probe | the same 4 canonical scenarios against 13 registry hooks (52 invocations) plus registry-order construction |
| Layer-2 dst_l2 | 7 Bun tests at the Track 1 baseline |

phase_c_l1 depends on compaction_dst, so the Make dependency graph runs those 14 compaction checks
once, then its 15 Phase-C L1 scenarios, 7 approval cases, and 18 Phase-C2 scenarios.
make conformance also checks/tests the package and therefore has more output than the four
scenario IDs; the package's 4.0.0 version and ABI behavior are not migration variables.

Track 1's current CI contract is target-based and must remain so:

- verify_extensions runs make CI=1 sync_packages, make check_core,
  make smoke_no_delegated_storm, make --keep-going compaction_dst conformance phase_c_l1,
  make smoke_parity, and advisory make verify_core.
- The sibling dst_l2 job runs make dst_l2 after the pinned Bun setup.
- The workflow contains no direct gate script invocation; Track 2 must preserve that property.

## Shared harness implementation

Add src/core/test/dst_harness.ail first. Copy the currently identical machinery from
phase_c2_wiring_scenarios.ail:60-106 and long_qwen_compaction_dst.ail:66-105 into the module,
then generalize only the exported names and imports needed by the other scripts. The runtime
status, Phase-C L1, and compaction-policy variants must converge on the same implementation, not
retain private aliases.

The shared module must:

1. Define and export exactly one in-repo ScenarioFailure shape and one maximal-row Scenario shape;
   require a seed field so the failure report realizes ADR-001's id/seed/trace contract.
2. Preserve recursive order and the integer failure count in run_all.
3. Preserve scenario=<id> ok, and report failures as scenario=<id> seed=<seed>
   invariant=<...> followed by trace <...> lines. Existing fixed scenarios use seed=fixed; the
   renamed ID and this required seed field are the only intended gate-output identity changes.
4. Export the failure constructor helper used by existing scenario bodies so invariant wording and
   trace contents remain local and unchanged.
5. Provide a small reporting adapter that accepts a copied {failed_invariant, trace} from the
   package-side conformance selftest, supplies seed=fixed, and never accepts or re-defines the
   package Scenario.
6. Avoid any production imports or changes to stub_step, scripted_ports, or ext_fixture.

After adding it, run ailang check on the harness and the real effect-row probe. The first commit
must contain no script migration, so Track 1 remains green and the new module is proven
independently before it becomes load-bearing.

## Migration and layout sequence

Every step below is a separate commit after the harness commit. A move, module declaration
change, Makefile path update, and that file's ID edits belong in the same commit so no CI target
ever points at a missing path. Do not batch two scenario scripts into one commit. After each
commit, wait for the Track 1 workflow to pass; locally run the changed gate with the original caps
and compare its count to the baseline table.

1. Harness foundation. Add src/core/test/dst_harness.ail, run its check and the effect-row probe.
   No existing gate path changes.
2. Compaction policy runner. Move scripts/compaction_policy_dst.ail to scripts/dst/, import the
   shared types/runner/helper, remove its private Scenario, ScenarioFailure, print_trace, run_one,
   and run_all, add seed: "fixed" to each of its three records, and update the three IDs only if
   the final map says so (they are already dotted). Update the compaction_dst command and module
   declaration. Preserve --caps IO.
3. Compaction catalog gate. Move compaction_catalog_dst.ail, update its module and Make path,
   rename the one reported ID to compaction.catalog_limit_qwen, and preserve --caps IO,Env,FS and
   its direct check.
4. Runtime-status runner. Move runtime_status_tool_dst.ail, remove its private runner block,
   import the shared maximal-row harness, add seed: "fixed" to both records, preserve its two
   already-dotted IDs, and retain the broad caps, --ai-stub, and /dev/null input.
5. Long-Qwen runner. Move long_qwen_compaction_dst.ail, remove its private runner block, import
   the shared harness, add seed: "fixed" to all eight records, prefix only
   strict_provider_orphaned_toolcall, and preserve the fixture catalog environment, broad caps,
   --ai-stub, input redirection, scenario order, and all six existing dotted IDs.
6. Phase-C L1 runner. Move phase_c_l1_scenarios.ail, remove its exported local types and runner,
   import the shared harness, add seed: "fixed" to all 15 records, and apply all 15 phase_c.l1.*
   IDs. Preserve the IO-only Make invocation and the pure scenario bodies.
7. Approval protocol gate. Move phase_c_approval_protocol.ail, update its module and Make path,
   prefix all seven case IDs in its failure-report strings, and preserve the seven-case order and
   --caps IO invocation. This is a case-runner migration, not a new Scenario type.
8. Phase-C2 runner. Move phase_c2_wiring_scenarios.ail, remove its duplicated runner, import the
   shared harness, add seed: "fixed" to all 18 records, and apply all 18 phase_c.c2.* IDs.
   Preserve its original caps (IO,Env,Clock,FS,Trace in Make), scripted provider setup, effectful
   scenario bodies, and order.
9. Conformance selftest adapter. Move conformance_selftest.ail and update its Make path. Keep the
   package Scenario, ScenarioFailure, run_scenario, four constructors, hook fixtures,
   expected-failure matrix, and ABI version untouched. Import only the shared failure reporter/
   adapter; it reports seed=fixed for in-repo selftest failures and preserves the existing
   labels and 20 invocations. Its package scenario IDs are already dotted and must not be renamed.
10. Conformance registry probe. Move conformance_registry_probe.ail and update its Make path/module.
    Do not alter registry order, package calls, or package scenario IDs. This is a gate-entrypoint
    move, not a conformance-kit consolidation.
11. Parity gate runner. Move phase_a_event_parity.sh to scripts/dst/ and update only the
    smoke_parity Make recipe's runner path. Keep every subordinate scripts/smoke_v2_* path,
    fixture, assertion, deterministic stub, capture normalization, and two-capture diff
    unchanged. This step must not reopen the deferred smoke audit.
12. Umbrella target. Add make dst after all gate paths work. It must invoke the complete Track 1
    deterministic set in one recursive Make call so compaction_dst is de-duplicated through
    phase_c_l1:

~~~make
.PHONY: dst
dst:
        +$(MAKE) --keep-going compaction_dst conformance phase_c_l1 smoke_parity dst_l2
~~~

Keep compaction_dst, conformance, and phase_c_l1 as stable component targets/compatibility
entrypoints. Do not make them aliases that expand into the umbrella; existing CI and operator
muscle memory must continue to run the same component scope. Do not include advisory verify_core,
test_core, test_integration, live calibration, or manual probes in dst.

The implementation may split the last two mechanical moves into additional one-file commits if
the working tree or CI requires it, but no commit may leave a tracked Make target pointing at a
nonexistent path. A failed CI result blocks the next migration commit; it is not waived because
the final tree is expected to be green.

## Makefile and CI contract after migration

The final Makefile must retain the existing caps and command semantics, changing only paths and
adding the umbrella:

- compaction_dst: policy (IO), catalog (IO/Env/FS), runtime-status (full caps + stub), and
  long-Qwen (same fixture catalog, full caps + stub).
- phase_c_l1: its existing dependency on compaction_dst, then L1, approval, and C2 gate
  entrypoints with their existing caps.
- conformance: package checks/tests plus the moved selftest and moved registry probe.
- smoke_parity: the moved parity runner, same capture/diff contract.
- dst_l2: unchanged explicit Bun-native test target from Track 1.
- dst: all five of the above gate targets, with no advisory or live target.

The workflow must remain unchanged by this track except insofar as it consumes the stable Make
targets. In particular, do not put scripts/dst/... paths in
.github/workflows/verify-extensions.yml. Track 1 CI is protected by target names, not paths.

## Verification plan

Run from a hydrated checkout. The implementation should capture concise logs rather than retain
the large runtime-status and long-Qwen JSON streams in review output.

### Per-commit checks

For the changed gate, run the exact original command/caps from Make, then verify:

~~~bash
ailang check <moved-file>
git diff --check
rg -n 'scripts/(dst/)?(compaction|conformance|long_qwen|phase_c|runtime_status|phase_a)' Makefile
~~~

At every commit, run the Track 1 blocking command set (after hydration) or wait for the equivalent
workflow result:

~~~bash
make --keep-going compaction_dst conformance phase_c_l1
make smoke_parity
make dst_l2
~~~

The unchanged baselines must remain visible in output or a captured log: 14 aggregate compaction
checks, 15 Phase-C L1 scenarios, 7 approval cases, 18 Phase-C2 scenarios, four conformance IDs,
the registry probe, and seven Layer-2 tests. No missing scenario may be hidden by a successful
process exit.

### Structural de-duplication checks

After the final runner migration:

~~~bash
rg -n 'func run_all|type ScenarioFailure|type Scenario|println\("scenario=' scripts src/core/test packages/motoko_ext_conformance
rg -n 'func run_all' scripts
rg -n 'ScenarioFailure|Scenario|run_all|run_one|print_trace' scripts/dst
~~~

The second command must find no run_all in scripts/; the only in-repo implementation is in
src/core/test/dst_harness.ail. The package harness's own run_all is expected outside scripts/ and
is not a violation. The moved scripts may import and call the shared functions, but must not
define shadow copies of the records or runner.

### ID and output checks

1. Extract every scenario=<id> line from each gate log and compare it against the full map in
   this plan, preserving scenario order and count.
2. Confirm no bare migrated IDs remain in gate source, Makefile assertions, CI scripts, or docs;
   allow the old strings only in this historical mapping and review evidence.
3. Confirm the four package conformance IDs and four Layer-2 harness.* descriptions are unchanged.
4. Confirm failure output still includes the ID, seed=fixed, failed invariant, and every trace line. Use a
   targeted temporary failure only if needed; do not commit a new failing scenario or alter a
   production invariant to exercise the reporter.
5. Confirm make -n dst shows all five component targets and that the compaction commands occur
   once through the Make dependency graph.

### Scope and ABI checks

~~~bash
git diff -- packages/motoko_ext_conformance
git diff -- 'scripts/smoke_v2_*.ail'
rg -n 'smoke_v2_|live_|phase_b_projection_gate|verify_core|test_core|test_integration' Makefile .github/workflows/verify-extensions.yml
~~~

The first two diffs must be empty for Track 2 (apart from pre-existing Track 1 state, which must
not be amended). The final audit must show no new live, smoke-retirement, orphaned-probe, or
advisory target in make dst.

Finally run:

~~~bash
make dst
git diff --check
git status --short
~~~

make dst must pass the complete deterministic set, and the implementation handoff must record the
final paths, counts, ID inventory, and any exact Track 1 CI run evidence.

## Acceptance mapping

- Same scenario inventory: the baseline table plus the full rename manifest makes a dropped
  scenario review-visible; post-migration counts must be 3, 1, 2, 8, 15, 7, 18, four package
  scenarios, and seven Bun tests as recorded.
- One runner: duplicated Scenario, ScenarioFailure, run_one, run_all, and trace-reporting blocks
  are deleted from scripts; rg 'func run_all' scripts is empty.
- CI safety: Track 1's target-only workflow stays green after every one-file migration commit; no
  workflow path coupling is introduced.
- Complete umbrella: make dst runs compaction_dst, conformance, phase_c_l1, smoke_parity, and
  dst_l2, with compaction executed once.
- Namespace contract: all newly emitted gate IDs are dotted and layer-prefixed; existing dotted
  package/runtime/harness IDs remain stable; consumers are found by the scenario= audit.
- ABI safety: no file under packages/motoko_ext_conformance changes, its 4.0.0 lockstep version
  remains unchanged, and the selftest still exercises the package's own Scenario and run_scenario.
- Scope safety: no smoke retirement, threshold/policy edit, new scenario, invariant change, live
  provider, or Track 3 documentation is introduced.

## Rollback and Track 3 handoff

Each migration commit is independently revertible: restore the moved file, its module declaration,
its Make path, and its ID strings as one commit. The harness-first sequence means a rollback does
not require reverting Track 1 CI. The umbrella can be reverted separately if its local dependency
surface proves unsuitable; the existing component targets remain the operational fallback.

After the final green implementation commit, write
.agent/projects/007_dst_consolidation/HANDOFF-write-dst-as-built-doc.md. It must point the Track 3
author at the actual scripts/dst/ inventory, final Make graph, final IDs/counts, shared-harness API,
conformance ABI boundary, and the successful verification evidence. Do not write that handoff from
this plan-only session as if the end state already exists.
