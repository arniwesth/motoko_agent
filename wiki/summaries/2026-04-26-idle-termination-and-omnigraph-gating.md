---
doc_type: short
full_text: sources/2026-04-26-idle-termination-and-omnigraph-gating.md
---

## Summary

This change resolves an issue where the agent loop terminated prematurely (after 0–2 steps) with an "idle" state when using smaller models like Gemma 4 26B via OpenRouter. The root causes were silent swallowing of non‑standard tool‑call syntax and hardcoded injection of omnigraph extensions into the system prompt.

## Key Changes

### Tool Parse Error Handling (`parse.ail`)
- The fallback for `extract_any_tool_json_candidate` no longer silently returns `NoToolCalls` when valid JSON lacks a `tool_calls` array. Instead, it now returns a `ToolParseError` with corrective feedback. This prevents the [[concepts/agent-loop-termination]] from exiting without giving the model a chance to recover.
- The helper `looks_like_non_json_tool_syntax` was simplified to a generic `call:` prefix check, catching any `call:something` text (not just a hardcoded list) and issuing a `ToolParseError` with formatting guidance.

### System Prompt Management (`prompts.ail`, `rpc.ail`, `tui`)
- Removed the `base_system()` fallback function that embedded a hardcoded system prompt. This masked configuration errors when `SYSTEM.md` was missing or misconfigured.
- When `SYSTEM.md` is not found, the agent now emits a `warning` event and continues with an empty [[concepts/system-prompt-management]], making it obvious that the system prompt is absent.
- TUI components now render warning events in yellow, improving visibility of configuration issues.

### Extension Loading (`Makefile`)
- The hardcoded `CORE_EXT_ORDER=omnigraph` environment variable was removed from the `run_test` target. Omnigraph now loads only when explicitly requested per run, avoiding [[concepts/extension-loading]] pollution that confused smaller models about available tools.

### Testing
- Dead property tests for the removed `base_system` function were deleted from `prompts_test.ail`.

## Impact
Models that previously produced non‑standard tool output (e.g., `call:ls_tree`, JSON with `"calls"` instead of `"tool_calls"`) now receive a parse error that allows the agent to iterate and eventually produce a well‑formed call, instead of silently idling out. Removing the omnigraph automatic load prevents unnecessary tool descriptions from confusing the model.

**Related concepts:** [[concepts/tool-call-parsing]], [[concepts/agent-loop-termination]], [[concepts/system-prompt-management]], [[concepts/extension-loading]]