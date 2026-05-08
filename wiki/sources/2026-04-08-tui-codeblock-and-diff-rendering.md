# 2026-04-08 TUI Code Block and Diff Rendering

## Scope
Implemented markdown fenced-code rendering improvements in `src/tui/src/ui.ts` with syntax-aware highlighting, plus a GitHub-style diff renderer with line-number gutters.

## Key Changes
- Added `MarkdownTheme.highlightCode` integration and routed fenced code through `highlightCodeLines(...)`.
- Added language support for:
  - TypeScript/JavaScript
  - Python (with multiline triple-quoted string state)
  - AILANG (reserved keywords, operators, comments, effects/types/prelude hints)
  - Shell
  - Diff/Patch
- Added canonical exported `AILANG_RESERVED_KEYWORDS` list (lexer-aligned, 41 keywords including `as`).

## Diff Renderer (Default)
- Added stateful diff parsing with:
  - file header, hunk header, add/delete/context/meta classification
  - hunk line-number tracking from `@@ -a,b +c,d @@`
  - fixed-width old/new gutter per line
- Added GitHub-style visual treatment:
  - tinted green/red backgrounds for add/delete lines
  - explicit bright `+`/`-` prefix coloring over background
  - hunk/header styles preserved
- Added language inference from diff file headers (`+++ b/<path>`), with inner syntax highlighting for changed lines.

## Bug Fixes Applied After Review
- Prevented hunk-line misclassification for valid content lines starting with `+++`/`---` by:
  - adding `inHunk` state
  - recognizing file headers only outside hunks and only with real header paths (`a/`, `b/`, `/dev/null`)
- Preserved inferred language for deleted-file diffs when `+++ /dev/null` appears by not overwriting `innerLang` with null.

## Tests
Added/updated `src/tui/src/ui.highlight.test.ts` to cover:
- token-class behavior for all supported languages
- Python multiline string continuity
- AILANG keyword parity/count
- diff precedence and patch alias
- GitHub-style diff background + token coloring
- hunk line-number gutters
- regression cases from review comments (`+++ value`/`--- comment` in hunk, `/dev/null` language preservation)

## Validation
- `cd src/tui && npm run build` ✅
- `cd src/tui && npm test` ✅ (31 tests passing)

## Notes
- Build artifacts in `src/tui/dist/*` updated by TypeScript build.
