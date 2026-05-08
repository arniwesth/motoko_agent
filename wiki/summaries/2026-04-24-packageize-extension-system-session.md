---
doc_type: short
full_text: sources/2026-04-24-packageize-extension-system-session.md
---

# Session Summary — 2026-04-24

## Overview
This session completed the core refactor to replace closed ADT extension dispatch with open hook records (Phase 1), then advanced the packaging of extensions into a local workspace (Phase 2). Several regressions were discovered and fixed, including Omnigraph prompt priority and loaded-extension visibility.

## Phase 1: Open Hook Dispatch
- Introduced `ExtensionHooks` and an `ExtRegistry` holding a list of hooks, replacing the old `PureExt`/`EffectExt` sum types. See [[concepts/extension-hooks]].
- The runtime now folds over hooks to dispatch pure/effectful operations, eliminating per-extension match trees.
- All existing extensions (`test_dummy`, `compose`, `omnigraph`) were converted to export a `register()` constructor that returns their hooks.
- The caller contract (`rpc.ail`) remained unchanged. Smoke tests confirmed all six dispatchers.

## Phase 2: Package Workspace & Imports
- **Spike findings** documented in `.agent/notes/Phase2_spike_results.md`:
  - Hyphens in package/import paths break imports (must use underscores).
  - `module_prefix` behavior validated for parent-package resolution.
  - `readFile` resolution relative to `AGENT.md` was probed.
- Created a package workspace under `.packages/` with four local packages: `motoko_core`, `motoko_test_dummy`, `motoko_compose`, `motoko_omnigraph`. See [[concepts/package-workspace]].
- To avoid module-name collisions (`MOD011`), core modules were namespaced (`motoko_core/tool_contract`, `motoko_core/types`, `motoko_core/ext/types`).
- Extension imports rewired to `pkg/sunholo/motoko_core/...`; registry resolution now uses `pkg/...` imports.
- `ailang lock` and `ailang check` succeeded across the workspace. `ailang publish --dry-run` passed for all packages.

## Regressions & Fixes
- **Omnigraph prompt regression**: Model started ignoring Omnigraph. The prompt loader accidentally favored a minimal AGENT doc over the richer legacy prompt. Fixed by prioritizing `omnigraph/AGENT_PROMPT.md` in `src/core/ext/omnigraph/prompts.ail`. See [[concepts/omnigraph-prompt-regression]].
- **Startup extension visibility**: Added emission of `loaded_extensions` in `session_start` payload, runtime helper to list extension names, TUI rendering (history line, status bar), and fallback for direct `CORE_EXT_ORDER` read. Internal instance suffixes like `#0` are now stripped for user-facing display.

## Key Deliverables
- Open extension dispatch architecture (Phase 1).
- Fully functional package workspace with dry-run publish pipeline (Phase 2).
- Regression-free Omnigraph and improved developer visibility at startup.

## Key Files Changed
- Core extension system: `types.ail`, `registry.ail`, `runtime.ail`
- Extensions: `test_dummy`, `compose`, `omnigraph` modules and test files
- TUI/runtime plumbing: `rpc.ail`, `runtime-process.ts`, `ui.ts`, `index.ts`
- Package workspace: `ailang.toml`, `ailang.lock`, all `.packages/*`, phase spike notes

## Related Concepts
- [[concepts/extension-hooks]]
- [[concepts/package-workspace]]
- [[concepts/omnigraph-prompt-regression]]
- [[concepts/extension-visibility]]