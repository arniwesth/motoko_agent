# Context Mode Transparent Bash Output Compression Plan

Date: 2026-06-21
Status: planned

Reference: PR #58 discussion comment:
https://github.com/arniwesth/motoko_agent/pull/58#issuecomment-4761393381

## TL;DR

Do not give extensions a general native-tool execution callback through
`ExtCtx`. Add a narrow post-result hook instead: core runs `BashExec` normally,
then subscribed extensions may transform the completed model-visible JSON result
before it becomes the tool-role message. This keeps native execution, policy,
approval, tracing, backend selection, and provider correlation in core while
letting `context_mode` transparently compress large `stdout`/`stderr` payloads.

## AILANG MCP Grounding

The plan is grounded against the AILANG MCP server configured in `.mcp.json`:

```json
{
  "mcpServers": {
    "ailang-docs": {
      "type": "http",
      "url": "https://mcp.ailang.sunholo.com/mcp/"
    }
  }
}
```

MCP session facts checked on 2026-06-21:

- `initialize` reported server `ailang-api` version `0.8.1`.
- `ailang_versions` reported latest docs version `0.25.0`.
- This repository currently uses local `AILANG v0.24.2`, so implementation must
  satisfy both MCP-documented syntax and the local compiler.

Language and stdlib grounding:

- `prompt_get(forVersion="0.25.0", kind="agent")` confirms AILANG is a strict
  Hindley-Milner language with explicit effect rows, slash-based imports, and
  type-checking through `ailang check`.
- `effects_catalog(forVersion="0.25.0")` confirms the documented effects used by
  this plan's hook signatures: `IO`, `FS`, `Net`, `AI`, `Env`, `Clock`,
  `Process`, and `Stream`.
- `stdlib_module(name="std/json", forVersion="0.25.0")` confirms `Json`,
  `encode`, `decode`, `jo`, `kv`, `js`, `jnum`, and related JSON helpers. This
  grounds the `ToolResultFrame.content: Json` proposal.
- `stdlib_module(name="std/sem", forVersion="0.25.0")` confirms semantic-frame
  storage APIs with `SharedMem` and `SharedIndex` effects, including
  `load_frame`, `store_frame`, `make_frame_at`, and `store_frame_ns`. This
  grounds the plan's use of SharedMem-backed storage for full tool output.
- `stdlib_search(query="Trace emit event telemetry", forVersion="0.25.0")`
  returned no MCP stdlib hits. Treat `Trace` as a Motoko/runtime-local effect
  seen in this repository, not as an AILANG MCP-documented extension ABI effect.
  The plan therefore keeps trace emission in host call sites that already carry
  `Trace`, instead of adding `Trace` to `on_tool_result`.

ABI compatibility grounding:

- MCP searches for `optional record fields default record fields` and
  `record optional field` returned no feature documentation.
- MCP record/type-system docs describe row polymorphism/open record types, not
  optional record fields or defaulted record fields.
- Local `AILANG v0.24.2` checks reject `field?: type`, reject
  `field: type = value` inside record types, and reject record literals that
  omit required fields.

Consequences for this plan:

- Adding `result_tools` and `on_tool_result` to `ExtensionHooks` is a
  source-breaking ABI change.
- Every `ExtensionHooks` record literal in in-repo and active registry packages
  must be updated unless an ABI helper/builder abstraction is introduced first.
- The proposed hook should use MCP-grounded types and effects only. Runtime-local
  tracing remains outside the hook signature.

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

## Why Existing Hooks Do Not Fit

This requires a new hook. None of the existing hooks can transparently transform
native `BashExec` output at the right point in the lifecycle:

- `on_tool_policy` runs before execution and can only allow, deny, defer, or stay
  neutral. It never sees stdout or stderr.
- `on_tool_handle` also runs before native execution. If it returns
  `Handled(result)`, the extension must fully own execution; if it returns
  `Delegate`, native execution continues but the extension never sees the
  completed result.
- `on_response_intercept` sees assistant text responses, not native tool results.
- `on_solver_candidate` sees final-answer candidates, which is too late to
  compress tool output before the next model turn.
- `on_pre_step` can compact or rewrite message history before a later step, but
  by then the large tool result has already entered the conversation. It also
  operates on message text rather than structured tool result payloads, making it
  the wrong layer for preserving tool-call correlation and native result shape.

Therefore the extension boundary needs a post-result decision point: after core
has executed the native tool and before core emits the tool-role message.

## Proposed ABI

Add a narrow post-result hook to `ExtensionHooks`. The hook should operate on
the model-visible native result payload, not on a `ToolResultEnvelope` wrapper
that would force native tools into the extension-result JSON shape.

```ail
import std/json (Json)

export type ToolResultFrame = {
  tool_call_id: string,
  tool: string,
  exit_code: int,
  content: Json
}

export type ToolResultDecision
  = Keep
  | Replace(ToolResultFrame)

export type ExtensionHooks = {
  ...
  result_tools: [string],
  on_tool_result: (ExtCtx, ToolCallEnvelope, ToolResultFrame)
    -> ToolResultDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}
}
```

`result_tools` is the explicit subscription list. For `context_mode`, this would
start with:

```ail
result_tools: ["BashExec", "RunTests"]
```

The hook is called only after a native tool has completed and produced the same
JSON payload that would otherwise become the tool-role message content. For
`BashExec`, that payload is the existing adapter shape:

```json
{
  "tool": "BashExec",
  "cmd": "...",
  "exit_code": 0,
  "stdout": "...",
  "stderr": "...",
  "truncated": false
}
```

This avoids a hidden behavior change where native results would become wrapped
as `{tool_call_id, tool, exit_code, stdout, stderr, metadata}`.

## ABI Compatibility

`ExtensionHooks` comes from `sunholo/motoko_ext_abi`, and in-repo plus registry
extensions construct that record directly. Adding required fields is therefore a
source break for every extension package.

Rollout must be versioned:

1. Bump `sunholo/motoko_ext_abi` and update its exported `ExtensionHooks`.
2. Update every in-repo extension package and smoke-test hook construction.
3. Republish or locally override any registry extension used by the active root
   dependency graph.
4. Regenerate `src/core/ext/registry_generated.ail` and `ailang.lock`.
5. Run extension boot verification before landing runtime wiring.

As grounded above against the AILANG MCP docs and the local `v0.24.2` compiler,
optional/defaulted record fields are not currently available. If AILANG later
supports optional record fields or the ABI package introduces a defaulted
hook-builder abstraction, use that to reduce future ABI churn. For this change,
assume direct record updates are required.

## Dispatch Semantics

1. Existing policy hooks run first.
2. Existing handle hooks run next.
3. If an extension returns `Handled`, core converts that result to the tool-role
   message as it does today. MVP result hooks do not post-process extension-
   handled results.
4. If all extensions delegate, core runs the normal native or delegated backend.
5. For native backend results, core converts the backend result into the existing
   model-visible JSON payload and a `ToolResultFrame`.
6. Core invokes subscribed `on_tool_result` hooks in extension order.
7. The final frame content becomes the tool-role message content.

MVP scope: apply result hooks only to completed native results. The current v2
delegated path returns a synthetic `delegated_backend_not_wired` message, not a
completed delegated tool result, so there is no real delegated result to
compress yet. When the ohmy_pi inbox wait path lands, it can construct a
`ToolResultFrame` from the completed delegated payload and reuse the same hook.

Decision folding:

- `Keep` leaves the current result unchanged.
- `Replace(next)` replaces the current frame and passes it to later result hooks.
- A result hook must not re-enter tool dispatch.
- A hook must preserve `tool_call_id` and `tool`.
- If a hook returns a mismatched `tool_call_id` or `tool`, core should ignore the
  replacement, keep the previous frame, and emit a trace/log event.

## Context Mode Behavior

For `BashExec` and `RunTests`, `context_mode` should:

1. Inspect `stdout`, `stderr`, `exit_code`, and the current JSON content.
2. If output is below threshold, return `Keep`.
3. If output exceeds threshold:
   - store the full output in SharedMem, with optional indexing into
     context-mode;
   - return a compressed summary in `stdout`/`stderr`;
   - preserve command, exit code, and existing result fields;
   - include a stable lookup key in the JSON content for later retrieval.
4. Optionally index durable summaries so later `CtxSearch` can recover facts.

Suggested JSON content shape:

```json
{
  "tool": "BashExec",
  "cmd": "...",
  "exit_code": 0,
  "stdout": "...compressed...",
  "stderr": "",
  "truncated": true,
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
5. In `agent_loop_v2`, avoid the current string-only `dispatch_one` boundary for
   hookable native tools. Add a helper that returns both:
   - the existing adapter JSON payload, and
   - the `ToolResultFrame` used by result hooks.
6. Ensure the hook is called after native execution and before
   `tool_result_message`.
7. In `tool_envelope_dispatch`, convert the native result payload to a
   `ToolResultFrame`, run result hooks, then convert the final frame back to the
   existing `ToolResultEnvelope` convention used by that loopback path:
   - `stdout: encode(frame.content)`
   - `stderr: ""`
   - `metadata: frame.content`
8. Do not call result hooks for denied calls, pending calls, recursive scratchpad
   errors, or the current v2 delegated-deferred synthetic message.
9. Emit trace events from the caller that already has `Trace` in its effect row,
   not from the pure extension runtime helper if that would widen shared runtime
   effects:
   - `ext_tool_result_keep`
   - `ext_tool_result_replace`
   - `ext_tool_result_invalid_replace`
10. Add tests for:
   - no subscribed hook leaves results unchanged;
   - subscribed hook can replace `BashExec` output;
   - multiple hooks fold deterministically;
   - invalid replacement with changed `tool_call_id` or `tool` is ignored;
   - extension-handled results are not post-processed in the MVP.

## Context Mode Implementation Steps

1. Add env-backed config:
   - `CONTEXT_MODE_TRANSPARENT_BASH=0|1`
   - `CONTEXT_MODE_TRANSPARENT_MIN_CHARS`
   - `CONTEXT_MODE_TRANSPARENT_INDEX=0|1`
2. Add a profile/config switch when the runtime config format has a natural
   place for extension settings. Until then, keep env disabled by default.
3. Subscribe to `BashExec` and `RunTests` only when transparent mode is enabled.
4. Implement output thresholding and compression.
5. Store full output under a stable per-session key.
6. Add JSON content fields with the lookup key and original byte counts.
7. Keep explicit `Ctx*` tools unchanged.

## Safety Rules

- Result hooks must not execute the original tool.
- Result hooks must not change `tool_call_id`.
- Result hooks must not change `tool`.
- Core should preserve the previous frame on invalid replacement.
- Result hooks should preserve the native result's required content fields for
  that tool. For `BashExec`, this means `tool`, `cmd`, `exit_code`, `stdout`,
  `stderr`, and `truncated`.
- Compression must preserve enough information for the model to know the command
  succeeded or failed.
- Full command output may contain secrets. Transparent storage should be disabled
  by default unless a profile or environment variable explicitly enables it.

## Open Questions

- Should the full original output live in SharedMem, context-mode's own index, or
  both?
- Should transparent compression be profile-controlled rather than env-only?
- Should `ReadFile` and `Search` be eligible later, or should this first version be
  limited to process-output tools?
- When delegated ohmy_pi results are fully wired, should they pass through the
  same result hook before the model sees them?

## Acceptance Criteria

- Existing explicit `Ctx*` tools still work.
- A plain model-emitted `BashExec` call can return compressed output without the
  model opting into `CtxExecute`.
- Core native dispatch remains the only owner of native process execution.
- Extensions do not receive a general native dispatch callback in `ExtCtx`.
- Tests cover unchanged, replaced, and multi-hook result-processing cases.
- Native `BashExec` result JSON shape remains backward-compatible except for the
  intentional compressed `stdout`/`stderr` content and added `context_mode`
  metadata.
