# Phase 2 Spike Results (2026-04-24)

## Scope
Validated package import and docs-loading behavior before flipping extension imports to `pkg/...`.

## Findings
1. `module_prefix` must be a single segment.
- Using `module_prefix = "docparse"` worked.
- Import path for exported module `docparse/main` became `pkg/sunholo/motoko_spike/main`.

2. Hyphens are not valid in AILANG import/module segments.
- `pkg/sunholo/motoko-spike/...` fails parse (`PAR_HYPHEN_IN_IMPORT`).
- Use underscores in package names intended for import paths (`motoko_spike`, `motoko_compose`, etc.).

3. `readFile("AGENT.md")` inside a dependency package resolves against consumer cwd, not package root.
- Test package had `AGENT.md` at package root.
- Runtime probe returned `MISSING` when called from consumer package.
- Consequence: loading extension prompt docs should use explicit host-known paths (or `ailang pkg-docs`) rather than assuming package-relative FS reads.

## Current Phase 2 Blocker
Directly flipping `registry.ail` to `pkg/...` imports is blocked by package boundary coupling:
- extension packages currently import `src/core/types`, `src/core/tool_contract`, and `src/core/ext/types`, which are outside each extension package root.
- a shared `motoko_core` package (or equivalent contract package split) is required before full `pkg/...` migration.
