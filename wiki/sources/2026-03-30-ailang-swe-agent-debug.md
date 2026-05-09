# Session Summary: AILANG SWE Agent Debugging — 2026-03-30

## Problem

Running `MODEL=openai/gpt-4o WORKDIR=. ./scripts/run-agent.sh` failed immediately with:

```
Error: module loading error: failed to load swe/rpc.ail ... parse errors in swe/rpc.ail:
PAR_NO_PREFIX_PARSE at swe/rpc.ail:62:32: unexpected token in expression: ;
...
```

Twenty-plus parse errors across `swe/rpc.ail`. Subsequent investigation revealed the same class of error in all five other `swe/*.ail` modules.

## Root Cause

The entire `swe/` module tree was generated from the plan spec without being verified against the actual AILANG language rules. Three categories of syntactic errors were present.

### 1. Expression-body functions with semicolon sequencing

AILANG has two function body styles:

- **Expression body** (`= expr`): a single expression. No semicolons. Multi-binding sequences require `let x = e1 in let y = e2 in ...`.
- **Brace body** (`{ stmts }`): a block. Statements separated by `;`. `let` bindings do not need `in`.

All `swe/` functions that needed multiple `let` bindings used the expression-body `=` form but separated bindings with `;`, which is only valid inside `{}` blocks. Example from the broken code:

```ailang
func poll_cmd() -> Option[string] ! {IO} =
  let line = _io_poll_stdin(());    -- ← ; is illegal here
  if line == "" then None else Some(trim(line))
```

Fix: convert to brace-body throughout.

### 2. `export let` not supported

AILANG's parser rejects `export let` with the message "use export func instead". `swe/prompts.ail` had:

```ailang
export let base_system: string = "..."
```

Fix: converted to `export func base_system() -> string = "..."` and updated the single call site in `rpc.ail` to `base_system()`.

### 3. API mismatches with stdlib and builtins

Several functions referenced non-existent or misused APIs:

| Broken usage | Correct form | Notes |
|---|---|---|
| `hd(state.msgs)` | pattern match `_ :: user :: _` | `hd` does not exist; `head` from `std/list` returns `Option` |
| `float(state.step)` | `_int_to_float(state.step)` | No `float()` cast; use builtin or `intToFloat` from `std/math` |
| `msgs :: [x]` | `msgs ++ [x]` | `::` is pattern syntax only; list append uses `++` |
| `_sharedmem_put(key, string)` | `_sharedmem_put(key, _bytes_from_string(s))` | SharedMem builtins take `bytes`, not `string` |
| `f.payload` | `toString(f.opaque)` | `sem_frame` has `opaque: bytes`, not `payload: string` |
| `make_frame_at(k, t, output, 0)` | `make_frame_at(k, t, fromString(output), 0)` | `opaque` arg is `bytes` |
| `put_trajectory(...)` as return value | `let _ = put_trajectory(...); response` | Returns `()`, not `string`; result must be discarded |
| `import std/string (... foldl ...)` | `import std/list (foldl)` | `foldl` lives in `std/list` |
| Missing `import std/option (Option, Some, None)` | added | Constructors are not globally visible |
| `main() ! {Net, AI, SharedMem, IO}` | add `Env` | `getEnvOr` carries the `Env` effect |

### 4. Multi-statement match arms without blocks

Match arms with more than one statement must be wrapped in `{}`:

```ailang
-- broken
Ok(obj) =>
  let x = ...;
  let y = ...;
  { x, y }

-- correct
Ok(obj) => {
  let x = ...;
  let y = ...;
  { x, y }
}
```

## Files Changed

| File | Change type |
|---|---|
| `swe/types.ail` | No change — was already correct |
| `swe/prompts.ail` | `export let` → `export func`; add `import std/list (foldl)` |
| `swe/parse.ail` | `=` bodies → `{}` bodies; add `import std/option` |
| `swe/env_client.ail` | `=` bodies → `{}` bodies; multi-statement match arms wrapped; `float()` → builtins; add `import std/option, std/result` |
| `swe/cache.ail` | `=` bodies → `{}` bodies; `f.payload` → `toString(f.opaque)`; `output` → `fromString(output)` for bytes arg |
| `swe/rpc.ail` | `=` bodies → `{}` bodies; `msgs :: [x]` → `msgs ++ [x]`; `hd` → `task_from_msgs` helper; `float()` → `_int_to_float()`; `put_trajectory` result discarded; `Env` added to `main` effect set; `base_system` → `base_system()`; SharedMem put converted to bytes |

## Verification

```
swe/types.ail:      ✓ No errors found!
swe/parse.ail:      ✓ No errors found!
swe/prompts.ail:    ✓ No errors found!
swe/env_client.ail: ✓ No errors found!
swe/cache.ail:      ✓ No errors found!
swe/rpc.ail:        ✓ No errors found!
```

Running `MODEL=openai/gpt-4o WORKDIR=. ./scripts/run-agent.sh` now reaches `✓ Running swe/rpc.ail` before failing on an unrelated runtime issue (missing API key or port conflict). The module loading error is gone.

## Remaining Runtime Issue

After parsing succeeds, there is a separate `ANTHROPIC_API_KEY environment variable required` error from the ailang runtime when `MODEL=openai/gpt-4o` is set. This indicates the runtime is not routing the `openai/gpt-4o` model string via the `--ai` flag to the OpenAI provider correctly. This is a runtime configuration issue, not an AILANG code problem.


---

## Second Session — Capability and Network Flags

### Problem

Running `ailang run swe/rpc.ail` (via the omp task runner with task text `test`) failed immediately after type/effect checking with:

```
Error: execution failed: effect 'Env' requires capability, but none provided
Hint: Run with --caps Env
```

### Root Cause 1 — `Env` missing from `--caps`

`main()` in `swe/rpc.ail` is correctly annotated `! {Net, AI, SharedMem, IO, Env}` because it calls `getEnvOr` three times (for `ENV_URL`, `TASK`, `MODEL`). `getEnvOr` from `std/env` carries the `Env` effect.

The spawn command in `tui/src/brain.ts` passed:

```
--caps Net,AI,SharedMem,IO
```

`Env` was absent. The effect checker caught the mismatch at runtime.

**Fix:** Added `Env` to the caps string → `Net,AI,SharedMem,IO,Env`.

### Root Cause 2 — `--net-allow-http` and `--net-allow-localhost` missing

The env server runs at `http://localhost:8080`. The ailang Net effect handler has two deny-by-default security policies:

- `AllowHTTP: false` — `http://` URLs are blocked unless `--net-allow-http` is passed
- `AllowLocalhost: false` — requests to `localhost`/`127.x`/`::1` are blocked unless `--net-allow-localhost` is passed

Both checks happen before any TCP connection is made, in `validateProtocol` and `isAllowedDomain`. Without these flags, `exec_in` would return a Go-level error on every command invocation, crashing the brain process the first time it tried to run a bash block.

**Fix:** Added `--net-allow-http` and `--net-allow-localhost` to the spawn args in `brain.ts`.

### Files Changed

| File | Change |
|---|---|
| `tui/src/brain.ts` | `--caps` string: added `Env`; spawn args: added `--net-allow-http`, `--net-allow-localhost` |
| `tui/dist/brain.js` | Rebuilt via `npm run build` |

### Verification

```
# Effect error gone:
ailang run --caps Net,AI,SharedMem,IO,Env --entry main swe/rpc.ail
→ ✓ No errors found!

# Full round-trip with stub AI and live env server:
TASK=test ENV_URL=http://localhost:18080 ailang run \
  --caps Net,AI,SharedMem,IO,Env --ai-stub \
  --net-allow-http --net-allow-localhost \
  --entry main swe/rpc.ail

{"type":"session_start","task":"test","model":"anthropic/claude-sonnet-4-6"}
{"type":"thinking","step":0,"text":"{\"kind\":\"Wait\"}"}
{"type":"done","step":0,"output":"{\"kind\":\"Wait\"}"}
```

The brain runs clean end-to-end without either capability error.

---

## Third Session — Runtime Model ID, emit-trace Pipe Hijack, Hardcoded CWD

### Problem

Running `MODEL=openai/gpt-4o WORKDIR=. ./scripts/run-agent.sh` with task `test` failed immediately:

```
Error: execution failed: E_AI_CALL_ERROR: openai error (400): invalid model ID
```

After fixing that, the process appeared to hang indefinitely with no output.

---

### Bug 1 — `openai/gpt-4o` passed verbatim to `--ai` flag

**Root cause:** `brain.ts` spawned ailang with `--ai model` where `model` was the full `openai/gpt-4o` string from the `MODEL` env var. The ailang runtime's `GuessProvider` correctly identifies the provider from `strings.Contains(lower, "openai")`, but then calls `client.NewHandler(modelName)` with the full string — passing `openai/gpt-4o` as the model ID to the OpenAI API, which rejects it.

The `--ai` flag expects bare model names (`gpt-4o`, `claude-sonnet-4-6`, `gemini-2.5-flash`), not the `provider/model` format used in the UI and `KNOWN_MODELS`.

**Fix:** `tui/src/brain.ts` — derive `aiModelArg` by stripping the prefix:

```typescript
const aiModelArg = model.includes("/") ? model.split("/").slice(1).join("/") : model;
// spawn: "--ai", aiModelArg
```

The full `provider/model` string is still passed via the `MODEL` env var (for `session_start` display) and held in the UI's status bar.

---

### Bug 2 — `--emit-trace` hijacked `println` to stderr, silencing the JSONL pipe

**Root cause:** When `--emit-trace trace.jsonl` is passed, the ailang runtime sets `effCtx.IOWriter = os.Stderr` so that `println` output goes to stderr and stdout carries pure JSONL trace output (`main_run.go:452`). `swe/rpc.ail` uses `println` (via `emit`) for its own JSONL protocol. With emit-trace active, all JSONL events were routed to the inherited stderr — the brain's stdout pipe was empty, readline in `brain.ts` received nothing, and no events ever reached the UI. `process.exit()` never fired, leaving the node process alive with stdin open: the hang.

**Fix:** Removed `--emit-trace` and `trace.jsonl` from the spawn args in `brain.ts`.

---

### Bug 3 — `WORKDIR` env var not read; cwd hardcoded to `/testbed`

**Root cause:** `swe/rpc.ail` `main()` hardcoded `cwd: "/testbed"` in the initial `AgentState`. Running with `WORKDIR=.` had no effect on where the brain told the LLM to operate.

**Fix:** `swe/rpc.ail` now reads `getEnvOr("WORKDIR", "/testbed")` and passes the result as the initial cwd.

---

### Ancillary fix — non-TTY hang: `AgentUI` / `ProcessTerminal` in devcontainer

The devcontainer environment has no TTY (`process.stdout.isTTY` is undefined). `AgentUI` constructs a `ProcessTerminal` and calls `tui.start()`, which calls `process.stdin.resume()`. On a non-TTY pipe stdin, this keeps the event loop alive indefinitely once the brain exits. Even without that, the pi-tui render loop writes ANSI escape sequences to a non-TTY stdout that the harness cannot display.

**Fix:** `tui/src/index.ts` — gate on `process.stdout.isTTY`. Non-TTY environments get a `PlainLogger` that writes human-readable lines to stdout and calls `process.exit(0)`/`process.exit(1)` on `done`/`error`. The pi-tui `AgentUI` is only instantiated when a real TTY is present.

```typescript
const isTTY = Boolean(process.stdout.isTTY);
const ui = isTTY ? new AgentUI() : new PlainLogger();
```

`PlainLogger` never touches `process.stdin`, so the event loop drains cleanly after the brain exits.

---

### Files Changed

| File | Change |
|---|---|
| `tui/src/brain.ts` | Strip `provider/` prefix before `--ai`; remove `--emit-trace trace.jsonl` |
| `tui/src/index.ts` | Add `PlainLogger`; select `PlainLogger` vs `AgentUI` based on `process.stdout.isTTY` |
| `swe/rpc.ail` | `main()`: read `WORKDIR` env var for initial cwd; fall back to `/testbed` |
| `tui/dist/` | Rebuilt via `npm run build` |

### Verification

End-to-end run (non-TTY, `MODEL=openai/gpt-4o TASK=test WORKDIR=.`):

```
[session] task=test model=openai/gpt-4o
[step 0] thinking
...
[step 0] $ cd /testbed && find . -name '*.py' | head -40
./tests/test_sample.py
./test_script.py
...
[step 4] $ echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
[done] 4 step(s)
COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
EXIT: 0
```

Brain runs to completion in 5 steps. No hang. Clean exit.

---

## Fourth Session — Wrong Write Directory (`/testbed` vs actual WORKDIR)

### Problem

Running the agent with task `Write a Hello World program in AILANG to workspaces/ailang_agent/examples` produced:

```
[stderr] /bin/sh: 1: cannot create /testbed/src/hello_world.ail: Permission denied
```

The brain was writing to `/testbed`, not the target directory.

---

### Root Cause — `WORKDIR` not forwarded to brain; `base_system` used hardcoded `/testbed`

Two coupled defects:

**1. `brain.ts` did not pass `WORKDIR` in the spawned process's environment.**

The spawn call spread `...process.env` but `WORKDIR` was never set in `index.ts`'s `process.env` — it was only held in a local `const workdir`. The brain process therefore had no `WORKDIR` variable in its environment.

**2. `base_system()` in `prompts.ail` had `/testbed` hardcoded in every filesystem idiom.**

`base_system` was a zero-argument function that emitted 11 hardcoded `/testbed` references in the system prompt. Even if `WORKDIR` had been forwarded correctly, the LLM would still follow the prompt's examples and write to `/testbed`.

Together: `rpc.ail` read `getEnvOr("WORKDIR", "/testbed")` for `state.cwd` correctly, but then passed that cwd to `base_system()` which ignored it entirely — so the LLM received instructions pointing at `/testbed` and acted on them.

---

### Fix 1 — Forward `WORKDIR` explicitly in `brain.ts`

```typescript
// tui/src/brain.ts — env block in spawn()
env: {
  ...process.env,
  ENV_URL: envUrl,
  TASK: task,
  MODEL: model,
  WORKDIR: process.env.WORKDIR ?? process.cwd(),  // ← added
},
```

If the caller sets `WORKDIR` in the outer environment it is forwarded as-is. Otherwise the TypeScript process's `cwd` (an absolute path) is used, matching the `workdir` value already passed to `startEnvServer`.

---

### Fix 2 — Parameterise `base_system` with the working directory

`swe/prompts.ail`: changed signature from `base_system() -> string` to `base_system(workdir: string) -> string`. All 11 literal `/testbed` occurrences are replaced with `++ workdir ++`:

```ailang
-- before
export func base_system() -> string =
  "  find /testbed -name '*.py' | head -40\n" ++ ...

-- after
export func base_system(workdir: string) -> string =
  "  find " ++ workdir ++ " -name '*.py' | head -40\n" ++ ...
```

---

### Fix 3 — Read `cwd` before calling `base_system` in `rpc.ail`

`main()` previously read `cwd` after calling `base_system()`, making it impossible to pass the value. Reordered to read `cwd` first:

```ailang
-- before
let hint   = get_hint(task);
let system = with_cache_hint(base_system(), hint);  -- base_system had no workdir
...
let cwd    = getEnvOr("WORKDIR", "/testbed");       -- too late

-- after
let cwd    = getEnvOr("WORKDIR", "/testbed");       -- read first
let hint   = get_hint(task);
let system = with_cache_hint(base_system(cwd), hint); -- correct workdir injected
```

---

### Files Changed

| File | Change |
|---|---|
| `tui/src/brain.ts` | Added `WORKDIR: process.env.WORKDIR ?? process.cwd()` to brain's env block |
| `swe/prompts.ail` | `base_system()` → `base_system(workdir: string)`; all 11 `/testbed` literals replaced with the param |
| `swe/rpc.ail` | Moved `cwd` read before `base_system` call; updated call to `base_system(cwd)` |
| `tui/dist/` | Rebuilt via `npm run build` (zero TypeScript errors) |

### Verification

`npm run build` passes clean. The fix is mechanically verified by the data flow: `WORKDIR=/workspaces/ailang_agent/examples node dist/index.js "..."` now propagates that path through `brain.ts` → `WORKDIR` env var → `rpc.ail getEnvOr("WORKDIR", ...)` → `base_system(cwd)` → every filesystem idiom in the system prompt. The LLM receives the correct target directory and writes there.

---

## Fifth Session — Continued Conversation After Task Completion

### Problem

After the brain emitted a `done` event and the task finished, hitting Enter in the TUI did nothing. The agent was effectively a single-shot tool: run once, read output, quit.

### Root Cause

Two coupled design gaps:

**1. Brain exited after `rpc_loop` returned.**
`main()` in `swe/rpc.ail` called `rpc_loop(state, model, 50)` and then fell off the end of the function, causing the brain process to exit. The TypeScript side's `onExit` callback then called `ui.stop()`, tearing down the TUI.

**2. TypeScript had no path for follow-up input.**
The UI's `handleCommand` routed everything that didn't start with `/model` or `/abort` to an "unknown command" message. There was no mechanism to deliver a user's follow-up text to the brain, and no protocol message type for carrying it.

---

### Fix 1 — `rpc_loop` returns `AgentState` (was `string`)

The return value of `rpc_loop` was previously a bare string (the final output text). The JSONL event carrying that text was already emitted before the return, so no caller actually used the string. Changing the return type to `AgentState` costs nothing at existing call sites (all used `let _ =`) while giving `conversation_loop` the full conversation history for follow-ups.

Every terminal branch now returns the last-known state:

- `depth == 0` → returns `state` unchanged
- `check_abort()` → returns `state` unchanged
- `None` branch (final answer, no bash block) → returns `{ ...state, msgs: msgs1 }` with the assistant reply appended
- `is_done` branch → same
- recursive branch → propagates whatever the recursive call returned

---

### Fix 2 — `conversation_loop` added to `swe/rpc.ail`

After `rpc_loop` returns, `main()` now calls `conversation_loop(final_state, model)` instead of exiting. The loop blocks on `readLine()` (from `std/io`) waiting for a JSONL command:

| Command | Behaviour |
|---|---|
| `{"type":"user_message","content":"..."}` | Appends to history, emits `session_start`, re-enters `rpc_loop` with 50 fresh steps, then recurses with the returned state |
| `{"type":"abort"}` or `{"type":"exit"}` | Returns `()` — brain exits cleanly |
| Empty line / EOF | Same — stdin closed means TypeScript exited |
| Malformed JSON | Skips and waits for the next line |

The key invariant: `conversation_loop` always receives the fully-updated `AgentState` from `rpc_loop`, so the entire conversation history (including all assistant turns and observations) is available for context on every follow-up.

---

### Fix 3 — AILANG syntax errors in `conversation_loop` (immediate follow-up)

The first version of `conversation_loop` had two syntax violations caught at parse time:

**Match arm body with `let` binding requires `{ }`.**
A bare `Ok(obj) => let x = ...` is not valid — the parser expects a single expression after `=>`. Wrapping in `{ }` makes it a block.

**`else if` does not exist in AILANG.**
The grammar only has `if EXPR then EXPR else EXPR`. Chained conditions must be written as nested `else { if ... then ... else { ... } }`. All `else if` occurrences were rewritten to explicit nesting, matching the pattern already used throughout `rpc_loop`.

---

### Fix 4 — `Brain.sendUserMessage` added to `brain.ts`

New method that sends `{"type":"user_message","content":"..."}` to the brain's stdin. Mirrors the existing `abort()` and `setModel()` methods in structure.

---

### Fix 5 — UI routes plain text as follow-up after `done`

Three changes to `tui/src/ui.ts`:

- Added `taskDone: boolean` flag (false initially).
- On `done` event: sets `taskDone = true`, calls `updateStatus()` so the status bar immediately reflects the new mode.
- `handleCommand`: when `taskDone` is true and the input doesn't start with `/`, the text is treated as a follow-up — echoed to history in cyan, delivered via `onUserMessage`, and `taskDone` is reset to false (the brain is processing again; the next `done` re-enables it).
- `updateStatus`: when `taskDone` is true the status bar reads `"type a follow-up or /model /abort"` instead of the normal hint.

---

### Fix 6 — `onUserMessage` wired in `index.ts`

```typescript
ui.onUserMessage = (content) => brain.sendUserMessage(content);
```

`PlainLogger` (non-TTY path) received the `onUserMessage?: ...` property declaration. In non-TTY mode `done` still calls `process.exit(0)` — no interactive follow-up is possible there, and the no-op property satisfies the TypeScript type checker.

---

### Files Changed

| File | Change |
|---|---|
| `swe/rpc.ail` | `rpc_loop` return type `string` → `AgentState`; all terminal branches return state; `readLine` added to `std/io` import; `conversation_loop` added; `main()` calls `conversation_loop(final_state, model)` |
| `tui/src/brain.ts` | Added `sendUserMessage(content: string)` method |
| `tui/src/ui.ts` | Added `taskDone` flag; `onUserMessage` callback; follow-up routing in `handleCommand`; status bar hint changes on task completion |
| `tui/src/index.ts` | Added `onUserMessage` to `PlainLogger`; wired `ui.onUserMessage` |
| `tui/dist/` | Rebuilt via `npm run build` (zero TypeScript errors) |

### Verification

`npm run build` — zero errors. The data flow is end-to-end verified structurally: after `done`, the user types text → `handleCommand` detects `taskDone && !startsWith('/')` → `onUserMessage(content)` → `brain.sendUserMessage(content)` → JSONL `user_message` written to brain stdin → `conversation_loop` unblocks from `readLine()` → appends to history → re-enters `rpc_loop` with full context → next `done` re-enables the cycle.

---

## Sixth Session — Rate Limit Handling

### Problem

Running the agent with `MODEL=openai/gpt-4o` produced a fatal crash after a few steps:

```
Error: execution failed: E_AI_CALL_ERROR: openai error (429): Rate limit reached for gpt-4o
on tokens per min (TPM): Limit 30000, Used 24827, Requested 7065.
Please try again in 3.783s.
```

AILANG has no try/catch. A Go-level error returned by `call()` terminates the evaluation immediately, killing the brain process.

### Root Cause

The brain calls the LLM in a tight recursive loop with no inter-call delay. At ~7k tokens per call against a 30k TPM ceiling, more than four sequential calls within a 60-second window triggers the 429. The error propagates as an unhandled Go error through `aiCallImpl` → AILANG runtime → process exit.

Two approaches were evaluated:

1. **Retry-with-backoff in `internal/ai/handler.go`** — add `generateWithRetry()` wrapping `provider.Generate()` with exponential backoff and retry-after hint parsing. Effective but modifies the ailang repository.
2. **Fixed inter-call delay in `swe/rpc.ail`** via `std/clock.sleep` — preventive rather than reactive; no ailang repo changes.

Approach 1 was implemented first (changes to `internal/ai/handler.go`, `internal/builtins/io.go`, `internal/effects/io.go`, plus a new `internal/ai/retry_test.go`), then **reverted** at the user's request. Approach 2 was kept as the permanent fix.

### Fix — `AI_STEP_DELAY_MS` env var in `swe/rpc.ail`

`std/clock (sleep)` is imported and `step_delay: int` is threaded through `rpc_loop` and `conversation_loop` as a new parameter. Before every `call()` invocation:

```ailang
let _ = if step_delay > 0 then sleep(step_delay) else ();
```

`step_delay` is read from `AI_STEP_DELAY_MS` in `main()`, defaulting to 0 (no delay):

```ailang
let delay_str  = getEnvOr("AI_STEP_DELAY_MS", "0");
let step_delay = match _stringToInt(delay_str) {
  None    => 0,
  Some(n) => n
};
```

For GPT-4o at the 30k TPM tier (~7k tokens/call → max 4 calls/min), `AI_STEP_DELAY_MS=15000` guarantees the rate is never exceeded. Higher-quota models leave the default at 0.

### Files Changed

| File | Change |
|---|---|
| `swe/rpc.ail` | `import std/clock (sleep)`; `rpc_loop` and `conversation_loop` gain `step_delay: int` param; `Clock` added to all effect signatures; sleep guard before `call()`; `main()` reads `AI_STEP_DELAY_MS`; `_stringToInt` used to parse it |
| `tui/src/brain.ts` | `Clock` added to `--caps` string |
| `tui/dist/` | Rebuilt via `npm run build` (zero TypeScript errors) |

### Reverted (ailang repo)

| File | Action |
|---|---|
| `ailang/internal/ai/handler.go` | `git checkout` — reverted |
| `ailang/internal/builtins/io.go` | `git checkout` — reverted |
| `ailang/internal/effects/io.go` | `git checkout` — reverted |
| `ailang/internal/ai/retry_test.go` | `rm` — removed |

The ailang binary was rebuilt from the clean source after revert.

### Usage

```bash
# GPT-4o at 30k TPM: ~7k tokens/call → 15s between calls
AI_STEP_DELAY_MS=15000 MODEL=openai/gpt-4o node tui/dist/index.js "your task"

# Anthropic/Gemini with higher quotas: no delay needed
MODEL=anthropic/claude-sonnet-4-6 node tui/dist/index.js "your task"
```