# Plan: Error Recovery — Merged Runtime Fix (Best Version)

## Purpose

Fix AI error handling at the runtime/core layer so provider failures (including 429) do not crash the process, while preserving conversation continuity and keeping retry policy in AILANG.

This merged plan uses the updated runtime-fix plan as the base and adds missing pieces for correctness and long-term API consistency.

---

## Why this is the best plan now

- Prevents process crashes on AI provider errors by returning structured error values from runtime AI ops.
- Implements retry/backoff in `core/rpc.ail` (policy lives in AILANG, configurable by env).
- Preserves conversation history by staying in the same runtime process and returning to `conversation_loop`.
- Keeps existing `std/ai.call*` behavior unchanged for backward compatibility.
- Adds complete builtin registration and safe API surface (`callResult`, `callJsonResult`, `callJsonSimpleResult`).

---

## Files to Modify

| File | Change |
|------|--------|
| `ailang/internal/effects/ai.go` | Add `callResult`, `callJsonResult`, `callJsonSimpleResult` effect ops returning structured records |
| `ailang/internal/builtins/ai.go` | Register `_ai_call_result`, `_ai_call_json_result`, `_ai_call_json_simple_result` builtins |
| `ailang/std/ai.ail` | Add `AIError` type + wrappers `callResult`, `callJsonResult`, `callJsonSimpleResult` |
| `core/rpc.ail` | Use Result-based AI calls + configurable retry/backoff |
| `tui/src/ui.ts` | Bright red error display; route next input as follow-up in live runtime |
| `tui/src/index.ts` | Crash safety net for unexpected process exit after error |

---

## 1) Runtime AI ops: structured error records (no crash path)

### File
`ailang/internal/effects/ai.go`

### Add ops
- `AI.callResult`
- `AI.callJsonResult`
- `AI.callJsonSimpleResult`

Register in `init()` alongside existing AI ops.

### Return contract (record)

```ailang
{
  ok: bool,
  output: string,
  error_message: string,
  provider: string,
  status_code: int,
  retryable: bool,
  error_code: string
}
```

Semantics:
- `ok=true`: success, `output` populated.
- `ok=false`: failure fields populated, `output=""`.
- Provider/API failures are returned as `(record, nil)`; do not return Go error for these.
- Type errors/arity errors may still return Go errors as internal programmer misuse.

### Classification (robust)

Use typed extraction first, then fallback heuristics.

- First attempt: `errors.As(err, *ai.ProviderError)`
  - `status_code = providerErr.StatusCode`
  - `provider = providerErr.Provider`
  - `retryable = isRetryableStatus(status_code)`
  - `error_code = "HTTP_<status>"` when status > 0
- Fallback:
  - transient transport text (`timeout`, `connection reset`, `EOF`) => `retryable=true`, `error_code="E_TRANSPORT"`
  - else `retryable=false`, `error_code="E_UNKNOWN"`

Retryable status set:
- `408, 409, 425, 429, 500, 502, 503, 504`

---

## 2) Builtin registration (required)

### File
`ailang/internal/builtins/ai.go`

Add registrations in `init()`:
- `registerAICallResult()` for `_ai_call_result`
- `registerAICallJsonResult()` for `_ai_call_json_result`
- `registerAICallJsonSimpleResult()` for `_ai_call_json_simple_result`

Each should:
- Require AI capability budget (`ctx.RequireCapWithBudget("AI", "")`)
- Delegate to effects op via `effects.Call(ctx, "AI", "callResult", args)` etc.

Type signatures:
- `_ai_call_result: (string) -> {ok:bool,...} ! {AI}`
- `_ai_call_json_result: (string, string) -> {ok:bool,...} ! {AI}`
- `_ai_call_json_simple_result: (string) -> {ok:bool,...} ! {AI}`

Note: Do not rely on effects registration alone for underscore builtin availability; builtins are registered through `internal/builtins/*` in this runtime layout.

---

## 3) Stdlib wrappers

### File
`ailang/std/ai.ail`

Add:

```ailang
export type AIError = {
  message: string,
  provider: string,
  statusCode: int,
  retryable: bool,
  code: string
}
```

Add wrappers:
- `callResult(input) -> Result[string, AIError] ! {AI}`
- `callJsonResult(input, schema) -> Result[string, AIError] ! {AI}`
- `callJsonSimpleResult(input) -> Result[string, AIError] ! {AI}`

Mapping:
- `r.ok == true` => `Ok(r.output)`
- else => `Err({...})` from record fields

Keep existing:
- `call`, `callJson`, `callJsonSimple` unchanged.

---

## 4) Core retry policy in AILANG

### File
`core/rpc.ail`

Replace direct `call(...)` with `callResult(...)` path.

Imports:
- `import std/ai (callResult, AIError)`

### Retry config env vars
- `AI_MAX_RETRIES` default `3`
- `AI_RETRY_BASE_MS` default `1000`
- `AI_RETRY_CAP_MS` default `30000`

### Important semantics
- `AI_MAX_RETRIES=0` must mean **no retries**.
- Therefore use `clamp_non_negative` for retries, not `clamp_positive`.

### Helper functions (implement explicitly; do not use nonexistent builtins)
Add pure helpers such as:
- `int_min(a, b)`
- `pow2(n)` via recursion
- `retry_wait_ms(base, cap, attempt)`

No `_int_min` / `_int_pow2` assumptions.

### Retry helper

```ailang
func ai_call_with_retry(...)-> Result[string, AIError] ! {AI, Clock, Env}
```

Flow:
1. `callResult(input)`
2. If `Ok` => continue normal step
3. If `Err(e)` and `e.retryable && attempt < maxRetries` => sleep(backoff), recurse
4. Else emit JSONL error and return current state

On terminal error:
- emit `{type:"error", message:e.message}`
- return `state2` so runtime remains alive and falls through to `conversation_loop`

---

## 5) TUI behavior adjustments

### `tui/src/ui.ts`
In `error` case:
- use `chalk.redBright`
- set `taskDone = true`
- focus command input

Reason: runtime is still alive; next input should route to `sendUserMessage` rather than spawning a second runtime.

### `tui/src/index.ts`
Keep crash safety net:
- track `errorOccurred`
- if process exits after error, set `awaitingTask(true)` so next task spawns fresh process

This is fallback only; normal path should remain live in-process.

---

## Backoff Policy

| Env var | Default | Meaning |
|---|---:|---|
| `AI_MAX_RETRIES` | `3` | Number of retries after first failure |
| `AI_RETRY_BASE_MS` | `1000` | Base wait |
| `AI_RETRY_CAP_MS` | `30000` | Maximum wait |

Formula:
- `wait = min(base * 2^attempt, cap)`
- Optional jitter can be added deterministically from `std/clock.now()` if needed.

---

## Compatibility

- Backward compatible for existing `std/ai.call*` consumers.
- New safe APIs are additive.
- No mandatory JSONL protocol changes.

---

## Test Plan

### Runtime/effects unit tests
- 429 -> `ok=false`, `status_code=429`, `retryable=true`
- 503 -> retryable true
- 401/403/404 -> retryable false
- transport timeout/reset -> retryable true
- success -> `ok=true` with output

### Builtins tests
- `_ai_call_result` and JSON variants resolve and return expected record shape
- capability gating preserved

### stdlib tests
- wrappers map record -> `Result[string, AIError]` correctly

### core integration
- transient 429 then success -> in-process recovery, no crash
- repeated retryable failures exhaust -> one error event, runtime stays alive
- `AI_MAX_RETRIES=0` -> immediate surface, no retry

### TUI smoke
- error shown in bright red
- follow-up after error routes through `user_message` in same runtime
- unexpected crash path still recoverable via awaiting-task spawn
- normal completion/abort unchanged

---

## Acceptance Criteria

- AI provider errors no longer crash the runtime process.
- Retry behavior is configurable via env and respects `AI_MAX_RETRIES=0`.
- Terminal AI errors emit JSONL `error` and runtime remains interactive in `conversation_loop`.
- `std/ai.call*` unchanged; new safe wrappers available.
- All affected modules type-check/build and TUI behavior remains coherent.
