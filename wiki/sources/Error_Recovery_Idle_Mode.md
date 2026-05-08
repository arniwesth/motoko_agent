# Plan: Error Recovery — Stay Alive on Runtime Error

## Files modified

| File | Status |
|------|--------|
| `tui/src/runtime-process.ts` | Modified |
| `tui/src/index.ts` | Modified |
| `tui/src/ui.ts` | Modified |

## Problem

When the AILANG runtime gets an AI API error (e.g. 429 rate-limit), the process crashes. The TUI then exits.

### Root cause

`call()` in `std/ai` returns a bare `string` — no `Result` wrapping. There is no error handling around `call(fmt_msgs(...))` at `core/rpc.ail:577`. When the AI API returns any error, the AILANG interpreter throws an unhandled exception that crashes the process. The crash message goes to stderr (`"inherit"` in `runtime-process.ts`), bypassing the JSONL pipe entirely. The TUI sees only a process exit and calls `process.exit(0)`.

### Constraint

Do not touch the AILANG runtime (`ailang/`). Changes are restricted to `core/` and `tui/` only.

Since the crash cannot be prevented from within AILANG code (no `Result`-returning variant of `call()` exists in `std/ai`), the fix lives entirely in the TUI layer: capture the crash, recover gracefully, and retry on 429.

---

## Goal

- TUI stays alive when the runtime crashes on an AI error
- 429 rate-limit errors are retried with exponential backoff + jitter (silently, like the Anthropic/OpenAI SDKs)
- Non-429 errors are logged in bright red and the TUI goes to idle/awaiting-task mode
- A retry countdown is shown in the history pane during backoff

---

## Changes

### 1. `tui/src/runtime-process.ts` — pipe stderr; synthesize `error` event

Change `stdio` from `["pipe", "pipe", "inherit"]` to `["pipe", "pipe", "pipe"]`. Buffer stderr and, on process exit, if stderr has content emit a synthetic `error` event before calling `onExit`. This routes the crash message through the normal JSONL event path so the TUI can act on it:

```ts
stdio: ["pipe", "pipe", "pipe"],  // was: "inherit" for stderr
```

```ts
let stderrBuf = "";
this.proc.stderr!.on("data", (chunk: Buffer | string) => {
  stderrBuf += typeof chunk === "string" ? chunk : chunk.toString("utf8");
});

this.proc.on("exit", () => {
  this.dead = true;
  if (stderrBuf.trim()) {
    onEvent({ type: "error", message: stderrBuf.trim() });
  }
  onExit();
});
```

### 2. `tui/src/index.ts` — retry on 429, go idle on other errors

Track the current task so it can be re-submitted on retry. On `error` events, inspect the message: if it contains `"429"` schedule a retry with exponential backoff; otherwise go to awaiting-task.

```ts
let errorOccurred = false;
let lastErrorMessage = "";
let currentTask = "";        // set when spawning
let retryCount = 0;
let retryTimer: NodeJS.Timeout | undefined;
```

Save the task when spawning:

```ts
function spawnRuntimeProcess(task: string): void {
  currentTask = task;
  retryCount = 0;
  // ... existing spawn logic ...
}
```

Intercept `error` events:

```ts
(event) => {
  if (event.type === "error") {
    errorOccurred = true;
    lastErrorMessage = event.message;
  }
  ui.handleEvent(event);
}
```

In `onExit`, branch on whether it was a 429:

```ts
() => {
  ui.runtimeProcess = undefined;
  if (interrupted) {
    interrupted = false;
    ui.setAwaitingTask(true);
    return;
  }
  if (errorOccurred) {
    const msg = lastErrorMessage;
    errorOccurred = false;
    lastErrorMessage = "";
    if (isRateLimit(msg) && retryCount < 3) {
      const waitMs = retryBackoffMs(retryCount);
      retryCount += 1;
      ui.appendRetryCountdown(retryCount, waitMs);
      retryTimer = setTimeout(() => {
        retryTimer = undefined;
        spawnRuntimeProcess(currentTask);
      }, waitMs);
    } else {
      retryCount = 0;
      ui.setAwaitingTask(true);
    }
    return;
  }
  ui.stop();
  process.exit(0);
}
```

Helper functions:

```ts
function isRateLimit(msg: string): boolean {
  return msg.includes("429") || msg.toLowerCase().includes("rate limit");
}

function retryBackoffMs(attempt: number): number {
  // Exponential backoff with full jitter: min(base * 2^n, cap) * random
  const base = 1000;
  const cap = 60_000;
  const ceiling = Math.min(base * Math.pow(2, attempt), cap);
  return Math.floor(Math.random() * ceiling) + 500; // +500ms floor
}
```

Also cancel any pending retry on abort/interrupt:

```ts
ui.onAbort = () => {
  if (retryTimer) { clearTimeout(retryTimer); retryTimer = undefined; }
  // ... existing abort logic ...
};
```

### 3. `tui/src/ui.ts` — bright red error; retry countdown

**`"error"` case** — `chalk.redBright` and restore focus:

```ts
case "error":
  this.setRunState("error");
  this.appendHistoryStyled(`Error: ${event.message}`, chalk.redBright);
  this.tui.setFocus(this.cmdInput);
  break;
```

**New public method `appendRetryCountdown`** — shows a dim message during backoff:

```ts
appendRetryCountdown(attempt: number, waitMs: number): void {
  const secs = Math.round(waitMs / 1000);
  this.appendHistoryStyled(
    `Rate limited. Retry ${attempt}/3 in ${secs}s...`,
    chalk.yellow
  );
  this.tui.requestRender();
}
```

---

## Files touched

| File | Change |
|------|--------|
| `tui/src/runtime-process.ts` | Pipe stderr; emit synthetic `error` event on exit |
| `tui/src/index.ts` | Track current task; exponential backoff retry on 429; go idle on other errors |
| `tui/src/ui.ts` | `chalk.redBright` for errors; `appendRetryCountdown` method |

## Files NOT touched

- `core/` — no changes needed
- `ailang/` — explicitly out of scope
- `PlainLogger` — `process.exit(1)` on error remains correct for non-TTY/CI

---

## Backoff parameters

| Attempt | Formula | Approximate wait |
|---------|---------|-----------------|
| 1 | `random(0, 1s) + 0.5s` | 0.5–1.5s |
| 2 | `random(0, 2s) + 0.5s` | 0.5–2.5s |
| 3 | `random(0, 4s) + 0.5s` | 0.5–4.5s |

3 retries, then surface the error and go idle. Consistent with Anthropic and OpenAI SDK defaults.

---

## Future improvement (out of scope)

Add `_ai_call_result` builtin to `ailang/internal/effects/ai.go` returning `Result[string]`. Then `core/rpc.ail` can catch errors without crashing, and retry logic can live inside the long-running process rather than requiring a full respawn. This avoids losing the conversation history on each retry.

---

## Test cases to verify

1. 429 from rate-limited model → TUI shows bright red error + yellow countdown, respawns after backoff, task resumes
2. Three consecutive 429s → TUI retries 3 times then goes idle with error shown
3. Fourth 429 after exhausting retries → goes idle, user can submit new task
4. Non-429 error (bad API key, invalid model) → goes idle immediately, no retry
5. ESC during a running task → existing behaviour unchanged
6. Normal task completion → TUI exits cleanly
7. `/abort` during retry countdown → countdown cancelled, TUI exits
