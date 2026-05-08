---
sources: [summaries/AILANG_Agent.md]
brief: AILANG Brain Processes are child processes running AILANG code over JSONL stdin/stdout, handling AI agent loops with effect-tracking and yolo execution.
---

# AILANG Brain Processes

An **AILANG Brain Process** is a child process that executes [[concepts/AILANG]] code and communicates with a host process (typically a TypeScript terminal UI) over a minimal [[concepts/JSONL Protocol]] via stdin and stdout. It is the core runtime unit for the [[summaries/AILANG_Agent]] SWE agent.

## Architecture

The brain process is spawned by the TypeScript frontend using the `ailang` CLI:

```bash
ailang run --caps Net,AI,SharedMem,IO \
  --ai <model> --entry main --emit-trace trace.jsonl \
  swe/rpc.ail
```

It receives configuration via environment variables (`ENV_URL`, `TASK`, `MODEL`) and communicates bidirectionally:

- **stdout** → JSONL events (session_start, thinking, proposed_cmd, obs, done, error)
- **stdin** ← JSONL commands (abort, model_change)

## Effect Signature

Every brain process declares its capabilities via an effect signature: `! {Net, AI, SharedMem, IO}`. This tracks all side effects — network calls to the [[concepts/Environment Server]], LLM invocations, shared memory access, and I/O — enabling stub injection, trace replay, and deterministic testing with `--ai-stub`.

## Yolo Mode

In the AILANG SWE-Agent, the brain always operates in [[concepts/Yolo Mode]]: every proposed command is executed immediately without pausing for user confirmation. This eliminates mode logic from the brain and simplifies the JSONL protocol — the brain never blocks waiting for stdin between steps.

## Core Loop (rpc_loop)

The brain's central recursion in `swe/rpc.ail` follows a tight cycle:

1. **Poll stdin** — Check for pending abort or model_change commands via `_io_poll_stdin`, a non-blocking builtin.
2. **LLM call** — Send message history to the AI model using `std/ai (call)` or the optional `call_with(model, prompt)` builtin.
3. **Emit thinking** — Write the full LLM response as a JSONL event.
4. **Extract bash** — Parse the response for a bash code block.
5. **Execute** — Send the extracted command to the [[concepts/Environment Server]] via POST /exec.
6. **Emit observation** — Write the execution result (stdout, stderr, exit_code) as a JSONL event.
7. **Check done** — If the sentinel `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT` is detected, emit a `done` event and persist the trajectory to [[concepts/SharedMem Cache]]. Otherwise append the observation as a user message and recurse (up to 50 steps).

## Builtins

The brain process relies on a few key builtins:

| Builtin | Purpose |
|---|---|
| `_io_poll_stdin` | Non-blocking stdin peek; returns `""` if no input is ready |
| `call(prompt)` | Standard LLM invocation via the `--ai` flag (phases 0–4) |
| `call_with(model, prompt)` | Runtime model selection reading from SharedMem (Phase 5, optional) |
| `store_config(key, value)` | Writes to SharedMem for cross-process state like current model |

`_io_poll_stdin` is the only runtime addition needed for the basic brain; `call_with` is deferred to the optional Phase 5 for live mid-session model switching via [[concepts/Option D Model Selection]].

## Relationship to Host Process

The brain is a pure computation layer — it never touches the terminal, never reads user keystrokes, and never manages UI state. All rendering, command input, and signal handling (SIGINT → abort) live in the TypeScript process. This clean separation means the brain can be tested headlessly with mock environment servers and AI stubs.