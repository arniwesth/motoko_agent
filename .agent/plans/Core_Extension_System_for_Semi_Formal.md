# Core Extension System for Semi-Formal Reasoning

Date: 2026-04-06
Created by: gpt-5.3-codex (medium)
Status: Proposed
Scope: `src/core/*` extension runtime architecture

## Planned File Changes

Expected to be modified:

1. `src/core/rpc.ail`
2. `src/core/tool_runtime.ail`
3. `src/core/prompts.ail` (only when migrating hardcoded semi-formal logic out)
4. `.agent/plans/Core_Extension_System_for_Semi_Formal.md`
5. `.agent/plans/Semi_Formal_Reasoning_Integration.md` (cross-plan alignment)

Expected to be added:

1. `src/core/ext/types.ail`
2. `src/core/ext/registry.ail`
3. `src/core/ext/runtime.ail`
4. `src/core/ext/test_dummy/dummy.ail`
5. `src/core/ext/test_dummy/dummy_test.ail`
6. `src/core/ext/semi_formal/prompt.ail`
7. `src/core/ext/semi_formal/classifier.ail`
8. `src/core/ext/semi_formal/policy.ail`
9. `src/core/ext/semi_formal/verifier.ail`
10. `src/core/ext/semi_formal/certificate.ail`
11. `src/core/ext/*_test.ail` (new extension runtime/module tests)

## Goal

Design a first-class extension system for `core` so Semi-Formal Reasoning is implemented as an extension module, while critical safety behavior remains kernel-enforced.

## Sequencing With Semi-Formal Plan

This plan and `.agent/plans/Semi_Formal_Reasoning_Integration.md` are linked.

Authoritative sequence for implementation:

1. Implement **Phase X1** here first (extension substrate with minimal hook set).
2. Continue with **X2-X4** here.
3. In the Semi-Formal plan, Phases A-F become feature-level behavior and validation targets mapped onto X2-X4 implementation details.

Practical migration note:

1. If any Semi-Formal logic already exists directly in `src/core/prompts.ail` / `src/core/rpc.ail`, X2 migrates it into extension modules and removes duplicated inline logic.

## Why Separate This Plan

The current Semi-Formal plan focuses on one feature. This plan defines the reusable extension substrate that can support Semi-Formal and future capabilities (policy gates, observability, custom reasoning modes, external integrations).

## Inspiration and Positioning

Reference architecture inspiration comes from Pi coding agent extensions:

1. lifecycle hooks across session/turn/tool stages,
2. extension-registered commands/tools,
3. event interception for permission gates,
4. package/discovery model.

This plan adapts those ideas to AILANG core with stronger typed enforcement for safety-critical decisions.

## Design Principles

1. Kernel small, deterministic, and typed.
2. Extension power at policy/prompt/orchestration layers.
3. Kernel always enforces hard limits (budget/tool safety/finalization).
4. Explicit conflict resolution and extension ordering.
5. Graceful degradation when extensions fail.

## Architecture Overview

### Core Kernel Responsibilities

1. Run loop and state machine.
2. Budget caps and invariants.
3. Tool execution dispatch.
4. Hard policy enforcement hooks.
5. Extension lifecycle and event dispatch.

### Extension Responsibilities

1. Prompt augmentation.
2. Task routing hints.
3. Soft policy recommendations.
4. Verifier orchestration behavior.
5. Output schema validation logic (if delegated by kernel policy).

## Proposed Hook Surface

Hooks are typed. Pure hooks are synchronous; effectful hooks are explicitly marked.

Minimal hook set for X1 (only what Semi-Formal A-D needs):

1. `on_build_system_prompt(ctx, prompt) -> PromptPatch` (pure)
2. `on_budget_plan(ctx, plan) -> BudgetPatch` (pure)
3. `on_tool_call(ctx, call) -> ToolDecision` (pure)
4. `on_solver_candidate(ctx, candidate) -> FinalizeDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock}` (effectful)

`on_solver_candidate` trigger semantics (explicit):

1. Hook fires only when the core loop has a candidate final answer (no further tool-call intent).
2. In current runtime terms this corresponds to:
   - hybrid path: `run_hybrid_step` when `parse_tool_calls(response) == NoToolCalls`
   - legacy path: `run_legacy_step` when `extract_bash(response) == None`
3. Semi-Formal verifier execution via this hook is enabled only when verifier mode is on and task mode is eligible; otherwise hook returns `NoDecision`.

Deferred hook candidates (post-X1):

1. `on_boot_config(ctx) -> ConfigPatch` (pure)
2. `on_tool_result(ctx, result) -> ResultPatch` (pure)
3. `on_finalize(ctx, output) -> OutputPatch` (pure)
4. `on_error(ctx, err) -> ErrorAction` (pure)

## Extension Data Model (Typed)

```ailang
-- sketch

type ExtCtx = {
  task: string,
  step: int,
  model: string,
  cwd: string,
  hybrid_tools: bool,
  budget: BudgetPlan,
  mode: string
}

type ConfigPatch = {
  -- extension order/enablement is immutable during runtime and controlled
  -- only by CORE_EXT_ORDER at startup.
  config_overrides: [string],
  strict_mode: Option[bool]
}

type PromptPatch = {
  prepend: [string],
  append: [string]
}

type BudgetPatch = {
  requested_total: Option[int],
  requested_solver: Option[int],
  requested_verifier: Option[int]
}

type ToolDecision = Allow | Deny(string) | NoOpinion

type FinalizeDecision
  = Accept(string)
  | ContinueWithFeedback(string)
  | NoDecision

type BudgetPlan = { total: int, solver: int, verifier: int }

type ResultPatch = {
  annotations: [string]
}

type OutputPatch = {
  append_sections: [string]
}

type ErrorAction = Ignore | Annotate(string) | Abort(string)

type ExtensionEvent
  = BuildPrompt
  | BudgetPlanEvent
  | ToolCallEvent
  | SolverCandidateEvent
  | FinalizeEvent
```

Implementation note for AILANG effect typing:

1. Pure and effectful hooks are represented in **separate registry shapes** in X1:
   - pure hook registry (prompt, budget, tool policy)
   - effectful hook registry (`on_solver_candidate`)
2. This avoids forcing prompt-only extensions to satisfy maximal effect signatures for all hook fields.

## Conflict Resolution Rules

1. Deterministic extension order from config.
2. For tool policy, `Deny` wins over `Allow`.
3. For budgets, kernel clamps to hard caps after patches.
4. For finalize decisions:
   - collect all extension decisions in order,
   - if any `ContinueWithFeedback` is present, completion is deferred,
   - else if one or more `Accept` decisions are present, select the first `Accept` in extension order and run kernel validators,
   - else no finalize action (`NoDecision`).

## Semi-Formal as an Extension

Module path proposal:

1. `src/core/ext/semi_formal/prompt.ail`
2. `src/core/ext/semi_formal/classifier.ail`
3. `src/core/ext/semi_formal/policy.ail`
4. `src/core/ext/semi_formal/verifier.ail`
5. `src/core/ext/semi_formal/certificate.ail`

Hook mapping:

1. `on_build_system_prompt`: add semi-formal template by task class.
2. `on_budget_plan`: request solver/verifier split.
3. `on_tool_call`: enforce read-only verifier policy.
4. `on_solver_candidate`: run verifier decision path.
5. `on_finalize`: attach structured reasoning metadata.

## Kernel-Enforced (Non-Overridable)

1. Global max steps and per-phase clamping.
2. Forbidden tool classes when mode is read-only.
3. Finalization requires kernel validator pass.
4. Abort/exit semantics.

## Configuration Model

Phase 1: env-driven

1. `CORE_EXT_ORDER=semi_formal,...` (single source of truth: enabled extensions + order)
2. `CORE_EXT_STRICT=0|1` (if extension errors should fail fast)
3. `CORE_EXT_HOOK_TIMEOUT_MS` (effectful hook timeout; default `15000`)

Phase 2: file-driven (`.core/extensions.json`)

1. extension list and order,
2. per-extension config blob,
3. enabled/disabled flags.

## Lifecycle

1. Load config.
2. Initialize extension registry.
3. Emit startup hook (`on_boot_config`).
4. Run normal loop with hook dispatch points.
5. Emit shutdown hook with summary.

## Failure Model

1. Extension hook error defaults to `NoOpinion` unless `CORE_EXT_STRICT=1`.
2. Kernel logs extension errors into trace.
3. Per-hook fallback behavior:
   - `on_build_system_prompt`: no prompt change
   - `on_budget_plan`: no budget change (kernel defaults/clamps remain)
   - `on_tool_call`: fail-closed in read-only mode (`Deny("extension error in tool policy")`), fail-open otherwise
   - `on_solver_candidate`: downgrade to `ContinueWithFeedback("verifier_extension_error")`
   - `on_finalize`: no output patch
4. In strict mode (`CORE_EXT_STRICT=1`), any hook error aborts startup/turn with explicit error output.
5. Hook timeout policy:
   - effectful hooks must complete within `CORE_EXT_HOOK_TIMEOUT_MS` (default: 15000)
   - on timeout, treat as hook error and apply the same fallback/strict handling
6. Abort precedence:
   - strict-mode abort (hook error under `CORE_EXT_STRICT=1`) takes precedence over extension-returned `ErrorAction`
   - outside strict mode, explicit `ErrorAction.Abort(msg)` from an extension aborts the current turn

Budget default/override semantics:

1. Kernel default plan is computed first:
   - `total = AI_MAX_STEPS` (fallback default from runtime)
   - if verifier mode is enabled: `verifier = max(1, floor(total * 0.25))`, `solver = total - verifier`
   - otherwise: `solver = total`, `verifier = 0`
2. Extension `BudgetPatch` overrides are applied next:
   - `requested_* = None` means "no override, keep current value"
3. Kernel performs final clamping and invariant enforcement.

## Phased Implementation

### Phase X1: Extension Substrate + Test Dummy Extension

Files:

1. `src/core/ext/types.ail`
2. `src/core/ext/registry.ail`
3. `src/core/ext/runtime.ail`
4. `src/core/ext/test_dummy/dummy.ail`
5. `src/core/ext/test_dummy/dummy_test.ail`
6. `src/core/rpc.ail` (hook call points)

Deliverables:

1. empty extension list support in registry (no built-in no-op extension required),
2. deterministic ordering,
3. trace-visible hook calls for X1 minimal hooks,
4. `test_dummy` extension that validates the substrate end-to-end before any real
   extension is written.

#### Test Dummy Extension

The test dummy is a configurable extension enabled via `CORE_EXT_ORDER=test_dummy`.
Its sole purpose is to exercise every hook dispatch path, conflict resolution rule,
and fallback behavior so the substrate can be verified to be correct before the
semi-formal extension is built on top of it.

**Behavior is controlled by env vars:**

| Env var | Values | Hook affected |
|---|---|---|
| `EXT_DUMMY_PROMPT` | `""` (no-op) or any string | `on_build_system_prompt` — appends the string as a marker |
| `EXT_DUMMY_TOOL_DECISION` | `allow`, `deny`, `noop` (default) | `on_tool_call` — returns `Allow`, `Deny("dummy deny")`, or `NoOpinion` |
| `EXT_DUMMY_FINALIZE` | `accept`, `continue`, `noop` (default) | `on_solver_candidate` — returns `Accept(candidate)`, `ContinueWithFeedback("dummy feedback")`, or `NoDecision` |
| `EXT_DUMMY_BUDGET_TOTAL` | int or unset | `on_budget_plan` — sets `requested_total` if present |

**Observable side effects (for test assertions):**

Every hook call emits a `dummy_hook` event to stdout in the JSONL trace:

```json
{"type": "dummy_hook", "hook": "on_tool_call", "decision": "noop"}
{"type": "dummy_hook", "hook": "on_build_system_prompt", "appended": "DUMMY_MARKER"}
```

This lets tests assert that the dispatch path fired, in the right order, with the right
input, without running a real LLM or real tool execution.

**Test cases covered by `dummy_test.ail`:**

1. Substrate with no extensions registered — hooks fire but return defaults, no event
   emitted.
2. `test_dummy` registered — `dummy_hook` events appear in trace for each hook.
3. `EXT_DUMMY_TOOL_DECISION=deny` — `on_tool_call` returns `Deny`; kernel produces
   `ToolErrorResult` for the call; `dummy_hook` event records the decision.
4. `EXT_DUMMY_FINALIZE=continue` — `on_solver_candidate` returns
   `ContinueWithFeedback`; solver loop continues; `dummy_hook` event confirms this path.
5. `EXT_DUMMY_BUDGET_TOTAL=10` — budget plan is overridden; `dummy_hook` event
   records the patched value; kernel clamps are applied on top.
6. Two dummy extensions registered in order — hook events appear in declared order;
   conflict resolution (deny-wins for tool policy) is observable.

**Why a configurable dummy rather than hardcoded test stubs:**

Hardcoded stubs require recompiling to test different behaviors. Env-var control lets the
dummy be exercised in multiple modes from a single `.ail` binary, matching how the
extension system will be used in production (env-driven config).

### Phase X2: Semi-Formal Extension Migration

Files:

1. `src/core/ext/semi_formal/*`
2. `src/core/prompts.ail` and `src/core/rpc.ail` (remove hardcoded semi-formal logic)

Deliverables:

1. existing Semi-Formal behavior reproduced via extension hooks,
2. parity tests pass.

### Phase X3: Policy Hardening

Files:

1. `src/core/tool_runtime.ail`
2. `src/core/ext/semi_formal/policy.ail`

Deliverables:

1. read-only enforcement through extension + kernel checks (or migration of already-inline policy into extension path if it exists),
2. deny-wins conflict behavior tested.

### Phase X4: Certificate and Finalization Integration

Files:

1. `src/core/ext/semi_formal/certificate.ail`
2. `src/core/rpc.ail`

Deliverables:

1. typed certificate validation integrated in finalize path,
2. explicit downgrade-to-inconclusive behavior.

## Testing Strategy

1. Unit tests for registry ordering and conflict resolution.
2. Hook contract tests (input/output types and invariants).
3. End-to-end tests with extension enabled/disabled parity.
4. Failure injection tests (hook errors, timeout, malformed decisions).

## Risks

1. Hook surface too broad too early -> slow delivery.
2. Extension interactions causing nondeterminism.
3. Over-delegating safety logic out of kernel.

## Mitigations

1. Start with minimal hook set and expand only when needed.
2. Keep hard safety controls kernel-enforced.
3. Require deterministic order and explicit merge rules.

## Immediate Next Action

Implement Phase X1 (extension substrate with no-op extension), then port Semi-Formal routing/prompt logic into `semi_formal` extension module.
