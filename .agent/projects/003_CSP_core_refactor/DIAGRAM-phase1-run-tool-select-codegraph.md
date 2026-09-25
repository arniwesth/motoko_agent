# Diagram: Phase-1 `run_tool_select` core architecture

Grounded in the refreshed `tools/code-graph` core profile from 2026-07-01:
25/25 modules extracted successfully; graph and source index were not stale.
Call/effect rows are source-parsed approximations, so this diagram uses code-graph
for module/function edges and source-index line anchors for concrete locations.

```mermaid
flowchart TD
  Loop["agent loop<br/>src/core/agent_loop_v2.ail"]
  Hybrid["hybrid synth call site<br/>agent_loop_v2.ail:1738"]
  Batch["normal tool batch call site<br/>agent_loop_v2.ail:1851"]

  Hybrid --> RTS["run_tool_select<br/>agent_loop_v2.ail:1066-1085"]
  Batch --> RTS

  RTS --> Flag{"MOTOKO_RUN_TOOL_SELECT?"}
  Flag -- "0 / default" --> Old["dispatch_calls fallback<br/>agent_loop_v2.ail:1128-1373"]
  Flag -- "1" --> Cancel{"MOTOKO_RUN_TOOL_SELECT_CANCEL?"}

  Cancel -- "yes" --> CancelMsgs["cancelled_tool_messages<br/>provider-valid cancelled results"]
  Cancel -- "no" --> Preflight["policy_preflight<br/>agent_loop_v2.ail:904-944"]

  Preflight --> Policy["ext/runtime.dispatch_tool_policy"]
  Preflight --> Adapter1["tool_dispatch_adapter.tool_call_to_envelope"]
  Preflight --> Denied["policy_denied_message / emit_tool_denied_event"]

  Preflight --> RunPreflighted["run_preflighted_tools"]
  RunPreflighted --> DispatchAllowed["dispatch_allowed_call<br/>agent_loop_v2.ail:946-1037"]

  DispatchAllowed --> Backend["tool_runtime.backend_for_v2"]
  DispatchAllowed --> Envelope["tool_dispatch_adapter.tool_call_to_envelope"]

  DispatchAllowed --> Scratchpad{"scratchpad tool?"}
  Scratchpad -- "yes" --> ScratchRuntime["ext/runtime.dispatch_tool_handle<br/>scratchpad special path"]
  Scratchpad -- "no" --> Native{"native live process requested?"}

  Native -- "no" --> DispatchOne["tool_dispatch_adapter.dispatch_one<br/>existing native/deferred dispatch"]
  Native -- "yes" --> Wrapper["wrapped_stream_process_message<br/>agent_loop_v2.ail:849-888"]

  Wrapper --> StdStream["std/stream.asyncExecProcess<br/>std/stream.selectEvents"]
  StdStream --> PyWrapper["scripts/tool_stream_wrapper.py<br/>captures stdout/stderr/exit"]
  PyWrapper --> Files["stdout/stderr/exit files"]
  Files --> ResultMsg["tool_result_message<br/>stdout + stderr + exit_code"]

  DispatchOne --> ResultMsg
  ScratchRuntime --> ResultMsg
  Denied --> ResultMsg
  CancelMsgs --> ResultMsg

  ResultMsg --> Assemble["tool_messages_to_result_jsons<br/>agent_loop_v2.ail:629-667"]
  Assemble --> Events["native_tool_calls / native_tool_results<br/>batched TUI bracket"]
  Assemble --> ModelNext["tool messages returned to loop<br/>next model step"]

  Old --> ModelNext
```

## Code-Graph Grounding

- `run_tool_select` is called from both tool-phase sites:
  `src/core/agent_loop_v2.ail:1738` for the hybrid synthesized call and
  `src/core/agent_loop_v2.ail:1851` for normal `result.tool_calls`.
- `run_tool_select` invokes `policy_preflight`, `run_preflighted_tools`,
  `cancelled_tool_messages`, and fallback `dispatch_calls`.
- `dispatch_allowed_call` invokes `tool_runtime.backend_for_v2`,
  `tool_dispatch_adapter.dispatch_one`, `tool_dispatch_adapter.tool_call_to_envelope`,
  `ext/runtime.dispatch_tool_handle`, and `wrapped_stream_process_message`.
- `wrapped_stream_process_message` is the current `std/stream` node; code-graph
  records calls to `std/stream.asyncExecProcess` and `std/stream.selectEvents`.
- Raw AILANG v0.26.0 `asyncExecProcess` does not surface stderr, so live process
  tools route through `scripts/tool_stream_wrapper.py` to preserve stdout, stderr,
  and exit-code fidelity.

