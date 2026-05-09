# 2026-04-03 — AILANG version in startup header

## Goal
The startup banner and history pane already showed TUI and Brain versions. The user wanted the AILANG runtime version displayed too, completing the version trinity.

## Final design
- **AILANG built datetime** — queried at TUI startup from `ailang --version` by parsing the `Built: 2026-04-03_10:56:34` line. The binary prints `AILANG dev` because it wasn't built with version ldflags, and the fork has no git tags for `git describe --tags` to produce a semver string.
- **Banner** — shows `AILANG Agent (AILANG built 2026-04-03_10:56:34) TUI v0.1.0 | Brain v0.1.0`.
- **History pane** — each `session_start` event shows `AILANG built 2026-04-03_10:56:34 | Brain v0.1.0 | TUI v0.1.0`.
- **Passthrough** — TUI passes the built datetime to the brain via `AILANG_BUILT` env var; the brain reads it and emits `ailangBuilt` in the JSONL `session_start` event so the history pane can render it from event data (preserving the pattern established for brain version).

## Changes

### tui/src/index.ts
- Parses `Built:  YYYY-MM-DD_HH:MM:SS` from the multiline output of `ailang --version` using a regex: `/^Built:\s+(.*)$/m`.
- Falls back to `"unknown"` if the binary is unavailable.
- Sets `process.env.AILANG_BUILT` before spawning the brain.
- Passes `ailangVersion` to the `AgentUI` constructor for the banner.

### tui/src/brain.ts
- `AgentEvent` union's `session_start` variant gains `ailangBuilt: string` field.

### tui/src/ui.ts
- Constructor accepts optional `ailangVersion` in its options param.
- `session_start` handler displays `AILANG built ${event.ailangBuilt} | Brain v${event.brainVersion} | TUI v${this.version}` instead of the previous `Brain v... | TUI v...` line.

### swe/rpc.ail
- Added `AILANG_BUILT` env var read via `getEnvOr("AILANG_BUILT", "unknown")` in both `main()` and `conversation_loop()`.
- Both `session_start` emits include `kv("ailangBuilt", js(ailang_built))`.
- Used `let ailang_built = ...` before the `jo()` call at both sites — same gotcha as brain version: nested `js(...)` inside `kv()` causes AILANG parser errors.

### swe/types.ail, swe/version.ail
- No changes — carried over from the brain version work.

## Key gotchas
- `ailang --version` prints `AILANG dev` when the binary is built without `-ldflags` version injection. The `Built:` line is the only stable runtime identity available in this case.
- `js(expr())` nested inside `kv()` — AILANG parser chokes on the `()` inside the nested call. Must bind to a local variable first.
- The TUI-to-brain passthrough pattern (env var → brain reads → emits in event) mirrors the brain version approach, keeping the architecture consistent.

## Verification
- `ailang check swe/rpc.ail` — passed
- `npx tsc --noEmit` — passed
- `npm test` — 15/15 passed
