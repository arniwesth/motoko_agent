# TUI Stream-Aware Markdown Rendering Plan

## Expected File Changes (Planned)

### Modified files
- `src/tui/src/ui.ts`
- `src/tui/src/runtime-process.ts`
- `src/tui/src/index.ts`
- `src/tui/src/ui.highlight.test.ts`
- `src/tui/src/ui.wait-state.test.ts`

### Added files
- `src/tui/src/stream-markdown.ts`
- `src/tui/src/stream-markdown.test.ts`

## Goal

Render markdown/code styling while content is still streaming, including fenced blocks like ` ```ail `, without regressing scroll behavior or introducing duplicate final output.

## UX Requirements

- Live streamed prose remains readable.
- Completed fenced code blocks are color-rendered during streaming.
- Open/incomplete fence segments are rendered in a stable preview mode.
- Final post-stream output remains a single canonical markdown render.
- No jump-to-top scroll regressions during long streams.

## Scope

- TTY rendering path only for rich stream-aware markdown UI.
- Plain logger remains compact by default; optional verbose raw stream remains controlled by env.
- No runtime protocol changes required for phase 1.

## Design

### 1. Incremental segment model

Introduce a stream segmentation layer:
- `plain` segment (markdown text outside fences)
- `code_complete` segment (closed fenced code block with language tag)
- `code_open` segment (currently open/incomplete fence)

The segmenter consumes `thinking_delta` text incrementally and emits updated segment list for a stream ID.

### 2. Rendering strategy

- `plain`: render as styled `Text` (fast path) during stream.
- `code_complete`: render using existing code highlighting path immediately.
- `code_open`: render with tolerant language-specific highlighter (best effort, no strict markdown parse requirement).
- On `thinking_stream_end`: replace transient segment rows with one final `Markdown` render and clear transient rows.
- On `thinking_stream_end` with `aborted`/`errored`: flush pending throttled updates, keep a partial rendered snapshot, and do not require a final `thinking` payload.

### 3. Stability/performance policy

- Render throttle: update stream-rendered segments at most every 50 ms per stream.
- Segment diffing: only update/add/remove changed rows; do not rebuild entire history on every delta.
- Memory caps:
  - parser buffer: 128 KiB per stream
  - visible live render cap: 12 KiB per stream (segment-aware trimming, not raw byte slicing)
- If caps exceeded, mark stream as truncated-for-live-render and continue final render at end.
- On `thinking_stream_end`, force a final render flush for pending throttled updates before transient row teardown.

### 4. Scroll-safety rules

- Never insert/remove rows above existing non-stream history during delta updates.
- Keep a fixed “stream block anchor” per stream ID and mutate only rows within that block.
- Avoid replacing stream rows with a growing single text blob.

## Data Model (UI)

Per stream ID:
- `rawBuffer: string`
- `segments: StreamSegment[]`
- `rows: Text[]` (transient row handles for this stream block)
- `lastRenderAtMs: number`
- `truncatedForLiveRender: boolean`

`StreamSegment`:
- `kind: "plain" | "code_complete" | "code_open"`
- `lang?: string`
- `text: string`
- `stableKey: string` (segment identity for diff updates)

Final render source (required):
- Final canonical markdown render must use the full assistant final payload (`thinking` / final response event), not the capped live `rawBuffer`.

## Implementation Phases

## Phase 1: Segmenter module
Files:
- `src/tui/src/stream-markdown.ts`
- `src/tui/src/stream-markdown.test.ts`

Changes:
- Build incremental fence detector for markdown stream buffers.
- Support language tags (`ail`, `ts`, `py`, `sh`, etc.).
- Emit deterministic segment keys and truncation metadata.

## Phase 2: UI integration
Files:
- `src/tui/src/ui.ts`

Changes:
- Replace current single streaming text row path with per-stream segment rows.
- Add row diff/update logic keyed by segment identity.
- Keep planned-tools streaming panel behavior unchanged.

## Phase 3: End-of-stream canonicalization
Files:
- `src/tui/src/ui.ts`

Changes:
- On stream completion, collapse transient rows and append one final markdown-rendered answer.
- Preserve current anti-duplicate behavior for `thinking` event fallback.
- Ensure end-of-stream flush occurs before collapse/teardown so throttled deltas are not visually dropped.
- For `aborted`/`errored` statuses:
  - Flush pending throttled updates first.
  - Preserve partial streamed content as markdown/text snapshot.
  - Mark snapshot status (`aborted` or `errored`) and avoid duplicate final render attempts.

## Phase 4: Plain logger + guardrails
Files:
- `src/tui/src/index.ts`
- `src/tui/src/runtime-process.ts` (only if type additions/helpers are needed)

Changes:
- Keep plain logger compact policy unchanged.
- Keep `MOTOKO_PLAIN_VERBOSE_STREAM=1` behavior for raw delta diagnostics.

## Phase 5: Tests
Files:
- `src/tui/src/stream-markdown.test.ts`
- `src/tui/src/ui.highlight.test.ts`
- `src/tui/src/ui.wait-state.test.ts`

Coverage:
- `plain -> code_open -> code_complete` transitions with ` ```ail ` fence.
- Multiple fenced blocks in one streamed response.
- Unclosed fence remains stable during stream and finalizes correctly at end.
- Throttle/diff logic avoids excessive row churn.
- `aborted`/`errored` stream end preserves a stable partial render and does not drop last deltas.
- Long stream does not trigger scroll-reset behavior:
  - automated guard: stable stream-anchor/row identity assertions across deltas
  - manual validation: mouse-wheel scroll during long streaming response does not jump to top
- Final canonical markdown render remains complete even when live parser buffer was capped.

## Acceptance Criteria

- During streaming, fenced code starts rendering with language highlighting before stream end.
- Incomplete fences are visibly rendered (best effort) without flicker spikes.
- Final streamed answer still renders once as canonical markdown.
- Aborted/errored streams preserve a visible partial snapshot without duplication or dropped tail tokens.
- Planned tool timeline remains intact.
- No duplicate assistant output in TTY or plain mode.
- Existing test suite passes plus new stream-markdown tests.
- Final canonical render is complete and not truncated by live buffer caps.

## Risks and Mitigations

- High-frequency delta churn:
  - Mitigate with 50 ms throttle and segment-level diff updates.
- Incomplete markdown parse edge cases:
  - Mitigate with tolerant segmenter and open-fence fallback rendering.
- Scroll instability:
  - Mitigate with fixed stream block anchor and in-place row updates only.
- Tail truncation breaking fence state:
  - Mitigate with segment-aware trimming (drop oldest complete segments first; avoid cutting fence tokens).

## Out of Scope (Future Upgrade)

- Full incremental markdown AST parser with block-level semantic diffing.
- Runtime-emitted typed markdown segment events.
- User-configurable live stream rendering themes/toggles.
