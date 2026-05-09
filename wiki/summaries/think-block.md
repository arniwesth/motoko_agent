---
doc_type: short
full_text: sources/think-block.md
---

# Think block issues (summary)

The document enumerates five open issues related to the Think block component in the terminal UI (`tui/src/ui.ts`), all on the `Tool_Parse_Robustness` branch.

1. **Blank line per collapsed block**: An empty `Text` element is unconditionally added to the history when a think block is rendered collapsed, causing spurious blank lines. Fix: only add the body row on first expand.
2. **No cycle-position indicator**: There is no `(N/M)` counter to show position when cycling through think blocks with `ctrl+t`. Fix: add a counter to the header.
3. **Cycling logic has no tests**: The block cycling and expand/collapse logic are untested. Fix: write a test suite using a mock `ProcessTerminal`, similar to existing tests.
4. **selectedThinkIdx not reset between sessions**: Session state (`selectedThinkIdx`, `thinkStepOrder`, `thinkBlocks`) is not cleared on `session_start`, leading to stale indices. Fix: reset them in the `session_start` event handler.
5. **Timestamp changes on each expand/collapse**: `collapseThinkBlock` and `expandThinkBlock` call `this.stamp(...)` using current time, overwriting the original timestamp. Fix: capture the stamp at render time and reuse it.

All issues are **open** and proposed fixes are provided. The underlying theme is improving robustness and user experience of the think block feature. Suggested [[concepts/think-block]] concept page could synthesize these concerns and design decisions. Related cross-cutting topics include [[concepts/session-state-management]] and [[concepts/terminal-ui-testing]].