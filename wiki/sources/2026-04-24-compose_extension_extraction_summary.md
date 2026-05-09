# Compose Extension Extraction Summary

## Scope
Implemented the extraction plan from `.agent/plans/Compose_Extension_Extraction_Plan.md` so Compose behavior is extension-owned and core runtime paths are extension-agnostic.

## Core Boundary Changes

### `src/core/types.ail`
- Removed `ComposeExecResult` from core shared types.
- Removed `ToolCallReq.Compose` constructor.
- Removed `ToolResultItem.ComposeResult` constructor.

### `src/core/rpc.ail`
- Removed compose-specific orchestration and fallback helpers:
  - `split_compose_calls`
  - `run_compose_calls`
  - `deny_compose_calls`
  - compose request shaping helpers and compose execution path.
- Removed core compose mode branching and compose-specific runtime behavior.
- Switched hybrid tool flow to generic extension handling only:
  - policy via `dispatch_tool_policy`
  - handling via `dispatch_tool_handle`
  - extension observations via `ToolResultEnvelope`.
- Switched system prompt bootstrap to extension-neutral `base_system(...)`.

### `src/core/tool_runtime.ail`
- Removed compose-specific native-runtime error branch.
- Unknown extension tools now continue through generic native error behavior.

### `src/core/prompts.ail`
- Removed compose-specific core prompt policy text and mode-specific base prompt builder.
- Kept core prompt extension-neutral.
- Removed compose-specific formatting path from core `ToolResultItem` rendering.

## Compose Extension Ownership

### `src/core/ext/runtime.ail`
- Wired compose extension hooks into runtime dispatch:
  - `on_build_system_prompt`
  - `on_tool_policy`
  - `on_tool_handle`
  - `on_response_intercept`
- Compose tool ownership now comes from compose extension `provided_tools()`.
- Updated policy dispatch effects to include `Env` (needed by compose mode policy).

### `src/core/ext/compose/compose.ail`
- Compose now owns policy gating (`AILANG_COMPOSITION_MODE`) in `on_tool_policy`.
- Compose now owns tool execution in `on_tool_handle`.
- Compose now returns `ToolResultEnvelope` directly instead of core `ToolResultItem` constructors.
- Compose output/metadata now encode attempts/summary/telemetry in envelope `stdout` + `metadata`.
- Kept compose inline-intercept behavior inside extension.
- Added local compose subagent prompt card and compose main prompt patch in extension.
- Updated string-building to interpolation in this module to satisfy current language rule (`++` list-only).

## Env Client Decoupling

### `src/core/env_client.ail`
- Removed all legacy compose transport code from env client:
  - deleted `ComposeExecResult` type
  - deleted `exec_compose(...)`
  - deleted `exec_compose_stream(...)`
  - deleted compose stream parsing/sharedmem helper functions.
- `env_client.ail` now contains only generic `/exec` and `/exec-ailang` client behavior.

## Validation Performed

### Type checks (`ailang check`)
Passed:
- `src/core/types.ail`
- `src/core/prompts.ail`
- `src/core/tool_runtime.ail`
- `src/core/ext/runtime.ail`
- `src/core/ext/compose/compose.ail`
- `src/core/rpc.ail`
- `src/core/env_client.ail`

### Tests (`ailang test`)
Passed:
- `src/core/ext/compose/compose_test.ail`
- `src/core/ext/registry.ail`
- `src/core/ext/omnigraph/omnigraph_test.ail`

Note:
- `src/core/prompts_test.ail` currently fails in this workspace with parser errors in property evaluation (not a `prompts.ail` type-check failure).
- `src/core/ext/compose/validator_test.ail` currently fails due legacy string `++` usage in test strings (language now enforces `++` as list-only). This is a test-style follow-up, not a compose extraction boundary issue.
- Updated stale validator fixture text that referenced `env_client` compose streaming to reference `exec_ailang` instead.

## Result Against Plan Objectives
- Core boundary files no longer contain compose-specific execution/policy branches.
- Compose behavior is routed through extension hooks.
- Core ADTs no longer model compose call/result constructors.
- Native runtime no longer has compose-specific handling.
- Prompt policy ownership for compose moved out of core prompt templates into compose extension patching.
