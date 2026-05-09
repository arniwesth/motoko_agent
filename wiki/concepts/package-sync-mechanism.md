---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md, summaries/Exa_Websearch_Extension.md, summaries/context_mode_runtime_vs_dev_paths.md, summaries/2026-05-03-motoko-core-package-sync.md]
brief: Mechanism to mirror extension source changes into .packages/ and regenerate lockfiles for runtime resolution.
---

# Package Sync Mechanism

The **Package Sync Mechanism** is the workflow that materializes extension and core packages—derived from canonical source directories—into a `.packages/` structure, where they can be resolved as stand-alone dependencies by other packages. It bridges the gap between the development source-of-truth (`src/core/ext/*`) and the package-based runtime environment, where the extension registry imports modules via `pkg/...` paths that resolve to `.packages/` directories through the root `ailang.toml`.

## Runtime vs Development Paths

Extensions are edited in `src/core/ext/` as the primary source. At runtime, however, the extension registry in `src/core/ext/registry.ail` imports these extensions using package-qualified paths (e.g., `pkg/sunholo/motoko_omnigraph/...`). The root dependency resolution in `ailang.toml` maps these imports to the mirrored copies under `.packages/motoko_*`. Thus, the extension code that actually executes comes from `.packages/`, not from the source tree. This distinction is crucial: direct targeted tests or checks against `src/core/ext/...` may compile from the source path, but the wired runtime flow always uses the package view. (See [[concepts/runtime_vs_dev_paths]]).

## Triggering the Sync

The sync is invoked via `make sync_packages`, which automates the mirroring from `src/core/ext/` to `.packages/motoko_*`. Under the hood, this may call a dedicated script (e.g., `scripts/sync-extension-packages.sh`) that performs the following operations:

1. **Copy source files** – Each extension directory under `src/core/ext/<name>/` is mirrored to `.packages/motoko_<name>/`. For the core package (`motoko_core`), a special routine copies `src/core/` (excluding extension subdirectories and build artifacts) into `.packages/motoko_core/src/core/` and places a project-level `ailang.toml` and `AGENT.md`.

2. **Rewrite import paths** – Source files originally use local imports (e.g., `import src/core/tool_contract`) to stay valid in the root project. The sync script transforms these into package-qualified imports using the target package’s `module_prefix`. For example, `import src/core/tool_contract` becomes `pkg/sunholo/motoko_core/core/tool_contract` when the package’s `module_prefix` is `"src"` and the export is `src/core/tool_contract`. This ensures that the compiler resolves every module path correctly within the isolated package structure.

3. **Generate per-package lock files** – After materialization, `ailang lock` is run inside each `.packages/<package>/` to resolve dependencies locally, enabling independent builds and type-checking of extensions.

In practice, when a developer changes an extension like [[concepts/omnigraph]] in the source tree, they must mirror the modified files into the corresponding `.packages/motoko_omnigraph/` and regenerate the lock file (`ailang lock`). This step was explicitly performed in the [[summaries/2026-04-26-abort-history-and-omnigraph-delete|Omnigraph deletion workflow]], where updates were mirrored and lock metadata was regenerated to ensure the runtime loaded the new `delete_all_*` mutations through the package dependency path.

## Design Principle

The sync mechanism enforces a strict rule: **the root project is the canonical source and must never declare any of these derived packages as dependencies**. If the root `ailang.toml` listed `sunholo/motoko_core` or extension packages, the compiler would encounter dual ownership of modules, leading to ambiguous resolution errors (see [[concepts/dependency-namespace-conflict]]). The sync is a one-way derivation—packages exist solely for downstream consumers and the runtime registry.

## Why It Matters

Without the sync, the compiler cannot locate the package-level `ailang.toml`, and even if found, import paths would remain broken because the local-to-package-path transformation is missing. The mechanism also isolates extension build environments, allowing separate locking, type-checking, and ultimately reliable runtime loading via the registry. As demonstrated by the Omnigraph delete rollout, any functional change to an extension must be mirrored into `.packages/` and re‑locked before the runtime can pick it up; otherwise the registry would resolve stale, pre‑edit code.

## Related Concepts

- [[concepts/runtime_vs_dev_paths]] – The distinction between editing source vs. resolving packages at runtime.
- [[concepts/dependency-namespace-conflict]] – Ambiguity when root and package share the same module prefix and source files.
- [[concepts/package-module-ownership]] – Rules for which package owns a module when sources are shared.
- [[concepts/effect-row-typing]] – A type-level concept surfaced after sync fixes; enabled by proper package isolation.
- [[summaries/2026-05-03-motoko-core-package-sync]] – Original fix that established the sync workflow.
- [[concepts/omnigraph]] – The extension whose deletion capability required a mirror + lock sync.

## Related Documents
- [[summaries/2026-04-26-abort-history-and-omnigraph-delete]] – Implementation that included the package sync step for Omnigraph.
- [[summaries/context_mode_runtime_vs_dev_paths]]
- [[summaries/Exa_Websearch_Extension]]