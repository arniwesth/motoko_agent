---
query: "What is the Motoko extension architecture?"
---

Let me also check the foundational extension documents for more depth.Let me grab one more foundational document for the original design vision.## Motoko Extension Architecture

The Motoko extension architecture is a **modular, hook-based framework** for extending agent capabilities without modifying the core runtime. Here are its key components:

### Core Principles

- **Separation of Concerns**: Extensions encapsulate their unique logic (tools, prompts, policies), while generic protocols like MCP communication are handled by reusable layers.
- **Hook-Based Integration**: Every extension exports a `register()` function that returns an `ExtensionHooks` record. This replaced the earlier closed-ADT `PureExt`/`EffectExt` dispatch, which required editing `types.ail`, `registry.ail`, and `runtime.ail` for every new extension.

### ExtensionHooks Interface

Each extension implements these lifecycle hooks:

| Hook | Purpose |
|---|---|
| `on_build_system_prompt` | Injects extension-specific instructions (often from an `AGENT.md` routing card) |
| `on_tool_handle` | Intercepts tool calls, resolves canonical→internal names, executes or delegates |
| `on_tool_policy` | Declares whether the extension blocks or allows certain tools |
| `on_budget_plan` | Modifies the step budget allocation |
| `on_response_intercept` / `on_solver_candidate` | Influences agent behavior mid-loop |

### Dispatch & Conflict Resolution

The runtime folds over all registered hooks. Conflict resolution rules:
- **Tool policy**: **deny wins** over allow/no-op
- **Finalize**: **continue wins**, else first accept, else no decision

This is fail-closed by default, with hook timeouts controlled by `CORE_EXT_HOOK_TIMEOUT_MS`.

### Tool Envelope Pattern

Core and extensions communicate through a **generic tool envelope** (`ToolCallEnvelope` / `ToolResultEnvelope`), defined in `src/core/tool_contract.ail`. This keeps the core parser completely extension-agnostic — it emits envelopes only, never extension-specific ADT constructors. Extensions then normalize, coerce, and execute within their own modules.

### Registry & Activation

- All extensions are declared in `src/core/ext/registry.ail` with a string→register table.
- Activation is via the **`CORE_EXT_ORDER`** environment variable — a comma-separated list of extension names that determines both enablement and ordering.
- Internal instance suffixes (e.g., `#0`) are stripped for user-facing display.

### Package Structure

Extensions are lifted into AILANG packages under `.packages/` (e.g., `motoko_core`, `motoko_compose`, `motoko_omnigraph`), each with:
- `ailang.toml` manifest with `[effects].max` ceiling
- Namespaced imports (`pkg/sunholo/motoko_core/...`)
- Per-extension prompt text in `AGENT.md`

### Anatomy of a Typical Extension (e.g., Exa Search)

| File | Role |
|---|---|
| `exa_search.ail` | `register()` returning `ExtensionHooks`, tool mappings, MCP config |
| `prompts.ail` | Loads `AGENT.md` routing card |
| `AGENT.md` | Tells the LLM when to prefer this extension's tools |
| `types.ail` | Constants and config shapes |
| `ailang.toml` | Package manifest, dependencies, effect ceilings |
| `registry.ail` entry | Wraps the extension for runtime resolution |

### Generic vs. Specific Logic

| Concern | Where |
|---|---|
| JSON-RPC, SSE parsing | MCP bridge scripts |
| Tool name resolution | Generic `mcp/resolve.ail` |
| Shell execution, timeouts | Generic `mcp/exec.ail` |
| Extension-specific URL, auth, tool list | Extension module |
| Prompt instructions | Extension `AGENT.md` |

This architecture ensures extensions are **focused, composable, and independently maintainable** — new capabilities can be added without touching the core runtime's types, parser, or dispatch logic.
