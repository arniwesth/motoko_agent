---
doc_type: short
full_text: sources/2026-04-06-error-recovery.md
---

# Error Recovery Summary

The runtime now stays alive after AI provider errors (429, 5xx, transport failures) and returns to the conversation loop, enabling follow-up in the same session.

## Core Changes
- **New effect ops** (`aiCallResult`, `aiCallJsonResult`, `aiCallJsonSimpleResult`) return a structured 7-field record on both success and failure, never propagating provider errors as Go errors. See [[concepts/effect-ops]].
- **Error classification** via `classifyAIError()` distinguishes retryable status codes (408, 409, 425, 429, 500, 502, 503, 504) and transport heuristics. The result is exposed as a typed `AIError` in AILANG.
- **Retry with exponential backoff** added in `core/rpc.ail`: pure functions for wait time calculation (`retry_wait_ms` with cap), configurable via env vars `AI_MAX_RETRIES`, `AI_RETRY_BASE_MS`, `AI_RETRY_CAP_MS`. On terminal failure a JSONL error is emitted and the runtime returns to `conversation_loop`.
- **TUI error handling** improved: `"error"` events keep the runtime live, focus the input, and a crash safety net prevents the process from exiting prematurely when an error occurred.

## AILANG Type System
- New builtins `_ai_call_result`, `_ai_call_json_result`, `_ai_call_json_simple_result` are gated with `RequireCapWithBudget("AI", "")` and return a new record type.
- Wrappers in `std/ai.ail` map the Go record to `Result[string, AIError]` using the `std/result` module, providing a functional error pattern. [[concepts/result-type]]

## Backoff Implementation
- Pure helpers (`int_min`, `pow2`) with inline tests ensure correct exponential growth capped at 30s.
- `read_retry_config()` re-reads env vars on each call, allowing hot changes without restart, though it could be cached.
- The retry path replaces the old `call(...)` in `rpc_loop`. See [[concepts/exponential-backoff]].

## Known Limitations
- No Go unit tests; AILANG inline tests cover the backoff math.
- `409 Conflict` and `425 Too Early` are included as retryable but may trigger false positives for LLM APIs.
- Retry config is re-read from env every step – a minor performance consideration.

## Related Work
- Structured error handling across the runtime: [[concepts/error-handling-runtime]]
- AI provider failure modes: [[concepts/ai-provider-errors]]
- State-safe conversations after failure: [[concepts/runtime-resilience]]