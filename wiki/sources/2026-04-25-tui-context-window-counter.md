# Session Summary — TUI Context Window Counter

Date: 2026-04-25
Plan: `.agent/plans/TUI_Context_Window_Counter.md`
Status: Implemented

## Objective
Add a live context-window usage counter to the TUI status bar, using a local estimate (chars ÷ 4), with model-aware limits and threshold coloring.

## Work Completed

### 1. New core usage module
- Added `src/core/context_usage.ail` with:
  - `estimate_tokens(msgs: [Msg], system: string) -> int`
  - `context_limit_for(model: string) -> int`
- Implemented `openrouter/` prefix stripping and recursive lookup.
- Added mapping for documented models and support for `anthropic/claude-sonnet-4-5` to satisfy OpenRouter normalization test case from the plan.

### 2. Core companion tests
- Added `src/core/context_usage_test.ail` with non-empty message-list tests via wrapper function `sum_of_two`.

### 3. Runtime emission wiring
- Updated `src/core/rpc.ail`:
  - Imported `estimate_tokens` and `context_limit_for`.
  - Added `emit_context_usage(state, model)` helper.
  - Emits JSONL event once per loop iteration, immediately before AI call:
    - `{"type":"context_usage","step":...,"tokens_est":...,"limit":...}`
- `system` is read from the first `system` message in `state.msgs`; history is all remaining messages.

### 4. TUI protocol and UI plumbing
- Updated `src/tui/src/runtime-process.ts`:
  - Added `context_usage` to `AgentEvent` union.
- Updated `src/tui/src/ui.ts`:
  - Added `latestContextUsage` state.
  - Added event handling for `context_usage`.
  - Extended status bar rendering to append:
    - `| ctx: used/limit (%)` when limit known
    - `| ctx: used` when limit is `0`
  - Added helpers:
    - `formatCount`
    - `formatContextUsage`
    - `colorizeContextUsageSegment`
  - Implemented threshold color behavior:
    - `>=75%` yellow
    - `>=90%` red
  - Avoided nested chalk wrapping conflicts by composing line segments separately.

### 5. Tests and docs
- Added `src/tui/src/ui.context-counter.test.ts` for:
  - count formatting
  - known/unknown limit rendering
  - threshold color assertions
- Updated `src/tui/src/runtime-process.stream-protocol.test.ts` with `context_usage` parse case.
- Updated `README.md` with status-bar counter note (local estimate, not provider usage).

## Validation Results

### Core
- `ailang test src/core/context_usage.ail` ✅
- `ailang test src/core/context_usage_test.ail` ✅
- `ailang check src/core/rpc.ail` ✅

### TUI
- `cd src/tui && npm test` ✅
- Result: 17 suites passed, 90 tests passed.

## Notable Implementation Notes
- Kept runtime as the source of truth for model limits; no changes to `src/tui/src/models.ts`.
- Emission is centralized in one call site in `rpc_loop`.
- Unknown models resolve to `limit = 0`, which safely hides ratio/percent in UI.

## Files Added
- `src/core/context_usage.ail`
- `src/core/context_usage_test.ail`
- `src/tui/src/ui.context-counter.test.ts`

## Files Modified
- `src/core/rpc.ail`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/runtime-process.stream-protocol.test.ts`
- `src/tui/src/ui.ts`
- `README.md`

## Outstanding / Not Performed
- No manual interactive runtime smoke test was run in this session to visually confirm live `ctx:` updates during an actual agent run; automated tests and type checks passed.
