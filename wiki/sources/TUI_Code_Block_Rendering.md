# TUI Code Block Rendering Plan

## Goal
Render fenced markdown code blocks in the TUI with language-aware keyword colors (TypeScript, Python, AILANG, plus sensible fallback for shell/plain text), so assistant responses display code clearly instead of dim monochrome blocks.

## Context
- Current rendering path in `src/tui/src/ui.ts` uses `new Markdown(..., MINIMAL_THEME)`.
- `MINIMAL_THEME` currently sets `codeBlock` + `codeBlockBorder` styles only (no syntax tokenization).
- The `@mariozechner/pi-tui` `MarkdownTheme` supports `highlightCode?: (code, lang) => string[]`, which is the integration hook to use.
- AILANG keyword highlighting must match the language reference exactly: `https://ailang.sunholo.com/docs/reference/language-syntax`.

## Non-Goals
- No change to runtime protocol or event shapes.
- No refactor of non-code markdown rendering.
- No broad dependency expansion unless clearly necessary.

## Proposed Approach
1. Confirm where markdown is appended in history.
2. Add a `highlightCode` function in `ui.ts` and wire it into `MINIMAL_THEME`.
3. Implement language routing by fence tag:
   - `typescript`, `ts`, `tsx`, `javascript`, `js`, `jsx`: TypeScript/JS token highlighting.
   - `python`, `py`: Python token highlighting.
   - `ailang`, `ail`: AILANG token highlighting.
   - `bash`, `sh`, `zsh`, `shell`: shell-oriented highlighting.
   - Unknown/no language: readable fallback (`chalk.dim` per line).
4. Keep behavior compatible with existing markdown renderer expectations:
   - Return `string[]` with one rendered ANSI line per source line.
   - Preserve line count and ordering from code blocks.
5. Add focused unit tests for highlighter behavior using token-class assertions (not brittle full ANSI snapshots).
6. Preserve all existing timestamp/history behavior.

## Extra Phase: Diff Rendering
1. Add explicit `diff` / `patch` routing in `highlightCodeLines`.
2. Implement line-prefix diff styling with deterministic precedence:
   - file headers: `--- ` and `+++ `
   - hunk headers: `@@ ... @@`
   - additions: `+...`
   - deletions: `-...`
   - context/other lines: default or dim
3. Preserve exact line count and text fidelity (ANSI-only transformation).
4. Add dedicated diff tests in `src/tui/src/ui.highlight.test.ts` for:
   - file header lines
   - hunk header lines
   - add/delete/context lines
   - ambiguity guard (`---` as file header, not generic deletion)

## Upgrade: GitHub-Style Diff Rendering
1. Add an opt-in mode flag (for example `TUI_DIFF_STYLE=github`) so rollout is controlled.
2. Add a diff line classifier with explicit categories:
   - `file_header_old`, `file_header_new`, `hunk`, `add`, `del`, `context`, `meta`
3. Apply GitHub-like baseline styling:
   - additions: green background
   - deletions: red background
   - hunk/file header/context styles aligned for readability
4. Add language-aware inner highlighting for `+`/`-` content:
   - infer language from `+++ b/<path>` extension when available
   - run existing language highlighters on line content after prefix marker
   - preserve visible `+`/`-` prefixes
5. Add ANSI composition helper to preserve background through token-level foreground color resets.
6. Add targeted tests:
   - classification precedence
   - background styling presence on add/delete lines
   - language inference from diff headers
   - mixed diff blocks with hunk + context + add/delete lines
   - text fidelity after stripping ANSI
7. Validate manually on representative diffs (TypeScript, Python, AILANG) across common terminal themes.

## Token Highlighting Strategy
- Implement an in-file lightweight lexer highlighter (no external package) for maintainability and no install step.
- TypeScript/JS tokens:
  - keywords (blue)
  - built-ins/common globals (cyan)
  - string literals (green)
  - numeric literals (magenta)
  - comments (gray)
- Python tokens:
  - keywords (blue)
  - built-ins (cyan)
  - string literals including triple-quoted strings (green)
  - numeric literals (magenta)
  - comments (gray)
  - explicit multi-line lexer state for triple-quoted strings
- AILANG tokens:
  - exact reserved keywords from language reference (blue):
    - `if`, `then`, `else`, `match`, `with`, `select`, `timeout`
    - `func`, `pure`, `let`, `letrec`, `in`
    - `type`, `class`, `instance`, `forall`, `exists`, `deriving`
    - `module`, `import`, `export`, `extern`, `as`
    - `test`, `tests`, `property`, `properties`, `assert`
    - `requires`, `ensures`, `invariant`
    - `spawn`, `parallel`, `channel`, `send`, `recv`
    - `true`, `false`, `and`, `or`, `not`
  - ADT constructors and enum-like PascalCase names (cyan)
  - effects and capabilities in `! {IO, FS, Net, AI, ...}` (cyan bright)
  - string literals (green)
  - numeric literals (magenta)
  - comments using `-- ...` (gray)
  - core syntax markers (`->`, `=>`, `::`, `++`, `|`, `\\`) with subtle operator color
- Shell tokens:
  - control keywords (blue)
  - env vars/substitutions (cyan)
  - comments (gray)
  - commands (yellow)
- Diff tokens:
  - `--- ` / `+++ ` file headers
  - `@@ ... @@` hunk headers
  - `+` additions
  - `-` deletions
  - context lines
  - GitHub-style upgrade: add/delete background colors with preserved token readability

## Test Strategy (Preferred for Stability)
- Use token-class tests and invariants rather than full-string ANSI snapshots.
- Primary test file: `src/tui/src/ui.highlight.test.ts`.
- Unit-test each language highlighter with representative lines and edge cases:
  - TypeScript/JS: keyword, string, comment, number.
  - Python: keyword, comment, number, and multi-line triple-quoted string continuity.
  - AILANG: reserved keywords, `--` comments, effects block, ADT constructor pattern.
  - Shell: env vars, command head, comments.
  - Diff: file header, hunk header, add/delete/context precedence.
  - GitHub-style diff mode: background + language-token composition and precedence.
- Add smoke assertions that highlighted output contains ANSI sequences for recognized languages.
- Assert output line count equals input line count for all languages.
- Add exact AILANG keyword-set tests:
  - assert highlighted keyword set equals the canonical lexer-backed reserved set (no additions, no omissions)
  - assert canonical set size is exactly 41

## Validation Plan
1. Build frontend: `cd src/tui && npm run build`.
2. Run tests: `cd src/tui && npm test`.
3. Manual verification in TUI:
   - Submit response text containing fenced `typescript` block (like the provided `index.ts` sample).
   - Submit response text containing fenced `python` block with triple-quoted string.
   - Submit response text containing fenced `ailang` block using representative constructs (`module`, `import`, `match`, `type`, effects, `--` comments).
   - Submit response text containing fenced `diff` block with file headers, hunk headers, and mixed add/delete/context lines.
   - Confirm code block borders remain visible and code lines show multiple colors.
   - Verify non-code markdown still renders unchanged.
4. Fixture-based regression inputs (committed in tests):
   - fixed multiline Python fixture for triple-quoted handling
   - fixed AILANG fixture covering reserved keywords/effects/comments/constructors
   - fixed diff fixture covering headers/hunks/additions/deletions/context
   - fixed github-style diff fixture with mixed-language file paths and hunk blocks

## Risks and Mitigations
- Risk: ANSI resets inside inline styles can bleed.
  - Mitigation: keep per-line styling simple and rely on `pi-tui` line wrapping.
- Risk: naive lexer may color edge cases imperfectly.
  - Mitigation: prioritize readability; keep fallback safe for unknown syntax.
- Risk: too aggressive shell command coloring.
  - Mitigation: conservative regexes and comment-first handling.
- Risk: AILANG token ambiguity (`|` in ADTs/records, constructors vs identifiers).
  - Mitigation: apply conservative constructor/effect heuristics and prefer correctness over over-coloring.
- Risk: diff precedence ambiguity (`---` file header vs deletion line).
  - Mitigation: enforce ordered matching and dedicated tests.
- Risk: ANSI reset interactions between foreground token colors and line backgrounds.
  - Mitigation: add background reapplication helper and regression tests for composed styles.

## Files Expected to Change
- `src/tui/src/ui.ts` (primary)
- `src/tui/src/ui.highlight.test.ts` (new tests for highlighters)

## Acceptance Criteria
- Fenced TypeScript blocks are rendered with visible keyword/token colors.
- Fenced Python blocks are rendered with visible keyword/token colors, including correct multi-line triple-quoted handling.
- Fenced AILANG blocks are rendered with visible keyword/token colors using the exact reserved keyword set from language reference.
- Fenced diff blocks are rendered with clear file/hunk/add/delete/context differentiation.
- GitHub-style upgrade mode renders add/delete lines with readable green/red backgrounds and preserves inner language token contrast.
- Shell fenced blocks have differentiated coloring.
- Unknown-language fenced blocks remain legible.
- Highlighter unit tests pass using token-class assertions.
- AILANG keyword-set tests assert exact 41-keyword parity.
- Frontend build/tests pass.
