---
doc_type: short
full_text: sources/2026-04-07-core-extension-phase-x1.md
---

# Summary: Core Extension System Phase X1

**Date:** 2026-04-07
**Source:** `2026-04-07-core-extension-phase-x1` (implementation session)

## Overview
Phase X1 lays the foundation for a modular [[concepts/extension-system|extension system]] by introducing the substrate types, a registry driven by environment variables, a minimal runtime dispatch for hooks, a testable dummy extension, and integration into the main RPC loop.

## Key Components

### Extension Substrate Types
- Defined typed contracts: `ExtCtx`, `BudgetPlan`, `PromptPatch`, `BudgetPatch`, `ToolDecision`, `FinalizeDecision`, `ExtRegistry`, `ExtRuntime`.
- Separates pure and effectful extension lists in the registry shape.

### Extension Registry
- Loads extensions based on `CORE_EXT_ORDER` environment variable.
- Provides stable ordering; unknown names are ignored; empty sets are supported.
- The `test_dummy` extension can be registered multiple times with unique IDs.

### Runtime Dispatch
- Hooks: `dispatch_build_system_prompt`, `dispatch_budget_plan`, `dispatch_tool_call`, `dispatch_solver_candidate`.
- Implements [[concepts/hook-conflict-resolution|hook conflict resolution]]:
  - Tool policy: **deny wins** over allow/no-op.
  - Finalize: **continue wins**, else first accept, else no decision.
- `init_runtime()` reads configuration from multiple env vars (`CORE_EXT_ORDER`, `CORE_EXT_STRICT`, and dummy-specific ones).

### Test Dummy Extension
- Behaviour controlled via `EXT_DUMMY_*` env vars: appends prompt markers, returns configurable tool/finalize decisions, sets optional budget total.
- Emits JSONL `dummy_hook` events for observability.

### RPC Loop Integration
- Initialized runtime and applied budget/prompt hooks in `main`.
- Hook wiring for budget plan (with verifier split support) and tool calls (denied calls become `ToolErrorResult`).
- At finalize boundary, `dispatch_solver_candidate` enables extension feedback loop or early acceptance.
- Threaded `ext_runtime` and budget through all loop variants (hybrid, legacy, conversation).

## Verification
- All `.ail` files pass type checks.
- 21 unit tests across registry, runtime, and dummy extension pass.
- Smoke test confirmed `dummy_hook` events with appropriate env configuration.

## Related Concepts
- [[concepts/extension-system]]
- [[concepts/env-driven-configuration]]
- [[concepts/hook-conflict-resolution]]
- [[concepts/budget-plan]]
- [[concepts/solver-candidate-feedback-loop]]