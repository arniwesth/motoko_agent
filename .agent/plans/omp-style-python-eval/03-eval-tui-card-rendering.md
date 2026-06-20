# Plan: `eval` rich TUI card rendering (Option B)

Feature context: **[ADR-001](../../research/omp-style-python-eval/ADR-001-eval-mvp-local-loopback.md)** (the `eval` tool).
**Depends on [plan 01 (Design C)](./01-design-c-mvp-local-loopback.md) only.** Independent of [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md).
Toolchain: AILANG v0.19.1, Bun 1.3.x.

## Background

Design C (plan 01, Phase 5b) renders eval results as a **flattened plain-text transcript** through the generic tool-result path (`formatToolDetailLines`), with **zero `ui.ts` changes**. That ships the feature but throws away structure: every cell's stdout, JSON `display()` bundles, and per-cell pass/fail collapse into one preview-truncated blob with no syntax coloring and no per-cell expand/collapse.

This plan adds a **rich, expandable eval card** — the same UX pattern the `compose` extension already uses (`ComposeCardState` in `ui.ts`, fed by dedicated `compose_*` `AgentEvent` variants in `runtime-process.ts`). It renders from the **structured fields C already produces** (`cells`, `jsonOutputs`, `images` metadata on the `/exec-cell` response), so it has **no dependency on B′'s WebSocket loopback** — only on C's result payload. It can ship any time after C.

## Why this is a separate plan (not folded into B′)

The card renders the *result payload*; B′ changes only *where in-cell `tool.*` calls resolve*. They touch disjoint code. Coupling the card to B′ would gate a low-risk UX win behind the highest-risk, deferred work (the unproven effectful-dispatch-in-handler gap, plan 02 Phase 3 ⚠). Kept independent, plan 02 and plan 03 are parallel successors to plan 01.

## Reference layout (the oh-my-pi screenshot)

Target = `.agent/research/omp-style-python-eval/Screenshot 2026-06-14 at 20.14.52.png`: two stacked cell cards, each with a `✓ [i/N] title (duration)` header, the cell's **syntax-highlighted source**, an `─ Output` divider, the captured output, and a `… N more lines (ctrl+o to expand)` affordance; then the assistant's narrative summary; an `OMP · EVAL` corner tag.

**Every element maps to a primitive that already exists in Motoko's TUI — this card is wiring, not new infrastructure.** Verified:

| Screenshot element | Motoko TUI primitive | Status |
|---|---|---|
| Stacked per-cell cards | `ComposeCardState` pattern (`ui.ts`) | exists |
| `✓ [i/N] title (duration)` header | status icon + `formatStatusLine`/`formatToolRow` + duration | exists |
| Syntax-highlighted **Python** source | `highlightCodeLines(code, "python")` → `highlightPyLine` (`ui.ts:603`) | **exists** |
| Syntax-highlighted **JS** source | `highlightCodeLines(code, "js")` → `highlightTsLine` (`ui.ts:599`) | **exists** |
| `─ Output` divider | one dim `chalk` line | trivial |
| Output + `… N more lines (ctrl+o to expand)` | `formatToolDetailLines` preview + `Ctrl+O` collapse (`ui.ts:1129/1139/1159`) | exists |
| Trailing narrative summary | assistant markdown via `segmentStreamMarkdown` | exists |
| `OMP · EVAL` corner tag | a small `EVAL` badge label | trivial |

**The screenshot contains no inline images** (the pandas `describe()` is text output), so the one capability Motoko lacks — terminal-image rendering — is **not required** to reproduce this exact layout. That is why inline images stay out of scope (Non-goals) without compromising the target view.

## Goals

- A per-`eval`-call card: a header (cell count, pass/fail, total duration) + one expandable section per cell, plus an `EVAL` card badge.
- Per cell, matching the reference layout: a `✓ [i/N] title (duration)` header line; the cell's **syntax-highlighted source** via `highlightCodeLines(cell.code, cell.language)` (the cell language `"py"`/`"js"` is accepted by `highlightCodeLines` as-is — `ui.ts:599,603` — so no mapping is needed); an `─ Output` divider; then stdout, stderr, and **structured** display rendering — **JSON** via `highlightJsonLines()` (`json-highlight.ts`), **markdown** via `segmentStreamMarkdown()` / `trimSegmentsForLiveRender()` (`stream-markdown.ts`).
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
   │  emits AgentEvent: { type: "eval_result", tool_call_id, request_id, cells_json }   ◀── new wire event (like compose_result)
   ▼
runtime-process.ts  (parse + forward the event)
   ▼
ui.ts  EvalCardState  ── renders header + per-cell sections (highlightCodeLines / json-highlight / stream-markdown / Ctrl+O)
```

The normal `DelegatedResult` (flat transcript from plan 01) **still flows** — the card is an *additive* richer view keyed by `tool_call_id`; if the event is missing, the flat row stands. This is precisely the `compose` model (the flat tool row + the rich `ComposeCardState` coexist).

---

## Phase 1 — structured eval event on the brain→TUI wire

**Files:** `src/core/` (brain emit site in `motoko_ext_eval` result handling / `rpc.ail` event stream), `src/tui/src/runtime-process.ts` (new `AgentEvent` variant + parse).

- Add an `AgentEvent` variant mirroring `compose_result`:
  `{ type: "eval_result"; tool_call_id: string; request_id: string; step: number; cells_json: string }`.
  - **`tool_call_id` is the correlation key** — it must equal the `tool_call_id` of the flat `DelegatedResult` for this eval call so the card can attach to / reconcile with that row (verified: `tool_results` events carry `request_id` for the batch, but each result row is keyed by `tool_call_id` — `runtime-process.ts:39,96`). `request_id` is kept for batch context only.
  - **`cells_json` decodes to `EvalCellResult[]` with output and display bundles *per cell*** — each cell carries `{index, title?, language, code, status, durationMs?, exitCode?, stdout, stderr, display: EvalDisplayOutput[]}`, where `display` is that cell's ordered JSON/markdown/image/status bundles. (Adapted from oh-my-pi's `EvalCellResult`, which uses a single combined `output`; Motoko keeps `stdout`/`stderr` separate so the card can render stderr distinctly — see Phase 2.) This is faithful to the kernel frames (`runner.py` emits `stdout`/`stderr`/`display`/`result` keyed by cell id) and is what lets the card render output and bundles **under the right cell**. ⚠ **Contract on plan 01:** plan 01 Phase 5b currently aggregates `images`/`jsonOutputs` at tool level; for this card it must instead attach each bundle to its originating `EvalCellResult`. Small change to plan 01's payload shape — flag it there.
- The brain emits it right after `env_client.exec_cell` returns, in the same place it produces the flat `ToolResultEnvelope`. (For C this is a single post-result event; B′ could later stream per-cell events — see Synergy.)
- `runtime-process.ts` parses and forwards it, exactly like the `compose_*` events at `runtime-process.ts:71–83`.

**Acceptance:** a unit test asserts `eval_result` round-trips through `runtime-process` parsing with per-cell `display` bundles intact, and that its `tool_call_id` matches the corresponding `DelegatedResult`.

---

## Phase 2 — `EvalCardState` + renderer in `ui.ts`

**Files:** `src/tui/src/ui.ts`, `src/tui/src/ui.eval-card.test.ts` (new).

- Add `EvalCardState` modeled on `ComposeCardState` (`ui.ts` ~840–880): `toolCallId`, `cells: EvalCellResult[]`, `expanded` flags, header `Text` row, body `Text` rows. (`EvalCellResult` is the type ported in plan 01 Phase 1 from oh-my-pi `eval/.../types.ts`; it must be importable by `ui.ts`, so define it in a shared `src/tui/src/eval/types.ts` rather than inside the env-server module.)
- **Card header row:** `EVAL · N cells · ✓P ✗F · {duration}ms` using `formatStatusLine`/`formatToolRow` conventions already in `ui.ts` (the `EVAL` badge is the corner-tag equivalent).
- **Per-cell section** (matches the reference screenshot, top to bottom):
  1. **Cell header line:** `✓`/`✗` status icon · `[i/N]` index · `title` · `(duration)ms`.
  2. **Highlighted source:** `highlightCodeLines(cell.code, cell.language)` — the cell `language` `"py"`/`"js"` is accepted directly and routes to `highlightPyLine` (`ui.ts:603`) / `highlightTsLine` (`ui.ts:599`). No mapping and no new highlighter needed.
  3. **`─ Output` divider** — one dim `chalk` rule line.
  4. **Output:** stdout (preview + collapse); stderr (red, preview); display bundles:
     - JSON → `highlightJsonLines(JSON.stringify(value, null, 2))`.
     - markdown → `trimSegmentsForLiveRender(segmentStreamMarkdown(text), cap)`.
     - status events → one dim line each.
     - images → `[image: <path> (<w>×<h> <mime>)]` (placeholder; Non-goals — not needed for the target layout).
- Register an `eval` entry in the `TOOL_RENDERERS` registry for the call line, consistent with the existing renderer-fallback pattern (`renderToolCallMetaWithFallback`).

**Acceptance:** a snapshot test renders a 2-cell card mirroring the reference screenshot — a `py` cell (highlighted Python source + `─ Output` + a multi-line table truncated with the `ctrl+o to expand` affordance) and a `js` cell (highlighted JS source + single-line output) — with correct `[i/N]` headers, per-cell durations, language-appropriate code coloring, and the `EVAL` badge.

---

## Phase 3 — expand/collapse interaction + truncation

**Files:** `src/tui/src/ui.ts`.

- Reuse the existing expand/collapse UX: model the toggle on `ComposeCardState.expanded` (the card owns an `expanded` flag driven by the same key path that expands compose cards / collapsed output); the `... N more (Ctrl+O to expand)` affordance *text* matches `ui.ts:1129/1139/1159`. Collapsed: header + first cell preview. Expanded: all cells full (subject to per-cell caps).
- Per-cell output caps mirror the generic previews (8 stdout / 4 stderr lines collapsed; full when expanded), with the `... N more (Ctrl+O …)` affordance.

**Acceptance:** toggling `Ctrl+O` on an eval card expands/collapses all cells; collapsed state shows the header + first-cell preview; large cells truncate with the standard affordance.

---

## Phase 4 — fallback + tests

**Files:** `src/tui/src/ui.ts`, tests.

- **Fallback:** if no `eval_result` event arrived for a `tool_call_id` (older brain, transcript-only path, or parse failure), render the flat `DelegatedResult.stdout` via the existing `formatToolDetailLines` — never lose output. Test this path explicitly.
- **Tests:** `cd src/tui && bun run test` — card rendering snapshot, header counts, JSON/markdown rendering, expand/collapse, image-placeholder, and the flat-fallback.
- **Regression:** existing `ui.tool-render` tests stay green; non-eval tool rows are unchanged.

---

## Synergy with B′ (cross-reference, not a dependency)

Once [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md) lands, the brain already hosts a `runEventLoop` over the eval channel — it could emit **per-cell `eval_cell_start` / `eval_cell_result` events live** as frames arrive, turning this static post-result card into a streaming one (cells fill in as they run). That's an additive enhancement to this card, not a precondition: under C the card renders fine from the single final `eval_result`. Note the hook in both plans so whoever builds B′ knows the card is ready to consume live events.

## Sequencing & risks

1. Phase 1 (wire) → 2 (card + renderer) → 3 (interaction) → 4 (fallback + tests).
2. **Risks:**
   - *Wire-extension surface* — touches both the brain emit site and `runtime-process`/`ui`. Well-trodden: `compose_*` did exactly this; follow its shape to de-risk.
   - *Card state lifecycle* — keying `EvalCardState` by `tool_call_id` and reconciling with the flat row; reuse the `ComposeCardState` lifecycle rather than inventing one.
   - *Scope temptation: inline images* — explicitly out; resist pulling the terminal-image capability into this plan.
