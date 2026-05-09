---
doc_type: short
full_text: sources/Phase2_spike_results.md
---

# Phase 2 Spike Results Summary (2026-04-24)

This spike tested package import behaviour prior to migrating extension imports to `pkg/...` paths. It revealed several constraints and a current blocker.

## Key Findings
- **Module prefix must be a single segment** – Using `module_prefix = "docparse"` worked, mapping the exported module to `pkg/sunholo/motoko_spike/main`. Multi‑segment prefixes are invalid. ([[concepts/module-prefix]])
- **Hyphens are disallowed in import paths** – Package names with hyphens (e.g., `motoko-spike`) cause `PAR_HYPHEN_IN_IMPORT` parse errors. Use underscores instead ([[concepts/hyphen-import-errors]]).
- **File resolution is consumer‑relative** – `readFile("AGENT.md")` inside a dependency resolves against the consuming package’s working directory, not the package root. This breaks assumptions about package‑relative docs loading for extension prompts. Explicit host‑known paths or the `ailang pkg-docs` tool should be used instead ([[concepts/file-resolution-in-packages]]).

## Migration Blocker
Directly switching to `pkg/...` imports is currently blocked by [[concepts/package-boundary-coupling]]: extensions import files like `src/core/types` and `src/core/tool_contract` that lie outside their package roots. A shared `motoko_core` package (or equivalent contract split) is required before full migration.