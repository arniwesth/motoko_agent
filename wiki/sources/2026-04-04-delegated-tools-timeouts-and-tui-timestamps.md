# 2026-04-04 — Delegated Tool Timeout Fixes + TUI Timestamping

## Goal
Address regressions after implementing `Tool_Dispatch_to_TUI.md`, specifically:
- false delegated timeout behavior
- missing per-message timestamps in the TUI
- footer timestamp visibility
- non-updating elapsed timer during delegated waits
- review finding on bounded delegated wait attempts

## Changes

### 1. Brain delegated wait path made reliable for tool results
- File: `swe/rpc.ail`
- Updated `wait_for_tool_results(...)` to consume tool-result messages from stdin via `readLine()` matching on:
  - `type == "tool_results"`
  - `request_id == expected request id`
- Kept handling of `abort` and `model_change` while waiting.

Why:
- The previous polling behavior (`_io_poll_stdin`) could miss incoming lines, causing false `timed out waiting for tool_results` even when TUI completed the batch.

### 2. Review fix: restore bounded delegated wait attempts (P1)
- File: `swe/rpc.ail`
- In `wait_for_tool_results(...)`, recursive branches now decrement attempts:
  - decode error branch
  - `model_change` branch
  - unrelated message branch
- Updated calls from `attempts` to `attempts - 1` in those paths.

Why:
- Reviewer correctly flagged that attempts were not being consumed in non-matching branches, making timeout effectively unreachable while stdin remained active.

### 3. TUI history messages now include millisecond timestamps
- File: `tui/src/ui.ts`
- Added timestamp formatting helper (`HH:MM:SS.mmm`) and centralized history append helpers.
- All newly appended history entries now include a leading timestamp, including:
  - reasoning/wait messages
  - tool batch queued/progress/done rows
  - user input echoes (`> ...`)
  - errors/warnings/info
  - markdown text rendered from thinking/output

### 4. Footer line 1 now includes absolute last-update timestamp
- File: `tui/src/ui.ts`
- Extended status line 1 to show both:
  - relative age (`last update: Xs ago`)
  - absolute time (`at: HH:MM:SS.mmm`)

### 5. Delegated execution switched from blocking to async
- File: `tui/src/brain.ts`
- Replaced `spawnSync` with async `spawn` for delegated tool calls.
- Preserved behavior:
  - 30s timeout
  - stdout/stderr capture
  - truncation in final result payload
- `handleToolCalls(...)` now awaits calls without blocking the Node event loop.

Why:
- With `spawnSync`, the event loop was blocked during tool execution, freezing footer timer updates in `tools_wait/tools_run`.

## Validation

### Brain / AILANG checks
- `ailang check swe/rpc.ail`
- `ailang check swe/types.ail`
- `ailang check swe/parse.ail`
- `ailang check swe/prompts.ail`
- `ailang check swe/env_client.ail`
- `ailang check swe/cache.ail`
- `ailang check swe/agents_md.ail`

All passed.

### TUI checks
- `cd tui && npm run build`
- `cd tui && npm test`

All passed (`4/4` test suites).

## Notes
- User-reported symptoms matched the implemented fixes:
  - false delegated timeout in batch flow
  - missing timestamps per message
  - frozen elapsed indicator while delegated tools were running
- A reviewer-confirmed P1 regression was addressed in follow-up by decrementing attempts on all non-terminal recursive paths.
