---
sources: [summaries/2026-05-03-motoko-core-package-sync.md]
brief: Ambiguity when a project and its dependency share source directories, breaking module resolution.
---

# Package Module Ownership

Package module ownership refers to the problem that arises when a root project and one of its dependencies have overlapping source directories and export the same or similar module paths. In the context of the Motoko agent workspace, the root project (`local/motoko_agent`) and the core package (`sunholo/motoko_core`) both drew source files from `src/core/`. The package was configured with `module_prefix = "src"` and exported modules like `src/core/tool_contract`, while the root project also had `module_prefix = "src"` and included those same modules in its own compilation unit.

When the root project declared `motoko_core` as a dependency, the compiler faced dual ownership: a module like `tool_contract.ail` existed **both** as a local root module (`src/core/tool_contract`) and as a publicly exported member of the package (`pkg/sunholo/motoko_core/core/tool_contract`). For other root modules that were **not** exported by the package (e.g., `rpc.ail`), cross-package imports were constructed incorrectly: the compiler stripped the root’s `module_prefix` from the import path, then attempted to resolve it within the package’s namespace, yielding an invalid path (e.g., `pkg/sunholo/motoko_core/tool_contract` instead of `pkg/sunholo/motoko_core/core/tool_contract`). This led to errors like `module … is not exported by package`.

## Root Cause

The root project and the package shared the same source tree and the root directly depended on the package. This created an unresolvable ownership conflict: the compiler cannot distinguish which version of a module is authoritative, and import resolution breaks when the boundaries are ambiguous.

## Resolution

The fix was to eliminate the dependency from the root project’s `ailang.toml`. The root project is the **canonical source** of all `src/core/` modules; the `motoko_core` package is a derived copy used only by downstream extension packages. By removing it from the root’s dependency list, the ambiguity is removed, and the root compiler no longer tries to resolve modules through the package boundary.

## Related Concepts
- [[concepts/dependency-namespace-conflict]]: broader issue of overlapping dependency namespaces
- [[concepts/package-sync-mechanism]]: how packages are materialized from shared sources
- For more context, see the original document [[summaries/2026-05-03-motoko-core-package-sync]]