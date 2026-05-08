---
doc_type: short
full_text: sources/TUI_Code_Block_Rendering.md
---

# Summary: TUI Code Block Rendering Plan

This document outlines a plan to enhance the TUI's Markdown rendering with syntax highlighting for fenced code blocks, supporting TypeScript, Python, AILANG, shell, and diff blocks, including an optional GitHub-style diff mode with background colours and inner language highlighting. It is part of the [[concepts/TUI]] code rendering pipeline.

## Key Objectives

- Wire a custom `highlightCode` function into the `MINIMAL_THEME` used by the `@mariozechner/pi-tui` Markdown renderer.
- Implement lightweight, in-file lexers for:
  - **TypeScript / JavaScript**
  - **Python** (with multi‑line triple‑quoted strings)
  - **AILANG** (exact reserved keyword set from the language reference)
  - **Shell**
  - **Diff** blocks (file headers, hunks, additions, deletions)
- Add an opt‑in GitHub‑style diff mode (`TUI_DIFF_STYLE=github`) with green/red backgrounds and language‑aware inner highlighting.
- Preserve existing rendering behaviour for non‑code Markdown, line counts, and protocol compatibility.

## Proposed Approach

1. Add the `highlightCode` callback in `src/tui/src/ui.ts` and attach it to `MINIMAL_THEME`.
2. Route languages by fence tag; unknown languages fall back to readable dim style.
3. Return ANSI‑escaped line arrays, one per source line, compatible with the theme’s contract.
4. Implement token‑based colouring (keywords, strings, numbers, comments, etc.) without external dependencies.
5. Build focused unit tests in `src/tui/src/ui.highlight.test.ts` using token‑class assertions, not brittle ANSI snapshots.

## Highlighting Strategy

### Language‑Specific Token Rules

- **TypeScript/JS**: keywords (blue), built‑ins/globals (cyan), strings (green), numbers (magenta), comments (gray).
- **Python**: similar palette, plus a stateful lexer for triple‑quoted strings to maintain continuity across lines.
- **AILANG** ([[concepts/AILANG]]): exact 41 reserved keywords (blue), ADT constructors (cyan), effects block names (cyan bright), strings (green), numbers (magenta), line comments (`--` → gray). Operator‑like syntax markers get a subtle colour. The keyword set is verified against the canonical language reference.
- **Shell**: control keywords (blue), environment variables (cyan), comments (gray), commands (yellow).
- **Diff**: 
  - File headers (`--- ` / `+++ `) and hunk headers (`@@ ... @@`)
  - Addition lines (`+`) and deletion lines (`-`)
  - Context lines default or dim
  - Precedence ensures `---` is only treated as file header, not generic deletion.

### GitHub‑Style Diff Upgrade

- Mode flag (`TUI_DIFF_STYLE=github`) enables background colours: green for additions, red for deletions.
- Inner language highlighting is applied per line (after removing the `+`/`-` prefix) by inferring the language from the diff header (`+++ b/<path>` extension).
- ANSI composition helpers ensure background colours remain stable across foreground reset sequences.

## Test Strategy

- Primary test file: `src/tui/src/ui.highlight.test.ts`.
- Token‑class checks (e.g., keyword, string, comment) rather than full ANSI output.
- Line‑count equality verified for every language.
- AILANG exact keyword‑set size test (41 keywords).
- Diff precedence tests and background+foreground composition tests for GitHub mode.
- Fixtures for multi‑line Python strings and diff blocks.

## Risks & Mitigations

- **ANSI reset bleed**: mitigates by keeping per‑line styling simple.
- **Naive lexer edge cases**: fallback to dim readable output.
- **Aggressive shell command colouring**: conservative regexes.
- **AILANG token ambiguity**: conservative constructor/effect heuristics.
- **Diff precedence ambiguity**: ordered matching and dedicated tests.

## Acceptance Criteria

- Fenced blocks for supported languages render with distinct token colours.
- Python multi‑line triple‑quoted strings handled correctly.
- AILANG highlighting uses the exact 41‑keyword set.
- Diff blocks clearly show file/hunk/add/delete differentiation.
- GitHub‑style mode adds backgrounds with readable inner highlights.
- Shell blocks have differentiated colouring; unknown languages remain legible.
- Unit tests pass for each highlighter and the keyword‑set assertion.

## Related Concepts

- [[concepts/syntax-highlighting]] – the general approach to token‑based colouring without external libraries.
- [[concepts/AILANG]] – the AILANG language reference and its reserved word set.
- [[concepts/diff-rendering]] – diff formatting and GitHub‑styled presentation in terminals.
- [[concepts/ANSI-styling]] – composing and maintaining ANSI escape sequences across background and foreground.
