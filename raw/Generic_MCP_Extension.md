# Plan: Generic MCP Extension for Motoko

## Context

Multiple external tool providers (Exa, Brave Search, Tavily, etc.) expose their APIs via the Model Context Protocol (MCP) — a standardized JSON-RPC 2.0 protocol over HTTP. Rather than building a bespoke extension per provider, we build a **generic MCP client layer** that any provider-specific extension can import. This eliminates duplicated protocol handling and makes adding new MCP-backed tools a thin-config exercise.

The MCP HTTP transport is identical across providers:
1. POST JSON-RPC `{"jsonrpc":"2.0","method":"tools/call","params":{"name":"...","arguments":{...}},"id":1}` to a server URL
2. Parse response — either plain JSON or SSE-wrapped (`data: {...}` lines)
3. Extract `result.content[].text` from the response envelope

---

## Architecture

Two layers:

```
┌─────────────────────────────────────────────────────┐
│  Provider extension (e.g. exa_search)               │
│  - Tool name mapping (canonical ↔ MCP names)        │
│  - AGENT.md routing card                            │
│  - Provider-specific config (URL, auth env var)     │
│  - ExtensionHooks implementation                    │
│  - Imports mcp/ for exec + result handling          │
└────────────────────┬────────────────────────────────┘
                     │ calls
┌────────────────────▼────────────────────────────────┐
│  Generic MCP layer (src/core/ext/mcp/)              │
│  - AILANG: types, exec wrapper, output parsing      │
│  - Node.js: scripts/mcp-call.mjs bridge script      │
│  - Shared: compress, timeout, ToolResultEnvelope    │
└─────────────────────────────────────────────────────┘
```

The generic layer is **not** a registered extension itself — it has no `ExtensionHooks` and no entry in `registry.ail`. It's a library that provider extensions import.

---

## Files to Create

### 1. `scripts/mcp-call.mjs` — Generic MCP bridge script

Node.js script (~150 lines), zero npm dependencies (uses built-in `fetch`).

**CLI interface:**
```bash
node scripts/mcp-call.mjs \
  --base-url "https://mcp.exa.ai/mcp" \
  --auth-env-var "EXA_API_KEY" \
  --auth-style "query:exaApiKey" \
  --tools "web_search_exa,deep_search_exa" \
  --tool "web_search_exa" \
  --args-json '{"query":"hello"}'
```

**Arguments:**
| Flag | Required | Description |
|---|---|---|
| `--base-url` | yes | MCP server endpoint (no auth params) |
| `--auth-env-var` | yes | Name of env var containing the API key (bridge reads it via `process.env`) |
| `--auth-style` | yes | How to pass auth: `query:<param>` (appends `?param=KEY`) or `header:Bearer` (sends `Authorization: Bearer KEY`) |
| `--tools` | no | Comma-separated MCP tool names to include as `tools=` query param (provider-specific) |
| `--tool` | yes | MCP tool name to invoke |
| `--args-json` | yes | JSON string of tool arguments |
| `--method` | no | JSON-RPC method, default `tools/call`. Pass `tools/list` for discovery. |
| `--timeout-ms` | no | HTTP fetch timeout, default `30000` |

**Responsibilities:**
- Read API key from the env var named by `--auth-env-var` (never passed as a CLI arg — avoids leaking secrets into `ps aux` / `/proc/*/cmdline`)
- Construct the final URL from `--base-url` + auth params per `--auth-style` + optional `--tools` query param
- POST JSON-RPC 2.0 request with headers `Content-Type: application/json`, `Accept: application/json, text/event-stream`
- Parse response body: take the **first** `data:` line if SSE-formatted (matches oh-my-pi behavior), fall back to plain JSON
- On `tools/call`: extract `result.content[].text`, join all text entries, output `{"output": "<text>"}`
- On `tools/list`: output `{"output": "<json array of tool definitions>"}`
- On MCP `error`: output `{"error": "<message>"}`
- On HTTP/network failure: output `{"error": "<message>"}` and exit 0 (let AILANG handle)

**Key design decisions:**
- **API keys stay in env vars.** The bridge reads `process.env[authEnvVar]` — the AILANG side never handles raw secrets, and they don't appear in process argument lists.
- **Auth style is explicit.** `query:<param>` vs `header:Bearer` covers the two common MCP auth patterns without baking in provider-specific URL templates.
- **First SSE `data:` line wins.** Some MCP servers may stream multiple events; we match oh-my-pi's behavior of taking the first. This is adequate for all known providers.
- Output is always a single JSON line to stdout, matching context_mode's bridge pattern.
- Exit code 0 even on MCP errors — the AILANG layer distinguishes via the `error` field. Non-zero exit only for truly unexpected failures (missing Node.js, etc.).
- **`--args-json` via CLI is fine for now** — MCP tool arguments are typically small (search queries, URLs). If a provider needs large payloads, a future `--args-stdin` flag can be added without breaking existing callers.

**Reference:** oh-my-pi/exa `shared.ts` lines 127-253 for the protocol handling.

### 2. `src/core/ext/mcp/types.ail` — Shared MCP types

```ailang
module src/core/ext/mcp/types

export type McpServerConfig = {
  base_url: string,         -- MCP endpoint, e.g. "https://mcp.exa.ai/mcp"
  auth_env_var: string,     -- env var name for API key, e.g. "EXA_API_KEY"
  auth_style: string,       -- "query:exaApiKey" or "header:Bearer"
  tool_filter: [string],    -- MCP tool names for --tools param, e.g. ["web_search_exa", "deep_search_exa"]
  timeout_ms: int,
  max_output_chars: int
}

export type McpToolMapping = {
  canonical: string,      -- e.g. "ExaSearch"
  mcp_name: string,       -- e.g. "web_search_exa"
  aliases: [string]       -- e.g. ["exa_search", "exa.search"]
}
```

### 3. `src/core/ext/mcp/exec.ail` — Generic MCP exec wrapper

Builds on context_mode's exec pattern but generalized:

```ailang
module src/core/ext/mcp/exec

-- Build CLI args for mcp-call.mjs from config
export func bridge_args(workdir: string, cfg: McpServerConfig, mcp_tool_name: string, args_json: string) -> [string]
  -- Returns: ["<workdir>/scripts/mcp-call.mjs", "--base-url", cfg.base_url,
  --           "--auth-env-var", cfg.auth_env_var, "--auth-style", cfg.auth_style,
  --           "--tools", join(",", cfg.tool_filter),
  --           "--tool", mcp_tool_name, "--args-json", args_json]

-- Execute bridge script, parse output, return ToolResultEnvelope
export func run_mcp_tool(
  id: string,           -- tool_call_id
  canonical: string,    -- canonical tool name for the envelope
  workdir: string,
  cfg: McpServerConfig,
  mcp_tool_name: string,
  args: Json
) -> Option[ToolResultEnvelope] ! {Process}

-- List available tools from MCP server (uses --method tools/list)
export func list_mcp_tools(
  workdir: string,
  cfg: McpServerConfig
) -> Option[string] ! {Process}
```

Internally:
- Shells out via `exec("bash", build_shell_argv("node", bridge_args(...), cwd, cfg.timeout_ms))`
- Reuses the same shell wrapper pattern as context_mode (timeout via `timeout` command, `set -eu`)
- Parses stdout JSON: if `error` key present, wraps as error envelope; if `output` key, uses as stdout
- Applies `compress_output` (imported from `motoko_core`) to truncate verbose results
- `list_mcp_tools` passes `--method tools/list` and returns the raw JSON output; useful for dynamic tool discovery

**Dropped:** `run_mcp_fire_and_forget` — MCP tool calls are request/response; no known use case for fire-and-forget. Can be added later if a provider needs it.

### 4. Extract `compress_output` to `motoko_core`

The `compress_output` function (strip ANSI, collapse repeated lines, truncate) is currently in `src/core/ext/context_mode/compress.ail`. It's general-purpose subprocess output cleanup — not specific to context-mode or MCP. Both layers need it, and future extensions that shell out will too.

**Action:** Move `compress_output` and its helpers (~70 lines) to `motoko_core`:
- New file: `src/core/compress.ail` (module `src/core/compress`)
- Export: `compress_output(text: string, max_chars: int) -> string`
- Add to `motoko_core`'s `ailang.toml` exports

**Then update imports:**
- `src/core/ext/context_mode/exec.ail`: change `import src/core/ext/context_mode/compress` → `import src/core/compress`
- `src/core/ext/mcp/exec.ail`: `import src/core/compress (compress_output)`

This avoids: (a) mcp depending on context_mode (wrong dependency direction), (b) duplicating code that would drift out of sync.

### 5. `src/core/ext/mcp/resolve.ail` — Tool name resolution helpers

```ailang
module src/core/ext/mcp/resolve

-- Given a raw tool name from an LLM call and a list of McpToolMappings,
-- find the matching mapping (checks canonical + all aliases)
export func resolve_tool(raw: string, mappings: [McpToolMapping]) -> Option[McpToolMapping]

-- Build the flat provided_tools list from all mappings
-- (canonical + all aliases for each mapping)
export func all_tool_names(mappings: [McpToolMapping]) -> [string]
```

This eliminates the repetitive `canonical_tool_name` if/else chains that each extension would otherwise need.

### 6. `src/core/ext/mcp/ailang.toml` — Package manifest

```toml
[package]
name = "sunholo/motoko_mcp"
version = "0.1.0"
edition = "1"
module_prefix = "src"

[exports]
modules = [
  "src/core/ext/mcp/types",
  "src/core/ext/mcp/exec",
  "src/core/ext/mcp/resolve"
]

[dependencies]
"sunholo/motoko_core" = { path = "../.." }

[effects]
max = ["Process", "Env", "IO"]
```

---

## What This Layer Does NOT Do

- **No ExtensionHooks** — the generic layer is a library, not a registered extension
- **No AGENT.md** — each provider extension writes its own routing card
- **No tool policy decisions** — provider extensions decide their own Allow/Deny/NoOpinion
- **No API key management** — the bridge script reads the key from the env var named in config; the AILANG side never touches raw secrets
- **No registry entry** — `CORE_EXT_ORDER` never includes `mcp`; only provider extensions like `exa_search` appear there

---

## How a Provider Extension Uses This

A provider extension (e.g. `exa_search`) does:

```ailang
import src/core/ext/mcp/types (McpServerConfig, McpToolMapping)
import src/core/ext/mcp/exec (run_mcp_tool)
import src/core/ext/mcp/resolve (resolve_tool, all_tool_names)

-- At register() time:
let cfg = {
  base_url: "https://mcp.exa.ai/mcp",
  auth_env_var: "EXA_API_KEY",
  auth_style: "query:exaApiKey",
  tool_filter: ["web_search_exa", "deep_search_exa", "get_code_context_exa", "crawling_exa"],
  timeout_ms: 30000,
  max_output_chars: 8000
};
let mappings = [
  { canonical: "ExaSearch", mcp_name: "web_search_exa", aliases: ["exa_search", "exa.search"] },
  ...
];

-- In on_tool_handle:
match resolve_tool(call.tool, mappings) {
  Some(m) => match run_mcp_tool(call.id, m.canonical, ctx.workdir, cfg, m.mcp_name, call.arguments) {
    Some(result) => Handled(result),
    None => Delegate
  },
  None => Delegate
}
```

---

## Verification

1. **Unit tests** in `src/core/ext/mcp/resolve.ail`: test `resolve_tool` matching canonical, alias, case-insensitive, and miss cases; test `all_tool_names` flattening
2. **Bridge script dry-run test**: Add a `--dry-run` flag to `mcp-call.mjs` that outputs the request it would send as JSON (URL, method, headers, body) without making a network call. This enables deterministic testing:
   ```bash
   node scripts/mcp-call.mjs --base-url "https://mcp.exa.ai/mcp" --auth-env-var EXA_API_KEY \
     --auth-style "query:exaApiKey" --tool web_search_exa --args-json '{"query":"test"}' --dry-run
   ```
3. **Bridge script live test** (requires API key):
   ```bash
   EXA_API_KEY=<key> node scripts/mcp-call.mjs --base-url "https://mcp.exa.ai/mcp" \
     --auth-env-var EXA_API_KEY --auth-style "query:exaApiKey" \
     --tools "web_search_exa" --tool web_search_exa --args-json '{"query":"hello world"}'
   ```
4. **compress_output migration**: `ailang test src/core/compress.ail` passes (existing tests move with the code), and `ailang test src/core/ext/context_mode/compress.ail` is removed
5. **Integration**: tested via the exa_search extension (see Exa plan)

---

## Future Providers

Adding a new MCP-backed provider (e.g. Brave Search) requires:
1. A thin `src/core/ext/brave_search/` with config + tool mappings + AGENT.md (~100 lines AILANG)
2. One line in `registry.ail` to register it
3. No changes to `scripts/mcp-call.mjs` or `src/core/ext/mcp/`
