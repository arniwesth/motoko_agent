---
doc_type: short
full_text: sources/2026-04-24-compose_extension_extraction_summary.md
---

# Compose Extension Extraction Summary

## Scope
Refactored the codebase so that all Compose-specific behavior lives inside a dedicated extension, leaving the core runtime completely free of Compose assumptions. This aligns implementation with an existing extraction plan.

## Core Boundary Changes
- **types**: Removed `ComposeExecResult`, `ToolCallReq.Compose`, and `ToolResultItem.ComposeResult` from core shared ADTs.
- **rpc**: Stripped out compose orchestration helpers (`split_compose_calls`, `run_compose_calls`, etc.) and compose branching from the main request flow. Hybrid tool handling now only delegates to generic extension hooks.
- **tool_runtime**: Eliminated the compose-specific native error branch; unknown extension tools fall through to unified error handling.
- **prompts**: Deleted compose-specific prompt templates and mode-dependent builders; core prompt rendering is extension-neutral.

## Extension Ownership
Compose behavior now lives entirely in `src/core/ext/compose/compose.ail` and is wired via standard [[concepts/extension_hooks]]:
- `on_tool_policy` gate’s compose mode (AILANG_COMPOSITION_MODE).
- `on_tool_handle` runs compose tool execution, returning `ToolResultEnvelope` directly.
- `on_build_system_prompt` and `on_response_intercept` handle prompt patching and inline interception.
- The extension’s `provided_tools()` declares ownership, and `Env` is propagated to policy hooks.

## Env Client Decoupling
Removed all legacy compose transport code from `env_client.ail` (`exec_compose`, streaming helpers, sharedmem support). Only generic `/exec` and `/exec-ailang` remain.

## Validation
- **Type checks passed** for all affected files.
- **Tests passed** for compose extension, registry, and omnigraph tests.
- Known unrelated test failures noted (prompts_test parser, legacy string concatenation in compose validator test).

## Result
Core boundaries are now compose-free - policy, execution, prompt ownership, and transport are all delegated to the extension, achieving the planned extraction and improving separation of [[concepts/compose_decoupling]].