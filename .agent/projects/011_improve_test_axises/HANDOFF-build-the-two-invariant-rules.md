# Handoff: build the two invariant rules (cluster 2 of ADR-003's plan)

Date: 2026-10-06, revised the same day after `REVIEW-001-plan-judge-recoveries-claude-opus-5.5.md`
From: the session that wrote `PLAN-judge-recoveries-on-real-runs.md`
For: a fresh session, in its own worktree and branch
Deliverable: one commit: D2 and D3's family half in `src/core/dst_invariants.ail`, their rows in
`scripts/dst/invariants_dst.ail`, and the regenerated contract register. This is the plan's WI-2.

**Build this one item. Do not build the gate,** WI-1 and WI-3: another session has it, in other
files, and the two can land in either order. **Do not run WI-4,** acceptance.

The plan is the specification. This handoff adds the grounding as of today, the rules you would
break by accident, a runnable definition of done, and where to stop. Where the two disagree the
plan wins, and where the plan and ADR-003 disagree the ADR wins.

## First: is this still the tree it was grounded on?

Grounded at `59d5cbb9`, AILANG v0.47.2.

    git diff --stat 59d5cbb9 HEAD -- src/core/dst_invariants.ail scripts/dst/invariants_dst.ail \
      scripts/dst/stream_parity_dst.ail src/core/session.ail src/core/phase_vocab.ail \
      src/core/step_machine.ail src/eval/journal tools/verify_classify Makefile

- **Empty:** the anchors below hold.
- **Not empty:** re-observe every anchor in a file that changed before you use it.
- **For the baseline,** run the check in `evidence/judge-recoveries/baseline-59d5cbb9/README.md`.
  It names the files the other cluster may have changed and says what that does to each
  comparison.
- **If the other cluster merged first,** the `Makefile` differs in its target lists and nothing
  below moves. Also run its gate, `make corpus_judge`, in your done-check: it evaluates your rules
  on sixteen real runs.

## Read first

1. `PLAN-judge-recoveries-on-real-runs.md`: §2 F3 and F4; §3; in §4, *Rules that hold for every
   item*, *Names this plan fixes* and WI-2.
2. `ADR-003-judge-recoveries-on-real-runs.md`: D2 and D3 with their soundness boundaries, D6's
   first precondition, rulings 7, 8 and 14.
3. `evidence/mutation-spike/scripts/prototype2.diff`: both rules as a prototype. A sketch. See
   *What you would break by accident*.
4. `NOTE-spike-findings-mutation-operator-feasibility.md`, parts 4 and 5, for what the prototype
   got wrong and what the rules must see.
5. `../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`.

## Anchors, observed at `59d5cbb9`

In `src/core/dst_invariants.ail` (2,390 lines, forty constructors, nine inline tests, no contract
and no `-- contracts:` line):

| what | where |
|---|---|
| the vocabulary import that gains `ProviderCallPrepared` | `:136` to `:140` |
| the type, its F6 block and its F8 block | `:318`; `:340` to `:343`; `:347` to `:350` |
| the three total matches | `violation_family` `:381`, `violation_rule` `:426`, `violation_message` `:471` |
| D3's neighbours | `provider_steps` `:1534` reads the **log**; `repeated_steps` `:1552` builds `ProviderStepRepeated`; `bounded_progress_findings` `:1570` |
| D2's neighbours | `terminal_summary_of` `:1647`, `outcome_agreement_findings` `:1687`, `summary_finish` `:1712`, `done_agreement` `:1728` |
| the set | `evaluate` `:2010` |
| the set's version, and the rule that moves it | `invariant_set_version()` `:222`, `"invariant-set/1"`; the comment at `:219` says a change to a rule id is a version change; only the banner at `invariants_dst.ail:1205` reads it |
| the count literal | `List.length(vs) == 40`, `:2290`, in `test_rules_are_distinct_across_families` |
| the sample list | `sample_violations` `:2306`; `test_every_rule_has_a_message_naming_it` `:2344` requires each message to start with `[<rule id>] ` |

In `scripts/dst/invariants_dst.ail`:

| what | where |
|---|---|
| the fixture's summary, which fixes `finish_reason: "stop"` | `fixture_summary` `:337` |
| the fixture's trace: one `ProviderCallPrepared` at step 0, and a `DoneEvent` | `fixture_trace` `:373`; `:376`; `:389` |
| the fixture's result, which builds only `Ok([])` | `fixture_result` `:394` |
| a helper that also writes `Ok([])` | `with_trace` `:426`, which `with_records` (`:433`) calls: passing a fixture through either resets its outcome |
| the surviving fixture | `fixture` `:409` |
| the other helpers | `with_log` `:437`, `mutant` `:489`, `replace_summary` `:975` |
| the F6 and F8 rows | `scenario_mutants_family_5_to_8` `:909`; frozen cursor `:942`; `Ok` against an error `:958`; no summary `:962` |

Elsewhere:

| what | where |
|---|---|
| the outcome's error type | `AIError = { code, message, retryable }`; `outcome: Result[[Message], AIError]`, `dst_result.ail:94` |
| the driver's own mapping, **for reference only** | `decision_fail_reason`, `session.ail:2467`; `finish_reason_wire`, `phase_vocab.ail:966` |
| where the three named codes are produced | `step_machine.ail:111`, `:113`, `:117`; `session.ail:3798` |
| the pinned rule sets of a real run | `stream_parity_dst.ail:380` `["clock-balance"]`, `:390` `[]` |
| the guard on the type | `make invariants`, `Makefile:1633`: it counts lines matching `^  [|=]` from the type's header to the next blank line, and checks the sample list by constructor name |
| every caller of `evaluate` outside the module | `invariants_dst.ail`, `stream_parity_dst.ail:293`, `:328`, `src/eval/journal/bridge.ail:103`, `witness_live_test.ail:174`, `:186`, `:328`, `candidate_checks.ail:383` |
| rule ids the evaluator pins, neither of them yours | `decision-budget-exceeded` (`witness_live_test.ail:334`), `journal-payload-disagrees` (`:376`) |

Measured, so you do not re-derive it:

- **The surviving fixture meets both rules as it stands:** `Ok`, `stop`, one prepared step.
- **Every corpus member satisfies D2's table and has no repeated driver step today.** The plan's
  reviewer computed both beside each of the sixteen runs. Six end `Err`: four on
  `E_PROVIDER_PROTOCOL` and seed 19 on `E_PROVIDER_TIMEOUT`, all with `error`; seed 244 on
  `StepBudgetExhausted` with `max_steps`.
- **No evaluator file needs an edit.** The one match on `Violation` outside the module,
  `cc_violation_step` in `candidate_checks.ail`, ends in a wildcard. The rule ids you sit beside,
  `outcome-summary-disagree` and `provider-step-repeated`, are named nowhere outside
  `invariants_dst.ail` (`:960`, `:945`).
- **D2's table function needs a real contract.** A probe of the same function verifies under a
  synthesised `ensures { true }`, so `new_contract_policy` would reject a `-- contracts:` excuse on
  it. `ensures { result != "stop" }` verifies in under 100 ms, on an exported function and on a
  private one. The recursive helpers take the excuse form already used at
  `src/core/dst_profile_coverage.ail:741`.
- **`new_contract_policy` sees only committed changes.** It reads `origin/main...HEAD`
  (`new_contract_policy.py:64`). On an uncommitted tree it prints `no pure func added` and exits
  0, whatever the tree holds.
- **The matrix is exact and takes under fourteen minutes.** Two runs at two commits differed in no
  row.

## The commit

The plan's WI-2 lists what goes in the module and the nine kinds of row in the script, and fixes
the two constructor names and rule ids. It also moves the set's version to `invariant-set/2`.

**Done, in this order.**

    make invariants
    make stream_parity                       # its two rule sets are unchanged in the source
    ailang test src/core/dst_invariants.ail  # the nine and yours
    make verify_classify                     # regenerates tools/verify_classify/contracts.register
    make verify_core verify_classify_check
    make dst                                 # its FAILED block is the baseline's four names
    # commit, and only then:
    make new_contract_policy
    make eval_matrix EVAL_MATRIX_ARGS="--logs <dir>"
    cp src/eval/journal/testdata/MATRIX.tsv <dir>/
    .agent/projects/011_improve_test_axises/evidence/judge-recoveries/compare_matrix.py \
      .agent/projects/011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9 <dir>

- The policy names each function you added, as `carries a contract`, `excuse checked` or
  `out of scope`. If it prints `no pure func added`, it did not see your commit.
- The comparer prints `VERDICT: IDENTICAL` and exits 0. That is D6's first precondition, run here
  because this commit is where both rules start running on journal runs (ruling 14). The reference
  is the tree without your two rules, which is that baseline while its README's check holds.
- The matrix goes after the commit because `scripts/eval/test_candidate.py` assembles its trees
  from a commit. It refuses its candidates before running at this commit in any case; the suites
  that carry the check are the three `*_live_test.ail` files that evaluate real runs.
- The matrix refuses its live suites when the container's `memory.current` is at 12 GiB or more.
  Run nothing heavy beside it. Do not commit the generated `MATRIX.tsv` under `src/eval/`.
- Only `check_core`, the `verify` job and `test_coverage` see this commit in CI. `make invariants`
  and `make stream_parity` are in no workflow, so the commands above are the only time they run.

## What you would break by accident

- **Reusing a constructor.** The prototype reported a repeated driver step through
  `ProviderStepRepeated`, whose message says the cursor "did not advance" in a log that was fine.
  Each rule has its own constructor and a message that is true of its own condition.
- **Asking the driver.** D2's table is stated in this module. An oracle that called
  `decision_fail_reason` would agree with the driver by construction.
- **A row that asserts "some finding".** Every rejection row names its rule. The two rows that
  matter most assert an absence as well: a repeated driver step is **not**
  `provider-step-repeated`, and the frozen cursor is **not** `driver-step-repeated`.
  `stream_parity_dst.ail:308` is the house form of such a row.
- **An `Err` fixture made by flipping the outcome.** The fixture trace carries a `DoneEvent`, and
  `done_agreement` rejects one beside a summary error. A survival row built that way is red on
  `done-event-disagrees` and tells you nothing about your rule.
- **Rejection without survival.** Each of the four code and reason pairs needs a row that must
  produce no finding. Two of them, `BudgetExceeded` and `ContextExhausted`, are checked nowhere
  else: no corpus member ends on cost or on compaction (the plan's F3). D3 needs one too: two
  prepared records with different steps, silent. The fixture has one prepared record, so without
  that row a rule that fired on any two would pass this script.
- **An `Err` fixture that turns back into `Ok`.** `with_trace` writes `Ok([])`. Build the outcome
  after the records, or give the helper a second form.
- **A blank line or a wrapped constructor inside the type.** The guard counts lines.
- **Touching `stream_parity_dst.ail`.** Its two rule sets are a pin. If one would have to change,
  that is a finding.
- **Tidying the `Makefile`.** Its comment at `:1612` quotes stale counts. Leave it: the other
  cluster edits that file.

## Stop and report, do not decide

- A healthy run red under either rule: in `make invariants`, in `make stream_parity`, in the
  matrix, or in `make corpus_judge` if it exists.
- A matrix row or suite exit that differs from the baseline.
- A pinned rule set, register count or any other pin that would have to move.
- A summary that reaches the rule with a finish reason or an error code the table does not name.
  D2 says such a run is red until the table is edited on purpose; whether to edit it is not yours.
- Anything in ADR-003's *Not decided* list.

## Conventions

One worktree and one branch for this cluster, from `origin/main`. Nothing is committed on `main`.
The pull request goes through `tools/pr` (`tools/pr/README.md`).

## Report at the end

The commit; the output of each done-check, with the comparer's lines in full; wall time from first
edit to green, files touched, edits that needed judgement against mechanical ones, and
verification runs repeated; anything in the plan or in this handoff that the source contradicted.
