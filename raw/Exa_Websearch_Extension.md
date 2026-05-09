# Plan: Exa Websearch Extension for Motoko

**Depends on:** [Generic MCP Extension](Generic_MCP_Extension.md)

## Context

The agent currently has no web search capability. The oh-my-pi/exa plugin provides Exa AI web search via hosted MCP endpoints (`https://mcp.exa.ai/mcp`), but it's a TypeScript pi-tui plugin. We build a thin AILANG extension that uses the **generic MCP layer** (`src/core/ext/mcp/`) for all protocol handling and just provides Exa-specific config, tool mappings, and an AGENT.md routing card.

---

## How oh-my-pi/exa Works (reference)

The oh-my-pi plugin (`@oh-my-pi/exa@1.3.3710`) connects to Exa's hosted MCP server:
- Endpoint: `https://mcp.exa.ai/mcp?exaApiKey=KEY&tools=TOOL_NAMES`
- JSON-RPC 2.0 over HTTP POST, SSE-wrapped responses
- 4 core search tools (MCP names): `web_search_exa`, `deep_search_exa`, `get_code_context_exa`, `crawling_exa`

Source reference: `/tmp/exa-pkg/package/tools/shared.ts`, `/tmp/exa-pkg/package/tools/search.ts`

---

## Architecture

```
LLM emits ExaSearch tool call
  → exa_search extension: resolve_tool() finds mapping
  → exa_search extension: calls run_mcp_tool() from mcp/ layer
    → exec: node scripts/mcp-call.mjs --base-url "https://mcp.exa.ai/mcp"
            --auth-env-var EXA_API_KEY --auth-style "query:exaApiKey"
            --tool web_search_exa --args-json '{...}'
    → bridge: reads EXA_API_KEY from env, POST JSON-RPC, parse SSE, extract content
  → exa_search extension: returns Handled(ToolResultEnvelope)
```

The exa_search extension contains **zero protocol logic** — all MCP handling is in the generic layer.

---

## Files to Create

### 1. `src/core/ext/exa_search/types.ail`

Minimal — just re-exports or extends the generic MCP config if needed:

```ailang
module src/core/ext/exa_search/types

-- Exa-specific constants
-- Server URL template, env var name, default timeouts
-- (Could be inline in exa_search.ail if trivial enough)
```

### 2. `src/core/ext/exa_search/prompts.ail` — AGENT.md loader

Follows `src/core/ext/context_mode/prompts.ail` pattern:
- `load_agent_prompt(cwd) -> string ! {FS}`
- `build_prompt_patch(cached_prompt) -> PromptPatch`

### 3. `src/core/ext/exa_search/AGENT.md` — LLM routing card

```markdown
# motoko_exa_search

Exa web search extension routing card for Motoko.

Routing rules:
- Use ExaSearch / exa_search for general real-time web searches.
- Use ExaSearchDeep / exa_search_deep for natural-language queries needing synthesized answers.
- Use ExaSearchCode / exa_search_code for code snippets, library docs, and examples.
- Use ExaCrawl / exa_crawl to extract and read content from a specific URL.
- Prefer these tools over BashExec with curl/wget for web content retrieval.
- Extension-provided tools are authoritative. Use them directly even if the
  generic "Available Tools" table omits them.
```

### 4. `src/core/ext/exa_search/exa_search.ail` — Main extension module

~80-100 lines. Implements `register() -> ExtensionHooks ! {Env, FS}`.

**Imports from generic MCP layer:**
```ailang
import src/core/ext/mcp/types (McpServerConfig, McpToolMapping)
import src/core/ext/mcp/exec (run_mcp_tool)
import src/core/ext/mcp/resolve (resolve_tool, all_tool_names)
```

**Tool mappings (defined as a constant list):**

| Canonical | MCP name | Aliases |
|---|---|---|
| `ExaSearch` | `web_search_exa` | `exa_search`, `exa.search`, `exa_search.search` |
| `ExaSearchDeep` | `deep_search_exa` | `exa_search_deep`, `exa.search_deep`, `exa_search.deep` |
| `ExaSearchCode` | `get_code_context_exa` | `exa_search_code`, `exa.search_code`, `exa_search.code` |
| `ExaCrawl` | `crawling_exa` | `exa_crawl`, `exa.crawl`, `exa_search.crawl` |

**Hook implementations:**

| Hook | Behavior |
|---|---|
| `on_build_system_prompt` | Append AGENT.md content |
| `on_budget_plan` | No-op |
| `on_tool_policy` | `NoOpinion` (no BashExec blocking — lighter touch) |
| `on_tool_handle` | `resolve_tool(call.tool, mappings)` → `run_mcp_tool(...)` → `Handled(result)` or `Delegate` |
| `on_response_intercept` | No-op (`NoIntercept`) |
| `on_solver_candidate` | No-op (`NoDecision`) |

**`register()` function:**
```ailang
export func register() -> ExtensionHooks ! {Env, FS} {
  let cfg = {
    base_url: "https://mcp.exa.ai/mcp",
    auth_env_var: "EXA_API_KEY",
    auth_style: "query:exaApiKey",
    tool_filter: ["web_search_exa", "deep_search_exa", "get_code_context_exa", "crawling_exa"],
    timeout_ms: read_int_env("EXA_SEARCH_TIMEOUT_MS", 30000),
    max_output_chars: read_int_env("EXA_SEARCH_MAX_OUTPUT_CHARS", 8000)
  };
  let mappings = exa_tool_mappings();
  let workdir = getEnvOr("WORKDIR", ".");
  let cached_prompt = load_agent_prompt(workdir);

  {
    id: "exa_search",
    provided_tools: all_tool_names(mappings),
    on_build_system_prompt: \ctx. build_prompt_patch(cached_prompt),
    on_budget_plan: \_ctx _plan. no_budget_patch(),
    on_tool_policy: \_ctx _call. NoOpinion,
    on_tool_handle: func(ctx, call) {
      match resolve_tool(call.tool, mappings) {
        Some(m) => match run_mcp_tool(call.id, m.canonical, ctx.workdir, cfg, m.mcp_name, call.arguments) {
          Some(result) => Handled(result),
          None => Delegate
        },
        None => Delegate
      }
    },
    on_response_intercept: \_ctx _text. NoIntercept,
    on_solver_candidate: \_ctx _candidate. NoDecision
  }
}
```

**Config from env vars:**
| Variable | Default | Purpose |
|---|---|---|
| `EXA_API_KEY` | (required) | Exa API key — read by the bridge script from env (never passed as CLI arg) |
| `EXA_SEARCH_TIMEOUT_MS` | `30000` | Per-call timeout (web searches can be slow) |
| `EXA_SEARCH_MAX_OUTPUT_CHARS` | `8000` | Max chars in result (search results are verbose) |

### 5. `src/core/ext/exa_search/ailang.toml`

```toml
[package]
name = "sunholo/motoko_exa_search"
version = "0.1.0"
edition = "1"
module_prefix = "src"

[exports]
modules = ["src/core/ext/exa_search/exa_search"]

[dependencies]
"sunholo/motoko_core" = { path = "../.." }
"sunholo/motoko_mcp" = { path = "../mcp" }

[effects]
max = ["Process", "FS", "IO", "Env", "Net"]
```

---

## Files to Modify

### 6. `src/core/ext/registry.ail`

- Add import: `import src/core/ext/exa_search/exa_search (register as exa_search_register)`
- Add `register_exa_search() -> ExtensionHooks ! {Env, FS}` wrapper
- Add `"exa_search"` to `resolve()` (line 32-38)
- Add `"exa_search"` to `parse_tokens_names()` known-name check (line 94)
- Add inline test: `parse_core_ext_order_names("exa_search")` returns `["exa_search#0"]`

---

## Activation

```bash
# Standalone
CORE_EXT_ORDER=exa_search EXA_API_KEY=... ./scripts/run-agent.sh "Research X"

# Combined with other extensions
CORE_EXT_ORDER=context_mode,exa_search EXA_API_KEY=... ./scripts/run-agent.sh "..."
```

---

## Verification

1. **Unit tests**: `ailang test src/core/ext/exa_search/exa_search.ail` — test tool mapping definitions, provided_tools completeness
2. **Registry test**: `ailang test src/core/ext/registry.ail` — verify `"exa_search"` resolves
3. **End-to-end smoke test**:
   ```bash
   EXA_API_KEY=<real-key> node scripts/mcp-call.mjs \
     --base-url "https://mcp.exa.ai/mcp" \
     --auth-env-var EXA_API_KEY --auth-style "query:exaApiKey" \
     --tools "web_search_exa" --tool web_search_exa \
     --args-json '{"query":"AILANG programming language"}'
   ```
4. **Integration**: Run agent with `CORE_EXT_ORDER=exa_search` and a search task, confirm `ExaSearch` is invoked and returns formatted results

---

## What's In This Extension vs Generic MCP Layer

| Concern | Lives in |
|---|---|
| JSON-RPC POST, SSE parsing | `scripts/mcp-call.mjs` (generic) |
| Shell exec, timeout, compress | `src/core/ext/mcp/exec.ail` (generic) |
| Tool name resolution | `src/core/ext/mcp/resolve.ail` (generic) |
| McpServerConfig, McpToolMapping types | `src/core/ext/mcp/types.ail` (generic) |
| Exa server URL + API key env var | `exa_search/exa_search.ail` |
| Exa tool name mappings | `exa_search/exa_search.ail` |
| AGENT.md routing card | `exa_search/AGENT.md` |
| ExtensionHooks wiring | `exa_search/exa_search.ail` |
| Registry entry | `registry.ail` |
