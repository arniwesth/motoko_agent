---
doc_type: short
full_text: sources/2026-04-02-brain-version.md
---

# Brain version at startup

## Goal
Add a brain version display alongside the existing TUI version at agent startup, using the actual brain binary's version rather than a hardcoded constant.

## Implementation
- **TUI version** is read from `tui/package.json`.
- **Brain version** is obtained at startup by executing `ailang run --entry print_version --caps IO swe/version.ail` from the TUI, with a 15-second timeout. If unavailable, it falls back to `"unknown"`.
- The banner now shows both versions (e.g., `AILANG Agent TUI v0.1.0 | Brain v0.1.0`).
- History pane `session_start` events also include the brain version (retrieved from JSONL), preparing for potential mid-session version changes.

## Module changes
### `swe/types.ail`
Added an exported version function returning `"0.1.0"` — the canonical brain version constant. AILANG does not support `export const`; `export func` with a literal string is the idiomatic way to expose module-level values (see [[concepts/ailang module patterns]]).

### `swe/version.ail`
New file: thin entry point that prints the version by calling `types.version()`. It uses `import swe/types as T` to avoid name collision with its own `print_version` export. Follows the pattern of creating dedicated entry modules for external queries.

### `swe/rpc.ail`
Updated `session_start` emits to include `brainVersion`. To avoid parser errors, the version string is first bound to a local variable before being passed to `jo()` (direct nesting of function calls inside `kv()` is problematic).

### TUI (`tui/src/`)
- `brain.ts`: Added `brainVersion` field to the `session_start` event union.
- `index.ts`: Uses Node.js `execSync` to call the brain version command at startup, forwarding the result to the banner.
- `ui.ts`: Displays brain version from event data in the history pane.

## Key design decisions and gotchas
- **AILANG module constants**: Only `export func` works for cross-module value exposure; `export const` and `let` are invalid here. This pattern may reappear in other modules — considered part of [[concepts/ailang module patterns]].
- **Parser limitation**: Nested function calls inside `kv()` cause AILANG parse errors, so expressions like `js(version())` must be factored into a local variable first.
- **Robustness**: The brain version query has a timeout and fallback, ensuring the TUI starts even if the brain is unavailable.

## Verification
All AILANG and TypeScript checks passed, tests passed, and the build succeeded. The version display works as designed.

## Related topics
- [[concepts/version management]] for tracking runtime component versions.
- [[concepts/tui-brain integration]] for patterns of connecting the TUI to the brain process.
- [[concepts/ailang module patterns]] for idioms like `export func` constants and entry-point modules.