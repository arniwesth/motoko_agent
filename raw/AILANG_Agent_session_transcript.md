# AILANG Session Transcript

*Conversation covering AILANG analysis, SWE-agent architecture, and Path 3 implementation planning.*

---

## 1. AILANG Analysis

**Q: Analyse https://ailang.sunholo.com/llms.txt. How could this language be used to build an actual coding agent?**

AILANG is a genuinely novel idea — not a general-purpose language in disguise, but a *substrate* designed from first principles around what makes code legible and safe for machines to generate, verify, and rewrite.

### What AILANG Actually Is

The core bet is that LLMs fail at code not because of intelligence, but because of ambiguity. Traditional languages were designed for humans: mutable state, implicit side effects, open-ended loops, syntactic sugar. AILANG eliminates that class of error at the language level:

- **No loops** — only `map`, `fold`, `filter`, recursion. Every iteration is a pure function over data, not time.
- **Algebraic effects** — every side effect (`IO`, `FS`, `Net`, `AI`, `SharedMem`) is declared in the function signature.
- **Hindley-Milner type inference** — types are inferred globally and checked statically. The LLM gets type errors as structured JSON, not ambiguous runtime crashes.
- **Deterministic evaluator** — the same input always produces the same output. Traces are replayable.
- **`SharedMem` + `SharedIndex`** — built-in semantic memory with SimHash deduplication and neural embedding search.

### How to Build a Coding Agent With It

The agent loop:

1. Receive a task in natural language
2. Query `SharedIndex` for similar previously-solved problems
3. Inject the relevant cached frames + the AILANG teaching prompt into the LLM context
4. Generate an AILANG module; run `ailang check` → parse JSON errors → loop until type-clean
5. Run with minimum necessary `--caps` flags; capture `--emit-trace jsonl`
6. Run property tests; if any fail, feed the minimal counterexample back to step 4
7. On success, call `store_frame` with the solution and its embedding for future retrieval

The MCP server (`ailang_check`, `ailang_run`, `ailang_builtins`, `ailang_eval`) exposes all of this to any MCP-compatible orchestrator.

---

## 2. Tool Calls in AILANG

**Q: Could actions/tool calls be done with code snippets instead, like eg https://github.com/huggingface/smolagents**

### The smolagents Insight

smolagents' core argument is that JSON tool-call schemas are an unnecessary indirection. Instead of JSON blob → parse → validate → dispatch → execute, you do: code snippet → execute directly. Tools are just functions in scope.

### Why AILANG is a Better Substrate

AILANG gives you three things Python can't:

1. **Static capability enforcement before execution.** If the generated snippet tries to `writeFile` but the module only declared `! {Net}`, the type-checker rejects it before a single line runs.
2. **The type-checker as a free corrector.** When the LLM writes bad AILANG, you get a structured JSON error at check-time with the exact line and type mismatch.
3. **Bounded execution by construction.** No-loops design means any generated snippet terminates.

### Tool Palette Approach

```ailang
module agent/palette

import std/net (httpGet, httpPost)
import std/fs  (readFile, writeFile)
import std/ai  (call)
import std/sem (load_frame, store_frame, make_frame_at)

export func search(query: string) -> string ! {Net} =
  httpGet("https://api.search.example.com/q?=" ++ query)

export func fetch_page(url: string) -> string ! {Net} =
  httpGet(url)

export func ask(prompt: string) -> string ! {AI} =
  call(prompt)
```

The LLM writes `fetch_page(search("AILANG tutorial"))` — a composed expression — not a JSON blob. One snippet, one eval, multiple tool calls composed.

---

## 3. `_ailang_eval` as a Runtime Builtin

**Q: Give an estimate of how difficult it would be to achieve `_ailang_eval` as a runtime builtin**

### Three Designs, Three Difficulty Bands

**Design A — Pure eval, fresh environment (1–3 days)**

```ailang
-- signature
_ailang_eval : string -> string -> Result[string, string] ! {Eval}
```

Essentially what `ailang repl` does for each line, invoked programmatically. No architectural changes needed.

**Design B — Eval inherits caller's bindings (1–2 weeks)**

Requires threading `eval.Env` through every builtin call — a non-trivial refactor of the builtin dispatch interface.

**Design C — Eval with capability argument + enforcement (add ~3 days)**

The caller explicitly grants a capability subset to the snippet.

### The Meta-Circular Type Problem

The deeper challenge: `_ailang_eval` takes a `string` and returns *something*, but the type-checker can't know what that something is until runtime. The cleanest escape hatch: make `_ailang_eval` return `string` always.

| Design | Core work | Blocker | Estimate |
|---|---|---|---|
| A: fresh env, string result | Wire REPL pipeline as builtin | None | 1–3 days |
| B: inherits caller scope | Thread `eval.Env` through builtins | Builtin interface refactor | 1–2 weeks |
| C: + capability enforcement | Runtime cap downgrade | Effect system exposure | +3 days |

---

## 4. mini-swe-agent Viability in AILANG

**Q: As a starting point would it be viable to implement https://github.com/SWE-agent/mini-swe-agent in AILANG?**

### What mini-swe-agent Actually Is

The entire agent is ~100 lines built on one radical simplification: **bash is the only tool**. The loop:
1. Send `messages` to LLM
2. Parse exactly one ` ```bash ``` ` block from the response
3. Run it with `subprocess.run` — stateless, each command independent
4. Append output to `messages`, repeat
5. Exit when output starts with `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`

### The Verdict: Blocked by One Missing Primitive

Almost everything maps cleanly to AILANG — except `subprocess.run`. AILANG's `FS` effect gives you `readFile`/`writeFile` — a tiny sliver of what `subprocess.run` provides.

### Three Paths Forward

| Design | Core work | Blocker | Estimate |
|---|---|---|---|
| **Path 1** | Add `Shell` effect, port the loop | None — all pieces exist | 1–3 days |
| **Path 2** | Replace bash with AILANG stdlib | Needs `_ailang_eval` | 1–2 weeks |
| **Path 3** | AILANG for scaffold, HTTP for execution | Environment server | 3–4 days |

---

## 5. Path 2 Exploration

**Q: Explore Path 2 a bit more.**

### The Semantic Decomposition

Bash operations fall into categories:

- **Discovery**: `find`, `grep` → pure FS traversal + string search
- **Reading**: `cat`, `head` → `readFile` + take
- **Editing**: `sed -i` → `readFile` + replace + `writeFile`
- **Execution**: `python reproduce.py`, `pytest` → ❌ subprocess — **the gap**

### Three Substitutes for Execution

**Substitute A: LLM self-review as the oracle**
```ailang
func verify_fix(issue: string, original: string, patched: string) -> string ! {AI} =
  call("Does this patch correctly fix the issue? Reason step by step, then YES or NO.")
```

**Substitute B: `ailang check` on the diff**
The type system ensures the agent always produces a well-formed edit record with all required fields.

**Substitute C: `SharedMem` as accumulated verification evidence**
The agent builds a cache of `(bug_pattern, fix_pattern, verified: bool)` frames.

### Honest Performance Assessment

Losing the reproduce-and-verify loop is a real cost. A bash agent scoring 74% would probably score 35–45% in pure read-edit mode. But Path 2 has different value: safe to run without a sandbox, every action logged as a typed value, `SharedMem` cache compounds over time, provably terminating.

---

## 6. Path 1 Exploration

**Q: Explore Path 1 a bit more**

### The Shell Effect Implementation

```go
// internal/effects/shell.go
func ExecShell(cmd string, timeoutSecs int) (ShellResult, error) {
    ctx, cancel := context.WithTimeout(context.Background(),
        time.Duration(timeoutSecs)*time.Second)
    defer cancel()
    c := exec.CommandContext(ctx, "bash", "-c", cmd)
    // ...
}
```

```ailang
-- std/shell (new module)
type ShellResult = { stdout: string, stderr: string, exit_code: int }

func sh(cmd: string) -> ShellResult ! {Shell} = _shell_exec(cmd, 30)
func sh_out(cmd: string) -> string ! {Shell} = (_shell_exec(cmd, 30)).stdout
```

### Where AILANG Changes the Design

mini-swe-agent made a brilliant architectural decision: **stateless subshells**. Each command runs in a fresh `subprocess.run` — no persistent shell session. This maps exactly onto AILANG's model: a `Shell` effect call is a function from `string` to `ShellResult`.

Python maintains `self.messages` as mutable class state. In AILANG it becomes an explicit parameter — the full trajectory is reconstructible from the function call chain alone.

### Key Additions Over Python

| Property | mini-swe-agent Python | Path 1 AILANG |
|---|---|---|
| Lines of core agent | ~100 | ~65 |
| Mutable state | `self.messages` list | Explicit `[Msg]` parameter |
| Trajectory persistence | JSON file, post-hoc | `SharedMem`, live |
| Shell capability control | Docker/bubblewrap | `--caps Shell` flag |
| Dry-run / mocking | `DeterministicModel` only | `MockEffContext` on any effect |
| Working directory | Prompt instruction | Explicit `cwd` parameter |
| SWE-bench score potential | 74% (demonstrated) | Same — identical LLM calls |

---

## 7. Path 3 Exploration

**Q: Now explore Path 3**

### The Precise Separation

Path 3: AILANG owns **reasoning** (LLM calls, message history, caching, trajectory management). A separate, swappable **environment** owns execution. AILANG talks to it over HTTP or MCP.

```
┌─────────────────────────┐       ┌──────────────────────────┐
│   AILANG brain          │       │   Environment             │
│   ! {AI, Net, SharedMem}│──────▶│   full shell, FS, net     │
│   no dangerous caps     │  HTTP │   Docker / bubblewrap     │
│   auditable trace       │  /MCP │   sandboxed               │
└─────────────────────────┘       └──────────────────────────┘
```

### What the Separation Uniquely Enables

1. **Capability tiers** — brain is `! {AI, Net, SharedMem}`, no Shell, no FS writes to repo
2. **Parallel environments from one brain** — `env_url` is a parameter, run two branches simultaneously
3. **Environment snapshotting** — checkpoint before risky operations, restore on failure
4. **Environment versioning** — same brain, different Docker images per task

### Environment Server (Python)

```python
# env_server.py — runs inside Docker or locally
@app.route("/exec", methods=["POST"])
def execute():
    cmd = request.json["cmd"]
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return jsonify({"stdout": result.stdout[:8000], "stderr": result.stderr[:2000],
                    "exit_code": result.returncode})
```

Switch to Docker: replace `subprocess.run` with `docker exec my-container bash -c "$cmd"`. The AILANG brain doesn't change at all.

---

## 8. Detailed Plan for Path 3

*[See separate plan document: `path3_plan.md`]*

Key phases:
- Phase 0: TypeScript scaffold (0.5 days)
- Phase 1: Environment server in TypeScript (1 day)
- Phase 2: AILANG brain modules (2–3 days)
- Phase 2b: `swe/rpc.ail` — yolo brain (0.5 days)
- Phase 2c: pi-tui frontend (1–2 days)
- Phase 3: SharedMem cache (1 day)
- Phase 4: Test harness (1.5–2 days)
- Phase 5 (opt): `call_with` builtin + streaming (2–3 days)
- Phase 6 (opt): MCP upgrade (1–2 days)
- **Total phases 0–4: 7–10 days**

---

## 9. Interactive Mode (mini CLI)

**Q: What I would like is something similar to https://mini-swe-agent.com/latest/usage/mini/**

mini provides three modes:
- **confirm** (`/c`): LM proposes, user presses Enter to execute or types rejection
- **yolo** (`/y`): Execute immediately without confirmation
- **human** (`/u`): User types commands directly

### Changes to the Plan

**New ADT:**
```ailang
export type Mode = Confirm | Yolo | Human
```

**`AgentState` gains a mode field:**
```ailang
export type AgentState = {
  env_url: string, msgs: [Msg], cwd: string, step: int, mode: Mode
}
```

**The confirm/reject/human logic** is recursive AILANG — the rejection path appends both the LLM's response and the rejection feedback to the message history before re-querying.

**The one genuine limitation vs. mini:** AILANG has no signal handling. If you press Ctrl+C while the LLM call is in flight, the process dies. A thin Python/TypeScript wrapper would add real value here.

---

## 10. pi-tui as Frontend

**Q: Could eg https://github.com/badlogic/pi-mono/tree/main/packages/tui be used as a frontend? Any sensible way to have typescript terminal frontend and AILANG as backend?**

### What pi-tui Actually Is

A self-contained TypeScript terminal UI framework with:
- **Differential rendering**: only repaints lines that changed, CSI 2026 synchronized output
- **Component model**: everything is a `Component` with `render(width): string[]`
- **Built-ins**: `Text`, `Markdown`, `Editor`, `Input`, `SelectList`, `Loader`, `Box`
- **Kitty keyboard protocol** plus legacy xterm fallback

### The Architecture

Three processes, two protocols:

```
┌─────────────────────────────────────────────────────┐
│  TypeScript process                                  │
│  ┌──────────────┐    ┌───────────────────────────┐  │
│  │  pi-tui UI   │    │  Environment server        │  │
│  │  (stdin/out) │    │  POST /exec  (HTTP :8080)  │  │
│  └──────┬───────┘    └───────────────────────────┘  │
└─────────┼───────────────────────────────────────────┘
          │ JSONL over stdin/stdout
          │
┌─────────┴───────────────────────────────────────────┐
│  AILANG brain process                                │
│  ! {Net, AI, SharedMem, IO}                          │
└─────────────────────────────────────────────────────┘
```

### JSONL Protocol

**AILANG → TypeScript (events):**
```json
{"type":"session_start","task":"Fix the off-by-one","mode":"confirm"}
{"type":"thinking","step":1,"text":"Let me find the relevant files first."}
{"type":"proposed_cmd","step":1,"cmd":"find . -name '*.py' | head -20"}
{"type":"obs","step":1,"cmd":"...","stdout":"...","stderr":"","exit_code":0}
{"type":"done","step":8,"output":"COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT"}
```

**TypeScript → AILANG (commands):**
```json
{"type":"execute"}
{"type":"reject","message":"Use grep instead"}
{"type":"mode_change","mode":"yolo"}
{"type":"abort"}
```

### What pi-tui Solves That Pure-AILANG Couldn't

- **Ctrl+C handled properly** — TypeScript catches SIGINT, sends `{"type":"abort"}`, can switch modes
- **Streaming LLM responses** — tokens rendered in real time via pi-ai's streaming API
- **Rich Markdown rendering** — LLM reasoning text as CommonMark with syntax highlighting
- **Python dependency eliminated** — environment server moves into TypeScript process

---

## 11. Model Selection via /model

**Q: Can model selection be supported in a session? Ie, a /model command to select a new model?**

### The Constraint

AILANG's model is fixed at process start via `--ai claude-sonnet-4-6`. There's no `setModel()` in `std/ai`.

### Three Options

**Option A — Serialize and restart:** Kill brain, spawn new one with new model. Ugly, laggy.

**Option B — TypeScript owns the LLM call:** AILANG emits `{"type":"llm_request","messages":[...]}` and blocks waiting for `{"type":"llm_response","content":"..."}`. TypeScript makes the actual API call. Model switching is `currentModel = newModel`. But this hollows out the `AI` effect from AILANG's type system.

**Option C — Option D: keep LLM calls in AILANG, make model a runtime value:**

```ailang
-- New builtin: call_with(model: string, prompt: string) -> string ! {AI}
func llm_call(msgs: [Msg]) -> string ! {AI, SharedMem} =
  let model = match load_frame("config:current_model") {
    Some(f) => f.content,
    None    => "claude-sonnet-4-6"
  };
  call_with(model, fmt_msgs(msgs))
```

TypeScript's `/model` writes to SharedMem. AILANG reads the new model on its next step. No restart, `AI` effect preserved in the type and the trace.

### Comparison

| Property | Option B | Option D |
|---|---|---|
| AI effect in AILANG type | ✗ laundered through IO | ✓ preserved |
| `--emit-trace` completeness | ✗ LLM calls missing | ✓ complete |
| `--ai-stub` testing | ✗ needs separate mock | ✓ works unchanged |
| Mid-session model switching | ✓ trivial | ✓ via SharedMem |
| Streaming tokens to UI | ✓ native | ⚠ needs new builtin |
| Runtime changes needed | none | `call_with` builtin (~1 day) |

**Option D costs one day of AILANG runtime work and preserves everything AILANG promises.**

---

## 12. Updated Plan: Yolo Mode + Option D

**Q: Update the plan with Option D. The agent should always run in yolo mode.**

### Key Simplifications

**Removed entirely:** Mode ADT, `await_user`, `human_turn`, `execute_and_continue`, all confirm/reject/human logic.

**New runtime requirement:** `_io_poll_stdin` — a non-blocking stdin peek returning `""` if nothing ready. ~10 lines Go. The only runtime addition needed for phases 0–4.

**Model selection in two tiers:**
- Phases 0–4: model fixed at startup, `model_change` stored in SharedMem for next invocation
- Phase 5: `call_with` enables true mid-session switching

### Core Brain (`swe/rpc.ail`) — Simplified

```ailang
-- Core recursive loop — always yolo
func rpc_loop(state: AgentState, model: string, depth: int)
    -> string ! {Net, AI, SharedMem, IO} =
  if depth == 0 then ... "step limit reached"
  else
  if check_abort() then ... "aborted"
  else
  let model2   = check_model_change(model);
  -- Phase 0-4: call(); Phase 5: call_with(model2, ...)
  let response = call(fmt_msgs(state.msgs));
  ...
```

One commented line separates the two phases. Upgrading is removing one comment character.

---

## 13. System Prompt

**Q: In the current version of the plan, how would the agent eg read a list of files in a directory?**

It goes through bash via the env server. Every interaction with the target repo — listing, reading, writing, running tests, diffing — goes through `exec_in` → `execSync`.

**Q: Update the system prompt in the plan**

The system prompt (`base_system` in `swe/prompts.ail`) now covers six operation categories with concrete bash examples:

```ailang
export let base_system =
  "You are a software engineering agent running in a bash environment." ++
  " Each response must contain exactly ONE bash code block." ++
  " Every command runs in a fresh subshell." ++
  "\n## All file and repo access goes through bash\n" ++
  "### List files\n" ++
  "  find /testbed -name '*.py' | head -40\n" ++
  "### Read a file\n" ++
  "  cat /testbed/src/utils.py\n" ++
  "  nl -ba /testbed/src/utils.py | sed -n '10,30p'\n" ++
  "### Search within files\n" ++
  "  grep -rn 'pattern' /testbed/src/\n" ++
  "### Edit a file\n" ++
  "  sed -i 's/old_string/new_string/g' /testbed/src/utils.py\n" ++
  "### Create or overwrite a file\n" ++
  "  cat <<'EOF' > /testbed/src/newfile.py\n  # content\n  EOF\n" ++
  "### Run tests\n" ++
  "  cd /testbed && python -m pytest tests/ -x -q\n" ++
  "### Inspect git state\n" ++
  "  git -C /testbed diff\n" ++
  "## Recommended workflow\n" ++
  "1. Find and read relevant files\n" ++
  "2. Create a script to reproduce the issue\n" ++
  "3. Edit source files to fix it\n" ++
  "4. Verify the fix by running your reproduction script and tests\n" ++
  "5. When done: echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT\n"
```

---

## 14. Memory Management in AILANG

**Q: How is memory managed in AILANG?**

Three distinct layers:

### Layer 1: The Language — No Memory Management

AILANG is purely functional with immutable values. No pointers, no references, no malloc/free, no ownership model. Every value is immutable. "Mutating" a record produces a new record — the original is untouched. Values exist as long as something references them and vanish when nothing does.

### Layer 2: The Runtime — Go's GC

AILANG is implemented in Go. Every AILANG value maps to a Go heap allocation. The Go GC handles reclamation automatically. GC pauses are irrelevant at the timescales an agent operates (2–10 seconds per LLM call).

### Layer 3: The Real Concern — Recursion and the Stack

AILANG has no loops — everything that iterates is recursive. Each call to `loop` adds a stack frame. At depth 50, you have 50 frames live simultaneously, each holding a `[Msg]` list that grows by 2 entries per step.

**The practical limit:** Go's goroutine stacks start at 8KB and grow dynamically up to 1GB. For 50-step agent loops, you won't hit the limit. But AILANG does not currently implement TCO (Tail Call Optimisation). The explicit depth bound is the workaround.

**Ring buffer mitigation:**
```ailang
func trim_history(msgs: [Msg], max_obs: int) -> [Msg] =
  let system = take(1, msgs);
  let task   = take(1, drop(1, msgs));
  let recent = takeLast(max_obs * 2, msgs);
  system :: (task :: recent)
```

### Layer 4: SharedMem — Explicit, Persistent, Separate

`SharedMem` is a separate named store outside the AILANG evaluator's heap that persists across runs. The message history `[Msg]` is heap memory (GC'd after the run); cached trajectories in `SharedMem` survive indefinitely.

| Layer | Who manages it | How |
|---|---|---|
| AILANG values | Go GC | Automatic; invisible to programmer |
| Stack depth | Programmer | Explicit depth bounds on recursion |
| SharedMem | Programmer | Explicit store/load calls; persists across runs |
| Effect resources | Go runtime | Cleaned up at effect boundary |
| Trace output | OS / filesystem | Written by `--emit-trace` |

---

## 15. Arrays in AILANG

**Q: Does AILANG have arrays?**

Yes — distinct from lists and documented in the `llms.txt`.

**Lists** (`[int]`): singly-linked, O(1) prepend via `::`, O(n) indexed access. The default.

**Arrays** (`#[int]`): O(1) indexed access, backed by a contiguous block:

```ailang
import std/array as A

let arr  = #[10, 20, 30]       -- array literal
let val  = A.get(arr, 0)       -- 10  (O(1))
let safe = A.getOpt(arr, 99)   -- None  (out of bounds → Option)
let arr2 = A.set(arr, 0, 99)   -- #[99, 20, 30]  (O(n) copy — immutable)
```

`A.set` is O(n) because AILANG values are immutable — "updating" an array produces a full copy. Use lists for incremental building; use arrays for repeated random-access lookups.

---

## 16. Dictionaries in AILANG

**Q: What about dictionaries?**

AILANG does not have a built-in dictionary or map type. The three things that cover dictionary use cases:

**Records** — fixed, known keys at compile time:
```ailang
let config = { host: "localhost", port: 8080, timeout: 30 }
let h = config.host
let config2 = { config | port: 9090 }
```
Keys are fixed at compile time — you can't add fields dynamically or iterate over keys.

**Lists of key-value pairs** — for dynamic string-keyed data (what the JSON module uses):
```ailang
let obj = jo([kv("name", js("Alice")), kv("count", jnum(42.0))])
match get(obj, "name") { Some(j) => asString(j), None => None }
```
`get` does a linear scan — O(n). Fine for small config objects.

**SharedMem** — for persistent string-keyed storage across the whole program:
```ailang
let _ = store_frame("user:alice", make_frame_at(...))
match load_frame("user:alice") { ... }
```

**Honest gap:** If you need an in-memory `Map[string, T]` with O(log n) or O(1) lookup and dynamic keys, AILANG doesn't have one yet. The schema registry planned for v0.6+ would likely introduce this.

---

## 17. Plan as Markdown

*[See separate file: `path3_plan.md`]*

The plan covers:
1. Architecture Overview
2. JSONL Protocol
3. AILANG Brain Modules (types, prompts, rpc)
4. TypeScript Frontend (env-server, brain, ui, models, index)
5. Model Selection: Two Modes
6. What is Unchanged
7. Runtime Requirements
8. Build Order
9. Success Criteria

---

## 18. Tool Calling in the Current Architecture

**Q: Since the Python server from the original plan has been replaced by TypeScript, is tool calling now handled by ts?**

There are two different things "tool calling" could mean:

**Bash execution — yes, TypeScript now runs it.** When AILANG calls `exec_in(env_url, cmd, 30)`, that HTTP request lands in `env-server.ts` which runs `execSync(cmd)`. TypeScript is the execution substrate. But the *decision* of what to execute stays in AILANG.

**LLM tool-calling API — not used, and intentionally so.** The design follows mini-swe-agent's approach: the LLM writes a bash block in plain text, AILANG parses it out with `extract_bash`. The OpenAI/Anthropic function-calling JSON schema interface is never invoked.

The split:
```
LLM response parsing  →  AILANG (extract_bash in swe/parse.ail)
What command to run   →  LLM decides, AILANG extracts
Running the command   →  TypeScript env server (execSync)
Observing the output  →  AILANG (receives ExecResult, emits obs event)
```

---

## 19. File Operations: How the Agent Reads Files

**Q: In the current version of the plan, how would the agent eg read a list of files in a directory?**

It goes through bash via the env server. The LLM generates:

```bash
find /testbed -name "*.py" | head -30
```

or

```bash
ls -la /testbed/src/
```

`extract_bash` pulls that out of the LLM response, `exec_in` POSTs it to `env-server.ts`, TypeScript runs `execSync(cmd)` with `WORKDIR=/testbed`, and the stdout comes back as an `ExecResult`. AILANG emits it as an `obs` event.

**The important implication:** AILANG's `std/fs` would only see the filesystem *where the AILANG process runs*, not where the env server is pointed. The brain's only path into the repo is through the declared `Net` effect — which is correct by design. The `FS` cap can be dropped from the brain's `--caps` flag entirely: `! {Net, AI, SharedMem, IO}`.

---

## 20. OpenRouter Support

**Q: Does AILANG support openrouter models?**

Based on all documentation, AILANG supports exactly three providers via the `--ai` flag:

```bash
ailang run --caps IO,AI --ai claude-haiku-4-5 ...   # Anthropic
ailang run --caps IO,AI --ai gpt5-mini ...           # OpenAI  
ailang run --caps IO,AI --ai gemini-2-5-flash ...   # Google
ailang run --caps IO,AI --ai-stub ...               # Testing stub
```

**Q: Check the AILANG GitHub to verify**

After checking the live documentation (now at v0.9.2), the `llms.txt`, the GitHub repo, and searching across all AILANG resources: **OpenRouter is not mentioned anywhere in the project.** No reference in docs, CHANGELOG, or examples.

**For the plan this means:**
- `KNOWN_MODELS` in `models.ts` should be restricted to Anthropic, OpenAI, and Google models only
- OpenRouter support would need to be added as part of the Phase 5 `call_with` builtin
- Since OpenRouter speaks the OpenAI API format, it would be a `baseURL` override on the OpenAI client — about 5 extra lines in Go

---

## Key Decisions Summary

| Decision | Chosen Approach | Rationale |
|---|---|---|
| Agent architecture | Path 3: AILANG brain + TypeScript env server | Cleanest separation; brain stays `! {Net, AI, SharedMem}` |
| Execution mode | Always yolo | Simplifies brain significantly; no mode logic needed |
| File operations | All via bash through env server | AILANG `std/fs` would only see brain's filesystem, not repo |
| Model selection | Option D: `call_with` builtin + SharedMem | Preserves AI effect in AILANG type system; `--ai-stub` still works |
| Model switching phases 0–4 | Fixed at startup; stored for next invocation | Avoids runtime work until architecture is proven |
| LLM tool-calling API | Not used | LLM writes bash blocks; same as mini-swe-agent |
| Frontend | pi-tui (TypeScript) | Differential rendering, Ctrl+C, Markdown, `/model` overlay |
| Environment server | TypeScript (express) | Eliminates Python dependency; embedded in same process as UI |
| OpenRouter | Not supported (phases 0–4) | Not in AILANG runtime; addable in Phase 5 `call_with` |

---

## AILANG Version Note

AILANG is at **v0.9.2** as of this session (the home page confirmed this). The `llms.txt` has a broken timestamp (`$(date -u ...)` was never evaluated), so it reflects an earlier state. The teaching prompt in the file is from v0.5.11. The provider list (Anthropic, OpenAI, Google) appears unchanged, but features, stdlib, and examples have continued to evolve since the documentation snapshot.
