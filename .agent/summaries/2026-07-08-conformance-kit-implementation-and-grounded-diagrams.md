# 2026-07-08 — Conformance kit implementation and grounded diagrams

## Context

This session implemented Plan 1 from
`.agent/projects/004_phase_core_refactor/PLAN-conformance-kit.md`: the
`motoko_ext_conformance` package, extracted compactor-output law, root conformance scripts, registry
probe, `make conformance` gate, and ADR amendment. It then refreshed the code graph and added an
implemented end-state diagram plus a meta-decision about comparing planned end-state diagrams to
actual grounded diagrams.

## Baseline and grounding

Before editing, the session:

- read the plan, ADR, handoff, scope note, false-alarm note, and re-grounding discipline;
- confirmed the toolchain: `AILANG v0.26.0`, commit `3b52a24`;
- verified commits after the plan were doc/diagram/handoff-only for the load-bearing source files;
- ran the requested green baseline:
  - `ailang check src/core/ext/runtime.ail`
  - `ailang check src/core/phase_vocab.ail`
  - `ailang test src/core/phase_vocab.ail`
  - `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail`
  - `make check_core`

The required AILANG workspace-resolution spike was performed with throwaway files. It confirmed:

- core can import `pkg/sunholo/motoko_ext_conformance/invariants` once the root path dependency is
  locked;
- root scripts can import exported package modules and compactor registers;
- the conformance package remains absent from `src/core/ext/registry_generated.ail`.

The spike also showed that `ailang lock` is required before new root path-dep package imports resolve.

## Implemented code

Added `packages/motoko_ext_conformance/`:

- `ailang.toml`
  - package `sunholo/motoko_ext_conformance`, version `3.0.0`;
  - depends only on `sunholo/motoko_ext_abi`;
  - exports `invariants`, `harness`, and `fixtures/reject_fixtures`;
  - not added to root `[extensions]`.
- `invariants.ail`
  - ABI-typed pure law over `pkg/sunholo/motoko_ext_abi/types.Msg`;
  - exports `no_system_in_output`, `pairing_preserved`, `ids_preserved`,
    `validate_compactor_output`, and `conformance_abi_version`;
  - preserves the core wrapper's id-aware recursion and exact error strings/order;
  - includes tests ported from `phase_vocab`, per-predicate checks, wrapper/predicate equivalence,
    and the required dropped-complete-pair accepted case.
- `harness.ail`
  - main-less library;
  - imports only ABI + `invariants`;
  - local ctx defaults, fake canned/poison ports, `same_msgs`, engineered compaction segment;
  - exports four scenarios, `run_scenario`, `run_conformance`, and `compaction_occurred`.
- `fixtures/reject_fixtures.ail`
  - exports `reject_prefix_hooks`, `reject_pair_hooks`, `reject_nocache_hooks`;
  - each fixture is ABI-3.0 and targets exactly one intended scenario/invariant class.

Moved the compactor-output validator cluster out of `src/core/phase_vocab.ail` and imported the law
back into:

- `src/core/ext/runtime.ail`
- `scripts/phase_c_l1_scenarios.ail`

Added root scripts:

- `scripts/conformance_selftest.ail`
  - imports harness, reject fixtures, `compaction_ai/register`, and `compaction_structural/register`;
  - asserts fail-then-pass by invariant name;
  - includes liveness guard that accept compactors return `Compacted`, not `PassThrough`;
  - prints `conformance self-test PASS`.
- `scripts/conformance_registry_probe.ail`
  - imports `parse_core_ext_order`, not unexported `resolve`;
  - uses the generated short-name CSV;
  - folds `run_conformance` over full registry hooks.

Updated root files:

- `ailang.toml`: added path dependency
  `"sunholo/motoko_ext_conformance" = { path = "packages/motoko_ext_conformance" }`.
- `ailang.lock`: refreshed with `sunholo/motoko_ext_conformance@3.0.0`.
- `Makefile`: added distinct `make conformance` registry/conformance gate.
- `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md`: applied the §6/§6.1
  amendment:
  - actual four-field `ExtPorts`;
  - law canonical home in `invariants.ail`;
  - three compactor-output predicates and deferred `envelope_well_formed`;
  - harness is a main-less library;
  - self-test is the root script;
  - ABI-version guard is compile-time structural plus declared constant.

## Important implementation notes

- The named predicate `pairing_preserved` must keep `all_output` separate from the recursion tail,
  just like the original wrapper. An early version recursed over the remaining tail as the output set,
  causing identity output to fail the predicate. Fixed by adding `pairing_preserved_rec(input,
  all_output, remaining)`.
- Direct `ailang check packages/motoko_ext_conformance/invariants.ail` can trip `MOD010` because the
  package directory is `packages/motoko_ext_conformance` while module declarations are
  `sunholo/motoko_ext_conformance/...`. The actual package imports and root scripts work. The
  `make conformance` package-file checks use `AILANG_RELAX_MODULES=1`, matching the repo's existing
  package-probe convention; root script checks remain strict.
- The conformance package is not registry-resolvable. A grep against `registry_generated.ail` showed
  no `motoko_ext_conformance` or `reject_fixtures` entries.

## Verification

Final verification passed:

- `make conformance`
- `make check_core`
- `ailang test src/core/phase_vocab.ail`
- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail`

During WI-5 caps measurement:

- hook-driving over structural conformance passed under `--caps IO`;
- a temporary port-bypassing hook using direct `std/env.getEnvOr` faulted under `--caps IO` with
  `effect 'Env' requires capability`.

The temporary caps probe was removed.

## Diagrams and code graph

The user then asked for a Mermaid diagram of the actual implemented end-state grounded in
`tools/code-graph/AGENTS.md`.

Actions:

- ran `tools/code-graph/extract.sh --profile=all`;
- refreshed graph metadata:
  - profile `all`;
  - 166 modules;
  - 1675 funcs;
  - 199 imports;
  - 48165 source lines;
  - stale/source_stale false;
  - coverage ok=145, partial=3, failed=18.
- queried `modules`, `imports`, `source_lines`, and `source_chunks` via `cgq.py`;
- found that `imports.csv` does not currently resolve `pkg/sunholo/motoko_ext_conformance/...`
  namespace imports back to filesystem slugs for the underscore package, so the implemented diagram
  labels those package import edges as source-index-confirmed.

Added:

- `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.mmd`
- `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.svg`

Updated:

- `.agent/projects/004_phase_core_refactor/mmd/README.md`

The implemented diagram was rendered with:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.mmd \
  .agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.svg \
  --theme tokyo-night
```

## Planned vs actual end-state comparison

The user asked to compare the implemented diagram with the plan author's expected end-state diagram:

- expected:
  `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-end-state.mmd`
- actual:
  `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.mmd`

Conclusion:

- no architectural contradiction;
- the implemented diagram is the same shape but more precise.

Actual-state additions relative to expected:

- `scripts/phase_c_l1_scenarios.ail` is a real consumer of `validate_compactor_output`;
- `scripts/conformance_registry_probe.ail` depends on `src/core/config` via `load_runtime_config`;
- the registry probe includes the full registry and non-compactors that pass vacuously;
- the gate is the concrete `make conformance` target rather than two abstract gate nodes;
- graph/source grounding limitations are explicitly documented.

## New meta-decision

The user asked whether speculating the end-state and comparing it with actual was a good approach,
then asked to add those insights to `.agent/meta-decisions/`.

Added:

- `.agent/meta-decisions/compare-speculated-end-state-to-actual.md`

Core rule captured there:

- planned end-state diagrams are hypotheses, not truth;
- after implementation, create or refresh an actual artifact grounded in source/code graph;
- compare boundaries, imports, gates, and forbidden edges;
- classify diffs as implementation bugs, plan gaps, harmless support edges, or tool limitations;
- preserve both planned and actual views when useful.

## Files changed during the session

Major source/gate files:

- `packages/motoko_ext_conformance/ailang.toml`
- `packages/motoko_ext_conformance/invariants.ail`
- `packages/motoko_ext_conformance/harness.ail`
- `packages/motoko_ext_conformance/fixtures/reject_fixtures.ail`
- `scripts/conformance_selftest.ail`
- `scripts/conformance_registry_probe.ail`
- `src/core/ext/runtime.ail`
- `src/core/phase_vocab.ail`
- `scripts/phase_c_l1_scenarios.ail`
- `ailang.toml`
- `ailang.lock`
- `Makefile`

Docs/diagrams/meta:

- `.agent/projects/004_phase_core_refactor/ADR-001-phase-oriented-core.md`
- `.agent/projects/004_phase_core_refactor/mmd/README.md`
- `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.mmd`
- `.agent/projects/004_phase_core_refactor/mmd/conformance-kit-implemented.svg`
- `.agent/meta-decisions/compare-speculated-end-state-to-actual.md`

This summary was added as:

- `.agent/summaries/2026-07-08-conformance-kit-implementation-and-grounded-diagrams.md`
