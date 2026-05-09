---
doc_type: short
full_text: sources/Exa_Websearch_Extension.md
---

## Summary

This document proposes an **Exa Websearch Extension** for the Motoko agent framework. It leverages the existing generic MCP (Model Context Protocol) layer to handle all low‑level protocol details, leaving the extension to provide only Exa‑specific configuration, tool name mappings, and an AGENT.md routing card.

### Key Concepts

- **Separation of concerns**: All JSON‑RPC, SSE parsing, and shell bridging stay in the generic [[concepts/MCP]] layer (scripts/mcp-call.mjs and mcp/exec.ail). The extension merely wires these capabilities to Exa’s hosted MCP server.
- **Minimal code footprint**: ~80‑100 lines of AILANG in `exa_search.ail` implement the `register()` hook, importing generic functions for tool resolution (`resolve_tool`) and execution (`run_mcp_tool`).
- **Tool mappings**: A canonical table maps four Exa search primitives (`web_search_exa`, `deep_search_exa`, `get_code_context_exa`, `crawling_exa`) to local tool names like `ExaSearch`, `ExaSearchDeep`, etc., with multiple aliases for LLM flexibility.
- **AGENT.md routing**: A dedicated prompt fragment tells the LLM when to prefer Exa tools over manual curl/wget, ensuring consistent web‑search behavior.
- **Environment‑driven config**: The Exa API key is read from `EXA_API_KEY` (never passed as a CLI argument), with env vars for timeout and output length.

### Integration Points

The extension registers itself via `registry.ail`, adding a new `"exa_search"` module to the core extension order. It hooks into the agent lifecycle (`on_tool_handle` to intercept search calls, `on_build_system_prompt` to inject the AGENT.md content) while remaining neutral on tool policy and budget.

### Activation

Set `CORE_EXT_ORDER=exa_search` and provide `EXA_API_KEY`. The extension can coexist with others like `context_mode`.

### Verification

Tests cover tool mapping lists, registry resolution, an end‑to‑end smoke test using the MCP bridge script, and a final agent integration test.

### Related Concepts
- [[concepts/mcp-protocol-integration]]
- [[concepts/motoko-extension-architecture]]
- [[concepts/tool-selection-bias]]
- [[concepts/handler-routing-architecture]]
- [[concepts/package-sync-mechanism]]
- [[concepts/MCP]] – The generic Model Context Protocol layer that handles transport and protocol logic.
- [[concepts/Motoko extensions]] – How Motoko’s extension architecture supports pluggable tools and hooks.
- [[concepts/Exa search]] – The specific AI‑powered web search capability provided by Exa.
- [[concepts/AGENT.md routing]] – The practice of injecting LLM‑readable routing cards for tool selection.