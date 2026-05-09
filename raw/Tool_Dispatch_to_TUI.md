# Tool Dispatch to TUI

## Purpose

Move tool execution out of the AILANG brain and into the TypeScript frontend (tui/).
The brain retains ownership of all reasoning: LLM calls, tool selection, sequencing,
loop invariants, and effect-typed state. tui retains ownership of all execution:
dispatch, env-server calls, and parallelism strategy.

This aligns with the project's primary goal: to explore AILANG as an agent reasoning
substrate. The brain's effect signature becomes an honest description of what it
actually does — reason — rather than a mix of reasoning and execution.

## Thesis alignment

The project thesis is that a coding agent benefits long-term from having its core
implementation in a language like AILANG, because deterministic semantics and effect
typing make the reasoning loop inspectable, verifiable, and improvable. That thesis
requires the reasoning loop to actually live in AILANG. This plan preserves that
while making execution appropriately the TypeScript frontend's responsibility.

---

## Two distinct invariants (do not conflate)

These are separate properties. Both must hold, but for different reasons.

### Invariant 1 — One round-trip per step (non-negotiable, structural)

> **The brain MUST emit all tool calls for a step as a single `tool_calls` event.
> tui MUST respond with a single `tool_results` event. There MUST be exactly one
> JSONL round-trip per `rpc_loop` iteration.**

This is the architectural load-bearing constraint. Emitting one `tool_call` at a
time and blocking on `readLine()` for each would serialize all tool execution through
the JSONL pipe. The latency cost per step would be `sum(tool times) + N×pipe_latency`
rather than `max(tool times) + pipe_latency`. With N=3 tools taking 500ms each and
10ms pipe latency, that's 1530ms vs 510ms — three times slower than the current
single-tool design, not faster. The round-trip count is what the brain controls.

### Invariant 2 — Parallel execution (tui's strategy, not the protocol)

tui SHOULD execute all calls in a batch with `Promise.all`. This is a tui
implementation choice, not a protocol contract. tui could use sequential execution
(useful for debugging), rate-limited concurrency, or any other strategy without the
brain caring or knowing. The brain emits a batch; what tui does with it is tui's
business.

Keeping these separate means: you can test the protocol with a sequential tui
executor, and switch to parallel execution independently.

---

## Architecture before and after

### Before

```
rpc_loop
  → call(fmt_msgs)          [AI effect]
  → extract_bash(response)  [pure — text parsing]
  → exec_in(url, cmd)       [Net effect — HTTP to env-server]
  → fmt_obs(result)         [pure]
  → recurse
```

Brain effects: `! {Net, AI, SharedMem, IO, Env, FS, Clock}`

### After

```
rpc_loop
  → call(fmt_msgs)                    [AI effect]
  → parse_tool_calls(response)        [pure — JSON parsing into ADTs]
  → emit tool_calls event             [IO effect]
  → read_tool_results()               [IO effect — one blocking readLine()]
  → fmt_batch_obs(calls, results)     [pure]
  → recurse
```

Brain effects: `! {AI, SharedMem, IO, Env, FS, Clock}`

The `Net` effect is removed from `rpc_loop` and `main` entirely. The brain no longer
makes HTTP calls. Its effect signature honestly describes what it does: reason (AI),
manage persistent state (SharedMem), emit events and read commands (IO), read
environment config (Env), read filesystem for system prompts (FS), rate-limit (Clock).

`swe/env_client.ail` is deleted (see Phase 2). `AgentState` loses its `env_url` field
since the brain no longer needs it.

---

## JSONL protocol changes

### New brain → tui event: `tool_calls`

Replaces `proposed_cmd`. Carries all tool calls for the current step as an array.
Each call carries a correlation `id`. Results echo that `id` back. Array order still
matches submission order in the default executor, but protocol correctness does not
depend on positional matching.

For `bash`, `cwd` is carried as structured data, not prefixed into `cmd`.

```json
{
  "type": "tool_calls",
  "step": 3,
  "calls": [
    { "id": "call-1", "tool": "bash", "cwd": "/testbed", "cmd": "cat src/utils.py" },
    { "id": "call-2", "tool": "bash", "cwd": "/testbed", "cmd": "grep -rn 'def parse' src/" },
    { "id": "call-3", "tool": "bash", "cwd": "/testbed", "cmd": "git log --oneline -10" }
  ]
}
```

### New tui → brain command: `tool_results`

Sent by tui after executing the batch. Results echo each call's `id`. If an abort is
requested while tools are executing, tui sends `aborted: true` instead of results.

```json
{
  "type": "tool_results",
  "step": 3,
  "results": [
    {
      "id": "call-1",
      "stdout": "def parse(x):\n    ...",
      "stderr": "",
      "exit_code": 0,
      "truncated": false,
      "stdout_bytes": 21,
      "stdout_total_bytes": 21,
      "stderr_bytes": 0,
      "stderr_total_bytes": 0,
      "stdout_sha256": "..."
    },
    {
      "id": "call-2",
      "stdout": "src/utils.py:12:def parse",
      "stderr": "",
      "exit_code": 0,
      "truncated": false,
      "stdout_bytes": 26,
      "stdout_total_bytes": 26,
      "stderr_bytes": 0,
      "stderr_total_bytes": 0,
      "stdout_sha256": "..."
    }
  ]
}
```

Abort path:
```json
{ "type": "tool_results", "step": 3, "aborted": true }
```

`aborted: true` is reserved for real cancellation of the currently in-flight batch.
Protocol violations (for example a second `tool_calls` while one is in-flight) are fatal:
TUI emits an error, sends `abort`, and terminates/restarts the brain session.

### `obs` event: one per tool result (not one per batch)

**Decision**: emit one `obs` event per result in the batch, immediately after
receiving `tool_results`. This preserves UI compatibility (existing code renders
obs events one at a time) and makes the JSONL trace easier to read. The event should
carry the correlation `id` and enough truncation metadata for the UI and model to
see when output was clipped.

```json
{ "type": "obs", "step": 3, "id": "call-1", "cmd": "cat src/utils.py",
  "stdout": "...", "stderr": "", "exit_code": 0, "truncated": false }
```

### `model_change` during tool execution

`model_change` commands may arrive on stdin while the brain is blocked in
`read_tool_results`. They must not be silently dropped. `read_tool_results` handles
this by looping: on receiving a `model_change`, it applies the change to SharedMem
and calls itself recursively to wait for the actual `tool_results`. See Phase 2 for
the full implementation.

### Retained events

`session_start`, `thinking`, `obs`, `done`, `error`.

### New warning event

`warning` is emitted by the brain when the model requests an unsupported tool type.
This is user-visible in the frontend and does not by itself abort the step.

### Tool schema

The tool JSON format should be described to the model with an explicit schema block
in the system prompt, not only prose examples. The schema remains project-local
JSON, but it should define required fields for each tool (`id`, `tool`, `cmd`, `cwd`
for `bash` in Phase 1) so the LLM is guided by a machine-readable contract.

### Deprecated and removed

`proposed_cmd` — replaced by `tool_calls`. Remove in Phase 2 (no transition period
needed since both ends change atomically).

---

## Phase 1 — AILANG: types  (swe/types.ail)

### ToolCallReq as an ADT

`ToolCallReq` MUST be an algebraic data type, not a record with a `tool: string`
discriminant. The string discriminant approach re-introduces the same stringly-typed
dispatch problem that `extract_bash()` has, just in a different location. AILANG's
type system exists to make this boundary typed.

The JSON wire format from the LLM uses string tool names (the LLM doesn't know about
AILANG ADTs). `parse_tool_calls` is the single translation point from stringly-typed
JSON to the typed ADT. After that boundary, all dispatch uses ADT pattern matching.

Phase 1 defines only `Bash`. Later phases add variants without changing the protocol
or the dispatch structure in tui.

```ailang
-- swe/types.ail additions

-- Tool call request: what the brain asks tui to execute.
-- Phase 1: Bash only.
-- Phase 6: extend with ReadFile, Search, WriteFile, RunTests.
export type ToolCallReq
  = Bash({ id: string, cmd: string, cwd: string })
  -- | ReadFile({ path: string, start: int, end: int })
  -- | Search({ pattern: string, dir: string, context: int })
  -- | WriteFile({ path: string, content: string })
  -- | RunTests(string)
  deriving (Eq)

-- Unsupported tool request preserved for UI visibility and corrective feedback.
export type UnsupportedToolCall = {
  tool: string,
  raw:  string
}

-- Tool result: what tui returns for one call.
-- Phase 1 uses a common transport envelope with correlation and truncation metadata.
-- Later phases may add a typed payload field for non-bash tools.
export type ToolResultItem = {
  id:                 string,
  stdout:    string,
  stderr:    string,
  exit_code:          int,
  truncated:          bool,
  stdout_bytes:       int,
  stdout_total_bytes: int,
  stderr_bytes:       int,
  stderr_total_bytes: int,
  stdout_sha256:      string
}

-- AgentState no longer carries env_url — brain does not make HTTP calls.
export type AgentState = {
  msgs:  [Msg],
  cwd:   string,
  step:  int
}
```

Note: `AgentState` loses `env_url`. All existing call sites that construct or
destructure `AgentState` must be updated in Phase 2.

---

## Phase 2 — AILANG: parser  (swe/parse.ail)

### parse_tool_calls — full specification

Replaces `extract_bash` with an explicit parse-status ADT so malformed attempted
tool calls do not get treated as completion.

```ailang
export type ParseToolCalls
  = NoCalls               -- no JSON structure present: completion signal
  | Calls({ supported: [ToolCallReq], unsupported: [UnsupportedToolCall] })
  | ParseError(string)    -- looked like a tool payload but failed to decode/shape-check
  deriving (Eq)
```

**Parsing algorithm:**

1. Strip leading/trailing whitespace from `text`.
2. Check for a code fence. If `text` contains ` ```json `, ` ```bash `, or plain
   ` ``` `, extract the content between the outermost fence pair.
3. In the (possibly stripped) text, find the first `[` or `{`.
4. If `[` comes first (or only `[` found): attempt `decode`, then convert the
   decoded JSON value with `asArray`.
   On success:
   - if the decoded array is empty (`[]`), return `NoCalls`
   - else map each element through `parse_one_call` and return `Calls(...)`
   If `decode` succeeds but `asArray` returns `None`: `ParseError(...)`.
   On `decode` failure: `ParseError(...)`.
5. If `{` comes first (or only `{` found): attempt `decode` as a single JSON object.
   On success, wrap in a list via `parse_one_call` and return `Calls(...)`.
   On failure: `ParseError(...)`.
6. If neither `[` nor `{` found: `NoCalls` (plain text response = done).

**parse_one_call**: classifies one decoded JSON object as supported or unsupported.
```ailang
type ParsedOneCall = Supported(ToolCallReq) | Unsupported(UnsupportedToolCall)

func parse_one_call(obj: Json, next_id: string, cwd: string) -> ParsedOneCall {
  match getString(obj, "tool") {
    Some("bash") =>
      match getString(obj, "cmd") {
        Some(cmd) => Supported(Bash({ id: next_id, cmd: cmd, cwd: cwd })),
        None => Unsupported({ tool: "bash", raw: encode(obj) })
      },
    Some(name) => Unsupported({ tool: name, raw: encode(obj) }),
    None => Unsupported({ tool: "<missing>", raw: encode(obj) })
  }
}
```

Unsupported tool types are not treated as parse failure, but they are also not
silently skipped. The brain preserves them, emits explicit `warning` events so the
frontend/user can see them, and feeds them back to the LLM so the next step can
correct itself. This keeps forward compatibility without hiding a capability mismatch.

Semantics distinction (intentional, explicit):
- `[]` from the model means "no tool calls this turn" and is treated as `NoCalls`.
- `[{"tool":"unknown", ...}]` means "attempted tool use but unsupported" and is
  treated as `Calls({ supported: [], unsupported: [...] })`.
- Mixed batches preserve both: supported calls execute, unsupported calls are shown
  to the user and included in corrective feedback to the model.

**tests block** (representative cases — implement all):

```ailang
export func parse_tool_calls(text: string) -> ParseToolCalls
  tests [
    -- bare JSON array, single tool
    ("[{\"tool\":\"bash\",\"cmd\":\"ls\"}]",
     Calls({ supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })], unsupported: [] })),

    -- bare JSON array, multiple tools
    ("[{\"tool\":\"bash\",\"cmd\":\"ls\"},{\"tool\":\"bash\",\"cmd\":\"pwd\"}]",
     Calls({
       supported: [
         Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" }),
         Bash({ id: "call-2", cmd: "pwd", cwd: "/testbed" })
       ],
       unsupported: []
     })),

    -- fenced with ```json
    ("```json\n[{\"tool\":\"bash\",\"cmd\":\"ls\"}]\n```",
     Calls({ supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })], unsupported: [] })),

    -- fenced with plain ```
    ("```\n[{\"tool\":\"bash\",\"cmd\":\"ls\"}]\n```",
     Calls({ supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })], unsupported: [] })),

    -- prose before the array
    ("I will run these commands:\n[{\"tool\":\"bash\",\"cmd\":\"ls\"}]",
     Calls({ supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })], unsupported: [] })),

    -- single object (no array wrapper)
    ("{\"tool\":\"bash\",\"cmd\":\"ls\"}",
     Calls({ supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })], unsupported: [] })),

    -- plain text response (completion signal)
    ("The bug is fixed. The issue was in parse_config at line 42.",
     NoCalls),

    -- empty string
    ("", NoCalls),

    -- malformed JSON
    ("[{bad json here}]", ParseError("decode failure")),

    -- empty array
    ("[]", NoCalls),

    -- unknown tool type (preserve and warn)
    ("[{\"tool\":\"unknown\",\"cmd\":\"ls\"}]",
     Calls({
       supported: [],
       unsupported: [{ tool: "unknown", raw: "{\"tool\":\"unknown\",\"cmd\":\"ls\"}" }]
     })),

    -- mixed known and unknown tools
    ("[{\"tool\":\"bash\",\"cmd\":\"ls\"},{\"tool\":\"unknown\",\"args\":{}}]",
     Calls({
       supported: [Bash({ id: "call-1", cmd: "ls", cwd: "/testbed" })],
       unsupported: [{ tool: "unknown", raw: "{\"tool\":\"unknown\",\"args\":{}}" }]
     }))
  ]
{ ... }
```

Keep `extract_bash` in `swe/parse.ail` until this plan is fully deployed and tested.
Delete it at the same time as `swe/env_client.ail`.

---

## Phase 3 — AILANG: rpc_loop rewrite  (swe/rpc.ail)

### cwd policy for batched calls

**Within a batch, cwd does not update between commands.** Commands run in parallel;
there is no sequencing within a step. The brain attaches `cwd` as structured data to
every `Bash` request. The executor is responsible for honoring that `cwd` without
rewriting the shell command string.

cwd tracking after a batch:
- Call `parse_cwd` on each command in the batch.
- If exactly one command changes cwd, use that new cwd.
- If multiple commands change cwd (should not happen with well-prompted LLMs, but
  possible), use the cwd from the last command that contains `cd /`.
- If none change cwd, keep `state.cwd` unchanged.

This is implemented by `update_cwd_from_batch` — a left fold over the batch applying
`parse_cwd` to each bash command string and carrying the result forward:

```ailang
func update_cwd_from_batch(calls: [ToolCallReq], current: string) -> string =
  foldl(\cwd call.
    match call {
      Bash(req) => parse_cwd(req.cmd, cwd)
      -- named tools do not affect cwd
    },
    current, calls)
```

The system prompt (Phase 5) explicitly instructs the LLM: **use absolute paths in
all commands; do not batch a `cd` command with other commands**.

### read_tool_results — handles model_change interleaving

`model_change` commands arriving while the brain is blocked on `readLine()` must not
be silently dropped. This function loops on `model_change`, applies the change, and
recurses until it sees `tool_results` or an exit condition.

```ailang
-- read_tool_results : string -> int
--   -> { results: [ToolResultItem], model: string, aborted: bool, protocol_error: Option[string] }
--   ! {IO, SharedMem}
--
-- Blocks until tui sends tool_results (or an exit/abort signal).
-- Loops on model_change commands rather than dropping them.
func read_tool_results(model_current: string, expected_step: int)
  -> { results: [ToolResultItem], model: string, aborted: bool, protocol_error: Option[string] } ! {IO, SharedMem} {
  let raw = readLine();
  if raw == "" then {
    results: [],
    model: model_current,
    aborted: true,
    protocol_error: Some("stdin closed while waiting for tool_results")
  }  -- EOF
  else
  match decode(raw) {
    Err(_) => {
      results: [],
      model: model_current,
      aborted: true,
      protocol_error: Some("malformed stdin JSON while waiting for tool_results")
    },
    Ok(obj) =>
      match get_str(obj, "type") {
        "tool_results" =>
          let msg_step =
            match getInt(obj, "step") {
              Some(n) => n,
              None => -1
            } in
          if msg_step != expected_step then
            -- Fatal protocol violation: brain/tui step correlation broke.
            {
              results: [],
              model: model_current,
              aborted: true,
              protocol_error: Some("protocol violation: tool_results step mismatch")
            }
          else
            let aborted =
              match getBool(obj, "aborted") {
                Some(b) => b,
                None => false
              } in
            if aborted then {
              results: [],
              model: model_current,
              aborted: true,
              protocol_error: None
            }
            else {
              results: parse_result_items(obj),
              model: model_current,
              aborted: false,
              protocol_error: None
            },
        "abort" =>
          { results: [], model: model_current, aborted: true, protocol_error: None },
        "model_change" =>
          -- Apply and loop — do not drop the model change.
          let new_model = get_str(obj, "model") in
          let _ = _sharedmem_put("swe:current_model",
                                 _bytes_from_string(new_model)) in
          read_tool_results(new_model, expected_step),
        _ =>
          -- Unknown command while waiting: skip and keep waiting.
          read_tool_results(model_current, expected_step)
      }
  }
}
```

Required helpers in `swe/rpc.ail` (define explicitly in this phase, not deferred):

```ailang
-- encode_calls : [ToolCallReq] -> Json
func encode_calls(calls: [ToolCallReq]) -> Json =
  ja(map(\c. match c {
    Bash(req) => jo([
      kv("id",   js(req.id)),
      kv("tool", js("bash")),
      kv("cmd",  js(req.cmd)),
      kv("cwd",  js(req.cwd))
    ])
  }, calls))

-- parse_result_items : Json -> [ToolResultItem]
func parse_result_items(obj: Json) -> [ToolResultItem] {
  match getArray(obj, "results") {
    None => [],
    Some(items) =>
      map(\j.
        {
          id: match getString(j, "id") { Some(s) => s, None => "" },
          stdout: match getString(j, "stdout") { Some(s) => s, None => "" },
          stderr: match getString(j, "stderr") { Some(s) => s, None => "" },
          exit_code: match getInt(j, "exit_code") { Some(n) => n, None => 1 },
          truncated: match getBool(j, "truncated") { Some(b) => b, None => false },
          stdout_bytes: match getInt(j, "stdout_bytes") { Some(n) => n, None => 0 },
          stdout_total_bytes: match getInt(j, "stdout_total_bytes") { Some(n) => n, None => 0 },
          stderr_bytes: match getInt(j, "stderr_bytes") { Some(n) => n, None => 0 },
          stderr_total_bytes: match getInt(j, "stderr_total_bytes") { Some(n) => n, None => 0 },
          stdout_sha256: match getString(j, "stdout_sha256") { Some(s) => s, None => "" }
        },
        items)
  }
}

-- emit_obs : int -> ToolCallReq -> ToolResultItem -> () ! {IO}
func emit_obs(step: int, call: ToolCallReq, r: ToolResultItem) -> () ! {IO} =
  match call {
    Bash(req) =>
      emit(encode(jo([
        kv("type",      js("obs")),
        kv("step",      jnum(_int_to_float(step))),
        kv("id",        js(r.id)),
        kv("cmd",       js(req.cmd)),
        kv("stdout",    js(r.stdout)),
        kv("stderr",    js(r.stderr)),
        kv("exit_code", jnum(_int_to_float(r.exit_code))),
        kv("truncated", jb(r.truncated))])))
  }
```

### rpc_loop core change

```ailang
match parse_tool_calls(response) {

  -- No tool calls: LLM gave a final answer. Done.
  NoCalls => {
    let _ = emit(encode(jo([
      kv("type",   js("done")),
      kv("step",   jnum(_int_to_float(state.step))),
      kv("output", js(response))])));
    let _ = put_trajectory(task_from_msgs(state.msgs), response);
    state
  },

  -- Parse looked like tool JSON but decoding/shape failed.
  ParseError(msg) => {
    let msgs2 = msgs1 ++ [{ role: "user",
      content: "Your previous response looked like tool JSON but could not be parsed: " ++ msg ++
               ". Return a valid JSON array of tool calls." }];
    rpc_loop({ msgs: msgs2, cwd: state.cwd, step: state.step + 1 },
             model_current, depth - 1, step_delay)
  },

  -- Parse succeeded: preserve unsupported tools for UI visibility and model correction.
  Calls(batch) => {
    let supported   = batch.supported;
    let unsupported = batch.unsupported;

    let _ = map(\u.
      emit(encode(jo([
        kv("type",    js("warning")),
        kv("step",    jnum(_int_to_float(state.step))),
        kv("message", js("unsupported tool requested by model: " ++ u.tool)),
        kv("raw",     js(u.raw))]))),
      unsupported);

    let correction =
      if unsupported == [] then ""
      else "Unsupported tool calls were requested and not executed:\n" ++
           join("\n", map(\u. "- " ++ u.tool ++ ": " ++ u.raw, unsupported)) ++
           "\nUse only supported tool \"bash\".\n";

    if supported == [] then {
      let msgs2 = msgs1 ++ [{ role: "user", content: correction }];
      rpc_loop({ msgs: msgs2, cwd: state.cwd, step: state.step + 1 },
               model_current, depth - 1, step_delay)
    } else {

    -- Attach current cwd to each bash request before encoding the batch.
    let qualified = map(\c. attach_cwd(c, state.cwd), supported);

    -- Emit ALL tool calls in one event (Invariant 1).
    let _ = emit(encode(jo([
      kv("type",  js("tool_calls")),
      kv("step",  jnum(_int_to_float(state.step))),
      kv("calls", encode_calls(qualified))])));

    -- Block until tui responds with all results (one readLine — Invariant 1).
    let tool_reply = read_tool_results(model_current, state.step);

    match tool_reply.protocol_error {
      Some(msg) => {
        let _ = emit(encode(jo([
          kv("type",    js("error")),
          kv("message", js(msg))])));
        state
      },
      None =>
    if tool_reply.aborted then {
      let _ = emit(encode(jo([
        kv("type",    js("error")),
        kv("message", js("aborted"))])));
      state
    } else {
      let _ = map(\call.
        match find_result_for_call(call, tool_reply.results) {
          Some(res) => emit_obs(state.step, call, res),
          None => ()
        },
        qualified);

      let obs_text = correction ++ fmt_batch_obs(qualified, tool_reply.results);
      let msgs2    = msgs1 ++ [{ role: "user", content: obs_text }];
      let new_cwd  = update_cwd_from_batch(qualified, state.cwd);

      rpc_loop({
        msgs: msgs2,
        cwd:  new_cwd,
        step: state.step + 1
      }, tool_reply.model, depth - 1, step_delay)
    }
    }
    }
  }
}
```

### attach_cwd — attach cwd to each call as structured data

```ailang
func attach_cwd(call: ToolCallReq, cwd: string) -> ToolCallReq =
  match call {
    Bash(req) => Bash({ req | cwd: cwd })
    -- Named tools handle their own path resolution in tui
  }
```

### fmt_batch_obs — correlate by `id`

Use correlation IDs when pairing calls and results. The default executor preserves
order, but observation formatting should not depend on that invariant.

```ailang
-- fmt_batch_obs : [ToolCallReq] -> [ToolResultItem] -> string
export func fmt_batch_obs(calls: [ToolCallReq], results: [ToolResultItem]) -> string =
  foldl(\acc call.
    acc ++ match find_result_for_call(call, results) {
      Some(res) => fmt_single_obs(call, res),
      None => ""
    },
    "", calls)

func find_result_for_call(call: ToolCallReq, results: [ToolResultItem]) -> Option[ToolResultItem] =
  match call {
    Bash(req) => findFirst(\r. r.id == req.id, results)
  }

func fmt_single_obs(call: ToolCallReq, r: ToolResultItem) -> string =
  match call {
    Bash(req) => fmt_obs(req.cmd, r)
    -- Named tools: format with tool-appropriate header in Phase 6
  }
```

### Effect and AgentState cleanup

```ailang
-- Remove env_url from AgentState constructor in main() and conversation_loop().
-- Remove Net from all effect signatures.
-- Delete: import swe/env_client (exec_in)

func rpc_loop(state: AgentState, model: string, depth: int, step_delay: int)
  -> AgentState ! {AI, SharedMem, IO, Clock}

export func main() -> () ! {AI, SharedMem, IO, Env, FS, Clock}
```

### Delete swe/env_client.ail

Delete the file. It has no remaining callers. Do not leave it as dead code — dead
code in an exploratory codebase signals "this might still be needed" to future
readers when it is not.

---

## Phase 4 — TypeScript: tui/src/brain.ts

### ToolCallRequest type mirrors the AILANG ADT at the wire boundary

The TypeScript type is a discriminated union, mirroring the AILANG ADT. Phase 1
has only `Bash`. Phase 6 adds variants.

```typescript
// Wire format for tool calls (matches what the brain emits in tool_calls event)
export type ToolCallRequest =
  | { id: string; tool: "bash"; cmd: string; cwd: string }
  // Phase 6: | { tool: "read_file"; path: string; start: number; end: number }
  // Phase 6: | { tool: "search"; pattern: string; dir: string; context: number }

export type ToolResultItem = {
  id: string;
  stdout:    string;
  stderr:    string;
  exit_code: number;
  truncated: boolean;
  stdout_bytes: number;
  stdout_total_bytes: number;
  stderr_bytes: number;
  stderr_total_bytes: number;
  stdout_sha256: string;
};

export type AgentEvent =
  | { type: "session_start"; task: string; model: string;
      brainVersion: string; ailangBuilt: string }
  | { type: "thinking";   step: number; text: string }
  | { type: "tool_calls"; step: number; calls: ToolCallRequest[] }
  | { type: "warning";    step: number; message: string; raw?: string }
  | { type: "obs";        step: number; id: string; cmd: string;
      stdout: string; stderr: string; exit_code: number; truncated: boolean }
  | { type: "done";       step: number; output: string }
  | { type: "error";      message: string };
```

### ToolExecutor injection

```typescript
export type ToolExecutor = (
  calls: ToolCallRequest[],
  signal: AbortSignal
) => Promise<ToolResultItem[]>;

export class Brain {
  constructor(
    task:         string,
    envUrl:       string,
    model:        string,
    onEvent:      (e: AgentEvent) => void,
    onExit:       () => void,
    executeTools: ToolExecutor
  ) { ... }
```

### Handling tool_calls events with abort safety

The readline handler becomes async. Class-level flags (`pendingAbort`, `toolsInFlight`)
handle abort coordination and protocol safety while execution is in flight.

```typescript
private pendingAbort = false;
private toolsInFlight = false;
private activeAbortController: AbortController | null = null;

rl.on("line", async (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;

  let event: AgentEvent;
  try {
    event = JSON.parse(trimmed) as AgentEvent;
  } catch {
    return;  // malformed line
  }

  if (event.type === "tool_calls") {
    if (this.toolsInFlight) {
      onEvent({ type: "error", message: "fatal protocol violation: concurrent tool_calls" });
      this.send({ type: "abort" });
      this.kill();
      return;
    }

    this.toolsInFlight = true;
    onEvent(event);

    const abortController = new AbortController();
    this.activeAbortController = abortController;
    if (this.pendingAbort) abortController.abort();

    let results: ToolResultItem[];
    let aborted = false;
    try {
      results = await this.executeTools(event.calls, abortController.signal);
    } catch {
      aborted = true;
      results = [];
    } finally {
      this.activeAbortController = null;
      this.toolsInFlight = false;
    }

    if (this.pendingAbort || aborted) {
      this.pendingAbort = false;
      this.send({ type: "tool_results", step: event.step, aborted: true });
    } else {
      this.send({ type: "tool_results", step: event.step, results });
    }

  } else {
    onEvent(event);
  }
});

abort(): void {
  this.pendingAbort = true;
  this.activeAbortController?.abort();
  this.send({ type: "abort" });
}
```

---

## Phase 5 — TypeScript: tui/src/index.ts tool executor

```typescript
import type { ToolCallRequest, ToolResultItem } from "./brain.js";

function makeToolExecutor(envUrl: string): ToolExecutor {
  return async (
    calls: ToolCallRequest[],
    signal: AbortSignal
  ): Promise<ToolResultItem[]> => {
    // All calls dispatched simultaneously — Promise.all is the default strategy.
    // Sequential execution (for debugging): replace with a for-of loop.
    return Promise.all(
      calls.map(async (call): Promise<ToolResultItem> => {
        switch (call.tool) {
          case "bash": {
            const res = await fetch(`${envUrl}/exec`, {
              method:  "POST",
              headers: { "Content-Type": "application/json" },
              body:    JSON.stringify({ cmd: call.cmd, cwd: call.cwd, timeout: 30 }),
              signal,
            }).then(r => r.json());
            return {
              id:            call.id,
              stdout:    res.stdout    ?? "",
              stderr:    res.stderr    ?? "",
              exit_code: res.exit_code ?? 1,
              truncated: res.truncated ?? false,
              stdout_bytes: res.stdout_bytes ?? 0,
              stdout_total_bytes: res.stdout_total_bytes ?? 0,
              stderr_bytes: res.stderr_bytes ?? 0,
              stderr_total_bytes: res.stderr_total_bytes ?? 0,
              stdout_sha256: res.stdout_sha256 ?? "",
            };
          }
          // Phase 6: case "read_file": ...
          // Phase 6: case "search":    ...
          default:
            // Defensive fallback: unsupported tools should normally have been
            // surfaced earlier by the brain as warning events.
            return {
              id:            call.id,
              stdout:    "",
              stderr:    `unknown tool: ${(call as any).tool}`,
              exit_code: 1,
              truncated: false,
              stdout_bytes: 0,
              stdout_total_bytes: 0,
              stderr_bytes: 0,
              stderr_total_bytes: 0,
              stdout_sha256: "",
            };
        }
      })
    );
  };
}
```

The `switch` on `call.tool` is the TypeScript dispatch boundary. Adding Phase 6
named tools means adding a `case` here, a `ToolCallRequest` variant in brain.ts, and
an ADT variant in `swe/types.ail`. No other files change.

---

## Phase 6 — System prompt  (swe/prompts.ail)

The system prompt must do two things the old one did not: teach the LLM the JSON
tool call format, and — critically — teach it when batching is safe.

### When to batch (and when not to)

Commands run in **parallel within a batch**. The output of command N is not available
to command M in the same batch step. The LLM must understand this.

```
SAFE to batch — independent reads:
[
  {"tool": "bash", "cmd": "cat /testbed/src/utils.py"},
  {"tool": "bash", "cmd": "cat /testbed/tests/test_utils.py"},
  {"tool": "bash", "cmd": "git -C /testbed log --oneline -5"}
]

UNSAFE to batch — second depends on first's output:
[
  {"tool": "bash", "cmd": "sed -i 's/foo/bar/' /testbed/src/utils.py"},
  {"tool": "bash", "cmd": "cat /testbed/src/utils.py"}
]
The second command would read the file BEFORE the edit is applied.
Put sequential commands in separate steps.
```

### Robustness against LLM formatting variation

Different LLMs wrap JSON differently. The prompt should show the bare format but
also note that code fences are accepted — this reduces model anxiety about formatting
and results in more consistent output. `parse_tool_calls` handles both.

### Updated base_system

```ailang
export func base_system(workdir: string) -> string =
  "You are a software engineering agent running in a bash environment.\n" ++
  "\n" ++
  "## Tool calls\n" ++
  "To execute commands, respond with a JSON array of tool calls.\n" ++
  "Each call must include an \"id\" field, a \"tool\" field, and tool-specific fields.\n" ++
  "Currently available tool: \"bash\" with fields \"id\", \"cmd\", and \"cwd\".\n" ++
  "Schema:\n" ++
  "{ \"type\": \"array\", \"items\": { \"type\": \"object\", \"required\": [\"id\", \"tool\", \"cmd\", \"cwd\"] } }\n" ++
  "\n" ++
  "Example (read three files in one step):\n" ++
  "[\n" ++
  "  {\"id\": \"call-1\", \"tool\": \"bash\", \"cwd\": \"" ++ workdir ++ "\", \"cmd\": \"cat src/utils.py\"},\n" ++
  "  {\"id\": \"call-2\", \"tool\": \"bash\", \"cwd\": \"" ++ workdir ++ "\", \"cmd\": \"cat tests/test_utils.py\"},\n" ++
  "  {\"id\": \"call-3\", \"tool\": \"bash\", \"cwd\": \"" ++ workdir ++ "\", \"cmd\": \"git log --oneline -5\"}\n" ++
  "]\n" ++
  "\n" ++
  "## Batching rules\n" ++
  "Commands in a batch run IN PARALLEL. This means:\n" ++
  "- DO batch commands that read or observe state independently\n" ++
  "- DO NOT batch commands where the second depends on the first's output\n" ++
  "- DO NOT batch a file edit and a read of the same file — they will race\n" ++
  "- Always set cwd explicitly; do not rely on cd persisting within a batch\n" ++
  "\n" ++
  "## Completion\n" ++
  "When you have finished the task, respond with plain text only — no JSON array.\n" ++
  "A response with no JSON array is the completion signal.\n" ++
  "\n" ++
  "## Rules\n" ++
  "- Use bash for all file and repo access — there is no native file API in Phase 1\n" ++
  "- Do not prepend `cd ... &&` in tool JSON; send cwd as a separate field\n" ++
  "- Base cwd: " ++ workdir ++ "\n" ++
  "- At most 50 steps total\n"
```

---

## Phase 7 — Named tools  (swe/types.ail, swe/prompts.ail, tui/src/index.ts)

With the dispatch infrastructure in place, named tools are purely additive:

| Tool | Args | AILANG ADT variant | Result shape | tui case |
|---|---|---|---|---|
| `bash` | `cmd, cwd` | `Bash({...})` | `{ stdout, stderr, exit_code, truncated, ... }` | POST `/exec` |
| `read_file` | `path, start, end` | `ReadFile({...})` | `{ content, line_count, truncated, sha256 }` | native file read |
| `search` | `pattern, dir, context` | `Search({...})` | `{ matches: [{ path, line_number, line_text, context }] }` | native recursive search |
| `write_file` | `path, content` | `WriteFile({...})` | `{ bytes_written, sha256 }` | native file write |
| `run_tests` | `cmd, cwd` | `RunTests({...})` | `{ stdout, stderr, exit_code, summary }` | process exec + summary parse |

Each named tool: one ADT variant in `swe/types.ail`, one `case` in tui's `switch`,
one result payload type, and one description paragraph in `base_system`. These tools
should return typed semantic payloads, not bash-formatted text that the LLM must
re-parse.

`fmt_single_obs` in `swe/prompts.ail` gains match branches for each variant,
formatting output with tool-appropriate headers (e.g., line numbers for `read_file`).

---

## Context window growth (known consequence)

Multi-tool batching increases the rate of context accumulation: a step that batches
3 file reads generates 3× the observation text of a single-read step. This compounds
over the 50-step budget.

This plan therefore requires bounded tool output at the protocol layer, not as a
future optimization:
- Every tool result MUST be size-limited before it is sent back to the brain.
- Result metadata MUST indicate truncation and total size.
- `stderr` truncation should be tail-biased so the most relevant failure text is kept.
- The full untruncated output should be hash-addressable via metadata even when only
  a prefix/suffix is returned to the model.

Mitigation is out of scope for this plan but must be tracked: a future
`swe/compress.ail` module should summarise observation history when the total
conversation token estimate exceeds a threshold (roughly `char_count / 4 > limit`),
replacing old tool output blocks with compact summaries via a fast `call()` to a
small model. The `SharedMem` effect already present in the brain's signature is the
right place to cache the compressed history.

---

## Migration path

| Phase | Files changed | State after |
|---|---|---|
| 1 | `swe/types.ail` | `ToolCallReq` ADT, `ToolResultItem`, updated `AgentState` |
| 2 | `swe/parse.ail` | `parse_tool_calls` with full test suite |
| 3 | `swe/rpc.ail`, delete `swe/env_client.ail` | Brain emits `tool_calls`, blocks on `read_tool_results` |
| 4 | `tui/src/brain.ts` | `tool_calls` intercepted, `tool_results` sent back |
| 5 | `tui/src/index.ts` | `makeToolExecutor` wired, parallel execution live |
| 6 | `swe/prompts.ail` | LLM prompted for JSON tool calls with batching guidance |
| 7 | All of the above | Named tools (additive, after Phase 6 is stable) |

**Atomic cutover (required):** Phases 1–6 MUST ship together in one release.
Do not deploy parser/rpc protocol changes, TUI dispatch changes, or prompt-format
changes independently. The legacy bash-block protocol and the new JSON tool-call
protocol are not wire-compatible; partial rollout can terminate tasks incorrectly or
strand the brain waiting for mismatched messages.

---

## What does NOT change

- `swe/cache.ail` — trajectory cache is unaffected
- `swe/agents_md.ail` — AGENTS.md loading is unaffected
- `swe/version.ail` — unchanged
- `tui/src/env-server.ts` — HTTP server unchanged; tools still call it via makeToolExecutor
- `tui/src/ui.ts` — add minimal rendering for `warning` events so unsupported tool requests are visible
- `tui/src/commands.ts` — slash commands unaffected
- `conversation_loop` in `swe/rpc.ail` control flow remains the same; state shape updates with `AgentState`
- `abort` / `user_message` command protocol — unchanged

---

## Testing

Existing tests must pass. New tests required:
**swe/parse.ail** — inline `tests [...]` blocks as specified in Phase 2. These run
without any capability flags and are the primary regression guard for the parser.

**tui/ integration tests** (new test file `tui/src/tool-dispatch.test.ts`):

| Test | What it verifies |
|---|---|
| Single bash tool call round-trip | Brain emits one call with `id` and `cwd`; tui executes and echoes the same `id` back |
| Multi-tool parallel batch (3 calls) | All 3 execute via Promise.all; correlation is by `id`, not array position |
| Abort during execution | pendingAbort set; tool_results with aborted:true sent; brain exits |
| Concurrent tool_calls guard | Second in-flight tool_calls is treated as fatal protocol violation (abort + kill/restart) |
| tool_results step mismatch | Brain treats out-of-step results as fatal protocol violation (emit error and stop loop) |
| model_change during tool execution | read_tool_results loops; model updated; execution completes |
| Unsupported tool type in batch | Brain emits `warning`; known tools in same batch still execute |
| Truncated tool output | Result metadata reports truncation, byte counts, and hash when output is clipped |
| Malformed attempted tool JSON from LLM | parse_tool_calls returns ParseError; brain feeds correction and continues |
| tui crash during execution (stdin EOF) | readLine returns ""; brain returns state; process exits cleanly |
| Empty batch (all tools unsupported) | Brain emits `warning`, appends corrective user message, and retries |

---

## Success criteria

- Brain's `rpc_loop` makes exactly one `readLine()` call per step (verifiable via trace)
- `swe/env_client.ail` is deleted
- `AgentState` has no `env_url` field
- Brain's effect signature contains no `Net`
- A step batching 3 independent file reads completes in `max(read times)` not `sum`
- Every tool call/result pair is correlated by explicit `id`
- `bash` execution receives `cwd` as structured data, not command-string prefixing
- Oversized tool output is truncated before entering the model context and marked as truncated in metadata
- `model_change` arriving during tool execution is applied to the next LLM call
- Out-of-step `tool_results` and concurrent `tool_calls` are treated as fatal protocol violations (not synthetic aborts)
- Phases 1–6 are released atomically (single cutover), with no mixed legacy/new protocol runtime window
- All existing tests pass; all new tests listed above pass
