---
repo: arniwesth/motoko_agent
pr: 229
branch: feat/011-two-invariant-rules
ticket: null
title: "feat(011): two rules in the invariant set — outcome agreement by reason, no repeated driver step"
---

## Summary

Adds two rules to the DST invariant set: ADR-003's D2 and the family half of D3, which is WI-2 of
`PLAN-judge-recoveries-on-real-runs.md`. Two single-edit defects in recovery branches added no
failure to `make dst` because no rule read what they change: a provider failure finalized as a
success, and a retried stream error that consumes no step budget. These rules read the summary's
finish reason and the driver's own step numbers. This is one of the plan's two build clusters; the
corpus gate that evaluates the set on sixteen real runs is the other, in other files.

## Changes

- feat(011): two rules in the invariant set — outcome agreement by reason, no repeated driver step

3 files changed.

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`: D2, D3,
  D6's first precondition, rulings 7, 8 and 14
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`: §2 F3 and F4,
  §4 WI-2
- `.agent/projects/011_improve_test_axises/HANDOFF-build-the-two-invariant-rules.md`
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9/README.md`
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## The two rules

| | D2 | D3, the set's half |
|---|---|---|
| constructor | `OutcomeFinishDisagrees(outcome, expected, seen)` | `DriverStepRepeated(step, times)` |
| rule id | `outcome-finish-disagrees` | `driver-step-repeated` |
| family | `OutcomeAgreement` | `BoundedProgress` |
| reads | the returned outcome and the terminal summary's `finish_reason` | the `step` on each `ProviderCallPrepared` in the returned trace |
| red when | an `Ok` did not finish `stop`, or an `Err` did not finish with the reason its code implies | one step number is on more than one prepared record |
| left as it was | `OutcomeSummaryDisagree` reads the error text; no summary is `SummaryAbsentForOutcome` | `ProviderStepRepeated` reads the interaction log; a gap in the steps is legal |

- **D2's table is stated in the module**, in `finish_reason_implied_by`, and does not import the
  driver's `decision_fail_reason`: `StepBudgetExhausted` implies `max_steps`, `BudgetExceeded`
  implies `cost_exhausted`, `ContextExhausted` implies `compaction_exhausted`, every other code
  implies `error`. It is keyed on strings, so a new code makes a healthy run red until the table
  is edited on purpose.
- **The table carries the module's first contract**, `ensures { result != "stop" }`: no failure
  code implies the success reason. The register classifies it substantive.
- **Each rule has its own constructor and a message that is true of its own condition.** The
  prototype reported a repeated driver step through `ProviderStepRepeated`, whose message says the
  cursor did not advance in a log that was in order.
- **`invariant_set_version()` is `invariant-set/2`.** Two rule ids added, none renamed or removed.
- **Not in the plan's list:** one inline test of D3 over the trace alone. No workflow runs
  `make invariants`, so without it CI would run nothing of D3.

## The rows in `make invariants`

The fixture could build only an `Ok` run finishing `stop`. Its summary, result and trace helpers
each get a second form that takes the reason or the outcome, and the first forms are defined
through them. `failed_run(code, finish)` builds an `Err` run without the fixture's `DoneEvent`:
the fixture with only its outcome flipped is red on `done-event-disagrees`.

Sixteen rows are new, 75 in all.

| row | must |
|---|---|
| `Err` with each of the four code and reason pairs | produce no finding |
| the failed-run fixture returns `Err` and carries no `DoneEvent` | hold, or the four rows above are vacuous |
| two prepared records under steps 0 and 1, and that trace holds two | produce no finding |
| `Ok` finishing `error` | `outcome-finish-disagrees` |
| a provider failure finishing `stop`, and finishing `max_steps` | `outcome-finish-disagrees` |
| `StepBudgetExhausted`, `BudgetExceeded` and `ContextExhausted`, each finishing `error` | `outcome-finish-disagrees` |
| two prepared records under step 0 | `driver-step-repeated`, and not `provider-step-repeated` |
| the existing frozen-cursor row | still `provider-step-repeated`, and not `driver-step-repeated` |

The `BudgetExceeded` and `ContextExhausted` rows are the only place those two table rows are
checked: no corpus member ends on cost or on compaction (the plan's F3).

## Predicted outcome

- **No healthy run goes red.** Checked here on every place that evaluates one today: the
  surviving fixture, the two real runs of `make stream_parity`, and the journal runs of
  `make eval_matrix`. The sixteen corpus members are checked when the gate cluster lands:
  whichever of the two pull requests merges second runs `make corpus_judge` with these rules in
  the set.
- **No pin moves.** `stream_parity`'s rule sets stay `["clock-balance"]` and `[]`, and
  `scripts/dst/stream_parity_dst.ail` is not in the diff. `corpus_pr`'s output, duration masked,
  hashes to the baseline's.
- **`make dst` and `make eval_matrix` fail exactly as they do without this change.** Both are red
  on `main` for reasons that are not this plan's, so each is read as a difference against
  `evidence/judge-recoveries/baseline-59d5cbb9/`.
- **CI sees three things:** `check_core`, the `verify` job (the contract, the register, the
  policy) and `test_coverage` (the inline tests). `make invariants` and `make stream_parity` are
  in no workflow.
- **Acceptance is not claimed.** D6's named driver mutants and the reviewer's own are WI-4, run
  once by a session that built none of this, after both clusters merge.
- **The matrix result here is D6's first precondition (ruling 14).** This commit is where both
  rules start running on journal runs, and the reference is the last tree without them.

## Test evidence

Run on 2026-10-06 and -07, AILANG v0.47.2 (`e939cba`), on this branch. No check had to be
repeated after a fix. The policy and the matrix ran on the commit, `c0f7eb02`; the others ran
on the same tree, before it was committed.

- [x] **`make invariants`.** PASS: 75 rows, sixteen of them new;
  `13 InvariantFamily variants == 13 in all_families(); all 42 Violation constructors sampled by name`.
  The commit message says "78 rows": that is the count of tick lines in the target's output, which
  also holds the two guard lines, the inline-test line and the toolchain's own.
- [x] **`make stream_parity`.** PASS, with
  `[scripted] the whole invariant set over the real run: 1 finding(s) — clock-balance` and
  `[recording] the whole invariant set over the real run: 0 finding(s)`.
- [x] **`ailang test src/core/dst_invariants.ail`.** 16 of 16: the nine, five table rows, the
  property the toolchain generates from the contract (100 cases), and the D3 row.
- [x] **`make verify_classify`.** One new entry, `finish_reason_implied_by`, substantive; totals
  13 to 14 substantive. Fifteen other rows change in their solve time only.
- [x] **`make verify_core verify_classify_check`.** `✓ src/core/dst_invariants.ail (1 proven)`;
  `16 contracts proven, 0 unstated, 1 blocked; 0 files failed, 49 bare`; 18 unit tests pass;
  `register agrees (14 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)`.
- [x] **`make dst`.** Exit 2, and its `FAILED` block is the baseline's four names and no other:
  `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope`, `ext_hook_scope_selftest`, each
  on the `test_dummy` registration shape. **The machine was suspended during this sweep**, from
  about 20:37 to 06:23 UTC, so its 38,150 s wall time means nothing. No target was re-run: none
  beyond the baseline's four was red.
- [x] **`make new_contract_policy`, after the commit.**
  `3 in-scope new pure func declarations, all justified; 2 more out of scope, reachable only from a tests block`:
  `finish_reason_implied_by` carries a contract; `prepared_steps` and `repeated_driver_steps` have
  their excuse checked; the D3 test and its record builder are out of scope.
- [x] **`make eval_matrix`, after the commit, against the baseline at `59d5cbb9`.** 1,038 s.
  `621 rows: credited=419, equal=129, failed=29, inapplicable=11, missing=33`; the same three
  suites non-zero; `witness_live_test`, `candidate_checks_live_test` and `admission_live_test`
  exit 0. `compare_matrix.py` prints:

  ```
  suites: 28 and 28; rows: 621 and 621
  present on one side only: 0
  suites whose exit code differs: 0
  rows whose observation differs: 0
  rows whose join status differs: 0
  VERDICT: IDENTICAL
  ```

- [x] **Each new row and each new inline test has been seen red.** Eleven single edits to the
  two rules and a comment-only control, then two edits to the script's fixtures, the red rows
  predicted before each run, the file restored and hash-checked after each. All fourteen went as
  predicted, the control with no row red. A D3 that fires on any two prepared records fails the
  survival row; a D3 that reuses `ProviderStepRepeated` or reads the log fails its own row and
  one of the two absences; each table row changed fails its survival row, its rejection row and
  its inline row; a table whose default is `stop` is a contract `VIOLATION`; a failed-run fixture
  that keeps the `DoneEvent` is red on `done-event-disagrees` in all four survival rows. This is
  the author's check and not WI-4; the table is in the build report and is not committed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
