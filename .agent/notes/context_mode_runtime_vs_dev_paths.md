# Context Mode Extension: Runtime vs Development Paths

Date: 2026-04-26

Findings:
- Extension runtime loading is package-based, not source-path-based.
- The extension registry imports extension modules via `pkg/...` paths (for example `pkg/sunholo/motoko_context_mode/...`) in `src/core/ext/registry.ail`.
- Root dependency resolution maps these package imports to `.packages/...` directories in `ailang.toml`.
- Therefore, in normal runtime flow, the extension code that runs is the mirrored copy under `.packages/motoko_*`.

Development model:
- `src/core/ext/*` is the source-of-truth for editing extension code.
- `.packages/motoko_*` is a mirrored/runtime package view.
- `make sync_packages` now automates mirroring from `src/core/ext/*` to `.packages/motoko_*`.

Nuance:
- If you run a file directly by source path (for example targeted checks/tests against `src/core/ext/...`), that specific command can compile and run from source.
- But the primary extension runtime wiring through the registry is package-based (`.packages`).
