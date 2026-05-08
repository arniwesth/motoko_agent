---
doc_type: short
full_text: sources/2026-04-27-tui-session-logging-and-markdown-transcript.md
---

# Summary: TUI Session Logging + Markdown Transcript

This document details the implementation of session logging and human-readable markdown transcripts for TUI sessions, extending the existing plan @ `TUI_Session_Logging.md`.

## Key Implementation

- **SessionLogger** (`src/tui/src/session-logger.ts`): Creates per-session JSONL logs (`logfile/session_<timestamp>.jsonl`) from all `AgentEvent` records. Idempotent close on all exit paths.
- **Markdown Transcript**: Extended the logger to also write `logfile/session_<timestamp>.md` with timestamped line-based output (`[hh:mm:ss.mmm] > ...`, reasoning lines, etc.), matching the TUI history pane.
- **Pipeline Integration**: Wired the logger into both non‑TTY (`PlainLogger`) and TTY (`AgentUI`) flows in `src/tui/src/index.ts`, with proper lifecycle management (one logger per spawned session, added close handling).
- **Duplicate Answer Fix**: Introduced `streamedSteps` tracking in the logger. When a step already has streamed output, the final `thinking` event is suppressed to avoid duplicated answers – mirroring the TUI’s own `shouldRenderThinkingAfterStream` logic.
- **Git Ignore**: Added `logfile/` to `.gitignore`.

## Validation

Build (`npm run build`) and tests (`17 suites, 92 tests`) passed. Manual synthetic check confirmed paired `.jsonl`/`.md` file creation and correct transcript formatting.

## Files Changed

- `src/tui/src/session-logger.ts` (new, extended for markdown + deduplication)
- `src/tui/src/index.ts`
- `.gitignore`

## Cross-Document Themes

- [[concepts/session-logging]] – general approach for logging agent runtime events.
- [[concepts/tui-markdown-transcript]] – human-readable markdown output from a terminal UI.
- [[concepts/stream-deduplication]] – preventing duplicate content when both streaming and final events exist.
- [[concepts/event-pipeline-integration]] – wiring lifecycle-aware components into the agent event flow.