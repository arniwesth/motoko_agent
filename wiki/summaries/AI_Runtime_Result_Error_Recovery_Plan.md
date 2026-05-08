---
doc_type: short
full_text: sources/AI_Runtime_Result_Error_Recovery_Plan.md
---

# Summary: AI Runtime Result Error Recovery Plan

This document defines an approach to handle AI provider failures (e.g., 429 rate limits) as values instead of process-killing errors. It adds new AI effect operations that return structured result records, then adopts those from `core/rpc.ail` to implement retry logic without crashing the runtime.

## Key Concepts
- **Result-returning AI ops** – New builtins (`AI.callResult`, `AI.callJsonResult`, `AI.callJsonSimpleResult`) that return a `{ok, output, error_message, status_code, retryable, ...}` record instead of throwing Go errors.
- **Backward compatibility** – Existing `std/ai.call*` operations keep their throwing behaviour; new wrappers in `std/ai` expose the result-returning variants as `Result[...]` values.
- **Bounded retry with backoff** – `core/rpc.ail` uses `callResult`, matches on `Ok`/`Err`, and retries on retryable errors up to a configurable limit. Exponential backoff and environment-driven tuning (`AI_MAX_RETRIES`, `AI_RETRY_BASE_MS`, `AI_RETRY_CAP_MS`) are applied.
- **Error classification** – Provider status codes (e.g., 408, 429, 5xx) are mapped to a `retryable` flag; non-retryable errors (auth, invalid model) cause immediate failure with an `error` JSONL event.
- **Preserving runtime liveness** – The runtime stays alive regardless of transient failures, enabling subsequent conversation turns.

## Design Highlights
- New AI ops in `ailang/internal/effects/ai.go` return structured records instead of Go errors.
- `std/ai.ail` adds wrappers `callResult`, `callJsonResult`, `callJsonSimpleResult` that produce `Result[string, AIError]` values.
- `core/rpc.ail` replaces direct `call(...)` with pattern matching on the `Result`; on `Err`, retries with backoff or emits an error event.
- No protocol shape changes for TUI; backward compatible.

## Integration & Testing
- **Unit tests** verify error shapes (429→retryable, 401→non-retryable), transport errors classified correctly, success path.
- **Stdlib tests** confirm record‑to‑`Result` mapping.
- **Core integration** ensures retries succeed in-process and failures emit events without crashing.
- **Rollout** proceeds from new runtime ops → `std/ai` wrappers → `core/rpc.ail` adoption.

## Risks
- Error-shape drift across providers (mitigation: central mapping).
- Misclassification of retryable errors (mitigation: conservative status-based policy, then expand).
- Retry delay tuning (mitigation: env controls).

## Potential Concept Pages
- [[concepts/ai-error-handling]]
- [[concepts/result-type-pattern]]
- [[concepts/retry-logic]]
- [[concepts/bounded-exponential-backoff]]
- [[concepts/ai-provider-error-classification]]