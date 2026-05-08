# Plan: Colored Real-Time Thinking Trace Rendering

## Context

Thinking traces (the LLM's internal reasoning) stream in real-time via `thinking_delta` events but render with minimal styling. During streaming, plain text segments get **no color at all** -- just raw text. When the stream ends, the thinking content collapses into a `[think]` accordion block, and expanding it shows the body as plain dim text with no syntax highlighting. This makes thinking traces hard to read and visually indistinct from answer content.

The goal is to make thinking traces visually distinctive and readable in real-time, with proper colors for both streaming and expanded accordion views.

## Changes

### 1. Color plain text in streaming thinking (`src/tui/src/ui.ts`)

In `renderStreamingVisibleText()` (~line 2563), plain segments currently render unstyled:
```typescript
if (seg.kind === "plain") {
  lines.push(seg.text);
  continue;
}
```

Change: Apply a thinking-specific color to plain segments. Use `chalk.dim` for a muted-but-readable look that clearly distinguishes thinking from answer text. Strip `<thinking>`/`</thinking>` and `<think>`/`</think>` tags before rendering, since they're structural noise.

### 2. Syntax-highlighted think block expansion (`src/tui/src/ui.ts`)

Currently `expandThinkBlock()` (~line 2157) dumps raw text:
```typescript
block.bodyRow.setText(block.content);
```

Change: Route the content through the same highlighting pipeline used during streaming. Create a `renderThinkContent(content: string): string` method that:
- Strips `<thinking>`/`<think>` tags
- Runs through `segmentStreamMarkdown()` for code fence detection
- Highlights code blocks with `highlightCodeLines()` / `highlightJsonLines()`
- Colors plain text with `chalk.dim`

**bgFn fix:** The `bodyRow` is created with `styledText("", chalk.dim)`, meaning pi-tui applies `chalk.dim` as a per-line wrapper. This would mute all embedded syntax highlighting colors. Fix: change both bodyRow creation sites (line 1690 in the `thinking` handler and line 2537 in `addThinkBlock()`) to use `chalk.reset` as bgFn instead. Plain-text dimming is then handled explicitly inside `renderThinkContent()`.

### 3. Colored think block headers (`src/tui/src/ui.ts`)

Currently the `[think]` header uses uniform `chalk.dim` (~lines 1687, 2154, 2160, 2534):
```
  [think] step 3 . 1200 chars  >  ^t
```

Change: Color the `[think]` label with `chalk.magenta` for visual distinction. Keep the metadata (step, chars, ^t hint) dim.

**bgFn fix:** The `headerRow` is also created with `chalk.dim` as bgFn, which would mute embedded magenta. Fix: change both headerRow creation sites (line 1686 in the `thinking` handler and line 2533 in `addThinkBlock()`) to use `chalk.reset` as bgFn. All styling is embedded directly in the header string.

**Two creation paths:** Think blocks are created in two independent code paths that must both be updated:
1. Inline in the `thinking` event handler (lines 1686–1694) — for pre-split runtime responses
2. Via `addThinkBlock()` (lines 2528–2541) — used by stream-end and other paths

### 4. Thinking tag stripping helper (`src/tui/src/ui.ts`)

Add a small helper `stripThinkTags(text: string): string` that removes `<thinking>`, `</thinking>`, `<think>`, `</think>` tags from text. Used by both the streaming renderer and think block expansion.

## Files modified

- `src/tui/src/ui.ts` -- all changes are in this file

## Existing code to reuse

- `segmentStreamMarkdown()` from `src/tui/src/stream-markdown.ts:117` -- code fence segmentation
- `trimSegmentsForLiveRender()` from `src/tui/src/stream-markdown.ts:168` -- segment trimming
- `highlightCodeLines()` from `src/tui/src/ui.ts:556` -- language-specific syntax highlighting
- `highlightJsonLines()` from `src/tui/src/json-highlight.ts` -- JSON highlighting
- `extractTaggedThinkAnswer()` from `src/tui/src/ui.ts:1293` -- existing tag parsing (reference for tag patterns)

## Color scheme

| Element | bgFn | Embedded style | Rationale |
|---------|------|----------------|-----------|
| Streaming plain text | `chalk.reset` (row) | `chalk.dim` (in rendered string) | Muted but readable; secondary to answer |
| Streaming code blocks | `chalk.reset` (row) | existing highlighting (unchanged) | Already works well |
| `[think]` label | `chalk.reset` (headerRow) | `chalk.magenta` | Eye-catching, distinct from other labels |
| Think header metadata | `chalk.reset` (headerRow) | `chalk.dim` | Step/chars/^t hint stays subtle |
| Expanded think body plain text | `chalk.reset` (bodyRow) | `chalk.dim` (via `renderThinkContent`) | Consistent with streaming |
| Expanded think body code | `chalk.reset` (bodyRow) | syntax highlighted (via `renderThinkContent`) | Colors not muted by bgFn |

## Verification

1. Build: `cd src/tui && bun run build`
2. Run tests: `cd src/tui && bun run test`
3. Manual verification:
   - Run the agent with a task that triggers multi-step reasoning
   - Confirm streaming text appears with dim styling (not raw unstyled)
   - Confirm code blocks within thinking traces get syntax highlighting during streaming
   - Confirm `[think]` headers show magenta `[think]` label with dim metadata
   - Press `^t` to expand a think block and confirm code blocks are syntax-highlighted, not uniformly dimmed
   - Confirm `<thinking>` tags are stripped from both streaming and expanded views
   - Confirm final answer still renders as full markdown (no regression)
   - Confirm collapsed think blocks still show empty body (no leftover styled text)
