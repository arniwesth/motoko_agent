# TUI Tool Call Rendering UI Specification

Version: v1.0 (implementation-ready)
Status: Draft for implementation handoff
Owner: TUI (`src/tui/src/ui.ts`)

## 1. Purpose
Define a deterministic, hybrid-only tool rendering model for Motoko TUI history and status bar so tool execution is readable at scale, stable under progress updates, and safe under partial/malformed data.

## 2. Scope
- In scope:
  - Hybrid tool events only: `tool_calls`, `tool_results`, `native_tool_calls`, `native_tool_results`.
  - History rendering for delegated and native tools.
  - Tool batch lifecycle headers and per-tool row states.
  - Compact and expanded row forms.
  - Output preview, truncation, and omitted-line messaging.
  - Status bar coupling to active delegated batch.
- Out of scope:
  - Legacy `proposed_cmd` / `obs` rendering.
  - Runtime protocol changes in `src/core/rpc.ail`.
  - General markdown/think-block UX redesign.
  - Theme system redesign.

## 3. UX Goals
- Keep default tool rendering compact and scan-friendly.
- Preserve enough detail to debug failures without leaving the TUI.
- Ensure progress updates are monotonic and deduplicated.
- Keep rendering deterministic for repeated/reordered progress events.
- Keep behavior stable on narrow terminal widths.

## 4. Non-Goals
- Pixel-perfect parity with Pi/Gemini/Codex.
- Most per-tool bespoke components in v1 (except deferred edit-diff renderer milestone).
- Interactive per-row cursor navigation in v1.

## 5. Current-State Baseline (for migration)
Current implementation already provides:
- Per-batch header rows in `toolBatchHeaders`.
- Per-tool rows in `toolRows` with stable metadata in `toolRowMeta`.
- Delegated batch counters in `toolBatchState` and dedupe via `seen`.
- Active batch pointer `activeToolRequestId` for status bar coupling.
- Run state transitions: `tools_wait` -> `tools_run` -> `thinking`.

This spec keeps those structures and extends rendering policy, not protocol shape.

## 6. Renderer Architecture

### 6.1 Registry Model
Introduce a renderer registry in TUI layer:
- `toolRenderers: Record<string, ToolRenderer>`.
- Key: canonical tool name (`ReadFile`, `Search`, `WriteFile`, `BashExec`, `RunTests`, etc.).
- Unknown tools use generic fallback renderer.

### 6.2 ToolRenderer Contract
`ToolRenderer` supports these logical hooks:
- `renderCall(call, ctx) -> RowRender`
- `renderResult(result, ctx) -> RowRender`
- Optional `mergeCallAndResult: boolean`.
- Optional `inline: boolean`.

Contract notes:
- `mergeCallAndResult=true`: single row evolves from queued/running to final result.
- `inline=true`: renderer skips boxed/extra-prefix style and uses flat history grammar.
- Renderer output must be pure from `(data, expanded, width)` and never mutate batch counters.

### 6.3 Fallback Renderer
If no renderer exists, or custom renderer throws:
- Render deterministic generic row grammar (Section 8).
- Emit one debug activity-log line when activity pane is enabled.
- Never drop tool rows/events.

## 7. Shared Status-Line Contract
All batch headers and row-leading status text must use the same field model:
- `icon`: one of `queued | running | done | failed | warning | info | background`.
- `title`: primary label (`tools <request_id>` for headers, `<tool> <target>` for rows).
- `description`: optional compact details.
- `badge`: optional bracket token (for example `[truncated]`).
- `meta[]`: optional key-value fragments (`exit=1`, `2/5 done`, `failed=1`).

### 7.1 Canonical Icon/Color Mapping
- `queued`: icon `~`, color `chalk.dim`
- `running`: icon spinner frame (`| / - \\`), color `chalk.yellow`
- `done`: icon `+`, color `chalk.green`
- `failed`: icon `x`, color `chalk.red`
- `warning`: icon `!`, color `chalk.yellow`
- `info`: icon `i`, color `chalk.cyan`
- `background`: icon `~`, color `chalk.dim`

If terminal/font rendering is degraded, tags (`[queued]`, `[running]`, `[done]`, `[failed]`) remain authoritative and must still be shown.

## 8. Visual Grammar

### 8.1 Batch Header (Compact)
Canonical format:
- Queued: `[tools] <request_id> queued (<N> call(s))`
- Running: `[tools] <request_id> running (<done>/<total> done, failed=<failed>)`
- Done: `[tools] <request_id> done (<N> result(s))`

### 8.2 Row (Compact)
Canonical format:
- Queued: `  [queued] <tool-meta>`
- Running: `  [running] <tool-meta>`
- Final: `  [done|failed] <tool-meta> exit=<code> [truncated]`

`<tool-meta>` comes from `describeToolCall` (or grouped policy output for grouped tools).

### 8.3 Row (Expanded)
Expanded row appends details below compact line (indented by two spaces):
- Argument preview lines (max lines from Section 9).
- Output preview lines from `stdout`/`stderr` policy.
- Omitted-line marker if output is longer than preview.

Expanded rows must never remove compact summary line.

## 9. Output Handling Policy

### 9.1 Preview Limits
Default limits (v1):
- Collapsed: no body output lines.
- Expanded:
  - `stdout`: up to 8 lines.
  - `stderr`: up to 4 lines.
  - Max rendered line width: terminal width minus timestamp/prefix margin.

### 9.2 Truncation Rules
- Long lines are hard-truncated to available width with `...` suffix.
- If renderer truncates by line count, append marker:
  - `  ... <N> more lines (Ctrl+O to collapse)` when expanded.
  - `  ... output hidden (Ctrl+O to expand)` when collapsed and output exists.
- If runtime result has `truncated=true`, append `[truncated]` badge on compact final line.

### 9.3 Stdout/Stderr Formatting
- `stdout` shown as plain/dim lines.
- `stderr` shown with `[stderr]` prefix and red/dim style.
- Empty output: omit detail body entirely.

## 10. Streaming Rules
These rules apply to progress-heavy updates and future streaming-compatible delegated tools.

- Progress update coalescing interval: 50ms minimum between visual row refreshes for the same `tool_call_id`.
- History row count must remain stable per tool call; updates mutate existing row text.
- Keep at most last 200 preview candidate lines per tool row in memory for expanded rendering.
- On terminal width changes, recompute truncation on next render; do not recompute persisted raw outputs.

## 11. Interaction Model

### 11.1 Global Expansion Toggle
- `Ctrl+O` toggles tool detail expansion globally (`collapsed` <-> `expanded`).
- Toggle applies to existing and future tool rows.
- Default state at session start: `collapsed`.

### 11.2 Think-Block Compatibility
- Existing `Ctrl+T` think-block cycle remains unchanged.
- `Ctrl+O` must not affect non-tool history rows.

## 12. Async/Background Tool Lifecycle

### 12.1 Batch-Level States
- `queued`: after `tool_calls` or `native_tool_calls`.
- `running`: after delegated `tool_results phase=running`.
- `progress`: while delegated `phase=progress` events continue.
- `done`: after delegated `phase=done` or native `native_tool_results`.

### 12.2 Row-Level States
- `queued` -> `running` -> `done|failed`.
- Duplicate progress for same `tool_call_id` after terminal state (`done|failed`) is ignored.
- Re-entry rule: if a row is terminal and a new event arrives with same `tool_call_id` in same request, keep first terminal status and log activity warning (when enabled).

### 12.3 Finalization
- Batch finalization sets `active=false`, `running=0` in `toolBatchState`.
- Delegated finalization transitions run state back to `thinking` and emits continuation hint line.
- Native finalization does not force run-state transition by itself.

## 13. Grouped Tool Policy

### 13.1 Initial Grouped Tool
Grouped rendering is enabled first for `ReadFile` only.

### 13.2 Group Semantics
Within one `request_id`:
- If `ReadFile` call count >= 2, render as a grouped block:
  - Header: `  [group] ReadFile (<N>)`
  - Children: `    [status] <path> lines <start>-<end>`
- Single `ReadFile` call remains a normal row.

### 13.3 Extensibility Contract
Future grouped tools must define:
- Group key function (`request_id + tool family`).
- Child row identity (`tool_call_id`).
- Status aggregation rule for header (`failed` if any child failed; else `done` when all done).

## 14. Event-to-Render Transition Table

| Incoming event | Preconditions | Header update | Row update | Status bar coupling |
|---|---|---|---|---|
| `tool_calls(request_id, calls)` | none | create queued header with total | create queued rows for each call | set active batch to `request_id`; state `tools_wait` |
| `tool_results(phase=running)` | batch exists or created lazily | set header running | set all batch rows to running | set run state `tools_run` |
| `tool_results(phase=progress, results)` | delegated batch | running counters updated with dedupe | update only rows in `results` to done/failed | keep `tools_run`; reflect done/failed counts |
| `tool_results(phase=done, results)` | delegated batch | set done header | update rows in `results`; finalize unseen rows as failed with `exit=1` + `[missing-result]` marker | set run state `thinking`; clear active batch if matching |
| `native_tool_calls(request_id, calls)` | none | create queued header | create queued rows | do not claim delegated active-batch status |
| `native_tool_results(request_id, results)` | native batch | set done header | set rows done/failed by exit code | no forced run-state transition |

Notes:
- The `phase=done` unseen-row rule prevents stranded `[running]` rows when result cardinality is inconsistent.
- `applyToolProgressCounters` remains source of truth for dedupe on delegated progress.

## 15. Data and State Model

### 15.1 Existing Fields (Retained)
- `toolRows: Map<requestId:toolCallId, Text>`
- `toolRowMeta: Map<requestId:toolCallId, string>`
- `toolBatchHeaders: Map<requestId, Text>`
- `toolBatchState: Map<requestId, ToolBatchState>`
- `activeToolRequestId: string | null`

### 15.2 New Fields (Required)
- `toolOutputExpanded: boolean` (global Ctrl+O toggle).
- `toolRowDetails: Map<requestId:toolCallId, ToolRowDetails>` where details include:
  - latest `stdout`, `stderr`, `truncated`, `exit_code`, `status`.
  - optional cached preview lines.
- `toolGroups: Map<groupId, ToolGroupState>` for grouped policy.
- `lastToolRenderMs: Map<requestId:toolCallId, number>` for 50ms throttle.

## 16. Error and Edge-Case Handling
- Missing `request_id`: render under synthetic request id `unknown:<counter>`.
- Missing `tool_call_id`: use `unknown:<rowCounter>` and mark row with `[warning] missing_id`.
- Duplicate `tool_calls` for same `(request_id, tool_call_id)`: keep first row, refresh meta only.
- Out-of-order `tool_results` before `tool_calls`: lazily create header and placeholder row.
- Renderer exception: fallback row grammar, never crash UI loop.

## 17. Acceptance Criteria
- Deterministic mapping for all in-scope event types and delegated phases.
- Compact and expanded row formats are both implemented and snapshot-tested.
- Progress dedupe correctness retained (`applyToolProgressCounters` behavior unchanged).
- Global `Ctrl+O` expansion works without affecting think-block controls.
- Grouped `ReadFile` rendering works for 2+ rows and degrades to single-row format for 1 row.
- Renderer failure fallback is covered by tests and preserves visibility of tool outcome.
- Narrow-width rendering remains readable (no unbounded wrapping loops; truncation markers present).
- Deferred-final milestone: file edit tool rows render diff preview (collapsed hunk summary + expanded diff) with deterministic truncation markers.

## 18. Test Plan

### 18.1 Unit Tests
- Extend `src/tui/src/ui.wait-state.test.ts`:
  - done/progress dedupe invariants (existing + regression cases).
  - unseen-row finalization behavior on `phase=done`.
- Add `src/tui/src/ui.tool-render.test.ts`:
  - compact row/header snapshots for each lifecycle state.
  - expanded output preview + omitted-lines markers.
  - renderer fallback behavior on thrown exception.
  - grouped `ReadFile` output formatting.
  - edit-tool diff preview rendering (collapsed + expanded) and truncation markers.
- Add `src/tui/src/ui.tool-events.test.ts`:
  - out-of-order and missing-id events.
  - native/delegated parity and divergence rules.

### 18.2 Integration Tests
- Keep `src/tui/src/runtime-process.tool-progress.test.ts` as protocol ordering baseline.
- Add integration assertion for delegated event stream:
  - `tool_calls` -> `running` -> `progress*` -> `done` produces monotonic header/row states.

## 19. Implementation Slices
1. Introduce shared formatting helpers and row detail state (no behavior change).
2. Add expanded/collapsed rendering + `Ctrl+O` toggle.
3. Add generic output preview/truncation policy.
4. Add grouped `ReadFile` rendering.
5. Add renderer registry/fallback wrapper for tool-specific overrides.
6. Add edge-case handling and finalize tests.
7. Deferred final slice: add edit-tool (`WriteFile` / file-edit family) diff renderer:
   - Collapsed: file path + operation + hunk/file summary.
   - Expanded: bounded diff preview with omitted-line counters.
   - Fallback to generic output when structured diff payload is unavailable.
   - Note: this is tool-call row diff rendering only. LLM markdown/codeblock diff rendering is already implemented and tracked in:
     - `.agent/plans/TUI_Code_Block_Rendering.md`
     - `.agent/summaries/2026-04-08-tui-codeblock-and-diff-rendering.md`
   - Reuse requirement: existing LLM diff rendering utilities/components should be reused for tool-call edit diff rendering wherever compatible; avoid re-implementing parallel diff formatting logic.

## 20. Open Follow-Ups (Post-v1)
- Per-row expansion/focus model (instead of global toggle).
- Rich tool-specific components (beyond deferred edit-diff), JSON tree rendering.
- Background async state beyond current delegated/native protocol.
