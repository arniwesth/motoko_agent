# Plan: `eval` inline terminal image rendering (Kitty / iTerm2)

Feature context: **[ADR-001](../../research/omp-style-python-eval/ADR-001-eval-mvp-local-loopback.md)** (the `eval` tool) and **[plan 03](./03-eval-tui-card-rendering.md)** (the rich eval card).
**Depends on plan 01 (Design C) and plan 03 (eval card) being shipped** — both are, on this branch (commit "Implemented plan 03").
Independent of [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md).
Toolchain: AILANG v0.19.1, Bun 1.3.x, `@mariozechner/pi-tui` ^0.64.0.

## Background

Plans 01–03 all carried **"no inline images"** as an explicit Non-goal, justified by the claim that *"a terminal-image capability doesn't exist anywhere in the TUI today."* **That premise is false.** Investigation (session `2026-06-15T13-11-25-999Z`, verified against `node_modules`) shows:

- **pi-tui v0.64.0 ships a complete terminal-image stack** (`@mariozechner/pi-tui/dist/terminal-image.js` + `components/image.js`), re-exported from the package index:
  `detectCapabilities()` / `getCapabilities()` → `"kitty" | "iterm2" | null`; `encodeKitty()`, `encodeITerm2()`, `renderImage()`, `imageFallback()`, `getImageDimensions()`, `allocateImageId()`, `deleteKittyImage()`, `deleteAllKittyImages()`, `isImageLine()`, plus a ready-made `Image` component (`new Image(base64, mime, theme, options)`).
- **pi-tui's differential renderer is already image-aware.** `tui.js` calls `isImageLine()` (`tui.js:562`, `570`, `839`) to skip appending `SEGMENT_RESET` to image lines, refuse to composite overlays over them, and exempt them from the width-overflow crash check. **But that handling only protects image lines emitted by a non-wrapping component (a `Box` child / the `Image` component) — a `Text` component mangles them first** (see Architecture → "Why a flattened `Text` cannot carry images"). So images must be rendered as `Image` child components, not embedded in the existing flattened card `Text`.
- **The image data already flows end-to-end to `ui.ts`**, base64 intact, and is dropped only at the final render step. Verified hop-by-hop:

  | Hop | File | Carries base64? |
  |---|---|---|
  | kernel emits image frame | `runner.py` `to_bundle()` → `{type:"image", mime:"image/png", data:<base64>}` | ✅ |
  | kernel host → cell result | `kernel-py.ts` → `EvalCellResult.displays[*].data` | ✅ |
  | env-server `/exec-cell` | `env-server.ts:739–774` (`spillImages` copies to disk, does **not** mutate the bundle) | ✅ |
  | brain decode | `env_client.ail:144` keeps the **entire** decoded response as `metadata` | ✅ |
  | brain → TUI event | `agent_loop_v2.ail:188` `emit_eval_result_if_present` → `cells_json = encode(metadata.cells)` | ✅ |
  | TUI parse | `runtime-process.ts:84` → `ui.ts:2519` `upsertEvalCard` → `parseEvalCellsJson` | ✅ |
  | **TUI render** | `ui.ts:1341` `renderEvalDisplayBundle` — `bundle.type === "image"` → `[image: <path> (<mime>)]` placeholder | ❌ **drops base64 here** |

**This plan closes that one gap.** It removes the inline-image Non-goal and renders eval image bundles as real terminal images, with a graceful text fallback. **No kernel, env-server, `env_client`, brain, or wire changes are required** — the change is contained to the TUI (`src/tui/src/ui.ts` + a small shared module and tests). It is *not*, however, a one-line swap of the placeholder: rendering real images requires restructuring the eval card body from a single flattened `Text` into a small component subtree (see Architecture → "Why a flattened `Text` cannot carry images").

## Goals

- When an `eval` cell emits an image display bundle (`display(pil_image)`, `plt.show()`-captured PNG, raw `bytes`), the eval card renders the **actual pixels** inline via Kitty or iTerm2, sized to the card width.
- **Graceful degradation:** terminals without image support (and all non-TTY contexts — tests, pipes, CI) fall back to `imageFallback()` / the existing `[image: <path> (<dims> <mime>)]` placeholder. Never crash, never emit raw escape bytes to a terminal that can't decode them.
- **Images are visible by default** — a card containing an image bundle defaults to expanded (today only error cards do; `ui.ts:2533`), so a successful plot shows pixels without requiring a `Ctrl+O` keystroke.
- **No image leaks or ghosting** across the card's frequent re-renders (every `eval_result` upsert and every `Ctrl+O` expand/collapse — both call `renderEvalCard`, `ui.ts:1843`, `2561`) — Kitty images are reused by stable ID (replace, not stack), and purged with `deleteAllKittyImages()` on process exit.
- **Truncation-safe:** each image is rendered by an atomic `Image` child component and is never sliced; the collapse/preview logic operates on whole segments, not into an image.

## Non-goals

- **No new transport, kernel, or brain work.** Base64 already arrives in `cells_json`; we render what's there.
- **No SVG rasterization.** `image/svg+xml` is vector; Kitty/iTerm2 want raster. SVG keeps the placeholder/fallback (rasterizing it is a separate effort).
- **No sixel protocol.** pi-tui exposes Kitty + iTerm2 only; sixel-only terminals get the fallback.
- **No still-image animation / streaming frames.** One static render per bundle.
- **Does not depend on, and is not blocked by, B′** (plan 02). Renders from plan 01/03's final aggregated `eval_result`.

---

## Relationship to plans 01–03 (Non-goal reversal)

Plans 01 (§Phase 5b, Non-goals), 02 (Non-goals), and 03 (Non-goals, Reference-layout note) each state inline images are out of scope because no terminal-image capability exists. **Plan 04 supersedes that specific Non-goal** — the capability exists in pi-tui and is unwired, not absent. The other plans' reasoning is otherwise unaffected (their layouts and data shapes are unchanged; the image bundle simply renders richly instead of as a placeholder). *Optional follow-up:* update the three Non-goal lines to cross-reference this plan so the archive stays coherent — flagged, not required for this plan to ship.

---

## Architecture

### Why a flattened `Text` cannot carry images (the load-bearing constraint)

The obvious-but-wrong approach is to keep the card's single flattened `detailRow` (`Text`, set via `detailRow.setText(lines.join("\n"))` at `ui.ts:2569`) and just emit image escape-sequence lines into it. **This does not work and can crash the TUI.** Verified against pi-tui v0.64.0 source:

1. `Text.render()` runs every line through `wrapTextWithAnsi` → `wrapSingleLine` (`components/text.js`, `utils.js`). Wrapping decides whether to break a line using `visibleWidth(line)`.
2. `visibleWidth` strips escape sequences via `extractAnsiCode` (`utils.js`). But `extractAnsiCode`'s **CSI branch only terminates on `[mGKHJ]`** — and the multi-row image line begins with the cursor-up prefix `\x1b[{rows-1}A`, whose final byte is **`A`**, which it does not recognize. Parsing runs past the `A` into the image payload, so `visibleWidth` mis-measures the line as *thousands of columns wide* instead of ~0.
3. Because `visibleWidth(line) > width`, `wrapSingleLine` calls `breakLongWord`, **shredding the escape sequence** into multiple lines. The trailing base64-only fragments no longer contain the `\x1b_G` / `\x1b]1337;` prefix, so `isImageLine()` returns false for them.
4. At the renderer (`tui.js:839`), any non-image line wider than the terminal triggers a **fatal crash** ("Rendered line exceeds terminal width", writes a crash log and calls `this.stop()`). A shredded image fragment hits exactly this path.

The codebase already knows this hazard — `ui.ts:1778` carries the comment *"raw ANSI inside Text children corrupts on re-render"* (the startup banner is printed via stdout for the same reason).

### The supported mechanism: `Image` child components in the Box tree

`Box.render()` (`components/box.js`) is the opposite of `Text`: it **never wraps**. It prepends a `leftPad` and, in `applyBg`, appends trailing pad-spaces *only when* `visibleWidth(line) < width` (`padNeeded = max(0, width - visLen)`). For a mis-measured image line (`visibleWidth ≫ width`), `padNeeded = 0`, so the line passes through **untouched**; `isImageLine()` then spares it the `tui.js:839` crash check. pi-tui's own `Image` component (`components/image.js`) is built to be a direct child of a Box for exactly this reason.

So the card body must change from *one flattened `Text`* to *an ordered component subtree*: `Text` runs for header/code/stdout/stderr/JSON/markdown, interleaved with `Image` components for image bundles, all inside a per-card body `Box`.

```
history: Box
  ├─ toolRow:  Text   (the "… eval" status row — unchanged)
  └─ bodyBox:  Box(0,0)              ← replaces the single flattened detailRow Text
       ├─ Text   header + code + stdout + stderr + json/markdown for cell 1 (pre-image)
       ├─ Image  cell-1 image bundle #1     ← real pixels; Box passes its lines through intact
       ├─ Text   any output after that image
       ├─ Image  cell-1 image bundle #2
       ├─ Text   cell 2 header + code + output …
       └─ …
```

`EvalCellResult.displays[*]` already arrives in `ui.ts` with base64 intact (see Background table); the only change is **where** the image bundle is rendered — an `Image` child instead of a `chalk.dim("[image: …]")` text line.

---

## Phase 0 — prove the mechanism, then build the image-segment helper

**Files (new):** `src/tui/src/eval/image-segment.ts`. **Tests:** `src/tui/src/eval/image-segment.test.ts`.

**Step 0a — de-risk spike (do first, ~30 min).** Before any card surgery, confirm in a throwaway script on a Kitty/iTerm2 terminal that a pi-tui `Box` containing a `Text` + an `Image` + another `Text` renders the image inline without crashing or shredding. This validates the entire premise of the plan against the real terminal, not just the source reading above. If it fails, stop and reassess (fallback: images as trailing sibling rows — Open Q #1).

**Step 0b — segment model.** The card renderer must stop returning a single `string[]` and instead return an **ordered list of segments**, each either text or image:

```ts
type EvalSegment =
  | { kind: "text"; lines: string[] }              // already-rendered (highlighted/dim) text lines
  | { kind: "image"; image: Image | null; fallback: string[] };  // Image component, or text fallback lines
```

Provide `makeImageSegment(base64, mime, opts, theme) -> EvalSegment`:
- `caps = getCapabilities()` (cached; `detectCapabilities()` runs once, lazily). If `caps.images == null` → `{kind:"image", image:null, fallback:[imageFallback(mime, dims, filename)]}` (still a text segment in effect).
- Else construct/reuse an `Image(base64, mime, theme, {maxWidthCells, imageId})`. The `Image` component already does dimension probing (`getImageDimensions`), capability check, fallback, and the `(rows-1)` blanks + cursor-up packing internally — **prefer reusing it over hand-rolling `renderImage`** (it owns the `rows`/`imageId` bookkeeping we'd otherwise duplicate).
- **Height is capped via width, not `maxHeightCells`.** ⚠ Verified: both `Image.render()` and `renderImage()` ignore `maxHeightCells` — rows are derived solely from `maxWidthCells` × aspect ratio (`calculateImageRows`, `terminal-image.js`). So to keep a tall plot from flooding scrollback, compute an **effective `maxWidthCells`**: take `dims = getImageDimensions(base64, mime)`, `rows = calculateImageRows(dims, cardWidth, getCellDimensions())`; if `rows > EVAL_IMAGE_MAX_ROWS`, shrink width to `floor(cardWidth * EVAL_IMAGE_MAX_ROWS / rows)` and pass *that* as `maxWidthCells`. This is the one bit of sizing math we own; everything else stays inside `Image`.
- SVG (`image/svg+xml`) and missing/empty base64 → fallback segment (Non-goals).
- **Non-TTY safety:** in tests/pipes `detectCapabilities()` returns `null` → fallback path; expose a test seam (`__setCapabilitiesForTest`) so both branches are unit-testable without a real terminal.

**Acceptance:** Step 0a spike renders an inline image in a real terminal. Unit tests: with injected `kitty` caps, `makeImageSegment(pngBase64,"image/png")` yields an `image` segment whose `Image.render(w)` last line satisfies `isImageLine()`; with `null` caps it yields a `fallback` segment of plain text; bad/empty base64 and SVG yield fallback, never throw.

---

## Phase 1 — restructure the eval card body into a component subtree

**Files:** `src/tui/src/ui.ts` — `EvalCardState` (`872`), `upsertEvalCard` (`2519`, the `detailRow` creation at `2549–2553`), `renderEvalCard` (`2564`), `renderEvalCardLines` (`1369`), `renderEvalDisplayBundle` (`1341`).

- **Card state:** replace the single `detailRow: Text` with `bodyBox: Box` (constructed `new Box(0, 0)` so it adds no extra margin/padding, matching the current `plainText` zero-padding). Add `images: Map<string, Image>` keyed by a stable `${cellIndex}:${bundleIndex}` so `Image` instances (and their Kitty `imageId`s) survive re-renders.
- **Refactor the line builder into a segment builder:** turn `renderEvalCardLines` (and the `renderEvalDisplayBundle` image branch) into a function returning `EvalSegment[]` — text segments accumulate the existing highlighted/dim lines exactly as today; an image bundle becomes an `image` segment via `makeImageSegment`, reusing the cached `Image` from `card.images` (create on first sight, update size on width change via `Image.invalidate()`).
- **`renderEvalCard` rebuilds the box:** `bodyBox.clear()`, then for each segment add either a `plainText(textLines.join("\n"))` child or the segment's `Image` child (or a `plainText(fallback)` when `image` is null), in order. The header line stays a `Text` segment at the top.
- **Wiring:** where `upsertEvalCard` currently does `addChild(detailRow)` (`2551`), add `bodyBox` instead. The `toolRow` status line is unchanged.
- **Default-expand image cards:** `upsertEvalCard` currently sets `expanded` only when a cell errored (`2533`/`2541`). Extend that predicate so a card with **any image bundle** also defaults to expanded — otherwise a successful plot shows only the collapsed placeholder until the user presses `Ctrl+O`, defeating the feature.

> Note: this means `renderEvalCardLines`'s current `string[]` return is replaced by the segment list. Any test importing it (plan 03's snapshot) must move to the segment API or a text-only projection of it (Phase 4).

**Acceptance:** with injected image caps, a card with one PNG bundle adds an `Image` child to `bodyBox` whose rendered last line passes `isImageLine`; text-only cards render byte-identically to today (the segment list collapses to the same lines); SVG/no-caps cards show the placeholder text segment.

---

## Phase 2 — image lifecycle (no leaks, no ghosting)

**Files:** `src/tui/src/ui.ts` (`EvalCardState`, `upsertEvalCard`, `renderEvalCard`, and the card-removal / `/clear` / session-reset paths — mirror where compose cards are torn down).

The card re-renders on **every** `eval_result` upsert and on **every** `Ctrl+O` toggle. Kitty graphics are stateful: a fresh `Image` (new `imageId`) on each render *stacks* images, and images are not freed when the card disappears.

- **Reuse, don't recreate (this is the primary anti-stacking mechanism):** keep `Image` instances in `card.images` across renders so the same Kitty `imageId` is reused — Kitty *replaces* an image drawn with the same id rather than stacking. `bodyBox.clear()` only detaches them from layout; the map retains them and re-adds the same instances. ⚠ **Reality check:** eval/compose cards are **never removed during a session** today — `history` only grows, and the sole `removeChild` (`ui.ts:2120`) is for transient *stream* rows, not cards. There is no `/clear` / session-reset / per-card teardown path to hook. So within a session, **reuse-by-id is the whole story** — there is nothing to dispose mid-session, and that is correct.
- **Cleanup on process exit only:** the one place stale Kitty images should be purged is when Motoko exits, so they don't linger in the user's terminal. There is a `process.on("SIGINT", …)` at `ui.ts:1873` (→ `onAbort`) but no general shutdown hook — add a single `deleteAllKittyImages()` emit on exit/abort (and on the pi-tui width-crash `stop()` path if reachable). `Image.getImageId()` (`components/image.d.ts:24`) is available if per-id deletion is ever needed, but `deleteAllKittyImages()` on exit is sufficient and simpler.
- **iTerm2** has no persistent image ids (it repaints inline each render); the reuse/delete logic is Kitty-specific. Branch on `caps.images`; for iTerm2 the `Image` component simply re-emits.

**Acceptance:** toggling `Ctrl+O` repeatedly on an image card does not accumulate ghosts (manual, Kitty); a unit test asserts re-rendering a card reuses the same `Image` instance / `imageId` from `card.images` (no new allocation per render); exiting Motoko emits `deleteAllKittyImages()` (unit-assert the exit/abort hook calls it).

---

## Phase 3 — truncation & collapse with image segments

**Files:** `src/tui/src/ui.ts` (`renderEvalCardLines`→segment builder, `formatEvalOutputLines` at `1306`, the `visibleCells`/collapse logic at `1369–1404`).

The existing collapse logic slices flat line arrays and counts `... N more lines`. With segments, truncation must operate on the **segment list**, treating each image as an indivisible unit (an `Image` component renders atomically — we never slice into it).

- **Collapsed cards** show only the first cell (`visibleCells = cells.slice(0,1)`, `1371`). *Decision:* in collapsed state, render image segments as a one-line `[image — Ctrl+O to expand]` **text** placeholder (no `Image` child); only the expanded state attaches real `Image` children. This keeps collapsed cards compact and sidesteps drawing large images behind a "collapsed" affordance. **This is reconciled with "images visible by default" (Phase 1) because image cards default to *expanded*** — the placeholder is only seen after a user deliberately collapses a card, or for images in a non-first cell of a manually-collapsed card.
- **Text segments** keep the current per-section preview caps (8 stdout / 4 stderr lines collapsed) and `... N more lines (Ctrl+O …)` affordance — unchanged logic, now applied within each text segment.
- A height cap (`EVAL_IMAGE_MAX_ROWS`, e.g. 24) is enforced by **clamping the effective `maxWidthCells`** (Phase 0b), since `maxHeightCells` is ignored by pi-tui. Aspect ratio is preserved automatically because rows track width.

**Acceptance:** a cell with stdout + a tall image renders, when collapsed, the `[image — Ctrl+O to expand]` one-liner and **no `Image` child / no escape bytes**; expanded, it attaches the `Image` child and renders pixels; the `... N more lines` counts still reflect the text segments.

---

## Phase 4 — tests & verification

- **TS unit (`cd src/tui && bun run test`):**
  - `image-segment.test.ts` (Phase 0): injected-caps Kitty branch yields an `Image` segment whose render passes `isImageLine`; `null`-caps and SVG/bad-base64 yield fallback text; never throws.
  - Card segment builder: a 1-image cell produces `[text, image]` segments with injected caps, and `[text]` (placeholder) without — adapt plan 03's eval-card snapshot to the segment API (or a text projection of it).
  - Lifecycle: re-render reuses the same `Image`/`imageId` from `card.images` (no per-render allocation); the exit/abort hook calls `deleteAllKittyImages()`.
  - Collapse: collapsed image card emits the `[image — Ctrl+O …]` placeholder and attaches no `Image` child.
- **Regression:** non-image bundles (json/markdown/status/text) and non-eval tool rows render unchanged; **text-only eval cards are byte-identical to today** (assert the segment list collapses to the same lines); the plan-01 flat transcript path (`transcript.ts`, no TTY) is untouched and still emits `[image: <path> …]`. Update any test that imported the old `string[]`-returning `renderEvalCardLines`.
- **Manual E2E** (image-capable terminal — Kitty, Ghostty, WezTerm, iTerm2):
  ```
  make run TASK="use eval to make a matplotlib sine plot and display() it"
  ```
  Confirm the plot renders inline; toggle `Ctrl+O` and resize; confirm no ghosting and clean teardown. In a non-capable terminal (plain `xterm`, or piped) confirm the `[image: …]` placeholder.
- **Capability log at startup (optional):** log the detected protocol once (`kitty`/`iterm2`/`none`).

---

## Sequencing & risks

1. **Phase 0a spike first** — prove `Box`+`Image` renders inline on a real terminal before touching the card. Then 0b (segment helper) → 1 (card subtree restructure) → 2 (lifecycle) → 3 (collapse) → 4 (tests + E2E). Phase 1 is the largest change (card body restructure); Phase 2 is the most error-prone (Kitty state).
2. **Risks:**
   - *Card-body restructure (the biggest)* — moving from one flattened `Text` to a `Box` of interleaved `Text`/`Image` children touches card state, `upsertEvalCard`, `renderEvalCard`, and the line-vs-segment builder, and forces plan 03's snapshot test to migrate. Contained to `ui.ts` + its tests, but not a one-liner. Mitigate by keeping text-only output byte-identical (regression assert).
   - *Kitty image lifecycle* — stacking/ghosting on re-render, lingering images after exit. Mitigate via `Image`-instance reuse (stable `imageId`, so redraws replace) + `deleteAllKittyImages()` on exit (Phase 2). Note there is no mid-session card-teardown path to worry about (cards persist for the session).
   - *Mechanism premise* — the whole plan rests on `Box`+`Image` rendering inline without the `tui.js:839` width-crash. Source reading says yes (Box doesn't wrap; `isImageLine` spares image lines); the Phase 0a spike confirms it empirically before commitment.
   - *Capability detection in odd environments* — tmux/SSH/multiplexers/non-TTY vary; `detectCapabilities()` → `null` → fallback. Treat `null` as the safe default; never emit raw image bytes when unsure.
   - *`cells_json` payload size* — a large PNG base64 rides the JSONL `eval_result` event (`agent_loop_v2.ail:197`). Works today (the data already flows), but if event-size limits ever bite, the contingency is to **read the already-spilled artifact from disk** (`.motoko/artifacts/<session>/cellN-*.<ext>`, written by `spillImages`, `transcript.ts:15`) — the file is in the TUI's workdir. Out of scope here, noted.
   - *Scrollback behavior* — Kitty images are placed at the cursor; scroll behavior is governed by pi-tui's renderer, which already manages `Image` children. By using the real `Image` component we inherit whatever support pi-tui's own components get; watch in manual E2E.
3. **Text fallback is the universal floor** — the `[image: <path> (<dims> <mime>)]` placeholder remains the output whenever caps are absent, data is missing, or the format is SVG. No environment loses information relative to today.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| 1 | Inline `Image` children in the card body vs. images as trailing sibling rows? | Inline (the plan) — matches the per-cell layout goal. Trailing sibling rows are the simpler fallback if the Phase 0a spike surfaces a Box/Image layout problem. |
| 2 | Reuse pi-tui's `Image` component, or call `renderImage()` directly? | Reuse `Image` — it owns dimension probing, capability fallback, the `(rows-1)`+cursor-up packing, and `imageId` bookkeeping; hand-rolling `renderImage` would duplicate all of it. |
| 3 | Render images when the card is collapsed? | No — collapsed shows a `[image — Ctrl+O to expand]` text placeholder; only expanded attaches real `Image` children (Phase 3). |
| 4 | Inline base64 (current flow) vs. read spilled artifact from disk? | Inline base64 — it already arrives intact end-to-end. Disk-read is the contingency if `cells_json` size ever bites. |
| 5 | Height cap for tall plots? | Clamp the effective `maxWidthCells` against `EVAL_IMAGE_MAX_ROWS` (~24) via `calculateImageRows` — `maxHeightCells` is ignored by pi-tui (verified). Aspect ratio is preserved. Tune in manual E2E. |
