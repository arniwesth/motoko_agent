# 2026-04-02 — Brain version at startup

## Goal
The agent had only one version (from `tui/package.json`) displayed at startup. The user wanted both a TUI version and a brain (swe/) version written when the agent starts up.

## Final design
- **TUI version** — known at startup from `package.json`.
- **Brain version** — queried from the actual brain binary at startup via `ailang run --entry print_version --caps IO swe/version.ail`.
- **History pane** — also shows the brain version from each `session_start` event (for future mid-session version changes).

## Changes

### swe/types.ail
- Added `export func version() -> string = "0.1.0"` — the brain version constant.
- AILANG does not support `export const` or `export let`; `export func` returning a string is the canonical way to expose a module-level constant.

### swe/version.ail (new)
- Thin entry point that prints the brain version. Invoked by the TUI at startup via `ailang run --entry print_version --caps IO swe/version.ail`.
- Uses `import swe/types as T` to avoid name conflict with the module's own exported function `print_version`.

### swe/rpc.ail
- Import line updated from `(Msg, AgentState)` to `(Msg, AgentState, version)`.
- Both `session_start` emits (in `main()` and `conversation_loop`) include `brainVersion`.
- Used `let bv = version()` before the `jo()` call at both sites — nested `js(version())` inside `kv()` causes AILANG parser errors with `()`.

### tui/src/brain.ts
- `AgentEvent` union's `session_start` variant gains `brainVersion: string`.

### tui/src/index.ts
- Imports `execSync` from `child_process`.
- At startup, calls `ailang run --entry print_version --caps IO swe/version.ail` with `cwd: workdir` and 15s timeout to get the real brain version.
- Falls back to `"unknown"` if the brain is unavailable (ailang not on PATH, etc.).
- Banner now shows: `AILANG Agent TUI v0.1.0 | Brain v0.1.0`.

### tui/src/ui.ts
- `session_start` handler in history pane shows `Brain v0.1.0 | TUI v0.1.0` from the JSONL event data.

## Key gotchas
- `export const VERSION` and `let VERSION` are invalid for cross-module use in AILANG — only `export func` works.
- `js(version())` nested inside `kv()` causes AILANG parser parse errors due to `()` — must bind to a local variable first.

## Verification
- `ailang check swe/types.ail` — passed
- `ailang check swe/rpc.ail` — passed
- `ailang check swe/version.ail` — passed
- `ailang run --entry print_version --caps IO swe/version.ail` — prints `0.1.0`
- `npx tsc --noEmit` — passed
- `npm test` — 15/15 passed
- `npm run build` — succeeded
