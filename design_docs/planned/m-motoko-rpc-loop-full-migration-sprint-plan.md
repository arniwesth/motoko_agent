# M-MOTOKO-RPC-LOOP-FULL-MIGRATION Sprint Plan

**Sprint ID**: `M-MOTOKO-RPC-LOOP-FULL-MIGRATION`
**Design doc**: [m-motoko-rpc-loop-full-migration.md](./m-motoko-rpc-loop-full-migration.md)
**Target**: motoko_agent vX.Y.Z (downstream consumer release; NOT an AILANG version)
**Created**: 2026-05-05
**Estimated**: 12-15 days realistic (range: 9-25)
**Risk level**: Medium-high (two wildcards: ohmy_pi backend + compose extension contract)

---

## Sprint Summary

Replace motoko_agent's `rpc_loop` (1494 LOC, text-based tool-call parsing) with a production-grade v2 loop using upstream AILANG `std/ai.step()` with TYPED tool_calls. This is the **third and final motoko-side migration** completing AILANG fork retirement:

1. ✅ PR #3 (streaming) — `callStreamResult` → `callStream`
2. ✅ PR #4 M1+M2 (foundation) — adapter + `[ToolSchema]` catalog
3. 🟡 **THIS SPRINT (M3-M10)** — replaces rpc_loop entirely, archives [arniwesth/ailang@motoko](https://github.com/arniwesth/ailang/tree/motoko)

**Headline outcome**: net ~1000 LOC removed from motoko_agent, AILANG fork archivable, GLM-5/MiniMax-class smaller models become reliable tool-callers (typed tool_use protocol eliminates the JSON-block hallucination class observed in PR #4 testing).

## Velocity Check

**This sprint's velocity is fundamentally different from AILANG-internal sprints.**

| Sprint type | Recent velocity | Why |
|-------------|----------------|-----|
| **AILANG-internal** (M-AI-TOOL-LOOP, M-AI-CALL-STREAM-HELPER, M-AI-PROVIDER-CONFIG) | ~1500 LOC/day on focused sprints (6,400 LOC in 6 hours via parallel sub-agents) | Full team control of stack, no external decisions needed mid-sprint, parallelizable work |
| **Motoko-side cross-repo** (PR #3, PR #4 M1+M2) | ~300 LOC/day net | Single-threaded execution, must verify against motoko's existing behavior, can't parallelize easily |
| **THIS sprint (M3-M10)** | ~70-100 LOC/day net (target) | All of motoko-side concerns + 2 arni-decision gates mid-sprint + 5-provider test matrix at M9 |

**Why so much slower per-day**: net LOC deletion (~1000) is what matters here, not gross LOC churn. Each milestone deletes legacy code AND adds new code AND keeps both running side-by-side via the env-var switch until M10 cuts over. Real engineering time goes into compatibility verification, not raw typing speed.

**Validity check**: 12-15 days × 70-100 LOC/day = 840-1500 net LOC moved/deleted, matching the design doc's ~1000 net LOC estimate. Velocity model holds.

## Milestones (8 — M3 through M10)

Each milestone is a separable PR-sized change. The env-gated `MOTOKO_AGENT_V2` switch lets each milestone ship to motoko's main branch without breaking existing users; default-on flips at M10.

### M3: Extension intercept dispatch (DP1)

**Files**:
- `src/core/agent_loop_v2.ail` (+150 LOC) — wrap step() result in `dispatch_response_intercept` call before tool dispatch
- Verify `src/core/ext/runtime.ail` `dispatch_response_intercept` signature is compatible (likely yes — arg is response text)

**Estimated**: ~150 LOC, 1 day, **risk: Low**

**Dependencies**: PR #3 + PR #4 M1+M2 + v2 stress test (all already shipped)

**Acceptance criteria**:
- v2 calls `dispatch_response_intercept(ext, result.message.content)` on each step's return
- `Accept(output)` short-circuits the loop with `done` event carrying `output`
- `ContinueWithFeedback(fb)` injects a `{role: "user", content: fb}` message and recurses
- `NoIntercept` / `NoDecision` falls through to tool dispatch unchanged
- Smoke test in `scripts/smoke_v2_intercept.ail`: synthetic stub always returns `Accept("intercepted")`; v2 emits `done` with `"intercepted"` instead of running tool calls
- `make check_core` still passes (currently 22/22)

### M4: Tool gating policy (DP3)

**Files**:
- `src/core/agent_loop_v2.ail` (+100 LOC) — call `apply_tool_policy_typed` between intercept and dispatch
- `src/core/tool_dispatch_adapter.ail` (+20 LOC) — batch translator for `[ToolCall] → [ToolCallEnvelope]` (single-call translator already exists)
- New helper: `apply_tool_policy_typed` wraps existing string-based policy if needed, OR existing `apply_tool_policy` is adapted to take typed input directly

**Estimated**: ~120 LOC, 0.5 day, **risk: Low**

**Dependencies**: M3 (intercept must run before gating)

**Acceptance criteria**:
- v2 calls policy gate on every typed `[ToolCall]` returned by step()
- `gated.allowed` flows to native dispatch; `gated.denied` becomes tool-role messages with `{"error": true, "denied_by_policy": "<reason>"}` JSON content
- Denied calls do NOT reach `run_native_batch`
- Smoke test: synthetic stub denies any `BashExec`; v2 emits a `denied` tool-result message; model's next turn sees the denial message
- All M3 acceptance criteria still hold (regression-free)

### M5: Tool-handle routing + Compose extension contract change (DP4)

**Files**:
- `src/core/agent_loop_v2.ail` (+150 LOC) — call `route_tool_handles_typed` after gating
- `src/core/ext/compose/claimcheck.ail` — refactor to take typed `StepResult` (or a shim depending on arni's M5 decision option a/b/c)
- `src/core/ext/compose/author_loop.ail` — same refactor
- `src/core/ext/types.ail` (+50 LOC) — possibly extend `ResponseInterceptDecision` to carry typed StepResult info

**Estimated**: ~300 LOC, 2 days, **risk: MEDIUM (wildcard #1 — see preflight checklist)**

**Dependencies**: M4 + **arni greenlight on M5 option (a/b/c)**

**Acceptance criteria**:
- Extension-routed tools (e.g. `compose_check_premise`) bypass `run_native_batch` and return their own `ToolResultEnvelope`
- claimcheck still validates compose-author output between turns (per arni's chosen migration path)
- author_loop still injects multi-attempt feedback for ailang-snippet authoring
- One existing claimcheck-using benchmark task passes end-to-end
- All M3+M4 acceptance criteria still hold

**🚦 GATING DECISION**: sprint-executor MUST NOT proceed past M4 into M5 without arni's explicit choice between:
- (a) Typed migration — extensions inspect typed StepResult (clean break)
- (b) Compatibility shim — re-stringify StepResult so extensions stay on prose contract
- (c) Drop compose extensions from v2 path entirely

### M6: Native vs ohmy_pi backend split (DP5)

**Files**:
- `src/core/agent_loop_v2.ail` (+200 LOC) — call `split_by_backend_typed` and dispatch native + delegated paths
- `src/core/tool_dispatch_adapter.ail` (+30 LOC) — possibly add ohmy_pi parallel dispatcher
- `src/core/ohmy_pi/*.ail` — likely no change (call existing API)

**Estimated**: ~230 LOC, 1-3 days, **risk: HIGH (wildcard #2)**

**Dependencies**: M5 + **arni answers on ohmy_pi backend questions (sync vs async dispatch shape, result schema parity, current development status)**

**Acceptance criteria**:
- Native tool calls dispatch through `run_native_batch` exactly as today
- Delegated tool calls dispatch through ohmy_pi's existing client and return `ToolResultEnvelope`s
- Mixed batches (some native, some delegated) work correctly
- `settings.ohmy_pi = false` falls back to all-native dispatch with no errors
- Smoke test: configure ohmy_pi=true with a remote backend; run a task that triggers ≥1 delegated call; verify both paths feed back to the model
- All M3-M5 acceptance criteria still hold

**🚦 GATING DECISION**: arni must answer the four ohmy_pi questions in the design doc's §Risk Analysis before M6 begins. Fallback: defer ohmy_pi (option b — temporarily return ToolErrorResult for delegated calls) and re-enable in a follow-up sprint.

### M7: Hybrid mode (extract_bash shorthand) + parse.ail cleanup

**Files**:
- `src/core/agent_loop_v2.ail` (+100 LOC) — fall through to `extract_bash` when `tool_calls=[]` and prose contains shell-shorthand
- `src/core/parse.ail` (~-400 LOC) — DELETE `parse_tool_calls`, `indicates_continuation_intent`, `extract_any_tool_json_candidate`, `looks_like_non_json_tool_syntax`, `parse_legacy_terminal_call`, `parse_legacy_direct_call`. Keep `parse_cwd`, `extract_bash`, `assistant_history_content`, `assistant_visible_output`.
- `src/core/parse_test.ail` — drop tests for deleted functions

**Estimated**: ~100 LOC added + ~400 LOC deleted = ~300 LOC NET DELETION, 0.5 day, **risk: Low**

**Dependencies**: M6 (hybrid only kicks in when no typed tool_calls returned, after backend split has had a chance)

**Acceptance criteria**:
- v2 falls through to `extract_bash` when `step()` returns `tool_calls=[]` AND `finish_reason="stop"` AND prose contains a `$ <cmd>` line-prefix
- Extracted bash command becomes a synthetic `BashExec` tool call dispatched through the native path
- Smoke test: `MOTOKO_AGENT_V2=1 motoko "$ pwd"`; v2 extracts and runs as BashExec
- `make check_core` still passes
- ~400 LOC deleted from parse.ail with no regression

### M8: Multi-turn conversation_loop

**Files**:
- `src/core/agent_loop_v2.ail` (+80 LOC) — outer loop that awaits next user input after `done`, appends to message history, recurses
- `src/core/rpc.ail` — drop the env-var branch from M3-stress-test wiring (keep rpc_loop callable for legacy default until M10)

**Estimated**: ~80 LOC, 0.5 day, **risk: Low**

**Dependencies**: M3-M7

**Acceptance criteria**:
- After v2 emits `done`, it awaits next user input via stdin/env-server
- New user message gets appended to running message history
- Loop resumes via fresh `step()` call with appended history
- Smoke test: TUI session — submit "what folder are you in?", then after answer, submit "what files are there?"; verify both turns succeed without restart
- TUI state machine handles the v2 done→next-task transition correctly

### M9: Test matrix — 5 providers × 5 benchmark tasks

**Files**:
- `scripts/v2_test_matrix.sh` (NEW) — driver running benchmarks against each model
- `benchmarks/v2_smoke/*.ail` (NEW, ~5 files) — single-tool, multi-tool, gated-tool, intercepted, error-recovery scenarios
- `docs/v2-model-compatibility.md` (NEW) — observed behavior per model, any per-provider quirks captured

**Estimated**: ~150 LOC + ~200 LOC benchmark fixtures, 2-3 days, **risk: MEDIUM**

**Dependencies**: M3-M8 complete

**Acceptance criteria**:
- Claude Sonnet 4.5: 5/5 benchmark tasks pass
- Gemini 3 Pro: 5/5 pass (likely surfaces functionCall ID quirks — fix upstream if needed)
- GPT-5: 5/5 pass
- GLM-5: ≥4/5 pass (acceptable — smaller OS model)
- MiniMax M2.7: ≥4/5 pass
- Any per-provider bug found gets a regression test added to upstream `internal/ai/<provider>/step_test.go`
- Documented compatibility matrix in `docs/v2-model-compatibility.md`

### M10: Production cutover — delete rpc_loop, drop opt-in env var

**Files**:
- `src/core/rpc.ail` — DELETE `rpc_loop`, `conversation_loop`, env-var branch (~600 LOC deletion); rename file to `agent_loop.ail` since the surface is now just `run_with_config`
- `src/core/parse.ail` — verify no remaining dead code from M7
- `src/core/agent_loop_v2.ail` → rename to `src/core/agent_loop.ail`; drop `_v2` suffix from `run_v2`
- `SYSTEM.md` — replace JSON-block instructions with "tools provided via API" message
- `src/tui/src/runtime-process.ts` — drop `MOTOKO_AGENT_V2` env var forwarding
- `CHANGELOG.md` (motoko-side) — entry referencing all 6 decision points retained, AILANG fork archivable

**Estimated**: ~50 LOC adjustments + ~600 LOC deletion + SYSTEM.md rewrite, 1 day, **risk: Low (the work is verified at this point)**

**Dependencies**: M9 (test matrix shows v2 production-ready)

**Acceptance criteria**:
- `make check_core` passes (now ~19 modules — 3 dropped: parts of rpc.ail, parse.ail dead code, agent_loop_v2 renamed)
- All benchmark tasks pass without `MOTOKO_AGENT_V2` env var
- AILANG fork (arniwesth/ailang@motoko) declared archivable
- Net LOC deleted from motoko_agent: ≥800 LOC
- SYSTEM.md tool-call instructions replaced with provider-native protocol description
- motoko_agent CHANGELOG entry references all 6 retained decision points

## Pre-Flight Checklist (BLOCKED on arni decisions)

**sprint-executor MUST verify each of these before starting work**. None of M3-M10 can run cleanly without these answers — running on assumptions risks scope creep + redo.

### Gate 1: Sprint cadence (before M3)

- [ ] **arni's choice**: single 3-week sprint (recommended) vs split across 2-3 releases
- **If split**: define which milestones go in which release; this changes the M5/M6/M9 risk profiles since users see partial features

### Gate 2: Compose extension contract change (before M5)

- [ ] **arni's choice on M5 option (a/b/c)**:
  - (a) Typed migration — extensions inspect typed StepResult; clean break, breaking change to extension contract
  - (b) Compatibility shim — re-stringify StepResult; extensions stay on prose contract; perpetuates legacy contract
  - (c) Drop compose extensions from v2 path; loses claimcheck/author_loop features
- [ ] **If (a)**: confirm extension-author maintainer availability for co-design (~2 days/extension)
- [ ] **Production-criticality**: are claimcheck + author_loop essential to motoko users? (informs urgency)

### Gate 3: ohmy_pi backend complexity (before M6)

- [ ] **Q1**: Does `ohmy_pi.delegate(envelopes)` return synchronously or async (poll-based)?
- [ ] **Q2**: Are delegated tool results equivalent to native ToolResultEnvelopes, or different schema?
- [ ] **Q3**: Is delegated execution still under active development, or stable?
- [ ] **Q4**: Are there ohmy_pi-specific tools (not in motoko's native catalog) that need ToolSchema entries?
- **Fallback if blocking**: option (b) defer ohmy_pi temporarily — return ToolErrorResult for delegated calls, fix in follow-up sprint

### Gate 4: SYSTEM.md update timing (before M10)

- [ ] **arni's confirmation**: replacing "emit JSON tool_calls block" instructions with "tools come via API" affects all model behavior across all providers; OK to ship in M10 cutover?
- [ ] **Test matrix dependency**: M9 must not regress on the new SYSTEM.md content; if regressions surface, iterate on phrasing before M10

### Gate 5: Default-on switch timing (after M10)

- [ ] **arni's choice**: when does `MOTOKO_AGENT_V2` stop being opt-in and become the only path?
  - Option (i): immediately at M10 (recommended once M9 passes)
  - Option (ii): after one stable motoko release with v2 default-off but available
  - Option (iii): user-by-user opt-in for N weeks before flipping default

## Day-by-day breakdown

Single 3-week sprint (recommended cadence). Per-week:

### Week 1 (M3 + M4 + start M5)

| Day | Tasks |
|------|-------|
| 1 | Pre-flight: confirm Gates 1+2 with arni; M3 implementation (intercept dispatch, ~150 LOC) |
| 2 | M3 smoke + tests; M4 implementation (tool gating, ~120 LOC) |
| 3 | M4 smoke + tests; verify M3+M4 don't regress v2 stress test |
| 4 | M5 start: refactor claimcheck per arni's chosen path (a/b/c) |
| 5 | M5 continued: author_loop refactor; tool_handle_routing implementation |

### Week 2 (finish M5 + M6 + M7)

| Day | Tasks |
|------|-------|
| 6 | M5 smoke against existing claimcheck-using benchmark; M6 prerequisites (Gate 3 confirmed) |
| 7 | M6: backend split + ohmy_pi parallel dispatcher (~230 LOC, may extend to day 8) |
| 8 | M6 smoke against ohmy_pi config; M7 start (extract_bash hybrid mode) |
| 9 | M7 finish: delete dead code from parse.ail (~400 LOC deletion); verify regressions |
| 10 | Buffer day for M5/M6 overruns OR start M8 if ahead |

### Week 3 (M8 + M9 + M10)

| Day | Tasks |
|------|-------|
| 11 | M8: conversation_loop (multi-turn); TUI integration test |
| 12 | M9 start: write test matrix driver + 5 benchmark tasks |
| 13 | M9 continued: run matrix against Claude/Gemini/GPT-5/GLM-5/MiniMax; capture per-provider bugs |
| 14 | M9 finish: file upstream regression tests for any provider bugs found; document compatibility matrix |
| 15 | M10: production cutover — delete rpc_loop, rename agent_loop_v2 → agent_loop, SYSTEM.md update, CHANGELOG, ship |

**Buffer / overrun risk**: 2-3 days unaccounted (M5/M6 wildcards) plus 1-2 days for M9 per-provider bug fixes. Pessimistic estimate (~25 days) accounts for both.

## Success metrics

- All M3-M10 acceptance criteria met
- M9 test matrix: ≥80% pass rate across 5 providers × 5 benchmark tasks
- LOC reduction: net ≥800 LOC removed from motoko_agent (target: ~1000)
- AILANG fork (arniwesth/ailang@motoko) archived after M10
- motoko_agent CHANGELOG entry references all 6 decision points retained
- Zero new heuristic string-matching code (no `indicates_*` regex patterns)

## Dependencies and open questions

**All blocking items are arni-side decisions** (see Pre-Flight Checklist):

1. Sprint cadence (Gate 1)
2. Compose extension contract approach (Gate 2)
3. ohmy_pi backend questions (Gate 3)
4. SYSTEM.md update timing (Gate 4)
5. Default-on switch timing (Gate 5)

**No AILANG-side dependencies remaining**:
- ✅ M-AI-TOOL-LOOP shipped (`step()` + `runTools()` available in v0.15.2)
- ✅ M-AI-CALL-STREAM-HELPER shipped (streaming layer used by PR #3)
- ✅ Two regression fixes (parser + stdout buffer) shipped in v0.15.2

**Open questions resolvable during execution** (non-blocking):
1. Should the v2 loop emit `compose_*` telemetry events at the same trigger points as rpc_loop, or simplify the telemetry surface? Land minimum viable; iterate.
2. After M10, the v2 loop still has `_io_poll_stdin` stubbed (motoko's runtime abort/model-change feature) — separate sprint to upstream a non-blocking-stdin builtin or migrate to a different control mechanism.

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| ohmy_pi backend split is high-touch | Medium | High | Gate 3 questions answered before M6; option (b) defer fallback if blocking |
| Compose extension migration drags | Medium | Medium | Gate 2 forces explicit choice; M5 option (c) drop is the escape hatch |
| Per-provider step() bug discovered late | Medium | Medium | M9 surfaces bugs; each becomes an upstream patch (small LOC) |
| SYSTEM.md change degrades smaller-model behavior | Low | Medium | M9 test matrix catches; iterate phrasing before M10 |
| Sprint overruns 3 weeks | Medium | Low | Acceptable — 12-15 day estimate has 1-2 day buffer; pessimistic = 25 days |
| AILANG upstream API breaks during sprint | Low | High | Pin AILANG to v0.15.2 stable; bump only post-sprint |

## Handoff to sprint-executor

**This sprint is BLOCKED on arni's pre-flight decisions.** sprint-executor must NOT begin M3 until Gates 1+2 are answered. Gate 3 must be answered before M6.

When unblocked, the handoff is:

```
SPRINT_PLAN_PATH: motoko_agent/design_docs/planned/m-motoko-rpc-loop-full-migration-sprint-plan.md
SPRINT_JSON_PATH: .ailang/state/sprints/sprint_M-MOTOKO-RPC-LOOP-FULL-MIGRATION.json
DESIGN_DOC: motoko_agent/design_docs/planned/m-motoko-rpc-loop-full-migration.md
EXECUTION_REPO: /Users/mark/dev/sunholo/motoko_agent
EXECUTION_BRANCH: ailang-tool-loop-migration (or new branch ailang-rpc-loop-v2)
```

**Note for sprint-executor**: this sprint executes against motoko_agent (downstream consumer), not AILANG. `make check_core` and motoko's smoke tests are the gates, not AILANG's `make ci`. Cross-repo: AILANG must stay pinned at v0.15.2 throughout the sprint (or whatever stable release is current).
