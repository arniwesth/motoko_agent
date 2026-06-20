# Fix In-Session Scratchpad Image Rendering

Base branch: `origin/main`

## Summary

This branch fixes scratchpad-generated plots/images not rendering correctly in the Motoko TUI session.

The failure had two parts:

- Python scratchpad cells could create image files or call notebook-style display APIs, but the runner did not reliably emit Motoko `image` display bundles for those cases.
- The ANSI half-block fallback rendered images in-session, but height limits could distort proportions or leave usable terminal space unused.

## Changes

- Teach the Python scratchpad runner to convert data-URL image strings, including HTML `<img src="data:image/...">` output, into structured `image` bundles.
- Auto-emit open matplotlib figures at the end of a Python scratchpad cell, so `plt.show()` and open figures render in-session without requiring IPython.
- Track whether an image was already emitted for a cell to avoid duplicate auto-renders when `display(fig)` or another explicit image display was used.
- Update the scratchpad prompt guidance so agents use Motoko-compatible image display patterns instead of IPython, HTML-only output, markdown placeholders, or save-only workflows.
- Preserve visual aspect ratio in ANSI half-block image rendering by using terminal cell dimensions and shrinking width when the row budget binds, instead of squashing height.
- Size scratchpad image rows from the current terminal height, reserving surrounding UI space while allowing wide plots to use available screen space.
- Include the terminal-height-derived row cap in the cached fallback key so resized renders regenerate ANSI art at the right dimensions.
- Regenerate `ailang.lock` for the updated scratchpad prompt package hash.

## User Impact

Users can now ask scratchpad to render plots/images in the active Motoko session and see the result directly in the TUI:

- Matplotlib figures render from common patterns such as `display(fig)`, `display(plt.gcf())`, and `plt.show()`.
- Data-URL image output is interpreted as an image instead of being printed as raw HTML/text.
- Terminals without Kitty/iTerm2 graphics support still get true-color ANSI half-block art.
- ANSI image fallback respects proportions and adapts to the terminal height instead of using a fixed hardcoded height.

## Verification

- `npm run build` from `src/tui`
- `node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/scratchpad/kernel-py.test.ts|src/scratchpad/image-segment.test.ts|src/ui.tool-render.test.ts'` from `src/tui`
- `node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/scratchpad/ascii-image.test.ts|src/scratchpad/image-segment.test.ts|src/ui.tool-render.test.ts'` from `src/tui`
- Direct Python runner smoke test confirming both data-URL images and `plt.show()` emit `type:"image"` frames

Note: the Bun/Jest launcher still fails before executing tests with `Attempted to assign to readonly property`; the focused suites pass under Node's Jest ESM runner.
