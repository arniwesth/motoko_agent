# Migrate motoko_agent's Tool Loop to upstream std/ai.runTools / step

**Status**: Planned (sprint plan, no code yet)
**Target**: motoko_agent v0.X.X (whichever release the team prefers)
**Depends on**: AILANG **v0.17.0** (M-AI-TOOL-LOOP — shipped upstream 2026-05-05; tagged release pending)
**Companion to**: [arniwesth/motoko_agent#3](https://github.com/arniwesth/motoko_agent/pull/3) — that PR migrates the streaming code path; this one migrates the tool-loop coordination layer.

---

## tl;dr

Upstream AILANG shipped a typed multi-turn tool-dispatch surface in M-AI-TOOL-LOOP:

```ailang
import std/ai (step, runTools, callResult, callJsonResult, AIError, Message, ToolCall, ToolSchema, StepResult)

-- One agent turn
step(model, messages, tools) -> Result[StepResult, AIError] ! {AI}

-- Convenience driver (loop until finish_reason != "tool_calls")
runTools(model, messages, tools, dispatch, step_budget) -> Result[[Message], AIError] ! {AI}
```

**This makes `motoko_agent`'s hand-rolled multi-turn tool loop in `rpc.ail` (~200-400 LOC of streaming + JSON tool-call extraction + correlation tracking) replaceable with a single `runTools(...)` call.** Domain code in `tool_runtime.ail` (~846 LOC of bash/FS/Process tool *implementations*) stays — that's the dispatch callback. Coordination layer collapses.

This sprint plan documents the migration before any code changes land.

## What stays vs what shrinks

| File | LOC today | What stays | What shrinks |
|------|-----------|-----------|--------------|
| `src/core/tool_contract.ail` | 103 | Domain envelope types (`ToolCallEnvelope`, `ToolResultEnvelope` — fork-specific shape with `stdout`/`stderr`/`exit_code`) | ~30 LOC of JSON helpers (now provided by `std/json`) |
| `src/core/tool_runtime.ail` | 846 | All tool implementations: `run_native_batch`, `parse_exec_from_args`, edit-op parsing, path normalization, capability gating | None — this is domain code, not coordination |
| `src/core/rpc.ail` | ~1,000 | Agent state machine, message construction, validation, telemetry helpers | The multi-turn tool-loop driver: `~200-400 LOC` of "stream → extract tool call → run dispatch → re-prompt" boilerplate, replaced with `runTools(model, msgs, tools, dispatch, budget)` |

**Net impact**: ~250–430 LOC removed from `rpc.ail`, ~50–80 LOC of glue added (an adapter that maps motoko's `ToolCallEnvelope` ↔ upstream `ToolCall` for the dispatch callback signature). Net deletion: ~200–350 LOC.

## API-shape adaptation

Upstream's `dispatch: (ToolCall) -> string` returns a single string for the model. Motoko's `run_native_batch` returns `[ToolResultItem]` with rich shell-execution metadata. The migration's adapter does:

```ailang
-- In motoko_agent's new tool-loop driver:
func toolDispatch(call: ToolCall) -> string ! {FS, Process} {
  let envelope = upstreamToolCallToFork(call) in   -- ToolCall → ToolCallEnvelope
  let results = run_native_batch([envelope], workdir) in
  match results {
    [r] => result_to_json_string(r),                -- ToolResultItem → string
    _ => "{\"error\":\"unexpected dispatcher result count\"}"
  }
}

-- Then the entire turn loop becomes:
match runTools(model, conversation, toolCatalog, toolDispatch, budgetSteps) {
  Ok(finalMessages) => {
    -- finalMessages contains the full transcript including assistant + tool messages
    -- Extract the last assistant message for the user-facing answer
    extractLastAssistantText(finalMessages)
  },
  Err(e) => handleError(e)
}
```

The dispatch callback's `! {FS, Process}` effects propagate through `runTools` via row polymorphism — no change to `runTools`'s signature is needed for motoko's effect-rich tools.

## Migration plan

| M | Description | Estimated | Status |
|---|-------------|-----------|--------|
| **M1** | Build a small adapter module `src/core/tool_dispatch_adapter.ail` that wraps `run_native_batch` as a `dispatch_one(workdir, ToolCall) -> string` callback. ~150 LOC + smoke test | 30 min | ✅ Shipped |
| **M2** | Define motoko's tool catalog as `[ToolSchema]` in `src/core/tool_catalog.ail`. ~80 LOC for the existing 6 tools (ReadFile, WriteFile, EditFile, BashExec, RunTests, Search) | 45 min | ✅ Shipped |
| **M3** | Replace `rpc.ail`'s tool-loop body with a `runTools(...)` call. **Scope revised upward** — see "M3 scope finding" below | **1-2 days** (originally estimated 1.5-2 hours) | 🔴 Blocked on design |
| **M4** | Re-run motoko_agent end-to-end (TUI) against a benchmark task that exercises tool dispatch | 30 min + iteration | Pending M3 |
| **M5** | Delete dead coordination code in `rpc.ail` and `tool_contract.ail` after M3 lands. Update CHANGELOG. | 30 min | Pending M3 |

### M3 scope finding (added 2026-05-05 after walking rpc.ail in detail)

The original sprint plan estimated M3 at "1.5-2 hours" assuming the tool loop in `rpc.ail` was a thin layer over `run_native_batch`. **It is not.** The loop interleaves at least 6 distinct decision points that upstream `runTools` doesn't currently model:

1. **Extension intercept dispatch** (`ContinueWithFeedback` / `Accept` / `NoIntercept` / `NoDecision`) — `dispatch_response_intercept` is called BEFORE tool dispatch and can short-circuit the loop with a final answer or inject a feedback message.
2. **Tool-call parser** — motoko's `parse_tool_calls` distinguishes `NoToolCalls` / `ToolParseError` / `ParsedToolCalls`, with the parse-error branch injecting a feedback message rather than retrying.
3. **Tool gating policy** — `apply_tool_policy` filters allowed/denied calls per extension hooks; denied calls become `ToolErrorResult` items.
4. **Tool-handle routing** — `route_tool_handles` lets extensions handle specific tool names directly (returning `ToolResultEnvelope`s) before the native dispatcher sees them.
5. **Backend split** — `split_by_backend` divides calls between native (`run_native_batch`) and delegated (`ohmy_pi`) execution paths.
6. **Continuation-intent detection** — `indicates_continuation_intent` injects a feedback message when the model's prose suggests it wants to continue without emitting tool calls.

Plus per-step `emit_event` calls for telemetry (`ext_tool_calls`, `ext_tool_results`, `native_tool_calls`, `native_tool_results`, `done`, `thinking`).

Upstream `runTools` provides the loop driver but no hooks for steps 1, 3, 4, 5, 6. To preserve motoko's behaviour, M3 needs one of:

- **Option A**: Custom loop in motoko that calls upstream `step` directly and re-implements the extension dispatch / tool gating / backend split between turns. ~600 LOC; close to the existing rpc.ail tool-loop body. Net deletion is small.
- **Option B**: Land all six hooks upstream as parameters / record fields on `runTools` (e.g. `RunToolsConfig { dispatch, on_response, on_call, on_result, ... }`). Substantial upstream design work; would let motoko's loop become ~30 LOC. Coordinate with the AILANG team.
- **Option C**: Migrate motoko to a SIMPLER agent shape — drop ohmy_pi backend split + extension intercepts, accept the loss of those features in exchange for a thin rpc.ail. Larger user-facing decision, not a pure migration.

**Recommendation**: defer M3 until the AILANG team and motoko team align on which option to pursue. M1 + M2 (this PR) are still useful — they lay the foundation for any of A/B/C and let new motoko consumers build on `runTools` directly without going through the legacy `rpc.ail` loop.

**Total estimate (revised)**: M1+M2 shipped; M3 needs a separate design alignment before estimation.

## Open questions for arni

These can be answered after PR #3 (streaming) lands; not blocking:

1. **Tool catalog evolution** — the fork's `tool_runtime.ail` has 6 native tools today. Are there plans for more in flight that would benefit from the upstream `[ToolSchema]` shape?
2. **Per-tool budgets** — `runTools` has a single `step_budget` (max turns). Does motoko need finer-grained per-tool budgets (e.g. "max 5 BashExec calls per task")? If yes, that's a wrapper around `runTools` we'd add to motoko, not an upstream change.
3. **Compose extension hooks** — the `src/core/ext/compose/` extensions intercept tool dispatch decisions today via the fork's runtime. Does the upstream `dispatch: (ToolCall) -> string` callback shape support all the existing extension hooks, or do we need a richer dispatcher signature? The fork's design doc on this would help.

## Why a separate PR (not folding into PR #3)

- **Reviewability**: PR #3 is a 1:1 API swap (callStreamResult → callStream). This PR is a deeper restructure of `rpc.ail`'s control flow.
- **Risk profile**: Streaming primitive is provably equivalent (same wire format, same SSE handling). Tool-loop is a structural change — different review depth needed.
- **Decoupled deployability**: PR #3 unblocks running on upstream v0.15.2 today. This PR can wait for v0.17.0 to tag (currently on dev, not yet released).

---

**Document created**: 2026-05-05
**Last updated**: 2026-05-05
