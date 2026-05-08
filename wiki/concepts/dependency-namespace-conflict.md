---
sources: [summaries/2026-05-03-motoko-core-package-sync.md]
brief: Ambiguous module resolution when a root project and its dependency package share overlapping source directories.
---

# Dependency Namespace Conflict

A **Dependency Namespace Conflict** occurs when a root project declares a package dependency whose own `module_prefix` and source files significantly overlap with the root project's source tree, causing ambiguous module ownership. The compiler may resolve module imports to the wrong package boundary, leading to errors like "module is not exported by package."

## Symptoms
- Modules that are not exported by the dependency package cause import failures when the compiler constructs package-qualified paths incorrectly.
- Cross-package imports from the root into the dependency resolve to non-existent paths (e.g., `pkg/sunholo/motoko_core/tool_contract` instead of the correct `pkg/sunholo/motoko_core/core/tool_contract`).
- The project hierarchy has two distinct package identities (`local/motoko_agent` and `sunholo/motoko_core`) sharing the same canonical source directory (`src/core/`).

## Root Cause
When a package is derived from a subset or copy of the root project's sources, and the root then depends on that package, the compiler faces unresolvable ambiguity: a single module file exists both as a local root module and as an exported module of the dependency. The compiler may cross the package boundary when resolving imports, stripping the wrong prefix and generating invalid package paths. This is a direct consequence of having overlapping `module_prefix` values (both `"src"`) and shared source files.

## Resolution
Eliminate the dependency from the root project. The root project is the canonical single source of truth for all shared modules. Package artifacts (e.g., `.packages/`) are derived copies intended only for downstream external consumers. This aligns with the principle of [[concepts/package-sync-mechanism]]: the root builds the source, and packages are materialized for others via a sync process, never re-imported back into the root.

## Example
From [[summaries/2026-05-03-motoko-core-package-sync]]:
- Root: `local/motoko_agent` with `module_prefix = "src"` and source in `src/core/`.
- Core package: `sunholo/motoko_core` derived from `src/core/`, also with `module_prefix = "src"`.
- Root initially depended on `sunholo/motoko_core`; imports like `src/core/tool_contract` from unexported modules caused the compiler to construct `pkg/sunholo/motoko_core/tool_contract` (wrong).
- Removing the dependency from `ailang.toml` resolved the conflict; the root project now uses its own local modules directly.

## Related Concepts
- [[concepts/package-module-ownership]] – how the compiler assigns module ownership based on package boundaries and exports.
- [[concepts/package-sync-mechanism]] – the process that materializes derived packages from root sources, ensuring clear separation.