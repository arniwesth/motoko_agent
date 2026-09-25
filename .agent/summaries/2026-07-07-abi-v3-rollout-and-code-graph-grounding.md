# 2026-07-07 ABI v3 rollout implementation and code-graph grounding

## Context

This session implemented `.agent/projects/004_phase_core_refactor/PLAN-abi-v3-rollout.md`,
the dependency-root rollout for extension ABI `2.2.0 -> 3.0`, `compaction_ai 0.3.0`,
`compaction_structural 1.1.0`, core-side artifact/telemetry threading, and the folded driven
trace scenario. Toolchain was verified as AILANG `v0.26.0`.

Before implementation, the operator closed the two ADR-001 open questions:

- Open Q2: `artifacts` remains raw `Json`.
- Open Q3: `ExtPorts` freezes `{ ai_step, proc_exec, clock_now, env_get }`; `http` and `kv`
  remain deferred.

ADR-001 and the rollout plan were amended with those decisions.

## Course correction: no `~/.ailang` rollout sources

The plan initially assumed creating new versions under the local registry cache. The operator
corrected this: `~/.ailang/` is disposable in the dev container and must not be the durable source
of this rollout.

Any temporary ABI/compaction cache dirs created during exploration were removed. The durable
implementation instead vendors active extension packages under `packages/` and resolves them via
path dependencies. The plan now records this as implementation correction G-A6.

## ABI and package rollout

Added `packages/motoko-ext-abi/` at version `3.0`:

- `ExtCtx += { ports, artifacts, telemetry }`
- new `ExtPorts`
- new `TokenTelemetry`
- `PreStepDecision.Compacted(msgs, note, artifacts: Json)`

Removed the vestigial in-tree mirror `src/core/ext/types.ail` after confirming no live `.ail`
source imports it.

Vendored active extension packages under `packages/` and pathified dependencies so the root
manifest and lockfile resolve through workspace paths rather than newly created registry-cache
versions. Root `ailang.toml` now uses path dependencies for the ABI and active extension packages.

`ailang.lock` was regenerated and records:

- `sunholo/motoko_ext_abi@3.0` from `packages/motoko-ext-abi`
- `sunholo/motoko_ext_compaction_ai@0.3.0` from `packages/motoko-ext-compaction-ai`
- `sunholo/motoko_ext_compaction_structural@1.1.0` from `packages/motoko-ext-compaction-structural`

## Core threading

Added `src/core/ext/ctx_defaults.ail` for neutral ABI v3 context defaults:

- `noop_ext_ports`
- `empty_ext_artifacts`
- `zero_token_telemetry`

Updated `src/core/session.ail` so `C2LoopState` carries extension artifacts and token telemetry
across steps. The loop now builds ABI v3 `ExtCtx` values with projected `ExtPorts`, existing
artifact state, and telemetry. The pre-step chain result writes `chain.artifacts` back into the
next loop state rather than resetting artifacts each iteration.

Updated `src/core/ext/runtime.ail` so `PreStepChainResult` includes `artifacts: Json`; the pre-step
fold threads artifacts through stages and treats `Compacted(_, _, artifacts)` as the next artifact
state for the chain.

Updated RPC builders, smoke scripts, DST scripts, fixtures, and all `Compacted` construction and
pattern-match sites for the new arity.

## Extension migrations

`packages/motoko-ext-compaction-ai` is now version `0.3.0`:

- uses `ctx.ports.ai_step` instead of direct `std/ai.step`
- converts core `[Msg]` to ABI `[Message]`
- preserves leading system prefix in splitting
- avoids splitting assistant tool calls from their paired tool results
- maintains an artifact cache keyed by segment digest
- returns real artifacts through `Compacted(..., cache_artifact(...))`

`packages/motoko-ext-compaction-structural` is now version `1.1.0`:

- dependency bumped to ABI v3
- `Compacted` arity updated mechanically
- no policy logic change

## Driven trace scenario and gates

Extended `scripts/phase_c2_wiring_scenarios.ail` with a driven `LedgerTrace` invariant asserting
that compactor chain stage order follows registry order. Scenario count changed from 6 to 7.

Updated `Makefile` so `phase_c_l1` also gates:

```sh
ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail
```

The default `make run` path was inspected and documented:

- `run -> build`
- `build -> sync_packages check_core build_tui`
- `sync_packages` still mirrors legacy source-tree extensions into `.packages/`, but it does not
  overwrite the rollout packages under `packages/`
- generated registry imports resolve through `pkg/...` and the path-based lockfile

This is documented in
`.agent/projects/004_phase_core_refactor/NOTE-abi-v3-runtime-package-resolution.md`.

## Verification

Baseline before edits was green:

- `ailang check src/core/session.ail`
- `ailang check src/core/ext/runtime.ail`
- `ailang check src/core/phase_vocab.ail`
- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` -> `PASS count=13`
- `ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail`
  -> `PASS count=6`

After implementation, the following passed:

- checks for ABI, `compaction_ai`, `compaction_structural`, core runtime, RPC, fixture, smoke, and
  DST scripts
- vendored extension exported-module sweep with `AILANG_RELAX_MODULES=1`
- `ailang run --caps IO --entry main scripts/phase_c_l1_scenarios.ail` -> `PASS count=13`
- `ailang run --caps IO,Env,Clock,FS,Trace --entry main scripts/phase_c2_wiring_scenarios.ail`
  -> `PASS count=7`
- `make phase_c_l1`
- `make check_core`

`~/.ailang/cache/registry/sunholo` was checked after the course correction; no new rollout package
versions were left there.

## Diagram and code-graph grounding

Added Mermaid diagram:

- source: `.agent/projects/004_phase_core_refactor/mmd/abi-v3-rollout-implemented.mmd`
- rendered SVG: `.agent/projects/004_phase_core_refactor/mmd/abi-v3-rollout-implemented.svg`

The diagram shows:

- Q2/Q3 decisions
- durable `packages/` sources
- root manifest and lockfile path resolution
- generated registry package imports
- ABI/core artifact and telemetry threading
- migrated compaction extensions
- driven trace and Makefile gates
- `make run` path and the `.packages` caveat

The operator then asked to ground the diagram with `tools/code-graph`. First finding: code-graph
did not index `packages/` in any profile. The broad `all` profile was updated to index
`packages/**`, and the source index host globs were extended to include `Makefile`, `ailang.lock`,
`packages/**/*.toml`, and `.motoko/config/**/*.json`.

Files changed for code-graph:

- `tools/code-graph/extractor/config.py`
- `tools/code-graph/AGENTS.md`
- `tools/code-graph/README.md`

Ran:

```sh
tools/code-graph/extract.sh --profile=all
```

Final code-graph status:

- profile: `all`
- `161 modules`
- `1595 funcs`
- `322 source files`
- `84 packages/* files`
- `source_stale=false`

Grounding queries confirmed the diagram's major claims against indexed source rows:

- ABI v3 fields and `Compacted(..., artifacts)` in `packages/motoko-ext-abi/types.ail`
- `ctx.ports.ai_step` and artifact cache in `packages/motoko-ext-compaction-ai/compaction_ai.ail`
- `ext_artifacts` and telemetry threading in `src/core/session.ail`
- `PreStepChainResult.artifacts` and `Compacted(_, _, next_artifacts)` fold in
  `src/core/ext/runtime.ail`
- root `ailang.toml` path dependencies
- `ailang.lock` `source: "path"` entries
- default config order includes `compaction_ai` and `compaction_structural`
- `Makefile` `run: build` and `build: sync_packages check_core build_tui`
- driven trace order invariant in `scripts/phase_c2_wiring_scenarios.ail`

The Mermaid source and README were updated with grounding metadata and the SVG was re-rendered.

## Notes for future agents

Use `tools/code-graph/extract.sh --profile=all` when reasoning about package-vendored extension
implementations. The default `core` profile intentionally remains `src/core/**` focused.

Do not recreate rollout package sources under `~/.ailang/cache`. The workspace `packages/` dirs
are the durable source of ABI v3 and the compaction extension migrations.
