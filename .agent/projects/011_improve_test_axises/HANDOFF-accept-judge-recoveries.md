# Handoff: run the acceptance of ADR-003's rules (WI-4 of the plan)

Date: 2026-10-07
From: the session that wrote `PLAN-judge-recoveries-on-real-runs.md` and verified both builds
For: a fresh session that built none of it, in its own worktrees
Deliverable: an evidence folder, a result note and one draft pull request

**Run WI-4, once, at `ce9cb247`. Change no rule, no gate and no source.** Your output is evidence
and a verdict per rule. A mutant that survives is a finding you report; it is not something you
repair.

The plan is the specification, and ADR-003 D6 is the decision it carries out. This handoff adds the
grounding as of today, what the builds actually produced, the rules you would break by accident,
and where to stop. Where they disagree the plan wins, and where the plan and the ADR disagree the
ADR wins.

## First: is this still the commit handed in?

    git rev-parse origin/main        # ce9cb247…, the merge of #229
    git diff --stat ce9cb247 origin/main -- src scripts tools packages Makefile .github ailang.toml ailang.lock

- **Both as expected:** go on.
- **`main` has moved in those paths:** stop and ask. Which commit is handed in is the operator's.
- **Docs only have moved:** go on at `ce9cb247`.

The baseline's own check, from `evidence/judge-recoveries/baseline-59d5cbb9/README.md`, shows
seven files at this commit: the gate cluster's four and the rules cluster's three. That is the
row of its table that makes the committed baseline the matrix's reference.

## Read first

1. `PLAN-judge-recoveries-on-real-runs.md`: WI-4, *Rules that hold for every item*, F3.
2. `ADR-003-judge-recoveries-on-real-runs.md`: D6 in full (the table, the controls, the four
   preconditions, the known-unseen list), and rulings 10, 14 and 16.
3. `../../meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`. Its six rules are
   the scoring rules here.
4. `scripts/dst/corpus_judge_dst.ail`, the header and `main`; `Makefile:2016`, the recipe.
5. `evidence/mutation-spike/scripts/`: `mutants.py`, `mutants3.py` and `mutants5.py` hold the exact
   text of most of the edits below, each refusing a replacement that does not match once.
   `control6.sh` is the known-bad journal control as it was run. `run_probe5.sh` is the shape of a
   runner. Do not reuse `score3.py`: it reads a timed-out gate as green.

## What the builds produced, as merged

| what | where and how it reads |
|---|---|
| the gate | `make corpus_judge`: exit 0 when clean, non-zero when any member is red. About a minute |
| a member's rows | `JUDGEROW <member> n=… ended=… finish=… set=[…] checks=[…] not_evaluated=[…]`, then one `JUDGE <member> <rule id> <clean\|RED\|not-evaluated> <detail>` per rule |
| a family finding | two rows: `JUDGE <member> invariant-set RED <n> finding(s)…` and `JUDGE <member> <the finding's rule id> RED <family>: [<rule id>] <message>` |
| the six gate rule ids | `steps-not-contiguous`, `provider-calls-exceed-budget`, `retry-at-budget-edge`, `provider-calls-unbalanced` (with `log below trace` or `log above trace`), `tool-dispatches-unbalanced` (likewise), `request-ordinals-not-contiguous` |
| the two family rule ids | `outcome-finish-disagrees` (`dst_invariants.ail:1802`, the table at `:1812`), `driver-step-repeated` (`:1620`, the test at `:1625`) |
| the two budget controls | `CONTROLROW` and `CONTROL` rows for `retry-with-two-steps-left` and `no-retry-with-one-step-left` |
| on red | a `FAILURE RECORD <member>` per red member; the recipe keeps its output file and prints its path. One file is kept per red run: collect what you need and delete it |
| the set's version | `invariant-set/2`, printed in the gate's first line |

The members, measured at this code on 2026-10-07:

| | members |
|---|---|
| end `Ok` on `stop` (10) | seeds 1, 2, 4, 9, 10, 12, 15, 62, 141 and `constructed-empty-terminal` |
| end `Err` on a provider failure (5) | seeds 5, 7, 30 and 32 on `E_PROVIDER_PROTOCOL`; seed 19 on `E_PROVIDER_TIMEOUT` |
| end `Err` on the step budget (1) | seed 244, `StepBudgetExhausted` with `max_steps` |
| record a retry (4) | seeds 9, 32 and 141 at step 1; seed 19 at step 8 |
| dispatch a tool (10) | seeds 1, 4, 10, 12, 15, 19, 32, 62, 141, 244 |
| make 12 calls on a budget of 12 (2) | seeds 19 and 244 |

**One row has been seen already, and it does not count.** On 2026-10-07 the delegating session
merged the two build branches in a throwaway worktree and applied row 1's edit once: red on
seeds 5, 7, 19, 30 and 32 with `outcome-finish-disagrees`. That was a smoke check before the
merges, on a tree that was not the commit handed in. Run row 1 like every other row.

## Where you work

- **The evidence worktree:** `/workspaces/motoko_agent-011-accept`, branch
  `docs/011-accept-judge-recoveries`, at `ce9cb247`. This handoff is in it, uncommitted. Your
  commit carries it with the evidence.
- **A scratch worktree for every source edit:** create it yourself, detached at `ce9cb247`, for
  example `/workspaces/motoko_agent-011-accept-scratch`. No source file is ever edited in the
  evidence worktree, and nothing from the scratch worktree is committed.

## The run, in this order

1. **Write the predictions and hash them.** One file, one row per mutant and per control: the
   rule, the edit, the rule id expected red, the members expected. The table below and the plan's
   WI-4 are your source. Record its SHA-256 in the sequence log before the first mutant runs.
2. **The unmutated controls.** At `ce9cb247`: `make corpus_judge` green with both `CONTROL` rows
   clean; `make invariants`; `make stream_parity` with `clock-balance` and none;
   `ailang test src/core/dst_invariants.ail`. Then a comment-only edit in the retry branch of
   `session.ail` (`mutants.py` `K0`): the gate is green and its `JUDGE` rows equal the unmutated
   run's line for line.
3. **Precondition 1, the journal callers** (ruling 14).
   - `make eval_matrix EVAL_MATRIX_ARGS="--logs <dir>"`, copy the generated `MATRIX.tsv` into
     `<dir>`, remove it from `src/eval/journal/testdata/`, and run
     `evidence/judge-recoveries/compare_matrix.py evidence/judge-recoveries/baseline-59d5cbb9 <dir>`.
     It must print `VERDICT: IDENTICAL`. The reference is the last tree without the two rules,
     which is that baseline. The rules cluster got `IDENTICAL` at `c0f7eb02`; this is the same
     check at the commit handed in.
   - Two known-bad controls, so that `IDENTICAL` is not the answer to everything. Each is one
     edit to `src/core/dst_invariants.ail` in the scratch worktree, then `witness_live_test.ail`
     and `candidate_checks_live_test.ail` run as `control6.sh` runs them, then restore.
     - D2: `:1812`, `StepBudgetExhausted` implies `"error"`. Expected: `witness_live_test` red on
       its suspended run with `A8:outcome-finish-disagrees@aggregate:invariants:outcome-agreement`.
     - D3: `:1625`, the test `n > 1` becomes `n > 0`. Expected: red with
       `A8:driver-step-repeated@aggregate:invariants:bounded-progress`. This shows the suites would
       report a D3 finding. No journal run holds a retry, so no driver mutant can show it there.
   - `scripts/eval/test_candidate.py` refuses its candidates before running at this commit. It
     says nothing either way; record that and do not chase it.
4. **Precondition 2, the budget-edge controls.** They are the two `CONTROL` rows of step 2. Cite
   them.
5. **Precondition 3, D5's other direction.** Row P3 of the table.
6. **Precondition 4, a hook that calls the model.** A one-off probe script, kept in the evidence
   and not added to the gate: a recording run whose pre-step hook calls `ai_step`, on the shape of
   `consuming_pre_step_2` in `scripts/dst/world_state_probe.ail:237`. Count `ProviderCallPrepared`
   records in the returned trace and provider interactions the run added to the log. Expected:
   more logged than prepared, on a healthy run. That is why D5 is fenced to the bank.
7. **Rows 1 to 13,** one at a time.
8. **The blind reviewer's mutants,** if `/workspaces/motoko_agent/tmp/blind-011/blind-mutants.tsv`
   and its `.sha256` exist when you reach this step. Check the hash, then run each row exactly as
   you ran your own. If the file is not there, say in your report that this step is owed and
   finish without it. Do not write these mutants yourself: you have seen the table.
9. **Score, write the evidence and the result note, open the draft pull request.**

## The rows

Sites are at `ce9cb247`. `session.ail`, `step_machine.ail`, `recovery.ail` and `tool_phase.ail`
have not changed since the spike, so its appliers' text still matches.

| # | one edit | text in | must print `RED` | on |
|---|---|---|---|---|
| 1 | `session.ail:3920`, the failure finalize reports `TermSuccess` | `mutants.py` `M3` | `outcome-finish-disagrees` | seeds 5, 7, 19, 30, 32 |
| 2 | `session.ail:3402`, the success finalize reports a failure reason | part 4's `M3m`, `mutants4.py` | `outcome-finish-disagrees` | the ten `Ok` members |
| 3 | `session.ail:3920` reports `TermMaxSteps` | `mutants5.py` `R1` | `outcome-finish-disagrees` | seeds 5, 7, 19, 30, 32 |
| 4 | `session.ail:2789` reports `TermInternalFailure` | `R2` | `outcome-finish-disagrees` | seed 244 |
| 5 | `session.ail:3887`, the retry keeps `step_idx` | `M1` | `driver-step-repeated` | seeds 9, 19, 32, 141 |
| 6 | `session.ail:3887`, the retry adds two | `R3` | `steps-not-contiguous` | seeds 9, 19, 32, 141 |
| 7 | `step_machine.ail:103`, `>=` becomes `>` | `R5` | `provider-calls-exceed-budget`, and no other rule | seed 244 alone, 13 on 12 |
| 8 | `recovery.ail:28`, drop `remaining_step_budget > 1` | `M9` | `retry-at-budget-edge` | seed 19, at step 11 of 12 |
| 9 | `session.ail:3892`, the retry keeps the pre-call world | `M2` | `provider-calls-unbalanced` and `request-ordinals-not-contiguous` | the four that retry |
| 10 | `session.ail:3613`, the denied-approval arm continues from `st` | `M6` | `request-ordinals-not-contiguous` | 12 members, by the spike |
| 11 | `session.ail:3920`, `capt.world` becomes `stepped.world` | `R4` | `request-ordinals-not-contiguous` | seeds 5, 7, 30, 32 |
| 12 | `session.ail:3623`, the approved call's successor is dropped | `mutants3.py` `T3` | `tool-dispatches-unbalanced`, `log below trace` | the ten that dispatch |
| 13 | `tool_phase.ail:505`, `emitted: [complete_event]` | new; write it | `tool-dispatches-unbalanced`, `log above trace` | the ten that dispatch |
| P3 | `session.ail:3861`, the `ProviderCallPrepared` append is dropped | new; write it | `provider-calls-unbalanced`, `log above trace` | all sixteen |

- Rows 1 to 12 are D6's. Row 13 is the plan's: D6 owes a second direction for D5 and none for
  D10, and the gate states both balances as red either way.
- Rows 13 and P3 are predicted by reading. The rest are the spike's results on a prototype, which
  gave counts of members and not always their names. The names in rows 5, 6, 9 and 11 are this
  handoff's reading of the member table above: the four that retry, and the four that end on a
  non-retryable provider failure, which is where the capture read is made.
- Row 5 will also turn `steps-not-contiguous` red, and `provider-calls-exceed-budget` on seed 19.
  Row P3 will also trip the gate's anti-vacuity guard on every member. Record what else goes red;
  the row is judged on the rule it names.
- Row 8's edit also breaks the contract on `should_retry_stream_error`. The gate does not run the
  verifier, so the row is still judged on `retry-at-budget-edge`.

## What counts

- **A kill:** the run's output holds `JUDGE <member> <rule id> RED` for the rule the row names.
- **Not a kill, recorded as what it is:** a type or compile error, a timeout, a non-zero exit with
  no row for the named rule, another rule red alone.
- **The members:** record the set seen beside the set predicted. A different set with the named
  rule red is a kill and a prediction miss, and you say so.
- **After every row:** restore the file, compare the SHA-256 of every source file you ever edit
  with its value before the first row, and check `git status` in the scratch worktree is empty.
  End the sequence log with one integrity line.
- **A rule is accepted** when every row naming it is a kill and every control is green. Say which
  rules are accepted, which are not, and what acceptance does not claim: D6's known-unseen list,
  the two table rows of F3, and everything in *Not decided*.

## What you would break by accident

- **Scoring by exit status.** A mutant that fails to compile exits non-zero too. Read the rows.
- **Stopping at the first survivor.** Finish the table. A survivor is one row of the result.
- **Repairing what a survivor shows.** Not a rule, not the gate, not a prediction after the hash.
- **Leaving a mutant in place.** The next row would then be two edits.
- **Editing source in the evidence worktree,** or committing anything from the scratch one.
- **Comparing the matrix with the commit's parent.** That parent has the rules; the comparison
  would be identical whatever they do. The reference is `baseline-59d5cbb9`.
- **Running the matrix beside something heavy.** It refuses its live suites at 12 GiB of container
  memory. Run it as `flock -x /tmp/motoko-011-heavy.lock make eval_matrix …`, in the background,
  and wait to be notified. Other sessions on this machine use the same lock.
- **Writing the blind mutants.** They have to come from an agent that has not seen D6's table.
- **Committing wires or the generated `MATRIX.tsv` under `src/eval/`.** The evidence holds
  non-wire lines, the comparer's output and your tables.

## Stop and report, do not decide

- The unmutated gate is not green at `ce9cb247`, or any control in step 2 is red.
- The matrix differs from the baseline, or a known-bad control leaves the live suites green.
- `main` has moved in a code path.
- Anything that would need a pin to move, a rule to change, or an item of *Not decided* settled.

A survivor among the rows is **not** one of these. Finish, and report it.

## The evidence, and the pull request

In `evidence/judge-recoveries/acceptance-ce9cb247/`: a `README.md` that is the result note
(what was accepted, each row's verdict, the preconditions, what is not claimed); `mutants.tsv`
with one row per mutant and control; the predictions file and its hash; the applier, the runner
and the scorer; the sequence log; each run's non-wire output; the comparer's output; the two
known-bad controls' lines; the hook probe and its output.

One commit on `docs/011-accept-judge-recoveries` with that folder and this handoff, then a draft
pull request opened as the bot through `tools/pr` (`tools/pr/README.md`). `pr.ts` has no draft
flag: stage the body with `bun tools/pr/pr.ts draft --base main --remote origin --title "…"`, fill
it, `git push origin <branch>`, open it with
`GH_TOKEN="$MOTOKO_BOT_GH_TOKEN" gh pr create --draft --repo arniwesth/motoko_agent --base main --head <branch> --title "…" --body-file <the staged body without its frontmatter>`,
then `bun tools/pr/pr.ts create --base main --remote origin` to adopt it and write the record,
and commit the record. The repository's git config is read-only in this container, so
`git push -u` prints an error after pushing; that is expected. Do not mark the pull request ready
and do not merge it. Do not edit ADR-003: whether its status changes is the operator's.

## Report at the end

Each row's verdict in one table; the preconditions; which rules are accepted; survivors and
prediction misses, each with its output; machine time per row and in total, and any run repeated
and why; anything in the plan or in this handoff that the source contradicted.
