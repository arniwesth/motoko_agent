# Brain-Owned Tool Execution

## Purpose

Move normal tool execution into the AILANG brain itself, using native process and
stream primitives instead of HTTP `/exec` through `tui/src/env-server.ts`.

This plan accepts the following conditions as deliberate architectural choices:

- Drop `env-server` for normal tool execution
- Use native AILANG process execution with runtime-supported working-directory semantics
- Stream output incrementally
- Keep tool interfaces typed at the AILANG boundary
- Accept the extra implementation complexity in the brain

The TUI remains the presentation and control layer: it renders events, forwards
user input, and sends `abort` / `model_change`. The brain owns reasoning, tool
lifecycle, process state, truncation policy, and typed observations.

---

## Why This Path

AILANG v0.9.0 already has the primitives needed for a serious execution runtime:

- `std/process.exec` for synchronous typed execution with stdout, stderr, timeout,
  truncation, and resolved path
- `std/process` managed stdin handles for write-only subprocesses
- `std/stream.asyncExecProcess` for incremental stdout-only streaming
- `std/stream` for multi-source event loops
- `std/crypto` for SHA-256 hashes of bounded outputs
- `std/json` for structured parsing and typed extraction

Keeping tool execution in the brain means those capabilities can be used directly.
If execution remains brain-owned, the current HTTP `/exec` model is the wrong
abstraction: it collapses process lifecycle into one opaque request/response and
throws away typed process results, runtime-enforced timeouts/output limits, and
stdout streaming.

This plan therefore does not preserve `exec_in(url, cmd)`. It replaces that model.

---

## Thesis Alignment

If the project thesis is only "reasoning lives in AILANG", the TUI-dispatch plan is
enough. If the thesis is stronger — "the core agent runtime is inspectable,
typed, and controllable in AILANG" — then execution belongs in the brain too.

This plan chooses the stronger thesis.

The tradeoff is real:

- Better architecture, stronger semantics, richer observability
- More complexity in `swe/*.ail`
- Larger effect surface: `Process`, `Stream`, `IO`, `AI`, `SharedMem`, `Env`, `FS`, `Clock`

That complexity is acceptable here because it is in service of the project's main
research goal, not incidental product plumbing.

---

## Architectural Shape

### Before

```
rpc_loop
  → call(fmt_msgs)          [AI effect]
  → extract_bash(response)  [pure]
  → exec_in(url, cmd)       [Net effect — HTTP to env-server]
  → fmt_obs(result)         [pure]
  → recurse
```

### After

```
rpc_loop
  → call(fmt_msgs)                      [AI effect]
  → parse_tool_calls(response)          [pure — JSON to ADTs]
  → run_tool_batch(batch)               [Process + Stream effects]
  → emit tool_start / tool_chunk / ...  [IO effect]
  → collect bounded final results       [pure + Process/Stream bookkeeping]
  → fmt_batch_obs(results)              [pure]
  → recurse
```

The brain becomes the system of record for tool execution. The TUI no longer
dispatches commands. It only renders what the brain emits.

---

## State of the Art Principles Applied

This plan intentionally adopts the following practices from modern tool-calling
systems and coding agents:

### 1. Correlation IDs are mandatory

Every tool call has a stable `id`. Every chunk, status event, and final result
references that `id`.

Why:

- Traceability in long sessions
- Robust matching independent of array order
- Future support for scheduler changes, retries, or partial re-execution

### 2. Tool interfaces are semantic, not shell-shaped

`bash` remains available, but named tools are first-class typed variants, not bash
shims. The model should observe typed results, not parse `grep` or `sed` output.

### 3. Structured invocation where the runtime supports it

Commands should not be encoded as `cd ... && cmd` unless there is no better runtime
option. In the current runtime, `std/process.exec` uses the runtime working
directory / sandbox semantics, not a per-call cwd field. The plan must therefore
model cwd as brain state and use relative paths from the current runtime working
directory unless the runtime is extended later.

### 4. Incremental streaming

Long-running tools emit chunks while running. The user sees progress without waiting
for a giant final blob. In the current runtime, this applies to stdout only via
`std/stream.asyncExecProcess`.

### 5. Bounded output with explicit truncation metadata

Tool output must be capped before it enters the model context. Every clipped result
must say that it was clipped and carry stable metadata about the full output.

### 6. Machine-readable tool schema

The system prompt must include an explicit schema block describing tool JSON, not
just prose and examples.

### 7. Typed boundary in AILANG

The translation from JSON tool payloads to typed ADTs happens once in the parser.
After that point, dispatch is typed and exhaustive via pattern matching.

---

## Tool Model

## Phase 1 tool set

Keep `bash` for migration, but align it with current runtime support:

```ailang
export type ToolCallReq
  = Bash({
      id:           string,
      cmd:          string
    })
  deriving (Eq)
```

This is intentionally a record-wrapped ADT constructor:

- The outer tool choice stays typed
- The inner payload stays structured
- New fields can be added without positional churn

## Phase 2+ named tools

Named tools should be additive and semantic:

```ailang
export type ToolCallReq
  = Bash({ id: string, cmd: string })
  | ReadFile({ id: string, path: string, start: int, end: int })
  | Search({ id: string, pattern: string, dir: string, context: int })
  | WriteFile({ id: string, path: string, content: string })
  | RunTests({ id: string, cmd: string })
  deriving (Eq)
```

The model still emits JSON. `parse_tool_calls` translates JSON to this ADT.

---

## Result Model

Phase 1 keeps `bash` results shell-like because `std/process.exec` naturally yields
stdout/stderr/exit code, but even there the transport must carry proper metadata.

```ailang
export type ToolResultMeta = {
  truncated:          bool,
  stdout_bytes:       int,
  stdout_total_bytes: int,
  stderr_bytes:       int,
  stderr_total_bytes: int,
  stdout_sha256:      string,
  stderr_sha256:      string
}

export type ToolResultItem
  = BashResult({
      id:        string,
      cmd:       string,
      stdout:    string,
      stderr:    string,
      exit_code: int,
      meta:      ToolResultMeta
    })
  | ReadFileResult({
      id:         string,
      path:       string,
      content:    string,
      line_count: int,
      truncated:  bool,
      sha256:     string
    })
  | SearchResult({
      id:      string,
      pattern: string,
      matches: [{
        path:        string,
        line_number: int,
        line_text:   string,
        context:     [string]
      }]
    })
  | WriteFileResult({
      id:            string,
      path:          string,
      bytes_written: int,
      sha256:        string
    })
  | RunTestsResult({
      id:        string,
      cmd:       string,
      stdout:    string,
      stderr:    string,
      exit_code: int,
      passed:    int,
      failed:    int,
      failures:  [{ test: string, message: string }],
      meta:      ToolResultMeta
    })
  deriving (Eq)
```

The model-facing observation formatter should expose only the fields that matter for
the next reasoning step. The raw event stream can still carry fuller detail for UI.
Hashes should be computed with `std/crypto.sha256Hex` / `sha256Bytes`.

---

## Tool Schema in the Prompt

The prompt must carry a schema block. Not provider-native tool calling, but a
project-local JSON schema contract.

Phase 1 example:

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "required": ["id", "tool"],
    "properties": {
      "id":   { "type": "string" },
      "tool": { "enum": ["bash"] },
      "cmd":  { "type": "string" }
    }
  }
}
```

Rules in prompt:

- Use unique `id` for each tool call in a step
- Use relative paths from the current working directory unless the runtime is extended
- Batch only independent calls
- Prefer named tools when available
- Plain text with no JSON array is the completion signal

---

## Streaming Model

The brain should emit incremental lifecycle events to the TUI.

### Brain → TUI events

- `tool_batch_start`
- `tool_call_start`
- `tool_stdout_chunk`
- `tool_call_finish`
- `tool_batch_finish`
- `warning`
- `thinking`
- `done`
- `error`

Example:

```json
{ "type": "tool_call_start", "step": 4, "id": "call-2", "tool": "bash",
  "cmd": "pytest tests/test_parse.py" }
```

```json
{ "type": "tool_stdout_chunk", "step": 4, "id": "call-2", "text": "=== test session starts ===\n" }
```

```json
{ "type": "tool_call_finish", "step": 4, "id": "call-2", "exit_code": 1,
  "truncated": true, "stdout_total_bytes": 18293, "stdout_sha256": "..." }
```

This preserves inspectability and gives the user immediate feedback. Stderr is not
streamed in the current runtime; it is available from synchronous `std/process.exec`
results only.

### Streaming policy

- Chunks are for UI visibility, not directly appended to the LLM context
- The brain maintains bounded in-memory accumulators per running tool
- Final model-facing observations are derived from the bounded accumulators
- Chunk events may be coalesced for UI smoothness, but final result metadata is authoritative

---

## Output Limits and Truncation Policy

This is not optional. It is part of correctness.

### Requirements

- Per-call caps on `stdout` and `stderr`
- Separate caps for streamed display and model-facing final observation
- Tail bias for `stderr` when clipped in synchronous results
- Prefix-only or prefix+suffix policy for huge `stdout`
- Stable hashes of full stdout/stderr when clipped

### Suggested initial policy

- `stdout` model cap: 16 KB per tool
- `stderr` model cap: 8 KB per tool
- UI chunk cap: 2 KB per event
- Keep head for `stdout`, keep tail for `stderr`
- Store `*_total_bytes` and `*_sha256` always

### Reason

Without this, one `cat` or recursive search can destroy the context window in a
single step even if the tool runtime itself behaved correctly.

---

## Cancellation Model

Cancellation must be brain-owned too.

### Semantics

- `abort` from stdin is consumed by the brain
- If no tools are running: abort at the next loop boundary, as today
- If tools are running in streaming mode: the brain closes active stream sources
- If tools are running synchronously via `std/process.exec`: cancellation is observed
  at the next loop boundary; hard interruption is not assumed

### Implementation direction

Use a tool runner state that tracks active stream sources by
tool `id`. On abort:

- mark batch as aborted
- close or stop observing active stdout stream sources
- emit `tool_call_finish` with `aborted: true` where appropriate
- emit final session error `aborted`

The key property is that the brain owns cleanup within what the runtime clearly
supports today. The plan should not assume a general AILANG-level kill API for all
running subprocesses.

---

## Concurrency Model

The brain may still execute a batch in parallel. The important shift is that
parallelism is now internal runtime behavior, not TUI behavior.

### Invariant

One LLM step may spawn N tool calls. Those N calls are the only tool work in flight
for that reasoning step.

### Scheduler policy

Initial implementation:

- start all read-only tools immediately
- run most normal tools via synchronous `std/process.exec`
- use `std/stream.asyncExecProcess` only for stdout-streaming long-running commands
- collect stdout streams concurrently where streaming is used
- wait for all calls in the batch to finish or abort

Future refinement:

- classify tools as read-only vs mutating
- allow wider parallelism for read-only tools
- serialize mutating tools when needed

This plan does not require a permission model, but it does require a scheduler model.

---

## Parser Semantics

Keep the lessons from the first plan:

- explicit parse-status ADT
- malformed attempted tool JSON is not treated as completion
- unsupported tools are preserved and surfaced as warnings
- machine-readable schema in prompt
- code fences tolerated

Suggested parse result:

```ailang
export type ParseToolCalls
  = NoCalls
  | Calls({ supported: [ToolCallReq], unsupported: [UnsupportedToolCall] })
  | ParseError(string)
  deriving (Eq)
```

Unsupported calls should still produce `warning` events and corrective feedback to
the model. That insight transfers directly from the first plan.

---

## CWD Tracking

Keep cwd as brain state.

### Rules

- The brain tracks current cwd conversationally
- `parse_cwd` remains useful only as best-effort brain state update after commands
  that intentionally change directory
- The brain's tracked `cwd` informs prompting and relative-path use for the next step

This avoids claiming unsupported per-call cwd semantics while preserving the
conversational shell model the agent already uses.

---

## TUI Role After the Change

The TUI becomes thinner, but not trivial.

Responsibilities:

- spawn the brain
- render stream events and final observations
- forward `abort`, `model_change`, and follow-up user messages
- preserve session history in the UI

Responsibilities removed:

- dispatching tools
- HTTP `/exec` for normal operation
- batching policy
- correlating tool calls to results

`tui/src/env-server.ts` should be removed from the normal execution path. It may be
kept temporarily only for legacy compatibility during cutover, but the target state
is that it is no longer part of the main agent runtime.

---

## AILANG Runtime Shape

This plan should use the native runtime directly:

- `std/process.exec`
- `std/process.spawnProcess`
- `std/process.writeProcessStdin`
- `std/process.closeProcessStdin`
- `std/crypto.sha256Hex`
- `std/crypto.sha256Bytes`
- `std/stream.asyncExecProcess`
- `std/stream.selectEvents`
- `std/stream.asyncReadStdinLines`

Practical implication:

- normal tool execution should be built on `std/process.exec` with runtime-wide process timeout/output settings
- streaming should be an opt-in execution mode for stdout-heavy or long-running tools
- stdin command handling (`abort`, `model_change`) and subprocess stream handling can
  live in one event-driven coordination layer instead of `readLine()` polling plus
  opaque `exec_in()`

This is a major architectural difference from the current loop and should be treated
as such.

---

## Protocol Simplification

One benefit of brain-owned execution is that the stdin/stdout protocol between brain
and TUI becomes simpler.

### Removed

- `proposed_cmd`
- `tool_calls`
- `tool_results`

### Added

- `tool_batch_start`
- `tool_call_start`
- `tool_stdout_chunk`
- `tool_call_finish`
- `tool_batch_finish`

There is no longer a control-plane round-trip for tool dispatch. The TUI is passive.

---

## Error Handling

### Process-level failures

Represent directly:

- spawn failure
- non-zero exit code
- timeout
- aborted
- stream error

These should become typed execution outcomes, not synthetic stringly failures.
For synchronous tools, use `std/process.ProcessError` and `ProcessOutput` directly
where possible.

### Unsupported tools

Keep the first plan's warning behavior:

- emit `warning`
- do not silently drop
- feed correction back to model

### Protocol mismatches

Because TUI no longer sends tool results, an entire class of step-mismatch bugs
disappears. That is a concrete simplification advantage of brain-owned execution.

---

## Suggested New Types

```ailang
export type ToolStatus
  = Running
  | Finished(int)
  | Aborted
  | TimedOut
  | SpawnFailed(string)
  | StreamFailed(string)
  deriving (Eq)

export type RunningTool = {
  id:            string,
  req:           ToolCallReq,
  stdout_acc:    bytes,
  stderr_acc:    bytes,
  stdout_total:  int,
  stderr_total:  int,
  status:        ToolStatus
}
```

The exact shape can differ, but the important point is explicit runtime state in the
brain, not implicit process state hidden behind `/exec`.

---

## Prompt Changes

The system prompt should be updated to teach:

- explicit JSON schema
- unique IDs per call
- current-working-directory semantics
- batching rules
- named-tool preference once available
- plain-text completion

It should also discourage giant outputs:

- prefer `read_file` over `bash cat` once `read_file` exists
- prefer bounded searches over recursive shell dumps
- read only the needed region of a file

That is state-of-the-art agent prompting: tool contract plus tool usage discipline.

---

## Phased Implementation

## Phase 1 — Types

Files:

- `swe/types.ail`

Changes:

- Replace `ExecResult`-only worldview with typed tool request/result ADTs
- Add correlation IDs, truncation metadata, runtime status types
- Remove `env_url` from `AgentState`

## Phase 2 — Parser

Files:

- `swe/parse.ail`

Changes:

- Replace `extract_bash`-only parsing with JSON tool parsing
- Preserve unsupported tools with warnings
- Add inline parser tests

## Phase 3 — Native tool runtime

Files:

- new `swe/tool_runtime.ail`

Changes:

- Synchronous execution wrappers over `std/process.exec`
- Stdout-streaming wrappers over `std/stream.asyncExecProcess`
- Truncation enforcement
- Correlated tool lifecycle events
- Cancellation support

This module is the core of the architecture.

## Phase 4 — rpc_loop rewrite

Files:

- `swe/rpc.ail`

Changes:

- Replace `exec_in()` with `run_tool_batch()`
- Emit stdout stream events when streaming mode is used
- Append bounded typed observations to message history
- Remove `Net` effect
- Add `Process` and `Stream` effects

## Phase 5 — Prompt rewrite

Files:

- `swe/prompts.ail`

Changes:

- Schema-bearing tool instructions
- ID and current-working-directory requirements
- Batching guidance
- Named-tool guidance for later phases

## Phase 6 — TUI simplification

Files:

- `tui/src/brain.ts`
- `tui/src/ui.ts`
- `tui/src/env-server.ts`

Changes:

- Stop dispatching tools
- Render streaming events
- Remove `env-server` from the normal path

## Phase 7 — Named tools

Files:

- `swe/types.ail`
- `swe/tool_runtime.ail`
- `swe/prompts.ail`

Changes:

- Add `ReadFile`, `Search`, `WriteFile`, `RunTests`
- Implement typed result construction
- Prefer semantic tools over bash where possible

---

## What Carries Over from the First Plan

These insights still apply:

- explicit parse-status ADT
- unsupported tool warnings, never silent drop
- machine-readable tool schema
- correlation IDs
- bounded output with truncation metadata
- typed AILANG boundary
- batching as a first-class concept
- model-change interleaving must not be dropped while work is in flight

These do not carry over:

- TUI-executed batches
- `tool_calls` / `tool_results` round-trip
- positional result matching
- HTTP `/exec`

---

## Testing

Existing tests must pass. New tests required:

### `swe/parse.ail`

- valid single-call JSON
- valid multi-call JSON
- fenced JSON
- malformed JSON -> `ParseError`
- unsupported tool -> `warning` path

### `swe/tool_runtime.ail`

- single bash process runs via `std/process.exec`
- stdout streaming emits chunk events
- synchronous execution returns stderr
- timeout produces `TimedOut`
- abort closes active stdout stream sources
- truncation metadata is correct for oversized output
- correlation IDs survive from request to finish event

### Integration

- `model_change` during running process is preserved and applied to next LLM call
- multi-tool batch runs concurrently
- TUI renders chunk events without dispatching tools
- legacy `env-server` is not required for normal run

---

## Success Criteria

- `swe/env_client.ail` is deleted from the normal runtime path
- Brain effect signature contains `Process` and `Stream`, not `Net`
- Tool execution works with current-runtime working-directory semantics, not HTTP `/exec`
- Long-running commands stream visible progress to the TUI
- Oversized outputs are clipped before entering the LLM context
- Every tool lifecycle event/result is correlated by explicit `id`
- Unsupported tool requests are visible to the user and corrected in-model
- Named tools return typed semantic payloads
- The TUI no longer performs normal tool dispatch

---

## Decision

If the project wants the strongest possible AILANG-centric architecture, this is the
plan to follow. It is more complex than TUI dispatch, but it uses AILANG for the
runtime concerns that matter instead of reducing the brain to an LLM wrapper around
opaque shell RPC.

---

## Future Research Direction

This project is explicitly a research project, so the current-runtime constraints
should not only be worked around; some of them should become targets for runtime
improvement. The revised plan above is grounded in what AILANG clearly supports
today. The roadmap below describes the runtime work that would make the brain-owned
architecture materially cleaner and stronger.

### Tier 1 — High-leverage runtime extensions

These changes are relatively contained and would significantly improve the current
brain-owned plan without requiring a full subprocess redesign.

#### 1. Per-call working directory

Today:

- `std/process.exec` uses the runtime working directory / sandbox
- `asyncExecProcess` does not expose per-call cwd

Research target:

- extend process/stream builtins to accept an optional `cwd`
- resolve it safely relative to `AILANG_FS_SANDBOX`
- make cwd explicit at the AILANG call site rather than implicit in runtime state

Impact:

- removes one of the largest remaining mismatches between conversational shell state
  and actual execution semantics
- reduces reliance on best-effort `parse_cwd`

#### 2. Per-call timeout and output limits

Today:

- timeout and max-output are runtime-wide `ProcessContext` settings

Research target:

- allow per-call overrides with safe defaults inherited from `ProcessContext`
- keep existing runtime-wide ceilings as upper bounds

Impact:

- read/search/test commands can have different execution budgets
- better control over context growth and runaway tools

#### 3. AILANG-level process termination

Today:

- the runtime can kill processes internally
- AILANG code does not have a clear general-purpose kill/terminate API

Research target:

- expose `terminateProcess` / `killProcess` for managed process handles
- define semantics for post-exit calls, repeated termination, and cleanup

Impact:

- makes abort semantics much cleaner
- reduces the gap between synchronous and streaming execution modes

### Tier 2 — Strong runtime improvements

These changes would make the brain-owned plan not just viable, but clearly superior
to TUI dispatch for this repo's thesis.

#### 4. Stderr streaming

Today:

- `asyncExecProcess` streams stdout only
- stderr is discarded in stream mode

Research target:

- add stderr streaming as a first-class runtime feature
- either via distinct event variants or explicit stream labels
- define ordering and buffering semantics between stdout and stderr

Impact:

- long-running failing commands become observable without falling back to
  synchronous execution
- tool streaming becomes useful for tests/builds, not just stdout-heavy commands

#### 5. Unified subprocess API

Today:

- `exec` gives final typed result but no streaming
- `asyncExecProcess` gives stdout streaming but no stderr/final result surface
- `spawnProcess` gives writable stdin but discards stdout/stderr

Research target:

- design one coherent subprocess abstraction that supports:
  - structured options (`cwd`, timeout, output caps, env)
  - optional stdin writes
  - stdout/stderr streaming
  - final exit/result capture
  - cancellation/termination

Impact:

- removes the hybrid-runtime awkwardness in the current revised plan
- gives AILANG a serious process model suitable for agents, tooling, and pipelines

### Tier 3 — Research-grade agent runtime features

These go beyond “fix the shortcomings” and move toward a genuinely advanced agent
runtime.

#### 6. Typed execution schemas at the runtime boundary

Research target:

- support runtime-native structured tool outputs beyond raw process text
- let AILANG helpers return typed payloads with standard metadata envelopes

Impact:

- tighter integration between typed tools and agent reasoning
- less parsing burden on the LLM

#### 7. Native bounded-stream collectors

Research target:

- provide standard runtime helpers for:
  - head/tail truncation
  - byte counting
  - rolling hashes
  - chunk coalescing

Impact:

- avoids reimplementing output management in every agent/tool runtime
- makes bounded streaming a runtime competency, not app-specific glue

### Research sequencing

If the project wants to explore this space incrementally, the recommended order is:

1. per-call `cwd`
2. per-call timeout/output overrides
3. AILANG-level termination
4. stderr streaming
5. unified subprocess API

That ordering captures the highest-value improvements first while preserving a path
to the more ambitious runtime work later.

### Why this belongs in the plan

The revised brain-owned plan should be understood as:

- operational plan for what AILANG supports today
- research roadmap for the runtime changes that would make this architecture truly
  compelling

That dual framing is appropriate for this repo. The immediate implementation should
stay honest about current constraints, while the research agenda should be explicit
about which runtime investments could change the architectural answer later.
