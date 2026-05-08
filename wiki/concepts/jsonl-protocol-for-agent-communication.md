---
sources: [summaries/Thinking_Traces.md, summaries/AILANG_Agent.md]
brief: A minimal JSON Lines protocol for structured agent-frontend IPC over stdin/stdout.
---

# JSONL Protocol for Agent Communication

A deliberately minimal protocol for structured inter-process communication between an AILANG brain and a TypeScript frontend, detailed in [[summaries/AILANG_Agent]]. Every record is a newline-delimited JSON object, transmitted over stdin and stdout. The simplicity ensures easy parsing, bounded memory, and straightforward testing.

## Message Direction

- **AILANG → TypeScript (events)**: The brain emits events (`session_start`, `thinking`, `proposed_cmd`, `obs`, `done`, `error`).
- **TypeScript → AILANG (commands)**: The frontend sends commands (`abort`, `model_change`) that the brain consumes asynchronously.

## Event Types

| Event           | Key fields                                | Purpose                                   |
|-----------------|-------------------------------------------|-------------------------------------------|
| `session_start` | `task`, `model`                           | Announced once at brain startup           |
| `thinking`      | `step`, `text`                            | Full LLM response before any bash block   |
| `proposed_cmd`  | `step`, `cmd`                             | Bash block extracted; about to execute    |
| `obs`           | `step`, `cmd`, `stdout`, `stderr`, `exit_code` | Result after environment server returns   |
| `done`          | `step`, `output`                          | Sentinel detected in stdout               |
| `error`         | `message`                                 | Step limit, parse failure, or abort       |

## Command Types

| Command        | Key fields               | Effect                                         |
|----------------|--------------------------|------------------------------------------------|
| `abort`        | —                        | Brain exits cleanly after current observation  |
| `model_change` | `model` (provider/name)  | Brain updates SharedMem config; used from next LLM call |

## Protocol Guarantees

- Split on `\n` only—never on Unicode line separators.
- The brain never blocks waiting for stdin; commands are buffered and consumed at the top of each loop iteration.
- In [[concepts/Yolo Mode]], the absence of a confirm/reject/human flow simplifies the protocol, as no user-input loop is required.
- The protocol is easily mockable for integration testing (Phase 4 of [[summaries/AILANG_Agent]]).

## Related Concepts

- [[concepts/Yolo Mode]] ensures the brain is always executing, never idle.
- [[concepts/Option D Model Selection]] uses the `model_change` command for mid-session provider switching.
- [[concepts/AILANG]] provides the brain runtime, while [[concepts/pi-tui]] renders the event stream as Markdown.

See also: [[summaries/Thinking_Traces]]