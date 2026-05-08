---
doc_type: short
full_text: sources/2026-03-30-ailang-swe-agent.md
---

# Summary: AILANG SWE Agent — 2026-03-30

A full software engineering agent was built on top of the AILANG language runtime. The system combines a TypeScript terminal UI and an AILANG brain process communicating over a JSONL pipe, always running in yolo mode.

## Repository layout

- `tui/` — TypeScript frontend: environment server (Express), brain process launcher, pi‑tui terminal UI, model definitions.
- `swe/` — AILANG brain components: message types, command parsing, environment HTTP client, prompt generation, trajectory cache, and main RPC loop.
- `runtime-patches/` — Go patches for an `_io_poll_stdin` builtin required by the brain.
- `scripts/` — install prerequisites and agent runner.

## Architecture ([[concepts/agent architecture]])

Three processes: a Node.js TUI process that owns the terminal and hosts an Express environment server; the environment server executes bash commands via `execSync`; an AILANG subprocess runs the brain logic (`swe/rpc.ail`) and communicates with the TUI over JSONL on stdin/stdout. This design allows the brain to call LLMs, extract bash commands, execute them via the env server, and recurse.

## Key decisions

- **Yolo‑only loop** ([[concepts/yolo mode]]): No confirm/reject step; the agentState carries no mode field. The loop calls the LLM, extracts a bash block, executes it, emits observations, and recurses.
- **JSONL IPC** ([[concepts/JSONL IPC protocol]]): All inter‑process messages are newline‑delimited JSON. The AILANG side uses `readline` splitting on `
` only; malformed lines are silently skipped.
- **Non‑blocking stdin peek** ([[concepts/io poll stdin builtin]]): To allow the brain to receive abort/model‑change commands without blocking, a custom Go builtin `_io_poll_stdin` was implemented. Patches for the AILANG runtime are provided and tested.
- **Model switching** ([[concepts/model switching in agent]]): `/model` changes write the new model name to SharedMem; the running process continues with the original `--ai` flag until the next brain invocation. An optional Phase 5 would swap to a `call_with` function.
- **Trajectory caching** ([[concepts/trajectory caching]]): After a successful run, the final output is stored in SharedMem keyed by task text; on subsequent identical tasks, a hint is injected into the system prompt.

## Bugs fixed during the session

- TypeScript `module` setting corrected from `ESNext` to `Node16`.
- pi‑tui API mismatch: the plan assumed a React‑like options API, but the library uses positional parameters. The UI code was rewritten accordingly (e.g., `Text`, `Box`, `Markdown`, `SelectList`, overlay handling).
- Working directory resolution: a runner script ensures the agent is invoked from the correct directory relative to the repository root.

## Verified outcomes

- TypeScript build passes with zero errors.
- All four environment server acceptance tests pass (echo, nonzero exit, timeout, health check).
- The `_io_poll_stdin` builtin returns an empty string when no input is available.

## Remaining work

- AILANG brain files cannot be type‑checked without a working `ailang check`.
- Phase 5 (dynamic model via `call_with`) is optional and depends on runtime support.
- SWE‑bench benchmarking (Phase 4) and persistent SharedMem storage are pending.
