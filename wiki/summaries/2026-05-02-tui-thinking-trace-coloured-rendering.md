---
doc_type: short
full_text: sources/2026-05-02-tui-thinking-trace-coloured-rendering.md
---

# TUI Thinking Trace Colored Rendering

This summary captures the implementation of visually distinct, syntax-highlighted thinking trace rendering in the Motoko TUI.

## Goal
Enhance the TUI to strip `` pair, handling mention of opening tags like `before<thinking>` and truncated fragments (`ng>`).
- **New rendering functions** – `renderThinkContent()` and `renderThinkingSegments()` use the same [[concepts/stream-markdown|stream markdown pipeline]] for expanded think blocks, ensuring consistent highlighting.
- **Visual distinction** – Dimmed plain text via `chalk.dim` inside think blocks, magenta `[think]` label, dimmed timestamp/metadata. Applied `chalk.reset` to header/body rows to avoid muting embedded ANSI codes.
- **Collapse handling** – Switched think block header/body from `chalk.dim` to `chalk.reset`, preserving syntax highlighting of code/JSON blocks (see [[concepts/syntax-highlighting]]).

## Issue Fixes
1. **Live stream residue** – After stream end, the empty stream row persisted. Fix: remove stream row from history and force redraw.
2. **Duplicate `[think]` block** – The pre‑split `thinking` event handler created a block outside the deduplication path. Fix: route through `addThinkBlock()` only for non‑streamed steps.
3. **Stored content** – Finalization now stores the extracted thinking body when tags exist, not the raw stream plus answer.

## Verification
- Build succeeded (`bun run build`).
- Executed subset of Jest tests (8 suites, 49 tests) covering stream-markdown, tool-plan-parser, models, config, commands, banner-runtime, env-server, compose_claimcheck.
- Known harness issue (`bun run test` fails with a readonly property error unrelated to the changes).

## Related Concepts
- [[concepts/thinking-trace-rendering]] – Colored display of AI thinking in TUIs.
- [[concepts/stream-markdown]] – Real‑time markdown segmentation and highlighting.
- [[concepts/chalk-styling]] – Terminal text styling with chalk.
- [[concepts/tag-stripping]] – Extracting content from XML‑like tags in streaming.
- [[concepts/pi-tui-behavior]] – Rendering engine quirks (row clearing, forced redraw).
- [[concepts/tool-plan-parser]] – Parsing of planned tool output influencing stream handling.
