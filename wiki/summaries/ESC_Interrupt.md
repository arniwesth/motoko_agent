---
doc_type: short
full_text: sources/ESC_Interrupt.md
---

# ESC Interrupt Implementation Plan

This document describes how to add an **ESC** key interrupt for a running task, re-enabling the input so the user can submit a new prompt — the same state as after a normal task completion.

## Background

The brain already supports abort correctly via `check_abort()` in `swe/rpc.ail`, which uses non‑blocking stdin polling. Abort is checked **between steps**, buffered if the brain is waiting for an LLM or bash command. Upon detecting abort, the brain emits `{"type":"error","message":"aborted"}` and returns to `conversation_loop` — identical to a `done` event.

The TUI’s `error` handler (`tui/src/ui.ts:245-249`) displays the abort message but fails to set `taskDone = true` and restore keyboard focus to the input. This is the **UI gap** that prevents a re‑prompt flow.

ESC also conflicts with the `Editor` component that uses ESC to cancel autocomplete. The global input listener runs before focused component handlers, so we can conditionally consume ESC only when a task is running.

## Changes Required

Two small additions to `tui/src/ui.ts`:

1. **Input listener enhancement** (lines 169–175): add ESC handling alongside `ctrl+c`. When a task is running (`this.brain && !this.taskDone`), call `this.brain.abort()` and consume the event; otherwise pass ESC through to the Editor.
2. **Abort error handler** (lines 245–249): in the `"error"` case, detect `event.message === "aborted"` and set `this.taskDone = true` and `this.tui.setFocus(this.cmdInput)`, restoring the post‑task state.

## Unchanged Components

- `swe/rpc.ail` — brain abort behavior works as is.
- `tui/src/brain.ts` — `brain.abort()` already sends the JSONL abort line.
- `tui/src/index.ts` — no wiring changes; `onAbort` is not used for ESC.
- `/abort` slash command — continues to exit the process.
- JSONL protocol — no new message types.

## Edge Cases

- ESC when no task is running: passed through to Editor (autocomplete dismiss).
- ESC during LLM call or bash execution: buffered; honored at next step start.
- Multiple rapid ESC presses: `brain.abort()` is idempotent.
- ESC immediately followed by new prompt: new prompt sits in input; abort is processed first, then `taskDone = true` enables submission.
- Brain ignoring abort: UI stays stuck; a future timeout/SIGTERM fallback may be added.

## Related Concepts

- [[concepts/soft_abort]] – non‑preemptive abort mechanism using stdin polling
- [[concepts/autocomplete_conflict]] – managing key overlap between global shortcuts and focused components
- [[concepts/task_interruption_ui]] – re‑enabling the UI after a task is interrupted
- [[concepts/brain_abort_flow]] – the brain’s abort handling and return to `conversation_loop`

## Testing

A checklist verifies ESC aborts a running task, re‑enables input, coexists with autocomplete, and that `ctrl+c` and `/abort` still exit the process.