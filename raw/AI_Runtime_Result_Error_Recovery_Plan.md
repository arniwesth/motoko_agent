# Plan: Runtime-Level AI Error Recovery via Result-Returning AI Ops

## Purpose

Enable `core/rpc.ail` to handle provider failures (including 429 rate limits) as values instead of process-killing runtime errors.

This plan intentionally introduces a runtime/API-surface enhancement in `ailang/` and then adopts it from `core/`.

---

## Goals

- Keep the runtime process alive on AI provider failures.
- Allow `core/rpc.ail` to branch on retryable vs non-retryable AI errors.
- Support bounded retry with backoff in AILANG code (`core/rpc.ail`).
- Preserve backward compatibility for existing `std/ai.call*` users.

---

## Non-Goals

- No changes to existing plan files.
- No mandatory protocol shape changes for TUI JSONL events.
- No removal of existing throwing AI operations (`call`, `callJson`, `callJsonSimple`).

---

## Design Summary

Add new AI effect operations that return a structured result record instead of returning Go errors for provider failures.

Then add `std/ai` wrappers that expose those operations as `Result[...]` values so `core/rpc.ail` can implement retry logic in-language.

### Key Principle

- Existing AI ops: **throw on provider failure** (current behavior, unchanged).
- New AI ops: **return `{ok: false, ...}` on provider failure**.

---

## Files to Add/Modify

### Runtime (AILANG fork)

1. `ailang/internal/effects/ai.go`
- Add new operations:
  - `AI.callResult`
  - `AI.callJsonResult`
  - `AI.callJsonSimpleResult`
- Register them in `init()`.
- Return structured records rather than Go errors for provider/API failures.

2. `ailang/std/ai.ail`
- Add Result-based wrappers:
  - `callResult(input: string) -> Result[string, AIError] ! {AI}`
  - `callJsonResult(input: string, schema: string) -> Result[string, AIError] ! {AI}`
  - `callJsonSimpleResult(input: string) -> Result[string, AIError] ! {AI}`
- Add an exported error type for callers.

### Core runtime

3. `core/rpc.ail`
- Replace direct `call(...)` usage in loop with Result-returning API.
- Implement bounded retry + backoff for retryable errors.
- Emit existing `error` JSONL event when retries are exhausted or non-retryable.

---

## Proposed Data Contract for New AI Ops

New builtins return a record with this shape:

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
- `ok = true`: `output` contains model text; error fields may be empty/default.
- `ok = false`: error fields are populated; `output` is empty.
- `status_code = 0` when not applicable/unknown.

Suggested error classification:
- Retryable: `408, 409, 425, 429, 500, 502, 503, 504` and transient transport failures.
- Non-retryable: auth, model-not-found, invalid request schema/payload.

---

## `std/ai` API Additions

In `ailang/std/ai.ail`:

```ailang
export type AIError = {
  message: string,
  provider: string,
  statusCode: int,
  retryable: bool,
  code: string
}
```

Wrappers map the record to `Result`:
- `{ok: true, output: x}` -> `Ok(x)`
- `{ok: false, ...}` -> `Err({...})`

Existing functions remain unchanged:
- `call`, `callJson`, `callJsonSimple` keep current throwing behavior.

---

## `core/rpc.ail` Retry Behavior

Current hot path:
- `let response = call(fmt_msgs(state2.msgs));`

Replace with Result flow:
- `match callResult(fmt_msgs(state2.msgs)) { Ok(response) => ..., Err(e) => ... }`

On `Err(e)`:
1. If `e.retryable` and attempts `< maxRetries`:
- Sleep with exponential backoff.
- Retry same model call.
2. Else:
- Emit existing JSONL `error` event.
- Return control to conversation loop without process crash.

### Backoff Configuration (env)

- `AI_MAX_RETRIES` (default `3`)
- `AI_RETRY_BASE_MS` (default `1000`)
- `AI_RETRY_CAP_MS` (default `30000`)

Backoff formula:
- `wait = min(base * 2^attempt, cap)`
- Optional jitter can be derived from `std/clock.now()` to avoid adding RNG dependencies.

---

## Compatibility & Migration

- Fully backward compatible for existing AILANG programs using `std/ai.call*`.
- `core/rpc.ail` migrates to new `callResult` path.
- TUI protocol does not require mandatory changes for this feature.

---

## Risks

1. Error-shape drift across providers
- Mitigate by centralizing mapping in `internal/effects/ai.go`.

2. Misclassification of retryable errors
- Start with conservative status-based policy, expand with tests.

3. Retry delay tuning
- Expose env controls and keep defaults modest.

---

## Test Plan

### Unit tests (`ailang/internal/effects/ai.go`)

- 429 provider error -> `ok=false`, `status_code=429`, `retryable=true`
- 401 provider error -> `retryable=false`
- transport timeout/network reset -> `retryable=true`
- success path -> `ok=true`, output populated

### Stdlib tests (`ailang/std/ai.ail` wrappers)

- Record-to-`Result` mapping correctness for success and error cases.

### Core integration tests (`core/rpc.ail`)

- transient 429 then success -> retries in-process, no runtime crash
- repeated 429 beyond max -> emits `error` event, process stays alive
- non-retryable auth/model error -> immediate `error` event, no retry

### TUI smoke

- Validate no regression in normal completion, abort, and follow-up behavior.

---

## Rollout Sequence

1. Implement new result-returning AI ops in runtime.
2. Add `std/ai` Result wrappers.
3. Switch `core/rpc.ail` to wrapper-based retries.
4. Run core checks and TUI build/tests.
5. Validate manual failure scenarios (429, invalid key, invalid model).

---

## Acceptance Criteria

- A 429 from provider does not crash the runtime process.
- `core/rpc.ail` retries according to configured bounds.
- On exhausted retries/non-retryable failure, runtime emits `error` event and remains usable for subsequent commands.
- Existing `std/ai.call*` behavior remains available and unchanged.
