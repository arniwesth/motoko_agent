---
doc_type: short
full_text: sources/Generic_MCP_Extension.md
---

## Summary: Generic MCP Extension for Motoko

This design plan proposes a generic [[MCP]] (Model Context Protocol) client library for Motoko, enabling provider-specific extensions to easily call external [[MCP]] tools without duplicating protocol handling.

### Context
Multiple providers (Exa, Brave, Tavily) expose APIs via [[MCP]]'s standardized [[JSON-RPC 2.0]] over HTTP. Instead of building a bespoke extension per provider, a reusable layer centralizes the transport logic.

### Architecture
A two-layer design:
- **Provider extension** (e.g., `exa_search`): configures server URL, auth, tool names, uses the library.
- **Generic MCP layer** (`src/core/ext/mcp/`): implements JSON-RPC requests, SSE parsing, output compression. Not a registered extension itself.

### Key Components
1. **Bridge script** (`scripts/mcp-call.mjs`): A Node.js script with zero dependencies, using built-in `fetch`. Handles auth via environment variables (never via CLI args), supports `query` and `header` auth styles, and parses both plain JSON and SSE responses. Executed by the AILANG layer.
2. **Shared types** (`types.ail`): `McpServerConfig` and `McpToolMapping` for provider configuration and tool name mappings.
3. **Exec wrapper** (`exec.ail`): Builds bridge script arguments, shells out, parses output into `ToolResultEnvelope`. Includes `run_mcp_tool` and `list_mcp_tools`.
4. **Output compression** moved to `motoko_core`: The [[compress_output]] function is extracted from `context_mode` into `src/core/compress.ail` to be shared across extensions.
5. **Tool name resolution** (`resolve.ail`): Utilities to match LLM-provided tool names against canonical names and aliases, and to flatten them for `provided_tools` lists.
6. **Package manifest** (`ailang.toml`): Declares the library with dependencies and allowed effects.

### Design Principles
- API keys stay in environment variables; never passed as CLI args.
- Auth style is explicit (query vs header).
- First SSE `data:` line wins for response parsing.
- Zero npm dependencies for the bridge.
- Exits 0 even on MCP errors; AILANG differentiates via `error` field.

### Integration
Provider extensions import the library, define config and tool mappings, and implement `on_tool_handle` by calling `run_mcp_tool`. Adding a new provider becomes a thin ~100-line AILANG module.

### Testing
Planned: unit tests for name resolution, dry-run mode for the bridge script, live tests with real keys, and compression migration tests.

### Related Concepts
- [[MCP]] (Model Context Protocol)
- [[JSON-RPC 2.0]]
- [[Motoko Extension Architecture]]
- [[Bridge Script Pattern]]
- [[Tool Name Resolution]]
- [[compress_output]]
- [[SSE Parsing]]
- [[MCP Auth Styles]]
- [[Motoko Core Utilities]]