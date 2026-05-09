---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md, summaries/Exa_Websearch_Extension.md]
brief: The modular framework for extending Motoko agents via hooks, tool mappings, and registry integration.
---

# Motoko Extension Architecture

The Motoko extension architecture provides a standardized way to add new capabilities to the agent. Each extension is a self-contained module that implements a set of lifecycle hooks, defines its provided tools with name mappings, and registers in a central registry.

## Core Principles

- **Separation of Concerns**: Extensions focus on their unique logic (tools, prompts, policies), while generic protocol handling, such as [[concepts/MCP]] communication, is delegated to reusable layers.
- **Hook-Based Integration**: Every extension implements the `ExtensionHooks` interface, which includes:
  - `on_build_system_prompt`: Adds extension-specific instructions (often loaded from an `AGENT.md` routing card).
  - `on_tool_handle`: Intercepts tool calls, resolves them to internal names, and performs the action (or delegates).
  - `on_tool_policy`: States whether the extension blocks or allows certain tools.
  - `on_budget_plan`, `on_response_intercept`, `on_solver_candidate`: Other hooks that can influence agent behavior.
- **Tool Mappings**: Extensions define a mapping from **canonical tool names** used by the LLM to **internal implementation names** (e.g., MCP tool names). Aliases allow flexible prompting.
- **Registry**: All extensions are declared in `src/core/ext/registry.ail`, which provides a function to resolve extensions by name. Adding a new extension requires importing it, wrapping its `register()` in a registry-callable function, and listing its name in known‑name checks and tests.

## Anatomy of an Extension (Based on Exa Example)

The [[summaries/Exa_Websearch_Extension]] illustrates a typical extension structure:

- **Module file** (`exa_search.ail`): Contains the `register()` function that returns an `ExtensionHooks` record. It imports generic MCP utilities (`run_mcp_tool`, `resolve_tool`) and defines the tool mapping constant.
- **Prompts file** (`prompts.ail`): Loads the `AGENT.md` routing card and prepares a prompt patch.
- **AGENT.md**: A Markdown prompt card that tells the LLM when to prefer the extension’s tools over default methods.
- **Type definitions** (`types.ail`): Optional file for constants and configuration shape.
- **Manifest** (`ailang.toml`): Declares the package, its dependencies, and allowed effects.
- **Registry integration**: Imports and wraps the extension in `registry.ail`.

The extension’s `register()` function:
1. Builds the MCP server configuration (base URL, auth style, timeout) from environment variables.
2. Defines the tool mappings (list of canonical names, MCP names, and aliases).
3. Returns the hooks, where `on_tool_handle` uses `resolve_tool` to match the incoming call and `run_mcp_tool` to execute it via a generic bridge script.

## Generic vs. Specific Logic

| Concern | Where It Lives |
|---|---|
| JSON-RPC protocol, SSE parsing | [[concepts/MCP]] bridges (scripts) |
| Tool name resolution | Generic `mcp/resolve.ail` |
| Shell execution, timeouts | Generic `mcp/exec.ail` |
| Exa-specific URL, auth, tool list | Exa extension module |
| Prompt instructions | Exa extension `AGENT.md` |
| Registry entry | `registry.ail` |

## Activation

Extensions are activated by setting the `CORE_EXT_ORDER` environment variable to a comma-separated list. For example, to activate the Exa search extension alone:
```bash
CORE_EXT_ORDER=exa_search EXA_API_KEY=... ./scripts/run-agent.sh "query"
```

## See Also

- [[concepts/AGENT.md routing]] – How prompt cards guide tool selection.
- [[concepts/MCP]] – The generic Model Context Protocol layer used by many extensions.
- [[summaries/Exa_Websearch_Extension]] – Full implementation plan for the Exa extension.

This architecture ensures extensions are focused, composable, and easy to maintain.

See also: [[summaries/2026-04-26-abort-history-and-omnigraph-delete]]