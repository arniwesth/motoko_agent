---
doc_type: short
full_text: sources/2026-04-01-esc-interrupt.md
---

# ESC Interrupt: Task Interruption Feature

## Overview
This change introduces the ability to press **ESC** while an agent task is running to immediately interrupt it and re-enter a new prompt without restarting the entire process.

## Problem
A soft abort (`brain.abort()`) was ineffective because the brain only checks for stdin signals between its RPC loop iterations. During long-running LLM calls or bash executions, the abort signal would remain unprocessed until the step completed — at which point it would be misinterpreted as an exit command, causing the whole TUI to terminate instead of just interrupting.

## Solution
ESC now sends **SIGTERM** to the brain process via `brain.kill()`, ensuring an immediate, hard interruption. After killing, the UI reuses the `awaitingTask` flow to let the user type a new prompt, which spawns a fresh brain through the existing `onInitialTask` → `spawnBrain` path.

## Key Changes
- **`tui/src/brain.ts`**: Added `kill()` method that sends `SIGTERM`.
- **`tui/src/ui.ts`**: Added `onInterrupt` callback; ESC only interrupts when a task is running (idle ESC is passed through for autocomplete cancellation).
- **`tui/src/index.ts`**: Uses an `interrupted` flag to branch between re-enabling input (on interrupt) and normal exit (on task completion).

## Design Decisions
- **Hard kill over soft abort**: Reliable interruption during blocking I/O.
- **Reuses `awaitingTask` flow**: No new code paths for restarting; the user’s next input spawns a fresh brain.
- **Distinguished exits**: The `interrupted` flag keeps the TUI alive only when interruption occurred; normal completions exit gracefully.
- **Plan reference**: `.agent/plans/ESC_Interrupt.md`

## Related Concepts
- [[concepts/task-interruption]] — patterns for aborting long-running agent tasks
- [[concepts/signal-handling]] — asynchronous process management in TUI applications
- [[concepts/tui-brain-communication]] — communication channels between UI and brain process