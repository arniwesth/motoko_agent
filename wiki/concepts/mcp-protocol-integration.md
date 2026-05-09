---
sources: [summaries/Exa_Websearch_Extension.md]
brief: A design pattern where a generic MCP handling layer abstracts transport and protocol details from specific tool extensions.
---

# MCP Protocol Integration

**MCP Protocol Integration** is a design pattern within the Motoko extension system that separates generic Model Context Protocol (MCP) transport logic from domain‑specific tool extensions. A thin, reusable MCP layer handles JSON‑RPC 2.0 over HTTP POST, Server‑Sent Events (SSE) parsing, authentication, timeouts, and output truncation. Extensions like [[summaries/Exa_Websearch_Extension]] then only declare server endpoints, tool name mappings, and environment‑variable configurations – they contain **zero protocol logic**.

## How It Works

- The core MCP module provides types (`McpServerConfig`, `McpToolMapping`), a resolver (`resolve_tool`), and a runner (`run_mcp_tool`) that invokes a bridge script (`scripts/mcp-call.mjs`).
- `run_mcp_tool` receives a server configuration with `base_url`, `auth_env_var`, `auth_style`, and `tool_filter`, plus the tool arguments, and returns a `ToolResultEnvelope` or `None`.
- The bridge script reads the API key from the environment (never exposed in command lines), performs the HTTP call, parses the SSE stream, and writes the result to a temporary file that the AILANG process reads back.
- Extensions supply only:
  - `base_url` – the MCP server endpoint (e.g., `https://mcp.exa.ai/mcp`).
  - `auth_style` – how the API key is transmitted (e.g., `query:exaApiKey`).
  - `tool_filter` – a list of MCP tool names the extension will expose.
  - Timeout and size limits via environment variables.

## Benefits

1. **Reduced duplication** – every new MCP‑speaking tool reuses the same transport layer.
2. **Security** – API keys remain in the process environment, not in logs or command lines.
3. **Testability** – the bridge script can be validated independently of any extension.
4. **Simplicity** – extension authors focus on tool semantics, not protocol plumbing.

## Relationship to Extensions

Extensions like `exa_search` call `resolve_tool(call.tool, mappings)` to map an LLM‑requested tool name to an MCP server name, then pass the call to `run_mcp_tool`. This keeps the extension’s hook implementation trivial, often just a few lines.

## See Also
- [[summaries/Exa_Websearch_Extension]] – a concrete consumer that uses this pattern for Exa AI web search.
- [[concepts/Motoko extensions]] – how extension hooks enable tool registration and interception.
- [[concepts/AGENT.md routing]] – how LLMs are guided to prefer MCP‑powered tools over manual commands.