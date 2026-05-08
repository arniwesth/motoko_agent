# Session Summary — 2026-04-04

## Scope

Worked on hybrid tool execution UX/debugging in TUI and delegated wait behavior in brain runtime.

## Key Changes Implemented

1. Frontend tool-call visibility improvements
- Ensured tool calls are clearly rendered in TUI/non-TTY paths.
- Added structured rendering for tool batches and tool result phases (`queued`, `running`, `done/failed`).
- Collapsed raw JSON tool-call blocks out of visible thinking markdown.

2. Native tool-call rendering fix
- Root cause: native tools (e.g., `ReadFile`, native `BashExec`) can appear only in thinking JSON, not `tool_calls` events.
- Added parsing of ` ```json { tool_calls: ... } ``` ` from thinking and rendered native calls explicitly.
- Updated delegated/native classification to mirror backend logic (`needs_delegation_for_process` semantics).

3. Thinking trace parsing fix
- `<think>...</think>` matching now works even when not at string start.
- Prevented hidden/mis-rendered thinking when wrappers/leading text exist.

4. Delegated abort correctness fix (P1 review item)
- In `swe/rpc.ail`, `DelegatedAborted` now emits `error: aborted` and exits immediately.
- Removed incorrect behavior that converted abort into synthetic timeout tool errors and continued looping.

5. Delegated timeout policy fix (P2 review item)
- Replaced hardcoded `wait_for_tool_results(..., 300)` with computed attempts based on delegated batch size.
- Added env-configurable policy:
  - `DELEGATED_TOOL_TIMEOUT_MS` (default 30000)
  - `DELEGATED_TOOL_POLL_MS` (default 100)
  - `DELEGATED_TOOL_TIMEOUT_SLACK_MS` (default 5000)
- New formula: `attempts = ceil((delegated_count * per_call_ms + slack_ms) / poll_ms)`.

6. Tool event ordering fix in TUI
- Investigated user report showing `[done]` rows before `[queued]`.
- Fixed line-handler ordering in `tui/src/brain.ts` so UI receives `tool_calls` before delegated execution state.
- Added `setImmediate` when kicking delegated execution to preserve deterministic `queued -> running -> done` order.

## Investigations and Findings

- Reproduced `3 x sleep 12` delegated batch runs.
- Verified delegated tool executions completed successfully (`exit=0`) after timeout-budget fix.
- Identified misleading UI event order as a major confusion source.
- Noted that `Unknown command: "Which tools where called?"` occurs when follow-up is sent before task completion handoff.

## Documentation Added

1. Research note:
- `.agent/research/Hybrid_Tool_Execution_Parallelism_Insight.md`
- Captures selective parallelism strategy used by modern agents and implications for AILANG.

2. Plan document:
- `.agent/plans/TUI_Wait_State_Clarity.md`
- Phased UX plan for clearer waiting/progress states in TUI.

## Validation Performed

- `cd tui && npm run build` (pass)
- `cd tui && npm test` (pass)
- `ailang check swe/rpc.ail` (pass)
- `make check_swe` (pass, 11/11)

## Remaining Follow-ups

1. P2 review item still open:
- Preserve model changes received during delegated waits (`DelegatedReceived(hit).model` currently not threaded through recursion path).

2. Implement wait-state clarity plan from `.agent/plans/TUI_Wait_State_Clarity.md`.
