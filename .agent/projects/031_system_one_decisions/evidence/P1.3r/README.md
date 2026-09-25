# P1.3r evidence — the per-atom decision cursor with the stub adapter arm

AILANG v0.33.0. Every AILANG check below ran in a throwaway workspace (P1.1's
method), never in a clone, so the `ailang.lock` trap does not apply.

| file | what it is |
|---|---|
| `p13r_check.sh` | P1.1's workspace (`evidence/P1.1/p11_core_check.sh`, reused line for line) plus P0.6's example consumers, exported by the **workspace** copy of the kit's toml only, and the e2e runner. Modes `check`, `test`, `e2e` |
| `cursor_e2e.ail` | the end-to-end runner: P0.6's `completion_guard` and `repeat_failure_policy`, registered through their own `register_with_config`, dispatched through the real `ext/runtime.ail` |
| `p13r_mutgate_spec.tsv`, `p13r_mutgate.sh`, `mutgate-result.tsv` | mutgate (013) spec, runner (P1.1's, re-pointed) and verdicts: **17/17 discriminate** |
| `open_row_probe/` | the measured fact that fixed the design (below) |
| `CORE-CHECK.log` | every tracked `src/core` module checked on 8.0: **71/72** |
| `RUNTIME-TEST.log` | `ailang test src/core/ext/runtime.ail`: 31/31 |
| `E2E.log` | `p13r_check.sh e2e`, exit 0 |
| `DRIVER_PLUS_NO_OPS.log`, `DPNO-STANDIN-*.log` | `make driver_plus_no_ops` exit 2 (see below) and its stand-in |
| `PROFILE_COVERAGE.log` | `make profile_coverage` exit 0 |

## End to end, per variant (`E2E.log`)

- **finalize**, `completion_guard`: `prepare` → `JudgeQuery(completion-judge)`; its
  `interpret` on the stub's `Unavailable(UnconfiguredBackend)` → `NoDecision`; dispatched
  alone the merged vote is `NoDecision`; with a legacy `SolverJudge` (Accept) behind it the
  next atom runs and the merge gives `Accept`; the successor world is the input world.
  Control: the same `interpret` on `Answered(1500 bp)` → `ContinueWithFeedback`.
- **tool policy**, `repeat_failure_policy`: `prepare` → `ToolQuery(repeat-failure-judge)`;
  `interpret` on the stub → `NoOpinion`; dispatched alone → `NoOpinion`; with a legacy
  `ToolPolicy` (Pending) behind it → `Pending(next atom ran)`. Control: `Answered(9000 bp)` → `Deny`.
- The context's `clock_now` port faults if called (the only port the two dispatchers' rows
  can reach). No run faulted.
- `decision_state` is `Some` with the consumer's own projections, since P0.6's consumers
  abstain without it. Which state the **host** hands a decision atom is P1.4r's. Note for
  P1.4r: the two config projections are per atom, and only the cursor in `ext/runtime.ail`
  sees each atom's descriptor.

## The open-row fact (`open_row_probe/`)

On the pin, a function-typed parameter's effect row is **open**. `arm: (int) -> int` accepts
an annotated `! {IO}` lambda, and the effect is charged to the caller, which then prints.
So a pure answerer parameter `(DecisionCursor) -> DecisionObservation` would promise
something the compiler does not check. The cursor therefore calls `stub_decision_answer`
(a `pure func` that sees only the cursor) **by name**. The dispatcher arms hold only
`PureCtx`, so no port is in scope. A related fact: a helper that calls a pattern-bound
callback gets charged its caller's row. That is why `decide_one_policy` carries
`! {IO, Clock}`, and why the declared-atom steps are written inline in the folds rather
than as helpers.

## Plan exits not reachable on the red tree

- `make check_core`, `make test`: these need all 18 packages on 8.0 (R-G's).
  Stand-in: `CORE-CHECK.log`, 71/72. The one failure is `src/core/test/integration_tests.ail`:
  `pkg/sunholo/motoko_ext_compaction_structural` is not in the workspace (a batch-A masked
  file, still 7.4 at HEAD). This is P1.1's failure, unchanged.
- `make driver_plus_no_ops` exit 2. `check_no_op_profile.py` calls
  `tools/ext_ambient_inventory/derive.py --json`, which exits 1 with provision failures on
  the 7.4 extension roots (a2a, agentcli, ailang_docs, compaction_ai, …). The target was
  equally red before this part (same traceback at HEAD `3eb6b71a`). Stand-in: the AILANG
  side, `ailang run scripts/dst/driver_plus_no_ops_dst.ail` exit 0, and
  `ailang test src/core/dst_driver_plus_no_ops.ail` 7/7.
- **The neutral decision atom "in the no-op profile".** `dst_driver_plus_no_ops.ail`'s
  per-extension atom lists are claims about four real packages' registrations.
  `check_no_op_profile.py` cross-checks them against those packages' source, and none of
  the four registers a decision atom (packages/ are P1.2a's). Adding one there would make
  the profile state something false. P0.5's no-op profile, `harness.neutral_registration()`
  (DescribeTools plus one neutral atom of each decision variant), is dispatched through the
  cursor instead (`neutral_registration_is_neutral_through_the_cursor_test`). Both
  dispatchers stay neutral and the world is untouched.
