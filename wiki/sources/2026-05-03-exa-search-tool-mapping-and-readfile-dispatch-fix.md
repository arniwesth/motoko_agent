# Exa Search Tool Mapping and ReadFile Dispatch Fix

## Problem 1: Exa search extension always fails

User reported the exa search extension does not work. Session log at
`.motoko/logfile/session_2026-05-03T18-01-10-751Z.md` showed `ReadFile` was failing
with `missing exec.cmd` (see Problem 2), but the underlying exa search issue was
three of four tool mappings targeting MCP tool names that don't exist on the Exa
MCP server.

### Root cause

The Exa MCP server at `https://mcp.exa.ai/mcp` exposes exactly two tools:

- `web_search_exa` — web search
- `web_fetch_exa` — fetch webpage content

`src/core/ext/exa_search/types.ail` mapped four tools:

| Canonical      | MCP name               | Exists on server? |
|----------------|------------------------|--------------------|
| ExaSearch      | web_search_exa         | Yes                |
| ExaSearchDeep  | deep_search_exa        | **No**             |
| ExaSearchCode  | get_code_context_exa   | **No**             |
| ExaCrawl       | crawling_exa           | **No**             |

The `tool_filter()` also passed all four names to the MCP server as a query
parameter, which the server ignores (requests still reach the valid endpoints).

### Fix

**`src/core/ext/exa_search/types.ail`:**
- `tool_filter()` reduced to `["web_search_exa", "web_fetch_exa"]`
- `tool_mappings()` reduced to three entries:
  - `ExaSearch` → `web_search_exa` (unchanged)
  - `ExaFetch` → `web_fetch_exa` (new, with aliases `exa_fetch`, `exa.fetch`,
    `exa_search.fetch`)
  - `ExaCrawl` → `web_fetch_exa` (now routes to the correct existing tool,
    preserving backward compatibility)

**`src/core/ext/exa_search/exa_search.ail`:**
- Test cases updated: expected name count 16→12, alias resolution test changed
  from `exa.search_deep` to `exa.fetch`.

**`src/core/ext/exa_search/AGENT.md`:**
- Removed references to non-existent tools (`ExaSearchDeep`, `ExaSearchCode`)
- Added `ExaFetch` routing rule
- Documented parameter names (`query`/`numResults` camelCase for search,
  `urls`/`maxCharacters` for fetch) to prevent LLM from using snake_case
  arguments.

### Verification

- All 3 exa_search tests pass (`ailang test src/core/ext/exa_search/exa_search.ail`)
- All 6 ext modules type-check clean
- End-to-end `mcp-call.mjs` → Exa MCP returns valid search results

---

## Problem 2: ReadFile tool calls fail with "missing exec.cmd"

Session log `.motoko/logfile/session_2026-05-03T18-04-53-149Z.md` showed
`ReadFile` tool calls returning:

```
stderr: "missing exec.cmd"
exit_code: 1
```

### Root cause

In `src/tui/src/runtime-process.ts`, `handleToolCalls` gated dispatching
`ReadFile`/`WriteFile`/`EditFile`/`Search` through the OhMyPi dispatcher behind
the `OHMY_PI_TOOLS` env var (defaults to `"0"` / `false` via `tools.ohmy_pi`
config key).

When `OHMY_PI_TOOLS` is not `"1"`, these tools fall through to
`runDelegatedCall`, which calls `resolveDelegatedExec` — a function that
extracts `exec: { cmd, args, ... }` from the tool call. `ReadFile` has `path`,
not `exec.cmd`, so `resolveDelegatedExec` returns `null` and the error
`"missing exec.cmd"` is returned.

### Fix

**`src/tui/src/runtime-process.ts`:**

Removed the `OHMY_PI_TOOLS` condition from `handleToolCalls`. The OhMyPi
dispatcher now unconditionally handles `ReadFile`, `WriteFile`, `EditFile`, and
`Search`. These tools have no `exec.cmd` field and cannot be handled by
`runDelegatedCall`.

Also removed the dead `ohMyPiToolsEnabled` class field (no longer read).

The `OHMY_PI_TOOLS` env var and `tools.ohmy_pi` config key remain in place for
future use (e.g., controlling tool advertisement to the LLM).

### Verification

- `bun build` compiles cleanly
- TUI test suite has a pre-existing Jest/Bun compatibility issue in this
  environment (all 18 suites fail with `TypeError: Attempted to assign to
  readonly property` in `stack-utils`) — unrelated to this change
