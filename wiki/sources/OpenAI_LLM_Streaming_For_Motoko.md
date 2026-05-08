# OpenAI LLM Streaming for Motoko (OpenAI-Only Plan)

## Goal
Implement real-time LLM output streaming from the runtime to the TUI for Motoko sessions, scoped to OpenAI models only.

## Scope Boundary
- In scope: OpenAI provider path only (`internal/ai/openai/*`), runtime JSONL streaming events, TUI rendering of incremental deltas.
- Out of scope: Anthropic, Gemini, Ollama streaming support.
- Out of scope: tool execution streaming changes (this plan is about model text streaming only).

## Expected File Changes (Planned)
Core/provider/runtime files expected to be changed:
- `ailang/internal/ai/provider.go`
- `ailang/internal/ai/handler.go`
- `ailang/internal/ai/openai/client.go`
- `ailang/internal/ai/openai/chat.go`
- `ailang/internal/ai/openai/responses.go`
- `ailang/internal/ai/openai/types.go`
- `ailang/internal/effects/ai.go`
- `ailang/internal/builtins/ai.go`
- `ailang/std/ai.ail`
- `src/core/rpc.ail`
- `src/core/types.ail` (if protocol/event typing additions are centralized here)
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`

Likely test files to be changed/added:
- `ailang/internal/ai/openai/*_test.go` (stream parser + filtering + cancellation)
- `ailang/internal/ai/*_test.go` (provider/handler stream contracts)
- `ailang/internal/effects/*_test.go` (typed stream effects, budget, trace markers)
- `src/tui/src/**/*.test.ts` (event decoding + incremental render + reconciliation)
- `src/core/**` test fixtures/specs for JSONL stream events (if present in this repo’s test layout)

## Current-State Constraint
- `src/core/rpc.ail` waits on a full `callResult(...)` string before emitting `thinking`.
- AILANG AI abstractions are unary (`string -> string`) and provider interface is single-shot (`Generate(...)`).
- TUI protocol has no assistant token delta event type.

## Target Behavior
When the model call starts, the user should see answer text incrementally in the history pane, followed by the existing final `thinking`/`done` flow.

## Design Decisions
1. Add first-class streaming support to AILANG AI provider abstraction.
2. Implement OpenAI streaming in backend clients (Chat + Responses API paths).
3. Expose streaming via AI effect builtins/stdlib so `src/core/rpc.ail` can consume it.
4. Extend runtime/TUI JSONL protocol with explicit delta/final stream events.
5. Keep existing non-streaming APIs for backward compatibility.

## Non-Negotiable Invariants
This implementation must model streaming as a first-class, typed, trace-visible effect path:
- **First-class**: streaming is part of `AI` effect semantics, not an untyped stdout side-channel.
- **Typed**: deltas, completion, and failures use explicit ADTs/records in `internal/ai`, `effects`, builtins, and `std/ai`.
- **Trace-visible**: stream lifecycle and emitted chunks are captured as structured effect trace events.
- **Deterministic ordering**: each chunk carries an ordered sequence index; runtime/TUI process strictly in sequence order.
- **Budget-correct**: one AI invocation consumes one AI effect budget unit (not one per chunk).
- **Abort-correct**: user/runtime abort must cancel provider stream context and emit exactly one terminal stream event.

## Protocol Additions (Motoko <-> TUI)
Add new runtime events emitted by `src/core/rpc.ail`:
- `thinking_stream_start` with `{ step, stream_id, model }`
- `thinking_delta` with `{ step, stream_id, seq, text_delta }`
- `thinking_stream_end` with `{ step, stream_id, status }` where `status ∈ {completed, aborted, errored}`
- `thinking_stream_error` with `{ step, stream_id, message, retryable }` (for explicit structured failure path)

Notes:
- Existing `thinking` event remains and still carries final full assistant text for compatibility.
- TUI should render deltas immediately and reconcile with final `thinking`.
- `thinking_stream_end(status=aborted)` is emitted only after provider cancellation is acknowledged and runtime stream state is finalized.

## Delta Content Policy (OpenAI)
Only user-visible assistant text tokens become `thinking_delta.text_delta`.

- Include:
  - Chat Completions: assistant textual delta content.
  - Responses API: output text deltas that map to assistant-visible text.
- Exclude:
  - reasoning summaries/tokens, tool-call JSON, usage counters, and non-text control events.
  - duplicate or empty deltas.

Policy rule: if an OpenAI stream event is not unambiguously user-visible assistant text, do not emit it as `thinking_delta`.

## Trace Policy
Streaming remains trace-visible at lifecycle and chunk level, with bounded and replay-safe semantics:

- Trace records include `stream_start`, ordered `stream_delta(seq, text_delta)`, and exactly one terminal event (`stream_end` or `stream_error`).
- Keep chunk events structured and ordered for audit; replay correctness is validated against canonical assembled final text, not transport chunk boundaries.
- Enforce bounded trace growth via configurable caps (max delta events and/or bytes per stream); when capped, append a typed `stream_truncated` marker event and continue assembling final text in runtime memory.

## Implementation Plan

## Phase 1: AILANG AI Core Streaming Interface
Files:
- `ailang/internal/ai/provider.go`
- `ailang/internal/ai/handler.go`

Changes:
- Extend `Provider` with streaming API (callback-based).
- Add stream event/result types in `internal/ai` (delta + completion/error metadata + sequence index).
- Add handler method(s) that expose streaming while preserving existing `Call`/`CallJson` behavior.
- Implement non-streaming compatibility wrapper by aggregating streamed chunks when needed.
- Add cancellation plumbing so runtime abort propagates through handler/provider context cancellation and closes stream deterministically.

Acceptance:
- Existing call sites compile unchanged.
- New streaming method available for runtime use.
- Stream types are explicit and versioned (no `map[string]any` style event payloads).
- Abort path is deterministic: cancellation request leads to one terminal stream result with no post-terminal deltas.

## Phase 2: OpenAI Streaming Backend
Files:
- `ailang/internal/ai/openai/client.go`
- `ailang/internal/ai/openai/chat.go`
- `ailang/internal/ai/openai/responses.go`
- `ailang/internal/ai/openai/types.go`

Changes:
- Add streaming request mode for both Chat Completions and Responses APIs.
- Parse incremental OpenAI stream events and emit text deltas via typed callback events.
- Preserve reasoning/think behavior consistency in final assembled text.
- Ensure error mapping remains compatible with existing `ProviderError` semantics.
- Apply strict event filtering per Delta Content Policy so only user-visible assistant text reaches `thinking_delta`.

Acceptance:
- Unit tests validate delta sequencing and final reconstruction.
- Stream cancellation/error path covered.
- Out-of-order/duplicate chunk handling policy is tested (reject or normalize deterministically).
- Delta filtering tests verify that non-user-visible OpenAI events never surface as text deltas.

## Phase 3: AI Effect and Builtins Surface
Files:
- `ailang/internal/effects/ai.go`
- `ailang/internal/builtins/ai.go`
- `ailang/std/ai.ail`

Changes:
- Add streaming-oriented AI effect operation(s), e.g. `callStreamResult`, as **typed AI effect operations**.
- Add builtin wrappers and stdlib exports for streaming calls with typed chunk/completion records.
- Keep old API stable (`call`, `callResult`, `callJson*` unchanged).
- Ensure capability and budget integration remains under `AI` effect path (no shadow effect).
- Add typed terminal/abort markers and optional typed `stream_truncated` marker for bounded trace policy.

Acceptance:
- AILANG code can subscribe to streamed model deltas through the new API.
- Backward compatibility retained.
- AI stream operation appears in effect traces as structured `effect` events (start/delta/end/error).
- Trace policy is enforced with deterministic typed marker events when limits are hit.

## Phase 4: Motoko Runtime Integration
Files:
- `src/core/rpc.ail`
- `src/core/types.ail` (if new event typing is needed)

Changes:
- Replace blocking AI step path with streaming-aware call path.
- Emit `thinking_stream_start` / `thinking_delta` / `thinking_stream_end`.
- Continue emitting final `thinking` with full merged response.
- Keep existing retry policy behavior; define retry semantics for pre-first-delta vs mid-stream failures.
- Maintain deterministic stream assembly using `seq` ordering and canonical buffer in runtime.
- Wire stdin `abort` command to stream cancel token/context; after cancel ack, emit `thinking_stream_end(status=aborted)` exactly once.
- Add delta coalescing/backpressure strategy (time/size threshold batching) before JSONL emission while preserving monotonic `seq`.

Acceptance:
- User sees incremental text in-session.
- Final `thinking`/solver behavior is unchanged functionally.
- Stream path remains replay/audit-friendly via explicit structured events.
- Abort during stream leaves no hanging stream state and no duplicate terminal events.
- Long outputs remain responsive without UI thrash due to bounded/coalesced delta emission.

## Phase 5: TUI Event Handling
Files:
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`

Changes:
- Extend `AgentEvent` union with stream event types.
- Render incremental assistant output as deltas arrive.
- Keep existing `thinking` handling as reconciliation/fallback.

Acceptance:
- No regressions for non-streaming events.
- Live output remains readable and stable in long responses.

## Phase 6: Testing and Validation
Backend:
- OpenAI stream parser unit tests (normal, empty, malformed event, error event).
- AI effect tests for streaming operation(s).
- Trace tests: stream start/delta/end/error events are present and structured.
- Budget tests: one streamed call consumes one AI budget unit regardless of chunk count.
- Delta filtering tests: excluded OpenAI event classes do not produce `thinking_delta`.
- Abort tests: cancel before first delta and mid-stream both produce exactly one terminal event and no post-terminal deltas.
- Trace cap tests: marker emission and replay validation against final assembled text.

Motoko/TUI:
- Protocol tests for new event types.
- UI behavior tests for incremental rendering + final reconciliation.
- Sequence/order tests: TUI ignores/reports out-of-order deltas deterministically.
- Coalescing tests: runtime batching preserves rendered text correctness and strict sequence progression.

Manual:
1. Run with OpenAI model and confirm visible incremental text.
2. Trigger network interruption and verify graceful error handling.
3. Confirm follow-up messaging/session flow still works.

## Risks and Mitigations
- Risk: protocol drift between runtime and TUI.
- Mitigation: update `runtime-process.ts` and `ui.ts` in same change set, plus integration tests.

- Risk: duplicated/misaligned final text after deltas.
- Mitigation: maintain one canonical stream buffer in runtime and emit full final `thinking` from that buffer.

- Risk: retry complexity for partial streams.
- Mitigation: only auto-retry before first delta; after first delta, fail fast with explicit error event.

- Risk: trace nondeterminism from unstable chunk boundaries.
- Mitigation: treat chunk boundaries as transport-level detail; compare semantic assembled output for replay checks while still recording ordered chunk events for audit.

- Risk: abort races causing duplicate terminal events or leaked goroutines/contexts.
- Mitigation: single terminal-state guard in runtime/provider stream controller; terminal event emission is idempotent and post-terminal deltas are dropped.

- Risk: stream event flood causes UI/render churn.
- Mitigation: runtime-side coalescing with deterministic flush rules and upper bounds.

## Rollout Strategy
1. Land backend streaming abstractions + OpenAI implementation behind a runtime env flag (recommended: `AI_STREAMING=1`).
2. Integrate rpc + TUI streaming events under the same flag.
3. Enable by default after validation.

## Future Upgrade Note (Explicitly Out of Scope Here)
Anthropic, Gemini, and Ollama streaming support should be implemented as a follow-up plan after OpenAI streaming is stable. That upgrade should reuse the same provider/effect/runtime protocol introduced here.
