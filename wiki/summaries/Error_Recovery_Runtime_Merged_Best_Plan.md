---
doc_type: short
full_text: sources/Error_Recovery_Runtime_Merged_Best_Plan.md
---

# Summary: Error Recovery — Merged Runtime Fix (Best Version)

This plan proposes a comprehensive fix at the AILANG runtime layer to prevent process crashes on AI provider failures (e.g., 429, transient errors). It introduces [[concepts/structured-errors|structured error records]] that return outcome metadata instead of raising exceptions, implements a configurable [[concepts/retry-policy|retry/backoff strategy]] directly in AILANG code (`core/rpc.ail`), and adds new safe API endpoints in `std/ai.ail`—`callResult`, `callJsonResult`, `callJsonSimpleResult`—while preserving backward compatibility for existing `call*` functions.

## Key Design Decisions
- **No process crash path**: Errors are returned as regular records with `ok`/`output`/`error_*` fields; the runtime stays alive and returns to `conversation_loop`.
- **Retry policy lives in AILANG**: Controlled by environment variables (`AI_MAX_RETRIES`, `AI_RETRY_BASE_MS`, `AI_RETRY_CAP_MS`), with `AI_MAX_RETRIES=0` meaning no retries.
- **Robust error classification**: Uses typed `ProviderError` extraction first, then heuristic fallback for transport/timeout errors; defines a set of retryable HTTP status codes (408, 409, 425, 429, 5xx).
- **Builtin & stdlib additions**: Three new builtins (`_ai_call_*_result`) registered via `internal/builtins/ai.go`, plus `AIError` type and `Result`-returning wrappers in `std/ai.ail`.
- **TUI adjustments**: Error display uses bright red, and the next user input routes through the same live runtime (no second spawn) unless the process crashes unexpectedly (fallback safety net).

## Files Affected
- `ailang/internal/effects/ai.go` – effect ops for structured results
- `ailang/internal/builtins/ai.go` – builtin registration for new underscore functions
- `ailang/std/ai.ail` – `AIError` type, `Result` wrappers, and unchanged legacy APIs
- `core/rpc.ail` – retry helper `ai_call_with_retry` using new safe calls
- `tui/src/ui.ts` & `tui/src/index.ts` – error display and crash resilience

## Acceptance Criteria
- AI provider errors emit JSONL `error` events but do not crash the runtime
- Retry behaviour is configurable and honours zero retries
- After terminal errors, runtime remains interactive in the conversation loop
- Legacy `std/ai.call*` usage continues to work unchanged
- All modified packages type-check and TUI behaviour remains coherent

Related concepts: [[concepts/structured-errors]], [[concepts/retry-policy]], [[concepts/runtime-stability]], [[concepts/backward-compatibility]], [[concepts/iail-builtins]]