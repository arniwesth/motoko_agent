# motoko_core Package Sync & Import Resolution (2026-05-03)

## Symptom
`make run` failed at `ailang lock` with:
```
Error: dependency resolution failed: failed to load dependency sunholo/motoko_core
at /workspaces/motoko_agent/.packages/motoko_core: failed to read
.packages/motoko_core/ailang.toml: no such file or directory
```
After fixing the sync, `make check_core` failed on `rpc.ail` and `supervisor.ail`:
```
module "sunholo/motoko_core/tool_contract" is not exported by package
"sunholo/motoko_core"
Available exports:
  src/core/compress
  src/core/config
  src/core/tool_contract
  src/core/types
  src/core/ext/types
```

## Architecture

The workspace has a split-personality layout:

| Role | Package name | `module_prefix` | Source |
|------|-------------|-----------------|--------|
| Root project | `local/motoko_agent` | `src` | `src/core/*.ail` |
| Core package | `sunholo/motoko_core` | `src` | `src/core/` (subset exported) |
| Extension pkgs | `sunholo/motoko_<name>` | `src` | `src/core/ext/<name>/` |

The root project and `motoko_core` share the same source directory. The sync script
materializes each into `.packages/` so extension packages can resolve `motoko_core`
as a dependency. Extension packages also have their own `ailang.toml` and are
materialized into `.packages/motoko_<name>/`.

## Root Causes

### 1. `motoko_core` never synced to `.packages/`

`scripts/sync-extension-packages.sh` iterated over extension directories under
`src/core/ext/<name>/` and synced each to `.packages/motoko_<name>/`. It had no
logic for `motoko_core`, whose source is `src/core/` (not under `ext/`).

**Fix**: Added `sync_core()` to the script. It rsyncs `src/core/` (excluding extension
subdirectories, `.ailang/`, `AGENT.md`, `ailang.toml`) to `.packages/motoko_core/src/core/`,
then copies `src/core/ailang.toml` and `AGENT.md` to `.packages/motoko_core/`.

### 2. Ambiguous module ownership between root and `motoko_core` package

Once `.packages/motoko_core` existed, the root project's dependency tree included
`motoko_core` (both directly via `ailang.toml` and transitively through extension
package deps). This created dual ownership: `src/core/tool_contract.ail` existed
both in the root project AND as an export of `motoko_core`.

Modules that were themselves exported by `motoko_core` (e.g., `types.ail`,
`tool_contract.ail`) resolved internally within the package boundary. But `rpc.ail`
and `supervisor.ail` are NOT exported by `motoko_core`. When they imported
`src/core/tool_contract`, the compiler crossed the package boundary and constructed
a package-qualified path by stripping the root's `module_prefix` (`src`) from the
import, yielding `pkg/sunholo/motoko_core/tool_contract`.

With `motoko_core`'s `module_prefix = "src"` and export `src/core/tool_contract`,
the correct package import is `pkg/sunholo/motoko_core/core/tool_contract`
(strip `module_prefix` from export). The compiler constructed the wrong path
(`tool_contract` instead of `core/tool_contract`), and resolution failed.

**Fix**: Removed ALL extension package dependencies from the root `ailang.toml`.
The root project contains the canonical source of all `src/core/` modules and
does not need `motoko_core` or any extensions as dependencies. Only
`sunholo/logging` remains as a root dependency.

### 3. Wrong package import paths in extension source files

Several extension files under `src/core/ext/` used `pkg/sunholo/motoko_core/tool_contract`
and `pkg/sunholo/motoko_core/ext/types`. These paths are incorrect — given
`module_prefix = "src"`, the correct forms are `core/tool_contract` and
`core/ext/types`. These files were never type-checked because `sync_packages`
always failed before reaching `check_core`.

Additionally, the presence of `pkg/` imports in extension source files (which
live in the root project's source tree) created spurious package resolution
chains when the root compiler walked imports transitively.

**Fix**: All extension source files now use only local imports
(`import src/core/tool_contract`, `import src/core/ext/types`). The sync script
transforms these to correct `pkg/` imports when copying to `.packages/`, and
generates per-package `ailang.lock` files so extensions resolve independently.

### 4. Pre-existing effect row bug in `test_dummy/dummy.ail`

`register()` returned `ExtensionHooks` with signature `! {Env}`, but the
`on_budget_plan` field has type `(ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS}`.
The lambda assigned to it captured `cfg` from an `Env`-only scope, so its inferred
effect was `{Env}`. AILANG uses closed effect rows: `{Env}` ≠ `{Env, FS}`.
This was always wrong but never surfaced because `check_core` never ran.

**Fix**: Changed `register()` to `! {Env, FS}`, and replaced the bare lambda
with an explicitly-typed `func` declaring `! {Env, FS}`. Added `BudgetPlan` to
imports.

## Key Design Principle

**Root project and core package must not share the same dependency namespace.**
When the root project declares a dependency whose `module_prefix` overlaps with
the root's own `module_prefix`, and the dependency contains copies of root modules,
the compiler faces an unresolvable ambiguity. The fix is to eliminate the
dependency from the root — the root IS the canonical source; packages are derived
copies for downstream consumers only.

## Files Changed

- `scripts/sync-extension-packages.sh` — added `sync_core()`, import path transformation, per-package `ailang lock`
- `ailang.toml` — removed all extension package dependencies (keep only `sunholo/logging`)
- `src/core/ext/**/*.ail` — reverted all `pkg/sunholo/motoko_core/...` imports to local `src/core/...` imports
- `src/core/ext/test_dummy/dummy.ail` — fixed effect row mismatch in `register()`
