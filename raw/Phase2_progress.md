# Phase 2 Progress (2026-04-24)

## Implemented

- Added package workspace roots under `.packages/`:
  - `.packages/motoko_core`
  - `.packages/motoko_test_dummy`
  - `.packages/motoko_compose`
  - `.packages/motoko_omnigraph`
- Added `ailang.toml` + `AGENT.md` for each package root.
- Rewired extension code to import shared contracts via package imports:
  - `pkg/sunholo/motoko_core/tool_contract`
  - `pkg/sunholo/motoko_core/types`
  - `pkg/sunholo/motoko_core/ext/types`
- Switched `src/core/ext/registry.ail` resolver imports to package imports:
  - `pkg/sunholo/motoko_test_dummy/...`
  - `pkg/sunholo/motoko_compose/...`
  - `pkg/sunholo/motoko_omnigraph/...`
- Added root `ailang.toml` + `ailang.lock` to wire all four path dependencies.

## Validation

- `ailang lock` (repo root) succeeds with 4 packages.
- `ailang check src/core/ext/registry.ail` succeeds with pkg imports.
- `ailang check src/core/rpc.ail` succeeds with pkg imports in the extension path.
- Existing extension/runtime tests pass:
  - `src/core/ext/runtime.ail`
  - `src/core/ext/registry.ail`
  - `src/core/ext/test_dummy/dummy_test.ail`
  - `src/core/ext/omnigraph/omnigraph_test.ail`
  - compose unit tests already in repo (`compose_test`, `claimcheck_test`).
- `ailang publish --dry-run` succeeds for all four `.packages/*` packages.

## Notes

- To avoid `MOD011` duplicate-module collisions, `motoko_core` package modules use a dedicated namespace:
  - `motoko_core/tool_contract`
  - `motoko_core/types`
  - `motoko_core/ext/types`
  rather than reusing local `src/core/...` module names.
