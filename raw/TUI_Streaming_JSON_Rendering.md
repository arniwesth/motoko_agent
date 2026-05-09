# TUI Streaming JSON Rendering Plan

## Expected File Changes (Planned)

### Modified files
- `src/tui/src/ui.ts`
- `src/tui/src/stream-markdown.ts`
- `src/tui/src/ui.highlight.test.ts`
- `src/tui/src/tool-plan-parser.test.ts`

### Optional modified files
- `src/tui/src/index.ts` (only if env plumbing is centralized there)

### Added files
- `src/tui/src/json-highlight.ts`
- `src/tui/src/json-highlight.test.ts`

## Goal

Add color rendering for streamed JSON blocks (complete and partial) while preserving the planned-tools UX and avoiding duplicate/noisy tool-call output.

## UX Requirements

- Streamed fenced JSON blocks are color rendered during streaming.
- Partial/incomplete streamed JSON still renders in a stable highlighted form.
- Tool-call JSON envelopes remain collapsed by default when planned-tools panel is active.
- Non-tool JSON blocks remain visible and highlighted.
- Debug mode can force-show tool-call JSON blocks.

## Scope

- TTY path only for rich JSON stream highlighting.
- Plain logger remains compact by default.
- No protocol changes required.

## Behavior Policy

### 1. JSON classification

Classify streamed fenced code segments with `lang` in:
- `json`, `jsonc`, `application/json`

Also classify bare/unfenced streamed JSON blocks:
- balanced top-level JSON objects detected in stream text outside fenced segments
- tolerant to partial/incomplete JSON during streaming

### 2. Rendering policy

- `code_complete` JSON:
  - highlighted using JSON token coloring.
- `code_open` JSON:
  - highlighted with tolerant tokenizer (no strict parse requirement).
- `json_bare` (unfenced) segments:
  - highlighted using the same tolerant JSON tokenizer/highlighter.

### 3. Tool-envelope visibility policy

Detect likely tool envelopes (`tool_calls` shape).

Envelope confidence levels (required):
- `confident_strict`:
  - JSON parse succeeds and top-level shape contains `tool_calls` array with object entries containing `tool` field.
- `confident_heuristic` (for partial/incomplete stream chunks):
  - segment contains `"tool_calls"` and `"tool"` and either `"id"` or `"exec"` tokens in plausible JSON object context.
- `not_confident`:
  - anything else.

Default:
- if confidence is `confident_strict` or `confident_heuristic`, hide/collapse tool-envelope JSON blocks immediately (timing-independent of planned panel render).
- render a stable placeholder line in stream area:
  - `[tool json hidden; see Planned Tools]`

Debug override:
- `MOTOKO_SHOW_TOOL_JSON_STREAM=1` shows highlighted tool JSON blocks in stream area too.

Non-tool JSON:
- always shown and highlighted.

Deterministic precedence (required):
- visibility decision is made per segment based on envelope confidence, not on whether planned-tools panel is currently mounted.
- no retroactive flip/flop of previously rendered segments due to panel timing.
- if a segment transitions from heuristic to strict confidence as stream grows, keep same hidden+placeholder mode (no visual mode switch).

## Design

### 1. Dedicated JSON highlighter module

Add `json-highlight.ts`:
- tolerant tokenizer for keys, strings, numbers, booleans, null, punctuation.
- works on incomplete buffers without throwing.
- returns highlighted lines for TTY rendering.

### 2. Stream segment integration

In `stream-markdown.ts`:
- normalize JSON language tags.
- annotate segment metadata for `isJson`.
- detect bare/unfenced JSON regions and mark them as JSON segments (`json_bare` equivalent metadata/kind).
- define precedence:
  - fenced JSON classification wins inside fenced regions,
  - bare JSON detection applies only outside fenced regions.

In `ui.ts` stream renderer:
- for JSON segments, call JSON highlighter.
- apply tool-envelope visibility policy before rendering segment lines.
- render placeholder for hidden tool-envelope JSON segments in default mode.

### 3. Consistency with existing tool-plan UX

- planned-tools panel remains source-of-truth for tool execution timeline.
- JSON stream area should never be the only place where tool intent is shown.

## Implementation Phases

## Phase 1: JSON tokenizer/highlighter
Files:
- `src/tui/src/json-highlight.ts`
- `src/tui/src/json-highlight.test.ts`

Changes:
- Implement tolerant incremental-safe JSON token highlighter.
- Export line-based highlight function for UI reuse.

## Phase 2: Segment metadata updates
Files:
- `src/tui/src/stream-markdown.ts`

Changes:
- Add normalized JSON language detection helpers.
- Keep segment model backward compatible.

## Phase 3: UI rendering integration
Files:
- `src/tui/src/ui.ts`

Changes:
- Route JSON segments through JSON highlighter in live stream rendering.
- Apply tool-envelope visibility policy + env override.
- Preserve throttled, segment-diff rendering and scroll-stability behavior.

## Phase 4: Env wiring and docs-in-code comments
Files:
- optional `src/tui/src/index.ts`

Changes:
- Read/forward `MOTOKO_SHOW_TOOL_JSON_STREAM` behavior only if UI env access is intentionally centralized.
- Keep plain logger unchanged.

## Phase 5: Tests
Files:
- `src/tui/src/json-highlight.test.ts`
- `src/tui/src/ui.highlight.test.ts`
- `src/tui/src/tool-plan-parser.test.ts`

Coverage:
- Complete streamed JSON block highlighting.
- Incomplete streamed JSON highlighting (no throw, stable output).
- Complete bare/unfenced streamed JSON highlighting.
- Partial bare/unfenced streamed JSON across multiple deltas.
- Tool-envelope hidden by default in stream area when planned panel exists.
- Tool-envelope hidden immediately on confident detection even before planned panel appears.
- Hidden tool-envelope segments render stable placeholder (no flicker/flip-flop).
- Confidence transitions (`heuristic -> strict`) do not change visibility mode.
- Tool-envelope visible when `MOTOKO_SHOW_TOOL_JSON_STREAM=1`.
- Non-tool JSON remains visible and highlighted.

## Acceptance Criteria

- JSON code fences are highlighted while streaming.
- Partial JSON remains highlighted without flicker spikes or parser crashes.
- Bare/unfenced JSON blocks are highlighted while streaming.
- Tool JSON is hidden by default when planned-tools panel is active.
- Tool-envelope JSON hide/show is deterministic and independent of panel timing.
- Env override reveals tool JSON stream rendering for debug use.
- No duplicate assistant final output regressions.
- Existing plus new tests pass.

## Risks and Mitigations

- Misclassifying non-tool JSON as tool envelope:
  - Mitigate with strict envelope detection (`tool_calls` object shape).
- Highlight churn on large JSON streams:
  - Mitigate with existing stream throttle and segment-level updates.
- Incomplete JSON edge cases:
  - Mitigate with tolerant tokenizer (never strict-parse-only behavior).

## Out of Scope (Future Upgrade)

- Full semantic JSON folding and collapsible object tree UI.
- Runtime-emitted typed JSON token stream events.
- Per-language user theme customization.
