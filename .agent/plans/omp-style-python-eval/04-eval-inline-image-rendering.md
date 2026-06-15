# Plan: `eval` inline terminal image rendering (Kitty / iTerm2)

Feature context: **[ADR-001](../../research/omp-style-python-eval/ADR-001-eval-mvp-local-loopback.md)** (the `eval` tool) and **[plan 03](./03-eval-tui-card-rendering.md)** (the rich eval card).
**Depends on plan 01 (Design C) and plan 03 (eval card) being shipped** — both are, on this branch (commit "Implemented plan 03").
Independent of [plan 02 (B′)](./02-design-b-prime-reentrant-websocket.md).
Toolchain: AILANG v0.19.1, Bun 1.3.x, `@mariozechner/pi-tui` ^0.64.0.

## Background

Plans 01–03 all carried **"no inline images"** as an explicit Non-goal, justified by the claim that *"a terminal-image capability doesn't exist anywhere in the TUI today."* **That premise is false.** Investigation (session `2026-06-15T13-11-25-999Z`, verified against `node_modules`) shows:

- **pi-tui v0.64.0 ships a complete terminal-image stack** (`@mariozechner/pi-tui/dist/terminal-image.js` + `components/image.js`), re-exported from the package index:
  `detectCapabilities()` / `getCapabilities()` → `"kitty" | "iterm2" | null`; `encodeKitty()`, `encodeITerm2()`, `renderImage()`, `imageFallback()`, `getImageDimensions()`, `allocateImageId()`, `deleteKittyImage()`, `deleteAllKittyImages()`, `isImageLine()`, plus a ready-made `Image` component (`new Image(base64, mime, theme, options)`).
- **pi-tui's differential renderer is already image-aware.** `tui.js` calls `isImageLine()` (`tui.js:562`, `570`) to skip appending `SEGMENT_RESET` to image lines and to refuse to composite overlays on top of them. So a `Text` whose lines contain raw Kitty/iTerm2 escape sequences renders images correctly through the existing pipeline.
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

**This plan closes that one gap.** It removes the inline-image Non-goal and renders eval image bundles as real terminal images, with a graceful text fallback. **No kernel, env-server, `env_client`, brain, or wire changes are required** — the change is localized to `src/tui/src/ui.ts` (the renderer) plus a small shared image-render helper and tests.

## Goals

- When an `eval` cell emits an image display bundle (`display(pil_image)`, `plt.show()`-captured PNG, raw `bytes`), the eval card renders the **actual pixels** inline via Kitty or iTerm2, sized to the card width.
- **Graceful degradation:** terminals without image support (and all non-TTY contexts — tests, pipes, CI) fall back to `imageFallback()` / the existing `[image: <path> (<dims> <mime>)]` placeholder. Never crash, never emit raw escape bytes to a terminal that can't decode them.
- **No image leaks or ghosting** across the card's frequent re-renders (every `eval_result` upsert and every `Ctrl+O` expand/collapse) — Kitty images are reused by stable ID and deleted on teardown.
- **Truncation-safe:** an image block is atomic — the collapse/preview line-slicing in `renderEvalCardLines` never splits the reserved rows from the cursor-up sequence line.

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

```
EvalCellResult.displays[*]  ({type:"image", mime, data:<base64>})   ← already arrives in ui.ts, intact
        │
        ▼
ui.ts renderEvalDisplayBundle(bundle)                                ← the ONLY code that changes
        │   bundle.type === "image" && typeof bundle.data === "string"
        ├─ detectCapabilities().images != null
        │      → getImageDimensions(base64, mime)
        │      → renderImage(base64, dims, {maxWidthCells, maxHeightCells, imageId})
        │      → emit (rows-1) blank lines + final line `\x1b[{rows-1}A` + sequence   (mirrors pi-tui Image)
        │      → register imageId for lifecycle cleanup
        └─ else → imageFallback(mime, dims, path)  /  existing `[image: …]` placeholder
        │
        ▼
renderEvalCardLines → detailRow.setText(lines.join("\n"))            ← unchanged; isImageLine() in the
                                                                        pi-tui renderer handles the image lines
```

**Key mechanism (verified in `components/image.js:27–67`).** To make an image occupy *N* terminal rows inside a line-based `string[]` model, pi-tui pushes `(rows-1)` empty strings then a final line of `"\x1b[{rows-1}A" + sequence` (move cursor up to the first reserved row, then paint). `isImageLine()` (`terminal-image.js:46`) recognizes that final line by its `\x1b_G` (Kitty) / `\x1b]1337;File=` (iTerm2) prefix, and the differential renderer (`tui.js:562`, `570`) treats it atomically. The eval card already deals in `string[]` joined by `\n` (`ui.ts:1369`, `2568`), so **we replicate this exact line pattern** rather than restructuring the card into child components — the minimal, lowest-risk change.

---

## Phase 0 — image-render helper (shared, testable)

**Files (new):** `src/tui/src/eval/image-render.ts`. **Tests:** `src/tui/src/eval/image-render.test.ts`.

Isolate the pi-tui calls behind one pure-ish function so the renderer stays thin and the logic is unit-testable without a TTY:

```ts
// renderImageBundleLines(base64, mime, opts) -> string[]
//   - caps = detectCapabilities() (cached via getCapabilities)
//   - if caps.images == null  -> [imageFallback(mime, dims, filename)]  (text)
//   - dims = getImageDimensions(base64, mime); if null -> fallback
//   - { sequence, rows, imageId } = renderImage(base64, dims, {maxWidthCells, maxHeightCells, imageId})
//   - return [...Array(rows-1).fill(""), `\x1b[${rows-1}A` + sequence]   (rows>1)
//                                or just [sequence]                       (rows==1)
//   - track/return imageId for the caller's lifecycle map
```

- Import from `@mariozechner/pi-tui` (index re-exports all of these — `index.d.ts` confirms `Image`, `detectCapabilities`, `renderImage`, `imageFallback`, `getImageDimensions`, `allocateImageId`, `deleteKittyImage`, `deleteAllKittyImages`, `isImageLine`).
- **Capability detection must not run in non-TTY contexts** (tests/pipes return `null`). Wrap so a thrown/`null` capability yields the text fallback path. Add a test-only override hook (inject a fake `caps`) so unit tests can exercise both the Kitty branch (assert the output line passes `isImageLine`) and the fallback branch.
- **Reuse vs. replicate the `Image` component:** the component's `render(width)` returns exactly the `string[]` shape we need and also caches by width and manages its own `imageId`. *Recommendation:* **wrap the `Image` component** if its caching/imageId lifecycle composes cleanly with the card's per-bundle ID map (Phase 2); otherwise call `renderImage()` directly and own the ID. Decide in Phase 0; either way the helper's signature is stable.

**Acceptance:** unit tests — with an injected `kitty` capability, `renderImageBundleLines(pngBase64, "image/png")` returns lines whose last line satisfies `isImageLine()` and whose blank-line count equals `rows-1`; with `null` capability it returns a single non-image fallback line; an unparseable/empty base64 returns the fallback, never throws.

---

## Phase 1 — wire the helper into `renderEvalDisplayBundle`

**Files:** `src/tui/src/ui.ts` (the `bundle.type === "image"` branch, `ui.ts:1348–1356`).

Replace the placeholder-only branch:

```ts
if (bundle.type === "image") {
  const base64 = typeof bundle.data === "string" ? bundle.data : stringValue(recordValue(bundle.data)?.data, "");
  const mime   = bundle.mime ?? stringValue(recordValue(bundle.data)?.mime, "image/png");
  if (base64 && mime !== "image/svg+xml") {
    const lines = renderImageBundleLines(base64, mime, { maxWidthCells: maxWidth, maxHeightCells: EVAL_IMAGE_MAX_ROWS, imageId: idFor(bundle) });
    if (lines) return lines;            // includes the in-terminal fallback line if caps are null
  }
  // existing placeholder (no base64, SVG, or render failure)
  …return [chalk.dim(`[image: ${path}${dims}]`)];
}
```

- `EVAL_IMAGE_MAX_ROWS` caps image height (e.g. 24 rows) so a tall plot doesn't flood scrollback; `renderImage` preserves aspect ratio against `maxWidthCells`.
- **Sizing source:** `maxWidth` already threads in from `toolPreviewWidth()` via `renderEvalCardLines` (`ui.ts:1385/1388`, `2568`). Subtract the 2-space card indent already applied at the call sites.
- The image branch keeps emitting the existing placeholder as its fallback return, so behavior is identical on non-image terminals and in the transcript path.

**Acceptance:** with an injected image capability, an `eval` card containing one PNG bundle renders the image-sequence line (passes `isImageLine`) sized to the card width; with no capability it renders the existing `[image: …]` placeholder; SVG bundles still render the placeholder.

---

## Phase 2 — image lifecycle (no leaks, no ghosting)

**Files:** `src/tui/src/ui.ts` (`EvalCardState` at `ui.ts:872`, `upsertEvalCard` at `2519`, `renderEvalCard` at `2564`, plus card-teardown/clear paths).

The card re-renders on **every** `eval_result` upsert and on **every** `Ctrl+O` toggle (`renderEvalCard` → `setText`). Kitty graphics are stateful: re-emitting a new image each render *stacks* images unless the same `imageId` is reused (which replaces), and images must be explicitly deleted when their card goes away.

- Add a stable per-bundle ID map to `EvalCardState`: `imageIds: Map<string /*cell:bundle key*/, number>`, allocated once via `allocateImageId()` and passed into `renderImageBundleLines` so re-renders **replace** rather than stack.
- On card removal / history clear / session reset / `/abort`, emit `deleteKittyImage(id)` for each tracked id (or `deleteAllKittyImages()` on a full screen clear). Find the existing clear/reset path the compose cards use and hook the same lifecycle point.
- **iTerm2** has no persistent image IDs (it re-paints inline each render) — the reuse logic is a Kitty concern; for iTerm2 the helper simply re-emits. Branch on `caps.images`.

**Acceptance:** toggling `Ctrl+O` repeatedly on an image card does not accumulate stacked/ghost images (manual check on a Kitty terminal); after the card is cleared, `deleteKittyImage` is emitted for each allocated id (unit-assert the teardown calls the delete with the tracked ids).

---

## Phase 3 — truncation & collapse safety

**Files:** `src/tui/src/ui.ts` (`renderEvalCardLines` at `1369`, `formatEvalOutputLines` at `1306`).

The collapse/preview logic slices line arrays by count (`formatEvalOutputLines`, the `visibleCells`/`... N more` logic). An image block is `(rows-1)` blanks + one sequence line whose `\x1b[{rows-1}A` count **must** match the preceding blanks, or the cursor lands on the wrong row and corrupts the display.

- Treat each image's `string[]` as an **atomic unit**: never let preview-truncation cut between the reserved blanks and the sequence line. Either render images only as whole blocks within the line budget, or drop the whole image (showing a `[image hidden — Ctrl+O to expand]` one-liner) when it doesn't fit the collapsed budget.
- **Collapsed cards** currently show only the first cell's preview (`visibleCells = cells.slice(0,1)`, `ui.ts:1371`). *Decision:* render images only when **expanded** (or when the card is the sole/selected one); collapsed shows the atomic one-line image placeholder. Keeps collapsed cards compact and avoids painting large images behind a "collapsed" affordance.
- Account image rows against the card's line budget so a multi-image cell doesn't blow past the preview window unexpectedly.

**Acceptance:** a cell with stdout + a tall image, collapsed, shows the `[image hidden …]` one-liner and no partial escape sequence; expanded, shows the full image with its `rows-1` blanks intact; the `... N more lines` math still reflects real rows.

---

## Phase 4 — tests & verification

- **TS unit (`cd src/tui && bun run test`):**
  - `image-render.test.ts` (Phase 0): Kitty branch line shape + `isImageLine`, null-caps fallback, bad-base64 safety.
  - `ui.eval-card` image snapshot: with injected caps, a 1-image card emits an image line; without caps, the placeholder — extend the existing eval-card test (`ui.tool-render.test.ts` / the eval-card snapshot from plan 03).
  - Lifecycle: re-render reuses the same `imageId`; teardown deletes tracked ids.
  - Truncation atomicity: collapsed image card never splits a sequence from its reserved rows.
- **Regression:** existing `ui.tool-render` and eval-card tests stay green; non-image bundles (json/markdown/status/text) and non-eval tool rows are unchanged; the plan-01 flat transcript path (`transcript.ts`, no TTY) is untouched and still emits `[image: <path> …]`.
- **Manual E2E** (needs an image-capable terminal — Kitty, Ghostty, WezTerm, or iTerm2):
  ```
  make run TASK="use eval to make a matplotlib sine plot and display() it"
  ```
  Confirm the plot renders inline in the eval card; resize and toggle `Ctrl+O`; confirm no ghosting and a clean teardown. In a non-capable terminal (e.g. plain `xterm`, or piped output) confirm the `[image: …]` placeholder.
- **Capability assertion at startup (optional):** log the detected protocol once (`kitty`/`iterm2`/`none`) so users understand why images may or may not render.

---

## Sequencing & risks

1. Phase 0 (helper + tests) → 1 (wire into renderer) → 2 (lifecycle) → 3 (truncation safety) → 4 (tests + manual E2E). Phase 0 is pure and de-risks the pi-tui API surface before touching `ui.ts`.
2. **Risks:**
   - *Kitty image lifecycle (the main one)* — stacking/ghosting on re-render and orphaned images on teardown. Mitigated by stable per-bundle `imageId` reuse + explicit `deleteKittyImage` on teardown (Phase 2). This is the one genuinely stateful part; budget for it.
   - *Truncation splitting an image block* — corrupts the cursor-up math. Mitigated by atomic-block handling (Phase 3); cover with a unit test.
   - *Capability detection in odd environments* — tmux passthrough, SSH, multiplexers, and non-TTY all vary. `detectCapabilities()` returns `null` → fallback; never emit raw image bytes when unsure. Treat `null` as the safe default everywhere.
   - *`cells_json` payload size* — a large PNG base64 rides the JSONL `eval_result` event (`agent_loop_v2.ail:197`). Works today (the data already flows), but if event-size limits ever bite, the fallback is to **read the already-spilled artifact from disk** (`.motoko/artifacts/<session>/cellN-*.png`, written by `spillImages`, `transcript.ts:15`) instead of shipping base64 — the file is in the TUI's workdir. Noted as a contingency, not part of this plan's scope.
   - *Scrollback behavior* — Kitty images are placed at the cursor; how they behave as history scrolls is governed by pi-tui's renderer, which already manages image lines (`tui.js`). By replicating the `Image` component's exact pattern we inherit whatever scroll handling pi-tui's own components get; flagged as the area to watch in manual E2E.
3. **Keep the text fallback as the universal floor** — the existing `[image: <path> (<dims> <mime>)]` placeholder remains the return value whenever caps are absent, data is missing, or the format is SVG. No environment loses information relative to today.

## Open questions

| # | Question | Recommendation |
|---|---|---|
| 1 | Wrap pi-tui's `Image` component, or call `renderImage()` directly? | Decide in Phase 0; wrap if its imageId/caching composes with the card's ID map, else own the id. Helper signature is stable either way. |
| 2 | Render images when the card is collapsed? | No — show an atomic `[image hidden — Ctrl+O to expand]` one-liner when collapsed; full image when expanded (Phase 3). |
| 3 | Inline base64 (current flow) vs. read spilled artifact from disk? | Inline base64 — it already arrives intact end-to-end. Disk-read is the contingency if `cells_json` size ever becomes a problem. |
| 4 | Height cap for tall plots? | `EVAL_IMAGE_MAX_ROWS` (~24); `renderImage` preserves aspect ratio against card width. Tune in manual E2E. |
