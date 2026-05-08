---
doc_type: short
full_text: sources/2026-04-03-ailang-version-in-header.md
---

## Overview
This change extends the TUI startup banner and history pane to include the AILANG runtime version, displayed as its build datetime. Previously, only TUI and Brain versions were shown. The work completes a "version trinity" and uses a passthrough pattern consistent with the existing Brain version mechanism.

## Design
- **AILANG Build Datetime**: Parsed from `ailang --version` via regex `Built: YYYY-MM-DD_HH:MM:SS` because the binary reports `AILANG dev` without semver.
- **Banner**: Shows `AILANG Agent (AILANG built ...) TUI v0.1.0 | Brain v0.1.0`.
- **History Pane**: Each `session_start` event now includes `ailangBuilt` alongside `brainVersion` and `tuiVersion`, displayed in the same style.
- **Passthrough**: TUI passes `AILANG_BUILT` env var to Brain, which reads it and emits in the JSONL `session_start` event. This mirrors the existing [[concepts/TUI-brain-architecture|TUI-brain passthrough pattern]].

## Implementation
- **tui/src/index.ts**: Parses the `Built:` line, sets `process.env.AILANG_BUILT`, passes `ailangVersion` to UI constructor.
- **tui/src/brain.ts**: Added `ailangBuilt` field to `session_start` event.
- **tui/src/ui.ts**: Accepts `ailangVersion` in constructor options, updates the `session_start` handler to include it.
- **swe/rpc.ail**: Reads `AILANG_BUILT` via `getEnvOr` in both `main()` and `conversation_loop()`, emits `kv("ailangBuilt", js(ailang_built))` — using a local variable to avoid [[concepts/AILANG-parser-quirks|AILANG parser nesting issue]].

## Key Gotchas
- **No semver for AILANG**: The binary is built without ldflags, so `ailang --version` outputs `AILANG dev`, leaving only the build timestamp as stable identity.
- **AILANG parser limitation**: Nesting `js(...)` inside `kv()` like `kv("x", js(getX()))` triggers a parse error; a local binding (`let x = getX(); kv("x", js(x))`) is required. This mirrors the earlier Brain version workaround.

## Verification
- AILANG source check (`ailang check swe/rpc.ail`) passed.
- TypeScript compilation (`npx tsc --noEmit`) passed.
- Full test suite (`npm test`) passed with 15/15.

## Related Concepts
- [[concepts/version-trinity|Display of all three version components (TUI, Brain, AILANG)]]
- [[concepts/TUI-brain-passthrough|Environment-driven data flow from TUI to Brain]]
- [[concepts/AILANG-parser-quirks|Parser restrictions with nested function calls in kv()]]