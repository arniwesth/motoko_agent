# TUI Dynamic Runtime Banner Plan

## Goal
Replace the fixed-size, pre-generated Motoko ASCII header (`src/tui/src/banner.ts`) with a runtime-generated banner that scales to the current terminal window width while preserving the current visual style.

## Scope
- TUI startup banner generation only (`src/tui/src/index.ts` path).
- Keep banner rendering behavior compatible in both TTY and non-TTY modes.
- Keep existing startup/version text formatting unless explicitly changed.
- Banner size is computed at process start; live resize reflow is out of scope for this change.

## Non-Goals
- No changes to core runtime protocol (`src/core/rpc.ail`, JSONL event shapes).
- No redesign of the banner art style.
- No changes to UI layout below startup banner except those required to preserve spacing.
- No runtime banner reflow on terminal resize events in this iteration.

## Current State Summary
- `misc/gen-banner.mjs` runs `misc/imageToAscii.ts` with fixed width/threshold and writes `src/tui/src/banner.ts`.
- `src/tui/src/index.ts` imports `BANNER` and prints it once at startup.
- Banner width is static and does not adapt to terminal resize or initial terminal width.

## Proposed Approach
Implement in-process banner generation in the TUI runtime and size it from terminal dimensions.

### 1. Introduce a runtime banner module
Create `src/tui/src/banner-runtime.ts` exporting:
- `renderBanner(opts): string[]`
- `computeBannerWidth(columns?: number): number`

Behavior:
- Determine target width from `process.stdout.columns`.
- Clamp width to a safe range (e.g., min readable width, max to cap startup CPU).
- Preserve block-character + ANSI truecolor style used by current pipeline.
- Return ready-to-print lines (each ending with ANSI reset where needed).

### 2. Reuse existing conversion logic without shelling out
Port/adapt logic from `misc/imageToAscii.ts` into pure TS functions callable at runtime:
- Pixel blending against background color
- Upper/lower block composition (`▀`, `▄`)
- Dark-threshold handling

Do not invoke `npx tsx` or external commands at TUI startup.

### 3. Choose runtime source data strategy
Preferred strategy: **preprocessed pixel data asset**.
- Add a one-time generation script under `misc/` that converts `misc/gits2.png` into compact TS/JSON pixel data.
- Commit generated asset into TUI source tree (e.g., `src/tui/src/banner-pixels.ts`).
- Runtime renderer reads this asset directly to avoid adding heavy image decode dependencies to normal startup.

Fallback strategy (if preferred by maintainers): add `jimp` to TUI dependencies and decode PNG at startup with memoization.

### 4. Replace static import in startup path
Update `src/tui/src/index.ts`:
- Remove `import { BANNER } from "./banner.js"`.
- Import runtime renderer.
- Compute and print banner lines before version string using current terminal width.
- Keep non-TTY fallback deterministic (use default width when `columns` is unavailable).
- Add a short code comment/TODO noting resize reflow as a future improvement.

### 5. Deprecate or repurpose static banner generator
- Default decision: repurpose `misc/gen-banner.mjs` to generate/update the preprocessed pixel asset consumed by runtime rendering.
- Explicitly deprecate static `src/tui/src/banner.ts` generation as part of this migration.

Also remove dead references and update comments to match runtime generation.

### 6. Add tests
Add focused tests under `src/tui/src/`:
- Width computation and clamp behavior for small/medium/large terminal widths.
- Renderer output invariants (non-empty, expected number of rows for a given width, contains ANSI reset).
- Startup integration test path in `index`-adjacent logic if test harness allows.

### 7. Documentation updates
Update `README.md` and any developer notes that currently describe fixed-size banner generation.
- Document that banner is runtime-sized from terminal width.
- If a preprocessed asset step exists, document regeneration command.

## Sequencing
1. Add `banner-runtime.ts` with pure rendering + width policy.
2. Add/prep source data asset path (preferred: preprocessed pixels).
3. Wire `index.ts` to runtime renderer.
4. Remove/repurpose static banner generation artifacts.
5. Add tests.
6. Run `npm run build` and `npm test` in `src/tui`.
7. Include updated committed `src/tui/dist/*` outputs in the same PR.
8. Validate visually at multiple terminal widths.

## Validation Checklist
- Banner width changes with different terminal widths at startup.
- TTY startup still prints banner + version line correctly.
- Non-TTY mode does not crash and prints deterministic banner output.
- `src/tui` build passes.
- `src/tui` tests pass.
- Updated `src/tui/dist/*` files are generated and committed in the same PR.
- `src/tui/src/index.ts` no longer imports `./banner.js`.
- `misc/gen-banner.mjs` no longer writes `src/tui/src/banner.ts`.
- No remaining docs instruct regeneration of `src/tui/src/banner.ts`.
- Compiled `src/tui/dist/index.js` uses runtime banner rendering path (not `banner.js` import).
- No protocol or runtime regressions outside startup banner path.

## Risks and Mitigations
- Startup latency increase from runtime rendering.
  - Mitigation: clamp max width and use preprocessed source data.
- ANSI artifacts if reset handling is inconsistent.
  - Mitigation: enforce reset per line and add invariant tests.
- Divergence from current visual output.
  - Mitigation: preserve conversion constants/threshold defaults and verify output remains in a similar style to current banner (not strict pixel parity).

## Rollback Plan
If runtime generation causes regressions, restore `src/tui/src/banner.ts` static import path in `index.ts` and keep runtime renderer behind a feature flag (e.g., `MOTOKO_DYNAMIC_BANNER=1`) until stabilized.
