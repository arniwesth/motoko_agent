# TUI Streamed Tool-Plan UX Plan

## Expected File Changes (Planned)

### Modified files
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/index.ts`
- `src/tui/src/__tests__/ui.test.ts`
- `src/tui/src/__tests__/index.test.ts`

### Added files
- `src/tui/src/tool-plan-parser.ts` (new)
- `src/tui/src/__tests__/tool-plan-parser.test.ts` (new)

## Goal

Keep streamed tool-call visibility, but present it as a coherent execution timeline instead of raw JSON followed by separate tool result logs.

## Key UX Requirements

- Preserve live visibility of model planning during streaming.
- Default expanded in TTY for streamed tool-plan content.
- Avoid duplicate/conflicting representations of the same tool call.
- Keep plain/non-TTY output compact and CI-friendly.
- Do not change runtime execution semantics in this phase.

## Problem Statement

Current flow interleaves:
- streamed raw JSON content (`tool_calls` block),
- then runtime execution events (`native_tool_calls`, `tool_calls`, `*_tool_results`),
- then final assistant prose.

This creates a double-render effect (intent as raw JSON, then intent again as executed calls) and weakens scanability under heavy tool use.

## Design

### 1. Two-layer rendering with one timeline

- Keep receiving `thinking_delta` as-is.
- Derive a structured, incremental `tool plan` view from streamed text.
- Render a dedicated “Planned Tools (streaming)” block that is expanded by default in TTY.
- When runtime emits execution events, map by canonical identity key and transition status:
  - `planned` -> `running` -> `done`/`error`.

Result: user still sees model intent live, but with one stable row per canonical identity.

### 2. Raw stream presentation policy

- TTY:
  - show “Planned Tools (streaming)” expanded by default,
  - keep raw streamed text visible but de-emphasized (collapsed toggle optional, not required for first cut).
- Non-TTY/plain:
  - no raw token-by-token JSON dump by default,
  - emit concise phase lines and final tool summaries.

### 3. Incremental tool-call extraction

Implement a tolerant incremental extractor over streamed deltas:
- Accumulate a bounded window of current assistant stream text.
- Detect candidate fenced JSON or bare JSON object containing `tool_calls`.
- Parse only when candidate is syntactically complete; ignore partial fragments.
- On parse success, publish normalized planned calls:
  - `{id, tool, args summary, source: "stream"}`
- If parsing fails repeatedly, do not surface parser errors to user; continue fallback rendering.

Concrete limits and eviction policy:
- `streamText` cap: 128 KiB per assistant step.
- parser candidate window cap: 64 KiB rolling tail.
- On cap overflow, drop oldest bytes and set a per-step flag (`stream_truncated_for_parse=true`) for diagnostics.

## Data Model Changes (TUI-side)

Add UI-internal state per assistant step:
- `streamText: string`
- `plannedTools: Map<string, PlannedTool>`
- `toolStatus: Map<string, "planned" | "running" | "done" | "error" | "planned_unexecuted" | "runtime_only" | "filtered">`
- `ttyExpanded: { plannedTools: true }` default true

`PlannedTool`:
- `id: string`
- `tool: string`
- `summary: string`
- `origin: "stream" | "runtime"`

Canonical identity key (required):
- Prefer `step + request_id + tool_call_id`.
- Fallback when missing IDs: `step + request_id + tool + normalized_args_hash + first_seen_index`.
- Never dedupe globally by `tool_call_id` alone.

Reconciliation rules (required):
- Stream-planned call that never appears in runtime batch -> `planned_unexecuted`.
- Runtime-emitted call with no streamed match -> `runtime_only`.
- Call denied/policy-blocked before execution -> `filtered`.
- Runtime result always wins terminal state (`done`/`error`) for the row.

No protocol change required for phase 1.

## Implementation Phases

## Phase 1: UI state and rendering skeleton
Files:
- `src/tui/src/ui.ts`

Changes:
- Add per-step planned-tool state and merged status timeline.
- Add a dedicated rendering section for “Planned Tools (streaming)”.
- Ensure section is expanded by default in TTY.
- Keep existing tool results rendering, but route through merged status model.

## Phase 2: Stream extraction pipeline
Files:
- `src/tui/src/runtime-process.ts`
- `src/tui/src/ui.ts`
- `src/tui/src/tool-plan-parser.ts`

Changes:
- In event handling path for `thinking_delta`, feed incremental parser.
- Emit internal UI updates for planned tool entries.
- Deduplicate by canonical identity key (not `tool_call_id` only).

## Phase 3: Plain logger policy cleanup
Files:
- `src/tui/src/index.ts`

Changes:
- Replace raw streamed JSON token logging with concise planning/execution summaries.
- Keep one final assistant text emission path (avoid duplication).
- Add debug override: `MOTOKO_PLAIN_VERBOSE_STREAM=1` to re-enable raw stream output in non-TTY mode.

## Phase 4: Tests
Files:
- `src/tui/src/__tests__/ui.test.ts`
- `src/tui/src/__tests__/index.test.ts`
- `src/tui/src/__tests__/tool-plan-parser.test.ts`

Coverage:
- Planned tool appears during stream before execution.
- Planned -> running -> done transitions by canonical identity key (including missing-ID fallback case).
- TTY default expansion is true.
- Non-TTY logs stay compact and non-duplicative.
- Reconciliation cases:
  - streamed-only (`planned_unexecuted`)
  - runtime-only (`runtime_only`)
  - filtered (`filtered`)
- Buffer-limit behavior:
  - parser truncation flag set
  - no crash on very long streamed JSON/no-JSON content

## Acceptance Criteria

- While streaming a `tool_calls` JSON response, user sees planned tools live in TTY.
- Planned tools are expanded by default in TTY.
- The same call is not rendered as disconnected duplicates.
- Execution results update planned entries by ID.
- Plain mode does not dump verbose streamed JSON by default.
- Parser and parser tests are included in the same rollout (not deferred).
- Canonical identity and reconciliation states are implemented and validated.

## Risks and Mitigations

- Incremental parse false positives:
  - Mitigate with strict key checks (`tool_calls` array shape, known fields).
- Parse churn from partial fragments:
  - Mitigate with bounded buffering and parse only on structurally complete candidates.
- UX ambiguity between planned vs executed:
  - Mitigate with explicit status badges and phase labels.
- High-volume stream memory growth:
  - Mitigate with explicit per-step caps and rolling tail eviction.

## Out of Scope (Future Upgrade)

- Runtime-level typed `tool_plan_delta` protocol event emitted directly from Motoko/AILANG.
- Cross-provider semantic tool-plan extraction guarantees.
- Advanced interactive collapse/expand commands.
