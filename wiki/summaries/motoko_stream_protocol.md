---
doc_type: short
full_text: sources/motoko_stream_protocol.md
---

# Motoko Stream Protocol

Defines a structured JSONL protocol for real-time, incremental rendering of AI reasoning steps between the AILANG runtime and a terminal UI (TUI).

## Key Concepts

- **Event Types**: Four core events—`thinking_stream_start`, `thinking_delta`, `thinking_stream_error`, and `thinking_stream_end`—carry step, stream ID, and payloads that drive UI updates.
- **Ordering Guarantees**: Per `stream_id`, a single start, strictly monotonic `seq` for deltas, optional error before terminal end, and no deltas after `thinking_stream_end`.
- **UI Reconciliation**: The TUI appends `text_delta` to a live row for each stream, flushes and commits on `end`, avoids duplicate output on repeated step events, and hides internal `compose-` prefixed streams from transcript rows.
- **Compatibility**: Unknown JSONL lines are ignored; non-streaming sessions use legacy `thinking`/`done` events; coexistence with tool/composition events is maintained.

## Relevance

This protocol enables [[concepts/streaming_thinking_output]] in the [[concepts/ailang_runtime]] and [[concepts/tui_renderer]], ensuring deterministic and user-friendly display of incremental AI thoughts. It intersects with [[concepts/event_driven_architecture]], [[concepts/jsonl_protocols]], and [[concepts/ui_state_reconciliation]]. The strict ordering and deduplication rules are essential for [[concepts/reliable_realtime_updates]] without visual glitches.