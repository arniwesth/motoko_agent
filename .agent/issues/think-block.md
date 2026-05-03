# Think block: blank line per collapsed block

## Status
open

## Branch
Tool_Parse_Robustness

## Description
`bodyRow = styledText("", chalk.dim)` is unconditionally added to the history `Box` when a think block is rendered collapsed. An empty `Text` renders as one blank terminal line. In a 20-step run with thinking traces this produces 20 blank lines scattered through the history.

## Location
`tui/src/ui.ts` — `thinking` event handler, think block construction

## Fix
Do not add `bodyRow` to the history initially. Instead, insert it lazily on first expand and remove it on collapse. Alternatively, hold a list of body rows and set their text to `"\u200b"` (zero-width space) when collapsed so they take no visible space, but this depends on whether pi-tui treats a single zero-width-space line as zero-height.

The cleanest approach: track whether `bodyRow` has been added to the box (`bodyAdded: boolean` on `ThinkBlock`) and only call `this.history.addChild(bodyRow)` inside `expandThinkBlock`, guarded by `!block.bodyAdded`.


# Think block: no cycle-position indicator

## Status
open

## Branch
Tool_Parse_Robustness

## Description
When cycling through think blocks with `ctrl+t`, there is no visual indicator of position. After wrapping from the oldest block back to the newest the user has no way to know they have cycled all the way around, or how many blocks exist in total.

## Location
`tui/src/ui.ts` — `expandThinkBlock` / `selectThinkBlock`

## Suggested fix
Add a `(N/M)` counter to the header line, e.g.:

```
  [think] step 3 · 847 chars  ▾  ^t  (2/4)
```

`selectThinkBlock` already has access to `idx` and `this.thinkStepOrder.length`, so the counter can be computed there and passed to `expandThinkBlock`.


# Think block: cycling logic has no tests

## Status
open

## Branch
Tool_Parse_Robustness

## Description
The `selectThinkBlock` / `collapseThinkBlock` / `expandThinkBlock` logic and the `ctrl+t` index-cycling arithmetic are non-trivial and currently have no automated tests. In particular:
- Cycling from the most recent to older blocks and wrapping back around
- Only one block expanded at a time (previous collapses correctly)
- Behaviour with a single block (toggle-like)
- Behaviour when no blocks exist yet (`thinkStepOrder.length === 0`)

## Location
`tui/src/ui.ts` — `selectThinkBlock` and `ctrl+t` input listener

## Fix
Add `tui/src/ui.think-cycling.test.ts`. The test can drive `AgentUI` with a mock `ProcessTerminal` (same pattern as `ui.wait-state.test.ts`) and inject `thinking` events with `think`/`answer` fields, then simulate `ctrl+t` keypresses and assert on `headerRow.text` and `bodyRow.text` values.


# Think block: selectedThinkIdx not reset between sessions

## Status
open

## Branch
Tool_Parse_Robustness

## Description
`selectedThinkIdx` and `thinkStepOrder` are never reset when a new session starts. If the runtime restarts mid-session (e.g. a follow-up task after task completion), new think blocks are pushed onto `thinkStepOrder` but `selectedThinkIdx` may still point to an index that now refers to a different block than expected. In the worst case the index is out of bounds.

## Location
`tui/src/ui.ts` — `handleEvent` `session_start` case

## Fix
Reset both on `session_start`:

```typescript
case "session_start":
  this.thinkStepOrder.length = 0;
  this.thinkBlocks.clear();
  this.selectedThinkIdx = -1;
  // ...existing logic...
```

Note: clearing `thinkBlocks` also releases the memory of prior-session content, addressing the unbounded-growth minor issue.


# Think block: timestamp changes on each expand/collapse

## Status
open

## Branch
Tool_Parse_Robustness

## Description
`collapseThinkBlock` and `expandThinkBlock` both call `this.stamp(...)` which reads the current wall-clock time. This means the timestamp displayed in the think-block header changes every time the user presses `ctrl+t`. The original timestamp (when the model returned the response) is lost on the first toggle.

## Location
`tui/src/ui.ts` — `collapseThinkBlock`, `expandThinkBlock`

## Fix
Store the stamp string at render time inside `ThinkBlock`:

```typescript
interface ThinkBlock {
  // ...
  stamp: string;  // captured once when the block is first rendered
}
```

Use `block.stamp` instead of `this.stamp(...)` in `collapseThinkBlock` and `expandThinkBlock`.