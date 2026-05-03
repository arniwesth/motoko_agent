# Motoko Stream Protocol

## Purpose
Define JSONL events for incremental AI thinking output between AILANG runtime and TUI.

## Event Types
1. `thinking_stream_start`
   - Payload:
     - `type: "thinking_stream_start"`
     - `step: number`
     - `stream_id: string`
     - `model: string`
2. `thinking_delta`
   - Payload:
     - `type: "thinking_delta"`
     - `step: number`
     - `stream_id: string`
     - `seq: number`
     - `text_delta: string`
3. `thinking_stream_error`
   - Payload:
     - `type: "thinking_stream_error"`
     - `step: number`
     - `stream_id: string`
     - `message: string`
     - `retryable: boolean`
4. `thinking_stream_end`
   - Payload:
     - `type: "thinking_stream_end"`
     - `step: number`
     - `stream_id: string`
     - `status: "completed" | "aborted" | "errored"`

## Ordering Guarantees
1. For a given `stream_id`, exactly one `thinking_stream_start` is emitted first.
2. `thinking_delta` events for a `stream_id` use strictly increasing `seq`.
3. `thinking_stream_error` may appear before terminal end for errored streams.
4. Exactly one terminal `thinking_stream_end` is emitted per `stream_id`.
5. No further deltas are emitted after `thinking_stream_end`.

## UI Reconciliation Rules
1. While streaming, TUI appends `thinking_delta.text_delta` into the live row for that `stream_id`.
2. On `thinking_stream_end`, TUI flushes pending render and commits accumulated text to history.
3. If a later `thinking` event for the same `step` arrives, TUI must not duplicate already streamed output.
4. Internal compose sub-streams (`stream_id` prefixed with `compose-`) are excluded from main reasoning transcript rows.

## Compatibility Notes
1. Unknown JSONL lines are ignored by the runtime parser.
2. Non-stream runs continue to rely on `thinking` + `done` events.
3. Stream lifecycle events coexist with existing tool/composition events.
