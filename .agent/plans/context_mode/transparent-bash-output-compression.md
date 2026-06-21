# Context Mode Transparent Bash Output Compression Plan

Date: 2026-06-21
Status: planned

## Problem

PR #58 fixes `context_mode` as an explicit extension tool provider: the model can call
`CtxSearch`, `ctx_index`, `ctx_execute`, and related tools directly.

That does not solve transparent compression of native `BashExec` output. Today an
extension sees a tool call before native dispatch through `on_tool_handle`, but it
cannot let core run the native tool and then transform the result. It can only:

- return `Handled(result)` and fully own execution, or
- return `Delegate` and lose visibility into the eventual native result.

Adding a generic native execution capability to `ExtCtx` would couple extensions to
core dispatch internals: backend selection, approval state, tracing, delegated
execution, cancellation, result formatting, and recursion safety.

## Goal

Enable `context_mode` to transparently compress or index selected native tool
results, especially `BashExec` and `RunTests`, without making extensions responsible
for executing native tools.

The core boundary should remain:

- core owns policy, approval, backend selection, execution, tracing, and tool-role
  message correlation;
- extensions may inspect and optionally transform completed tool results.

## Non-Goals

- Do not add `run_native_tool` or a general dispatch callback to `ExtCtx`.
- Do not make `context_mode` reimplement `BashExec`.
- Do not require the model to switch from `BashExec` to `CtxExecute` for transparent
  compression.
- Do not change provider-facing tool call correlation semantics.

## Proposed ABI

Add a narrow post-result hook to `ExtensionHooks`.

```ail
export type ToolResultDecision
  = Keep
  | Replace(ToolResultEnvelope)

export type ExtensionHooks = {
  ...
  result_tools: [string],
  on_tool_result: (ExtCtx, ToolCallEnvelope, ToolResultEnvelope)
    -> ToolResultDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
}
```

`result_tools` is the explicit subscription list. For `context_mode`, this would
start with:

```ail
result_tools: ["BashExec", "RunTests"]
```

The hook is called only after a tool has completed and produced a
`ToolResultEnvelope`.

## Dispatch Semantics

1. Existing policy hooks run first.
2. Existing handle hooks run next.
3. If an extension returns `Handled`, core converts that result to the tool-role
   message as it does today.
4. If all extensions delegate, core runs the normal native or delegated backend.
5. Core converts the backend result into a `ToolResultEnvelope`.
6. Core invokes subscribed `on_tool_result` hooks in extension order.
7. The final envelope becomes the tool-role message.

Decision folding:

- `Keep` leaves the current result unchanged.
- `Replace(next)` replaces the current result and passes it to later result hooks.
- A result hook must not re-enter tool dispatch.
- If a result hook fails, core should preserve the original result and attach a
  trace/log event rather than fail the user-visible tool call.

## Context Mode Behavior

For `BashExec` and `RunTests`, `context_mode` should:

1. Inspect `stdout`, `stderr`, `exit_code`, and metadata.
2. If output is below threshold, return `Keep`.
3. If output exceeds threshold:
   - store the full output in context-mode/index storage or SharedMem;
   - return a compressed summary in `stdout`/`stderr`;
   - preserve command, exit code, and truncation metadata;
   - include a stable lookup key in metadata for later retrieval.
4. Optionally index durable summaries so later `CtxSearch` can recover facts.

Suggested metadata shape:

```json
{
  "context_mode": {
    "compressed": true,
    "snapshot_key": "ctxmode:tool-result:<state>:<tool_call_id>",
    "stdout_original_bytes": 123456,
    "stderr_original_bytes": 0
  }
}
```

## Core Implementation Steps

1. Extend the extension ABI package with `ToolResultDecision`, `result_tools`, and
   `on_tool_result`.
2. Update all in-repo extension registrations to provide defaults:
   - `result_tools: []`
   - `on_tool_result: \_ _ _ . Keep`
3. Add `dispatch_tool_result` to `src/core/ext/runtime.ail`.
4. Wire `dispatch_tool_result` into both tool execution paths:
   - `src/core/agent_loop_v2.ail`
   - `src/core/tool_envelope_dispatch.ail`
5. Ensure the hook is called after native/delegated execution and before
   `tool_result_message`.
6. Emit trace events:
   - `ext_tool_result_keep`
   - `ext_tool_result_replace`
   - `ext_tool_result_error`
7. Add tests for:
   - no subscribed hook leaves results unchanged;
   - subscribed hook can replace `BashExec` output;
   - multiple hooks fold deterministically;
   - `Handled` extension results can also pass through result hooks, or document
     if they intentionally do not.

## Context Mode Implementation Steps

1. Add env-backed config:
   - `CONTEXT_MODE_TRANSPARENT_BASH=0|1`
   - `CONTEXT_MODE_TRANSPARENT_MIN_CHARS`
   - `CONTEXT_MODE_TRANSPARENT_INDEX=0|1`
2. Subscribe to `BashExec` and `RunTests` only when transparent mode is enabled.
3. Implement output thresholding and compression.
4. Store full output under a stable per-session key.
5. Add metadata with the lookup key and original byte counts.
6. Keep explicit `Ctx*` tools unchanged.

## Safety Rules

- Result hooks must not execute the original tool.
- Result hooks must not change `tool_call_id`.
- Result hooks should not change `tool` unless they are converting an internal
  extension result with a documented reason.
- Core should preserve the unmodified result on hook failure.
- Compression must preserve enough information for the model to know the command
  succeeded or failed.

## Open Questions

- Should result hooks apply to extension-handled tool results as well as native
  results? Applying them uniformly is simpler, but it lets extensions post-process
  each other.
- Should the full original output live in SharedMem, context-mode's own index, or
  both?
- Should transparent compression be profile-controlled rather than env-only?
- Should `ReadFile` and `Search` be eligible later, or should this first version be
  limited to process-output tools?

## Acceptance Criteria

- Existing explicit `Ctx*` tools still work.
- A plain model-emitted `BashExec` call can return compressed output without the
  model opting into `CtxExecute`.
- Core native dispatch remains the only owner of native process execution.
- Extensions do not receive a general native dispatch callback in `ExtCtx`.
- Tests cover unchanged, replaced, and multi-hook result-processing cases.
