# hy3:free model call hangs at step 26 with no client-side timeout
## Status
open

## Branch
Provider_Timeout_Guard

## Description
Running `make live_hunyuan3_free_compaction_heavy_headless` (config `hunyuan3-free-compaction-live`, model `openrouter/tencent/hy3:free`) stalls and never terminates. The session `.motoko/logfile/session_2026-07-09T18-10-09-291Z.jsonl` ends at step 26 with `thinking_stream_start` + `provider_call_prepared` for `openrouter/tencent/hy3:free`, and then **nothing** — no `thinking_delta`, no `thinking_stream_end`, no `native_tool_calls`, no `run_summary`, no `done`/`error`/`session_end`. The step-26 provider request was dispatched (`provider_call_prepared`) but never returned a stream nor an error. The loop parked on an unresolved promise.

It is NOT a step-budget stop: `config.json` sets `agent.max_steps = 100`, and `current_step` only reached 25 (step_idx 26), so `step_machine.ail`'s `if step_budget > 0 && step_idx >= step_budget → max_steps` guard never fired. Sibling `hy3:free` sessions in the same `logfile/` dir terminate cleanly with `type:"done"`, confirming the run is abnormal rather than expectedly bounded.

OpenRouter's free tier (`hy3:free`) is known for silently dropped/long-tailed streams and intermittent unavailability. With no client-side timeout on the main completion fetch and a free endpoint that accepted the request but never streamed, the awaited call blocks indefinitely.

## Location
- `src/tui/src/models.ts` and/or `src/tui/src/ui.ts` — the primary agent chat-completion `fetch` (SSE/stream) has **no** `AbortController`/`AbortSignal`/`timeout`.
- `src/tui/src/index.ts` (`JsonlLogger.handleEvent`) — `done`/`error` are the only terminal events; a hung request emits neither.

## Fix
Add a client-side timeout + `AbortController`/`signal` to the main model-completion `fetch` (e.g. 60–120s), so a dead upstream call **rejects** instead of hanging forever. Mirror the pattern already used in `src/tui/src/env-server.ts` (`timeoutMs` + `setTimeout` on subagent authoring) and `src/tui/src/runtime-process.ts` (30s runtime spawn timeout).

---

# Stream retry path does not cover hangs (only thrown errors)
## Status
open

## Branch
Provider_Timeout_Guard

## Description
`src/core/recovery.ail`'s `should_retry_stream_error(retry_enabled, remaining_step_budget > 1)` is invoked from `src/core/session.ail:1647` **only inside the `catch` of the model call** (`StreamErrorRetry`). `retry_stream_errors` is on by default (`MOTOKO_RETRY_STREAM_ERROR="1"`). This means a *thrown* stream error is retried — but a request that is sent and then never returns (no error, no data) bypasses the `catch` entirely, so the loop blocks on the awaited `fetch` and the retry never triggers. The step-26 stall is exactly this case: `provider_call_prepared` fired, no error was raised, nothing recovered.

## Location
- `src/core/recovery.ail:12` — `should_retry_stream_error`
- `src/core/session.ail:1647-1668` — `StreamErrorRetry` only on caught error

## Suggested fix
Treat a **timeout / no-first-byte / no-token** stream as a retryable stream error. When the new client-side timeout (see above) rejects the fetch, route that rejection through the same `StreamErrorRetry` path so `should_retry_stream_error` can fire. Confirm the `remaining_step_budget > 1` guard still permits retries at low step counts (step 26 with budget 100 easily qualifies).

---

# Free-tier silent-drop has no circuit breaker / fast-fail
## Status
open

## Branch
Provider_Timeout_Guard

## Description
On the free tier, a single dropped/long-tailed stream is enough to wedge a headless run (seen: step 26 of a 100-step budget, no termination event, had to be killed externally). There is no escalation after repeated empty/dropped `hy3:free` responses — the runtime will happily block again on the next attempt.

## Location
- `src/core/session.ail` — model-call dispatch / retry accounting
- `src/core/recovery.ail` — stream-retry policy

## Suggested fix
Add a **free-tier circuit breaker**: count consecutive empty/dropped/timeout responses for the model; after N consecutive failures, either (a) fail fast with `error` (so a `run_summary` with partial totals is emitted, matching the 6 termination-path contract), or (b) fall back to a configured paid model. Keep it gated behind an env flag so non-free configs are unaffected. This also gives the eval harness a clean `error` termination instead of a silent hang.

---

# Evidence pointers (for reviewers)
## Status
open

## Branch
Provider_Timeout_Guard

## Description
Reproduction artifacts and where the claim is verified in-repo.
- Session: `.motoko/logfile/session_2026-07-09T18-10-09-291Z.jsonl` — ends at `thinking_stream_start`/`provider_call_prepared` step 26, no terminal event.
- Config: `.motoko/config/hunyuan3-free-compaction-live/config.json` — `agent.model = openrouter/tencent/hy3:free`, `agent.max_steps = 100`.
- Makefile target: `live_hunyuan3_free_compaction_heavy_headless` → `MOTOKO_CONFIG=hunyuan3-free-compaction-live MOTOKO_HEADLESS=1`.
- Context limit present (so fail-open isn't the cause): `.motoko/model-catalog.json` has `"openrouter/tencent/hy3:free": 262144`.
- Client timeout search result: `ABortController`/`AbortSignal`/`signal`/`timeout` appear only in `compose-claimcheck.ts`, `env-server.ts`, `commands.ts`, `runtime-process.ts` — **not** on the main agent completion fetch in `models.ts`/`ui.ts`.
- Sibling `hy3:free` sessions in `logfile/` end with `type:"done"` (e.g. `session_2026-07-09T17-37-26-698Z.jsonl`, `…T17-44-20-737Z.jsonl`), confirming the abnormal stall is specific to this run's step-26 call.

## Location
`src/tui/src/*.ts`, `src/core/{recovery,session,step_machine}.ail`, `.motoko/config/hunyuan3-free-compaction-live/`, `Makefile`
