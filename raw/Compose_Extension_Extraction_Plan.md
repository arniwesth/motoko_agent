# Compose Extension Extraction Plan

## Objective

Extract `Compose` from core runtime semantics so core remains extension-agnostic.

Target state:
- Core parses and routes generic `ToolCallEnvelope` only.
- `Compose` behavior (policy, retries, execution, formatting hints) is owned by compose extension modules.
- Core does not branch on compose-specific tool logic in `rpc.ail`, `tool_runtime.ail`, or core ADTs.

---

## Current Coupling Inventory

### 1. RPC orchestration coupling
- File: `src/core/rpc.ail`
- Coupling:
  - `split_compose_calls`
  - `run_compose_calls`
  - `deny_compose_calls`
  - composition-mode control flow in `run_hybrid_step`

### 2. Core ADT coupling
- File: `src/core/types.ail`
- Coupling:
  - `ToolCallReq` still includes `Compose`
  - compose-specific assumptions still present in legacy core result shaping paths

### 3. Runtime backend coupling
- File: `src/core/tool_runtime.ail`
- Coupling:
  - native runtime has compose-aware error behavior (`Compose is orchestrated in rpc...`)

### 4. Prompt/composition policy coupling
- Files: `src/core/prompts.ail`, `src/core/rpc.ail`
- Coupling:
  - core system prompt and mode logic explicitly encode compose policy (`AILANG_COMPOSITION_MODE` semantics)

---

## Target Architecture

### A. Core-owned responsibilities
- Generic envelope parsing and routing.
- Extension hook dispatch (`policy`, `handle`, `intercept`, `finalize`).
- Generic telemetry channels (`tool_calls`, `native_tool_*`, `ext_tool_*`).

### B. Compose extension-owned responsibilities
- Compose alias/tool ownership.
- Compose policy decisions (allow/deny based on mode or config).
- Compose execution and retries.
- Compose-specific metadata and result formatting hints.

### C. Core tool ADTs
- `ToolCallReq` remains only for native core tools (`ReadFile`, `Search`, `WriteFile`, `EditFile`, `BashExec`, `RunTests`).
- `Compose` exists only as extension envelope tool.

---

## Migration Strategy (Phased)

### Phase 0: Baseline lock
1. Add/confirm tests for compose current behavior:
   - subagent mode execution
   - inline/off mode denial behavior
   - telemetry shape (`ext_tool_calls`, `ext_tool_results`)
2. Capture deterministic assertions (event presence + key fields), not full trace snapshots.

Acceptance:
- baseline compose e2e scenarios pass on current branch.

### Phase 1: Extension-first compose dispatch
1. Move compose tool handling from `rpc.ail` into compose extension handler path.
2. Ensure compose extension returns `ToolResultEnvelope` directly.
3. Keep transitional fallback path in `rpc.ail` behind gate during rollout window:
   - fallback symbols may remain temporarily: `split_compose_calls`, `run_compose_calls`, `deny_compose_calls`
   - fallback path executes only when gate indicates compatibility mode
4. Introduce temporary rollout gate `CORE_COMPOSE_EXTENSION_ONLY`:
   - `0` (default during rollout): keep compatibility fallback path enabled.
   - `1`: force extension-only compose path.
5. Define rollback trigger + action:
   - Trigger: compose e2e fail or extension dispatch error rate above agreed threshold.
   - Action: flip gate to `0` and revert to fallback path while triaging.

Acceptance:
- compose calls flow through `dispatch_tool_handle` only.
- extension-only path is exercised and validated with gate=`1`.
- compatibility fallback path is exercised and validated with gate=`0`.
- gate can be toggled at runtime without code changes.
- rollback path is validated in CI (both gate states exercised during transition window).

### Phase 2: Compose policy extraction
1. Move composition mode gating (`inline`/`off`/`subagent`) into compose extension `on_tool_policy`.
2. Core keeps generic `Allow/Deny` semantics only.
3. Keep env var compatibility (`AILANG_COMPOSITION_MODE`) but read it inside compose extension.
4. Explicitly verify extension hook ownership for compose in this phase:
   - `on_tool_policy`: compose mode gating owner
   - `on_tool_handle`: compose execution owner
   - `on_response_intercept`: explicitly documented no-op or behavior owner
   - `on_solver_candidate`: explicitly documented no-op or behavior owner

Acceptance:
- core no longer inspects composition mode for compose decisions.
- deny messages remain behaviorally equivalent.
- hook ownership table is documented and tested for compose.

### Phase 3: Core ADT cleanup
1. Remove `Compose` from `ToolCallReq` in `src/core/types.ail`.
2. Remove compose-specific matching from core runtime code.
3. Ensure parser still emits compose as generic envelope tool.

Acceptance:
- core ADTs contain no compose constructor.
- build/test pass with compose fully extension-driven.

### Phase 4: Tool runtime cleanup
1. Remove compose branch/error handling from `src/core/tool_runtime.ail`.
2. Ensure unknown extension tools produce consistent structured errors in native path.

Acceptance:
- `tool_runtime.ail` has no compose-specific behavior.
- delegated/native split unchanged for non-compose tools.

### Phase 5: Prompt boundary cleanup
1. Remove compose-specific behavioral instructions from core prompt templates.
2. Add compose guidance via extension prompt patch only.
3. Validate user-facing compose observation contract after cleanup:
   - compose summary text remains present
   - attempts/final status remains visible
   - validator outcome (satisfied/unsatisfied/inconclusive) remains visible when applicable
   - stderr/stdout visibility behavior remains unchanged

Acceptance:
- core base prompt remains extension-neutral.
- compose prompt guidance still appears when compose extension active.
- user-facing compose observation assertions pass in deterministic e2e checks.

### Phase 6: Shim retirement + docs
1. Remove compatibility helpers that only existed for transitional compose path.
2. Update docs:
   - extension author contract
   - compose extension behavior ownership
3. Retire rollout gate:
   - remove `CORE_COMPOSE_EXTENSION_ONLY` branching and fallback code
   - keep extension-only compose dispatch as the single path

Acceptance:
- no dead compose shim code in core.
- docs match runtime behavior.
- rollout gate and compatibility fallback path are removed.

---

## Risks and Mitigations

1. Risk: Compose behavior drift (retry semantics, result quality).
- Mitigation: phase-0 baseline tests + golden semantic assertions.

2. Risk: Telemetry consumer regressions.
- Mitigation: keep `ext_tool_calls`/`ext_tool_results` event keys stable; additive metadata only.

3. Risk: Policy confusion between core and extension.
- Mitigation: single ownership rule: compose policy only in compose extension.

4. Risk: Hidden compile-time coupling via legacy constructors.
- Mitigation:
  - enforce allowlist-based boundary checks in CI with explicit rules:
    - forbidden in core paths (`src/core/rpc.ail`, `src/core/tool_runtime.ail`, `src/core/types.ail`, `src/core/prompts.ail`):
      - `Compose(` constructor matches
      - compose-specific helper symbols (`split_compose_calls`, `run_compose_calls`, `deny_compose_calls`) after Phase 6
      - compose-specific mode branching (`AILANG_COMPOSITION_MODE`) after Phase 2 extraction
    - allowed compose ownership only in compose extension modules and explicitly allowlisted tests/docs
  - add compile/runtime contract test proving compose path works via envelope dispatch only.

5. Risk: Hard cutover causes production regression without quick mitigation.
- Mitigation: temporary feature gate + documented rollback playbook (Phase 1).

6. Risk: Telemetry passes while UX regresses.
- Mitigation: add user-visible observation contract assertions (Phase 5), not just event-key validation.

---

## Suggested PR Breakdown

1. PR1: Baseline tests + telemetry assertions (Phase 0)
2. PR2: Extension-first compose dispatch + rollout gate + rollback validation (Phase 1)
3. PR3: Compose policy extraction (Phase 2)
4. PR4: Remove compose from core ADTs/runtime (Phases 3-4)
5. PR5: Prompt cleanup + shim/doc updates (Phases 5-6)

---

## Done Definition

Extraction is complete when:
- `src/core/rpc.ail` has no compose-specific execution branches.
- `src/core/types.ail` has no compose constructor in core tool ADTs.
- `src/core/tool_runtime.ail` has no compose-specific handling.
- compose behavior is fully implemented through extension hooks.
- compose e2e behavior and telemetry assertions pass.
- temporary rollout gate/fallback path is retired (single extension-only path).
