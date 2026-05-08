---
doc_type: short
full_text: sources/TUI_Session_Logging.md
---

## Motivation

The AILANG TUI currently logs no agent events to disk, only passing them to the UI via callbacks. A session log provides a persistent, human-readable record of every agent run for debugging, review, and future analysis. This document outlines the implementation plan.

## Approach

A new `SessionLogger` class in `src/tui/src/session-logger.ts` handles file I/O:

- Creates a `logfile/` directory under the project root (with `mkdirSync`).
- Opens a write stream to a **timestamped JSONL file** (e.g., `logfile/session_2026-04-27T14-30-00-000Z.jsonl`).
- Exposes `log(event)` to write JSON lines and `close()` to flush/close.

### Integration into the Event Pipeline

- **Non-TTY path**: Logger instance created before spawning the runtime process; all events logged before UI handling; logger closed on exit callback.
- **TTY path** (`spawnRuntimeProcess`): Logger created per task call, logged in the event callback, and closed in **all three exit branches** (interrupted, error recovery, normal exit). Each new task gets its own log file.

## Key Design Decisions

- **JSONL format** – one JSON object per line, matching the runtime’s own protocol and easy to parse or grep.
- **Timestamped filenames** – avoid collisions and allow easy chronological sorting.
- **Per-task logging** – each call to `spawnRuntimeProcess` creates a fresh logger, ensuring every agent interaction is recorded separately.
- **Sync filesystem ops** – `mkdirSync` and write streams are used for simplicity given the Node.js environment.

## Files Affected

| File | Change |
|------|--------|
| `src/tui/src/session-logger.ts` | **New.** `SessionLogger` class. |
| `src/tui/src/index.ts` | Import and wire logger before UI handling; close on exit. |
| `.gitignore` | Add `logfile/` entry to keep logs local. |

## Related Concepts

- [[concepts/tui-session-logging]] – General concept of persistent session recording in terminal UIs.
- [[concepts/agent-events]] – The `AgentEvent` type that flows from the runtime and is logged.
- [[concepts/jsonl-logging]] – Tradeoffs and benefits of JSONL as a logging format.

## Verification Steps

1. Build TypeScript: `cd src/tui && npm run build`.
2. Run a short session to confirm `logfile/session_*.jsonl` is created with valid JSON.
3. Ensure existing tests (`npm test`) still pass.