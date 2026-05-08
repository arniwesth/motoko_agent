# Hybrid Tool Execution

## Purpose

Combine the strongest parts of the two existing plans into one architecture that is
better matched to current AILANG constraints.

Core idea:

- The brain owns the tool model, tool parsing, batching, IDs, schemas, warnings,
  observation shaping, and overall step control.
- The brain executes tools natively when AILANG supports that execution mode well.
- The TUI executes only the subset of tool work that current AILANG does not yet
  support cleanly.

This is not “two systems at once.” It is one tool system with two execution
backends:

- `native` backend: executed directly inside the AILANG brain
- `delegated` backend: executed by the TUI

The brain remains the system of record.

---

## Why Hybrid

The first plan is cleaner for delivery because TypeScript can handle process
execution, per-call cwd, cancellation, and richer scheduling more easily.

The revised second plan is stronger for thesis alignment because more of the real
agent runtime lives inside AILANG.

Current AILANG support makes the pure brain-owned plan weaker than it first seemed:

- `std/process.exec` is strong for synchronous execution
- `std/stream.asyncExecProcess` is useful for stdout-only streaming
- but the runtime does not clearly support per-call cwd, stderr streaming, or a
  general AILANG-level kill API

That creates a natural split:

- keep what AILANG already does well inside the brain
- delegate only the execution modes that are currently awkward or unsupported

This gives a better tool system today while preserving a research path toward more
brain-owned execution over time.

---

## Architectural Principle

The tool system should be unified at the semantic level and split only at the
execution backend level.

The model should not need to reason about “brain tool” vs “TUI tool” most of the
time. It should reason about tools. Backend choice is a runtime concern owned by the
brain.

So the architecture is:

```
LLM JSON tool calls
  → parse_tool_calls()                  [brain]
  → typed ToolCallReq ADT               [brain]
  → choose execution backend per call   [brain]
  → run native calls in AILANG          [brain]
  → emit delegated batch to TUI         [brain → TUI only when needed]
  → collect results into one typed view [brain]
  → fmt_batch_obs()                     [brain]
  → recurse
```

The TUI is not the default tool runtime. It is a capability extension layer.

---

## What the Brain Owns

The following responsibilities should remain entirely in the brain:

- parsing tool JSON into typed ADTs
- schema-bearing prompt construction
- correlation IDs
- unsupported-tool warnings
- batching rules
- execution backend choice
- observation formatting
- message-history updates
- cwd conversational state
- final “what the model sees” tool result shaping

This is the load-bearing decision. Even when execution is delegated, the brain still
owns the semantics.

---

## What Runs Natively Today

These should be executed directly inside AILANG now.

### 1. Semantic file tools

- `ReadFile`
- `Search`
- `WriteFile`

Why:

- AILANG already has strong FS support
- these tools benefit most from typed inputs and typed outputs
- keeping them native eliminates pointless shell parsing

Suggested result shapes:

```ailang
export type ToolResultItem
  = ReadFileResult({
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
```

### 2. Synchronous process execution

- `BashExec`
- `RunTests` in non-streaming mode

Why:

- `std/process.exec` already gives typed stdout/stderr/exit/truncation/resolvedPath
- timeout and output-limit enforcement already exist in the runtime
- this is enough for many commands

Suggested request shape:

```ailang
export type ToolCallReq
  = BashExec({ id: string, cmd: string, args: [string] })
  | RunTests({ id: string, cmd: string, args: [string] })
  deriving (Eq)
```

Important:

- use structured command + args where possible
- avoid shell strings as the primary abstraction
- keep raw shell escape-hatch only if needed

### 3. Hashing and truncation metadata

Native:

- `std/crypto.sha256Hex`
- `std/crypto.sha256Bytes`

Use these in-brain for all bounded output metadata.

---

## What Should Be Delegated Today

These should go to the TUI for now because current AILANG support is weaker here.

### 1. Streaming subprocesses that need more than stdout-only visibility

Examples:

- tests/builds where stderr matters during execution
- long-running commands where users need live failure details

Why delegated:

- `asyncExecProcess` is stdout-only today
- stderr streaming is not clearly supported

### 2. Execution requiring per-call cwd semantics

Examples:

- commands that need to run in different subdirectories within the same step
- process execution where conversational cwd and actual execution cwd must match exactly

Why delegated:

- current runtime ties process cwd to runtime/sandbox semantics, not per-call fields

### 3. Hard-cancelable long-running processes

Examples:

- builds
- test watchers
- heavy grep/ripgrep scans

Why delegated:

- TUI/Node can offer stronger process lifecycle control today
- current AILANG support does not clearly expose a general kill API at the language level

### 4. Advanced interactive subprocess workflows

Examples:

- processes needing live stdin + live stdout/stderr + cancellation
- REPL-like subprocesses

Why delegated:

- current AILANG support is split across `exec`, `asyncExecProcess`, and `spawnProcess`
- a unified process abstraction does not exist yet

---

## Backend Selection Strategy

Backend selection should be explicit in the runtime, not hidden in ad hoc code.

Suggested internal classification:

```ailang
export type ToolBackend = Native | Delegated
  deriving (Eq)
```

And:

```ailang
pure func backend_for(call: ToolCallReq) -> ToolBackend =
  match call {
    ReadFile(_) => Native,
    Search(_) => Native,
    WriteFile(_) => Native,
    BashExec(req) =>
      if needs_delegation_for_process(req.exec) { Delegated } else { Native },
    RunTests(req) =>
      if needs_delegation_for_process(req.exec) { Delegated } else { Native }
  }
```

The exact classification can evolve, but it should live in one place in the brain.

---

## Shell-Compatibility Routing Rules

Native `std/process.exec` and delegated shell execution are not equivalent. The
runtime must route explicitly.

Delegate when any of the following are present:

- shell metacharacters or composition operators: `|`, `>`, `<`, `&&`, `||`, `;`
- subshell forms: `$()`, backticks
- shell-dependent glob-heavy commands
- per-call cwd requirements
- live stderr requirements
- hard-cancel requirements

Native-safe execution means:

- `cmd` + `args` only
- no shell parsing
- execution semantics are those of `std/process.exec`

This routing must be deterministic for identical requests.

---

## Tool Model

A good hybrid tool model should separate semantic intent from backend quirks.

Suggested initial direction:

```ailang
export type ProcessExecReq = {
  cmd:                string,
  args:               [string],
  cwd:                Option[string],
  streaming:          bool,
  needs_stderr_live:  bool,
  needs_hard_cancel:  bool
}

export type ToolCallReq
  = ReadFile({ id: string, path: string, start: int, end: int })
  | Search({ id: string, pattern: string, dir: string, context: int })
  | WriteFile({ id: string, path: string, content: string })
  | BashExec({ id: string, exec: ProcessExecReq })
  | RunTests({ id: string, exec: ProcessExecReq })
  deriving (Eq)
```

Meaning:

- `BashExec` and `RunTests` stay semantic
- process-execution requirements live in `ProcessExecReq`
- backend choice is derived from capabilities, not from a separate tool name

Suggested helper:

```ailang
pure func needs_delegation_for_process(req: ProcessExecReq) -> bool =
  req.streaming
    || req.needs_stderr_live
    || req.needs_hard_cancel
    || isSome(req.cwd)
```

This is better than making the model choose between “native” and “delegated” tools
directly. The model expresses intent; the brain can still rewrite or route where
necessary.

---

## Result Model

Results should be unified even when execution came from different backends.

That means the brain should normalize delegated results into the same ADT family used
for native results.

Example:

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
  = BashExecResult({
      id:        string,
      cmd:       string,
      stdout:    string,
      stderr:    string,
      exit_code: int,
      meta:      ToolResultMeta
    })
  | ReadFileResult({...})
  | SearchResult({...})
  | WriteFileResult({...})
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

The LLM should not have to care whether a `RunTestsResult` came from native or
delegated execution.

---

## Protocol Shape

Unlike the pure TUI-dispatch plan, the brain should emit delegation events only when
there are delegated calls in the batch.

### Brain-only batch

No TUI round-trip.

### Mixed batch

Two-stage execution:

1. execute native calls in the brain
2. emit one delegated `tool_calls` event for the delegated subset
3. receive one delegated `tool_results` response
4. normalize all results into one typed result list
5. produce one model-facing observation

### Fully delegated batch

Equivalent to the first plan for that step, but only for that step.

This preserves the “one round-trip per delegated step” insight without forcing every
tool invocation through the TUI.

---

## Delegation Message Contract

Delegation messages on stdin/stdout need strict contracts so control messages and tool
messages cannot be dropped or misclassified.

Required message types:

- `tool_calls` (brain → TUI)
- `tool_results` (TUI → brain)
- `tool_stream` (TUI → brain, optional incremental output)
- `tool_cancel_ack` (TUI → brain, cancellation confirmation)

Required identifiers:

- batch-level `request_id`
- per-call `tool_call_id`

Runtime rules:

- stdin lines that are not `abort` or `model_change` must be queued, not discarded
- queue consumption must be explicit by expected message type and `request_id`
- delegated waits must have timeout behavior with explicit error results
- abort/model-change handling must coexist safely with in-flight delegated batches

---

## Batching Semantics

The brain still owns batch semantics.

Rules:

- native tools can batch together
- delegated tools can batch together
- mixed batches are allowed, but execution must preserve the “independent in one
  step” invariant
- the model should not batch dependent commands regardless of backend

The brain may choose to split a model-proposed batch internally if backend
requirements force it.

That internal split should not leak into the prompt contract unless necessary.

---

## Streaming Model

Streaming should be supported, but only where the runtime/backend can support it.

### Native streaming

Current AILANG support:

- stdout-only via `std/stream.asyncExecProcess`

Use for:

- long-running stdout-heavy tools

Do not use for:

- stderr-sensitive workflows unless the runtime improves

### Delegated streaming

Use when:

- stderr streaming matters
- hard cancellation matters
- per-call cwd matters

The brain still owns:

- IDs
- event meaning
- truncation policy
- result normalization

The TUI only supplies the execution capability.

---

## Cancellation Model

Cancellation should also be hybrid.

### Native calls

- synchronous native calls: cancellation observed at the next loop boundary
- native streaming calls: close stream sources on abort

### Delegated calls

- TUI aborts the delegated subprocesses immediately using stronger host process control

### Brain responsibility

The brain defines abort semantics and result shaping in both cases.

This is important: delegation should improve execution capability, not take semantic
control away from the brain.

---

## CWD Model

The hybrid design gives a clean answer to the cwd problem.

### Native tools

- use current-runtime working-directory semantics
- brain tracks cwd conversationally
- prefer semantic file tools where cwd ambiguity is minimal
- native process execution does not provide per-call cwd fields

### Delegated tools

- use explicit per-call cwd in the protocol

Brain-level invariants:

- conversational cwd state is brain-owned in all cases
- backend choice must not change conversational cwd semantics
- mixed batches must produce deterministic cwd state transitions

This is a good example of why the hybrid plan is better under current constraints:
it avoids pretending native AILANG can do something it currently cannot, while still
letting the overall system support it when needed.

---

## State of the Art Features Preserved

This hybrid plan should still preserve the strongest tool-calling lessons:

- correlation IDs
- machine-readable schema in the prompt
- explicit parse-status ADT
- unsupported-tool warnings, never silent drop
- bounded output with truncation metadata
- typed tool/result boundaries
- semantic tools, not only bash
- one round-trip per delegated step
- normalized results regardless of backend

---

## Why This Is Better Than Either Pure Plan Today

### Better than pure TUI-dispatch

- more real runtime logic lives in AILANG
- semantic file tools and synchronous process execution stay typed and local
- fewer protocol crossings
- clearer research value

### Better than pure brain-owned

- no need to fake unsupported runtime capabilities
- richer process control is available today where needed
- stderr streaming, per-call cwd, and strong cancellation remain possible
- avoids forcing the design around the split `exec` / `asyncExecProcess` / `spawnProcess` model

---

## Phased Implementation

## Phase 0 — Runtime and capability readiness

Files:

- `tui/src/brain.ts`
- `tui/src/index.ts`
- `swe/rpc.ail`

Changes:

- introduce feature flag for rollout (example: `HYBRID_TOOLS=1`)
- include required runtime caps for hybrid execution paths (`Process`, `Stream`)
- update brain effect signatures to include newly used effects where needed
- keep legacy execution path available behind flag during cutover

## Phase 1 — Unified tool ADTs

Files:

- `swe/types.ail`
- `swe/parse.ail`

Changes:

- introduce a single typed tool model
- preserve IDs, schemas, warnings, and bounded-result metadata

## Phase 2 — Native tool runtime

Files:

- new `swe/tool_runtime.ail`
- `swe/types.ail`

Changes:

- implement native semantic file tools
- implement native synchronous process execution via `std/process.exec`
- normalize native results to shared result ADTs
- map process timeout/output-limit/allowlist settings into result metadata
- document security and ops knobs:
  - `--process-timeout`
  - `--process-max-output`
  - `--process-allowlist` (optional)

## Phase 3 — Delegation protocol

Files:

- `swe/rpc.ail`
- `swe/types.ail`
- `tui/src/brain.ts`
- `tui/src/ui.ts`
- `tui/src/index.ts`

Changes:

- add delegated subset execution
- emit `tool_calls` only for delegated calls
- receive one `tool_results` response for delegated calls
- normalize delegated results back into shared result ADTs
- add request/call correlation (`request_id`, `tool_call_id`)
- add stdin inbox/queue so unknown command types are never dropped
- define delegated timeout and failure shaping

## Phase 4 — Mixed-batch orchestration

Files:

- `swe/rpc.ail`
- `swe/tool_runtime.ail`
- `swe/types.ail`

Changes:

- support batches containing both native and delegated calls
- preserve IDs and one final observation surface

## Phase 5 — Streaming support

Files:

- `swe/tool_runtime.ail`
- `tui/src/ui.ts`
- `tui/src/brain.ts`
- `tui/src/index.ts`
- `swe/types.ail`

Changes:

- native stdout-only streaming where useful
- delegated richer streaming when required
- unified event rendering

## Phase 6 — Prompt and schema refinement

Files:

- `swe/prompts.ail`

Changes:

- teach semantic tools first
- teach when streaming/delegated execution may be used implicitly by the runtime
- preserve plain-text completion contract

---

## Testing Gates

Each phase should have a hard verification gate before moving to the next phase.

- run `ailang check` on all touched `swe/*.ail` modules
- add protocol tests for native-only, delegated-only, and mixed batches
- add regression tests for stdin message ordering:
  - interleavings of `abort`, `model_change`, `tool_results`, and `tool_stream`
- add deterministic backend-selection tests for representative process requests
- run end-to-end tests in both TTY and non-TTY modes

---

## Migration Path

This plan creates a good research trajectory:

### Near term

- native semantic tools
- native synchronous process execution
- delegated advanced subprocesses only

### Medium term

- improve AILANG runtime
- shrink delegated surface

### Long term

- if the runtime matures enough, delegated execution becomes rare or disappears

That gives the project a clean way to learn from both plans instead of choosing too
early between purity and practicality.

---

## Success Criteria

- The brain is the semantic owner of all tool calling
- Native execution is used wherever AILANG already supports the mode well
- Delegation is limited to genuinely unsupported or awkward execution modes
- Results are normalized into one typed observation model
- Unsupported tool requests remain visible and corrective
- Correlation IDs are used across both native and delegated execution
- The delegated surface becomes an explicit runtime-research target, not hidden glue
- No stdin command loss under control + delegated tool traffic
- Native and delegated outputs normalize to equivalent result ADTs
- Backend selection is deterministic for identical tool requests

---

## Decision

Given current AILANG constraints, this hybrid plan is likely the strongest design
available.

It preserves the research value of brain-owned tooling while using the TUI as a
targeted capability extension layer rather than the default execution runtime.
