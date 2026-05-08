---
doc_type: short
full_text: sources/2026-05-03-motoko-core-package-sync.md
---

# motoko_core Package Sync & Import Resolution

Fix for a series of build failures in `make run` and `make check_core`. The root causes were a missing sync step for the `motoko_core` package, ambiguous module ownership between root project and package, and incorrect cross-package import paths.

## Architecture

The workspace uses a split-personality layout where the root project (`local/motoko_agent`) and the core package (`sunholo/motoko_core`) share the same source directory (`src/core/`). Extension packages live in `src/core/ext/<name>/` and each is materialized into `.packages/motoko_<name>/`. The sync script originally only handled extensions and omitted `motoko_core`.

## Root Causes & Fixes
1. **Missing `motoko_core` sync**: The script `scripts/sync-extension-packages.sh` had no logic for `motoko_core`. Added `sync_core()` that rsyncs `src/core/` (excluding extension dirs) to `.packages/motoko_core/`.
2. **Ambiguous module ownership**: After syncing, both root and `motoko_core` exported files from `src/core/`. The root depended on `motoko_core`, causing the compiler to construct incorrect package-qualified paths. The fix removed all extension package dependencies from the root's `ailang.toml` — the root is the canonical source, and packages are only derived for downstream consumers. This is a [[concepts/dependency-namespace-conflict]].
3. **Incorrect package import paths in extension sources**: Extensions used `pkg/sunholo/motoko_core/tool_contract` but with `module_prefix = "src"` the correct form should be `core/tool_contract`. All extension sources reverted to local imports like `import src/core/tool_contract`. The sync script now transforms these to correct `pkg/` imports during materialization. This touches [[concepts/package-module-ownership]].
4. **Pre-existing effect row bug**: `test_dummy/dummy.ail` had a type mismatch (`{Env}` vs `{Env, FS}`) that was never caught because `check_core` never ran. Fixed by widening effect row and using explicit function type. This relates to [[concepts/effect-row-typing]].

## Key Design Principle
**Root project and core package must not share the same dependency namespace.** When both overlap in source and the root declares the package as a dependency, the compiler faces unresolvable ambiguity. The root project is the canonical source; packages exist solely for external consumers. This is captured as [[concepts/package-sync-mechanism]].