# Session Summary: Core Extension System Phase X1 — 2026-04-07

## Scope Completed

Implemented **Phase X1** from `.agent/plans/Core_Extension_System_for_Semi_Formal.md` only:

- extension substrate types,
- extension registry with env-driven ordering,
- extension runtime dispatch for minimal hook set,
- configurable `test_dummy` extension,
- X1 hook wiring in `src/core/rpc.ail`.

No X2/X3/X4 semi-formal modules were started.

---

## Files Added

1. `src/core/ext/types.ail`
2. `src/core/ext/registry.ail`
3. `src/core/ext/runtime.ail`
4. `src/core/ext/test_dummy/dummy.ail`
5. `src/core/ext/test_dummy/dummy_test.ail`

## Files Modified

1. `src/core/rpc.ail`

---

## Substrate Design Implemented (X1)

### 1) Extension Types (`src/core/ext/types.ail`)

Added typed contracts for:

- `ExtCtx`
- `BudgetPlan`
- `PromptPatch`
- `BudgetPatch`
- `ToolDecision` (`Allow | Deny(string) | NoOpinion`)
- `FinalizeDecision` (`Accept(string) | ContinueWithFeedback(string) | NoDecision`)
- `ExtRegistry`
- `ExtRuntime`

Implementation detail: pure and effectful extension lists are separate in the registry shape (`pure_hooks`, `effectful`).

### 2) Registry (`src/core/ext/registry.ail`)

Implemented env-driven extension loading:

- `CORE_EXT_ORDER` parser (`parse_core_ext_order`)
- stable ordering based on declared order
- unknown extension names ignored
- empty extension set supported without fallback/no-op entries

`test_dummy` supports multiple registrations and preserves order (`test_dummy#<index>` IDs).

### 3) Runtime Dispatch (`src/core/ext/runtime.ail`)

Implemented X1 minimal hook dispatch:

- `dispatch_build_system_prompt`
- `dispatch_budget_plan`
- `dispatch_tool_call`
- `dispatch_solver_candidate`

Conflict resolution implemented:

- tool policy: **deny wins** over allow/no-op
- finalize: **continue wins**, else first accept, else no decision

Also added `init_runtime()` to load runtime env config:

- `CORE_EXT_ORDER`
- `CORE_EXT_STRICT` (stored on runtime struct)
- `EXT_DUMMY_PROMPT`
- `EXT_DUMMY_TOOL_DECISION`
- `EXT_DUMMY_FINALIZE`
- `EXT_DUMMY_BUDGET_TOTAL`

### 4) Dummy Extension (`src/core/ext/test_dummy/dummy.ail`)

Configurable behavior by env vars:

- `EXT_DUMMY_PROMPT`: append marker to prompt
- `EXT_DUMMY_TOOL_DECISION`: `allow | deny | noop`
- `EXT_DUMMY_FINALIZE`: `accept | continue | noop`
- `EXT_DUMMY_BUDGET_TOTAL`: optional integer override for total budget

### 5) Trace-Visible Hook Events

Each dummy hook dispatch emits JSONL event via stdout:

- `{"type":"dummy_hook", "hook":"on_build_system_prompt", ...}`
- `{"type":"dummy_hook", "hook":"on_budget_plan", ...}`
- `{"type":"dummy_hook", "hook":"on_tool_call", ...}`
- `{"type":"dummy_hook", "hook":"on_solver_candidate", ...}`

This made hook path execution observable without requiring full feature logic.

---

## `rpc.ail` Integration Changes

### 1) Extension Runtime Initialization

In `main`:

- initialize extension runtime via `init_runtime()`
- compute budget plan through extension budget hook
- apply prompt hook to final system prompt before session init

### 2) Budget Hook Wiring

Added budget planning helpers:

- default total from `AI_MAX_STEPS` (fallback 50)
- optional verifier split when `SEMI_FORMAL_VERIFIER_MODE=1`
- extension patch application via `dispatch_budget_plan`
- final kernel clamp/invariant normalization

### 3) Tool Policy Hook Wiring (Hybrid Path)

Before backend split:

- call `dispatch_tool_call` per parsed tool call
- denied calls converted to `ToolErrorResult`
- allowed calls continue through normal native/delegated execution
- deny-wins behavior inherited from runtime merge logic

### 4) Solver-Candidate Hook Wiring

At finalize boundary (no further tool-call intent):

- legacy path: `extract_bash(response) == None`
- hybrid path: `parse_tool_calls(response) == NoToolCalls`

At these points, `dispatch_solver_candidate` is called:

- `ContinueWithFeedback(msg)` => append user feedback and continue loop
- `Accept(output)` => finalize with accepted output
- `NoDecision` => existing finalize behavior

### 5) Loop Signatures

Threaded `ext_runtime` and `budget` through:

- `rpc_loop`
- `run_hybrid_step`
- `run_legacy_step`
- `conversation_loop`

---

## Verification and Test Results

### Type checks

Passed:

- `ailang check src/core/ext/types.ail`
- `ailang check src/core/ext/registry.ail`
- `ailang check src/core/ext/runtime.ail`
- `ailang check src/core/ext/test_dummy/dummy.ail`
- `ailang check src/core/ext/test_dummy/dummy_test.ail`
- `ailang check src/core/rpc.ail`

### Tests

Passed:

- `ailang test src/core/ext/registry.ail` (4/4)
- `ailang test src/core/ext/runtime.ail` (5/5)
- `ailang test src/core/ext/test_dummy/dummy.ail` (7/7)
- `ailang test src/core/ext/test_dummy/dummy_test.ail` (5/5)

Runtime smoke execution with env configuration produced expected `dummy_hook` events for budget + prompt hooks.

---

## Operational Notes

- Running `src/core/rpc.ail` directly requires capabilities and AI selection flags (`--caps ...`, plus `--ai ...` or `--ai-stub`), independent of `MODEL` env used by the app runtime.
- `CORE_EXT_ORDER=test_dummy` is sufficient to activate the dummy extension.

---

## Status

Phase X1 implementation is complete and validated in core/runtime + dummy extension paths.
