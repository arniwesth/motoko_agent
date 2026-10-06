---
repo: arniwesth/motoko_agent
pr: 223
branch: docs/011-adr-003-judge-recoveries-on-real-runs
ticket: null
title: "docs(011): ADR-003 (accepted) — judge wrong recoveries on real runs, with the mutation spike behind it"
---

## Summary

Adds ADR-003 to project 011, accepted by the operator on 2026-10-06: how DST should judge a wrong
recovery on a real run. It
comes out of the operator-feasibility spike `RESEARCH-test-axes-beyond-dst.md` §3.3 asked for, which
found two single-edit driver defects that pass the whole of `make dst` and showed that the
invariant set does not see them even when it is evaluated over the corpus. The spike's plan, its
findings note and its evidence are added with it, because the ADR's numbers are theirs.

Documents only. No source, gate or `Makefile` change.

## Changes

- docs(011): the mutation operator-feasibility spike — plan, findings and evidence
- docs(011): ADR-003 (proposed) — how DST should judge a wrong recovery on a real run
- docs(011): ADR-003 accepted — the operator's six rulings of 2026-10-06

47 files changed.

## Governing docs

- `.agent/projects/011_improve_test_axises/ADR-003-judge-recoveries-on-real-runs.md`
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md`
- `.agent/projects/011_improve_test_axises/PLAN-spike-mutation-operator-feasibility.md`
- `.agent/projects/011_improve_test_axises/evidence/mutation-spike/README.md`

The ADR sits under `.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`
D7 and does not reopen it (ADR-003 D8). It applies
`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md` as its acceptance (D6).

## Predicted outcome

- **Nothing a session does changes.** Checked: `git diff --name-only origin/main HEAD` outside
  `.agent/` is empty.
- **ADR-003 is on record as Accepted.** Its *Rulings* section holds the operator's six rulings of
  2026-10-06, given in conversation after a recommendation for each decision. Nothing is
  implemented, and six items of its *Not decided* list stay open.
- **The first part that implements it hands in a `mutants.tsv`.** ADR-003 D6 names six one-edit
  mutants that must each turn its rule red, and the controls that must stay green. Checked by
  reading that part's evidence.
- **§3.3's planning figure stops being used.** The findings note measures a full sweep at 50
  minutes cold and about 31 warm against the 196 seconds §3.3 budgets. The research note itself is
  not edited here.

## Test evidence

The measurements are the spike's, run 2026-10-05/06 in a throwaway worktree at `259265b5` on
AILANG v0.47.2. They are in the findings note; the tables are in
`evidence/mutation-spike/results/`. In short:

- [x] **Part 1, 13 rows and 7 full sweeps.** Controls as required: a comment-only edit leaves the
  corpus wire identical to the unmutated run (0 of 1,609 lines differ); the demo's mutant is killed
  by the named rule. Of 11 mutants, 9 turn `make dst` red and 2 do not. `FINAL INTEGRITY: PASS`.
- [x] **Part 2, 14 rows.** `evaluate()` over all 16 corpus members: clean on the unmutated tree,
  clean under all 11 mutants at the driver's own bounds, red under a known-bad control.
- [x] **Part 3, 7 rows.** Three tool handoffs, each with a reach probe. Two mutants killed; the
  handoff at `session.ail:3694` is reached by no gate.
- [x] **Part 4, 18 rows.** A prototype of D2–D5: both survivors red, no control red; with it applied
  to the unmutated tree `make invariants` and `make stream_parity` pass and the module's 9 inline
  tests pass. 18 of 18 outcomes predicted in advance.
- [x] **Each scorer was run on planted cases before it saw a result**: 15/15, 9/9, 11/11.
- [x] **`mutants.tsv` is generated**, by `evidence/mutation-spike/scripts/make_table.py` from the
  run output.
- [x] **Every source line the ADR cites was re-observed at `259265b5`**; one was off by a line and
  was corrected before commit.
- [x] **Both proposed rules were checked against the unmutated sweep's wire output**: of 100 run
  summaries, `stop` never carries an error and every other reason does, and no run repeats a
  driver step.

Not done:

- [ ] No gate was run on this branch. It changes documents only.
- [ ] No second reader has reviewed the ADR, the plan or the findings note.
- [ ] The raw gate and sweep logs, about 50 MB, are not committed. They are in the spike worktree.
- [ ] Four extension-inventory targets are red on the unmutated tree in the spike worktree. Not
  investigated, and not checked against `main`'s CI.
- [ ] The prototype is not on this branch as code. It is `evidence/mutation-spike/scripts/prototype.diff`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
