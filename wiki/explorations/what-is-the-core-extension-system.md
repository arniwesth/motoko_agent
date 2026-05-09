---
query: "What is the core extension system?"
---

Here's what the wiki reveals about the **core extension system**:

## Overview

The core extension system is Motoko's modular framework for extending agent capabilities. It allows new features (like web search, knowledge graphs, or composition sub-agents) to be added as self-contained modules that hook into the core runtime, rather than being baked into the kernel.

## Architecture

The system is built around four pillars:

### 1. **Hook-Based Integration**
Every extension implements the `ExtensionHooks` interface with lifecycle hooks:
- `on_build_system_prompt` — injects extension-specific instructions
- `on_tool_handle` — intercepts and resolves tool calls
- `on_tool_policy` — states whether the extension blocks/allows certain tools
- `on_budget_plan`, `on_response_intercept`, `on_solver_candidate` — additional influence points

### 2. **Registry**
All extensions are declared in `src/core/ext/registry.ail`. Activation is controlled by the `CORE_EXT_ORDER` environment variable (a comma-separated list). This provides stable ordering; unknown names are ignored; empty sets are supported.

### 3. **Tool Mappings**
Extensions define mappings from **canonical tool names** (used by the LLM) to **internal implementation names**, allowing flexible prompting. Extensions can also include an `AGENT.md` routing card that tells the LLM when to prefer their tools.

### 4. **Conflict Resolution**
When multiple extensions express opinions on the same tool call, the runtime applies clear rules:
- **Tool policy**: deny wins over allow/no-op
- **Finalize**: continue wins, else first accept, else no decision

## Evolution

The system evolved through several phases:

| Phase | What Changed |
|---|---|
| **Phase X1** (2026-04-07) | Introduced the substrate: `ExtCtx`, registry, runtime dispatch, `test_dummy` extension, and RPC loop integration. 21 unit tests passed. |
| **Disentangling** (2026-04-24) | Removed all Omnigraph-specific logic from core. Introduced **generic tool envelopes** (`ToolCallEnvelope` / `ToolResultEnvelope`) as the sole core–extension interface. Core became extension-agnostic. |
| **Compose Extraction** (2026-04-24) | Applied the same pattern to move Compose logic from core to its own extension. |
| **Packageization** (2026-04-24 plan) | Replaced the sealed ADT dispatch (`PureExt` / `EffectExt`) with **hook records** and a `register()` pattern. Each extension becomes an independent AILANG package with its own `ailang.toml`, effect ceilings, and `AGENT.md`. |

## Design Principles

- **Kernel safety**: safety actions (abort, hard caps, tool deny) stay in core; behavior (prompt shaping, verifier invocation) belongs to extensions
- **Fail-closed defaults**: hook timeouts via `CORE_EXT_HOOK_TIMEOUT_MS`
- **Separation of concerns**: generic protocol handling (e.g., MCP JSON-RPC) lives in reusable layers; extensions own only domain-specific logic

Related concepts: [[concepts/motoko-extension-architecture]], [[concepts/mcp-protocol-integration]], [[concepts/generic_tool_envelope]], [[concepts/hook-conflict-resolution]]
