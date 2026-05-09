# AILANG SWE-Agent: Path 3 Implementation Plan

**AILANG Brain + pi-tui TypeScript Frontend + Yolo Mode + Option D Model Selection**

## Important
AILANG references:

- https://ailang.sunholo.com/llms.txt
- https://github.com/sunholo-data/ailang

Be sure to read these references first!


---

> **Key decisions in this revision**
>
> The agent always runs in yolo mode — no confirm/reject/human flow required, which significantly simplifies both the AILANG brain and the TypeScript frontend. Model selection uses Option D: a new `call_with(model, prompt)` builtin reads the current model from SharedMem, so `/model` in the TUI switches provider mid-session without restarting the brain. The `call_with` builtin is the only runtime change needed and is deferred to the final optional phase. Until then, a simple fallback reads the model from an environment variable, preserving all AILANG AI-effect guarantees throughout.

## Phase Summary

| Phase | Component | Effort | Notes |
|---|---|---|---|
| 0 | TypeScript project scaffold | 0.5 days | tui/ package, deps, build |
| 1 | Environment server (TypeScript) | 1 day | Replaces Python; runs inside tui/ |
| 2 | AILANG brain modules | 2–3 days | types, parse, prompts, env_client, cache |
| 2b | swe/rpc.ail — yolo brain | 0.5 days | Simplified: no mode logic |
| 2c | tui/src/index.ts — pi-tui frontend | 1–2 days | /model overlay, streaming render |
| 3 | SharedMem cache layer | 1 day | Unchanged from original plan |
| 4 | Test harness | 1.5–2 days | Unit + integration + JSONL protocol |
| 5 (opt) | call_with builtin + streaming | 2–3 days | Option D full implementation |
| 6 (opt) | MCP upgrade | 1–2 days | If richer tool semantics needed |
| **Total (phases 0–4)** | | **7–10 days** | |

---

## 1  Architecture Overview

Three processes, two protocols. The TypeScript process owns the terminal and the environment server. The AILANG brain is a child process communicating over JSONL on stdin/stdout. The environment server is embedded in the TypeScript process — no Python dependency.

| TypeScript process | AILANG brain process |
|---|---|
| pi-tui: differential terminal rendering | Effect signature: `! {Net, AI, SharedMem, IO}` |
| Environment server: POST /exec (express) | Always yolo — execute every proposed command immediately |
| Model registry: `currentModel` variable | `std/ai (call)` with `--ai` flag (phases 0–4) |
| `/model` command → writes to SharedMem config key | `call_with(model, prompt)` reads config key (phase 5) |
| Streams tokens to Markdown component | Emits JSONL events; reads JSONL commands |
| Catches SIGINT → sends `{"type":"abort"}` | Exits cleanly on abort; trace written to disk |

```
┌──────────────────────────────────────────────────────────────┐
│  TypeScript process (node tui/dist/index.js "task text")     │
│                                                              │
│  ┌─────────────────────┐   ┌──────────────────────────────┐  │
│  │   pi-tui UI         │   │  Environment server          │  │
│  │   Markdown, Text,   │   │  POST /exec  :8080           │  │
│  │   SelectList        │   │  POST /snapshot              │  │
│  │   /model overlay    │   │  POST /restore               │  │
│  └──────────┬──────────┘   └──────────────────────────────┘  │
└─────────────┼────────────────────────────────────────────────┘
              │  JSONL over stdin / stdout
┌─────────────┴────────────────────────────────────────────────┐
│  AILANG brain  (ailang run --caps Net,AI,SharedMem,IO ...)   │
│  swe/rpc.ail — always yolo                                   │
│  Reads ENV_URL, MODEL env vars                               │
│  Writes JSONL events to stdout                               │
│  Reads JSONL commands from stdin                             │
└──────────────────────────────────────────────────────────────┘
```

---

## 2  JSONL Protocol

Deliberately minimal. AILANG writes events to stdout; TypeScript writes commands to AILANG stdin. All records are newline-delimited JSON. Split on `\n` only — never on Unicode line separators.

### 2.1  AILANG → TypeScript (events)

| Event type | Key fields | When emitted |
|---|---|---|
| `session_start` | task, model | Once at startup |
| `thinking` | step, text | Full LLM response text before bash block |
| `proposed_cmd` | step, cmd | Bash block extracted; about to execute |
| `obs` | step, cmd, stdout, stderr, exit_code | After environment server returns |
| `done` | step, output | Sentinel detected in stdout |
| `error` | message | Step limit, parse failure, or abort |

### 2.2  TypeScript → AILANG (commands)

In yolo mode the brain never pauses for user input, so the only commands TypeScript needs to send are model changes and abort. Both are handled asynchronously — the brain checks for a pending command at the top of each loop iteration.

| Command type | Key fields | Effect |
|---|---|---|
| `abort` | — | Brain exits after current obs; trace saved |
| `model_change` | model (provider/name string) | Brain updates SharedMem config key; used from next LLM call |

> Because the brain is always yolo, it never blocks waiting for stdin between steps. Commands are buffered on stdin and consumed at the top of each loop iteration. This avoids any need for async stdin reading in AILANG.

---

## 3  AILANG Brain Modules

### 3.1  swe/types.ail

The `Mode` ADT is removed entirely. `AgentState` no longer carries a mode field.

```ailang
-- swe/types.ail
module swe/types

export type Msg = { role: string, content: string }

export type ExecResult = {
  stdout:    string,
  stderr:    string,
  exit_code: int
}

-- No Mode type — agent is always yolo
export type AgentState = {
  env_url: string,
  msgs:    [Msg],
  cwd:     string,
  step:    int
}

export type StepOutcome
  = Continue(AgentState)
  | Done(string)
  | LimitReached
  | ParseFailed(string)
  | Aborted
```

### 3.2  swe/prompts.ail

All file access, editing, and execution in the agent goes through bash commands sent to the env server — there is no native filesystem API available to the LLM. The system prompt must make this explicit and provide concrete bash idioms for every common operation.

```ailang
-- swe/prompts.ail
module swe/prompts

import swe/types (Msg)

-- Base system prompt: bash-only, no native file API
export let base_system =
  "You are a software engineering agent running in a bash environment." ++
  " Each response must contain exactly ONE bash code block." ++
  " Include your reasoning before the block." ++
  " Every command runs in a fresh subshell." ++
  " Prefix with your working directory: cd /testbed && your_command\n" ++
  "\n## All file and repo access goes through bash\n" ++
  "There is no native file API. Use these patterns:\n" ++
  "\n### List files\n" ++
  "  find /testbed -name '*.py' | head -40\n" ++
  "  ls -la /testbed/src/\n" ++
  "  find /testbed -type f -name '*.py' | xargs grep -l 'def parse'\n" ++
  "\n### Read a file\n" ++
  "  cat /testbed/src/utils.py\n" ++
  "  head -n 50 /testbed/src/utils.py\n" ++
  "  nl -ba /testbed/src/utils.py | sed -n '10,30p'\n" ++
  "\n### Search within files\n" ++
  "  grep -n 'pattern' /testbed/src/utils.py\n" ++
  "  grep -rn 'pattern' /testbed/src/\n" ++
  "\n### Edit a file\n" ++
  "  sed -i 's/old_string/new_string/g' /testbed/src/utils.py\n" ++
  "  sed -i '10s/.*/replacement line/' /testbed/src/utils.py\n" ++
  "\n### Create or overwrite a file\n" ++
  "  cat <<'EOF' > /testbed/src/newfile.py\n" ++
  "  # file content here\n  EOF\n" ++
  "\n### Run tests\n" ++
  "  cd /testbed && python -m pytest tests/ -x -q\n" ++
  "  cd /testbed && python -m pytest tests/test_utils.py::test_parse -v\n" ++
  "\n### Inspect git state\n" ++
  "  git -C /testbed diff\n" ++
  "  git -C /testbed log --oneline -5\n" ++
  "\n### Reproduce an issue\n" ++
  "  cd /testbed && python -c 'from src.utils import parse; print(parse(\"test\"))'\n" ++
  "\n## Recommended workflow\n" ++
  "1. Find and read relevant files\n" ++
  "2. Create a script to reproduce the issue\n" ++
  "3. Edit source files to fix it\n" ++
  "4. Verify the fix by running your reproduction script and tests\n" ++
  "5. When done, submit with this command on its own line:\n" ++
  "   echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT\n" ++
  "   Do not combine this with any other command.\n"

-- Inject a cached trajectory hint when available
export func with_cache_hint(system: string, hint: string) -> string =
  if hint == "" then system
  else system ++ "\n## A similar issue was previously resolved\n" ++ hint

-- Format full message history for LLM context
export func fmt_msgs(msgs: [Msg]) -> string =
  foldl(\acc, m. acc ++ "[" ++ m.role ++ "]\n" ++ m.content ++ "\n\n",
        "", msgs)

-- Format an exec result as an observation string
export func fmt_obs(cmd: string, r: ExecResult) -> string =
  "$ " ++ cmd ++
  "\n[exit " ++ show(r.exit_code) ++ "]\n" ++
  r.stdout ++
  (if r.stderr == "" then ""
   else "\n[stderr]\n" ++ r.stderr)
```

> The bash idiom examples in `base_system` are not exhaustive — they establish the pattern. The LLM will generalise to other bash commands (`awk`, `wc`, `diff`, `git blame`, `python -c`, etc.) once it understands that bash is the only interface available. Keep examples concrete and copy-pasteable.

### 3.3  swe/rpc.ail — the simplified yolo brain

The absence of confirm/reject/human modes reduces this module to its essential logic: emit, execute, emit observation, recurse. The only stdin read is the non-blocking abort/model_change check at the top of each iteration.

```ailang
-- swe/rpc.ail
module swe/rpc

import std/ai     (call)
import std/io     (println, readLine)
import std/json   (encode, decode, jo, kv, js, jnum, get, asString)
import std/string (contains, trim)
import std/env    (getEnvOr)
import swe/types  (Msg, AgentState, StepOutcome,
                   Continue, Done, LimitReached, Aborted)
import swe/env_client (exec_in)
import swe/parse   (extract_bash, is_done, parse_cwd)
import swe/prompts (base_system, with_cache_hint, fmt_msgs, fmt_obs)
import swe/cache   (get_hint, put_trajectory)

-- Emit a JSONL event
func emit(obj: string) -> () ! {IO} = println(obj)

-- Check stdin for a pending command (non-blocking)
-- _io_poll_stdin is a builtin: returns "" if nothing ready
func poll_cmd() -> Option[string] ! {IO} =
  let line = _io_poll_stdin();
  if line == "" then None else Some(trim(line))

-- Check for an abort command on stdin
func check_abort() -> bool ! {IO} =
  match poll_cmd() {
    None      => false,
    Some(raw) => match decode(raw) {
      Err(_)  => false,
      Ok(obj) => get_str(obj, "type") == "abort"
    }
  }

-- Handle model_change if present; return updated model string
func check_model_change(current: string) -> string ! {IO, SharedMem} =
  match poll_cmd() {
    None      => current,
    Some(raw) => match decode(raw) {
      Err(_)  => current,
      Ok(obj) =>
        if get_str(obj, "type") == "model_change"
        then
          let new_model = get_str(obj, "model");
          -- Store in SharedMem so call_with can read it (Phase 5)
          let _ = store_config("current_model", new_model);
          new_model
        else current
    }
  }

-- Core recursive loop — always yolo
func rpc_loop(
  state: AgentState,
  model: string,
  depth: int
) -> string ! {Net, AI, SharedMem, IO} =
  if depth == 0 then
    let _ = emit(encode(jo([kv("type", js("error")),
                             kv("message", js("step limit reached"))])));
    "step limit reached"
  else
  -- Check for abort or model change before each step
  if check_abort() then
    let _ = emit(encode(jo([kv("type", js("error")),
                             kv("message", js("aborted"))])));
    "aborted"
  else
  let model2   = check_model_change(model);
  -- LLM call: std/ai (call) for phases 0-4; call_with for phase 5
  let response = call(fmt_msgs(state.msgs));
  let msgs1    = state.msgs :: [{ role: "assistant", content: response }];
  -- Emit full LLM response as thinking event
  let _ = emit(encode(jo([
    kv("type", js("thinking")),
    kv("step", jnum(float(state.step))),
    kv("text", js(response))])));
  match extract_bash(response) {
    None =>
      -- Final answer with no bash block
      let _ = emit(encode(jo([
        kv("type",   js("done")),
        kv("step",   jnum(float(state.step))),
        kv("output", js(response))])));
      put_trajectory(hd(state.msgs).content, response),
    Some(raw_cmd) =>
      -- Emit proposed_cmd then execute immediately (yolo)
      let _ = emit(encode(jo([
        kv("type", js("proposed_cmd")),
        kv("step", jnum(float(state.step))),
        kv("cmd",  js(raw_cmd))])));
      let cmd    = "cd " ++ state.cwd ++ " && " ++ raw_cmd;
      let result = exec_in(state.env_url, cmd, 30);
      let _ = emit(encode(jo([
        kv("type",      js("obs")),
        kv("step",      jnum(float(state.step))),
        kv("cmd",       js(raw_cmd)),
        kv("stdout",    js(result.stdout)),
        kv("stderr",    js(result.stderr)),
        kv("exit_code", jnum(float(result.exit_code)))])));
      if is_done(result.stdout)
      then
        let _ = emit(encode(jo([
          kv("type",   js("done")),
          kv("step",   jnum(float(state.step))),
          kv("output", js(result.stdout))])));
        put_trajectory(hd(state.msgs).content, result.stdout)
      else
        let msgs2 = msgs1 :: [{ role: "user",
                                content: fmt_obs(raw_cmd, result) }];
        rpc_loop({
          env_url: state.env_url, msgs: msgs2,
          cwd: parse_cwd(raw_cmd, state.cwd),
          step: state.step + 1
        }, model2, depth - 1)
  }

export func main() -> () ! {Net, AI, SharedMem, IO} {
  let env_url = getEnvOr("ENV_URL", "http://localhost:8080");
  let task    = getEnvOr("TASK",    "");
  let model   = getEnvOr("MODEL",   "claude-sonnet-4-6");
  let hint    = get_hint(task);
  let system  = with_cache_hint(base_system, hint);
  let init    = [{ role: "system", content: system },
                 { role: "user",   content: task }];
  let state   = { env_url: env_url, msgs: init,
                  cwd: "/testbed", step: 0 };
  let _ = emit(encode(jo([
    kv("type",  js("session_start")),
    kv("task",  js(task)),
    kv("model", js(model))])));
  rpc_loop(state, model, 50)
}
```

> `_io_poll_stdin` is a small new builtin (non-blocking stdin peek, returns `""` if nothing ready). About 10 lines in Go. It does not touch the effect system or type checker. It is the only runtime addition needed for phases 0–4.

---

## 4  TypeScript Frontend (tui/)

### 4.1  Project structure

```
tui/
├── package.json          ← deps: @mariozechner/pi-tui, express, typescript
├── tsconfig.json
├── src/
│   ├── index.ts          ← entry point, CLI args, wires everything together
│   ├── env-server.ts     ← express wrapper around child_process.execSync
│   ├── brain.ts          ← spawn + JSONL pipe to/from AILANG
│   ├── ui.ts             ← pi-tui layout: Editor (autocomplete), status bar, model overlay
│   ├── models.ts         ← known model list for /model SelectList
│   └── commands.ts       ← declarative SlashCommand[] registry (oh-my-pi pattern)
└── dist/                 ← compiled output
```

### 4.2  env-server.ts

The environment server is embedded in the TypeScript process. It replaces the Python server from the original plan.

```typescript
// tui/src/env-server.ts
import express from "express";
import { execSync } from "child_process";
import { randomBytes } from "crypto";

export function startEnvServer(port: number, workdir: string) {
  const app = express();
  app.use(express.json());
  const snapshots = new Map<string, string>();

  app.post("/exec", (req, res) => {
    const { cmd, timeout = 30 } = req.body;
    try {
      const stdout = execSync(cmd, {
        cwd: workdir, timeout: timeout * 1000,
        encoding: "utf8", maxBuffer: 8 * 1024 * 1024
      });
      res.json({ stdout: stdout.slice(0, 8000), stderr: "", exit_code: 0 });
    } catch (e: any) {
      res.json({
        stdout: String(e.stdout || "").slice(0, 8000),
        stderr: String(e.stderr || "").slice(0, 2000),
        exit_code: e.status ?? 1
      });
    }
  });

  app.post("/snapshot", (_req, res) => {
    try {
      execSync("git stash", { cwd: workdir });
      const id = randomBytes(4).toString("hex");
      snapshots.set(id, "stash@{0}");
      res.json({ snapshot_id: id });
    } catch { res.json({ snapshot_id: "none" }); }
  });

  app.post("/restore", (req, res) => {
    const ref = snapshots.get(req.body.snapshot_id) ?? "stash@{0}";
    try { execSync(`git stash pop ${ref}`, { cwd: workdir }); } catch {}
    res.json({ ok: true });
  });

  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  app.listen(port);
}
```

### 4.3  brain.ts — spawn and wire AILANG

```typescript
// tui/src/brain.ts
import { spawn, ChildProcess } from "child_process";
import * as readline from "readline";

export type AgentEvent =
  | { type: "session_start"; task: string; model: string }
  | { type: "thinking";     step: number; text: string }
  | { type: "proposed_cmd"; step: number; cmd: string }
  | { type: "obs";          step: number; cmd: string;
        stdout: string; stderr: string; exit_code: number }
  | { type: "done";  step: number; output: string }
  | { type: "error"; message: string };

export class Brain {
  private proc: ChildProcess;

  constructor(
    task: string, envUrl: string, model: string,
    onEvent: (e: AgentEvent) => void,
    onExit:  () => void
  ) {
    this.proc = spawn("ailang", [
      "run", "--caps", "Net,AI,SharedMem,IO",
      "--ai",   model,
      "--entry", "main",
      "--emit-trace", "trace.jsonl",
      "swe/rpc.ail"
    ], {
      env: { ...process.env, ENV_URL: envUrl, TASK: task, MODEL: model },
      stdio: ["pipe", "pipe", "inherit"]
    });

    const rl = readline.createInterface({ input: this.proc.stdout! });
    rl.on("line", line => {
      try { onEvent(JSON.parse(line) as AgentEvent); }
      catch { /* skip malformed */ }
    });
    this.proc.on("exit", onExit);
  }

  send(cmd: object) {
    this.proc.stdin?.write(JSON.stringify(cmd) + "\n");
  }

  abort() { this.send({ type: "abort" }); }

  setModel(model: string) {
    this.send({ type: "model_change", model });
  }
}
```

### 4.4  ui.ts — pi-tui layout

Three vertical regions: a scrollable history pane, a one-line status bar, and a one-line command input. The history renders LLM responses as Markdown and command output as plain text. The status bar shows step count and current model. The input handles `/model` and `/abort`.

```typescript
// tui/src/ui.ts
import { TUI, Text, Markdown, Input, Box,
         SelectList, ProcessTerminal } from "@mariozechner/pi-tui";
import type { AgentEvent } from "./brain.js";
import { KNOWN_MODELS } from "./models.js";

export class AgentUI {
  private tui:       TUI;
  private history:   Box;
  private statusBar: Text;
  private cmdInput:  Input;
  private step  = 0;
  private model = "";

  onModelChange?: (model: string) => void;
  onAbort?:       () => void;

  constructor() {
    const terminal = new ProcessTerminal();
    this.tui       = new TUI(terminal);
    this.history   = new Box({ scrollable: true, grow: true });
    this.statusBar = new Text("", { dim: true });
    this.cmdInput  = new Input({ placeholder: "/model  /abort" });

    this.tui.addChild(this.history);
    this.tui.addChild(this.statusBar);
    this.tui.addChild(this.cmdInput);

    this.cmdInput.onSubmit = (value: string) => {
      this.cmdInput.clear();
      this.handleCommand(value.trim());
    };

    process.on("SIGINT", () => this.onAbort?.());
    this.tui.start();
  }

  handleEvent(event: AgentEvent) {
    switch (event.type) {
      case "session_start":
        this.model = event.model;
        this.history.addChild(new Markdown(`## Task\n${event.task}\n`));
        break;
      case "thinking":
        this.step = event.step;
        this.history.addChild(new Markdown(event.text));
        break;
      case "proposed_cmd":
        this.history.addChild(new Text(
          `$ ${event.cmd}`, { bold: true, color: "cyan" }));
        break;
      case "obs":
        this.history.addChild(new Text(
          event.stdout,
          { dim: true, color: event.exit_code === 0 ? "default" : "red" }
        ));
        break;
      case "done":
        this.history.addChild(new Markdown(
          `## Done ✓\n_${event.step} steps_`));
        this.tui.setFocus(this.cmdInput);
        break;
      case "error":
        this.history.addChild(new Text(
          `Error: ${event.message}`, { color: "red" }));
        break;
    }
    this.updateStatus();
    this.tui.requestRender();
  }

  private handleCommand(value: string) {
    if (value === "/abort") {
      this.onAbort?.();
      return;
    }
    if (value.startsWith("/model")) {
      const parts = value.split(" ");
      if (parts.length >= 2) {
        this.switchModel(parts[1]);
      } else {
        this.showModelPicker();
      }
      return;
    }
    this.history.addChild(new Text(
      `Unknown command. Try /model or /abort`, { dim: true }));
    this.tui.requestRender();
  }

  private switchModel(model: string) {
    this.model = model;
    this.history.addChild(new Text(
      `Model → ${model}`, { color: "cyan", dim: true }));
    this.onModelChange?.(model);
    this.updateStatus();
    this.tui.requestRender();
  }

  private showModelPicker() {
    const list = new SelectList(KNOWN_MODELS, {
      onSelect: (model: string) => {
        this.tui.hideOverlay();
        this.switchModel(model);
      },
      onCancel: () => this.tui.hideOverlay()
    });
    this.tui.showOverlay(list, "center");
  }

  private updateStatus() {
    this.statusBar.setText(
      `[ailang-mini]  step ${this.step}  model: ${this.model}` +
      `  /model to switch  /abort to stop`
    );
  }

  stop() { this.tui.stop(); }
}
```

### 4.5  models.ts

```typescript
// tui/src/models.ts
export const KNOWN_MODELS = [
  "anthropic/claude-sonnet-4-6",
  "anthropic/claude-opus-4-6",
  "anthropic/claude-haiku-4-5",
  "openai/gpt-4o",
  "openai/gpt-4o-mini",
  "google/gemini-2.5-flash",
  "google/gemini-2.5-pro",
];
```

### 4.6  index.ts — entry point

```typescript
// tui/src/index.ts
import { startEnvServer } from "./env-server.js";
import { Brain }          from "./brain.js";
import { AgentUI }        from "./ui.js";

async function main() {
  const task    = process.argv[2] ?? await promptForTask();
  const model   = process.env.MODEL   ?? "anthropic/claude-sonnet-4-6";
  const envPort = Number(process.env.ENV_PORT ?? 8080);
  const workdir = process.env.WORKDIR  ?? process.cwd();

  startEnvServer(envPort, workdir);
  const envUrl = `http://localhost:${envPort}`;

  const ui = new AgentUI();
  let brain: Brain;

  function spawnBrain(m: string) {
    brain = new Brain(task, envUrl, m,
      event => ui.handleEvent(event),
      ()    => ui.stop()
    );
  }

  ui.onModelChange = (newModel) => brain.setModel(newModel);
  ui.onAbort       = ()         => brain.abort();

  spawnBrain(model);
}

async function promptForTask(): Promise<string> {
  process.stdout.write("Task: ");
  return new Promise(resolve => {
    process.stdin.once("data", d => resolve(d.toString().trim()));
  });
}

main();
```

### 4.7  Running

```bash
# Install deps
cd tui && npm install

# Build
npm run build

# Run against current directory
MODEL=anthropic/claude-sonnet-4-6 \
  WORKDIR=/path/to/repo \
  node dist/index.js "Fix the off-by-one in parse_config"

# Or prompt for task interactively
node dist/index.js

# While running:
#   /model                → opens SelectList picker
#   /model openai/gpt-4o  → switches immediately
#   /abort                → stops the brain cleanly
#   Ctrl+C                → same as /abort
```

---

## 5  Model Selection: Two Modes

### 5.1  Phases 0–4: model fixed at startup

In the initial implementation, when TypeScript sends a `model_change` command, the AILANG brain reads it from stdin and stores it in SharedMem via `store_config`. The current brain process still uses the original `--ai` flag for LLM calls — the new model takes effect on the next brain invocation. The TypeScript side tracks the current model for display purposes.

> **Known limitation (phases 0–4):** If the user changes model mid-session via `/model`, the change does not affect LLM calls in the current brain process. The status bar makes this visible. The new model is used if the brain is restarted.

### 5.2  Phase 5 (optional): mid-session switching via call_with

The full Option D implementation requires one new AILANG builtin and one line change in `swe/rpc.ail`.

#### New builtin: call_with

```ailang
-- call_with : string -> string -> string ! {AI}
--             model     prompt
--
-- Identical to call() but selects the provider/model at runtime.
-- Model string format: "provider/model-name"
-- e.g. "anthropic/claude-opus-4-6"  "openai/gpt-4o"
--
-- Go side (internal/builtins/registry.go):
-- ~20 lines following existing call() pattern,
-- parsing "provider/model" and constructing an API client
```

#### Change to swe/rpc.ail

One line changes in `rpc_loop`. The comment marks both versions:

```ailang
-- Phase 0–4 (current):
let response = call(fmt_msgs(state.msgs));

-- Phase 5 (after call_with builtin is implemented):
-- let response = call_with(model2, fmt_msgs(state.msgs));

-- To upgrade: swap the comment, rebuild. No other changes needed.
```

#### Effect signature after Phase 5

The `AI` effect is preserved throughout. `call_with` is still `! {AI}` — the model name is a runtime value but the capability declaration is unchanged. `--emit-trace`, `--ai-stub`, and M-EVAL integrations all continue to work.

---

## 6  What is Unchanged from the Original Plan

The following modules require no changes:

- `swe/env_client.ail` — HTTP client for environment server
- `swe/parse.ail` — `extract_bash`, `is_done`, `parse_cwd` (pure functions)
- `swe/cache.ail` — `get_hint`, `put_trajectory` (SharedMem layer)
- SharedMem namespace conventions and two-tier retrieval strategy
- Batch mode `swe/agent.ail` — unaffected; still uses `std/ai (call)` with `--ai` flag

---

## 7  Runtime Requirements

| Requirement | Phase | Effort | Notes |
|---|---|---|---|
| `_io_poll_stdin` builtin | 0–4 | ~1 hour | Non-blocking stdin peek, returns `""` if empty. ~10 lines Go. |
| `call_with(model, prompt)` builtin | 5 (opt) | 1–2 days | Parses `"provider/model"`, constructs API client at runtime. |
| Streaming variant (`stream_call_with`) | 5 (opt) | +1–2 days | Emits `token_delta` events to stdout during call. TypeScript renders in real time. |

> `_io_poll_stdin` is the only runtime requirement for phases 0–4. It does not touch the type checker, effect system, or evaluator. All other phases 0–4 work is pure AILANG code and TypeScript.

---

## 8  Build Order

Each step produces a working, independently testable artifact before the next begins.

1. Add `_io_poll_stdin` to Go runtime (~1 hour). Verify with `ailang repl` that `_io_poll_stdin()` returns `""` when stdin is empty.
2. Write and test `env-server.ts`. Run the four acceptance tests (echo, nonzero exit, timeout, snapshot/restore).
3. Write `swe/types.ail`, `swe/parse.ail`, `swe/env_client.ail`. Run `ailang check` and `ailang test` on each.
4. Write `swe/prompts.ail` and `swe/cache.ail`. Test cache independently with `ailang run --caps SharedMem`.
5. Write `swe/rpc.ail`. Test with mock env server and `--ai-stub`. Verify JSONL event stream is well-formed.
6. Write `tui/src/brain.ts` and wire to `swe/rpc.ail`. Verify JSONL events arrive and abort works.
7. Write `tui/src/ui.ts` with pi-tui. Run against real task. Verify `/model` overlay, status bar, Markdown rendering.
8. Write `tui/src/index.ts` entry point. Smoke test: full run on a real repo issue.
9. Run 10-issue SWE-bench sample. Target >50% pass rate as gate to proceed.
10. *(Optional Phase 5)* Implement `call_with` builtin. Swap one line in `swe/rpc.ail`. Verify mid-session `/model` switch takes effect immediately.
11. *(Optional Phase 5)* Implement streaming variant. Verify TypeScript renders token deltas in real time.
12. *(Optional Phase 6)* MCP upgrade to environment server, if richer tool semantics are needed.

---

## 9  Success Criteria by Phase

| Phase | Done when… | Validation |
|---|---|---|
| 0 | `npm run build` succeeds; `ProcessTerminal` renders text | Manual smoke test of pi-tui hello world |
| 1 | All 4 env-server acceptance tests pass | `npm test` in `tui/` |
| 2 | `ailang check swe/rpc.ail` exits 0 | `ailang check` on all `swe/*.ail`; `--ai-stub` integration test |
| 2c | `/model` opens picker; status bar shows model name | Manual TUI test; model name updates on switch |
| 3 | Second run on same issue injects cache hint | Log hint retrieval; confirm token reduction |
| 4 | >50% on 10-issue SWE-bench sample | Benchmark script; compare to mini-swe-agent baseline |
| 5 (opt) | `/model` mid-session uses new model on next LLM call | Switch model; confirm trace shows new model name |


---

## 10  Implementation Checklist

Ordered by Section 8 build sequence. Each item is independently testable before the next begins.

### Phase 0 — Scaffold
- [x] Create `tui/` package with `package.json`, `tsconfig.json`, deps (`@mariozechner/pi-tui`, `express`, `typescript`)
- [x] Confirm `npm run build` succeeds and `ProcessTerminal` renders text

### Phase 1 — Environment Server
- [x] Implement `tui/src/env-server.ts` (POST /exec, /snapshot, /restore, GET /health)
- [x] Acceptance test: echo command returns stdout + exit 0
- [x] Acceptance test: nonzero-exit command returns correct exit code
- [x] Acceptance test: timeout is enforced
- [x] Acceptance test: snapshot/restore round-trip via git stash

### Phase 2 — AILANG Brain Modules
- [x] Add `_io_poll_stdin` builtin to Go runtime (~10 lines); verify with `ailang repl`
- [x] Write `swe/types.ail` — `Msg`, `ExecResult`, `AgentState`, `StepOutcome`; run `ailang check`
- [x] Write `swe/parse.ail` — `extract_bash`, `is_done`, `parse_cwd`; run `ailang test`
- [x] Write `swe/env_client.ail` — `exec_in` HTTP client; run `ailang check`
- [x] Write `swe/prompts.ail` — `base_system`, `with_cache_hint`, `fmt_msgs`, `fmt_obs`; run `ailang check`
- [x] Write `swe/cache.ail` — `get_hint`, `put_trajectory`; test with `ailang run --caps SharedMem`

### Phase 2b — Yolo Brain
- [x] Write `swe/rpc.ail` — `rpc_loop`, `main`, `poll_cmd`, `check_abort`, `check_model_change`
- [x] Test with mock env server and `--ai-stub`; verify JSONL event stream is well-formed

### Phase 2c — TypeScript Frontend
- [x] Write `tui/src/brain.ts` — spawn AILANG process, wire JSONL pipe
- [x] Verify JSONL events arrive on `Brain` and abort command is delivered
- [x] Write `tui/src/models.ts` — `KNOWN_MODELS` list
- [x] Write `tui/src/ui.ts` — history box, status bar, `/model` overlay, `/abort` handler
- [x] Adopt oh-my-pi command pattern: declarative `SlashCommand[]` registry in `tui/src/commands.ts`
- [x] Replace `Input` with `Editor` component for slash-command tab-complete
- [x] Wire `ui.brain` property so registry dispatch can call `abort()` / log to history
- [x] Manual TUI test: `/model` opens SelectList picker; status bar updates on switch
- [x] Manual TUI test: `/` autocompletes to `/model` and `/abort` with tab
- [x] Write `tui/src/index.ts` — entry point, wires env server + brain + UI
- [ ] Smoke test: full run on a real repo issue
### Phase 3 — SharedMem Cache
- [x] Verify `swe/cache.ail` stores and retrieves trajectory hints across runs
- [x] Confirm second run on same issue injects cache hint; check token reduction in trace

### Phase 4 — Test Harness & Benchmark
- [ ] Write unit tests for `swe/parse.ail` (extract_bash edge cases, is_done sentinel)
- [ ] Write integration test: JSONL protocol contract between brain and TypeScript
- [ ] Run 10-issue SWE-bench sample; confirm >50% pass rate
- [ ] Compare against mini-swe-agent baseline

### Phase 5 (optional) — call_with + Streaming
- [ ] Implement `call_with(model, prompt)` builtin in `internal/builtins/registry.go`
- [ ] Swap one line in `swe/rpc.ail`: `call(...)` → `call_with(model2, ...)`
- [ ] Verify mid-session `/model` switch takes effect on next LLM call; check trace
- [ ] Implement `stream_call_with` streaming variant
- [ ] Verify TypeScript renders token deltas in real time

### Phase 6 (optional) — MCP Upgrade
- [ ] Evaluate whether richer tool semantics are needed after Phase 4 benchmark
- [ ] Upgrade environment server to MCP protocol if warranted
