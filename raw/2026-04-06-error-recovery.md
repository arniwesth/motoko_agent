# Error Recovery — Structured AI Errors + Retry with Backoff

**Branch:** `Error_Recovery_Idle_Mode`
**Plan:** `.agent/plans/Error_Recovery_Runtime_Merged_Best_Plan.md`

## What was done

Implemented the full merged error recovery plan. AI provider failures (429, 5xx, transport errors) no longer crash the runtime process. The runtime stays alive after an error and returns to `conversation_loop` so the user can follow up in the same session.

## Files changed

### `ailang/internal/effects/ai.go`
- Added `retryableStatuses` map: 408, 409, 425, 429, 500, 502, 503, 504.
- Added `classifyAIError()`: uses `errors.As(*ai.ProviderError)` first (picks up status code and provider name), then falls back to string heuristics for transport errors (`timeout`, `connection reset`, `eof`, `connection refused`).
- Added `makeAIResultRecord()`: builds a 7-field record `{ok, output, error_message, provider, status_code, retryable, error_code}`.
- Added three new effect ops — `aiCallResult`, `aiCallJsonResult`, `aiCallJsonSimpleResult` — that return the record on both success and failure. Provider errors are **never** propagated as Go errors; only arity/type misuse returns Go errors.
- Registered all three in `init()`.

### `ailang/internal/builtins/ai.go`
- Added `aiResultRecordType()` and three `make*Type` functions for the type system.
- Registered `_ai_call_result`, `_ai_call_json_result`, `_ai_call_json_simple_result` builtins with standard `RequireCapWithBudget("AI", "")` gating, delegating to the new effect ops.

### `ailang/std/ai.ail`
- Added `import std/result (Result, Ok, Err)`.
- Added `export type AIError = {message, provider, statusCode, retryable, code}`.
- Added `callResult`, `callJsonResult`, `callJsonSimpleResult` wrappers that map the Go record to `Result[string, AIError]`.
- Existing `call`, `callJson`, `callJsonSimple` unchanged (backward compatible).

### `core/rpc.ail`
- Changed import from `call` to `callResult, AIError`.
- Added pure helpers with inline tests:
  - `int_min(a, b)` — 5 tests
  - `pow2(n)` — 8 tests covering cap boundary at n=30
  - `retry_wait_ms(base, cap, attempt)` — 11 tests covering full backoff curve and cap behaviour
- Added `read_retry_config()`: reads `AI_MAX_RETRIES` (default 3), `AI_RETRY_BASE_MS` (1000), `AI_RETRY_CAP_MS` (30000) from env on each call (env vars take effect mid-session).
- Added `ai_call_with_retry()`: exponential backoff loop `min(base × 2^attempt, cap)`. On terminal failure emits `{type:"error", message:...}` JSONL and returns `state2` so the runtime falls through to `conversation_loop`.
- Replaced `let response = call(...)` in `rpc_loop` with the retry path. 24 inline tests total, all passing.

### `tui/src/ui.ts`
- `"error"` case: `chalk.red` → `chalk.redBright`, sets `taskDone = true`, refocuses `cmdInput`. Next plain-text input routes to `sendUserMessage` in the live runtime instead of spawning a new process.

### `tui/src/index.ts`
- Added `errorOccurred` flag, set on any `error` event, reset on spawn.
- Exit callback: if `errorOccurred` is true, calls `setAwaitingTask(true)` instead of `process.exit(0)` — crash safety net for the narrow window where the process exits after emitting an error before the user responds.

## Known limitations / follow-up
- `read_retry_config()` is called per step (cheap, but re-reads env every LLM call). Could be cached in state or read once in `main()` if this becomes measurable.
- `409 Conflict` and `425 Too Early` are in the retryable set — these are uncommon for LLM APIs and could be narrowed if false positives appear.
- No Go-layer unit tests (intentionally skipped per user instruction). AILANG inline tests cover the pure retry math.
- `ai_call_with_retry` effect signature is `! {AI, Clock}` — correct. The outer `rpc_loop` effect set already includes both.
