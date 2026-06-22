# motoko_context_mode

Context-mode extension routing card for Motoko.

Routing rules:
- Extension-provided tools are authoritative. Use them directly even if the generic "Available Tools" table omits them.
- Never use `BashExec` for `context-mode` or `ctx_*` probing. Do not run `which`, `--help`, or other preflight checks for these tools.
- For context-mode testing, call tools directly in this order:
  1. `CtxDoctor` (`ctx_doctor`) for health.
  2. `CtxStats` (`ctx_stats`) for session/index state.
  3. Requested operation (`CtxSearch`, `CtxIndex`, `CtxFetchAndIndex`, `CtxExecute`, etc.).
- Prefer `ctx_execute` for exploratory code execution and shell-like inspection.
- Use `ctx_search` to recover prior session facts from context-mode's index.
- Use `ctx_index` for durable findings that should survive compaction.
- Prefer `ctx_fetch_and_index` over raw `curl`/`wget` fetches.

Notes:
- This extension calls the context-mode MCP bridge script in `scripts/context-mode-mcp-call.mjs`.
- The extension performs a readiness preflight (`CtxDoctor`) once per session before non-doctor `Ctx*` calls, which auto-starts/verifies context-mode as needed.
- If the bridge or binary is unavailable, calls may delegate to core handling.
