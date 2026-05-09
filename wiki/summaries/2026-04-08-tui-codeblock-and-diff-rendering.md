---
doc_type: short
full_text: sources/2026-04-08-tui-codeblock-and-diff-rendering.md
---

# 2026-04-08 TUI Code Block and Diff Rendering

## Overview
Improved markdown code-block rendering in the TUI (`src/tui/src/ui.ts`) by integrating `highlightCodeLines` with syntax-aware highlighting and adding a default GitHub-style diff renderer with line-number gutters.

## Key Features
- **Syntax highlighting**: Fenced code blocks now route through `MarkdownTheme.highlightCode` → `highlightCodeLines`.
- **Supported languages**: TypeScript/JavaScript, Python (including multiline triple-quoted strings), AILANG (41 reserved keywords, operators, comments, effects/types/prelude hints), Shell, Diff/Patch.
- **AILANG keyword list**: Exported canonical `AILANG_RESERVED_KEYWORDS` list aligned with the lexer, including `as` (see [[concepts/ailang-keywords]]).
- **Diff rendering**: A stateful parser classifies file headers, hunk headers, and line types (add/delete/context/meta). It tracks line numbers from hunk headers (`@@ -a,b +c,d @@`) and displays fixed-width old/new gutters. GitHub-style visual treatment applies green/red tinted backgrounds and explicit `+`/`-` coloring. Inner syntax highlighting for changed lines is inferred from diff file headers (`+++ b/<path>`).

## Bug Fixes
- **Prevented hunk-line misclassification**: Valid content lines starting with `+++` or `---` inside hunks are no longer mistaken for file headers. Added `inHunk` state and strict header detection (only recognized outside hunks, with real paths like `a/`, `b/`, `/dev/null`).
- **Preserved language for deleted-file diffs**: When `+++ /dev/null` appears, inner language inference does not overwrite the previously inferred language; stays as the original file language.

## Testing
Tests in `src/tui/src/ui.highlight.test.ts` cover:
- Token-class behavior for all supported languages
- Python multiline string continuity
- AILANG keyword parity and count
- Diff precedence and patch alias
- GitHub-style background + token coloring
- Hunk line-number gutters
- Regression cases from review (`+++ value`, `--- comment` in hunk, `/dev/null` language preservation)

Build and test suite (`npm run build && npm test`) passed with 31 tests.

## Related Concepts
- [[concepts/tui-markdown-rendering]] – overall markdown rendering in TUI
- [[concepts/syntax-highlighting]] – syntax highlighting strategies
- [[concepts/github-style-diff]] – diff visualization patterns
- [[concepts/ailang]] – AILANG language definition