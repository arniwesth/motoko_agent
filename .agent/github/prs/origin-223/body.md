---
repo: arniwesth/motoko_agent
pr: 223
branch: docs/011-adr-003-judge-recoveries-on-real-runs
ticket: null
title: "docs(011): ADR-003 v0.2 (accepted) — judge wrong recoveries on real runs, with the mutation spike and two reviews behind it"
---

## Summary

Adds ADR-003 to project 011: how DST should judge a wrong recovery on a real run. The operator
accepted v0.1 on 2026-10-06, two independent reviews then found that four of its rulings rested on
things that do not hold, and the operator accepted the v0.2 amendment the same day.

It comes out of the operator-feasibility spike `RESEARCH-test-axes-beyond-dst.md` §3.3 asked for.
The spike found two single-edit driver defects that add no failure to `make dst`, and showed that
the invariant set does not see them even when it is evaluated over the corpus. The spike's plan,
its findings note, its evidence and both reviews are added with the ADR, because the ADR's numbers
and its changes are theirs. A handoff for the implementation plan is added last.

Documents only. No source, gate or `Makefile` change.

## Changes

- docs(011): the mutation operator-feasibility spike — plan, findings and evidence
- docs(011): ADR-003 (proposed) — how DST should judge a wrong recovery on a real run
- docs(011): ADR-003 accepted — the operator's six rulings of 2026-10-06
- docs(011): two reviews of ADR-003 and the spike's part 5 — the amended rules, run
- docs(011): ADR-003 v0.2 accepted — the amendment after review, and the operator's rulings
- docs(011): the spike's part 6 — the journal control, with the prototype
- docs(011): handoff — write the plan that implements ADR-003

67 files changed.

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`
- `.agent/projects/011_improve_test_axises/REVIEW-001-adr-003-codex-gpt-6-astra.md`
- `.agent/projects/011_improve_test_axises/REVIEW-001-adr-003-claude-fable-5.1.md`
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md`
- `.agent/projects/011_improve_test_axises/PLAN-spike-mutation-operator-feasibility.md`
- `.agent/projects/011_improve_test_axises/evidence/mutation-spike/README.md`
- `.agent/projects/011_improve_test_axises/HANDOFF-write-judge-recoveries-plan.md`

The ADR sits under `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`
D2 and D7 and does not reopen it (ADR-003 D8). It applies
`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md` as its acceptance (D6).

## What v0.2 changed

| | v0.1 | v0.2 |
|---|---|---|
| D2 | `Ok` if and only if `stop` | Also: an `Err` finishes with the reason its error code implies. The table is in the invariant module. Results with no summary are excluded. |
| D3 | No repeated driver step | No repeat in the invariant set; no gap on the corpus, as a gate check. |
| D4 | "The value the run was started with" | The effective budget. A non-positive start is undeclared, and reported as not evaluated. |
| D5 | Sound for a recording world | Three premises: a recording world, no hook that calls the model, a delta over the starting log. |
| D9 | — | Request ordinals in the returned trace are contiguous. |
| D10 | Tool balance deferred | Tool-dispatch balance on the corpus now. Approvals stay undecided. |
| D6 | Six rows | Twelve rows, four controls that are a precondition of acceptance, and a known-unseen list. |
| D8 | D5 "is the discovery contract" | D5, D9 and D10 belong to 009 D2. Still no reopen. |

D1 and D7 keep their rulings.

## Predicted outcome

- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` outside
  `.agent/` is empty.
- **ADR-003 is on record as Accepted, as v0.2.** Its *Rulings* section holds the operator's six
  rulings on v0.1 and the six on v0.2, both of 2026-10-06 and both given in conversation after a
  recommendation for each item. Nothing is implemented, and nine items of its *Not decided* list
  stay open.
- **The first part that implements it hands in a `mutants.tsv`.** ADR-003 D6 names twelve rows of
  one-edit mutants that must each turn its rule red, and the controls that must stay green.
  Checked by reading that part's evidence.
- **No rule is accepted before `make eval_matrix` has run with it.** D6 makes the journal callers
  of `evaluate` the first of four precondition controls. That target is outside `make dst` and
  named by no workflow.
- **The implementation plan is written by a fresh session, from the handoff.** Per
  `.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`. Checked
  by `PLAN-judge-recoveries-on-real-runs.md` appearing in project 011 from another session.
- **§3.3's planning figure stops being used.** The findings note measures a full sweep at 50
  minutes cold and about 31 warm against the 196 seconds §3.3 budgets. The research note itself is
  not edited here.

## Test evidence

The measurements are the spike's, run 2026-10-05/06 in a throwaway worktree at `259265b5` on
AILANG v0.47.2. They are in the findings note; the tables are in
`evidence/mutation-spike/results/`. In short:

- [x] **Part 1, 13 rows and 7 full sweeps.** Controls as required: a comment-only edit leaves the
  corpus wire identical to the unmutated run (0 of 1,609 lines differ); the demo's mutant is killed
  by the named rule. Of 11 mutants, 9 add a failure to `make dst` and 2 do not.
  `FINAL INTEGRITY: PASS`.
- [x] **Part 2, 14 rows.** `evaluate()` over all 16 corpus members: clean on the unmutated tree,
  clean under all 11 mutants at the driver's own bounds, red under a known-bad control.
- [x] **Part 3, 7 rows.** Three tool handoffs, each with a reach probe. Two mutants killed; the
  handoff at `session.ail:3694` is reached by none of the six gates probed.
- [x] **Part 4, 18 rows.** A prototype of v0.1's D2–D5: both survivors red, no control red.
  18 of 18 outcomes predicted in advance.
- [x] **Part 5, 24 rows.** A prototype of v0.2, run before the amendment was written, with the
  reviewers' six mutants. With it on the unmutated tree `make invariants` and `make stream_parity`
  pass, the module's 9 inline tests pass, and all 16 members are clean on every rule. Every mutant
  that breaks a stated rule goes red on that rule. One reviewer mutant, a retry that rewinds the
  generator, passes everything and is listed as known and unseen. 24 of 24 predicted; the rules
  were written from these mutants, so read that score for what it is.
- [x] **Part 6, the journal control at prototype level.** `make eval_matrix` with the v0.2
  prototype is identical to the unmutated tree's run: 28 suites, 621 rows. A known-bad control, one
  wrong row in D2's table, turns both live journal suites red on their suspended run. The baseline
  is itself red on 3 of 28 suites at `259265b5`, for reasons that are project 013's, so the matrix
  is read as a difference.
- [x] **Two independent reviews of v0.1**, each in its own worktree at the reviewed commit, each
  running its own probes. Every finding accepted was re-observed first. Dispositions are in the
  review records.
- [x] **Each scorer was run on planted cases before it saw a result**: 15/15, 9/9, 11/11.
- [x] **`mutants.tsv` is generated**, by `evidence/mutation-spike/scripts/make_table.py` from the
  run output. It covers parts 1 to 4; part 5's rows are in `results/part5-score.txt`.
- [x] **Every source line the ADR cites was re-observed at `259265b5`.**

Not done:

- [ ] No gate was run on this branch. It changes documents only.
- [ ] v0.2 has not been read by a second reader. The operator ruled against a second general
  review round; the next independent check is the implementation's acceptance run.
- [ ] Of the four controls D6 makes a precondition of acceptance, three have not been run. The
  fourth, the journal callers, has been run with the prototype only: it had no D4, its
  committed-tree path was not reached, and its known-bad control covers D2's `Err` half alone.
- [ ] The generated `MATRIX.tsv` files and the matrix suites' raw logs are not committed.
- [ ] `score3.py` treats a gate that timed out as green. No part-3 gate timed out; the scorer is
  left as it ran and the defect is recorded in the findings note.
- [ ] The raw gate and sweep logs, about 50 MB, are not committed. They are in the spike worktree.
- [ ] Four extension-inventory targets are red on the unmutated tree in the spike worktree. Not
  investigated, and not checked against `main`'s CI.
- [ ] Neither prototype is on this branch as code. They are `prototype.diff` and `prototype2.diff`
  under `evidence/mutation-spike/scripts/`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
