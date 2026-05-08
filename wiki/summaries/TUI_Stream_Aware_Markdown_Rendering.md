---
doc_type: short
full_text: sources/TUI_Stream_Aware_Markdown_Rendering.md
---

# TUI Stream-Aware Markdown Rendering

## Goal
Render markdown/code styling incrementally while content is still streaming, including fenced code blocks, without regressing scroll behavior or introducing duplicate final output.

## Key Concepts

- **Incremental segment model**: A [[concepts/stream-segmentation]] layer splits incoming text into `plain`, `code_complete`, and `code_open` segments, enabling per-segment updates.
- **Rendering strategy**: [[concepts/incremental-rendering]] applies code highlighting immediately for completed blocks, tolerant best-effort highlighting for open fences, and a final canonical [[concepts/markdown-finalization]] step.
- **Scroll safety**: A fixed [[concepts/stream-block-anchor]] per stream ID and row-level diffs prevent jump-to-top regressions during long streams.
- **Performance & throttling**: Updates are throttled at 50 ms, segment diffs minimize row churn, and memory caps (128 KiB parser buffer, 12 KiB visible live render) prevent resource issues; if caps are exceeded the stream is marked truncated-for-live-render.

## Design Details

### Segment Model
- `plain`: markdown text outside fences, rendered as styled text.
- `code_complete`: closed fenced code block with language tag; full highlighting.
- `code_open`: incomplete fence; best-effort highlighting.
- Segmenter emits deterministic keys for stable diffing.

### End-of-Stream Handling
- On `thinking_stream_end`, transient segment rows are replaced by a single final [[concepts/markdown-finalization]] render.
- For aborted/errored streams: flush pending updates, preserve partial rendered snapshot, mark status, avoid duplicate render.

### Scroll-Safety Rules
- No insert/remove rows above existing history.
- Fixed stream block anchor per ID; mutations only within its rows.

### Data Model
Per stream ID: `rawBuffer`, `segments`, transient `rows`, `lastRenderAtMs`, `truncatedForLiveRender` flag. Each segment has a `stableKey` for diffing.

## Implementation Phases
1. **Segmenter module** (`stream-markdown.ts`): incremental fence detection, language tag support, deterministic keys, truncation metadata.
2. **UI integration** (`ui.ts`): replace single-text-row streaming with per-stream segment rows and row diff/update logic.
3. **End-of-stream canonicalization**: collapse transient rows, append final markdown render, handle abort/error.
4. **Plain logger guardrails**: preserve compact default, verbose raw stream via env.
5. **Tests**: covering fence transitions, multiple blocks, unclosed fences, throttle/diff logic, abort/error flows, scroll stability, and final render completeness.

## Acceptance Criteria
- Code blocks receive highlighting before stream end; incomplete fences render without flicker.
- Final output is a single canonical markdown render; aborted streams preserve partial snapshot.
- Scroll behavior remains stable; no duplicate output.
- Existing tests pass plus new stream-markdown tests.

## Related Concepts
- [[concepts/stream-segmentation]]
- [[concepts/incremental-rendering]]
- [[concepts/markdown-finalization]]
- [[concepts/stream-block-anchor]]
- [[concepts/scroll-safety]]
- [[concepts/render-throttling]]
- [[concepts/truncated-live-render]]