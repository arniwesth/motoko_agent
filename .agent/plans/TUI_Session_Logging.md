# Plan: TUI Session Logging to `logfile/` Folder

## Context

There is no session-level logging in the TUI today. The AILANG runtime emits JSONL events on stdout, the `RuntimeProcess` class parses them and passes them to the UI via an `onEvent` callback, but nothing is written to disk. The only file-writing is per-snippet persistence in `env-server.ts` (for fine-tuning), and an unrelated `logs/` folder with old benchmark logs. Adding a session log gives the user a persistent, human-readable record of every agent run for debugging and review.

## Approach

Add a `SessionLogger` class in a new file `src/tui/src/session-logger.ts` that:
1. Creates a `logfile/` directory under the Motoko project root if it doesn't exist.
2. Opens a write stream to a timestamped JSONL file for the session.
3. Exposes a `log(event: AgentEvent)` method that writes one JSON line per event.
4. Exposes a `close()` method that flushes and closes the stream.

Wire it into the event pipeline in `src/tui/src/index.ts` — the single place where `RuntimeProcess` events are consumed before being forwarded to the UI.

## Files to modify

| File | Change |
|------|--------|
| `src/tui/src/session-logger.ts` | **New file.** `SessionLogger` class. |
| `src/tui/src/index.ts` | Import `SessionLogger`, create instance before spawning runtime, call `logger.log(event)` in the event callback, call `logger.close()` on exit. |
| `.gitignore` | Add `logfile/` entry so session logs aren't committed. |

## Step-by-step

### 1. Create `src/tui/src/session-logger.ts`

```ts
import * as fs from "fs";
import * as path from "path";
import type { AgentEvent } from "./runtime-process.js";

export class SessionLogger {
  private stream: fs.WriteStream;
  readonly filePath: string;

  constructor(projectRoot: string) {
    const dir = path.join(projectRoot, "logfile");
    fs.mkdirSync(dir, { recursive: true });

    const ts = new Date().toISOString().replace(/[:.]/g, "-");
    this.filePath = path.join(dir, `session_${ts}.jsonl`);
    this.stream = fs.createWriteStream(this.filePath, { flags: "a" });
  }

  log(event: AgentEvent): void {
    this.stream.write(JSON.stringify(event) + "\n");
  }

  close(): void {
    this.stream.end();
  }
}
```

Key decisions:
- **JSONL format** — one JSON object per line, matches the runtime's own protocol, easy to parse/grep.
- **Timestamped filename** — `session_2026-04-27T14-30-00-000Z.jsonl` avoids collisions.
- **`flags: "a"`** — append mode; safe if the file already exists (shouldn't, but defensive).
- **`mkdirSync` with `recursive: true`** — creates `logfile/` on first use, no-op after.

### 2. Wire into `src/tui/src/index.ts`

**Compute `projectRoot` in `main()`** — `import.meta.dirname` resolves to `src/tui/src/` (source) or `src/tui/dist/` (compiled). Three levels up gives the Motoko project root. Add this near the top of `main()`, after the existing `pkgPath` computation (~line 258):

```ts
const projectRoot = path.resolve(import.meta.dirname, "../../..");
```

**Non-TTY path** (line ~331) — create logger, log every event, close on exit:
```ts
const logger = new SessionLogger(projectRoot);
runtimeProcess = new RuntimeProcess(task, envUrl, model, workdir, (event) => {
  logger.log(event);
  ui.handleEvent(event);
}, () => {
  logger.close();
  ui.stop();
});
```

**TTY path** — `spawnRuntimeProcess()` (line ~342) has three exit branches: interrupted (ESC), error recovery, and normal exit. The logger must be scoped per-call (each task gets its own log file) and closed in all three branches:

```ts
function spawnRuntimeProcess(task: string): void {
  errorOccurred = false;
  const logger = new SessionLogger(projectRoot);
  runtimeProcess = new RuntimeProcess(
    task, envUrl, model, workdir,
    (event) => {
      if (event.type === "error") errorOccurred = true;
      logger.log(event);
      ui.handleEvent(event);
    },
    () => {
      logger.close();          // <-- close in ALL exit paths
      ui.runtimeProcess = undefined;
      if (interrupted) {
        interrupted = false;
        ui.setAwaitingTask(true);
      } else if (errorOccurred) {
        errorOccurred = false;
        ui.setAwaitingTask(true);
      } else {
        ui.stop();
        process.exit(0);
      }
    },
  );
  ui.runtimeProcess = runtimeProcess;
}
```

Since `spawnRuntimeProcess` can be called multiple times (ESC → new task), each call creates a fresh `SessionLogger` instance with its own file.

### 3. Add `logfile/` to `.gitignore`

Append `logfile/` so session logs stay local.

## Verification

1. `cd src/tui && npm run build` — confirm TypeScript compiles.
2. `make run TASK="echo hello" MODEL=anthropic/claude-sonnet-4-6 WORKDIR=.` — run a short session.
3. Confirm `logfile/session_*.jsonl` was created with one JSON object per line.
4. `cd src/tui && npm test` — confirm existing tests still pass.
