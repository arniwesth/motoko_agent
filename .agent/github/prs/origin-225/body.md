---
repo: arniwesth/motoko_agent
pr: 225
branch: docs/011-plan-judge-recoveries
ticket: null
title: "docs(011): plan for ADR-003 — one gate judging every corpus member's real run, with rulings 13 to 16, a review and two build handoffs"
---

## Summary

Adds the plan that implements ADR-003 v0.2, written by a fresh session at `59d5cbb9` as
`HANDOFF-write-judge-recoveries-plan.md` asked. Its survey put four questions to the operator, who
ruled on all four on 2026-10-06; ADR-003 is amended with them as rulings 13 to 16. The plan was
reviewed once before it was committed, and the branch carries the review record, the two build
handoffs and the baseline evidence the build sessions compare against. Nothing is built.

## Changes

- docs(011): plan for ADR-003 — one gate that judges every corpus member's real run

15 files changed.

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`
- `.agent/projects/011_improve_test_axises/HANDOFF-build-the-corpus-judge-gate.md`
- `.agent/projects/011_improve_test_axises/HANDOFF-build-the-two-invariant-rules.md`
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`
- `.agent/projects/011_improve_test_axises/REVIEW-001-plan-judge-recoveries-claude-opus-5.5.md`
- `.agent/projects/011_improve_test_axises/evidence/judge-recoveries/baseline-59d5cbb9/README.md`

## What the rulings change in ADR-003

Each was a question in the plan with a recommendation, ruled in conversation. The first three:
"I will go with your recommendations". The fourth, after the review: "I will go with your
recommendation". Rulings 1 to 12 stand as given.

| # | Was | Is |
|---|---|---|
| 13 | D4: the execution record carries the step budget; `execution_of` gains a ninth parameter | The gate declares and holds it. No record field, eight parameters. v0.2 had moved D4's two rules into the gate and left the field with the gate as its only reader, at the cost of edits in three of project 013's evaluator files |
| 14 | D6's journal precondition named `make eval_matrix` and no more | The whole matrix, row for row, against the last tree without D2 and D3, with the three suites that evaluate real runs exiting 0 in both |
| 15 | The gate is added to `DST_TARGETS` | And named in a CI workflow, as its own step beside `corpus_pr`. No workflow runs `make dst` |
| 16 | The gate's failure record was not specified | A red row reports the twelve items of 009 ADR-001 D8, with the serialized program by reference to the artifact `corpus_pr` persisted |

## What is in the plan

- **The baseline at `59d5cbb9`, on a clean checkout.** `make dst` exits 2 in 2,085 s with 48 of
  52 targets passing; the four red ones have one cause, the registration-shape inventory failing
  to read `packages/motoko-ext-test-dummy/register.ail`, and no workflow runs any of them.
  `make eval_matrix` fails on three of 28 suites in 821 s and is identical in all 621 rows to the
  spike's unmutated run at `259265b5`.
- **Four findings against ADR-003**, three of them the rulings above. The fourth is a limit on
  acceptance: no corpus member ends on cost or on compaction, so two of D2's four table rows are
  judged on no real run.
- **Four work items in two build clusters that share no file**, then acceptance: the corpus script
  shares its bank and the gate is built on it; the two invariant rules; D6's table with one row
  added for D10's second direction.

## Predicted outcome

- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` outside
  `.agent/` is empty.
- **Two build sessions can start from `main`, in parallel.** Each has a handoff that opens with a
  source-unchanged check, and their file lists do not overlap. Checked by two pull requests, one
  touching `scripts/dst/corpus_pr_dst.ail`, a new `scripts/dst/corpus_judge_dst.ail`, the
  `Makefile` and `.github/workflows/dst-corpora.yml`, and one touching
  `src/core/dst_invariants.ail`, `scripts/dst/invariants_dst.ail` and the contract register.
- **Neither build edits a file under `src/eval/journal/`, and `execution_of` keeps eight
  parameters.** Ruling 13. Checked by those two diffs.
- **Each build reads `make dst` and `make eval_matrix` as a difference against
  `evidence/judge-recoveries/baseline-59d5cbb9/`.** Its README says when that baseline is valid.
  Checked by each build's report naming the same four red sweep targets, and by
  `compare_matrix.py` printing `IDENTICAL` for the rules build.
- **The gate runs in CI on every pull request once it lands.** Ruling 15. Checked by a
  `corpus_judge` step in the `pr-corpus` job.
- **Acceptance is a third session's, with a blind reviewer's mutants.** WI-4. Its handoff is not
  written: it needs the built names and the gate's real output.

## Test evidence

Run on 2026-10-06 at `59d5cbb9`, AILANG v0.47.2. The results are in
`evidence/judge-recoveries/baseline-59d5cbb9/`; the full logs are not committed.

- [x] **`make dst` on a clean detached checkout, cold, `-j8`.** Exit 2, 2,085 s, four targets red:
  `driver_plus_compose`, `driver_plus_no_ops`, `ext_hook_scope`, `ext_hook_scope_selftest`. The
  same four the spike saw. `dst-summary.txt` has each target's failing lines.
- [x] **`make eval_matrix` on the same checkout.** 621 rows: 419 credited, 129 equal, 29 failed,
  33 missing, 11 inapplicable; three of 28 suites non-zero. `compare_matrix.py` against the
  spike's unmutated run: 0 suites, 0 rows and 0 join statuses differ.
- [x] **`corpus_pr`'s output is stable.** 1,871 lines with `duration_ms` masked, identical line for
  line to the spike's comment-only control, and reproduced on a third checkout by the reviewer.
- [x] **Three throwaway probes, each removed afterwards.** A sibling script can import the corpus
  script (53 s cold). D2's table as a function verifies under `ensures { true }`, so it needs a
  real contract. A scripted retryable provider error retries with two steps of budget left and
  not with one.
- [x] **One independent review, by Claude Opus 5.5 in its own worktree.** Verdict: no finding of
  the plan wrong; seven changes asked, all applied. It ran `make invariants`, `make stream_parity`,
  the corpus script, the import route with the helpers exported, and the contract policy on an
  uncommitted tree. The record has its response verbatim and the disposition of each finding.
- [x] **Every `file:line` in the plan and both handoffs was observed at `59d5cbb9`.** No file under
  `src`, `scripts`, `tools`, `.github` or the `Makefile` differs from `259265b5`, where the spike's
  anchors were taken.
- [ ] Nothing in the plan is built, so nothing here shows the two rules or the gate working.
  The reviewer computed what they would read beside each of the sixteen corpus runs and found
  every member clean; that probe is not in the repository.
- [ ] The reviewer's probes were not re-run by the authoring session.
- [ ] `evidence/judge-recoveries/baseline-59d5cbb9/MATRIX.tsv` is a copy of a generated file that
  project 013 keeps untracked at its own path. It is committed here because ruling 14 makes it
  the reference later runs are compared with. Say if it should not be.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
