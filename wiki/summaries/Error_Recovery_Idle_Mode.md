---
doc_type: short
full_text: sources/Error_Recovery_Idle_Mode.md
---

# Error Recovery — Idle Mode

## Overview

This plan ensures the TUI survives AI runtime crashes (e.g., API errors) without exiting. It intercepts stderr via the JSONL event pipe, retries rate‑limited (429) requests with exponential backoff + jitter, and gracefully returns to idle mode for all other errors. The constraint is to modify only `tui/` (not `ailang/` or `core/`).

## Problem

- The AILANG interpreter's `call()` in `std/ai` returns a plain `string`, not a `Result`.  
- An unhandled exception from an AI API error (e.g., `429`) crashes the process.  
- stderr goes directly to the terminal (`"inherit"`), bypassing the JSONL pipe, so the TUI only sees a process exit and shuts down.  
- See [[concepts/runtime-process-management]] for how the process is spawned and monitored.

## Constraint

All fixes must stay in `tui/`; the AILANG runtime (`ailang/`) and `core/` are off‑limits. The crash cannot be prevented from within AILANG code, so recovery is handled entirely at the TUI layer.

## Goal

1. **TUI never exits** on a runtime crash (except normal completion).
2. **429 errors**: retry up to 3 times with exponential backoff (full jitter), showing a countdown in the history pane.
3. **Non‑429 errors**: log in bright red, switch TUI to idle (awaiting a new task).
4. User can abort a running task or a pending retry.

## Changes

### 1. Route stderr through the pipe (`runtime-process.ts`)

- Change `stdio` to `["pipe", "pipe", "pipe"]` (previously stderr was `"inherit"`).
- Buffer stderr content, and on process exit emit a **synthetic `error` event** via the existing JSONL event stream.  
- This turns a terminal crash into a structured event the TUI can handle.

### 2. Retry logic and idle fallback (`index.ts`)

- Track `currentTask` (the submitted prompt) so it can be re‑submitted on retry.
- Intercept `error` events: if the message contains `"429"` or `"rate limit"` and `retryCount < 3`, schedule a retry with exponential backoff (full jitter).  
- On exit, if no retry is pending, set the UI to idle.  
- Cancel any pending retry on abort or interrupt.

Helper backoff parameters:
```
attempt 1: random(0ms, 1000ms) + 500ms
attempt 2: random(0ms, 2000ms) + 500ms
attempt 3: random(0ms, 4000ms) + 500ms
```
This mirrors Anthropic/OpenAI SDK defaults; see [[concepts/rate-limit-retry]].

### 3. Visual feedback (`ui.ts`)

- **Error event**: append error message in `chalk.redBright` and restore input focus.
- **Retry countdown**: new `appendRetryCountdown` method shows a yellow `"Rate limited. Retry X/3 in Ys..."` message.

## Files Modified

| File | Change |
|------|--------|
| `tui/src/runtime-process.ts` | Pipe stderr; emit synthetic error event on exit |
| `tui/src/index.ts` | Task tracking, retry with backoff, idle fallback |
| `tui/src/ui.ts` | Bright red error styling, retry countdown display |

## Files Not Touched

- `core/` – no changes required
- `ailang/` – explicitly out of scope
- `PlainLogger` – remains correct for non‑TTY/CI (exits on error)

## Future Work

Adding a `_ai_call_result` builtin to `ailang/internal/effects/ai.go` that returns a `Result[string]` would allow `core/rpc.ail` to catch errors without crashing, keeping conversation history intact across retries. This is out of scope for the current plan but would eliminate the need for full process respawns (see [[concepts/error-recovery]]).

## Related Concepts

- [[concepts/runtime-process-management]] – spawn and lifecycle of the runtime process
- [[concepts/tui-event-loop]] – JSONL event handling in the TUI
- [[concepts/rate-limit-retry]] – exponential backoff patterns
- [[concepts/error-recovery]] – future improvements for in‑process resilience
