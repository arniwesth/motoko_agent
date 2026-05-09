---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md]
brief: Retaining conversation history and partial tool results after a user abort so the agent can explain what was attempted in the next turn.
---

# Abort State Preservation

Abort State Preservation is the runtime behavior of keeping the in-flight turn context intact when a user issues an abort during a hybrid step that delegates tool calls. Without this, the agent would lose the assistant’s output, the partial tool calls, and any already returned tool results, making it impossible to explain what was attempted or to continue reasoning about the interrupted task.

In the implementation described in [[summaries/2026-04-26-abort-history-and-omnigraph-delete]], the `run_hybrid_step` function in `rpc.ail` was updated so that when a `DelegatedAborted` signal occurs, instead of returning a bare state, the code:

- Emits the abort error event for the current turn.
- Uses a new helper `delegated_aborted_results` to synthesize per-tool `ToolErrorResult` objects with the message `"aborted"` for each delegated call that did not produce a result.
- Merges the fake aborted results with any native and denied results that arrived before the abort.
- Appends an observation to the conversation history, including the marker `[turn aborted by user before all tool results returned]`.
- Returns the state with the updated messages list and the step counter unchanged.

Because the assistant’s last message and partial tool execution context remain in the conversation, the agent can, on the next turn, describe what was attempted, which tools were invoked, and which results were missing. This preserves alignment with the user’s intent and avoids a silent reset.

This concept is part of the broader [[concepts/abort-handling]] and works in tandem with the [[concepts/guardrail-policy]] that governs safe mutations on branches. The approach ensures that interruptions do not break the agent’s chain of thought, making the system more robust and user-friendly.