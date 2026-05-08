# 2026-04-27 — TUI Session Logging + Markdown Transcript

## Goal
Implement `.agent/plans/TUI_Session_Logging.md` and extend it so each TUI session also produces a human-readable markdown transcript that mirrors what users see in the history pane.

## What Was Implemented

### 1. Session JSONL logging
- Added `SessionLogger` in `src/tui/src/session-logger.ts`.
- Per session, creates `logfile/` under project root (if missing).
- Writes all `AgentEvent` records to timestamped JSONL:
  - `logfile/session_<timestamp>.jsonl`
- Logger close is idempotent and called on all runtime exit paths.

### 2. Integration in runtime event pipeline
- Wired logger in `src/tui/src/index.ts` for both:
  - non-TTY (`PlainLogger`) flow
  - TTY (`AgentUI`) flow
- Added lifecycle handling so each spawned runtime session gets its own logger.
- Added close handling in event path and exit callback to avoid leaks.

### 3. Markdown transcript output (new extension)
- Extended `SessionLogger` to also write:
  - `logfile/session_<timestamp>.md`
- Transcript format is timestamped line-based text, matching TUI history style:
  - `[hh:mm:ss.mmm] > ...`
  - `[hh:mm:ss.mmm] Runtime is reasoning...`
  - version/extensions lines from `session_start`
  - model output lines from thinking/streaming events
- Added `logUserInput(...)` and integrated it in `index.ts` so user prompts are captured in the transcript.

### 4. Duplicate answer fix
Issue observed: answers appeared twice in markdown transcript.

Root cause:
- Runtime emits streamed tokens (`thinking_stream_*`) and then a final `thinking` event with same content.
- Logger initially recorded both.

Fix:
- Added `streamedSteps` tracking in `SessionLogger`.
- If a step has streamed output, logger skips `thinking` text for that step.
- This now matches the TUI’s own `shouldRenderThinkingAfterStream(...)` behavior.

### 5. Git ignore
- Added `logfile/` to `.gitignore`.

## Validation Performed
- `cd src/tui && npm run build` passed.
- `cd src/tui && npm test` passed (`17` suites, `92` tests).
- Manual synthetic logger check confirmed paired file creation (`.jsonl` + `.md`) and expected transcript line format.

## Files Changed
- `src/tui/src/session-logger.ts` (new, then extended for markdown transcript + dedupe)
- `src/tui/src/index.ts`
- `.gitignore`
