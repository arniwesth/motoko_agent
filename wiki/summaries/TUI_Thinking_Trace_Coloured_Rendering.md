---
doc_type: short
full_text: sources/TUI_Thinking_Trace_Coloured_Rendering.md
---

# Colored Real-Time Thinking Trace Rendering Plan

This document outlines a plan to improve the visual rendering of LLM thinking traces in the TUI. Currently, streaming thinking text appears as raw, unstyled plain text, and expanded think blocks show uniformly dim content. The goal is to make thinking traces clearly distinguishable from answer content and more readable through [[concepts/syntax-highlighting|syntax-highlighted]] code blocks and dimmed plain text.

## Key Changes

1. **Streaming Plain Text Coloring** – Apply `chalk.dim` to plain text segments in the live thinking stream, while stripping structural tags like `<thinking>` and `</thinking>` for cleaner output.
2. **Syntax-Highlighted Think Block Expansion** – Route expanded think block content through a new `renderThinkContent()` method that uses the same highlighting pipeline as streaming: segmenting with [[concepts/stream-markdown|segmentStreamMarkdown]], detecting code fences, and applying [[concepts/code-highlighting|code highlighting]] or `chalk.dim` to plain text.
3. **Colored Think Block Headers** – Render the `[think]` label in `chalk.magenta` while keeping metadata (step, character count, ^t hint) in `chalk.dim`. Both header and body rows must use `chalk.reset` as their background function (`bgFn`) to avoid muting embedded colors.
4. **Tag Stripping Helper** – Introduce `stripThinkTags()` to remove `<thinking>`, `</thinking>`, ` thinking`, and ` response` tags from text, used in both streaming and expanded views.

## Color Scheme Overview

| Element                | bgFn         | Embedded style        |
|------------------------|--------------|-----------------------|
| Streaming plain text   | `chalk.reset` | `chalk.dim`           |
| Streaming code blocks  | `chalk.reset` | existing highlighting |
| `[think]` label        | `chalk.reset` | `chalk.magenta`       |
| Think header metadata  | `chalk.reset` | `chalk.dim`           |
| Expanded plain text    | `chalk.reset` | `chalk.dim`           |
| Expanded code blocks   | `chalk.reset` | syntax highlighted    |

## Important Implementation Details

- Two independent code paths create think blocks (inline in the `thinking` event handler and via `addThinkBlock()`); both must be updated with the new `bgFn` and styling.
- The rendering leverages existing utilities: `segmentStreamMarkdown`, `highlightCodeLines`, and `highlightJsonLines`.
- Verification involves building the TUI, running tests, and manually confirming colored streaming text, magenta `[think]` labels, syntax-highlighted code in expansions, and tag stripping.

This plan improves the [[concepts/tui-rendering|TUI rendering]] for [[concepts/thinking-traces|thinking traces]], making them more readable and visually distinctive while preserving the final answer's full markdown rendering.