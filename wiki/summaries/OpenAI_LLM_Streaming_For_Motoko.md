---
doc_type: short
full_text: sources/OpenAI_LLM_Streaming_For_Motoko.md
---

# OpenAI LLM Streaming for Motoko Plan

This document defines a plan to introduce real-time streaming of OpenAI model responses into the Motoko TUI, moving from a single-shot `callResult` to incremental text deltas while maintaining backward compatibility.

## Core Design
- **First-class streaming** via the AILANG AI effect system, not an untyped side-channel.
- New protocol events: `thinking_stream_start`, `thinking_delta`, `thinking_stream_end`, `thinking_stream_error`.
- Typed delta records with sequence indices for deterministic ordering.
- Trace visibility: structured `stream_start`, `stream_delta`, and terminal events recorded in effect traces.
- One AI budget unit consumed per invocation (not per chunk).
- Abort cancels provider context and emits a single terminal event; no post-cancel deltas.
- Delta content policy: only user-visible assistant text tokens become deltas; reasoning, tool calls, and empty events are filtered out.

## Implementation Phases
1. **AILANG Core Streaming Interface** – Extend `Provider` with streaming API, typed stream events, cancellation plumbing, and backward-compatible wrappers.
2. **OpenAI Streaming Backend** – Add streaming request mode to Chat Completions and Responses APIs, parse SSE events, apply delta filtering, and handle errors/aborts.
3. **AI Effect and Builtins Surface** – Introduce `callStreamResult` effect operations, stdlib exports, and trace policy enforcement (including truncation markers).
4. **Motoko Runtime Integration** – Wire `rpc.ail` to use streaming, emit new events, coalesce deltas, handle abort, and keep final `thinking` for compatibility.
5. **TUI Event Handling** – Extend `AgentEvent` union, render incremental deltas, reconcile with final `thinking`.
6. **Testing and Validation** – Unit tests for parsing, ordering, filtering, budget, abort, trace caps, and protocol/UI integration tests.

## Key Invariants
- Streaming is a typed, trace-visible AI effect path.
- Delta sequencing is monotonic and strictly ordered.
- Abort and error paths are deterministic and leave no dangling state.
- The existing `thinking` event remains for full-text reconciliation.

## Rollout
Feature-gated behind `AI_STREAMING=1` env flag; enable by default after validation.

## Cross-Cutting Concepts
- [[concepts/ai-effect-streaming]] – Typed streaming as part of AI effect semantics.
- [[concepts/openai-streaming-backend]] – Implementation details for OpenAI SSE parsing and delta filtering.
- [[concepts/motoko-tui-protocol]] – New streaming protocol events and rendering.
- [[concepts/stream-trace-visibility]] – Structured trace events for audit and replay.
- [[concepts/delta-content-policy]] – Rules for which OpenAI events become user-visible deltas.
- [[concepts/stream-abort-semantics]] – Deterministic cancellation and terminal event handling.
- [[concepts/stream-budget-model]] – One AI effect budget unit per call despite many chunks.