# ESC Interrupt: Implementation Plan

## Goal

Allow the user to press **ESC** to interrupt a running task. After interruption, the input is re-enabled so the user can submit a new prompt — identical to the state after a normal task completion.

---

## Background

### Brain abort behaviour

`check_abort()` in `swe/rpc.ail:78-87` uses a non-blocking stdin poll. It runs at the **top of every `rpc_loop` iteration**, before the LLM call. This means:

- Abort is checked **between steps**, not mid-LLM-call or mid-exec.
- If the brain is currently awaiting an LLM response or a bash command (30 s timeout), the abort signal is buffered and honoured at the start of the next step.
- After detecting abort, the brain emits `{ "type": "error", "message": "aborted" }` and falls through to `conversation_loop` — the same state it enters after a normal `done`.

So **the brain already supports abort correctly**. No changes to `swe/rpc.ail` are needed.

### Current UI gap

The `error` event handler in `tui/src/ui.ts:245-249` displays the error message but does **not**:
- Set `taskDone = true`
- Restore keyboard focus to `cmdInput`

This is the only missing piece that prevents the re-prompt flow from working after an abort.

### ESC vs autocomplete

The `Editor` component already uses ESC internally to cancel autocomplete suggestions. The global `tui.addInputListener` runs **before** focused component handlers. The return value `{ consume: true }` prevents ESC from reaching the Editor; returning `undefined` passes it through. This allows conditional delegation: consume ESC only when a task is actually running.

---

## Changes required

### 1. `tui/src/ui.ts` — Extend the input listener (lines 169-175)

Add ESC handling alongside the existing `ctrl+c` check:

```typescript
this.tui.addInputListener((data) => {
  if (matchesKey(data, "ctrl+c")) {
    this.onAbort?.();
    return { consume: true };
  }
  // ESC while a task is running: send abort signal to brain.
  // Do NOT consume ESC when idle — let Editor handle it (e.g. cancel autocomplete).
  if (matchesKey(data, "escape") && this.brain && !this.taskDone) {
    this.brain.abort();
    return { consume: true };
  }
  return undefined;
});
```

**Why not call `onAbort`?** `onAbort` in `index.ts` currently calls `process.exit(0)`. ESC should interrupt the task but keep the process alive for a follow-up prompt. The soft `brain.abort()` is sufficient — the brain will emit an `error` event which the UI handles (see step 2).

### 2. `tui/src/ui.ts` — Handle the "aborted" error event (lines 245-249)

Extend the `error` case to detect the abort signal and transition to the re-prompt state:

```typescript
case "error":
  this.history.addChild(
    styledText(`Error: ${event.message}`, chalk.red)
  );
  // An "aborted" error means the brain is now in conversation_loop,
  // waiting for the next user message — same state as after "done".
  if (event.message === "aborted") {
    this.taskDone = true;
    this.tui.setFocus(this.cmdInput);
  }
  break;
```

---

## What does NOT need to change

| Component | Reason |
|-----------|--------|
| `swe/rpc.ail` | Brain already handles `abort` correctly and enters `conversation_loop` |
| `tui/src/brain.ts` | `brain.abort()` already sends `{ "type": "abort" }` on stdin |
| `tui/src/index.ts` | No wiring changes needed; `onAbort` is not used for ESC |
| `tui/src/commands.ts` | `/abort` command continues to work as before (exits process) |
| JSONL protocol | No new message types needed |

---

## Edge cases

| Scenario | Behaviour |
|----------|-----------|
| ESC while no task is running (`!brain \|\| taskDone`) | Not consumed; Editor handles it (cancels autocomplete if active) |
| ESC while LLM call is in flight | Abort buffered on stdin; honoured at start of next step |
| ESC while bash command is executing (up to 30 s) | Same — buffered; honoured after exec returns |
| ESC pressed multiple times | `brain.abort()` is idempotent (sends a JSONL line); no harm |
| Rapid ESC followed immediately by new prompt | New prompt sits in `cmdInput`; brain processes abort first, enters `conversation_loop`, then `taskDone = true` enables the submission |
| Brain ignores abort (unexpected) | Brain continues running; UI is stuck. This is an existing limitation of the soft-abort design and is out of scope here. A timeout + SIGTERM fallback can be added later if needed. |

---

## Testing checklist

- [ ] ESC while agent is stepping → history shows `Error: aborted`, input re-enabled
- [ ] New prompt submitted after ESC → brain processes it as a follow-up
- [ ] ESC with autocomplete open and no task running → autocomplete dismissed, input unchanged
- [ ] ESC with autocomplete open while task is running → task aborted (autocomplete closes as side-effect)
- [ ] Ctrl+C still exits the process as before
- [ ] `/abort` slash command still exits the process as before
- [ ] Normal task completion (done event) still re-enables input as before
