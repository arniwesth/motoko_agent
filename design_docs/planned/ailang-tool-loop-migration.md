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

| M | Description | Estimated |
|---|-------------|-----------|
| **M1** | Build a small adapter module `src/core/tool_dispatch_adapter.ail` that wraps `run_native_batch` as a `(ToolCall) -> string` callback. ~50 LOC + unit tests | 30 min |
| **M2** | Define motoko's tool catalog as `[ToolSchema]` (the fork's tool definitions are Json-Schema strings; lift them into AILANG `ToolSchema` records). ~80 LOC for the existing 6 tools (ReadFile, WriteFile, EditFile, BashExec, RunTests, Search) | 45 min |
| **M3** | Replace `rpc.ail`'s tool-loop body with a `runTools(...)` call. Keep telemetry hooks (compose_*, ai_check, etc. emit_event calls) by wrapping them around the runTools call rather than threading through it. Tier 1 smoke per call site | 1.5–2 hours |
| **M4** | Re-run motoko_agent end-to-end (TUI) against a benchmark task that exercises tool dispatch (e.g. "read README.md and summarize") | 30 min + iteration |
| **M5** | Delete dead coordination code in `rpc.ail` and `tool_contract.ail` after M3 lands. Update CHANGELOG. | 30 min |

**Total estimate**: ~3.5–4 hours assuming v0.17.0 is tagged and the upstream API is stable.

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
