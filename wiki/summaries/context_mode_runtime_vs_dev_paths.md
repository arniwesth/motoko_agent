---
doc_type: short
full_text: sources/context_mode_runtime_vs_dev_paths.md
---

## Extension Runtime Loading: Package-Based, Not Source-Based

- **Runtime path**: The extension registry in `src/core/ext/registry.ail` imports extension modules via `pkg/...` paths (e.g., `pkg/sunholo/motoko_context_mode/...`).
- **Resolution**: Root dependency mapping in `ailang.toml` resolves these `pkg/` imports to the mirrored `.packages/` directories.
- **Result**: At normal runtime, the executing extension code comes from `.packages/motoko_*`, not from `src/core/ext/`.

## Development Model

- **Source of truth**: Extensions are edited in `src/core/ext/*`.
- **Runtime view**: `.packages/motoko_*` is the mirrored, package-ready version.
- **Sync mechanism**: `make sync_packages` automates mirroring from `src/core/ext/*` to `.packages/motoko_*` to keep the runtime view current.

## Important Nuance

- Direct execution (e.g., targeted tests or checks against `src/core/ext/...`) can compile and run from the source path.
- However, the primary extension wiring through the registry **always** uses the package-based `.packages` paths.

## Related Concepts
- [[concepts/package-sync-mechanism]]

- [[concepts/package_resolution]]
- [[concepts/runtime_vs_dev_paths]]
- [[concepts/make_sync_packages]]
