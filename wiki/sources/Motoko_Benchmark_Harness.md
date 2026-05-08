# Motoko Benchmark Harness

**Adapt little-coder's benchmark system to evaluate Motoko against Aider Polyglot and Terminal-Bench.**

---

> **Key insight**: little-coder's benchmark system is a thin Python harness that
> (1) prepares exercise environments, (2) speaks JSONL to an agent subprocess,
> (3) runs language test suites, and (4) records pass/fail. The exercise prep,
> test runners, and scoring are agent-independent — only the RPC layer and
> subprocess spawn need to change. Motoko already speaks JSONL over stdin/stdout,
> so the translation is mechanical.

## Phase Summary

| Phase | Component | Effort | Notes |
|---|---|---|---|
| 0 | `MotokoRpc` + JSONL output mode | 1 day | RPC client + `JsonlLogger` in TUI |
| 1 | Aider Polyglot driver | 0.5 days | Fork `aider_polyglot.py`, swap RPC class |
| 2 | Terminal-Bench adapter | 1.5 days | Python HTTP sidecar proxying tmux commands |
| 3 | Configurable step budget + model | 0.5 days | Env-var overrides (mostly already done) |
| 4 | Result reporting + status scripts | 0.5 days | JSON results, shell status summaries |
| 5 | Smoke test + CI gate | 0.5 days | Pre-flight checks + end-to-end verify |
| **Total** | | **~4.5 days** | |

---

## Architecture

```
benchmarks/
├── motoko_rpc.py          ← Phase 0: MotokoRpc (replaces PiRpc)
├── smoke.py               ← Phase 5: quick end-to-end check
├── aider_polyglot.py      ← Phase 1: Polyglot runner
├── tb_adapter/
│   ├── motoko_agent.py    ← Phase 2: Terminal-Bench BaseAgent
│   └── shell_sidecar.py   ← Phase 2: HTTP sidecar for tmux proxy
├── harbor_adapter/
│   └── motoko_agent.py    ← Phase 2: Harbor adapter (stretch)
├── gaia_scorer.py         ← Copy from little-coder, reuse as-is
└── results/               ← Phase 4: output dir
```

The harness spawns Motoko in non-TTY mode and reads JSONL events.
`index.ts` already has a non-TTY code path (line 324) that uses
`PlainLogger` when `process.stdout.isTTY` is false. Since the Python
harness spawns Node as a subprocess (stdout is a pipe), this path
activates automatically — no `--headless` flag is needed.

The one change required: `PlainLogger` currently writes human-readable
text (`[step 3] $ echo hello`). We add a `MOTOKO_JSONL_OUTPUT=1` env
var that makes the non-TTY path write raw `JSON.stringify(event)` lines
instead, so the Python harness can parse structured events.

```
Python harness (benchmarks/)
│
├─ spawns ──► node src/tui/dist/index.js   (non-TTY auto-detected)
│              │     MOTOKO_JSONL_OUTPUT=1
│              │
│              ├── Env server  POST /exec :<dynamic port>
│              └── AILANG core  src/core/rpc.ail
│
├─ sends task via TASK env var at spawn time
├─ reads JSONL events from subprocess stdout
│   session_start → thinking → proposed_cmd → obs → ... → done/error
├─ runs language test suite (pytest, go test, cargo test, ...)
└─ records {status, elapsed_s, step_count} to results JSON
```

---

## Phase 0: `MotokoRpc` + JSONL output mode

**Goal**: A Python RPC client that spawns Motoko as a subprocess and reads
structured JSONL events, plus a small TUI change to emit raw JSON in
non-TTY mode.

### 0.1 JSONL output mode in `index.ts`

The non-TTY code path already exists (`index.ts:324`). When
`process.stdout.isTTY` is false, it uses `PlainLogger` which writes
human-readable text like `[step 3] $ echo hello`. The Python harness
needs structured JSON instead.

**Two changes required:**

**Change 1 — Suppress the banner.** Line 293 of `index.ts` writes the
ASCII art banner to `process.stdout` **unconditionally**, before the TTY
check. When `MOTOKO_JSONL_OUTPUT=1`, these non-JSON lines would corrupt
the JSONL stream. Gate the banner write:

```typescript
// index.ts ~line 292 — guard banner output
if (process.env.MOTOKO_JSONL_OUTPUT !== "1") {
  const bannerLines = renderBanner({ columns: process.stdout.columns });
  process.stdout.write(bannerLines.join("\n") + "\nMotoko ...\n\n");
}
```

**Change 2 — Add `JsonlLogger`.** A new class that writes one
`JSON.stringify(event)` line per event to stdout — the same `AgentEvent`
objects that `RuntimeProcess` already parses from the AILANG subprocess.

```typescript
class JsonlLogger {
  onModelChange?: (model: string) => void;
  onAbort?: () => void;
  onUserMessage?: (content: string) => void;

  handleEvent(event: AgentEvent): void {
    process.stdout.write(JSON.stringify(event) + "\n");
    if (event.type === "done" || event.type === "error") {
      process.exit(event.type === "done" ? 0 : 1);
    }
  }
  stop(): void {}
}

// In the non-TTY branch (index.ts ~line 324):
const ui = process.env.MOTOKO_JSONL_OUTPUT === "1"
  ? new JsonlLogger()
  : new PlainLogger();
```

Together these are ~20 lines of new code across two spots in `index.ts`.
The existing `RuntimeProcess` constructor, env server startup, and event
routing are untouched.

### 0.2 Protocol mapping

little-coder's `PiRpc` sends a `{"type": "prompt", "message": "..."}` and
drains events until `agent_end`. Motoko's protocol is different — the task
is passed via `TASK` env var at spawn time, and the runtime emits events
autonomously until `done` or `error`. There is no mid-session prompt injection.

| PiRpc concept | Motoko equivalent |
|---|---|
| `{"type": "prompt", "message": "..."}` | `TASK` env var at spawn |
| `agent_end` event | `done` or `error` event |
| `tool_execution_start/end` | `proposed_cmd` + `obs` pair |
| `tool_calls` / `tool_results` | `tool_calls` + `tool_results` events (delegated/hybrid tools) |
| `turn_end` | Each `proposed_cmd` → `obs` cycle = 1 step |
| `message_update` (assistant text) | `thinking` event `.text` field |
| `compaction_end` | No equivalent (Motoko doesn't compact mid-run) |
| `{"type": "abort"}` command | `{"type": "abort"}` command (same) |

Motoko also emits event types that `MotokoRpc` should consume or ignore:

| Event type | Action |
|---|---|
| `session_start` | Record model, task confirmation |
| `thinking`, `thinking_stream_*` | Accumulate assistant reasoning text |
| `proposed_cmd`, `obs` | Track step commands and results |
| `tool_calls`, `tool_results` | Track delegated tool execution |
| `done` | Terminal — extract final output, mark agent_ended |
| `error` | Terminal — record error message |
| `context_usage` | Record for token estimation |
| `compose_*`, `proposed_ailang`, `ailang_check` | Ignore (extension-specific) |

### 0.3 `MotokoRpc` class design

```python
@dataclass
class MotokoResult:
    steps: list[dict]          # [{cmd, stdout, stderr, exit_code}]
    final_output: str          # text from the `done` event
    thinking_text: str         # concatenated `thinking` events
    step_count: int
    agent_ended: bool
    elapsed_s: float

class MotokoRpc:
    def __init__(
        self,
        task: str,
        model: str = "anthropic/claude-sonnet-4-6",
        workdir: str | None = None,
        env_port: int | None = None, # None = auto-pick free port
        max_steps: int = 50,
        env: dict | None = None,
        timeout: float = 900,
    ):
        ...

    def run_and_collect(self, timeout: float = 900) -> MotokoResult:
        """Spawn Motoko, drain JSONL events until done/error, return result."""
        ...

    def abort(self):
        """Send {"type": "abort"} on stdin."""
        ...

    def close(self, timeout: float = 5):
        ...

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()
```

### 0.4 Subprocess spawn

The harness spawns the TUI entry point (not AILANG directly) to keep the
env server lifecycle managed by the same Node process. The README warns
against running `node src/tui/dist/index.js` from subdirectories — the
harness should use `scripts/run-agent.sh` or resolve the path from
`REPO_ROOT` the same way `run-agent.sh` does.

```python
REPO_ROOT = Path(__file__).parent.parent
TUI_ENTRY = REPO_ROOT / "src" / "tui" / "dist" / "index.js"

self._proc = subprocess.Popen(
    ["node", str(TUI_ENTRY), task],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    cwd=str(REPO_ROOT),      # always run from repo root
    env={
        **os.environ,
        **(env or {}),
        "TASK": task,
        "MODEL": model,
        "WORKDIR": workdir or os.getcwd(),
        "ENV_PORT": str(env_port),
        "AI_MAX_STEPS": str(max_steps),
        "MOTOKO_JSONL_OUTPUT": "1",
    },
    text=True,
    bufsize=1,
    start_new_session=True,   # create process group for clean kill
)
```

### 0.5 Port allocation for parallel runs

Each Motoko instance starts an env server on `ENV_PORT`. When running
exercises in parallel, port collisions are fatal.

**Strategy**: The Python harness picks a free port before spawning:

```python
import socket
s = socket.socket(); s.bind(("", 0)); port = s.getsockname()[1]; s.close()
```

Then passes it as `ENV_PORT=<port>` in the subprocess env.

Note: `ENV_PORT=0` (let-the-OS-pick) won't work because
`startEnvServer()` returns `void` and `ENV_URL` is constructed before
the server starts (`index.ts:297`). The TUI has no way to communicate
the assigned port back. Python-side port picking avoids this entirely.

### 0.6 Process cleanup

The Node process spawns an AILANG child. On timeout, the harness must
kill the entire process tree. Using `start_new_session=True` at spawn
and `os.killpg` at cleanup:

```python
def close(self, timeout: float = 5):
    if self._closed:
        return
    self._closed = True
    try:
        if self._proc.stdin and not self._proc.stdin.closed:
            self._proc.stdin.close()
    except Exception:
        pass
    try:
        self._proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(self._proc.pid), signal.SIGKILL)
        except OSError:
            self._proc.kill()  # fallback if process group kill fails
        self._proc.wait()
```

### 0.7 JSONL reader thread

Same architecture as `PiRpc`: a background thread reads stdout line-by-line,
parses JSON, and pushes events into a queue. The main thread drains events
until it sees `{"type": "done"}` or `{"type": "error"}`.

```python
def _read_loop(self):
    assert self._proc.stdout is not None
    while True:
        line = self._proc.stdout.readline()
        if not line:
            break
        line = line.rstrip("\r\n")
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        with self._cv:
            self._events.append(ev)
            self._cv.notify_all()
```

Note: uses explicit `readline()` instead of `for line in stdout` to avoid
Python's opaque read-ahead buffering (same lesson as `PiRpc`).

### 0.8 Files to create/modify

| File | Action |
|---|---|
| `benchmarks/motoko_rpc.py` | **Create** — `MotokoRpc` + `MotokoResult` |
| `src/tui/src/index.ts` | **Modify** — add `JsonlLogger`, wire into non-TTY branch |

---

## Phase 1: Aider Polyglot driver

**Goal**: Run Exercism exercises against Motoko and record pass/fail.

### 1.1 Fork `aider_polyglot.py`

The driver is almost identical to little-coder's. Key differences:

1. Import `MotokoRpc` instead of `PiRpc`
2. The Motoko agent gets a single task prompt (no interactive retry via RPC).
   For retry: spawn a second `MotokoRpc` instance with a modified task that
   includes the test failure output (see 1.4 for tradeoffs).
3. `WORKDIR` is set to the exercise temp directory (Motoko's env server
   executes commands there).

### 1.2 Prompt construction

Reuse little-coder's `_build_prompt()` verbatim. Motoko's system prompt
(`SYSTEM.md`) already instructs the agent to read files, implement solutions,
and run tests — the Exercism prompt maps naturally to its workflow.

### 1.3 Test runner

Reuse little-coder's per-language `_run_tests` functions unchanged. These
are pure `subprocess.run` calls — they don't depend on the agent at all.

### 1.4 Retry flow

```python
# First attempt
with MotokoRpc(task=prompt, model=model, workdir=work_dir) as rpc:
    result1 = rpc.run_and_collect()
passed, output = run_tests(work_dir)

if not passed and retry:
    retry_task = (
        f"{prompt}\n\n"
        f"The tests failed. Output:\n```\n{output[-4000:]}\n```\n"
        f"Fix the implementation and try again."
    )
    with MotokoRpc(task=retry_task, model=model, workdir=work_dir) as rpc:
        result2 = rpc.run_and_collect()
    passed, output = run_tests(work_dir)
```

**Retry tradeoff vs. little-coder**: In little-coder, `PiRpc` keeps the
same session alive across retries — the LLM sees the full conversation
history from the first attempt. In Motoko, retry spawns a fresh process
with no conversation memory. The retry prompt includes the original task
+ test failure output, and the agent sees the files modified by the first
attempt on disk, but has no access to its previous reasoning.

This is likely fine for Exercism — the modified source files carry most of
the context, and the test output tells the agent what went wrong. But it
means `pass_2` results are not directly comparable to little-coder's
`pass_2` results (Motoko's retry is harder since it lacks conversation
context). This should be noted in any benchmark comparison.

### 1.5 Result format

Same JSON schema as little-coder for comparability:

```json
{
  "exercises": {
    "python/hello-world": {"status": "pass_1", "elapsed_s": 42.3, "step_count": 5}
  },
  "meta": {"model": "anthropic/claude-sonnet-4-6", "agent": "motoko", "started_at": "..."}
}
```

### 1.6 Files to create

| File | Action |
|---|---|
| `benchmarks/aider_polyglot.py` | **Create** — Polyglot runner using `MotokoRpc` |

---

## Phase 2: Terminal-Bench adapter

**Goal**: Implement `BaseAgent` for Terminal-Bench that routes shell commands
through Motoko's environment server into the TB Docker container.

### 2.1 Architecture difference

little-coder uses a `_TmuxShellProxy` that bridges pi's ShellSession tool
calls to TB's `TmuxSession` via an `extension_ui_request` callback channel.
This works because pi has a bidirectional RPC protocol — the agent can ask
the harness to run a command.

Motoko doesn't have ShellSession or bidirectional RPC. It executes bash
commands via `POST /exec` to its embedded env server. The env server runs
commands locally via `child_process.exec`.

**Approach**: A Python HTTP sidecar wraps the TB `TmuxSession` and exposes
a `POST /exec` endpoint. The TS env server, when `TB_EXEC_PROXY` is set,
forwards command execution to this sidecar instead of running locally.

### 2.2 Python HTTP sidecar (`shell_sidecar.py`)

The sidecar runs inside the Python adapter process. It:
- Listens on a local port
- Accepts `POST /exec` with `{command, timeout}` (same schema as the TS
  env server)
- Routes commands through `TmuxSession` using the same sentinel-based
  exit-code recovery as little-coder's `_TmuxShellProxy`
- Maintains CWD state across stateless exec calls
- Returns `{stdout, stderr, exit_code}`

```python
from http.server import HTTPServer, BaseHTTPRequestHandler

class ShellSidecarHandler(BaseHTTPRequestHandler):
    proxy: "_TmuxShellProxy"  # set on the class before starting

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        # proxy.run() returns formatted output with an exit code footer:
        #   "output text\n[exit=0 cwd=/app ...]"
        # Parse the exit code from the footer and return the env server's
        # expected schema: {stdout, stderr, exit_code}
        raw = self.proxy.run(body["command"], body.get("timeout", 30))
        code = parse_exit_code(raw)  # extract from [exit=N ...] footer
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({
            "stdout": raw[:8000],
            "stderr": "",
            "exit_code": code,
        }).encode())
```

### 2.3 Env server proxy mode

Add to `env-server.ts`: when `TB_EXEC_PROXY` env var is set (a URL like
`http://localhost:9090`), the `POST /exec` handler forwards the request to
that URL instead of running `child_process.exec` locally.

**Important**: The current `POST /exec` handler (`env-server.ts:910`) uses
synchronous `execSync` inside a synchronous Express handler. To add
`await fetch(...)` for the proxy path, the handler must become `async`.
This requires converting `execSync` to a promisified `exec` on the normal
code path as well — a slightly larger change (~20 lines) but
straightforward since Express supports async handlers natively.

```typescript
const tbProxy = process.env.TB_EXEC_PROXY;

app.post("/exec", async (req, res) => {
    const { cmd, timeout = 30 } = req.body;

    if (tbProxy) {
        // Forward to Python sidecar
        const resp = await fetch(`${tbProxy}/exec`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ command: cmd, timeout }),
        });
        const result = await resp.json();
        res.json(result);
    } else {
        // Existing local exec path, converted from execSync to async exec
        try {
            const { stdout, stderr } = await execPromise(cmd, {
                cwd: workdir, timeout: timeout * 1000,
                encoding: "utf8", maxBuffer: 8 * 1024 * 1024,
            });
            res.json({ stdout: stdout.slice(0, 8000), stderr: "", exit_code: 0 });
        } catch (e: any) {
            res.json({
                stdout: String(e.stdout ?? "").slice(0, 8000),
                stderr: String(e.stderr ?? "").slice(0, 2000),
                exit_code: typeof e.status === "number" ? e.status : 1,
            });
        }
    }
});
```

This keeps the AILANG runtime completely untouched — it still calls
`POST /exec` to the TS env server as usual.

### 2.4 CWD persistence

Motoko's env server runs commands statelessly (`child_process.exec` in a
fresh shell each time). TB tasks need persistent shell state (CWD, env vars
between commands). The Python sidecar must track CWD:
- Append `; echo __CWD__; pwd` to each command
- Parse the CWD from output after the sentinel
- Prepend `cd <tracked_cwd> &&` to subsequent commands

This matches the `_HarborShellProxy` pattern from little-coder's Harbor
adapter.

### 2.5 `MotokoAgent` class

```python
class MotokoAgent(BaseAgent):
    @staticmethod
    def name() -> str:
        return "motoko"

    def perform_task(self, instruction, session, logging_dir):
        proxy = _TmuxShellProxy(session, session_id)
        # Start Python HTTP sidecar wrapping the TmuxSession
        sidecar = start_shell_sidecar(proxy, port=0)
        sidecar_url = f"http://localhost:{sidecar.port}"

        rpc = MotokoRpc(
            task=tb_prompt(instruction),
            model=self._model,
            max_steps=40,
            env={
                "TB_EXEC_PROXY": sidecar_url,
                "SYSTEM_MD": str(TB_SYSTEM_PROMPT),
            },
        )
        result = rpc.run_and_collect(timeout=3600)
        sidecar.shutdown()
        # ... log results, return AgentResult
```

### 2.6 Benchmark-specific system prompt

TB tasks need a different system prompt (shell-only, container context).
Create `benchmarks/prompts/tb_system.md` and pass via `SYSTEM_MD`.

### 2.7 Files to create/modify

| File | Action |
|---|---|
| `benchmarks/tb_adapter/motoko_agent.py` | **Create** — TB BaseAgent |
| `benchmarks/tb_adapter/shell_sidecar.py` | **Create** — Python HTTP sidecar for tmux proxy |
| `benchmarks/prompts/tb_system.md` | **Create** — TB-specific system prompt |
| `src/tui/src/env-server.ts` | **Modify** — add `TB_EXEC_PROXY` forwarding |

---

## Phase 3: Configurable step budget + model

**Goal**: Let the benchmark harness control Motoko's step limit and model
via environment variables.

### 3.1 Current state — mostly already done

`rpc.ail` line 493 already reads `AI_MAX_STEPS`:
```ailang
let max_steps = clamp_positive(parse_env_int("AI_MAX_STEPS", 50), 50);
```

`clamp_positive(n, fallback)` returns `n` if `n > 0`, otherwise `fallback`.
There is **no upper bound** — `AI_MAX_STEPS=100` works fine. The `50` is a
fallback for when the env var is unset or non-positive, not a ceiling.

This means the harness can set `AI_MAX_STEPS=30` (for GAIA), `AI_MAX_STEPS=40`
(for TB), or `AI_MAX_STEPS=100` via the `env` dict passed to `MotokoRpc`.

### 3.2 Env vars available to the benchmark harness

| Variable | Default | Purpose | Status |
|---|---|---|---|
| `AI_MAX_STEPS` | 50 | Step budget | Already implemented, no ceiling |
| `MODEL` | `anthropic/claude-sonnet-4-6` | Model string | Already implemented |
| `SYSTEM_MD` | `SYSTEM.md` | Override system prompt path | Already implemented |
| `MOTOKO_JSONL_OUTPUT` | — | Enable JSONL output for harness | Phase 0 |
| `MOTOKO_BENCHMARK` | — | Benchmark name (for logging/result tagging) | **New** |

### 3.3 Benchmark-specific system prompts

For Terminal-Bench, the system prompt needs to be different (shell-only,
no file tools). For Polyglot, the default `SYSTEM.md` is likely fine since
it already instructs the agent to read files, implement code, and run
commands.

| File | Purpose |
|---|---|
| `benchmarks/prompts/polyglot_system.md` | Optional override; default `SYSTEM.md` may suffice |
| `benchmarks/prompts/tb_system.md` | TB: shell-only, container context |

The harness sets `SYSTEM_MD=benchmarks/prompts/tb_system.md` when spawning
Motoko for Terminal-Bench tasks.

---

## Phase 4: Result reporting + status scripts

**Goal**: Consistent result storage and live monitoring.

### 4.1 Result JSON schema

```json
{
  "exercises": {
    "<lang>/<name>": {
      "status": "pass_1 | pass_2 | fail | error",
      "elapsed_s": 42.3,
      "step_count": 5
    }
  },
  "meta": {
    "agent": "motoko",
    "model": "anthropic/claude-sonnet-4-6",
    "started_at": "2026-04-27T...",
    "ailang_version": "0.12.1"
  }
}
```

Note: per-step token counts are not currently available in Motoko's JSONL
events. The `context_usage` event has cumulative `tokens_est` but not
per-step input/output breakdowns. Token fields can be added later if
needed for cost analysis (see Open Questions).

### 4.2 Status script

`benchmarks/status.sh` — reads the result JSON and prints:

```
Motoko Polyglot Status (anthropic/claude-sonnet-4-6)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  pass_1:  45 / 100  (45.0%)
  pass_2:   8 / 100  ( 8.0%)
  fail:    47 / 100  (47.0%)
  total:  53.0% pass rate
  avg elapsed: 38.2s
  avg steps:   6.1
```

### 4.3 Files to create

| File | Action |
|---|---|
| `benchmarks/results/` | **Create** — output directory |
| `benchmarks/status.sh` | **Create** — live status reporter |

---

## Phase 5: Smoke test + CI gate

**Goal**: A quick end-to-end test that verifies the harness works.

### 5.1 Pre-flight checks

The smoke test should verify prerequisites before attempting a real run:

```python
def preflight():
    # 1. ailang binary exists and runs
    assert shutil.which("ailang"), "ailang not on PATH"

    # 2. TUI is built
    tui_entry = REPO_ROOT / "src" / "tui" / "dist" / "index.js"
    assert tui_entry.exists(), f"TUI not built: {tui_entry} missing. Run: cd src/tui && npm run build"

    # 3. Node.js available
    assert shutil.which("node"), "node not on PATH"
```

### 5.2 Smoke test

```python
# benchmarks/smoke.py
# Spawn Motoko with a trivial task ("echo hello world"),
# verify JSONL events flow (session_start arrives),
# verify at least one proposed_cmd + obs cycle,
# verify done event arrives within 60s.
```

### 5.3 Single-exercise gate

```bash
# Run one Polyglot exercise as a CI gate
python benchmarks/aider_polyglot.py \
    --language python \
    --exercise hello-world \
    --model anthropic/claude-sonnet-4-6 \
    --verbose
```

`hello-world` is the simplest Exercism exercise — if it fails, the harness
is broken.

### 5.4 Files to create

| File | Action |
|---|---|
| `benchmarks/smoke.py` | **Create** — pre-flight checks + minimal end-to-end verify |

---

## Dependency graph

```
Phase 0 (MotokoRpc + JSONL mode)
  │
  ├──► Phase 1 (Polyglot) ──► Phase 4 (Reporting)
  │                                │
  ├──► Phase 2 (TB adapter)        ▼
  │                           Phase 5 (Smoke)
  └──► Phase 3 (Config)
```

Phase 0 is the sole prerequisite. Once it's done, Phases 1–3 can proceed
in parallel. Phase 4 (reporting) needs at least Phase 1 to have a result
format to report on. Phase 5 (smoke test) can run as soon as Phase 0 is
done, but should be finalized last to cover all paths.

---

## Exercism dataset setup

The Polyglot benchmark expects exercises at `~/Documents/polyglot-benchmark/`.
This is the standard Exercism track layout:

```bash
mkdir -p ~/Documents/polyglot-benchmark
cd ~/Documents/polyglot-benchmark
git clone https://github.com/exercism/python
# Exercises live at python/exercises/practice/<name>/
```

Update `BENCHMARK_ROOT` in `aider_polyglot.py` if needed.

---

## Open questions

1. **Token counting**: Motoko doesn't currently report token usage in its
   JSONL events. The `context_usage` event has `tokens_est` and `limit`,
   but per-step input/output token counts aren't available. For benchmark
   comparison with little-coder (which reports token totals via
   `AgentResult`), we may want to add token fields to `thinking` or `done`
   events. Not blocking for pass/fail benchmarks, but needed for cost
   analysis.

2. **GAIA benchmark**: The scorer exists in little-coder and is reusable.
   The driver needs web browsing capabilities. Motoko currently supports
   web access via bash `curl` — is that sufficient, or do we need a proper
   browser tool? Defer until Polyglot + TB are stable.

3. **Parallel exercise runs**: The plan addresses port allocation (Phase
   0.5), but running N exercises in parallel also means N concurrent LLM
   API calls. For rate-limited providers (Anthropic, OpenAI), the harness
   may need a concurrency limiter. little-coder runs exercises sequentially;
   we should too initially, with parallelism as a future optimization.

4. **Polyglot system prompt**: The default `SYSTEM.md` may work for
   Polyglot exercises, but it's tuned for general SWE tasks, not Exercism.
   A tailored prompt (e.g., "you are solving an Exercism exercise, focus
   on the stub file and test file") might improve pass rates. Worth
   A/B testing after the baseline is established.
