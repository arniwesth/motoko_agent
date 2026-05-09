# 2026-04-26 — Fix premature idle termination + omnigraph prompt gating

## Problem
When using smaller models (e.g. Gemma 4 26B) through OpenRouter, the agent terminated prematurely at step 0-2 with state "idle" instead of continuing the agent loop. Two root causes:

1. **Silent tool-parse failure**: Models that output non-standard tool-call formats (e.g. `call:ls_tree\n{}`, or JSON with `"calls"` instead of `"tool_calls"`) were silently treated as "no tool calls found," which triggered the `NoDecision` → `done` exit path.
2. **Omnigraph prompt pollution**: `CORE_EXT_ORDER=omnigraph` was hardcoded in the `run_test` Makefile target, injecting omnigraph tool descriptions into the system prompt for every task — confusing smaller models about available tools.

## Changes

### `src/core/parse.ail` — tool parse error instead of silent drop
- **Line 997**: Changed the `extract_any_tool_json_candidate` fallback from `Ok(_) => NoToolCalls` to `Ok(_) => ToolParseError(...)`. Valid JSON that lacks a `tool_calls` array now returns corrective feedback to the model instead of silently ending the loop.
- **`looks_like_non_json_tool_syntax`**: Replaced the hardcoded list of 6+ specific `call:` prefixes with a single `startsWith(trim(text), "call:")` check. Any `call:` prefix text triggers a `ToolParseError` with formatting guidance.

### `src/core/prompts.ail` — removed `base_system()` fallback
- Deleted the `base_system(workdir)` function and its hardcoded system prompt string.
- Rationale: `SYSTEM.md` is the canonical system prompt source; a baked-in fallback masks configuration errors.

### `src/core/rpc.ail` — warning on missing SYSTEM.md
- Replaced the `base_system(cwd)` fallback with a `warning` event emission when `SYSTEM.md` is not found at the configured path. The agent continues with an empty system prompt rather than silently using a stale built-in.
- Removed `base_system` from the import list.

### `src/tui/src/runtime-process.ts` — warning event type
- Added `{ type: "warning"; message: string }` to the `AgentEvent` union.

### `src/tui/src/ui.ts` — warning event rendering
- Added `case "warning"` handler that renders the message in yellow via `chalk.yellow`.

### `Makefile` — removed hardcoded omnigraph extension
- Removed `CORE_EXT_ORDER=omnigraph` from the `run_test` target so omnigraph only loads when explicitly requested per-run.

### `src/core/prompts_test.ail` — removed dead tests
- Removed two `base_system` property tests that referenced the deleted function.

## Files modified
- `src/core/parse.ail`
- `src/core/prompts.ail`
- `src/core/prompts_test.ail`
- `src/core/rpc.ail`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`
- `Makefile`
