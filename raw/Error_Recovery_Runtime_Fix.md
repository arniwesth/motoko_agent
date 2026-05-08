# Plan: Error Recovery — Fix Root Cause in AILANG Runtime

## Files modified

| File | Status |
|------|--------|
| `ailang/internal/effects/ai.go` | Modified |
| `ailang/std/ai.ail` | Modified |
| `core/rpc.ail` | Modified |
| `tui/src/ui.ts` | Modified |
| `tui/src/index.ts` | Modified |

## Problem

When the AILANG runtime gets an AI API error (e.g. 429 rate-limit), the process crashes. The TUI then exits.

### Root cause

`call()` in `std/ai` returns a bare `string` — no `Result` wrapping. There is no error handling around `call(fmt_msgs(...))` at `core/rpc.ail:577`. When the AI API returns any error, the AILANG interpreter throws an unhandled exception that crashes the process. The crash message goes to stderr (`"inherit"` in `runtime-process.ts`), bypassing the JSONL pipe entirely.

### Why this plan is preferable to the TUI-only plan

- The runtime **never crashes** on AI errors — it emits a proper `error` JSONL event and falls through to `conversation_loop`, keeping the session alive with full conversation history intact
- Retry-with-backoff happens inside the long-running process — no full respawn, no lost history
- Retry policy lives in AILANG (`core/rpc.ail`), visible and configurable — not buried in Go
- `tui/src/runtime-process.ts` is untouched — stderr stays inherited, no synthetic event hacks

---

## Goal

- The AILANG runtime does not crash on AI call errors; it emits a proper `error` JSONL event and continues into `conversation_loop`
- Retryable errors (429, 500, 502, 503, 504, transient transport) are retried with exponential backoff + jitter in `core/rpc.ail` before surfacing as an error
- The TUI logs errors in bright red and returns to idle/awaiting-task mode
- Conversation history is preserved across retries

---

## Changes

### 1. `ailang/internal/effects/ai.go` — add `aiCallResult` op

Register a new effect operation `callResult` that returns a structured result record instead of a Go error. This separates mechanism (Go classifies the error) from policy (AILANG decides retry behaviour).

The record shape:

```go
// Returned for both success and failure — never returns a Go error for provider failures.
// ok=true:  output is populated, error fields are zero values.
// ok=false: error fields are populated, output is empty.
{
  ok:            bool
  output:        string
  error_message: string
  provider:      string
  status_code:   int
  retryable:     bool
  error_code:    string
}
```

Retryable status codes: `408, 409, 425, 429, 500, 502, 503, 504` and transient transport failures (connection reset, timeout). Non-retryable: auth errors, invalid request, model-not-found.

```go
func init() {
    // existing registrations ...
    RegisterOp("AI", "callResult", aiCallResult)
}

func aiCallResult(ctx *EffContext, args []eval.Value) (eval.Value, error) {
    if len(args) < 1 {
        return makeErrRecord("callResult: expected 1 argument", "", 0, false, ""), nil
    }
    input, ok := args[0].(*eval.StringValue)
    if !ok {
        return makeErrRecord("callResult: expected string input", "", 0, false, ""), nil
    }
    if ctx.AI == nil {
        return makeErrRecord(ErrNoAIHandler.Error(), "", 0, false, "E_NO_HANDLER"), nil
    }
    output, err := ctx.AI.Call(input.Value)
    if err == nil {
        return makeOkRecord(output), nil
    }
    statusCode, retryable, code := classifyAIError(err)
    return makeErrRecord(err.Error(), inferProvider(err), statusCode, retryable, code), nil
}

func isRetryableStatus(code int) bool {
    switch code {
    case 408, 409, 425, 429, 500, 502, 503, 504:
        return true
    }
    return false
}

func classifyAIError(err error) (statusCode int, retryable bool, code string) {
    msg := err.Error()
    // Extract HTTP status code from error message (providers include it)
    for _, candidate := range []int{408, 409, 425, 429, 500, 502, 503, 504, 401, 403, 404, 400} {
        if strings.Contains(msg, strconv.Itoa(candidate)) {
            return candidate, isRetryableStatus(candidate), fmt.Sprintf("HTTP_%d", candidate)
        }
    }
    // Transient transport errors
    if strings.Contains(msg, "timeout") || strings.Contains(msg, "connection reset") ||
        strings.Contains(msg, "EOF") {
        return 0, true, "E_TRANSPORT"
    }
    return 0, false, "E_UNKNOWN"
}
```

Helper constructors build `eval.RecordValue` fields. Add imports: `"strconv"`, `"strings"`, `"fmt"`.

### 2. `ailang/std/ai.ail` — add `AIError` type and `callResult` wrapper

Add an exported error type and a wrapper that maps the Go record to `Result[string, AIError]`:

```
export type AIError = {
  message:    string,
  provider:   string,
  statusCode: int,
  retryable:  bool,
  code:       string
}

-- callResult: safe variant of call — returns Result instead of throwing.
-- Retryable errors (429, 5xx, transport) have retryable=true in the Err payload.
export func callResult(input: string) -> Result[string, AIError] ! {AI} {
  let r = _ai_call_result(input);
  if r.ok
  then Ok(r.output)
  else Err({
    message:    r.error_message,
    provider:   r.provider,
    statusCode: r.status_code,
    retryable:  r.retryable,
    code:       r.error_code
  })
}
```

Existing `call`, `callJson`, `callJsonSimple` are unchanged.

### 3. `core/rpc.ail` — retry in AILANG with configurable backoff

Replace `import std/ai (call)` with `import std/ai (callResult, AIError)`. Add `import std/clock (sleep)` (already present). Read retry config from env.

Add a retry helper:

```
func ai_call_with_retry(
  input: string,
  max_retries: int,
  base_ms: int,
  cap_ms: int,
  attempt: int
) -> Result[string, AIError] ! {AI, Clock, Env} {
  match callResult(input) {
    Ok(response) => Ok(response),
    Err(e) =>
      if e.retryable && attempt < max_retries then {
        let wait = clamp_non_negative(
          _int_min(base_ms * _int_pow2(attempt), cap_ms)
        );
        let _ = sleep(wait);
        ai_call_with_retry(input, max_retries, base_ms, cap_ms, attempt + 1)
      } else
        Err(e)
  }
}
```

In `rpc_loop`, replace the bare `call(...)` and its tail with a match on `ai_call_with_retry`. Read config from env at the top of `rpc_loop`:

```
let max_retries = clamp_positive(parse_env_int("AI_MAX_RETRIES",    3),  3);
let base_ms     = clamp_positive(parse_env_int("AI_RETRY_BASE_MS",  1000), 1000);
let cap_ms      = clamp_positive(parse_env_int("AI_RETRY_CAP_MS",   30000), 30000);

let _ = if step_delay > 0 then sleep(step_delay) else ();
match ai_call_with_retry(fmt_msgs(state2.msgs), max_retries, base_ms, cap_ms, 0) {
  Err(e) => {
    let _ = emit(encode(jo([
      kv("type",    js("error")),
      kv("message", js(e.message))
    ])));
    state2
  },
  Ok(response) => {
    let msgs1 = state2.msgs ++ [{ role: "assistant", content: response }];
    let _ = emit(encode(jo([
      kv("type", js("thinking")),
      kv("step", jnum(_int_to_float(state2.step))),
      kv("text", js(response))
    ])));
    if hybrid_enabled
    then run_hybrid_step(state2, model2, response, msgs1, depth, step_delay, hybrid_enabled)
    else run_legacy_step(state2, model2, response, msgs1, depth, step_delay, hybrid_enabled)
  }
}
```

On `Err`, `state2` is returned and falls through to `conversation_loop` — runtime stays alive.

`Ok` and `Err` are already imported. `AIError` is imported from `std/ai`.

### 4. `tui/src/ui.ts` — bright red error, return to idle

```ts
case "error":
  this.setRunState("error");
  this.appendHistoryStyled(`Error: ${event.message}`, chalk.redBright);
  this.taskDone = true;   // route next input to sendUserMessage, not spawnRuntimeProcess
  this.tui.setFocus(this.cmdInput);
  break;
```

`taskDone = true` because the runtime is still alive in `conversation_loop` — the next user input must go to `sendUserMessage`, not spawn a new process.

### 5. `tui/src/index.ts` — safety net for unexpected crashes

```ts
let errorOccurred = false;

(event) => {
  if (event.type === "error") errorOccurred = true;
  ui.handleEvent(event);
}

() => {
  ui.runtimeProcess = undefined;
  if (interrupted) {
    interrupted = false;
    ui.setAwaitingTask(true);
  } else if (errorOccurred) {
    errorOccurred = false;
    ui.setAwaitingTask(true);  // process exited: next task must spawn fresh
  } else {
    ui.stop();
    process.exit(0);
  }
}
```

---

## Backoff parameters

| Env var | Default | Purpose |
|---------|---------|---------|
| `AI_MAX_RETRIES` | `3` | Max retry attempts before surfacing error |
| `AI_RETRY_BASE_MS` | `1000` | Base wait in ms (`base * 2^attempt`) |
| `AI_RETRY_CAP_MS` | `30000` | Maximum wait cap in ms |

Note: jitter is not added at this layer — `sleep()` in AILANG takes an int ms. If jitter is desired it can be derived from `std/clock.now() mod cap` without adding an RNG dependency.

---

## Files NOT touched

- `ailang/internal/builtins/ai.go` — `_ai_call_result` is registered via `effects/ai.go`'s `init()`; no separate builtin spec needed if the record type is handled inline
- `tui/src/runtime-process.ts` — stderr stays inherited; no synthetic event hacks needed
- `PlainLogger` — `process.exit(1)` on error remains correct for non-TTY/CI

---

## Test cases to verify

1. 429 from rate-limited model → runtime retries up to 3 times (silently), then emits `error` JSONL; TUI shows bright red, stays alive
2. Successful retry on second attempt → no error shown, task continues normally with history intact
3. 503 upstream error → retried (retryable=true); 401 auth error → not retried (retryable=false)
4. `AI_MAX_RETRIES=0` → no retries, immediate error surface
5. User submits follow-up after error → `conversation_loop` receives `user_message`, new `rpc_loop` with history intact
6. ESC during a running task → existing behaviour unchanged
7. Normal task completion → TUI exits cleanly
8. `/abort` → TUI exits cleanly
9. Step limit reached → controlled `error` JSONL, same TUI recovery
