# Acceptance of ADR-003's rules at `ce9cb247`: the result

Run on 2026-10-07 for `../../../PLAN-judge-recoveries-on-real-runs.md` WI-4, under
`../../../HANDOFF-accept-judge-recoveries.md`, by a session that built none of what it judged.
Commit handed in: `ce9cb247` (`origin/main`, the merge of #229). AILANG v0.47.2 (`e939cba`),
8 cores. No rule, gate or source was changed; every source edit was made in a scratch worktree,
one at a time, and restored.

## The result

- **Every row of the table is a kill.** D6's twelve rows, the plan's row 13 and precondition
  row P3: fourteen mutants, each red on the rule it names, on the members predicted. No prediction
  missed.
- **All four preconditions held, and every control is green.** The matrix is identical to the
  baseline without the two rules, and both known-bad controls turned the journal suites red.
- **The blind reviewer's eight rows: six kills, two survivors.** Both survivors are on lines no
  bank member runs. The reviewer forecast both.
- **Six rule ids are accepted. Two are held for the operator**, each on one blind survivor.

## Verdict per rule

The handoff's rule: a rule is accepted when every row naming it is a kill and every control is
green. Blind rows are counted as rows.

| rule id | decision | table rows naming it | blind rows naming it | verdict |
|---|---|---|---|---|
| `outcome-finish-disagrees` | D2 | 1, 2, 3, 4: kills | B6: kill | **accepted** |
| `steps-not-contiguous` | D3, gate | 6: kill | B7: kill | **accepted** |
| `provider-calls-exceed-budget` | D4 | 7: kill, and no other rule red | B4: kill | **accepted** |
| `retry-at-budget-edge` | D4 | 8: kill | B1: kill | **accepted** |
| `provider-calls-unbalanced` | D5 | 9: kill, log below trace. P3: kill, log above trace | none written | **accepted** |
| `request-ordinals-not-contiguous` | D9 | 9, 10, 11: kills | B5: kill | **accepted** |
| `driver-step-repeated` | D3, family | 5: kill | B3: **survived** | **held**: see below |
| `tool-dispatches-unbalanced` | D10 | 12: kill, log below trace. 13: kill, log above trace | B8: kill. B2: **survived** | **held**: see below |

D1, the set on every member's run, is accepted on what the plan names for it: the unmutated bank
is clean on all sixteen members, and rows 1 to 5 were seen red through the gate.

**The two held rules, and the one question this leaves.** Each has every table row a kill, so each
meets D6's own sentence: "accepted when its mutant has been seen red on that rule and the controls
green". Each also has a blind row naming it that no rule printed, so neither meets the handoff's
sentence read over every row. The two sentences disagree only here. Which governs is the
operator's ruling, and so is the choice between withholding the rule and recording the unreached
branch beside D6's known-unseen list. Nothing was repaired.

## The rows

Fourteen mutants, run through `make corpus_judge` in the scratch worktree. "Seen" is the set of
bank members with `JUDGE <member> <rule id> RED`.

| # | one edit | rule named | predicted on | seen on | verdict | also red |
|---|---|---|---|---|---|---|
| 1 | `session.ail:3920` reports `TermSuccess` | `outcome-finish-disagrees` | seeds 5, 7, 19, 30, 32 | the same 5 | kill | none |
| 2 | `session.ail:3402` reports a failure reason | `outcome-finish-disagrees` | the ten `Ok` members | the same 10 | kill | none |
| 3 | `session.ail:3920` reports `TermMaxSteps` | `outcome-finish-disagrees` | seeds 5, 7, 19, 30, 32 | the same 5 | kill | none |
| 4 | `session.ail:2789` reports `TermInternalFailure` | `outcome-finish-disagrees` | seed 244 | seed 244 | kill | none |
| 5 | `session.ail:3887`, the retry keeps `step_idx` | `driver-step-repeated` | seeds 9, 19, 32, 141 | the same 4 | kill | `steps-not-contiguous` on the same 4; `provider-calls-exceed-budget` on seed 19, 14 calls on 12. Both predicted |
| 6 | `session.ail:3887`, the retry adds two | `steps-not-contiguous` | seeds 9, 19, 32, 141 | the same 4 | kill | none |
| 7 | `step_machine.ail:103`, `>=` becomes `>` | `provider-calls-exceed-budget` | seed 244 alone | seed 244, 13 on 12 | kill | none, as predicted |
| 8 | `recovery.ail:28`, the budget conjunct dropped | `retry-at-budget-edge` | seed 19 | seed 19, a retry at step 11 of 12 | kill | none |
| 9 | `session.ail:3892`, the retry keeps the pre-call world | `provider-calls-unbalanced` and `request-ordinals-not-contiguous` | seeds 9, 19, 32, 141 | the same 4, both rules, log below trace | kill | none |
| 10 | `session.ail:3613`, the denied arm continues from `st` | `request-ordinals-not-contiguous` | 12 members, not named | 12: seeds 1, 2, 4, 7, 9, 10, 12, 15, 19, 62, 141, 244 | kill | none |
| 11 | `session.ail:3920`, `capt.world` becomes `stepped.world` | `request-ordinals-not-contiguous` | seeds 5, 7, 30, 32 | the same 4 | kill | none |
| 12 | `session.ail:3623`, the approved call's successor dropped | `tool-dispatches-unbalanced`, log below trace | the ten that dispatch | the same 10, log below trace | kill | none |
| 13 | `tool_phase.ail:505`, `start_event` left out | `tool-dispatches-unbalanced`, log above trace | the ten that dispatch | the same 10, log above trace | kill | no rule. The guard "a member dispatched a tool" is crossed |
| P3 | `session.ail:3861`, the prepared record's append dropped | `provider-calls-unbalanced`, log above trace | all sixteen | all 16, log above trace | kill | no rule. The guard "every member's trace holds a prepared call" is crossed, as predicted |

- **No row failed to compile, timed out or stopped early.** Every run printed sixteen member rows
  and its closing verdict.
- **The two budget controls also go red under some mutants**, because they run through the same
  mutated driver. A `CONTROL` row never counts toward a kill.
- **Row 13 left the invariant set silent.** A trace with a dispatch-complete record and no
  dispatch-start record drew no finding from the set on any member; only the gate's balance saw it.
  Recorded as seen, not judged.

## The blind reviewer's rows

Written by another session at `ce9cb247`, told the eight rules as prose and not shown D6's table.
Its file is `blind/blind-mutants.tsv` (SHA-256 `a042edec…5670753`, checked against the hash beside
it). It was opened only after the fourteen rows above were scored; the sequence log has the order.
Scoring was fixed in `blind/blind-scoring.tsv` before any blind row ran: the rule a row names is
the rule its edit breaks.

| # | one edit | rule named | reviewer forecast | seen | verdict |
|---|---|---|---|---|---|
| B1 | `session.ail:3879`, the retry decision is given the whole budget | `retry-at-budget-edge` | no rule red | seed 19 | kill; the forecast was wrong |
| B2 | `tool_phase.ail:615`, the fold recurses with `world` | `tool-dispatches-unbalanced` | no rule red | nothing red, exit 0 | **survived** |
| B3 | `session.ail:2985`, a verifier rejection keeps `step_idx` | `driver-step-repeated` | no rule red | nothing red, exit 0 | **survived** |
| B4 | `step_machine.ail:103`, `>=` becomes `>` | `provider-calls-exceed-budget` | that rule | seed 244 | kill |
| B5 | `session.ail:3402`, the success finalize reads `st.world_state` | `request-ordinals-not-contiguous` | that rule | the ten `Ok` members | kill |
| B6 | `session.ail:3920` reports `TermMaxSteps` | `outcome-finish-disagrees` | that rule | seeds 5, 7, 19, 30, 32 | kill |
| B7 | `session.ail:2868`, a finished tool batch adds a step | `steps-not-contiguous` | that rule | 13: seeds 1, 2, 4, 7, 9, 10, 12, 15, 19, 32, 62, 141, 244 | kill |
| B8 | `session.ail:3623`, the approved call's successor dropped | `tool-dispatches-unbalanced` | that rule | the ten that dispatch | kill |

- **B4, B6 and B8 are the same edits as rows 7, 3 and 12**, reached without seeing them. B1, B2,
  B3, B5 and B7 are new.
- **The reviewer wrote no row for `provider-calls-unbalanced`.** Its reply says the only one-edit
  breaks it found are the two directions the gate's comments describe.
- **B1 was forecast green and is a kill.** The reviewer did not know seed 19 takes a retryable
  error at step 11 of 12.

## The two survivors

| | B2 | B3 |
|---|---|---|
| the edit | `dispatch_tool_entries_with_builtin` recurses with `world` and not `executed.next_state` | `c2_dp7_rejected_state` sets `step_idx: step_idx` |
| what it breaks | a tool run without an approval loses its successor: D10, log below trace | the model is called again under the same step: D3's family rule |
| the gate | exit 0, all sixteen members clean | exit 0, all sixteen members clean |
| why, by the reviewer | the bank's policy hook answers `Pending` for every call, so every tool runs from the approval arm | the bank's runtime has verification disabled |
| measured | no member and neither control evaluates the line | no member and neither control evaluates the line |

**Measured how.** Three reach probes, in `reach-probes.tsv`: the same line made to panic if it is
ever evaluated. On row 12's line the gate crashes with `panic: division by zero` before its first
member row. On B2's line and on B3's line it stays green with all sixteen members clean. The
probes are diagnostic. They are not rows of any table and no verdict rests on them.

So neither survivor is a rule missing a defect on a run it judged. Each is a branch the sixteen
members do not walk, which is the limit D1 states for the gate. `make invariants` holds a
constructed row for a repeated driver step; no real run with a verifier rejection, and no real run
with a tool executed without an approval, is judged by anything this acceptance ran.

## The preconditions

| # | precondition | result |
|---|---|---|
| 1 | the journal callers (ruling 14) | `make eval_matrix` at `ce9cb247`, 789 s: `VERDICT: IDENTICAL` against `../baseline-59d5cbb9`, 28 suites and 621 rows, no suite exit, observation or join status differing. `witness_live_test`, `candidate_checks_live_test` and `admission_live_test` exit 0 on both sides |
| 1 | known-bad D2: `StepBudgetExhausted` implies `error` | `witness_live_test` exits 1; `m11_t0_suspended_clean: findings=[A8:outcome-finish-disagrees@aggregate:invariants:outcome-agreement]`, `FAIL m11_t0_suspended_clean` |
| 1 | known-bad D3: `n > 1` becomes `n > 0` | `witness_live_test` exits 1; `A8:driver-step-repeated@aggregate:invariants:bounded-progress` on the suspended and the finalized run, `FAIL` on both |
| 2 | the two budget-edge controls | both `CONTROL` runs of the unmutated gate clean: 14 of 14 rows, 6 of 6 report rows |
| 3 | D5's other direction | row P3 above: a kill on all sixteen, log above trace |
| 4 | a hook that calls the model | `hook-probe/`: the bank's rig with a pre-step hook that calls `ai_step` once. The run ends `Ok` on `stop` with steps and ordinals contiguous, 1 prepared record and 2 provider interactions logged. The same rig with the bank's hook: 1 and 1. The invariant set printed no finding on either |

- **The reference is the last tree without the two rules.** `git diff --stat 59d5cbb9 ce9cb247`
  over the code paths shows the seven files the baseline's README names, so that baseline is valid
  as the reference.
- **`scripts/eval/test_candidate.py` says nothing either way.** It refuses its candidates before
  running (`ProtectedRegionTouched`) and exits 1 here and in the baseline. Recorded, not chased.
- **`candidate_checks_live_test` also exits 1 under both known-bad controls** (`FAIL admission of
  the entries`).

## The controls

| control | result |
|---|---|
| the unmutated gate | exit 0; 16 of 16 members clean on the set and the six checks; both budget controls clean |
| a comment-only edit in the retry branch (K0) | exit 0; its 144 `JUDGEROW`, `JUDGE`, `CONTROLROW` and `CONTROL` lines equal the unmutated run's line for line |
| `make invariants` | passes; 13 families, 42 constructors sampled by name |
| `make stream_parity` | passes; the scripted run reports `clock-balance` and the recording run reports nothing, both as pinned |
| `ailang test src/core/dst_invariants.ail` | 16 tests, 16 passed |

## What acceptance does not claim

- **D6's known-unseen list.** The retry that keeps the successor's log and rewinds its generator
  state; failure reasons that share the wire string `error`; a step label offset by a constant; a
  re-issued park that consumes no budget.
- **The two table rows of F3.** `BudgetExceeded` with `cost_exhausted` and `ContextExhausted` with
  `compaction_exhausted` are judged on no real run. No bank member ends on either.
- **Everything in ADR-003's *Not decided*,** all nine items.
- **The two branches the blind survivors are on.** A tool executed without an approval, and the
  continuation after a verifier rejection. The bank reaches neither.
- **Any profile but `driver_only`,** and any trajectory the sixteen members do not walk. The hook
  probe shows `provider-calls-unbalanced` would be red on a healthy run whose hook calls the model.
- **The replay family.** It is not evaluated on any member; the obligation is `NoReplay`.

## How it was run

- **Order.** Predictions written and hashed (`predictions.tsv.sha256`, `4cde56fe…`) before any
  run. Then the unmutated controls, the matrix, the two known-bad controls, P3, the hook probe,
  rows 1 to 13, the blind rows, the reach probes. `sequence.log` has every step with its time.
- **Scoring reads rows, not exit status.** `scripts/score.py` counts a kill only on
  `JUDGE <member> <rule id> RED` for the named rule, with the direction where the row names one.
  `scripts/score_selftest.py` holds the cases that could be misread: a timeout, a compile error,
  another rule red alone, the wrong direction, a `CONTROL` row.
- **Integrity.** Five files were ever edited: `session.ail`, `step_machine.ail`, `recovery.ail`,
  `tool_phase.ail` and `dst_invariants.ail`. Before and after each of the 28 edits their SHA-256
  equalled `base.sha256` and `git status` in the scratch worktree was empty. The log's last line
  is the closing check; its count of edits was corrected once, from a miscount, before commit.
- **Nothing was repeated.** No run timed out, and every run's wall time equalled its uptime
  delta, so none spanned a suspend.
- **The matrix ran alone,** under `/tmp/motoko-011-heavy.lock`.

| | runs | machine time |
|---|---|---|
| the fourteen table rows | 14 | 524 s, 36 to 38 s each |
| the unmutated controls and K0 | 5 | 244 s |
| the matrix | 1 | 789 s |
| the two known-bad controls | 4 suite runs | 141 s |
| the hook probe | 1 | 51 s |
| the blind rows | 8 | 307 s |
| the reach probes | 3 | 117 s |
| **total** | | **2,173 s, about 36 minutes** |

## What the source contradicted

Nothing that changes a verdict.

1. **The spike's appliers do not all refuse a second match.** The handoff says each refuses a
   replacement that does not match once. An anchored edit in `mutants.py` and `mutants5.py` is
   refused only when its text is absent from the window. `R5`'s text occurs twice after its
   anchor at `ce9cb247`, at `step_machine.ail:103` and `:145`, and the spike took the first.
   `scripts/apply_mutant.py` matches `:103` once by carrying the function header. The blind row
   B4 has the same shape, and its author said so.
2. **The plan's "nine tests and the new ones" is sixteen** at this commit.
3. **Every `ailang` run prints a lock warning** for `sunholo/motoko_ext_herdr` ("content changed",
   locked `e1e96240…`, current `6928b495…`), the unmutated runs included. Not chased.
4. **Every failure record reads "serialized program ABSENT".** `corpus_pr` was never run in the
   scratch worktree, so the artifact a red row refers to is not there. That is ruling 16's
   behaviour, and the gate names the command that writes it.

## Files

| file | what |
|---|---|
| `mutants.tsv` | one row per mutant, control and blind row, as `scripts/score.py` printed it |
| `predictions.tsv`, `predictions.tsv.sha256` | the predictions and scoring rules, hashed before any run |
| `sequence.log` | every step in order, with times, exit codes and the integrity checks |
| `base.sha256` | the five files' hashes before the first edit |
| `scripts/apply_mutant.py`, `apply-check.txt` | the applier, and each edit's single match at `ce9cb247` |
| `scripts/run_row.sh`, `run_controls.sh`, `run_matrix.sh`, `run_known_bad.sh`, `run_hook_probe.sh` | the runners |
| `scripts/score.py`, `score_selftest.py` | the scorer and its self-test |
| `runs/<id>/` | each gate run: `gate.out` (every non-wire line), `mutant.diff`, `apply.log`, `rc`. The controls keep `out.txt` |
| `matrix/` | `compare.txt` (the comparer's output), `MATRIX.tsv`, `suites.json`, `join.tsv`, `matrix.stdout.log`, `live-suites.txt`, `test_candidate-note.txt` |
| `known-bad/` | each control's diff, exit codes and the two suites' non-wire lines; the unmutated suite's lines for comparison |
| `hook-probe/` | the probe script and its output |
| `blind/` | the reviewer's file and hash as received, `blind-scoring.tsv` and its hash, `apply-check.txt` |
| `reach-probes.tsv` | the three reach probes |

Not committed: wires, the per-suite matrix logs, and the full logs of the known-bad suites. The
scratch worktree, `/workspaces/motoko_agent-011-accept-scratch`, is left clean at `ce9cb247`.
The reviewer's brief and reply are in `/workspaces/motoko_agent/tmp/blind-011/`.
