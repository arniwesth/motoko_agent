# M-MOTOKO-STUB-STEP Sprint Plan

**Sprint ID**: M-MOTOKO-STUB-STEP  
**Design Doc**: [m-motoko-stub-step.md](m-motoko-stub-step.md)  
**Branch**: motoko-dx-compaction-pending  
**Estimated duration**: 1–2 days (~235 LOC net new, ~5 LOC deleted)  
**Risk**: Low — pure .ail additions, no parser/typechecker/codegen changes

---

## Goal

Make `std/ai.step()` in `loop_v2` injectable via a `StepProvider` parameter. Ship three reference integration tests that validate Pending policy, compaction DP0, and cost-budget across live `loop_v2` control-flow paths — without burning real LLM API tokens.

---

## Current Status

| Feature | Layer-1 smoke | Integration gap |
|---|---|---|
| Pending policy | 10/10 pass | ❌ No round-trip test |
| Compaction DP0 | 10/10 pass | ❌ No live loop trigger test |
| Cost budget | 13/13 pass | ❌ No live accumulation test |

`loop_v2` calls `step(model, compacted_msgs, tools())` directly at line 633 of `agent_loop_v2.ail`. There is no way today to drive the loop without a real LLM call.

---

## Milestones

### M1 — `src/core/test/stub_step.ail` (~120 LOC) ❌

**New file** implementing the `StepProvider` ADT and scripted dispatch.

**Tasks:**
1. Create `src/core/test/` directory
2. Write `stub_step.ail` with:
   - `ScriptedStep` record type
   - `StepProvider = LiveAI | Scripted([ScriptedStep])` ADT
   - `scripted_to_step_result(s: ScriptedStep) -> StepResult` — pure conversion
   - `terminal_step() -> StepResult` — emitted when script is exhausted
   - `dispatch_step(provider, model, msgs) -> { result, next_provider }` — main dispatch
   - `prose_step(text)`, `tool_step(tool, args_json, step_id)`, `token_step(prose, input_tok, output_tok)` constructor helpers
3. Run `ailang check src/core/test/stub_step.ail`

**Acceptance criteria:**
- `ailang check src/core/test/stub_step.ail` — no errors
- All 3 constructor helpers type-check as pure functions
- `dispatch_step` with `LiveAI` provider has effect `! {AI}` (just calls `step()`)
- `dispatch_step` with `Scripted([])` returns `Ok(terminal_step())` with `next_provider: Scripted([])`
- `dispatch_step` with `Scripted(s::rest)` returns `Ok(scripted_to_step_result(s))` with `next_provider: Scripted(rest)`

**Estimated LOC**: +120

---

### M2 — `src/core/agent_loop_v2.ail` refactor (+35 / -5 LOC) ❌

**Add `provider: StepProvider` parameter to `loop_v2` and all public entry points.**

**Tasks:**
1. Import `stub_step` at top of `agent_loop_v2.ail`
2. Add `provider: StepProvider` as final param to `loop_v2` (after `cost_warned_pct: int`)
3. Replace `step()` call at line 633 with `dispatch_step(provider, ...)` + bind `next_provider`
4. Thread `next_provider` through all 4 recursive `loop_v2` calls
5. Add `provider: StepProvider` to 5 public entry points: `run_v2`, `run_v2_from_messages`, `conversation_loop_v2`, `run_v2_with_conversation`
6. `run_v2` and `run_v2_from_messages` pass `LiveAI` as default at their own call site to `loop_v2`
7. Add `run_v2_with_stub` new entry point (test-only, not exported from rpc.ail)
8. Update `rpc.ail`: pass `LiveAI` to `run_v2_with_conversation`
9. Run `ailang check src/core/agent_loop_v2.ail` + `make check_core`

**Acceptance criteria:**
- `ailang check src/core/agent_loop_v2.ail` — no errors
- `make check_core` — 23/23 pass (no regression)
- `rpc.ail` compiles cleanly (LiveAI default wired in)
- `run_v2_with_stub` signature matches design doc exactly

**Estimated LOC**: +35 / -5

---

### M3 — `src/core/test/integration_tests.ail` (~80 LOC) ❌

**Three reference integration tests. Pending stdin round-trip is deferred (Open Q #1); implement compaction trigger and cost-budget exhaustion instead.**

**Tests to implement:**
1. `test_compaction_fires_above_70pct` — 12 tool calls with ~500-char results; assert elided content in returned history
2. `test_cost_budget_exhausted` — 5 steps at 100k/50k tokens against 50k millicent cap; assert `Err({code: "BudgetExceeded"})`
3. `test_pending_deny_path` — model calls BashExec; extension policy returns `Deny` directly (no stdin); assert denial message in history

**Each test uses:**
- `run_v2_with_stub` as the entry point
- `empty_rt()` (or equivalent no-op ExtRuntime stub)
- Constructor helpers from `stub_step.ail`

**Acceptance criteria:**
- `ailang test src/core/test/integration_tests.ail` — all 3 tests pass
- No LLM API call is made during test execution
- `test_cost_budget_exhausted` returns `Err({code: "BudgetExceeded"})` with correct millicent arithmetic (cap 50000 mc, step cost ~16400 mc, trips on step 4)
- `test_compaction_fires_above_70pct` asserts elided content (substring `"...[elided"`) in tool-role messages beyond keep_last boundary

**Estimated LOC**: +80

**Open question**: Does `empty_rt()` already exist? Check `src/core/ext/` for a no-op ExtRuntime. If not, add a minimal one to `stub_step.ail` or a separate `src/core/test/test_helpers.ail`.

---

### M4 — Makefile + wiring (~6 LOC) ❌

**Add `test_integration` Makefile target and ensure `rpc.ail` is clean.**

**Tasks:**
1. Add to Makefile:
   ```makefile
   test_integration:
   	@ailang test src/core/test/integration_tests.ail || (echo "integration tests failed" && exit 1)
   ```
2. Verify `make test` still passes (test_core is not broken)
3. Verify `make check_core` still 23/23

**Acceptance criteria:**
- `make test_integration` runs all 3 integration tests without LLM calls
- `make test` (test_core) is unaffected
- `make verify_core` passes (Z3 step_cost_millicents contract still verified)

**Estimated LOC**: +6

---

## Task Breakdown

### Day 1 (~4 hours)

**Morning:**
- M1: Create `src/core/test/` dir + write `stub_step.ail`
- M1: `ailang check src/core/test/stub_step.ail`

**Afternoon:**
- M2: Import + param addition in `agent_loop_v2.ail`
- M2: Replace step() call site, thread next_provider through 4 recursive calls
- M2: Add provider param to 5 public entry points + `run_v2_with_stub`
- M2: Update `rpc.ail` to pass `LiveAI`
- M2: `ailang check` + `make check_core`

### Day 2 (~3 hours)

**Morning:**
- M3: Write `integration_tests.ail` with 3 tests
- M3: Verify empty_rt() availability; add stub if needed
- M3: `ailang test src/core/test/integration_tests.ail`

**Afternoon:**
- M4: Add `test_integration` Makefile target
- M4: `make test` + `make verify_core`
- Commit: `feat(test): M-MOTOKO-STUB-STEP — StepProvider injection + 3 integration tests`

---

## Success Metrics

- [ ] `ailang check src/core/agent_loop_v2.ail` — no errors
- [ ] `make check_core` — 23/23 pass
- [ ] `make test_core` — agents_md 11/11, compose 2/2, claimcheck 2/2 (no regression)
- [ ] `make test_integration` — 3 integration tests pass without any LLM API call
- [ ] `test_cost_budget_exhausted` returns `Err({code: "BudgetExceeded"})` with correct millicent math
- [ ] `test_compaction_fires_above_70pct` asserts elided content in returned history
- [ ] Existing `rpc.ail` builds cleanly with `LiveAI` defaults
- [ ] `make verify_core` — Z3 unchanged (step_cost_millicents pure contract still verified)

---

## Dependencies

- `motoko-dx-compaction-pending` branch (already current) — Pending policy, compaction DP0, cost budget all landed
- No external dependencies

## Risks

| Risk | Mitigation |
|---|---|
| `empty_rt()` doesn't exist — integration tests need a no-op ExtRuntime | Check `src/core/ext/`; if absent, add a 10-LOC stub to `src/core/test/stub_step.ail` |
| `test_compaction_fires_above_70pct` — unclear whether 12×500-char tool results actually triggers 70% window usage in stub mode | Use the scripted provider to inject tool_result messages directly into history; or adjust token counts so the 70% threshold triggers deterministically |
| Pending deny-path test requires dispatch_calls to receive a Deny decision synchronously | Use a no-op ExtRuntime that returns `Deny("test denial reason")` for BashExec calls |

---

## Files

| File | Change |
|------|--------|
| `src/core/test/stub_step.ail` | New (+120 LOC) |
| `src/core/agent_loop_v2.ail` | Refactor (+35 / -5 LOC) |
| `src/core/test/integration_tests.ail` | New (+80 LOC) |
| `src/core/rpc.ail` | Pass `LiveAI` (+1 LOC) |
| `Makefile` | Add `test_integration` target (+5 LOC) |

**Total**: ~235 LOC net new, ~5 LOC deleted.
