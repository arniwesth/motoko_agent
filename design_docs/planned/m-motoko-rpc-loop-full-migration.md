# M-MOTOKO-RPC-LOOP-FULL-MIGRATION: Full rpc_loop → upstream std/ai.step() Migration

**Status**: Planned (sprint plan, ready for execution post arni-review)
**Target**: motoko_agent — downstream consumer release (motoko's own version cadence)
**Priority**: P1 — completes the AILANG fork retirement (the third and final motoko-side migration after PR #3 streaming + PR #4 M1+M2 foundation)
**Estimated**: ~12-15 days realistic (range: 7-25 depending on ohmy_pi + compose-extension wildcards — see §Risk Analysis)
**Dependencies**:
- ✅ PR #3 (streaming migration via `callStream`) — ready for review
- ✅ PR #4 (M1 dispatch adapter + M2 ToolSchema catalog + v2 stress-test loop) — ready for review
- ✅ Empirical validation: v2 stress test verified end-to-end against real OpenRouter+GLM-5 (typed `tool_use` protocol works; no hallucinations)
- AILANG v0.15.2 (shipped 2026-05-05, has `step()` + `runTools()`)

**Author**: Claude + Mark
**Created**: 2026-05-05

---

## Framing

> **Replace motoko_agent's `rpc_loop` (1494 LOC, text-based tool-call parsing) with the upstream typed `std/ai.step()` agent loop, retaining all 6 decision points from rpc_loop's existing behaviour.**

The strategic argument was made in [AILANG's M-AGENT-LOOP-ARCHITECTURE design doc](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_17_0/m-agent-loop-architecture.md) (3 options scored against the 12 axioms; recommended Hybrid path with motoko keeping a custom loop calling `step()` directly). That recommendation is empirically validated by [agent_loop_v2.ail](../../src/core/agent_loop_v2.ail) shipped in PR #4: typed tool dispatch via upstream `step()` round-trips correctly through motoko's existing `run_native_batch` dispatcher.

This document is the implementation plan to take the **stress-test v2** (env-gated, feature-incomplete) to a **production v2** (replaces rpc_loop entirely, retains the 6 decision points, ships compose-extension parity).

## Axiom Compliance

**Canonical reference:** [AILANG Design Axioms](https://ailang.sunholo.com/docs/references/axioms)

This is downstream consumer work, but motoko_agent inherits axiom constraints from AILANG since its agent loop IS an AILANG program.

### Axiom Scoring

| Axiom | Score | Justification |
|-------|-------|---------------|
| A1: Determinism | +1 | Typed step() removes regex-parsing nondeterminism; same input → same parsed tool calls |
| A2: Replayability | +2 | Each step() emits a typed trace event; turn-by-turn replay becomes possible |
| A3: Effect Legibility | +1 | Dispatch callback's effects (FS, Process, ohmy_pi, etc.) flow via row polymorphism |
| A4: Explicit Authority | +1 | Tool gating runs on typed ToolCall — capability decisions are typed, not regex-matched |
| A5: Bounded Verification | 0 | No type-checking impact |
| A6: Safe Concurrency | 0 | Single-threaded loop; no concurrency change |
| A7: Machines First | +2 | Eliminates an ENTIRE class of regex/string-parsing bugs (parse_tool_calls, indicates_continuation_intent, extract_any_tool_json_candidate). Smaller models become reliably tool-using |
| A8: Minimal Syntax | 0 | No new syntax |
| A9: Cost Visibility | +1 | step() returns input_tokens/output_tokens directly; no string-length-based estimation |
| A10: Composability | +1 | dispatch callback is a typed function — composes with extension-supplied alternatives |
| A11: Structured Failure | +2 | Typed AIError replaces string error messages; parse errors disappear (no parsing) |
| A12: System Boundary | +1 | step() boundary is provider-native (Anthropic tool_use, OpenAI tool_calls, Gemini functionCall); no fork-specific protocol |

**Net Score: +12** → **Decision: ✅ Proceed to implementation**

### Hard Violation Check

- [x] A1 (Determinism): improves — eliminates parse-call regex ambiguity
- [x] A3 (Effects): no hidden side effects; dispatch callback effects propagate explicitly
- [x] A4 (Authority): tool gating moves from string-matched to typed ToolCall — strictly safer
- [x] A7 (Machines First): the headline win — removes an entire class of model-behavior bugs

## Problem Statement

**Current state** (after PR #3 + PR #4 M1+M2 land):
- motoko's streaming code path uses upstream `callStream` ✅
- Tool dispatch adapter (`dispatch_one`) and `[ToolSchema]` catalog exist ✅
- v2 loop (`agent_loop_v2.ail`) is env-gated stress test — works for simple tasks but lacks 6 production features ✅

**The remaining gap**:
1. `rpc_loop` (1494 LOC) is still the production agent loop
2. v2 deliberately omits 6 decision points needed for production: extension intercepts, tool gating, tool-handle routing, ohmy_pi backend split, hybrid mode, multi-turn conversation_loop
3. SYSTEM.md still teaches the model the JSON-block protocol (which the typed-`step()` path makes obsolete)
4. Compose extensions (claimcheck, author_loop) hook the prose-based response shape — they need contract changes to work with typed StepResult

**Symptom that triggered this work**: testing on PR #4 with GLM-5 surfaced repeated hallucinations because GLM-5 isn't reliable about emitting JSON-block tool calls inside prose. The typed `tool_use` protocol used by `step()` makes this entire failure mode go away.

**Why this is the LAST migration motoko needs**: with rpc_loop replaced, the AILANG fork (arniwesth/ailang@motoko) has zero remaining users. The fork can be archived.

## Goals

**Primary goal**: replace `rpc_loop` with a production-grade v2 loop using upstream `std/ai.step()`, retaining all 6 decision points from rpc_loop's existing behaviour.

**Success metrics**:
1. **Functional parity**: every rpc_loop test scenario passes against the new loop, including ohmy_pi delegated execution and at least one compose extension (claimcheck or author_loop)
2. **Reliability across models**: GLM-5, MiniMax, Claude, Gemini, GPT all reliably emit typed tool_use blocks (verified via the test matrix in M9)
3. **LOC reduction**: net deletion in motoko of ≥800 LOC (rpc_loop's 1494 → ~600 LOC, plus parse.ail's parse_tool_calls + indicates_continuation_intent gone)
4. **Trace replayability**: each agent turn produces a typed trace event sequence (step → dispatch → step) that can be replayed offline against captured ToolCall responses
5. **AILANG fork retirement unblocked**: with this PR merged, arniwesth/ailang can be archived

**Non-goal**: re-architect compose extensions (claimcheck, author_loop) into a fundamentally different shape. They migrate from "prose response inspection" to "typed StepResult inspection" — same conceptual hook, different data shape. Bigger redesigns are separate sprints.

## High-Impact Decisions

| Decision | Options | Who decides | Change cost |
|----------|---------|-------------|-------------|
| Single sprint vs split releases | (a) one ~3-week sprint completing M3-M10, ships as motoko_agent vX.Y.0; (b) split across 2-3 releases with v2 default-on after each milestone proves stable | arni | (a) all-or-nothing risk; (b) per-milestone deployability but more release overhead |
| ohmy_pi migration scope | (a) full port — ohmy_pi delegated execution works through dispatch callback; (b) defer ohmy_pi temporarily — tools requiring ohmy_pi return ToolErrorResult with "delegated mode disabled in v2" | arni (this is product) | (a) ~3 days + access to ohmy_pi backend; (b) <1 day + user-visible feature loss while v2 stabilizes |
| Compose extension contract change | (a) extensions migrate to typed StepResult inspection; (b) extensions stay on prose mode with a compatibility shim that re-stringifies StepResult; (c) drop compose extensions from v2 path entirely | arni | (a) ~2 days per extension, breaking change to extension contract; (b) ~1 day, perpetuates legacy contract; (c) simplest but loses claimcheck/author_loop |
| SYSTEM.md tool-call instructions | replace JSON-block instructions with tool-list documentation; provider-native typed protocol means the model receives tool schemas via API, not via prompt text | author of this PR | ~1 day across all extension prompts; affects model behavior matrix |
| Default-on switch | when does MOTOKO_AGENT_V2 stop being opt-in? | arni | depends on M9 test matrix outcome; could be "after motoko vX.Y.0" or "after one stable release" |

## Solution Design

### Overview

Single new module `src/core/agent_loop_v2.ail` (already exists from PR #4 stress test) grows from ~180 LOC to ~600 LOC over M3-M9, gaining one decision point per milestone. `rpc_loop` is removed in M10 once v2 has parity. Compose extensions migrate alongside the loop in M5 (their pre-existing surface area).

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│ supervisor.ail                                           │
│   run_with_config()                                     │
│     └─> agent_loop_v2.run_v2(model, msgs, workdir, ...) │
└─────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ agent_loop_v2.ail (PRODUCTION v2 — this design's scope) │
│                                                          │
│   loop_v2(model, messages, workdir, step_idx, budget)   │
│     │                                                    │
│     ├── step(model, messages, tools())  ◄── upstream     │
│     │                                                    │
│     ├── DP1: ext.dispatch_response_intercept(result)    │
│     │   ├── Accept(output) → emit done, return         │
│     │   ├── ContinueWithFeedback(fb) → recurse         │
│     │   └── NoIntercept / NoDecision → continue        │
│     │                                                    │
│     ├── if result.tool_calls empty → emit done, return  │
│     │                                                    │
│     ├── DP3: ext.apply_tool_policy(tool_calls)          │
│     │     gated.allowed, gated.denied                   │
│     │                                                    │
│     ├── DP4: ext.route_tool_handles(gated.allowed)      │
│     │     handled.passthrough, handled.handled          │
│     │                                                    │
│     ├── DP5: split_by_backend(handled.passthrough)      │
│     │   ├── native_calls → run_native_batch  ◄── M1     │
│     │   └── delegated_calls → ohmy_pi.delegate          │
│     │                                                    │
│     ├── DP6: hybrid mode → extract_bash if no calls     │
│     │                                                    │
│     ├── tool_results = denied + handled + native + ohmy │
│     │                                                    │
│     └── recurse: loop_v2(model, msgs ++ results, ...)   │
└─────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│ tool_dispatch_adapter.dispatch_one  ◄── M1 (shipped)    │
│ tool_catalog.tools()                ◄── M2 (shipped)    │
└─────────────────────────────────────────────────────────┘
```

### Implementation Plan (M3-M10)

Each milestone is a separable PR-sized change. Acceptance criteria are concrete. Smoke test = the smallest end-to-end run that proves the milestone works.

#### M3: Extension intercept dispatch (DP1)

**Scope**: integrate `dispatch_response_intercept(ext, response_text)` into v2's per-turn flow. Each step() return calls intercept, branches on `Accept` / `ContinueWithFeedback` / `NoIntercept` / `NoDecision`.

**Files**:
- `src/core/agent_loop_v2.ail` (+150 LOC) — add intercept call between step() result and tool dispatch
- `src/core/types.ail` — no change (ResponseInterceptDecision already typed)
- `src/core/ext/runtime.ail` — verify `dispatch_response_intercept` signature compatible with v2 (likely compatible; arg is response text)

**LOC**: ~150 added to agent_loop_v2; 0 deletions yet (rpc_loop still in place)
**Days**: 1
**Risk**: Low — mechanical wrap; extension contract unchanged
**Dependencies**: M1+M2 shipped; v2 stress test working

**Success criteria**:
- v2 calls `dispatch_response_intercept` on each step
- `Accept(output)` short-circuits the loop with `done` event carrying `output`
- `ContinueWithFeedback(fb)` injects a user-role message with `fb` and recurses
- `NoIntercept` / `NoDecision` falls through to tool dispatch unchanged

**Smoke test**: write a synthetic compose-extension stub that always returns `Accept("intercepted")` from `dispatch_response_intercept`. Run any task; verify v2 emits `done` with `"intercepted"` instead of running the model's tool calls.

#### M4: Tool gating policy (DP3)

**Scope**: run `apply_tool_policy(parsed.calls, ext, ctx)` against typed `[ToolCall]` from step(). Translate ToolCall → ToolCallEnvelope (already in M1 adapter), pass to existing gating logic, get back `gated.allowed` and `gated.denied`. Denied calls become tool-result messages with denial reason.

**Files**:
- `src/core/agent_loop_v2.ail` (+100 LOC)
- `src/core/tool_dispatch_adapter.ail` — possibly +20 LOC for the typed→envelope batch translator (or reuse single-call translator in a list helper)

**LOC**: ~120
**Days**: 0.5
**Risk**: Low — adapter already handles single ToolCall ↔ envelope; this batches
**Dependencies**: M3 (intercept must run before gating)

**Success criteria**:
- v2 calls `apply_tool_policy` on every typed ToolCall list before dispatch
- `gated.allowed` flows to native dispatch; `gated.denied` becomes tool-role messages with `{"error": true, "denied_by_policy": "<reason>"}` JSON
- Gated-but-denied tool calls do NOT reach `run_native_batch`

**Smoke test**: synthetic compose-extension stub denies any `BashExec` call. Run task asking the model to use BashExec; verify tool-result message says "denied" and the model's next turn sees that denial.

#### M5: Tool-handle routing + Compose extension contract (DP4)

**Scope**: integrate `route_tool_handles(gated.allowed, ext, ctx)` to let extensions handle specific tool names directly (returning `ToolResultEnvelope`s) before native dispatch. Migrate compose extensions (claimcheck, author_loop) to inspect typed `StepResult` instead of prose text.

**Files**:
- `src/core/agent_loop_v2.ail` (+150 LOC)
- `src/core/ext/compose/claimcheck.ail` — refactor to take `StepResult` instead of prose
- `src/core/ext/compose/author_loop.ail` — same
- `src/core/ext/types.ail` — possibly extend `ResponseInterceptDecision` to carry typed StepResult info

**LOC**: ~300 (heaviest individual milestone)
**Days**: 2
**Risk**: **Medium** — this is the compose-extension contract change wildcard. Per arni's input on §High-Impact Decisions, choose between (a) typed migration, (b) shim, or (c) drop.

**Dependencies**: M4 must land first; arni decision on extension migration approach

**Success criteria**:
- Extension-routed tools (e.g. `compose_check_premise`) bypass `run_native_batch` and return their own `ToolResultEnvelope`
- claimcheck still validates compose-author output between turns (or whatever its hook semantics are post-migration)
- author_loop still injects multi-attempt feedback for ailang-snippet authoring (or its post-migration equivalent)

**Smoke test**: run motoko's existing claimcheck-using benchmark task; verify the validator still triggers and shapes the conversation as before.

#### M6: Native vs ohmy_pi backend split (DP5)

**Scope**: integrate `split_by_backend(handled.passthrough, settings.ohmy_pi)`. Native calls go through `run_native_batch` (already wired). Delegated calls go through ohmy_pi's existing infrastructure.

**Files**:
- `src/core/agent_loop_v2.ail` (+200 LOC)
- `src/core/ohmy_pi/*.ail` (no change expected — calling existing API)
- `src/core/tool_dispatch_adapter.ail` — possibly +30 LOC if ohmy_pi needs a parallel dispatcher

**LOC**: ~230
**Days**: 1-3 (depends on ohmy_pi infrastructure — see §Risk Analysis)
**Risk**: **High** — this is the ohmy_pi wildcard. If clean abstractions exist, ~1 day. If ohmy_pi is tangled with prose-based response shape, ~3 days + arni input.

**Dependencies**: M5 (handled tool calls must be filtered out before backend split)

**Success criteria**:
- Native tool calls (BashExec, ReadFile, etc.) dispatch through `run_native_batch` exactly as today
- Delegated tool calls dispatch through ohmy_pi's existing client and return `ToolResultEnvelope`s
- Mixed batches (some native, some delegated) work correctly
- `settings.ohmy_pi = false` falls back to all-native dispatch with no errors

**Smoke test**: configure motoko with `ohmy_pi = true` and a remote backend; run a task that triggers at least one delegated tool call; verify both paths complete and feed back to the model correctly.

#### M7: Hybrid mode (extract_bash shorthand) (DP6)

**Scope**: when the model emits prose without tool calls but the prose contains a bash-shorthand prefix (e.g. `$ ls -la` at line start), `extract_bash` parses it as if it were a `BashExec` tool call. Mostly relevant for hybrid-trained models that occasionally emit shell prefix instead of JSON.

**Files**:
- `src/core/agent_loop_v2.ail` (+100 LOC)
- `src/core/parse.ail` — keep `extract_bash` (still useful); remove `parse_tool_calls`, `indicates_continuation_intent`, `extract_any_tool_json_candidate`

**LOC**: ~100 added to v2; ~400 LOC removable from parse.ail (the JSON-block parsing layer)
**Days**: 0.5
**Risk**: Low

**Dependencies**: M6 (hybrid only kicks in when no typed tool_calls returned)

**Success criteria**:
- v2 falls through to `extract_bash` when `step()` returns `tool_calls=[]` AND `finish_reason="stop"` AND prose contains a bash-shorthand prefix
- Extracted bash command becomes a synthetic `BashExec` tool call dispatched through native path
- Net deletion: ~400 LOC from parse.ail (entire JSON-block parsing layer is dead with typed step())

**Smoke test**: `MOTOKO_AGENT_V2=1 motoko "$ pwd"` (the prompt itself uses shell shorthand); model echoes back `$ pwd` in prose; v2 extracts and runs as BashExec.

#### M8: Multi-turn conversation_loop

**Scope**: after v2's main task completes (`done` event), loop back for the user's next task input. Equivalent to motoko's existing `conversation_loop` but built on v2's typed-message state.

**Files**:
- `src/core/agent_loop_v2.ail` (+80 LOC)
- `src/core/rpc.ail` — drop the env-var branch from M3-stress-test wiring; v2 becomes the only path

**LOC**: ~80
**Days**: 0.5
**Risk**: Low — mechanical loop around `loop_v2` with TUI input wait

**Dependencies**: M3-M7 complete

**Success criteria**:
- After agent emits `done`, v2 awaits next user input via stdin/env-server
- New user message gets appended to the running message history
- Loop resumes via fresh `step()` call with the appended history

**Smoke test**: TUI session — submit "what folder are you in?", then after answer, submit "what files are there?"; verify both turns succeed without restart.

#### M9: Test matrix — all models × all tools

**Scope**: validate v2 across the model providers AILANG supports. Each model × at least one tool-using benchmark task. Capture any model-specific quirks (e.g. Gemini's functionCall ID generation, OpenAI's argument-string-vs-object).

**Files**:
- `scripts/v2_test_matrix.sh` — driver that runs a small benchmark suite against each model
- `benchmarks/v2_smoke/*.ail` — 3-5 benchmark tasks (single-tool, multi-tool, gated, intercepted, error)
- `docs/v2-model-compatibility.md` — observed behavior per model

**LOC**: ~150 (mostly script + benchmark task wrappers)
**Days**: 2-3 (driver work is fast; debugging model-specific quirks is the time sink)
**Risk**: **Medium** — likely surfaces 2-3 per-model bugs that need fixes in upstream `std/ai/<provider>/step.go`

**Dependencies**: M3-M8 complete

**Success criteria**:
- Claude Sonnet 4.5: 5/5 benchmark tasks pass
- Gemini 3 Pro: 5/5 pass (likely to surface functionCall ID quirks)
- GPT-5: 5/5 pass
- GLM-5: 4/5 pass (acceptable — smaller model, occasional tool-use failures expected)
- MiniMax M2.7: 4/5 pass
- Any per-provider bug found gets a regression test in upstream AILANG (`internal/ai/<provider>/step_test.go`)

**Smoke test**: `bash scripts/v2_test_matrix.sh > matrix.log`; visual inspection of pass-rate matrix.

#### M10: Production cutover — delete rpc_loop, drop opt-in env var

**Scope**: with M3-M9 validated, v2 becomes the only agent loop. Delete `rpc_loop`, `parse_tool_calls`, `indicates_continuation_intent`, `extract_any_tool_json_candidate`. Update SYSTEM.md to drop JSON-block protocol instructions (provider-native tool schemas replace prompt-taught format).

**Files**:
- `src/core/rpc.ail` — drop `rpc_loop`, `conversation_loop`, the env-var branch (~600 LOC deletion). Rename to `agent_loop.ail` since the file's surface is now just `run_with_config`.
- `src/core/parse.ail` — drop the dead string-matching layer (~400 LOC deletion); keep only `parse_cwd`, `extract_bash`, `assistant_history_content` (still used)
- `src/core/agent_loop_v2.ail` — rename to `src/core/agent_loop.ail`; drop the `_v2` suffix from `run_v2`
- `SYSTEM.md` — replace "emit JSON tool_calls block" instructions with "tools are provided to you via the API; emit them via your provider's tool-use protocol"
- `src/tui/src/runtime-process.ts` — drop `MOTOKO_AGENT_V2` env var forwarding (no longer needed)

**LOC**: net deletion ~1000 LOC across the project
**Days**: 1
**Risk**: Low (the work is verified at this point — this is just cleanup)

**Dependencies**: M9 (test matrix shows v2 production-ready)

**Success criteria**:
- `make check_core` passes (now ~22-3 = 19 modules, since dead modules removed)
- All benchmark tasks pass without `MOTOKO_AGENT_V2` env var
- AILANG fork retirement: arniwesth/ailang has zero remaining users; can be archived
- Net LOC deleted from motoko_agent: ~1000+ LOC

**Smoke test**: same matrix as M9, but without the env var. All pass.

### Files to Modify/Create

| Path | M | LOC delta | Type |
|------|---|-----------|------|
| `src/core/agent_loop_v2.ail` | M3-M10 | +600 / -180 (rename to agent_loop.ail in M10) | Heaviest changes |
| `src/core/rpc.ail` | M10 | -1300 (most deleted) | Major deletion |
| `src/core/parse.ail` | M7+M10 | -400 (dead text-parsing) | Cleanup |
| `src/core/ext/compose/claimcheck.ail` | M5 | ±200 (contract change) | Wildcard |
| `src/core/ext/compose/author_loop.ail` | M5 | ±200 (contract change) | Wildcard |
| `src/core/ext/types.ail` | M5 | +50 (typed StepResult info if needed) | Small |
| `src/core/tool_dispatch_adapter.ail` | M4+M6 | +50 (batch + delegated dispatch) | Small additions |
| `SYSTEM.md` | M10 | rewrite tool-call instructions | Behavior-affecting |
| `src/tui/src/runtime-process.ts` | M10 | -3 (drop env var) | Cleanup |
| `scripts/v2_test_matrix.sh` (NEW) | M9 | +150 | Test infrastructure |
| `benchmarks/v2_smoke/*.ail` (NEW) | M9 | +200 | Test fixtures |
| `docs/v2-model-compatibility.md` (NEW) | M9 | +100 | Reference doc |

**Net**: ~1000 LOC deletion across the system, ~700 LOC added → **~300 LOC net removal**.

## Examples

**Before (rpc_loop with text parsing)**:

```ailang
match ai_stream_call_with_retry(fmt_msgs(state.msgs), ...) {
  Ok(response) => {
    let think_split = split_think_answer(response);
    -- ...
    match parse_tool_calls(response) {
      NoToolCalls => {
        match dispatch_solver_candidate(ext, ctx, response) {
          Accept(out) => done(out),
          ContinueWithFeedback(fb) => recurse_with_feedback(fb),
          NoDecision =>
            if indicates_continuation_intent(response)
            then inject_continuation_feedback()
            else done(response)
        }
      },
      ToolParseError(err) => inject_parse_error_feedback(err),
      ParsedToolCalls(parsed) => {
        let gated = apply_tool_policy(parsed.calls, ext, ctx);
        let handled = route_tool_handles(gated.allowed, ext, ctx);
        let by_backend = split_by_backend(handled.passthrough, settings.ohmy_pi);
        let native = run_native_batch(by_backend.native, settings.workdir);
        let delegated = ohmy_pi.delegate(by_backend.delegated);
        recurse_with_results(gated.denied ++ handled.handled ++ native ++ delegated)
      }
    }
  },
  Err(e) => emit_error(e)
}
```

**After (typed step() loop)**:

```ailang
match step(model, messages, tools()) {
  Ok(result) => {
    emit_thinking_events(result);
    match dispatch_response_intercept(ext, result.message.content) {
      Accept(out) => done(out),
      ContinueWithFeedback(fb) => recurse_with_feedback(fb),
      _ => {
        if result.finish_reason != "tool_calls" then done(result.message.content)
        else {
          let gated = apply_tool_policy_typed(result.tool_calls, ext, ctx);
          let handled = route_tool_handles_typed(gated.allowed, ext, ctx);
          let by_backend = split_by_backend_typed(handled.passthrough);
          let native = dispatch_calls(by_backend.native, workdir);
          let delegated = ohmy_pi_dispatch(by_backend.delegated);
          recurse_with_results(gated.denied ++ handled.handled ++ native ++ delegated)
        }
      }
    }
  },
  Err(e) => emit_error(e)
}
```

The shape is **isomorphic** — every decision point survives. The win is at the leaves: typed `result.tool_calls` replaces regex-parsed `parsed.calls`, eliminating an entire class of failure modes.

## Conflict Surface

**This section is required per the new design-doc gate** because this PR touches motoko's PUBLIC AGENT LOOP — the heart of the product. While the change is downstream-only (no AILANG core changes), motoko users (compose extensions, ohmy_pi backend, the TUI itself) all interact with the loop's behavior.

### Surface positions touched

- **The agent loop's main control flow** in `rpc.ail` → `agent_loop_v2.ail`. Anything that imports `rpc_loop` or `conversation_loop` directly would break (none in current codebase verified, but external callers of motoko's API surface should be checked).
- **Compose extensions' input contract**: `dispatch_response_intercept` currently receives prose; M5 may change it to also receive typed StepResult. Extensions that use this hook are: claimcheck, author_loop. Per the wildcard analysis, this is the second-highest-risk contract change.
- **`SYSTEM.md` content**: changes the model's instructions about tool-use protocol. Affects model behavior across all providers — Claude/Gemini/GPT/etc. all see new instructions.
- **`tool_runtime.ail`'s argument extraction**: assumes the JSON-block protocol's argument shape. If providers' typed tool_use blocks differ on argument shape (Anthropic uses JSON object, OpenAI uses JSON STRING), the M1 adapter handles the impedance match — but compose extensions that read arguments directly need to verify.

### What else lives here

| Position | Existing valid form | Shape | Conflict risk |
|----------|--------------------|-------|---------------|
| Compose extensions reading model response | Prose string passed to `dispatch_response_intercept` | `string` | Medium — M5 may change shape; extensions need migration |
| ohmy_pi delegated dispatch | Receives `ToolCallEnvelope[]` from rpc_loop | `[ToolCallEnvelope]` | Low — adapter already translates ToolCall → ToolCallEnvelope |
| TUI rendering | Receives `thinking_*` / `done` / `native_tool_*` events | JSON event stream | Low — v2 emits same event shapes |
| Trajectory cache | Reads `task_from_msgs(state.msgs)` and writes via `put_trajectory` | motoko Msg shape | Medium — v2 uses upstream Message; need bidirectional translator |
| Telemetry (compose_*, ai_check) | Emit JSON events from rpc_loop directly | JSON lines | Low — relocate emission sites |

### Disambiguation strategy

- **Backwards compat**: M3-M9 keep rpc_loop AS-IS, gated by `MOTOKO_AGENT_V2`. Default OFF. Users who don't opt in see zero behavior change. Users who opt in get the new path with feature gaps closed milestone-by-milestone.
- **Compose-extension contract**: per arni's M5 decision (a/b/c), either typed migration (clean break, with codemod), shim (legacy contract preserved), or drop (loses features).
- **SYSTEM.md change**: applies only to the v2 path. Old SYSTEM.md is preserved for rpc_loop until M10 deletes both.

### Programs that MUST still work post-change

1. **Existing motoko benchmarks** — single-turn tasks like "summarize README.md" must still complete with the same output shape
2. **Compose extension flows** — claimcheck-validated authoring, author_loop multi-attempt snippets must produce equivalent results
3. **ohmy_pi delegated execution** — tasks that route specific tools to a remote backend must still route correctly
4. **TUI session resumption** — multi-turn conversations (M8) must work as well as today
5. **All 5 model providers** — the M9 test matrix is the gate

### What deliberately changes (Option A confirmed)

- Model behavior with very small OS models: GLM-5/MiniMax become MORE reliable (typed tool_use eliminates JSON-block hallucination class)
- Compose extension contract: typed StepResult inspection replaces prose inspection (per M5 option (a))
- SYSTEM.md: tool-call format instructions removed (provider-native typed protocol)
- `parse_tool_calls`, `indicates_continuation_intent`, `extract_any_tool_json_candidate`: deleted in M10

## Success Criteria

This is a multi-PR sprint. Per-milestone success criteria are listed in §Implementation Plan. Sprint-level success:

- [ ] All M3-M10 milestones complete
- [ ] M9 test matrix shows ≥80% pass rate across 5 providers × 5 benchmark tasks
- [ ] LOC reduction: net ≥800 LOC removed from motoko_agent
- [ ] AILANG fork (arniwesth/ailang@motoko) archived
- [ ] motoko's CHANGELOG entry references all 6 decision points retained vs the original rpc_loop behavior

## Testing Strategy

**Unit tests**: each milestone gets its own AILANG-side smoke (e.g. `scripts/smoke_v2_intercept.ail` for M3, etc.). All must pass before milestone is considered complete.

**Integration tests** (M9 test matrix): the load-bearing test suite. Provider × task matrix run against real LLM APIs. Captured in `docs/v2-model-compatibility.md`.

**Regression-surface tests**: the existing AILANG fork's tests get ported to upstream-AILANG-targeted equivalents. Specifically: any test that calls `parse_tool_calls` directly gets rewritten to construct typed StepResult.

## Risk Analysis

### Wildcard 1: ohmy_pi backend complexity (M6)

**Why uncertain**: ohmy_pi is fork-only delegated-execution infrastructure not in upstream AILANG. The fork's existing implementation (in `src/core/ohmy_pi/*.ail`) has its own request/response cycle, polling, timeout handling. Whether it slots cleanly into v2's typed-tool-call flow or needs partial rewrite depends on details only arni's team knows.

**Information needed from arni**:
1. Does `ohmy_pi.delegate(envelopes)` return synchronously (waits for results) or async (poll-based)?
2. Are delegated tool results equivalent to native ToolResultEnvelopes, or do they have different schema?
3. Is delegated execution still under active development, or stable?
4. Are there ohmy_pi-specific tools (not in motoko's native catalog) that need ToolSchema entries?

**Mitigation**: budget 1-3 days for M6 with arni standing by for clarifying questions; fallback to the option (b) defer ohmy_pi from §High-Impact Decisions if blocking.

### Wildcard 2: Compose extension contract change (M5)

**Why uncertain**: claimcheck and author_loop are intricate. Their behavior depends on patterns observed in model prose; a contract change to typed StepResult inspection might lose information they currently extract from prose-only signals.

**Information needed from arni**:
1. Are claimcheck/author_loop production-critical for motoko users?
2. What % of agent runs use these extensions? (informs whether the migration is high or low priority)
3. Is there an extension-author maintainer who can co-design the migration?

**Mitigation**: M5 options (a/b/c) — pick at sprint start, not mid-sprint.

### Risk: SYSTEM.md changes shift model behavior unpredictably

The instructions to the model affect every turn. Replacing JSON-block instructions with provider-native protocol means models receive tools via API alongside the system prompt — but the system prompt itself still influences how the model approaches the task.

**Mitigation**: M9 test matrix is the gate. If models behave worse on benchmarks after SYSTEM.md change, iterate on prompt phrasing.

### Risk: Bug in upstream `step()` provider implementation

The 5 provider implementations (`internal/ai/{anthropic,gemini,openai,openrouter,ollama}/step.go`) shipped recently in M-AI-TOOL-LOOP. Any per-provider bugs not caught by upstream tests will surface in M9.

**Mitigation**: every bug found in M9 produces an upstream regression test against `internal/ai/<provider>/step_test.go`. Bugs become AILANG-side fixes that ship in patches.

## Timeline

**Recommended cadence: single 3-week sprint.**

Reasoning: the milestones are tightly coupled (each builds on the previous; v2 isn't useful until M3-M8 are all done because it's missing features users depend on). Splitting across releases means users see "v2 mode is here but missing X, Y, Z" for 2-3 release cycles, which is worse UX than waiting for the complete migration.

| Week | Milestones | Days | Risk |
|------|-----------|------|------|
| **Week 1** | M3 (intercept) + M4 (gating) + start M5 (compose contract decision call w/ arni) | 4-5 | Medium (M5 decision gate) |
| **Week 2** | Finish M5 + M6 (ohmy_pi) + M7 (hybrid) | 4-5 | High (ohmy_pi wildcard) |
| **Week 3** | M8 (conversation loop) + M9 (test matrix) + M10 (cutover) | 3-4 | Medium (M9 surfaces per-provider bugs) |

**Variance bands** (per §Risk Analysis):
- **Optimistic** (clean ohmy_pi + option (a) compose migration with no per-provider bugs): 9 days
- **Realistic**: 12-15 days (3 weeks)
- **Pessimistic** (ohmy_pi rewrite needed + 2-3 per-provider bugs surfaced + compose migration drags): 20-25 days

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| ohmy_pi backend split is high-touch | Medium | High | arni clarifies §Wildcard 1 questions before M6 starts; fallback to defer ohmy_pi (option b) if blocking |
| Compose extension migration is bigger than expected | Medium | Medium | M5 decision gate forces explicit choice between (a/b/c) options |
| Per-provider step() bug discovered late | Medium | Medium | M9 surfaces; each becomes an upstream patch |
| SYSTEM.md change degrades model behavior | Low | Medium | M9 test matrix catches; iterate phrasing |
| Sprint overruns 3 weeks | Medium | Low | acceptable — doc estimates 12-15 days; budget extra week |
| AILANG upstream API breaks during sprint | Low | High | pin AILANG to v0.15.2 (or v0.16.x stable); bump explicitly post-sprint |

## Related Documents

**Direct predecessors**:
- [AILANG: M-AGENT-LOOP-ARCHITECTURE](https://github.com/sunholo-data/ailang/blob/dev/design_docs/planned/v0_17_0/m-agent-loop-architecture.md) — the Option A/B/C decision; this doc executes Option A
- [motoko: ailang-tool-loop-migration](./ailang-tool-loop-migration.md) — the M1-M5 sprint plan, scope finding, recommended split into M1+M2 (shipped) vs M3+ (this doc)
- [AILANG: M-AI-TOOL-LOOP](https://github.com/sunholo-data/ailang/blob/dev/design_docs/implemented/v0_17_x/m-ai-tool-loop.md) — the upstream sprint that shipped step() + runTools()

**Companion AILANG-side**:
- [AILANG: M-AI-CALL-STREAM-HELPER](https://github.com/sunholo-data/ailang/blob/dev/design_docs/implemented/v0_15_1/m-ai-call-stream-helper.md) — streaming-side migration pattern (PR #3 reference)
- [AILANG: M-AI-PROVIDER-CONFIG](https://github.com/sunholo-data/ailang/blob/dev/design_docs/implemented/v0_15_0/m-ai-provider-config.md) — the upstream change PR #3 consumes

**External consumer signals**:
- [PR #3 (streaming migration)](https://github.com/arniwesth/motoko_agent/pull/3) — ready for review
- [PR #4 (M1+M2 + v2 stress test)](https://github.com/arniwesth/motoko_agent/pull/4) — ready for review; this design doc lives on the same branch
- [arniwesth/ailang@motoko](https://github.com/arniwesth/ailang/tree/motoko) — the fork that gets archived in M10

**Process docs**:
- [AILANG: Conflict Surface design-doc gate](https://github.com/sunholo-data/ailang/blob/dev/.claude/skills/design-doc-creator/resources/design_doc_structure.md) — the gate this doc passes against
- [AILANG: M-PERF6B-PIPE-FLUSH + M-PARSER-REFINEMENT-LOOKAHEAD](https://github.com/sunholo-data/ailang/blob/dev/changelogs/v0.10-current.md) — case studies for why external-consumer evidence catches what internal testing misses

## Future Work

After M10 lands and the AILANG fork is archived:

1. **Per-tool budgets** — extend ToolPolicyDecision to include "deny if would exceed budget"; layer cost-aware tool gating on top of M4. Connects to AILANG's M-EVAL-COST-AND-SPEED-BUDGETS work.
2. **Trace replay** — capture step()'s typed responses to disk; enable offline replay of agent sessions for debugging.
3. **Compose-extension SDK** — extract claimcheck / author_loop's contracts into a reusable extension toolkit that other AILANG agents can consume.
4. **Upstream M-AGENT-COMPOSABILITY** (Option B from the architecture doc) — once motoko's custom loop is the validated prototype, propose extending upstream `runTools` with hook parameters so eval-harness, docparse legal review, and hypothetical agent SDKs can share the same kernel.

---

**Document created**: 2026-05-05
**Last updated**: 2026-05-05
**Author**: Claude (with input from Mark + arni's PR #4 thread)
**Status**: Awaiting arni review on the 5 wildcards (§High-Impact Decisions) before sprint-executor can run the plan
