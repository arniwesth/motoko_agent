---
repo: arniwesth/motoko_agent
pr: 337
branch: research/039-random-mutant-pilot
ticket: null
title: "docs(039): random-mutant pilot on the session driver at dd8a12f1"
---

## Summary

This PR adds the first unbiased measure of how much the DST checks notice, as RESEARCH-systematic-mutation-testing §8.1 asks. Thirty small bugs were drawn mechanically, with the base SHA as the seed, from 399 candidate edits in the driver's recovery branches and world handoffs (31 functions across `session.ail`, `recovery.ail`, `step_machine.ail` and `tool_phase.ail`). Each was run one at a time in a scratch worktree and judged by whether a check about the broken behaviour fails. A count pin, vacuity guard or crash that goes red for another reason is recorded and not counted. The PR is evidence only: no test, rule or production source changes.

What it found across the whole suite (`evidence/pilot-dd8a12f1/README.md` has the per-mutant table):

- **22 of 30 are killed** by a check about the broken behaviour somewhere in `make dst`. `ledger_parity`'s wire-against-trace counts killed the most, 7.
- **5 are run, and no check names them.** m11 is an oracle gap: the retry record leaves the returned trace but stays on the wire. m02 marks the intercept arm's journal record as replacing the previous entry, and none of the five targets that run it notices. m03 makes an allowing approval timeout deny; it differs only on EOF or an unparseable reply, which by my reading no run sends, and the fault catalogue already records that. m05 and m18 are judged equivalent on every walked path.
- **3 are run by no target**: m15, on the extension-handled tool path ADR-003 D6 already names, and two sites judged dead code.

Within `corpus_judge`, the gate the pilot was built to grade:

- A bank member runs 17 of the 30, and `corpus_judge`'s rules name 5 of them. The pilot's four tiers named 14 of 30.
- 13 sit where no member runs. The rest of `make dst` runs 10 of those and kills 8 (follow-ups F1 to F3).
- The brief's yield, as it fixed it: 3 by measurement (m05, m11, m18) and 2 after judgement (m11, m18), so its rule says "draw again" and "the operator decides". Read suite-wide, which was not fixed in advance, the yield is 5 and 4, and the rule says "draw again" either way.

**Recommendation: draw a second batch and run it through `make dst`**, with rulings on m02, m03, m11 and m18 alongside. This changed in amendment A8. The earlier advice to wait rested on `corpus_judge`'s reach gaps, and across the suite only 3 of 30 sites go unrun.

## Changes

- docs(039): random-mutant pilot on the session driver at dd8a12f1
- chore(github): PR #337 record
- docs(039): amendment A5, reach wording narrowed to what was measured
- docs(039): follow-up F1, reach probes under make dst (amendment A6)
- docs(039): follow-up F2, the eight reached mutants under make dst (amendment A7)
- docs(039): follow-up F3 and a suite-wide reframe (amendment A8)

**Reviewers: of the 747 files, 671 are raw output under `runs/`. Only the other 75 evidence files are meant to be read.** All are under `.agent/projects/039_systematic_mutation_testing/evidence/pilot-dd8a12f1/`:

- **Read:** `README.md`, which holds the result across the suite and within `corpus_judge`, the per-mutant verdict table, deviations and the recommendation.
- **Check if you want the method:** the other top-level files. These are `population.md`, `operators.md`, `AMENDMENTS.md`, `draw-order.tsv`, `predictions.tsv`, `triage.tsv`, `mutants.tsv` and `sequence.log`, the step log with each step's SHA-256. `README-pre-a5.md` is the README as first committed, kept by amendment A5, `README-pre-a6.md` the README after A5, kept by A6, `README-pre-a7.md` the README after A6, kept by A7, and `README-pre-a8.md` the README after A7, the last that led with the `corpus_judge` result, kept by A8. F1's plan, scores and write-up are `reach-dst-plan.md`, `reach-dst-scores.tsv` and `reach-dst-results.md`. F2's are `mutants-dst-plan.md`, `mutants-dst-scores.txt` and `mutants-dst-results.md`, with each sweep's new failing rows in `mutants-dst-new-rows.txt`. F3's are the same names with `-f3`.
- **Open only to check a method or a verdict:**
  - `scripts/`: the tools that enumerate, draw, apply and score the mutants.
  - `runs/<target>/<id>/`: the raw output of one gate run, with its `out.txt`, `rc`, `mutant.diff` and `apply.log`.
- **Skip:** `runs/` itself. It holds 671 files of raw output kept as evidence, not for review. Its value is that the survivors' "no rule named it" rests on green outputs a later re-run may not reproduce, and that the score tables can be re-derived from it.

The directory is 12.0 MB uncompressed and about 2.3 MB compressed. Each run's files follow the same layout as 011's `acceptance-ce9cb247`.

## Governing docs

- `.agent/projects/039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md` (§8.1, §4.2, §5)
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`
- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md` (D6's "Known, and not seen" list, D9, *Not decided* item 1)
- `.agent/projects/039_systematic_mutation_testing/evidence/pilot-dd8a12f1/README.md`
- `.agent/projects/039_systematic_mutation_testing/evidence/pilot-dd8a12f1/population.md`
- `.agent/projects/039_systematic_mutation_testing/evidence/pilot-dd8a12f1/operators.md`
- `.agent/projects/039_systematic_mutation_testing/evidence/pilot-dd8a12f1/AMENDMENTS.md`

## Predicted outcome

Nothing in the product changes, because this lands only evidence files. 039 gets its §8.1 pilot result and an operator decision with its inputs: whether to draw a second batch through `make dst`, how to rule on m02, m03, m11 and m18, and whether `corpus_judge`'s bank should walk the four branches the rest of `make dst` already walks. The check is that `git diff --stat origin/main` touches only the evidence directory, and that each step's SHA-256 in `sequence.log` matches the file it names.

## Test evidence

The population, operators, enumeration, draw and predictions were each fixed and hashed into `sequence.log` before any mutant ran. Every later change is a dated amendment, A1 to A8 in `AMENDMENTS.md`, not a silent edit. A1 to A5 are corrections; A6 to A8 add the follow-ups' results, and A8 also rewrites the README to lead with the suite-wide verdict.

- **Calibration.** On the unmutated tree, `make corpus_judge` was green on 18 members (46 s). A comment-only edit was green, with all 190 rows identical. Three of acceptance's known-bad rows, re-anchored by text, each went red on their own rule: `outcome-finish-disagrees`, `provider-calls-exceed-budget` and `tool-dispatches-unbalanced`.
- **Tier 3 baseline.** All six targets were green on the unmutated tree: `check_core`, `strict_replay`, `discovery`, `stream_parity`, `ledger_parity` and `corpus_pr`.
- **Tier 4 baseline.** `make dst` on the unmutated tree took 612 s, and only the known-red `declared_vs_performed` failed.
- **Run totals.** 38 draw type checks and 136 mutated gate runs, each restored and hash-checked afterwards (`FINAL INTEGRITY: PASS`). Machine time was 9,672 s.
- **F1 (follow-up, 2026-11-19).** 12 `make dst` sweeps, one reach probe each: 6,952 s. The plan, the predictions, `score_reach_dst.py` and its self-test were hashed into `sequence.log` before any sweep result existed. The positive control's error was printed by 9 targets. `applied_twin` hides it in its printed output but keeps it in the raw output file it names, and the rule for reading that case was logged before any real probe finished. `ledger_parity` and `world_framed_wire` delete a failed program's output, so m12 needed one more run of that program with its output kept (3 s), under a reading rule logged first. Every sweep restored the tree to `base.sha256`. The predictions, from a text search of `scripts/dst/`, held for 8 of 12.
- **F2 (follow-up, 2026-11-19).** 8 `make dst` sweeps, one drawn mutant each: 5,537 s. The plan, the predictions, `score_dst.py` (unchanged since the pilot) and a fresh run of its self-test were hashed into `sequence.log` before the first sweep. Every sweep restored the tree to `base.sha256`. Each red target's output was read by hand, and only a failing check about the broken behaviour counts. The other reds (count pins, a census row, herdr's discovery grade, `test_coverage`) are recorded in `mutants-dst-results.md` and not counted. `scripts/new_rows_dst.py`, which lists each sweep's failing rows absent from the base sweep, was written after the sweeps as a reading aid. The predictions held for 7 of 8; m03 was predicted killed. The scratch worktree was removed afterwards, clean at `dd8a12f1`, and the removal is logged.
- **F3 (follow-up, 2026-11-20).** 2 `make dst` sweeps, m09 and m14, the mutants only `corpus_judge`'s controls reach: 1,622 s, in a scratch worktree recreated at `dd8a12f1` and removed again afterwards. The plan fixed one reading before the sweeps: at the suite level, a `corpus_judge` CONTROL row red on the broken rule counts. Both were killed as predicted: m09 by `ledger_parity`'s `ToolArgumentsInvalid: projected 0, returned 1`, and m14 by the `solver-feedback` control's `journal-fold-disagrees`. Under m14, two of `phase_c_l1`'s decision-sequence pins also went red; they are recorded and not counted.
- **Re-run for this PR.** `scripts/score_selftest.py`, `score_target.py selftest`, `score_dst.py selftest`, `mutator.py selftest` and `score_reach_dst.py selftest` all PASS. On `origin/main` at `2eae0666` (2026-11-19), three of the four driver files still match `base.sha256`. `session.ail` does not: `d66085ab` and `fc546d68` changed `tool_messages_to_result_jsons`, which the population excludes, and added tests after the last site. All 38 drawn site lines are identical at both commits. `tools/githooks/pre-commit` exits 0.
- **Not verified.** The README's *What was not verified* section lists these in full:
  - The four judgements (m05 and m18 equivalent on walked paths, m08 and m26 dead code) rest on reading the source, not on a run that could tell the mutants apart.
  - m01's failing `corpus_pr` row was lost before amendment A4. Its kill rests on `strict_replay` and `discovery`.
  - Tier 2 probed reach under `corpus_judge` only; F1 measured it under `make dst` for 11 of the 13 unreached sites. m09 and m14 were left out because `corpus_judge`'s own controls reach them; F3 ran their mutants under `make dst`.
  - Kills at tiers 1 and 3 count across the suite because `make dst` runs the same targets. Those 13 mutants were not re-run in a full sweep.
  - The suite-wide framing and its yield were not fixed before the pilot (deviation 9). The pilot's own verdicts, counts and yield are unchanged and given beside them.
  - F2 and F3 ran one sweep per mutant. Why m02 survives was not traced: whether the targets that run the intercept arm fold that run's journal at all. Which inline test `test_coverage` caught under m23 and m30 is inferred, because its output names only the file.
  - F1's three "not reached" sweeps hold no division error anywhere and turn no target red. A gate that swallows a runtime error and prints nothing different would still hide a hit.
- **Commit.** The evidence commit was made with git hooks bypassed, without a reason. No hook is installed for this user. `tools/githooks/pre-commit` run by hand on the commit exits 0.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
