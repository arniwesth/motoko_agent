---
doc_type: short
full_text: sources/TUI_Dynamic_Runtime_Banner.md
---

# TUI Dynamic Runtime Banner Plan

This document outlines a plan to make the Motoko TUI startup banner dynamically sized to the terminal width, replacing the current fixed-width pre-generated ASCII art.

## Goal
Replace the static, pre-generated Motoko banner (`src/tui/src/banner.ts`) with a runtime-generated banner that scales to the current terminal width, while preserving the existing visual style and compatibility with both TTY and non-TTY modes.

## Scope & Non-Goals
- **In scope:** Startup banner generation only; width computed at process start, no live resize reflow.
- **Out of scope:** Core runtime protocol changes, redesign of art style, UI layout changes beyond spacing, runtime reflow on terminal resize.

## Proposed Approach
The plan introduces a runtime banner module (`src/tui/src/banner-runtime.ts`) that generates banner lines from terminal dimensions, using preprocessed pixel data to avoid heavy image decoding at startup.

### Key Components
1. **Runtime banner renderer** (`renderBanner`) – takes terminal column count, clamps width, produces lines with ANSI truecolor block characters (`▀`, `▄`).
2. **Preprocessed pixel data asset** – a one-time generated TS/JSON file from the source PNG, committed to the TUI source tree.
3. **Startup integration** – `index.ts` imports the runtime renderer instead of the static `BANNER` import, and uses `process.stdout.columns` to size the banner.

### Design Decisions
- **Pure TypeScript rendering:** No external commands, avoids shelling out.
- **Preprocessed asset over Jimp:** The preferred strategy commits pre‑converted pixel data to avoid adding heavy PNG decoding dependencies to normal startup (fallback: `jimp` with memoization).
- **Width clamping:** Ensures a safe minimum/maximum width to balance readability and start‑up CPU cost.
- **ANSI consistency:** Each line ends with a reset; all conversion constants/thresholds mirror the current pipeline to keep visual similarity.

## Sequencing & Validation
1. Implement `banner-runtime.ts` with width policy and rendering logic.
2. Generate and commit the pixel data asset.
3. Wire into `index.ts`, removing the static `./banner.js` import.
4. Repurpose `misc/gen-banner.mjs` to produce the new asset.
5. Add unit tests for width computation, render output invariants, and an integration check.
6. Verify build, tests, and visual behaviour across multiple terminal widths.

## Risks & Mitigations
- **Startup latency:** Mitigated by preprocessed data and width clamping.
- **ANSI artifacts:** Enforced line‑level resets and invariant tests.
- **Visual divergence:** Keep conversion constants consistent; aim for style similarity, not pixel parity.
- **Rollback:** Quick restore of static import if needed; runtime renderer can live behind a feature flag (`MOTOKO_DYNAMIC_BANNER=1`) during stabilization.

## Related Concepts
- [[concepts/runtime-banner-generation]] – the transition from build‑time art to runtime sizing.
- [[concepts/preprocessed-asset-pipeline]] – committing pre‑converted pixel data to avoid heavy startup dependencies.
- [[concepts/terminal-ui-adaptation]] – adapting TUI elements to terminal dimensions.
- [[concepts/ansi-output-testing]] – testing ANSI escape sequences for correctness.