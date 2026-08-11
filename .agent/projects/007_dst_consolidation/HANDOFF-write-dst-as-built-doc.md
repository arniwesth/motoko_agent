# Handoff: write the DST as-built framework document

Date: 2026-07-12
Track: 3 after Track 2 DST code consolidation
Implementation HEAD: `970def4` (`Avoid core/package compaction config name collision`)
Source baseline: `3ee3667` (Track 1 implemented)

## Actual consolidated end state

Track 2 is implemented and verified. The in-repo deterministic scenario runner is consolidated
in `src/core/test/dst_harness.ail`. The ten Makefile-backed DST entrypoints are under
`scripts/dst/`; `scripts/smoke_v2_*` files and fixtures remain flat and unchanged. The GitHub
workflow remains target-only and has no `scripts/dst/...` path coupling.

The implementation commits, in order, are:

1. `2873f71` — add the shared DST scenario harness.
2. `3cff5f3` — rename the Phase-F `CheckResult` aggregator to `run_checks`.
3. `ab0fd50` — move and consolidate `compaction_policy_dst`.
4. `e2f5d3c` — move `compaction_catalog_dst` and rename its output ID.
5. `a6e4c8e` — move and consolidate `runtime_status_tool_dst`.
6. `0c2098c` — move and consolidate `long_qwen_compaction_dst`.
7. `f9a5604` — move and consolidate `phase_c_l1_scenarios`.
8. `21569e5` — move and namespace the approval protocol cases.
9. `84d6283` — move and consolidate `phase_c2_wiring_scenarios`.
10. `9c7cae1` — move `conformance_selftest`.
11. `c5f34c6` — move `conformance_registry_probe`.
12. `3818664` — move `phase_a_event_parity.sh` and update only its Make runner path.
13. `72d1dcb` — add the `dst` umbrella target.
14. `617faae` — normalize two accidental recipe-indentation changes.
15. `d67545e` — refresh the root AILANG lock for the new core test module.
16. `67bc9e5` — refresh moved-file header comments to their final paths.
17. `970def4` — rename the core-local `CompactionAiConfig` to
    `CoreCompactionAiConfig` so clean-cache extension boot checks cannot collide with the
    package's distinct eight-field `CompactionAiConfig`.

## Shared harness API

`src/core/test/dst_harness.ail` exports exactly these in-repo scenario records:

```ailang
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
```

It exports `print_trace`, `run_one`, `run_all`, `failure`, `ok_or_failure`, and
`report_failure`. `run_all` retains recursive ordering and failure accumulation. Successful
records print `scenario=<id> ok`; failures print
`scenario=<id> seed=<seed> invariant=<failed_invariant>` followed by `trace <line>`.
All migrated fixed scenarios use `seed="fixed"`.

The real harness and an IO-only/maximal-row probe both type-checked, and the probe ran with only
`--caps IO`. The migrated IO-only gates therefore retain their original IO-only commands while
sharing the maximal effect-row type.

The package conformance selftest still imports and uses the package-owned `Scenario`,
`ScenarioFailure`, `run_scenario`, constructors, fixtures, and reporter. A shared failure
reporting adapter was tested but not retained: this AILANG version resolves the shared exported
`Scenario` name transitively alongside the ABI package's distinct `Scenario`, producing a package
constructor type collision. Keeping the package reporter avoids any package source, ABI, or
behavior change. The package harness remains the only `run_all` outside the in-repo harness.

## Final `scripts/dst/` inventory

```text
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
```

The following remain outside `scripts/dst/` as required: `scripts/smoke_v2_*`, their fixtures,
`scripts/long_qwen_catalog_fixture_probe.ail`, probes and spikes, and the manual
`scripts/phase_b_projection_gate.sh`.

## Final Make graph

The stable component targets remain:

```text
compaction_dst
  compaction_policy_dst       --caps IO
  compaction_catalog_dst      --caps IO,Env,FS
  runtime_status_tool_dst     broad caps, --ai-stub, stdin=/dev/null
  long_qwen_compaction_dst    qwen fixture catalog, broad caps, --ai-stub, stdin=/dev/null

conformance
  package invariant check
  package harness check
  conformance_selftest check/run
  conformance_registry_probe check/run
  package invariant tests

phase_c_l1: compaction_dst
  phase_c_l1_scenarios         --caps IO
  phase_c_approval_protocol    --caps IO
  phase_c2_wiring_scenarios    --caps IO,Env,Clock,FS,Trace

smoke_parity
  scripts/dst/phase_a_event_parity.sh

dst_l2
  cd src/tui && bun test src/harness-dst.test.ts

dst
  +$(MAKE) --keep-going compaction_dst conformance phase_c_l1 smoke_parity dst_l2
```

`phase_c_l1` still depends on `compaction_dst`, so `make -n dst` shows the four compaction
commands once through the dependency graph, followed by the remaining component targets.
`verify_core`, core/integration test targets, live calibration, probes, and manual gates are not
part of `dst`.

## Scenario ID inventory and counts

The final deterministic inventory is:

| Gate | Count | Final IDs / namespace |
|---|---:|---|
| `compaction_policy_dst` | 3 | `compaction.estimate_tier_ladder`, `compaction.tool_shape_preserved_by_elision`, `compaction.emergency_recovery_or_defer` |
| `compaction_catalog_dst` | 1 | `compaction.catalog_limit_qwen` |
| `runtime_status_tool_dst` | 2 | `runtime_status.basic`, `runtime_status.mixed_pending` |
| `long_qwen_compaction_dst` | 8 | seven existing `compaction.*` IDs plus `compaction.strict_provider_orphaned_toolcall` |
| `compaction_dst` | 14 | the four compaction rows above, aggregate |
| `phase_c_l1_scenarios` | 15 | all `phase_c.l1.*` |
| `phase_c_approval_protocol` | 7 | all `phase_c.approval.*` case IDs |
| `phase_c2_wiring_scenarios` | 18 | all `phase_c.c2.*` |

The complete Phase-C L1 suffixes are `harness_self_test`, `segment_excludes_system_prefix`,
`project_prep_vs_uncompacted_history_pressure`, `empty_system_prompt_rejected`,
`oversized_payload_rejected`, `ext_compaction_invalid_rejected`, `summary_cache_replay_stable`,
`history_rewrite_requires_checkpoint_event`, `checkpoint_never_emitted_when_policy_off`,
`checkpoint_emitted_under_pressure`, `checkpoint_terminates_not_spins`,
`checkpoint_output_is_valid_transcript`, `compactor_chain_order_is_registry_order`,
`invalid_stage_skipped_chain_continues`, and `actual_token_pressure_defers_to_seal`.

The complete Phase-C2 suffixes are `decision_record_append_name_round_trip`,
`traced_prose_decisions`, `traced_tool_decisions`, `tool_call_with_stop_finish_still_runs`,
`traced_persist_nudge_decisions`, `traced_approval_default_deny`, `traced_stage_records`,
`compactor_chain_order_is_registry_order`, `empty_stop_guard_loops_within_budget`,
`empty_stop_guard_budget_exhaustion_floors`, `empty_stop_floor_without_guard`,
`progress_contract_catches_failure_shape`, `progress_contract_budget_exhaustion_finalizes`,
`progress_contract_ignores_blank`,
`progress_contract_combined_chain_blank_owned_by_empty_stop`,
`progress_contract_completion_passes`, `progress_contract_allowed_compaction_passes`, and
`progress_contract_no_contract_passes`.

Package conformance IDs remain exactly:

- `conformance.compactor.system_prefix_preserved`
- `conformance.compactor.tool_pairing_preserved`
- `conformance.compactor.deterministic_replay`
- `conformance.compactor.artifact_cache_effective`

The selftest exercises those four scenarios across five hook cases: 20 invocations total. The
registry probe exercises the same four scenarios across 13 hooks: 52 invocations total. Layer 2
remains seven Bun tests with the existing `harness.*` descriptions.

## Baseline comparison

No scenario body, invariant wording, trace logic, threshold, policy, scripted provider payload,
wire shape, fixture behavior, or provider behavior changed. Compared with the Track 1 baseline:

```text
compaction_policy_dst       3  -> 3
compaction_catalog_dst      1  -> 1
runtime_status_tool_dst     2  -> 2
long_qwen_compaction_dst    8  -> 8
compaction_dst             14  -> 14
phase_c_l1_scenarios        15  -> 15
phase_c_approval_protocol   7  -> 7
phase_c2_wiring_scenarios  18  -> 18
conformance selftest       20  -> 20 package calls
conformance registry       52  -> 52 package calls
dst_l2                      7  -> 7 Bun tests
```

The only intended scenario output identity changes are dotted namespace IDs and `seed=fixed` on
shared in-repo runner failures. The catalog and approval reporters remain their direct probe/case
shapes. Package conformance IDs and reporting remain package-owned.

## ABI and scope boundary

`packages/motoko_ext_conformance` has no Track 2 source diff. Its package version remains 4.0.0,
its conformance ABI remains 4.0, and its `Scenario.run` signature still accepts `ExtensionHooks`.
The smoke_v2 sources and fixtures also have no Track 2 diff. The only root generated artifact
updated is `ailang.lock`, whose `motoko_core` content hash now includes the new shared test module
and the core config type-name fix.

The Track 1 workflow remains target-only and unchanged from `3ee3667`; no `scripts/dst/...` path
was added to GitHub Actions. Historical ADRs, handoffs, generated diagrams, and superseded plans
still contain their original paths and are intentionally not bulk-rewritten. Current Make,
workflow, and `scripts/` operational path audits contain only final paths.

## Verification evidence

Hydration completed successfully with:

```bash
make CI=1 sync_packages
```

The final `make dst` at `970def4` passed all component targets. Its summary was:

```text
compaction_policy_dst PASS count=3
runtime_status_tool_dst PASS count=2
long_qwen_compaction_dst PASS count=8
conformance package tests: 6 passed, 0 failed
conformance self-test PASS
conformance registry probe PASS
phase_c_l1_scenarios PASS count=15
phase_c_approval_protocol PASS count=7
phase_c2_wiring_scenarios PASS count=18
Layer-2 Bun: 7 pass, 0 fail
```

The final structural checks passed:

```text
rg '^func run_all' scripts                 # empty
only src/core/test/dst_harness.ail defines the in-repo runner
all scripts/dst/*.ail ailang-check         # passed
old executable moved paths under Make/.github/scripts  # empty
git diff -- packages/motoko_ext_conformance # empty
git diff -- 'scripts/smoke_v2_*.ail'       # empty
git diff --check                            # passed
```

No remote GitHub Actions run was observed in this implementation session. The operator-confirmed
Track 1 blocking set was run locally after every migration commit and is green at the final HEAD:
`make --keep-going compaction_dst conformance phase_c_l1`, `make smoke_parity`, and `make dst_l2`.
The CI failure mode was reproduced with `AILANG_NO_CACHE=1 make check_core`; after the type-name
fix it passed with 7 extension boots and 34 core modules checked.
