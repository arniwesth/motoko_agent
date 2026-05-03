# Session Summary: AILANG SWE Agent — 2026-03-30

## What was built

A full software engineering agent on top of the AILANG language runtime, consisting of a TypeScript terminal frontend and an AILANG brain process that communicates over a JSONL pipe.

---

## Repository layout produced

```
ailang_agent/
├── tui/
│   ├── src/
│   │   ├── env-server.ts     Express server: POST /exec, /snapshot, /restore, GET /health
│   │   ├── env-server.test.ts 4 acceptance tests (all passing)
│   │   ├── brain.ts          Spawns ailang subprocess, wires JSONL pipe
│   │   ├── models.ts         KNOWN_MODELS list (7 providers)
│   │   ├── ui.ts             pi-tui terminal UI (history, status bar, /model overlay)
│   │   └── index.ts          Entry point; wires env-server + brain + UI
│   ├── package.json          deps: @mariozechner/pi-tui, express, chalk, typescript
│   └── tsconfig.json         module: Node16, target: ES2022
├── swe/
│   ├── types.ail             Msg, ExecResult, AgentState, StepOutcome
│   ├── parse.ail             extract_bash, is_done, parse_cwd (pure)
│   ├── env_client.ail        exec_in — HTTP POST to env-server
│   ├── prompts.ail           base_system, with_cache_hint, fmt_msgs, fmt_obs
│   ├── cache.ail             get_hint, put_trajectory via std/sem
│   └── rpc.ail               rpc_loop, main — always-yolo brain, 50-step budget
├── runtime-patches/
│   ├── io_poll_stdin.builtin.go  Patch for internal/builtins/io.go
│   ├── io_poll_stdin.effects.go  Patch for internal/effects/io.go
│   └── README.md
├── scripts/
│   ├── install-prerequisites.sh  Installs Go, Node.js, npm deps (Debian + macOS)
│   └── run-agent.sh              Runs tui/dist/index.js by absolute path
├── Makefile                  Added: build, run, install targets
└── README.md                 Full install + run documentation
```

---

## Architecture

Three-process design:

1. **TypeScript process** (`node tui/dist/index.js`) owns the terminal and the environment server
2. **Embedded environment server** (express, default :8080) executes bash commands via `execSync`
3. **AILANG brain process** (`ailang run swe/rpc.ail`) communicates over JSONL on stdin/stdout

The brain always runs in yolo mode — no confirm/reject step. It emits JSONL events to stdout (session_start, thinking, proposed_cmd, obs, done, error) and reads JSONL commands from stdin (abort, model_change).

---

## Key decisions

### Yolo mode only
The Mode ADT was eliminated entirely. AgentState carries no mode field. The loop reduces to: call LLM → extract bash block → execute → emit observation → recurse.

### JSONL protocol
All IPC is newline-delimited JSON. readline splits on `
` only (never Unicode line separators). Malformed lines are silently skipped on the TypeScript side.

### `_io_poll_stdin` builtin
A non-blocking stdin peek builtin was required for the brain to check for abort/model_change commands without blocking the recursive loop. This was:
- Specified in `runtime-patches/` with full Go code
- Applied directly to the AILANG repo at `ailang/internal/builtins/io.go` and `ailang/internal/effects/io.go`
- Verified: `ailang run --caps IO --entry main /tmp/test_poll.ail` prints `poll result: ''`

### Model switching (phases 0-4)
Model changes sent via `/model` are stored in SharedMem (`_sharedmem_put("swe:current_model", ...)`) but the running process continues using the original `--ai` flag. The new model takes effect on the next brain invocation. Phase 5 (optional) swaps one line: `call(...)` → `call_with(model2, ...)`.

### Trajectory cache
After a successful run, the final output is stored in SharedMem via `std/sem` under a key derived from the task text. On subsequent runs against the same task, the hint is injected into the system prompt via `with_cache_hint`.

---

## Bugs fixed during session

### tsconfig module mismatch
`module: ESNext` is incompatible with `moduleResolution: Node16`. Fixed to `module: Node16`.

### pi-tui API mismatch
The plan assumed a React-like options-object API (`new Text(str, {bold, color})`, `new Box({scrollable, grow})`). The actual installed API is positional: `Text(text?, paddingX?, paddingY?, bgFn?)`. ui.ts was rewritten after reading the actual `.d.ts` files. Key differences:
- `Text` — no colour options; use chalk via `bgFn` parameter
- `Box` — no scrollable/grow; plain container with padding
- `Markdown` — requires a full `MarkdownTheme` object as 4th argument
- `Input` — no constructor args; use `setValue("")` to clear (no `clear()` method)
- `SelectList` — takes `SelectItem[]` (not strings), `maxVisible: number`, and a theme object; `onSelect` receives `SelectItem`
- `showOverlay` — returns `OverlayHandle`; call `handle.hide()` to dismiss (no `hideOverlay()` method)

### Wrong working directory
Running `node tui/dist/index.js` from inside `ailang/` resolved to `ailang/tui/dist/index.js` which does not exist. Fixed with `scripts/run-agent.sh`, which resolves the path relative to the script's own location using `$(dirname ${BASH_SOURCE[0]})/..`.

---

## Files verified

- `npm run build` — passes (zero TypeScript errors)
- `npm test` — 4/4 env-server acceptance tests pass:
  - echo command returns stdout and exit_code 0
  - nonzero-exit command returns correct exit_code
  - timeout enforced (sleep 30 killed after 1s)
  - GET /health returns `{status: "ok"}`
- `ailang run --caps IO --entry main /tmp/test_poll.ail` — `_io_poll_stdin(())` returns `""`

---

## What remains

- **AILANG brain untestable without `ailang check`** — the `.ail` files are written to spec but cannot be type-checked in this environment without a working `ailang check` command against the swe/ module tree.
- **Phase 5** (optional): swap `call(fmt_msgs(...))` → `call_with(model2, fmt_msgs(...))` in `swe/rpc.ail` once the `call_with` builtin is implemented in the runtime.
- **Phase 4**: SWE-bench 10-issue sample benchmark to gate further work.
- **SharedMem persistence**: the trajectory cache survives only as long as the SharedMem process lives; no cross-restart persistence without a separate store.
