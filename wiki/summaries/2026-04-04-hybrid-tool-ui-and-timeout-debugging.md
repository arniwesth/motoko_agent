---
doc_type: short
full_text: sources/2026-04-04-hybrid-tool-ui-and-timeout-debugging.md
---

# Summary: 2026-04-04 Hybrid Tool UI & Timeout Debugging

This session focused on improving the user experience and correctness of hybrid (AI + native) tool execution in the TUI, and fixing delegated wait timeout behaviour in the brain runtime.

## Key Changes

- **Tool-call visibility in TUI** – tool calls and result phases (`queued`, `running`, `done/failed`) are now clearly rendered, with raw JSON blocks collapsed from visible thinking output.
- **Native tool rendering** – native calls (e.g., `ReadFile`, `BashExec`) that only appear in thinking JSON are now parsed from ` ```json { tool_calls: ... } ``` ` blocks and displayed explicitly. A `needs_delegation_for_process` semantics check was added to align with the backend classification.
- **Thinking trace parsing** – `` matching works even when not at the start of the string, preventing hidden or mis-rendered thinking content.
- **Delegated abort correctness** – in `swe/rpc.ail`, `DelegatedAborted` now emits `error: aborted` and exits immediately, instead of incorrectly converting an abort into synthetic timeout tool errors and continuing.
- **Delegated timeout policy** – replaced a hardcoded `wait_for_tool_results(..., 300)` with a computed number of attempts based on batch size and configurable environment variables. The formula is  
  `attempts = ceil((delegated_count * per_call_ms + slack_ms) / poll_ms)`, with defaults:
  - `DELEGATED_TOOL_TIMEOUT_MS` = 30000
  - `DELEGATED_TOOL_POLL_MS` = 100
  - `DELEGATED_TOOL_TIMEOUT_SLACK_MS` = 5000
- **Tool event ordering fix** – a user-reported UI anomaly where `[done]` rows appeared before `[queued]` was resolved by reordering the line‑handler in `tui/src/brain.ts` to deliver `tool_calls` before delegated execution state, plus a `setImmediate` when kicking delegated execution to preserve the `queued → running → done` sequence.

## Investigations and Findings

- Reproduced delegated batch runs with 3 × `sleep 12` tools; all completed successfully (`exit=0`) after the timeout‑budget fix.
- Identified misleading UI event order as a major source of confusion.
- Noted that `Unknown command: "Which tools where called?"` appears when a follow‑up is sent before the task‑completion handoff.

## Documentation Added

- Research note: `.agent/research/Hybrid_Tool_Execution_Parallelism_Insight.md` – describes selective parallelism strategies used by modern agents and their implications for AILANG.
- Plan: `.agent/plans/TUI_Wait_State_Clarity.md` – phased UX plan for clearer waiting/progress states in the TUI.

## Validation

- `cd tui && npm run build` – passed
- `cd tui && npm test` – passed
- `ailang check swe/rpc.ail` – passed
- `make check_swe` – passed (11/11)

## Remaining Follow‑ups

1. A P2 review item remains: the model changes received during delegated waits (`DelegatedReceived(hit).model`) are not threaded through the recursion path – they must be preserved.
2. Implement the wait‑state clarity plan from `TUI_Wait_State_Clarity.md`.

## Related Concepts
- [[concepts/hybrid-tool-execution]]
- [[concepts/delegated-tool-timeout-policy]]
- [[concepts/tui-tool-rendering]]
- [[concepts/thinking-trace-parsing]]
- [[concepts/event-ordering-tui]]