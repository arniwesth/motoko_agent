---
query: "What is the Motoko core extension system?"
---

Let me look at the central concept page and the core implementation summaries.Let me also read the disentangling and packageize sessions, plus the extension disentangling plan.# Motoko Core Extension System

The Motoko core extension system is a **modular, hook-based framework** that allows new capabilities to be added to the Motoko agent without modifying the core runtime. It evolved through several phases: initial substrate (Phase X1), disentangling from core, and full packageization.

## Architecture

### Hook-based integration
Every extension implements an **`ExtensionHooks`** record with lifecycle hooks:

| Hook | Purpose |
|---|---|
| `on_build_system_prompt` | Injects extension-specific instructions into the system prompt |
| `on_tool_handle` | Intercepts and resolves tool calls to internal implementation |
| `on_tool_policy` | Declares whether the extension allows, blocks, or is neutral on a tool |
| `on_budget_plan` | Adjusts token/step budgets |
| `on_solver_candidate` | Reviews solver outputs for early acceptance or feedback |
| `on_response_intercept` | Modifies responses before delivery |

Each extension exports a `register()` function that returns its hooks. See [[concepts/motoko-extension-architecture]].

### Registry and activation
Extensions are declared in `src/core/ext/registry.ail` and activated at runtime via the **`CORE_EXT_ORDER`** environment variable — a comma-separated list that controls both which extensions load and their ordering. Unknown names are silently ignored.

### Conflict resolution
- **Tool policy**: **deny wins** — if any extension denies a tool, it's blocked.
- **Finalize**: **continue wins** over accept, and first accept is used if no continue is signaled.
- All hooks are fail-closed with configurable timeouts (`CORE_EXT_HOOK_TIMEOUT_MS`).

## Key design decisions

### Kernel vs. extension split
Safety-critical actions (abort, hard caps, tool denial) stay in the **kernel**. Behavioral logic (prompt shaping, tool implementation, verifier invocation) belongs to **extensions**. This was formalized in [[summaries/Core_Extension_System_for_Semi_Formal]].

### Generic tool envelopes
The core was made **extension-agnostic** via `ToolCallEnvelope` / `ToolResultEnvelope` — the sole interface between core and extensions. No core module (parser, types, RPC, dispatch) contains extension-specific logic. Extensions own their normalization, coercion, and policy. See [[summaries/Core_Extension_Disentangling_Plan]].

### Open dispatch (not sealed ADT)
Originally, extensions were variants of a sealed `PureExt | EffectExt` ADT. This was replaced with **hook records**: the runtime folds over a list of `ExtensionHooks`, eliminating per-extension match trees and allowing extensions to be authored independently. See [[summaries/Packageize_Extension_System]].

### Package-based distribution
Each extension lives as an **AILANG package** under `.packages/` (e.g., `motoko_omnigraph`, `motoko_compose`, `motoko_test_dummy`) with its own `ailang.toml`, effect ceilings, and lockfile. Core imports use `pkg/sunholo/motoko_core/...` paths. Effect polymorphism on record fields is not supported, so the full union effect row is hardcoded. Per-extension effect ceilings are enforced at publish time via `[effects].max`.

## Existing extensions
- **Omnigraph** — typed knowledge graph for agent memory and retrieval
- **Compose** — multi-step composition subagent with anti-fabrication guards
- **Test Dummy** — controllable test extension for validation
- **Exa Search** — MCP-based web search (illustrates the generic MCP pattern)
- **Context Mode** — context window compression (~98% reduction)
