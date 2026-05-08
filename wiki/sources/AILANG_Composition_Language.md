# AILANG as Agent Composition Language

## Purpose

Replace sequential single-command execution with a code-first composition model
where the LLM writes AILANG programs that orchestrate multiple operations in a
single agent step. Inspired by Pydantic's Monty project, but using AILANG itself
as the sandbox language instead of Python.

Core idea:

- The LLM writes AILANG snippets that compose file reads, searches, filtering,
  and bash execution into a single program.
- AILANG's effect system provides the sandbox: capabilities are granted per-run
  via `--caps`, not by the LLM.
- `ailang check` provides a pre-execution type-checking gate that catches errors
  before any side effects occur.
- `ailang verify` can prove pure helper functions correct via Z3 before execution.
- The entire AILANG core was written by LLMs. LLM fluency with AILANG is proven,
  not speculative.

This is not a replacement for the existing tool-calling system. It is an
additional execution mode for multi-step composition tasks where the current
approach burns multiple agent steps on what could be a single program.

---

## Why AILANG Instead of Monty/Python

Monty (pydantic/monty) solves the same problem with a sandboxed Python
interpreter. AILANG offers structural advantages for this project:

### Zero new dependencies

The AILANG runtime is already the host process. No sidecar, no FFI bridge, no
Rust binary to ship. The composition language is the same language the agent
core is written in.

### Algebraic effect sandbox

Monty's security model: zero capabilities, add external functions explicitly.
AILANG's security model: zero effects, add `! {FS}` or `! {Net}` explicitly.
The capability grant is in the `--caps` flag, controlled by Motoko, not by the
LLM. Effect violations are caught at type-check time, not runtime.

### Pre-execution type checking

`ailang check` catches type errors, missing imports, effect mismatches, and
syntax errors before any code runs. This is strictly better than Monty's
runtime-error-then-retry loop. The agent can self-correct from type errors
without burning a step on a failed execution.

### Z3 verification

For pure helper functions (`! {}`), `ailang verify` can mathematically prove
correctness. No Python sandbox offers this. Practical for validation logic,
data transformations, and filter predicates the agent writes.

### Proven LLM authorship

The entire `src/core/` codebase — recursive parsers, JSON fence scanners,
effect-annotated RPC loops, ADT-based tool result types — was written
exclusively by LLMs without a single line of human-authored code. LLM fluency
with AILANG is an empirical fact, not speculation.

### Ecosystem coherence

The agent runtime, the composition scripts, and the core logic all share one
language, one type system, one effect model. No impedance mismatch between
the sandbox and the host.

---

## What the LLM Gains

Today's execution model:

```
Step 1: LLM → "ls src/"          → stdout → LLM
Step 2: LLM → "grep -r TODO"     → stdout → LLM (thousands of lines)
Step 3: LLM → "wc -l matches"    → stdout → LLM
Step 4: LLM → "git blame file"   → stdout → LLM
Step 5: LLM → summarize
```

With AILANG composition:

```
Step 1: LLM → ```ailang
  import std/fs (listDir, readFile)
  import std/string (contains)
  import std/list (filter, length, filterE, forEachE)

  export func main() -> () ! {IO, FS} {
    let files = listDir("src/");
    let ts_files = filter(\f. contains(f, ".ts"), files);
    let with_todos = filterE(\f. contains(readFile("src/" ++ f), "TODO"), ts_files);
    let count = length(with_todos);
    println("Files with TODOs: " ++ show(count));
    forEachE(\f. println("  " ++ f), with_todos)
  }
``` → single execution → compact stdout → LLM
Step 2: LLM → summarize
```

Five steps become two. Intermediate data (full file contents, grep output)
never enters the context window.

---

## Architectural Design

### Execution flow

```
LLM response contains ```ailang fence
  → extract_ailang(response)                    [brain, parse.ail]
  → write snippet to temp file                  [brain or env-server]
  → ailang check <temp>.ail                     [pre-execution gate]
  → if type error: feed error back to LLM as observation, retry
  → ailang run --caps <granted> --entry main <temp>.ail
  → capture stdout/stderr/exit_code
  → emit observation to LLM
  → continue loop
```

### Capability control

The brain decides which effects to grant based on the task context:

| Capability level | Granted caps       | Use case                           |
|------------------|--------------------|------------------------------------|
| Read-only        | `IO,FS`            | Exploration, search, analysis      |
| Read-write       | `IO,FS,Process`    | File edits, bash subcommands       |
| Network          | `IO,FS,Net`        | API calls, downloads               |
| Full             | `IO,FS,Net,Process`| Unrestricted (current yolo mode)   |

The LLM declares effects in its snippet. If the declared effects exceed the
granted caps, `ailang check` or `ailang run` rejects the program. The brain
never grants more than the task warrants.

### Sandbox boundaries via FS sandbox

AILANG's `AILANG_FS_SANDBOX` environment variable restricts all FS operations
to a directory. When running composition snippets:

```
AILANG_FS_SANDBOX=/path/to/workdir ailang run --caps IO,FS <temp>.ail
```

All `readFile`, `writeFile`, `listDir` calls are jailed to the workdir. No
path traversal. This matches the existing env-server's cwd semantics.

### Integration with existing tool system

The composition tool coexists with the current hybrid tool-calling system:

```
LLM response
  → try parse_tool_calls(response)     [existing JSON tool path]
  → if NoToolCalls:
      → try extract_ailang(response)   [new AILANG composition path]
      → if None:
          → treat as final answer      [existing done path]
```

The LLM chooses which mode to use per step. The system prompt guides this
choice (see Prompt Engineering section below).

---

## Implementation Plan

### Phase 0 — AILANG fence extraction

Files:
- `src/core/parse.ail`

Changes:
- Add `extract_ailang(text: string) -> Option[string]` function
- Recognizes ` ```ailang ``` ` fenced blocks
- Reuses existing `extract_fence` infrastructure
- Add inline tests

This is a small, safe change. The function exists but is not wired into the
main loop yet.

### Phase 1 — Snippet execution via env-server

Files:
- `src/tui/src/env-server.ts`

Changes:
- Add `POST /exec-ailang` endpoint
- Accepts `{ code: string, caps: string, timeout: number }`
- Writes code to a temp file with deterministic module declaration
- Runs `ailang check <temp>.ail` first
- If check passes, runs `ailang run --caps <caps> --entry main <temp>.ail`
- Returns `{ stdout, stderr, exit_code, check_passed, check_errors }`
- Temp file cleanup after execution
- `AILANG_FS_SANDBOX` set to workdir
- Session-scoped result store (from LLMVM pattern):
  - Create `<workdir>/.motoko-store/` directory at session start
  - Delete it at session end
  - AILANG snippets persist results between executions via normal FS ops:
    `writeFile(".motoko-store/key.json", data)` to save,
    `readFile(".motoko-store/key.json")` to retrieve
  - No `Net` cap needed — granting `Net` for localhost access would also
    grant full network access with no way to restrict to localhost only
  - Sandboxed automatically by `AILANG_FS_SANDBOX`
  - Analogous to Monty's `results` tool but implemented as plain files

Why env-server, not brain-native:
- The brain already delegates bash execution to the env-server
- Process spawning, timeout enforcement, and cleanup are well-handled there
- Keeps the brain focused on orchestration, not process lifecycle

### Phase 2 — Brain integration

Files:
- `src/core/parse.ail`
- `src/core/env_client.ail`
- `src/core/rpc.ail`
- `src/core/types.ail`

Changes:
- Add `exec_ailang(url, code, caps, timeout)` to env_client
- Handle AILANG composition as a **separate code path**, not as a new
  `ToolCallReq` variant. AILANG composition is an alternative to tool calls,
  not a tool call itself. The plan's "Interaction with Existing Execution
  Modes" section frames the three modes as peers — the implementation should
  match. Adding to `ToolCallReq` would force AILANG snippets through the
  tool-call pipeline (parsing, backend selection, result normalization),
  which is unnecessary overhead for "run this script."
- Add `run_ailang_step` function in rpc.ail (parallel to `run_hybrid_step`
  and `run_legacy_step`), handling:
  - Calling `exec_ailang` via env_client
  - Type-check retry loop (see Phase 4)
  - Observation formatting and emission
- Wire into the main step handler (AILANG before bash in both modes,
  matching the priority table: JSON tools > AILANG > bash > final answer):
  - `run_hybrid_step`: after `parse_tool_calls` returns `NoToolCalls`,
    try `extract_ailang` before falling through to final-answer handling
  - `run_legacy_step`: try `extract_ailang` first, then `extract_bash`,
    then treat as final answer. This is a change from the current legacy
    flow (which goes straight to `extract_bash`), but the priority order
    should be consistent across both modes — otherwise the LLM's choice
    of AILANG vs bash depends on which mode is active, which is confusing
- Emit `proposed_ailang` event (parallel to `proposed_cmd`)
- Emit observation with stdout/stderr/exit_code
- Default capability grant: `IO,FS,Process` (matches yolo mode). Configurable
  via `AILANG_SNIPPET_CAPS` env var for restricted environments.
- Extension system interaction (`src/core/ext/`):
  - `dispatch_tool_call` is NOT invoked for AILANG snippets — they are not
    tool calls. AILANG composition is a peer execution mode, not a tool.
  - `dispatch_solver_candidate` IS invoked when the AILANG snippet produces
    output that looks like a final answer (no further code fences). The
    extension system can accept or request continuation as with any response.
  - `dispatch_build_system_prompt` should include the AILANG reference card
    and mode selection guidance (Phase 3 content).

### Phase 3 — Prompt engineering

Files:
- `src/core/prompts.ail`
- `SYSTEM.md`

Changes:
- Add AILANG composition instructions to the system prompt
- Include mode selection guidance, compressed reference card, and few-shot
  examples as specified below

#### Mode selection guidance (draft)

```
EXECUTION MODES (use exactly one per response):

1. JSON tool calls — for structured file operations (ReadFile, Search,
   WriteFile, EditFile) and simple bash commands. Preferred for single
   operations or independent batches.

2. AILANG composition — for multi-step workflows where you need to read
   files, filter results, transform data, or chain operations. Write an
   AILANG program in a ```ailang fenced block. Use this when:
   - You would otherwise need 3+ sequential tool calls
   - You need to filter or aggregate large outputs before reporting
   - You need loops, conditionals, or data transformations on results
   Do NOT use AILANG for simple one-off commands.

3. Bash — for simple shell commands when JSON tools are not available.
   Fallback only.

Use one mode per response. Do not mix fenced block types.
```

#### Compressed reference card (draft, ~2K tokens)

```
AILANG COMPOSITION REFERENCE

The env-server prepends the module declaration. Do not include one.
Your snippet must export a main function.

--- Structure ---
export func main() -> () ! {IO, FS} {
  let x = expr;           -- semicolons in { } blocks, NOT 'in'
  let y = expr;
  println(show(x + y))    -- last expression has no semicolon
}

--- Effects (declare ALL used effects) ---
! {IO}           println, readLine
! {FS}           readFile, writeFile, listDir, fileExists, mkdir
! {IO, FS}       most composition tasks
! {IO, Process}  exec(cmd, args)
! {IO, Net}      httpGet, httpPost

--- Imports (only import what you use) ---
import std/fs (readFile, writeFile, listDir, fileExists, isDir, isFile)
import std/string (contains, split, trim, find, substring, length, join,
                   startsWith, endsWith, toUpper, toLower)
import std/list (map, filter, foldl, length, concat, sortBy, take, drop,
                 nth, any, findIndex, flatMap, forEachE, mapE, filterE)
import std/json (encode, decode, jo, ja, kv, js, jnum, jb,
                 get, getString, getInt, getArray, asString, asArray)
import std/option (Option, Some, None)
import std/result (Ok, Err)
import std/process (exec)

--- Key patterns ---
-- String concat: s1 ++ s2 (NOT concat, NOT +)
-- Print values: println(show(42)), println(str)
-- show() works on ALL types
-- No loops: use map/filter/foldl or recursion
-- Multi-arg funcs: f(a, b) NOT f(a)(b)
-- Lambda: \x. x * 2
-- Multi-param lambda: \acc x. acc + x
-- Pattern match: match xs { [] => ..., x :: rest => ... }
-- Record: {name: "Alice", age: 30}
-- Record update: {person | age: 31}

--- List operations ---
let doubled = map(\x. x * 2, [1, 2, 3])
let evens = filter(\x. x % 2 == 0, xs)
let sum = foldl(\acc x. acc + x, 0, xs)
forEachE(\x. println(x), items)     -- effectful iteration

--- File operations ---
let content = readFile("src/main.ts")
let files = listDir("src/")
writeFile("out.txt", result)
let found = fileExists("config.json")

--- JSON ---
let obj = decode("{\"key\":\"val\"}");
match obj { Ok(j) => getString(j, "key"), Err(e) => ... }
let out = encode(jo([kv("name", js("Alice")), kv("age", jnum(30.0))]))

--- Result store (persist data between snippets) ---
writeFile(".motoko-store/my_key.json", data)    -- save
let prev = readFile(".motoko-store/my_key.json") -- retrieve

--- Common mistakes ---
WRONG: let x = 1 in          RIGHT: let x = 1;     (in { } blocks)
WRONG: list.map(f)            RIGHT: map(f, list)
WRONG: for x in xs            RIGHT: map(\x. ..., xs) or recursion
WRONG: import "std/io"        RIGHT: import std/io (println)
WRONG: concat(a, b)           RIGHT: a ++ b
```

#### Few-shot example (draft)

```
Example: Find all TypeScript files importing 'express', show their paths
and line counts.

```ailang
import std/fs (listDir, readFile)
import std/string (contains, split)
import std/list (filter, length, filterE, forEachE)

export func main() -> () ! {IO, FS} {
  let files = listDir("src/");
  let ts_files = filter(\f. contains(f, ".ts"), files);
  let express_files = filterE(\f. {
    let content = readFile("src/" ++ f);
    contains(content, "import") && contains(content, "express")
  }, ts_files);
  println("Files importing express: " ++ show(length(express_files)));
  forEachE(\f. {
    let lines = split(readFile("src/" ++ f), "\n");
    println("  " ++ f ++ " (" ++ show(length(lines)) ++ " lines)")
  }, express_files)
}
`` `
```

### Phase 4 — Type-check feedback loop

Files:
- `src/core/rpc.ail`

Changes:
- When `ailang check` fails, the error is formatted as a targeted observation
  (see "Targeted error backtracking" below for format)
- The LLM sees the type error and can fix its snippet
- Type-check retry budget rules:
  - First type-check failure: free retry (step not decremented)
  - Second type-check failure: free retry (step not decremented)
  - Third type-check failure: step IS decremented, fall back to bash
  - The 3-retry cap is **per step**, not per session
  - After fallback to bash, normal step counting resumes
  - This bounds the worst case to 3 extra LLM calls per step, not
    3 × 50 = 150 extra calls across the session
- Error feedback uses targeted backtracking (from LLMVM pattern):
  - Parse `ailang check` stderr to extract line number and error category
  - Include only the failing lines (3-5 lines of context), not the full
    snippet — the LLM already has the snippet in conversation history
  - Append the relevant doc section mapped from error category (Strategy 3):

    | Error category        | Doc section to inject              |
    |-----------------------|------------------------------------|
    | Effect mismatch       | Effects reference                  |
    | Unknown function      | Standard Library imports           |
    | Pattern match error   | Pattern Matching syntax            |
    | Let binding error     | Let Bindings: Block vs Expression  |
    | Type mismatch         | Type Annotations reference         |

  - Example feedback shape:

    ```
    AILANG type-check failed (retry 1/3) at line 7:
      let files = listDir("src/");
                  ^^^^^^^
      Error: Effect checking failed — missing effect: FS
      Your main function declares ! {IO} but listDir requires ! {FS}.
      Fix: change the effect signature to ! {IO, FS}
    ```

### Phase 5 — Z3 verification for pure snippets (optional)

Files:
- `src/tui/src/env-server.ts`
- `src/core/rpc.ail`

Changes:
- If the snippet contains `requires`/`ensures` contracts:
  - Run `ailang verify <temp>.ail` before execution
  - If verification fails, feed counterexample back to LLM
  - If verification passes, note it in the observation ("verified by Z3")
- This is opt-in and only applies to pure functions

---

## Optimizing AILANG Doc Injection

The `ailang-v0.9.0-docs.md` file is ~22K tokens. Injecting it wholesale into
the system prompt would consume context that should be used for reasoning.
This is exactly the problem Monty was designed to solve (Logfire's 40+ tool
descriptions consumed the context window).

Four strategies, from simplest to most sophisticated:

### Strategy 1: Compressed reference card (~2K tokens)

Write a compact AILANG cheat sheet that covers only what an agent needs for
composition snippets. See Phase 3 for the full draft reference card.

This covers 90% of composition use cases. Inject it always.

### Strategy 2: On-demand docs via help tool (Monty pattern)

Add an `AilangHelp` tool that the LLM can call to retrieve specific sections
of the AILANG docs:

```json
{"tool_calls": [
  {"id": "h1", "tool": "AilangHelp", "topic": "json parsing"}
]}
```

The brain looks up the relevant section of `ailang-v0.9.0-docs.md` and returns
it as a tool result. The LLM pays the token cost only when it needs the docs.

Implementation: a native brain tool (no delegation needed). The docs file is
loaded once at startup and sectioned by heading. Topic matching can be simple
string containment on section headings.

### Strategy 3: Progressive disclosure

Start with the compressed reference card in the system prompt. If the LLM's
first AILANG snippet fails type-checking, include the relevant doc section
in the error feedback:

```
Type error: Effect checking failed for function 'main'
Missing effects: FS

AILANG reference — Effects:
Every function performing I/O must declare effects in the signature.
func greet(name: string) -> () ! {IO} = println("Hello " ++ name)
Common effects: IO (print), FS (readFile/writeFile), Net (httpGet), ...
```

This is zero-cost when the LLM gets it right, and self-correcting when it
doesn't. The brain maps type-error categories to doc sections:

| Error category        | Doc section to inject              |
|-----------------------|------------------------------------|
| Effect mismatch       | Effects reference                  |
| Unknown function      | Standard Library imports           |
| Pattern match error   | Pattern Matching syntax            |
| Let binding error     | Let Bindings: Block vs Expression  |
| Type mismatch         | Type Annotations reference         |

### Strategy 4: Cached few-shot examples (trajectory cache integration)

Extend the existing SharedMem trajectory cache to store successful AILANG
snippets keyed by task-type similarity:

```
Task: "find files with TODO comments and count by directory"
Cached snippet: (the AILANG code that worked last time)
```

On a new composition task, the brain retrieves a similar cached snippet and
includes it as a few-shot example. This is more effective than docs because
the LLM sees working code, not reference material.

This integrates naturally with the existing `cache.ail` infrastructure. The
hint injection in `with_cache_hint` already does this for bash trajectories.

### Recommended approach

Combine strategies 1 + 3:

- Always inject the ~2K compressed reference card
- On type-check failure, inject the relevant doc section
- Total token cost when things work: ~2K (negligible)
- Total token cost on first failure: ~2K + ~500 per error section
- No new tools, no new protocol, no new infrastructure

Add strategy 4 (cached snippets) once the basic flow is working, since the
trajectory cache infrastructure already exists.

Reserve strategy 2 (help tool) for a future phase if empirical evaluation
shows the LLM needs broader doc access than progressive disclosure provides.

---

## Module Declaration Strategy

Every AILANG file needs a `module` declaration matching its path. For temp
snippets, the env-server must handle this transparently:

Option A: Unique temp path per execution

```
/tmp/motoko-snippets/tmp/snippet_3_1712841600.ail
module tmp/snippet_3_1712841600
```

The env-server generates a unique filename per execution using step number
and timestamp (e.g., `snippet_<step>_<epoch>`). It strips any `module`
declaration the LLM includes and prepends the correct one matching the
generated path. This avoids race conditions if multiple sessions run
concurrently or if the env-server processes overlapping requests.

Option B: Fixed temp path

```
/tmp/motoko-snippets/tmp/snippet.ail
module tmp/snippet
```

Simpler, but creates a race condition under concurrency.

Recommendation: Option A. The filename generation is trivial, and it
eliminates a class of bugs. The LLM should never need to write a `module`
declaration — the env-server always handles it.

---

## JSONL Protocol Extensions

New event types for the runtime-to-TUI protocol:

### Runtime -> TypeScript (stdout)

```json
{"type": "proposed_ailang", "step": 3, "code": "import std/fs ..."}
{"type": "ailang_check", "step": 3, "passed": false, "errors": "...", "attempt": 1, "max_attempts": 3}
{"type": "ailang_check", "step": 3, "passed": false, "errors": "...", "attempt": 2, "max_attempts": 3}
{"type": "ailang_check", "step": 3, "passed": true, "attempt": 3, "max_attempts": 3}
{"type": "obs", "step": 3, "stdout": "...", "stderr": "...", "exit_code": 0}
```

The `attempt` and `max_attempts` fields let the TUI display progress
(e.g., "type-check failed (1/3)") and distinguish the final failure
("type-check failed (3/3), falling back to bash") from recoverable ones.

### TUI rendering

The TUI renders `proposed_ailang` events with AILANG syntax highlighting
(or generic code block rendering). The `ailang_check` event shows a
pass/fail indicator before execution output appears.

---

## Interaction with Existing Execution Modes

The three execution modes coexist:

| Mode              | Trigger                        | Execution path          |
|-------------------|--------------------------------|-------------------------|
| JSON tool calls   | `parse_tool_calls` succeeds    | Hybrid native/delegated |
| Bash (legacy)     | `extract_bash` finds a block   | POST /exec              |
| AILANG composition| `extract_ailang` finds a block | POST /exec-ailang       |

Priority order in the brain's step handler:

1. Try `parse_tool_calls` (JSON tools)
2. If `NoToolCalls`, try `extract_ailang`
3. If `None`, try `extract_bash` (legacy fallback)
4. If `None`, treat as final answer

Fence collision rules:

- Only one execution mode fires per response. The first match in priority
  order wins; lower-priority extractions are not attempted.
- If a response contains both ` ```ailang ``` ` and ` ```bash ``` ` fences,
  AILANG wins (priority 2 beats priority 3). The bash block is ignored.
- If a response contains a JSON tool block alongside an AILANG fence,
  JSON tools win (priority 1 beats priority 2). The AILANG block is ignored.
- The system prompt must instruct the LLM to use exactly one execution mode
  per response. Fence collisions are a fallback, not the design.

This ordering means:
- JSON tools remain the primary structured path
- AILANG composition is available when the LLM chooses it
- Bash remains as a simple fallback
- The LLM naturally gravitates to the best tool for each step

---

## Security Model

### Effect-based capability control

The brain grants effects per-snippet via the `--caps` flag. The LLM cannot
escalate: declaring `! {Net}` in a snippet run with `--caps IO,FS` will fail
at type-check time.

### FS sandbox

`AILANG_FS_SANDBOX` jails all file operations to the workdir. Path traversal
is handled by the runtime, not by the snippet.

### No SharedMem access

Composition snippets run in a fresh `ailang run` invocation. They do not share
the brain's SharedMem state. The snippet cannot read or modify the trajectory
cache, model state, or any brain-internal data.

### Timeout enforcement

The env-server enforces execution timeout. Infinite recursion or long-running
snippets are killed after the configured timeout (default: 30 seconds).

### Comparison to Monty

| Dimension          | Monty                        | AILANG composition          |
|--------------------|------------------------------|-----------------------------|
| Capability model   | External functions whitelist | Effect system + --caps flag |
| Enforcement        | Runtime                      | Compile-time (type-check)   |
| FS access          | Blocked by default           | AILANG_FS_SANDBOX           |
| Network access     | Blocked by default           | Only if --caps includes Net |
| Process execution  | Not available                | Only if --caps has Process  |
| Verification       | None                         | Z3 for pure functions       |

---

## Testing Strategy

### Unit tests (parse.ail)

- `extract_ailang` with valid fences
- `extract_ailang` with missing closing fence
- `extract_ailang` returning `None` for non-AILANG fences
- `extract_ailang` ignoring AILANG blocks inside `<think>` spans
- Priority ordering: JSON tools > AILANG > bash > final answer

### Integration tests (env-server)

- `POST /exec-ailang` with valid snippet → stdout
- `POST /exec-ailang` with type error → check_passed: false, check_errors populated
- `POST /exec-ailang` with effect violation → check failure
- `POST /exec-ailang` with timeout → killed, exit_code nonzero
- `POST /exec-ailang` with FS sandbox → paths resolved correctly
- `.motoko-store/` created at session start, cleaned up at session end
- AILANG snippet can writeFile/readFile under `.motoko-store/` successfully
- `.motoko-store/` contents do not leak across sessions

### End-to-end tests

- LLM writes AILANG snippet → type-checks → executes → observation returned
- LLM writes AILANG snippet with type error → error feedback → LLM fixes →
  executes on retry
- LLM switches between bash and AILANG within same session
- Multi-step session with AILANG composition reducing step count vs baseline

---

## Success Criteria

- AILANG snippets execute in a sandboxed environment with effect-controlled
  capabilities
- Type-check failures are caught before execution and fed back to the LLM
- The LLM can compose multiple file/search/bash operations into a single step
- Token usage for intermediate data is reduced (data stays server-side)
- Step budget consumption is reduced for multi-operation tasks
- The compressed reference card is sufficient for most composition tasks
  (~2K tokens, not 22K)
- Progressive doc disclosure handles edge cases without constant token cost
- The feature coexists cleanly with JSON tool calls and legacy bash
- No new external dependencies (AILANG runtime is already present)
- Type-check error feedback is targeted (failing lines + relevant doc section,
  not full snippet echo)
- Session-scoped result store allows multi-step AILANG workflows without
  re-executing expensive operations or bloating the context window

---

## Influences

This plan draws on two external projects:

- **Pydantic Monty** (pydantic/monty) — the core inspiration: replace tool
  menus with sandboxed code execution. AILANG's effect system and type checker
  provide a stronger sandbox than Monty's external-function model.
- **LLMVM** (9600dev/llmvm) — two specific patterns adopted: targeted error
  backtracking (integrated into Phase 4) and session-scoped result persistence
  (integrated into Phase 1 as `.motoko-store/` under the FS sandbox).

---

## Open Questions

1. **Step budget accounting**: Should a successful AILANG composition count as
   1 step or as N steps (where N is the number of operations composed)?
   Recommendation: 1 step. The LLM earned the efficiency.

2. **Output size limits**: AILANG snippets can produce arbitrarily large stdout.
   Should the env-server truncate output before returning to the brain?
   Recommendation: Yes, same truncation policy as bash execution.

3. **Import restrictions**: Should the brain restrict which AILANG modules the
   LLM can import? E.g., block `std/ai` to prevent the snippet from making
   its own LLM calls?
   Recommendation: Yes, control via `--caps`. `std/ai` requires `AI` cap,
   which the brain should not grant to composition snippets.

4. **Parallel execution**: AILANG's `mapE` is sequential. For true parallel
   composition (like Monty's `asyncio.gather`), AILANG would need a parallel
   combinator. This is a language-level feature request, not a Motoko concern.
   For now, sequential composition still saves steps vs sequential bash.

5. **Snippet persistence**: Should successful snippets be saved for
   reproducibility? The trajectory cache already stores task-level outcomes.
   Snippet-level caching is a natural extension but not required for Phase 0-3.

---

## Decision

AILANG as a composition language is architecturally sound and practically
viable given that the entire core runtime was authored by LLMs. The effect
system provides a stronger sandbox than Monty's external-function model, the
type-checker provides a pre-execution safety gate that Python cannot match,
and the zero-dependency integration eliminates the operational complexity of
shipping a Rust/Python sidecar.

The compressed reference card + progressive doc disclosure strategy solves
the token cost problem without sacrificing LLM fluency.

Implementation should proceed in phases, with Phase 0-2 (parsing, env-server
endpoint, brain wiring) deliverable independently of prompt optimization.
Phase 3 (prompt engineering) is where empirical evaluation determines the
right doc injection strategy.
