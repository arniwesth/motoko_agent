# M-MOTOKO-STUB-STEP — Stub-step fixture for loop_v2 integration testing

**Status**: Planned  
**Priority**: P1 — gates behavioral verification of three shipped features + unblocks downstream sprints  
**Estimated effort**: 1–2 days (~230 LOC)  
**Dependencies**: `motoko-dx-compaction-pending` merged (Pending policy, compaction DP0, cost budget all on this branch)  
**Source**: motoko-explore inbox msg `7dff5bd4` (2026-05-06)

---

## Problem

Three features shipped in the `motoko-dx-compaction-pending` branch have layer-1 algebraic verification (pure-function contracts, inline tests) but **no integration round-trip** through `loop_v2`:

| Feature | Layer-1 smoke | Integration gap |
|---|---|---|
| Pending policy (`61af8be`) | `smoke_v2_pending.ail` — 10/10 merge-priority cases | Extension issues `Pending` → `tool_pending` event → stdin `approve`/`deny` → correct outcome |
| Compaction DP0 (`86848d8`) | `smoke_v2_compaction*.ail` — 10/10 across tiers | Live loop with growing tool_result history actually fires DP0 elision pre-step |
| Cost budget (`7488b57`) | `smoke_v2_cost_budget.ail` — 13/13 math + threshold logic | Live loop accumulates `total_cost_millicents` across steps; `cost_warning` and `cost_exhausted` fire at correct thresholds |

**Shared blocker**: `loop_v2` calls `std/ai.step()` at line 633 of `agent_loop_v2.ail`. There is no way to drive the loop through its full control-flow paths without a real LLM call today. The existing smoke suites call internal helpers directly with synthetic inputs; there is no middle path between "algebraic unit test" and "burns real API tokens."

**Downstream impact**: `m-motoko-extensions-as-packages.md` and `m-motoko-chain-provenance.md` both require integration test infrastructure to validate their correctness properties. Without a scripted step fixture, those sprints will ship with the same layer-1-only coverage gap.

---

## Goals

1. Make `std/ai.step()` in `loop_v2` injectable: production path unchanged, test path uses scripted responses
2. Three reference integration tests: Pending round-trip, compaction live trigger, cost-budget live trigger
3. Makefile target (`make test_integration`) that runs all integration tests without LLM calls
4. No change to any existing caller signature beyond adding an optional-defaulting `provider` parameter

---

## Design

### Core ADT: `StepProvider`

New type in `src/core/test/stub_step.ail`:

```ailang
-- A scripted LLM turn: what the "model" returns for one step() call.
export type ScriptedStep = {
  prose: string,
  tool_calls: [ToolCall],
  input_tokens: int,
  output_tokens: int,
  finish_reason: string   -- "stop" | "tool_calls"; auto-derived if ""
}

-- Step provider: either the live AI or a scripted sequence.
-- Scripted([]) → emit a terminal "stop" result so the loop exits cleanly.
export type StepProvider = LiveAI | Scripted([ScriptedStep])
```

### Layer 1: `src/core/test/stub_step.ail` (~120 LOC) — new file

```ailang
module src/core/test/stub_step

import std/ai (StepResult, ToolCall, Message, AIError)
import std/result (Result, Ok, Err)
import src/core/tool_catalog (tools)

-- ... ScriptedStep + StepProvider types (see above) ...

-- Convert a ScriptedStep to the StepResult shape loop_v2 expects.
export pure func scripted_to_step_result(s: ScriptedStep) -> StepResult {
  let finish = if s.finish_reason != "" then s.finish_reason
               else if _list_length(s.tool_calls) > 0 then "tool_calls"
               else "stop";
  {
    message: { role: "assistant", content: s.prose, tool_calls: [], tool_call_id: "" },
    tool_calls: s.tool_calls,
    finish_reason: finish,
    input_tokens: s.input_tokens,
    output_tokens: s.output_tokens
  }
}

-- Terminal step: emitted when Scripted([]) is reached mid-loop.
export pure func terminal_step() -> StepResult {
  {
    message: { role: "assistant", content: "stub: script exhausted", tool_calls: [], tool_call_id: "" },
    tool_calls: [], finish_reason: "stop", input_tokens: 0, output_tokens: 0
  }
}

-- Dispatch one step call through the provider.
-- Returns both the step result and the updated provider (tail of script for Scripted).
-- Loop callers thread `next_provider` into their recursive call.
export func dispatch_step(
  provider: StepProvider,
  model: string,
  msgs: [Message]
) -> { result: Result[StepResult, AIError], next_provider: StepProvider } ! {AI} {
  match provider {
    LiveAI => {
      { result: step(model, msgs, tools()), next_provider: LiveAI }
    },
    Scripted(script) => {
      match script {
        [] => {
          { result: Ok(terminal_step()), next_provider: Scripted([]) }
        },
        s :: rest => {
          { result: Ok(scripted_to_step_result(s)), next_provider: Scripted(rest) }
        }
      }
    }
  }
}

-- Constructor helpers for test scripts
export pure func prose_step(text: string) -> ScriptedStep {
  { prose: text, tool_calls: [], input_tokens: 100, output_tokens: 50, finish_reason: "stop" }
}

export pure func tool_step(tool: string, args_json: string, step_id: string) -> ScriptedStep {
  {
    prose: "",
    tool_calls: [{ id: step_id, name: tool, arguments: args_json }],
    input_tokens: 200, output_tokens: 100,
    finish_reason: "tool_calls"
  }
}

export pure func token_step(prose: string, input_tok: int, output_tok: int) -> ScriptedStep {
  { prose: prose, tool_calls: [], input_tokens: input_tok, output_tokens: output_tok, finish_reason: "stop" }
}
```

### Layer 2: `src/core/agent_loop_v2.ail` (+30 LOC refactor)

**Import addition:**
```ailang
import src/core/test/stub_step (StepProvider, dispatch_step, LiveAI, Scripted)
```

**`loop_v2` signature** — add `provider: StepProvider` parameter:
```ailang
func loop_v2(
  rt: ExtRuntime,
  ...,          -- existing params unchanged
  max_cost_millicents: int,
  cost_rates: CostRates,
  total_cost_millicents: int,
  cost_warned_pct: int,
  provider: StepProvider     -- NEW: LiveAI for production, Scripted for tests
) -> Result[[Message], AIError] ! {AI, FS, Process, IO, Env, Net, SharedMem, Clock, Stream}
```

**Replace the `step()` call site** (line 633):
```ailang
-- Before:
match step(model, compacted_msgs, tools()) {
  Err(e) => ...
  Ok(result) => ...
}

-- After:
let dispatched = dispatch_step(provider, model, compacted_msgs);
let next_provider = dispatched.next_provider;
match dispatched.result {
  Err(e) => ...
  Ok(result) => ...
}
```

All four recursive `loop_v2` calls pass `next_provider` instead of `provider`.

**Public entry points** — `run_v2`, `run_v2_from_messages`, `run_v2_with_conversation`, `conversation_loop_v2` each get `provider: StepProvider` appended. All existing callers in `rpc.ail` pass `LiveAI`.

**New test entry point:**
```ailang
-- Run loop_v2 with a scripted provider. No real LLM call made.
-- Intended for integration tests only; not exported from rpc.ail.
export func run_v2_with_stub(
  rt: ExtRuntime,
  task: string,
  env_url: string,
  hybrid_tools: bool,
  budget: BudgetPlan,
  model: string,
  history: [Message],
  workdir: string,
  step_budget: int,
  ohmy_pi: bool,
  max_cost_millicents: int,
  cost_rates: CostRates,
  script: [ScriptedStep]
) -> Result[[Message], AIError] ! {FS, Process, IO, Env, Net, SharedMem, Clock, Stream} {
  let budget_steps = if step_budget <= 0 then 8 else step_budget;
  loop_v2(rt, task, env_url, hybrid_tools, budget, model, history,
          workdir, 0, budget_steps, ohmy_pi,
          max_cost_millicents, cost_rates, 0, 0, Scripted(script))
}
```

### Layer 3: `src/core/test/integration_tests.ail` (~80 LOC) — 3 reference tests

#### Test 1: Pending round-trip

```ailang
-- Script: model calls BashExec → extension issues Pending → stdin "approve" →
-- second script step returns "done".
-- Assertion: final history contains no denied-by-policy message for the approved call.
func test_pending_approve_round_trip() -> bool
  tests [((), true)]
  {
    let script = [
      tool_step("BashExec", encode(jo([kv("cmd", js("echo hello"))])), "t1"),
      prose_step("done")
    ];
    -- ... drive with stub stdin "approve" + run_v2_with_stub ...
    -- Inspect final history for tool-role message with exit_code 0 (not a denial)
    true  -- placeholder until Pending stdin-stub is wired
  }
```

#### Test 2: Compaction live trigger

```ailang
-- 12 tool calls each returning ~500 chars → after 10 turns, usage crosses 70%.
-- Assertion: tool-role messages beyond keep_last=10 have elided content
--            (contains "...[elided" substring).
func test_compaction_fires_above_70pct() -> bool
  tests [((), true)]
  {
    let big_result = join("x", repeat("x", 500));
    -- Build script: 12 identical tool-call + result turns
    -- Run with Scripted(script) on claude-sonnet-4-6 (200k window)
    -- Inspect returned history for elided tool-role content
    true  -- concrete assertion once dispatch_step wired
  }
```

#### Test 3: Cost-budget live trigger

```ailang
-- 10 steps of 50k input + 10k output at 60/208 millicents/1M token rates
-- = (3000 + 2080) / 1000000 = 0 mc per step (sub-millicent — fine for demonstration)
-- Use larger token counts: 100k input + 50k output per step
-- rate: 60k/1M + 208k/1M = (100000*60000 + 50000*208000) / 1000000 = 16400 mc/step
-- cap: 50000 mc → exhausted after 3 steps (3 * 16400 = 49200 < 50000 → 4th step = 65600 > 50000)
func test_cost_budget_exhausted() -> bool
  tests [((), true)]
  {
    let step = token_step("thinking...", 100000, 50000);
    let script = [step, step, step, step, step];  -- 5 steps; cap should trip at step 4
    let rates = { input_per_1m_millicents: 60000, output_per_1m_millicents: 208000 };
    let result = run_v2_with_stub(
      empty_rt(), "test task", "", false,
      { total: 10, solver: 10, verifier: 0 },
      "anthropic/claude-sonnet-4-6",
      [{ role: "user", content: "test", tool_calls: [], tool_call_id: "" }],
      "/tmp", 10, false,
      50000,  -- cap: 50000 millicents (~$0.50)
      rates,
      script
    );
    match result {
      Err(e) => e.code == "BudgetExceeded",
      Ok(_) => false
    }
  }
```

---

## Conflict Surface

This change touches `agent_loop_v2.ail`, the public agent loop API. Changes are **additive and backward-compatible**:

| Position | Current shape | After this change | Conflict? |
|---|---|---|---|
| `loop_v2` signature | 15 params ending in `cost_warned_pct: int` | +1 `provider: StepProvider` at end | None — internal function |
| `run_v2` signature | 12 params ending in `cost_rates: CostRates` | +1 `provider: StepProvider` at end | rpc.ail is only caller; passes `LiveAI` |
| `run_v2_from_messages` | same | same | same |
| `run_v2_with_conversation` | same | same | same |
| `conversation_loop_v2` | same | same | same |
| `step()` call site (line 633) | direct call to `std/ai.step` | replaced by `dispatch_step(provider, ...)` | None — semantically identical for LiveAI |

**Existing programs that MUST still work post-change:**
1. `rpc.ail::run_with_config` → all entry points pass `LiveAI` → identical runtime behaviour
2. `src/core/compaction.ail` — not touched; `compact_step` unchanged
3. `src/core/ext/compose/` — extension hooks fire in `dispatch_calls`, not at the `step()` callsite
4. All 23 `make check_core` modules — type-check must pass
5. `make test_core` — agents_md (11/11), compose (2/2), claimcheck (2/2) must pass

**Intentional change:** `loop_v2` no longer unconditionally has `{AI}` effect in the `Scripted` path. The effect row on the function signature stays `! {AI, ...}` (because `LiveAI` justifies it), but in a scripted run the AI effect is declared-but-not-invoked. This is legal in AILANG's effect system.

**No syntactic conflicts**: this is a pure .ail API addition with no parser, type-checker, or codegen changes. The conflict surface analysis gate (from CLAUDE.md) does not apply to this change.

---

## Files

| File | Change | ~LOC |
|------|--------|------|
| `src/core/test/stub_step.ail` | New: ScriptedStep + StepProvider types, dispatch_step, constructor helpers | +120 |
| `src/core/agent_loop_v2.ail` | Add `provider` param to loop_v2 + 5 public entry points; replace step() call site; add run_v2_with_stub | +35 / -5 |
| `src/core/test/integration_tests.ail` | New: 3 reference integration tests | +80 |
| `Makefile` | Add `test_integration` target | +5 |
| `src/core/rpc.ail` | Pass `LiveAI` to run_v2_with_conversation | +1 |

**Total**: ~235 LOC net new, ~5 LOC deleted.

---

## Acceptance Criteria

- [ ] `ailang check src/core/agent_loop_v2.ail` — no errors
- [ ] `make check_core` — 23/23 pass
- [ ] `make test_core` — agents_md 11/11, compose 2/2, claimcheck 2/2 (no regression)
- [ ] `make test_integration` — 3 integration tests pass without any LLM API call
- [ ] `test_cost_budget_exhausted` returns `Err({code: "BudgetExceeded"})` with correct millicent arithmetic
- [ ] Existing rpc.ail builds cleanly with `LiveAI` defaults
- [ ] `make verify_core` — Z3 unchanged (step_cost_millicents pure contract still verified)
- [ ] `run_v2` and `run_v2_from_messages` still work with `LiveAI` in manual smoke test

---

## Open Questions

1. **Pending round-trip stdin stub**: The pending-approval path reads from `readLine()` inside `dispatch_calls`. A full Pending integration test needs either a fake stdin injector or a redesign of the stdin read to be injectable. Suggest deferring this to a follow-up (test the easy path: a call the extension `Deny`s directly, which doesn't touch stdin). The cost and compaction tests have no stdin dependency.

2. **`empty_rt()` helper**: integration tests need a no-op `ExtRuntime`. Check if one already exists in `src/core/ext/` or create a minimal stub that returns `NoDecision` / `NoIntercept` / `Delegate` for all dispatch hooks.

3. **Makefile `test_integration` target**: runs `ailang test src/core/test/integration_tests.ail`. Should this be part of `make test` or kept separate to avoid accidental LLM calls in CI? Recommend: separate target, CI runs it only with `RUN_INTEGRATION_TESTS=1`.

---

## Cross-references

- `m-motoko-conversation-compaction.md` — compaction DP0 feature this tests
- `m-motoko-cost-budget.md` — cost budget feature this tests  
- `m-motoko-tool-policy-pending.md` — Pending policy feature this tests
- `m-motoko-extensions-as-packages.md` — downstream sprint that needs this infrastructure
- `m-motoko-chain-provenance.md` — downstream sprint that needs this infrastructure
- Source: motoko-explore inbox msg `7dff5bd4` (2026-05-06)
