---
doc_type: short
full_text: sources/Error_Recovery_Runtime_Fix.md
---

# Error Recovery Runtime Fix

## Problem
AILANG runtime crashes on AI API errors (e.g. rate‑limit, 5xx) because `call()` in `std/ai` returns a bare string without error wrapping, and no error handling exists around the call in `core/rpc.ail`. The process exits, breaking the TUI and discarding conversation history.

## Solution Overview
This plan eliminates process crashes by:
- Introducing a new Go effect operation **`callResult`** that returns a structured record (`ok`, `output`, `error_message`, `status_code`, `retryable`, …) instead of throwing.
- Adding a typed wrapper in `std/ai` (`callResult` returning `Result[string, AIError]`).
- Implementing configurable retry‑with‑backoff **purely in AILANG** (`core/rpc.ail`), separating retry policy from mechanism.
- Updating the TUI to log errors in bright red and stay alive, preserving conversation history.

## Key Changes

### 1. Go Effect Operation (`ailang/internal/effects/ai.go`)
- New `callResult` op classified as AI effect.
- Error classification: retryable status codes (408, 409, 425, 429, 500, 502, 503, 504) and transient transport errors get `retryable=true`; everything else is non‑retryable.
- Always returns a record – never a Go error – so the interpreter never panics on provider failures.

### 2. AILANG Standard Library (`ailang/std/ai.ail`)
- New type `AIError` with `message`, `provider`, `statusCode`, `retryable`, `code`.
- `callResult` function wrapping the built‑in to produce `Result[string, AIError]`.
- Existing `call`, `callJson` remain unchanged for backward compatibility.

### 3. Core Retry Logic (`core/rpc.ail`)
- Replaces `import std/ai (call)` with `callResult` and adds `ai_call_with_retry` recursive helper.
- Reads environment variables for max retries (`AI_MAX_RETRIES`, default 3), base delay (`AI_RETRY_BASE_MS`, default 1000), and cap (`AI_RETRY_CAP_MS`, default 30000).
- On `Ok(response)`, proceeds as before. On `Err(e)`, if `e.retryable` and attempts remain, waits with exponential backoff (`base * 2^attempt`, capped) and retries. Otherwise emits a JSONL `error` event and returns the current state, allowing `conversation_loop` to continue.

### 4. TUI Error Handling (`tui/src/ui.ts`, `tui/src/index.ts`)
- `error` event logs the message in bright red, sets run state to `"error"`, and marks `taskDone = true` so the next user input goes to `sendUserMessage` (not spinning a new process).
- `index.ts` tracks `errorOccurred` flag to handle clean shutdown vs. crash recovery: if an error occurred and the process exits, TUI re‑sets `awaitingTask` to spawn a fresh process for the next command.

## Design Principles
- **Separation of mechanism and policy**: Go merely classifies errors; AILANG decides retry behaviour – visible, configurable, not buried in Go.
- **No process crash**: The runtime always stays alive; errors become JSONL events.
- **History preservation**: Retries happen within the same long‑running process; no re‑spawn, no loss of conversation.

## Relevant Concepts
- [[concepts/error-recovery-in-runtime]]
- [[concepts/retry-with-backoff]]
- [[concepts/structured-error-handling]]
- [[concepts/AILANG-effect-system]]
- [[concepts/TUI-error-display]]

## Testing Focus
- 429 / 5xx retry silently, then surface error; TUI stays responsive.
- Successful retry on a later attempt produces normal output, no user‑visible error.
- Non‑retryable errors (401, 400) immediately surface.
- `AI_MAX_RETRIES=0` disables retries.
- Conversation history intact after error.
- Existing behaviours (ESC, normal exit, `/abort`, step limit) remain unchanged.