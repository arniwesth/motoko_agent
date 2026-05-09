---
sources: [summaries/TUI_OM_Command_Patterns.md, summaries/AILANG_Agent.md]
brief: Autonomous execution mode where every proposed command runs immediately without user confirmation.
---

# Yolo Execution Mode

## Definition

**Yolo Execution Mode** is an autonomous agent execution strategy in which every command proposed by the LLM is executed **immediately** — without any human confirmation, rejection, or interruption. The name derives from "You Only Live Once," capturing the risk-tolerant, fully automatic nature of the mode.

In the context of [[summaries/AILANG_Agent]], yolo mode simplifies both the AILANG brain and the TypeScript frontend by eliminating the need for confirm/reject/human flows. The agent never pauses for user input between steps; it emits a `proposed_cmd` event and immediately dispatches the command to the [[concepts/Environment Server]].

## Why Yolo?

Traditional SWE agents often implement a **confirm/reject** loop: the user or a supervisor must approve each command before execution. This adds friction and UX complexity. Yolo mode removes that friction for scenarios where the agent can be trusted to operate autonomously within a sandboxed environment.

Key benefits:
- **Simpler brain**: No `Mode` ADT, no branching logic for human-in-the-loop.
- **Simpler protocol**: The JSONL protocol needs fewer command/event types; no `request_approval` / `user_decision` round-trips.
- **Lower latency**: No waiting for human response between steps.

## Implementation in AILANG SWE-Agent

### AILANG Brain (`swe/rpc.ail`)

The `rpc_loop` function is the core of the yolo brain. Each iteration:
1. Checks for an abort or model-change command via `_io_poll_stdin` (non-blocking).
2. Calls the LLM and emits the full response as a `thinking` event.
3. Extracts the bash block (`extract_bash`).
4. **Immediately** executes the command via `exec_in` on the environment server — no pause, no approval.
5. Emits the `obs` event with stdout/stderr/exit_code.
6. If the sentinel `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT` is detected, emits `done` and exits.

Because the brain never blocks waiting for stdin between steps, commands (`abort`, `model_change`) are buffered and consumed at the top of each loop iteration. This avoids any need for async stdin reading in AILANG.

### Frontend (TypeScript / pi-tui)

The frontend does not implement any confirm/reject UI. It simply renders:
- LLM responses as Markdown (`thinking` events)
- Proposed commands in bold cyan (`proposed_cmd` events)
- Command output with exit-code coloring (`obs` events)

The `/abort` command (or Ctrl+C) is the only user interaction available mid-run, sending an `abort` message to the brain.

## Implications

- **Safety**: Yolo mode assumes the agent operates in a sandboxed environment via the [[concepts/Environment Server]], which runs commands in a specified workdir and enforces timeouts.
- **Traceability**: All steps are recorded in the JSONL trace (`--emit-trace trace.jsonl`), providing an audit trail.
- **No Mode ADT**: The `AgentState` type in `swe/types.ail` carries no mode field — the agent is **always** yolo.
- **Non-blocking stdin check**: The `_io_poll_stdin` builtin is the only runtime addition needed to support abort/model-change while running yolo.

## Related Concepts
- [[concepts/Option D Model Selection]] — model can be switched mid-session without leaving yolo mode
- [[concepts/JSONL Protocol]] — event stream that carries `proposed_cmd` and `obs` without any `request_approval` round-trip
- [[concepts/Environment Server]] — sandbox that makes yolo mode safe by isolating command execution
- [[concepts/SharedMem Cache]] — trajectory hints stored across runs, independent of execution mode

See also: [[summaries/TUI_OM_Command_Patterns]]