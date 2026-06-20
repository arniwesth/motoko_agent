# 2026-06-15 eval inline image rendering (Kitty/iTerm2 + ANSI half-block fallback)

## Context

Implemented `.agent/plans/omp-style-python-eval/04-eval-inline-image-rendering.md`:
render `eval` image display bundles as real terminal images instead of the
`[image: …]` text placeholder. Builds on plan 03 (the rich eval card). Branch
`omp-style-python-eval-plan-04`.

The plan was scoped TUI-only. During manual testing two follow-on changes were
made beyond that scope (both at the user's request): a kernel tweak so
`display(fig)` works, and an ANSI half-block art fallback for terminals without
a graphics protocol.

## Environment notes (carry forward)

- **`bun run test` (the package.json script) is broken in this container.** It
  shells to the jest binary, which dies with `TypeError: Attempted to assign to
  readonly property` (bun 1.3.14 + jest 29 `stack-utils` incompatibility) across
  *all* suites, independent of any change. **Use `bun test src` instead** — it
  runs the identical jest-API suites fine.
- One pre-existing failure throughout: `src/eval/ws-channel.test.ts` "correlates
  tool-request frames…" times out (5s WebSocket `beforeEach`). Environmental, not
  related to this work.
- This dev container reports `TERM_PROGRAM=vscode` → pi-tui `detectCapabilities()`
  returns `images: null` (truecolor). So real Kitty/iTerm2 pixels can't be
  validated here; verified via injected-caps spikes + the ANSI-art path.

## pi-tui 0.64.0 gotcha (plan fact correction)

The plan claimed pi-tui re-exports `isImageLine` from the package index. **False
in 0.64.0** — `dist/index.js` omits it (the `.d.ts` wrongly declares it). Feature
code doesn't need it; tests import it from the `dist/terminal-image.js` subpath.
Everything else needed (`Image`, `getImageDimensions`, `calculateImageRows`,
`getCellDimensions`, `allocateImageId`, `deleteAllKittyImages`, `imageFallback`,
`getCapabilities`) IS exported from root.

## Feature: inline terminal images

### New `src/tui/src/eval/image-segment.ts`

- `EvalSegment = {kind:"text"; lines} | {kind:"image"; image: Image|null; fallback: string[]}`.
- `makeImageSegment(base64, mime, opts)` — builds a reusable pi-tui `Image` on
  graphics terminals; never throws. SVG / empty / undecodable → fallback.
- `effectiveImageWidthCells()` — height cap via **width** clamp against
  `EVAL_IMAGE_MAX_ROWS` (24). ⚠ pi-tui ignores `maxHeightCells` (verified) — rows
  derive from width × aspect only.
- `__setCapabilitiesForTest()` test seam. **Caveat:** the seam drives *our*
  branch; pi-tui's `Image.render` calls pi-tui's own `getCapabilities` (reads
  env), so a test asserting real graphics bytes must set `KITTY_WINDOW_ID` +
  `resetCapabilitiesCache()`.
- `evalImageExitSequence()` — Kitty purge (`deleteAllKittyImages`) on exit, null
  for iTerm2/none.
- `evalImageCapabilityLabel()` — `kitty` / `iterm2` / `ANSI half-block art`
  (truecolor, no protocol) / `none (text fallback)`.

### `src/tui/src/ui.ts`

- **Card body restructured** from a single flattened `detailRow: Text` to a
  `bodyBox: Box(0,0)` holding interleaved `Text`/`Image` children. Load-bearing
  reason: `Text.render` word-wraps via `visibleWidth`, whose `extractAnsiCode`
  only terminates CSI on `[mGKHJ]` — the cursor-up image prefix `\x1b[{N}A` ends
  in `A`, so a `Text` mis-measures and **shreds** the image escape sequence. A
  `Box` never wraps, so image lines pass through intact and pi-tui's renderer
  exempts them (`isImageLine` at `tui.js:839`).
- `renderEvalCardLines` now returns `EvalSegment[]` (was `string[]`); added
  `evalSegmentsToText()` projection. `EvalCardImageEntry` caches the `Image`
  **and** the computed fallback/ANSI lines by `${cellIndex}:d${i}` / `:r`.
- **Image reuse by stable `imageId`** across re-renders so Kitty *replaces*
  rather than stacks. `deleteAllKittyImages()` on `process.on("exit")`
  (`purgeTerminalImages`). No mid-session card teardown exists (cards persist).
- Image cards **default to expanded** (`shouldExpandEvalCard` / `evalCellsHaveImage`);
  collapsed image bundles show `[image — Ctrl+O to expand]`, no Image child.
- One-line **startup capability log**: `eval images: <label>`.

### Critical wiring bug found & fixed

`eval` is dispatched as a normal tool, so `applyNativeToolResults` creates
`toolRows[key]` **and** `toolDetailRows[key]` (a plain `Text`) under
`requestId:toolCallId` **before** `eval_result` fires. The old card piggybacked
on that `Text`. The first cut of this work only created `bodyBox` inside
`if (!toolRows.has(key))` → it was skipped → `card.bodyBox` undefined →
`renderEvalCard` bailed → **no card rendered at all** (only the `[done] … eval`
row). Fix: `upsertEvalCard` now creates `bodyBox` unconditionally and, when a
stale generic `detailRow` exists, removes it from history (a `Text` can't carry
`Image` children) before adding the `Box`. `refreshToolDetailRow` checks
`evalCards` before the `toolDetailRows` guard. Note: this path needs a live
TTY/TUI so it's covered by reasoning + manual run, not a unit test.

## Out-of-plan change 1: kernel `display(fig)` support (`src/tui/src/eval/runner.py`)

`to_bundle()` only emitted image bundles for `bytes` or an image-mime dict — so
`display(fig)` / `display(pil_image)` silently degraded to a text repr (observed
in testing: model fell back to printing `data:image/png;base64,…` to stdout).
Added `_rich_image_bytes(value)` (before the text fallthrough): tries
`_repr_png_`/`_repr_jpeg_`, then `savefig` (covers a `Figure`, the `pyplot`
module, and `Axes` via `.figure`), then a PIL `save`. All best-effort. Bundle
shape unchanged. Verified against the real runner subprocess: `display(fig)`,
`display(plt)`, PIL image, and a bare `fig` result → `image/png`;
`display('text')` → text.

## Out-of-plan change 2: ANSI half-block fallback (`src/tui/src/eval/ascii-image.ts`)

For terminals with truecolor but no Kitty/iTerm2 protocol (VS Code, plain
xterm-256color), render PNGs as colour half-block (`▀`) art instead of
`[Image: …]`. Inspired by `.agent/research/omp-style-python-eval/imageToAscii.ts`.
Dependency-free (uses `node:zlib`):

- `decodePng(buf)` — minimal decoder: 8-bit, non-interlaced, colour types
  0/2/3/4/6, all 5 scanline filters. Returns null outside that subset.
- `renderImageAsAnsi(base64, mime, maxWidthCells, maxRows)` — box-resample, half
  blocks (fg=top px, bg=bottom px), height hard-capped `min(aspectRows, maxRows)`,
  transparency composited over black. PNG only; null otherwise.

Wired into `makeImageSegment`'s non-graphics branch (gated on `caps.trueColor`),
result cached per `(idKey, width)` in `ui.ts` to avoid re-decoding on each
render/Ctrl+O.

### Render tiers now

| terminal | result |
|---|---|
| Kitty / Ghostty / WezTerm | Kitty graphics pixels |
| iTerm2 | iTerm2 graphics pixels |
| VS Code / xterm-256color (truecolor, no protocol) | colour half-block `▀` art |
| no truecolor / non-PNG / undecodable | `[Image: …]` text placeholder |

## Tests

- New `image-segment.test.ts`, `ascii-image.test.ts`; updated `ui.tool-render.test.ts`
  (migrated plan-03 snapshot to the segment API; added image/ascii/collapse/reuse
  + byte-identical text-only regression).
- Gotcha: the old 1×1 PNG fixture is **malformed** (IDAT length field says 11 but
  the zlib stream is 13 bytes — lenient header probes don't care, the full decoder
  does). Replaced with a well-formed 4×4 PNG for decode/art tests.
- `bun test src` → 146 pass, 1 pre-existing WS timeout. `tsc --noEmit` clean.
  `make check_core` → 24/0.

## Files

- New: `src/tui/src/eval/image-segment.ts` (+ `.test.ts`),
  `src/tui/src/eval/ascii-image.ts` (+ `.test.ts`).
- Modified: `src/tui/src/ui.ts`, `src/tui/src/ui.tool-render.test.ts`,
  `src/tui/src/eval/runner.py`.

## Follow-ups / open

- Manual E2E on a real Kitty/Ghostty/WezTerm/iTerm2 terminal still outstanding
  (ghosting on Ctrl+O/resize, clean teardown) — couldn't run from the vscode
  container.
- `runner.py` change is outside the plan's "no kernel changes" boundary (user
  approved). Optional plan-04 follow-up: cross-reference the reversed inline-image
  Non-goal in plans 01–03.
