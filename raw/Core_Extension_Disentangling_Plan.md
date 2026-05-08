# Core/Extension Disentangling Plan

## Objective

Decouple extension-specific semantics from core runtime so core remains a stable host for:
- LLM loop
- generic tool-call envelope parsing
- extension lifecycle hooks (prompt, policy, handle, telemetry)

Target state: core is extension-agnostic; Omnigraph and other extensions own their own aliasing, coercion, policy, and handler semantics.

## Current Coupling Inventory

### 1. Parser coupling
- File: `src/core/parse.ail`
- Coupling:
  - Omnigraph-specific aliases in `canonical_tool_name`
  - Omnigraph-specific coercion logic in `parse_one_tool_call`
  - Omnigraph tool whitelist references

### 2. Core ADT coupling
- File: `src/core/types.ail`
- Coupling:
  - `ToolCallReq` includes `OmnigraphRead/Mutate/Branch/Status`
  - `ToolResultItem` includes `OmnigraphResult`
  - Core imports Omnigraph request types directly

### 3. RPC/telemetry coupling
- File: `src/core/rpc.ail`
- Coupling:
  - Omnigraph-specific serialization in `one_tool_call_to_json`
  - Omnigraph-specific telemetry shaping in `tool_result_item_to_display`
  - Omnigraph-specific result/tool-name branching

### 4. Extension runtime dispatch coupling
- File: `src/core/ext/runtime.ail`
- Coupling:
  - `tool_name` hardcodes Omnigraph variants
  - `ext_provided_tools` hardcodes Omnigraph tool names
  - dispatch path branches on Omnigraph constructors

### 5. Extension/core type dependency
- File: `src/core/ext/omnigraph/omnigraph.ail`
- Coupling:
  - Omnigraph extension consumes core `ToolCallReq` constructors directly

## Target Architecture

### A. Generic tool contract in core
Core-owned envelopes only:
- `ToolCallEnvelope = { id: string, tool: string, arguments: Json }`
- `ToolResultEnvelope = { tool_call_id: string, tool: string, exit_code: int, stdout: string, stderr: string, metadata: Json }`

### B. Extension-owned semantics
Each extension owns:
- alias normalization
- argument coercion/inference
- policy logic
- tool execution mapping
- metadata schema

### C. Core-owned stable responsibilities
Core keeps:
- event loop and solver orchestration
- extension hook registry and call order
- generic telemetry emission (`ext_tool_calls`, `ext_tool_results`)
- policy merge and dispatch mechanics

## Registration Strategy Decision

Decision for this effort:
- Keep extension registration enum-based.
- Do not convert to descriptor/data-driven registration in this plan.

Rationale:
1. Scope control: disentangling already spans parser, RPC/telemetry, dispatch, runtime backend, and type boundaries.
2. Risk reduction: descriptor migration would simultaneously alter registry model, startup resolution, and dispatch contracts.
3. Delivery focus: immediate goal is Omnigraph/core semantic separation with behavior parity.

Follow-up effort (separate plan/PR stream):
- Introduce descriptor-based registration in parallel with compatibility adapters.
- Add startup conflict checks for duplicate tool claims.
- Migrate built-in extensions after generic contract has stabilized.

## Migration Strategy (Phased, Low Risk)

### Phase 0: Behavior freeze
1. Add/confirm golden tests for current Omnigraph parse compatibility and telemetry.
2. Define deterministic baseline assertions for e2e telemetry and outcomes (required events + pass/fail predicates), instead of relying on a single fixed `run.jsonl` artifact.

Acceptance:
- existing parser tests pass unchanged
- e2e Omnigraph smoke passes
- deterministic telemetry assertions pass (schema + required event semantics)

### Phase 1: Introduce parallel generic contracts
1. Add a new core module, e.g. `src/core/tool_contract.ail`.
2. Define `ToolCallEnvelope` and `ToolResultEnvelope`.
3. Keep existing `ToolCallReq`/`ToolResultItem` active.

Acceptance:
- no runtime behavior changes
- code compiles and existing tests pass

### Phase 2: Add generic parse path (dual path)
1. Add `parse_tool_calls_envelope(text) -> ...` in `src/core/parse.ail` (or new parser module).
2. Keep legacy `parse_tool_calls` and adapt through compatibility mapping temporarily.
3. Ensure generic parser does not include extension-specific branches.

Acceptance:
- dual-path outputs equivalent for current supported scenarios
- parser regression tests remain green

### Phase 3: Extension runtime generic dispatch
1. Extend ext host interfaces in `src/core/ext/types.ail` to accept/return generic envelopes.
2. Implement generic dispatch in `src/core/ext/runtime.ail`.
3. Keep enum-based registry in `src/core/ext/registry.ail`; do not introduce descriptor-driven registration in this phase.
4. Keep extension capability mapping explicit and deterministic during this migration.
5. Keep old dispatch as fallback during migration window.
6. Migrate and validate `compose` and `test_dummy` extensions against updated host interfaces before enabling generic dispatch by default.

Acceptance:
- all current extension calls route through generic path without regression
- fallback path can be disabled in test mode
- registry model remains stable (enum-based) throughout this effort
- compose/test_dummy compatibility tests pass on the generic dispatch path

### Phase 4: Move Omnigraph normalization out of core
1. Create `src/core/ext/omnigraph/normalize.ail`.
2. Move Omnigraph alias map and coercion rules from `src/core/parse.ail` into extension normalization.
3. Parse layer outputs generic call envelopes; extension normalization produces executable Omnigraph requests.

Acceptance:
- Omnigraph alias/coercion tests pass from extension module
- parser no longer contains Omnigraph-specific logic

### Phase 5: Make telemetry fully generic
1. In `src/core/rpc.ail`, emit `ext_tool_calls` from generic envelopes directly.
2. Emit `ext_tool_results` from `ToolResultEnvelope` only.
3. Remove extension-specific branches from `tool_result_item_to_display`.

Acceptance:
- telemetry schema stable across extensions
- no Omnigraph special-casing in rpc telemetry path

### Phase 6: Migrate tool_runtime off Omnigraph ADTs
1. In `src/core/tool_runtime.ail`, replace Omnigraph constructor pattern-matching with generic envelope/tool-name routing.
2. Move backend classification (`backend_for`) to generic tool/capability checks rather than Omnigraph ADT constructors.
3. Preserve current error semantics for missing extension capability using structured generic errors.
4. Ensure native/delegated split behavior remains unchanged for non-extension tools.

Acceptance:
- `src/core/tool_runtime.ail` has no Omnigraph ADT constructor references
- unknown/missing extension tools produce deterministic structured errors
- native core tool behavior remains unchanged
- Omnigraph e2e flow still passes through extension dispatch

### Phase 7: Remove Omnigraph from core ADTs
1. Remove Omnigraph variants/imports from `src/core/types.ail`.
2. Keep core ADTs for native non-extension tools only (hybrid end-state). Do not move all core tools to envelope model in this effort.
3. Update any remaining pattern matches in core to generic envelope handling.

Acceptance:
- core builds without importing extension-specific request/result types
- Omnigraph works entirely through extension contract
- non-extension native tools continue to use core ADTs without behavior change

### Phase 8: Retire compatibility shims
1. Remove legacy mapper and dual-path parser/dispatch code.
2. Update docs and extension author guide.
3. Keep a short rollback window via tagged release branch.

Acceptance:
- all tests green with legacy path removed
- documented extension contract is the only path

## Key Risks and Mitigations

1. Risk: Hidden behavior regressions from alias/coercion moves.
- Mitigation: golden parse tests + e2e smoke on each phase.

2. Risk: Telemetry consumers break on schema changes.
- Mitigation: keep `ext_tool_calls`/`ext_tool_results` keys stable; additive-only metadata changes.

3. Risk: Extension dispatch ambiguity when multiple extensions claim same tool.
- Mitigation: deterministic resolution by registry order + explicit conflict checks at startup.

4. Risk: Migration complexity if old/new paths diverge.
- Mitigation: dual-path period limited to 1-2 phases with strict removal milestone.

5. Risk: Registry model churn (enum -> descriptor) destabilizes disentangling rollout.
- Mitigation: explicitly defer descriptor/data-driven registry migration to a separate follow-up effort.

## Suggested Work Breakdown

1. PR 1: Contracts + no-op wiring (Phase 1)
2. PR 2: Dual parser path + tests (Phase 2)
3. PR 3: Generic extension dispatch (Phase 3)
4. PR 4: Omnigraph normalization extraction (Phase 4)
5. PR 5: Generic telemetry path (Phase 5)
6. PR 6: tool_runtime generic backend/error routing (Phase 6)
7. PR 7: Remove Omnigraph from core types (Phase 7)
8. PR 8: Remove shims + docs (Phase 8)

## Follow-Up (Out of Scope Here)

Descriptor-based extension registration:
- Add `ExtensionDescriptor` registry model with capabilities and hook pointers.
- Add conflict detection for overlapping tool ownership.
- Migrate built-ins from enum registration to descriptors after this plan is complete.

Potential future model evolution (separate from this effort):
- Evaluate full envelope model for all core tools (ReadFile/Search/WriteFile/BashExec/RunTests) if desired.

## Done Definition

The disentangling effort is complete when:
- `src/core/parse.ail` has no extension-specific normalization
- `src/core/types.ail` has no Omnigraph-specific types/constructors
- `src/core/rpc.ail` telemetry is extension-agnostic
- `src/core/ext/runtime.ail` dispatch is generic-envelope based
- `src/core/tool_runtime.ail` has no Omnigraph-specific ADT references
- Omnigraph functionality and current e2e telemetry checks still pass
