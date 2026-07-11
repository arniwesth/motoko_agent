# Compaction summarizer call hangs the loop at step 395 (no per-call timeout)
## Status
partially-fixed

## Branch
arniwesth/mot-38-progress-contract-finalize-guard-extension

## Description
Running `make live_hunyuan3_free_compaction_heavy_headless` (config `hunyuan3-free-compaction-live`, model `openrouter/tencent/hy3:free`, `max_steps: 1010`) hangs with no progress after step 395. The process stays alive (`ailang run … --model openrouter/tencent/hy3 … --port 40131`) but emits no further events.

Session `.motoko/logfile/session_2026-07-10T18-24-41-982Z.jsonl` (started 18:24, last write 19:53:10). Event census pins the stall precisely:
- `native_tool_results` for **step 395** is the last event in the file.
- `provider_call_prepared` and `compaction_extension` both stop at **step 395** — there is no step-396 of either.
- No `run_summary` / `error` / terminal event.

The step-396 pre-step chain runs **AI compaction before** `provider_call_prepared`, so the block is in the compaction summarizer call, not the main model call. This is a *different location* from the previously-filed main-completion hang (see `free-tier-hang-no-timeout.md`) but the same root cause: a `:free` OpenRouter endpoint accepted the request and then never streamed, and there is no client-side timeout to reject it.

Aggravating pathology (why this run hit it so hard): compaction is ephemeral, so raw history re-inflates every step. From ~step 300 on, every single step re-summarized ~1,880 turns:
```
step 390  AI-summarized 1856 turns (629% -> 2%)
...
step 395  AI-summarized 1886 turns (638% -> 2%)
```
So every step made a fresh summarizer call to the flaky free model — 1 hang opportunity per step until one stuck. See `ephemeral-compaction-and-ai-noop-thrash.md` for the thrash itself.

Compounding the hang, the pre-fix code also **corrupted context on any *returned* summarizer failure**: `summarize_with_ai` swallowed `Err(AIError)` into the string `"[summarizer unavailable: …]"`, and `compact_with_ai` spliced that sentinel in as if it were a real summary, returning `Compacted`. So a failed summarize still "succeeded" with a placeholder standing in for ~1,880 dropped turns.

## Location
- `packages/motoko-ext-compaction-ai/compaction_ai.ail` — `summarize_with_ai` / `compact_with_ai` (the summarizer call + splice).
- `src/core/session.ail:607` `ext_ai_step` → `p.model_step` → AILANG `std/ai.stepWithStream` — the underlying call with no per-call timeout.
- `.motoko/config/hunyuan3-free-compaction-live/compaction_ai.json` — summarizer `model` set to `openrouter/tencent/hy3:free` (same flaky free tier as the agent).

## Fix (applied — the returned-failure half)
Landed in `packages/motoko-ext-compaction-ai/compaction_ai.ail`:
- Added `summarize_attempt` / `summarizer_max_attempts` (=2): a returned `Err` (RateLimit / ConnectionFailed / Timeout) or empty response gets one bounded retry.
- Added `summarize_with_ai_result -> Result[string,string]`; kept `summarize_with_ai` as a back-compat string wrapper (preserves the `_smoke.ail` "[summarizer unavailable:" contract).
- `compact_with_ai` now **degrades to `PassThrough`** (skip compaction this step) when the fresh summary fails, instead of splicing a placeholder. Shared `finalize_compaction` helper for the cached + fresh paths.
- Tests: 6/6 pass. Two happy-path tests now use a working stub-summarizer port (`stub_ext_ports`) instead of relying on the old broken splice; added `test_ai_summarizer_failure_degrades_to_passthrough` to pin the degrade. `ailang.lock` hash bumped.

## Remaining gap (not fixed here — needs AILANG core)
The applied fix only converts a summarizer failure that **returns** into a safe skip. It does **not** interrupt an already in-flight stalled request: `std/ai`'s `step` / `stepWithCache` / `stepWithStream` (v0.26.0) expose **no per-call timeout**, and there is no user-facing AILANG HTTP-timeout env var. So the exact step-395 hang (connection accepted, stream never arrives) can still block the loop. A true wall-clock timeout has to come from AILANG core — route via the `ailang-feedback` skill. Once std/ai can emit a `Timeout` `AIError` for a stalled stream, it flows through the retry/degrade path added here for free.

## Related
- `free-tier-hang-no-timeout.md` — same root cause on the **main** completion fetch; proposes client-side `AbortController`/timeout + circuit breaker.
- `ephemeral-compaction-and-ai-noop-thrash.md` — the every-step re-summarization thrash that multiplied the hang exposure.
- Follow-ups not yet done: (#2) point `compaction_ai.json` summarizer at a non-free model; (#4) stop re-summarizing from scratch every step.
