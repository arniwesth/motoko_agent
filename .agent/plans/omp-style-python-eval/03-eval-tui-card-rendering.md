# Plan: `eval` rich TUI card rendering (Option B)

Feature context: **[ADR-001](../../research/omp-style-python-eval/ADR-001-eval-mvp-local-loopback.md)** (the `eval` tool).
**Depends on [plan 01 (Design C)](./01-design-c-mvp-local-loopback.md) only.** Independent of [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md).
Toolchain: AILANG v0.19.1, Bun 1.3.x.

## Background

Design C (plan 01, Phase 5b) renders eval results as a **flattened plain-text transcript** through the generic tool-result path (`formatToolDetailLines`), with **zero `ui.ts` changes**. That ships the feature but throws away structure: every cell's stdout, JSON `display()` bundles, and per-cell pass/fail collapse into one preview-truncated blob with no syntax coloring and no per-cell expand/collapse.

This plan adds a **rich, expandable eval card** — the same UX pattern the `compose` extension already uses (`ComposeCardState` in `ui.ts`, fed by dedicated `compose_*` `AgentEvent` variants in `runtime-process.ts`). It renders from the **structured fields C already produces** (`cells`, `jsonOutputs`, `images` metadata on the `/exec-cell` response), so it has **no dependency on B′'s WebSocket loopback** — only on C's result payload. It can ship any time after C.

## Why this is a separate plan (not folded into B′)

The card renders the *result payload*; B′ changes only *where in-cell `tool.*` calls resolve*. They touch disjoint code. Coupling the card to B′ would gate a low-risk UX win behind the highest-risk, deferred work (the unproven effectful-dispatch-in-handler gap, plan 02 Phase 3 ⚠). Kept independent, plan 02 and plan 03 are parallel successors to plan 01.

## Goals

- A per-`eval`-call card: a header (cell count, pass/fail, total duration) + one expandable section per cell.
- Per cell: code/title, stdout, stderr, and **structured** display rendering — **JSON** via `highlightJsonLines()` (`json-highlight.ts`), **markdown** via `segmentStreamMarkdown()` / `trimSegmentsForLiveRender()` (`stream-markdown.ts`).
- Expand/collapse via the existing `Ctrl+O` pattern (mirrors the diff/output collapse already in `ui.ts`); error cells expanded by default.
- Graceful fallback: if structured fields are absent (e.g. an older brain, or the transcript-only path), fall back to the plan-01 flat-text rendering — never lose output.

## Non-goals

- **No inline images.** Images still render as artifact-path placeholders (`[image: <path> (<w>×<h> <mime>)]`, from plan 01 Phase 5b). True inline rendering needs a terminal-image capability (kitty/iTerm/sixel protocol + capability detection) that does not exist anywhere in the TUI today — a separate effort, deferred regardless of this plan.
- **No kernel, loopback, or extension changes.** The env-server kernels, `/exec-cell`, fencing, and `motoko_ext_eval` are untouched. The only new data is a structured eval event on the brain→TUI wire (Phase 1).
- **No dependency on B′.** Renders from C's final aggregated result.

---

## Architecture: get the structured payload to the TUI

Today the TUI wire `DelegatedResult` (`runtime-process.ts`) is flat — `{tool_call_id, stdout, stderr, exit_code, truncated}`, **no structured field**. So the card needs a structured channel. Mirror exactly how `compose` solved the same problem: **dedicated `AgentEvent` variants** carrying structured JSON, emitted by the brain alongside the normal tool result.

```
brain (eval on_tool_handle, after exec_cell returns)
   │  emits AgentEvent: { type: "eval_result", request_id, cells_json }   ◀── new wire event (like compose_result)
   ▼
runtime-process.ts  (parse + forward the event)
   ▼
ui.ts  EvalCardState  ── renders header + per-cell sections (json-highlight / stream-markdown / Ctrl+O)
```

The normal `DelegatedResult` (flat transcript from plan 01) **still flows** — the card is an *additive* richer view keyed by `request_id`; if the event is missing, the flat row stands. This is precisely the `compose` model (the flat tool row + the rich `ComposeCardState` coexist).

---

## Phase 1 — structured eval event on the brain→TUI wire

**Files:** `src/core/` (brain emit site in `motoko_ext_eval` result handling / `rpc.ail` event stream), `src/tui/src/runtime-process.ts` (new `AgentEvent` variant + parse).

- Add an `AgentEvent` variant mirroring `compose_result`:
  `{ type: "eval_result"; request_id: string; step: number; cells_json: string }` where `cells_json` is the `{cells, jsonOutputs, images}` payload C already builds (plan 01 Phase 5/5b `metadata`).
- The brain emits it right after `env_client.exec_cell` returns, in the same place it produces the flat `ToolResultEnvelope`. (For C this is a single post-result event; B′ could later stream per-cell events — see Synergy.)
- `runtime-process.ts` parses and forwards it, exactly like the `compose_*` events at `runtime-process.ts:71–83`.

**Acceptance:** a unit test asserts `eval_result` round-trips through `runtime-process` parsing with the structured cells intact.

---

## Phase 2 — `EvalCardState` + renderer in `ui.ts`

**Files:** `src/tui/src/ui.ts`, `src/tui/src/ui.eval-card.test.ts` (new).

- Add `EvalCardState` modeled on `ComposeCardState` (`ui.ts` ~840–880): `requestId`, `cells: EvalCellResult[]`, `expanded` flags, header `Text` row, body `Text` rows.
- **Header row:** `eval · N cells · ✓P ✗F · {duration}ms` using `formatStatusLine`/`formatToolRow` conventions already in `ui.ts`.
- **Per-cell body:** title/language line; stdout (preview + collapse); stderr (red, preview); display bundles:
  - JSON → `highlightJsonLines(JSON.stringify(value, null, 2))`.
  - markdown → `trimSegmentsForLiveRender(segmentStreamMarkdown(text), cap)`.
  - status events → one dim line each.
  - images → `[image: <path> (<w>×<h> <mime>)]` (placeholder; Non-goals).
- Register an `eval` entry in the `TOOL_RENDERERS` registry for the call line, consistent with the existing renderer-fallback pattern (`renderToolCallMetaWithFallback`).

**Acceptance:** a snapshot test renders a 3-cell card (one stdout, one JSON display, one error) with correct header counts, JSON coloring present, and the error cell expanded by default.

---

## Phase 3 — expand/collapse interaction + truncation

**Files:** `src/tui/src/ui.ts`.

- Wire the card into the existing `Ctrl+O` expand/collapse handling used for diffs/output (`ui.ts:1129/1139/1159`). Collapsed: header + first cell preview. Expanded: all cells full (subject to per-cell caps).
- Per-cell output caps mirror the generic previews (8 stdout / 4 stderr lines collapsed; full when expanded), with the `... N more (Ctrl+O …)` affordance.

**Acceptance:** toggling `Ctrl+O` on an eval card expands/collapses all cells; collapsed state shows the header + first-cell preview; large cells truncate with the standard affordance.

---

## Phase 4 — fallback + tests

**Files:** `src/tui/src/ui.ts`, tests.

- **Fallback:** if no `eval_result` event arrived for a `request_id` (older brain, transcript-only path, or parse failure), render the flat `DelegatedResult.stdout` via the existing `formatToolDetailLines` — never lose output. Test this path explicitly.
- **Tests:** `cd src/tui && bun run test` — card rendering snapshot, header counts, JSON/markdown rendering, expand/collapse, image-placeholder, and the flat-fallback.
- **Regression:** existing `ui.tool-render` tests stay green; non-eval tool rows are unchanged.

---

## Synergy with B′ (cross-reference, not a dependency)

Once [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md) lands, the brain already hosts a `runEventLoop` over the eval channel — it could emit **per-cell `eval_cell_start` / `eval_cell_result` events live** as frames arrive, turning this static post-result card into a streaming one (cells fill in as they run). That's an additive enhancement to this card, not a precondition: under C the card renders fine from the single final `eval_result`. Note the hook in both plans so whoever builds B′ knows the card is ready to consume live events.

## Sequencing & risks

1. Phase 1 (wire) → 2 (card + renderer) → 3 (interaction) → 4 (fallback + tests).
2. **Risks:**
   - *Wire-extension surface* — touches both the brain emit site and `runtime-process`/`ui`. Well-trodden: `compose_*` did exactly this; follow its shape to de-risk.
   - *Card state lifecycle* — keying `EvalCardState` by `request_id` and reconciling with the flat row; reuse the `ComposeCardState` lifecycle rather than inventing one.
   - *Scope temptation: inline images* — explicitly out; resist pulling the terminal-image capability into this plan.
