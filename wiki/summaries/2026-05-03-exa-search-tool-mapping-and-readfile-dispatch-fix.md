---
doc_type: short
full_text: sources/2026-05-03-exa-search-tool-mapping-and-readfile-dispatch-fix.md
---

# Exa Search Tool Mapping and ReadFile Dispatch Fixes

This document describes two fixes: one for Exa search extension tool mapping against the actual MCP server, and one for ReadFile/WriteFile tool dispatch in the TUI runtime.

## Problem 1: Exa Search Tool Mapping

- **Issue**: The Exa search extension mapped three of four canonical tools to MCP tool names that did not exist on the Exa MCP server (`deep_search_exa`, `get_code_context_exa`, `crawling_exa`), causing failures.
- **Root cause**: The server at `https://mcp.exa.ai/mcp` only exposes `web_search_exa` and `web_fetch_exa`. The `tool_filter()` also sent invalid names, ignored by the server.
- **Fix in `src/core/ext/exa_search/types.ail`**:
  - Reduced `tool_filter()` to the two valid names.
  - `tool_mappings()` now maps `ExaSearch` → `web_search_exa`, `ExaFetch` → `web_fetch_exa`, and `ExaCrawl` → `web_fetch_exa` for backward compatibility.
- **Fix in `src/core/ext/exa_search/exa_search.ail`**: Updated test cases.
- **Fix in `src/core/ext/exa_search/AGENT.md`**: Removed references to non-existent tools; documented camelCase parameter names.
- **Verification**: All tests pass, type-check clean, end-to-end call succeeds.

This demonstrates the importance of aligning internal tool catalogues with the actual MCP server capabilities. See [[concepts/exa_mcp_tool_mapping]] for broader patterns in MCP tool integration.

## Problem 2: ReadFile Dispatch Failure

- **Issue**: `ReadFile` (and `WriteFile`, `EditFile`, `Search`) tool calls returned `"missing exec.cmd"`.
- **Root cause**: In `src/tui/src/runtime-process.ts`, `handleToolCalls` gated dispatch of these file tools behind the `OHMY_PI_TOOLS` environment variable (default off). When disabled, calls fell to `runDelegatedCall` → `resolveDelegatedExec`, which expected an `exec.cmd` field not present in `ReadFile`.
- **Fix**: Removed the `OHMY_PI_TOOLS` condition; the OhMyPi dispatcher now unconditionally handles `ReadFile`, `WriteFile`, `EditFile`, and `Search`. The env var and config key remain for future use (e.g., advertising tools). Also removed dead `ohMyPiToolsEnabled` field.
- **Verification**: `bun build` compiles cleanly; pre-existing Jest/Bun test issue unrelated.

This highlights the need for consistent tool dispatch logic—tools without an `exec` model must bypass delegated execution. See [[concepts/tool_dispatch_runtime_process]] for dispatch architecture patterns.

Both fixes improve reliability of tool invocation in the personal knowledge base assistant.