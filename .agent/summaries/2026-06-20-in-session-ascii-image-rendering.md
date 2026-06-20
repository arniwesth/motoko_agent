# 2026-06-20 In-Session ASCII Image Rendering

## Context

Investigated `.motoko/logfile/session_2026-06-20T15-58-34-701Z.md`, where the model repeatedly failed to render a Julia set image in-session. The session showed the agent generating PNG files and then trying notebook/browser-oriented display paths:

- `IPython.display.Image`, which failed because IPython was not installed.
- `plt.show()`, which produced no Motoko scratchpad display frame.
- HTML `<img src="data:image/png;base64,...">`, which was printed as literal text in the scratchpad output.
- Markdown placeholder image links, which did not correspond to actual Motoko inline rendering.

The TUI already had inline image support and an ANSI half-block fallback, but the Python runner was not consistently producing structured `image` bundles for common plotting patterns.

## Changes Made

### Python Scratchpad Runner

Updated `src/tui/src/scratchpad/runner.py` to:

- Convert data-URL image strings, including HTML `<img src="data:image/...">`, into structured `image` display bundles.
- Auto-emit open matplotlib figures at the end of a cell so `plt.show()` and open figure workflows render in-session.
- Track whether an image has already been emitted in the current cell to avoid duplicate auto-renders after explicit `display(fig)`/image display.
- Centralize image bundle construction.

Added `src/tui/src/scratchpad/kernel-py.test.ts` covering:

- Data-URL HTML image strings becoming image display bundles.
- Open matplotlib figures from `plt.show()` becoming image display bundles when matplotlib is available.

### Scratchpad Prompt Guidance

Updated `packages/motoko_scratchpad/prompts.ail` to tell agents that Motoko-compatible Python image rendering should use:

- `display(fig)`
- `display(plt.gcf())`
- `display(pil_image)`
- open matplotlib figures / `plt.show()`

The prompt now explicitly discourages IPython.display, HTML-only output, markdown placeholders, and save-only workflows for in-session rendering.

### ANSI Image Proportions And Sizing

Updated `src/tui/src/scratchpad/ascii-image.ts` and `src/tui/src/scratchpad/image-segment.ts` so ANSI half-block rendering:

- Uses terminal cell dimensions from `pi-tui`.
- Preserves visual aspect ratio.
- Shrinks width when the row budget binds instead of squashing height.
- Keeps the half-block two-pixel sampling model while computing visual rows from real terminal cell aspect.

Updated `src/tui/src/ui.ts` so scratchpad image row budget is based on terminal height:

- `scratchpadImageMaxRowsForTerminal(rows)` returns `rows - 8` with a floor of 1.
- The dynamic row cap is passed into scratchpad card image rendering.
- Fallback art cache keys include the row cap, so resized renders regenerate at the correct dimensions.

Added/updated tests in:

- `src/tui/src/scratchpad/ascii-image.test.ts`
- `src/tui/src/scratchpad/image-segment.test.ts`
- `src/tui/src/ui.tool-render.test.ts`

### PR Description

Created `.agent/prs/mot-8-fix-in-session-ascii-graph-rendering.md` with:

- Base branch: `origin/main`
- Summary, changes, user impact, and verification commands for the branch.

## Verification

Ran focused test suites under Node's Jest ESM runner:

```sh
node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/scratchpad/kernel-py.test.ts|src/scratchpad/image-segment.test.ts|src/ui.tool-render.test.ts'
node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/scratchpad/ascii-image.test.ts|src/scratchpad/image-segment.test.ts|src/ui.tool-render.test.ts'
```

Ran TypeScript build:

```sh
npm run build
```

Also ran a direct Python runner smoke test confirming both data-URL output and `plt.show()` emit `type:"image"` frames.

Note: the Bun/Jest launcher still fails before executing tests with `Attempted to assign to readonly property`; the same focused suites pass under Node's Jest ESM runner.

## Observations

- The first terminal-height implementation used a `45%` viewport fraction, which preserved proportions but made wide images too narrow. It was changed to use all available rows after reserving 8 rows for surrounding UI.
- The aspect-ratio bug was separate from terminal-height sizing: the old ANSI renderer capped rows by reducing sampled height, visually squashing images. The final fix reduces width when the row budget binds.
- The workspace still contains unrelated untracked directories/files such as `ailang/`, `oh-my-pi/`, and screenshots/artifacts used during manual inspection. These were not part of the code changes.
