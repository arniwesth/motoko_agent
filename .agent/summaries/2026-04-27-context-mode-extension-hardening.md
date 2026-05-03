# 2026-04-27: Context Mode Extension Hardening

## Scope
This session focused on making the `context_mode` extension reliable in real runtime use, reducing fallback to `BashExec`, and automating package mirror + lock maintenance so runtime code and source code stay aligned.

## Key outcomes

1. Context-mode bridge integration
- Added a Node MCP bridge script (`scripts/context-mode-mcp-call.mjs`) that:
  - spawns `context-mode` over stdio,
  - performs MCP `initialize`,
  - calls `tools/call` for a requested `ctx_*` action,
  - returns structured output/error.
- Updated `src/core/ext/context_mode/context_mode.ail` to route `Ctx*` tools through this bridge instead of direct shell invocations that did not match actual CLI behavior.

2. Stronger routing and policy nudges toward Context Mode
- Hardened `on_tool_policy` to deny `BashExec` for:
  - context-mode probing commands (`context-mode`, `ctx_*`, `Ctx*`-style variants),
  - remote URL fetches in `BashExec` (any command containing `http://` or `https://`).
- Deny messages now explicitly redirect to extension tools (`CtxFetchAndIndex`, `CtxStats`, `CtxDoctor`, `CtxSearch`, etc.) even if generic tool tables omit them.
- Expanded routing card (`src/core/ext/context_mode/AGENT.md`) with explicit behavioral rules:
  - extension tools are authoritative,
  - no Bash preflight checks for context-mode,
  - preferred test order (`CtxDoctor` -> `CtxStats` -> requested operation).

3. Readiness preflight (auto-start/verify behavior)
- Added per-session readiness logic in `context_mode.ail`:
  - before non-`CtxDoctor` calls, the extension runs a one-time `ctx_doctor` preflight via the bridge,
  - stores a shared-memory ready marker keyed by session state,
  - avoids repeating preflight once marked ready.
- This provides practical “check/start if needed” behavior for the stdio model (spawned per call), without requiring a separate daemon manager.

4. Package mirroring automation
- Added `scripts/sync-extension-packages.sh` to mirror extension source directories:
  - `src/core/ext/compose` -> `.packages/motoko_compose`
  - `src/core/ext/omnigraph` -> `.packages/motoko_omnigraph`
  - `src/core/ext/test_dummy` -> `.packages/motoko_test_dummy`
  - `src/core/ext/context_mode` -> `.packages/motoko_context_mode`
- Excludes local caches and source-only metadata during mirror copy, then writes package-root metadata.
- Correctly rewrites mirrored extension dependency path:
  - from `../..` to `../motoko_core`.

5. Makefile automation
- `sync_packages` now runs:
  - `check_ailang`
  - `./scripts/sync-extension-packages.sh`
  - `ailang lock`
- `check_core` depends on `sync_packages`.
- `build` simplified to avoid duplicate sync/lock work and relies on `check_core`.

## Root-cause findings documented during debugging

1. Why files exist in both `src/core/ext/...` and `.packages/motoko_*...`
- Runtime registry imports extension packages via `pkg/sunholo/...` paths.
- Root `ailang.toml` resolves those dependencies to `.packages/...`.
- Therefore runtime extension loading is package-based (`.packages`), while `src/core/ext/*` is the development source-of-truth.
- Added note file: `.agent/notes/context_mode_runtime_vs_dev_paths.md`.

2. Lock/hash warning cause
- Warning like `dependency sunholo/motoko_context_mode content changed` occurred when mirrored package content changed but `ailang.lock` was stale.
- Also surfaced when mirror manifests were incorrect (`../..` instead of `../motoko_core`), causing resolution drift.
- Automated `ailang lock` in `sync_packages` to keep lock hashes current.

## Tests and validation
- `ailang check src/core/ext/context_mode/context_mode.ail` passed after fixes.
- `ailang test src/core/ext/context_mode/context_mode_test.ail` expanded and passing:
  - alias normalization,
  - policy deny for context-mode Bash probes,
  - policy deny for remote URL fetch via BashExec,
  - deny for non-curl URL fetch attempts,
  - prompt patch behavior,
  - compression behavior.
- `make sync_packages` succeeds and regenerates `ailang.lock`.
- `make check_core` passes.

## Remaining nuance
- Tool planner output can still show a `BashExec` step as `planned` before policy filters/replans. The enforcement point is tool policy at execution time, not initial plan text.
- Context-mode uses stdio MCP spawn-per-call semantics via bridge; readiness preflight verifies availability but does not create a persistent daemon.
