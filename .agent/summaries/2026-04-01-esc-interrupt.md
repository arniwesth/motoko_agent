# ESC Interrupt: Task Interruption Feature

## Overview

Added the ability to press **ESC** to interrupt a running agent task and immediately re-enter a new prompt, without restarting the whole process.

## Problem

The first attempt used a soft abort: `brain.abort()` sends `{"type":"abort"}` to the brain's stdin. The AILANG brain only reads this via `_io_poll_stdin` (non-blocking) at the **top of each `rpc_loop` iteration** — before the LLM call. While the brain is blocked inside an LLM HTTP request or a 30-second bash exec, the abort signal sits unread. The task runs to completion; the abort is then consumed by `conversation_loop` which treats it as an exit signal, terminating the whole process.

## Solution

Press ESC → **SIGTERM** the brain process immediately via `brain.kill()`. Three files changed:

### `tui/src/brain.ts`
Added `kill()` method:
```typescript
kill(): void {
  if (this.dead) return;
  this.proc.kill("SIGTERM");
}
```

### `tui/src/ui.ts`
- Added `onInterrupt?: () => void` public callback
- ESC input listener: only fires when `this.brain && !this.taskDone` (task is running); adds "Task interrupted" to history and calls `onInterrupt`; consumes the ESC key so the Editor doesn't also handle it
- When idle (no running task), ESC is not consumed so the Editor can use it for autocomplete cancellation

### `tui/src/index.ts`
- Added `interrupted: boolean` flag (local to `main()`)
- `ui.onInterrupt`: sets `interrupted = true`, calls `brain.kill()`
- `spawnBrain` `onExit` callback: checks `interrupted` flag — if true, calls `ui.setAwaitingTask(true)` to re-enable the initial-task input flow instead of calling `process.exit(0)`

## Key Design Decisions

- **Hard kill over soft abort**: `_io_poll_stdin` is only polled between steps, making soft abort unreliable during long-running LLM or bash operations.
- **Re-uses `awaitingTask` flow**: After interrupt, `setAwaitingTask(true)` re-enables the same initial-task submission path, so the user's next input spawns a fresh brain via the existing `onInitialTask` → `spawnBrain` path.
- **No brain restart on normal exit**: The `interrupted` flag ensures the process only stays alive when ESC was the cause of exit; natural task completion still exits normally via `process.exit(0)`.
- **Plan**: `.agent/plans/ESC_Interrupt.md`
