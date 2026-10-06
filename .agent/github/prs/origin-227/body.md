---
repo: arniwesth/motoko_agent
pr: 227
branch: docs/039-systematic-mutation-testing-research
ticket: null
title: "docs(039): systematic mutation testing — a research note, and the thesis that simulation and mutation complete each other"
---

## Summary

Opens project 039 with two documents. The research note asks what *Property-Based Mutation
Testing* (Bartocci et al., ICST 2023) adds to how Motoko mutates its own source, and what it
would take to make that practice systematic. The thesis note records a claim that came out of it:
a deterministic simulation harness and source mutation each supply what the other lacks. The
operator asked for both on 2026-10-06, and said of the second that it "might down the line be
publishable". Nothing is built and no mutant was run.

## Changes

- docs(039): research note — systematic mutation testing
- docs(039): thesis note — deterministic simulation and source mutation complete each other

2 files changed.

## Governing docs

- `.agent/projects/039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md`
- `.agent/projects/039_systematic_mutation_testing/NOTE-dst-and-mutation-testing-as-one-method.md`

What they build on, none of it edited here:

- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md`, §3.3: the kill
  matrix the research note takes over.
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md`:
  every measurement of a source mutant against the driver.
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`: the gate
  `corpus_judge`, which the proposed pilot waits for.
- `.agent/projects/011_improve_test_axises/NOTE-dst-substrate-versus-oracle.md`: the earlier
  finding the thesis note follows, in shape and in subject.
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`: the kill rule,
  and the shared runner it names and does not build.

The DST report draft's citation of the paper is #226.

## Why a new project

- **The subject cuts across projects.** Nine sets of mutation scripts exist: three standing
  tools, five parts of 037, and the 011 spike. The ADR-003 plan specifies a tenth run. They share
  no kill rule, restore step or table format. The discipline names a shared runner and nobody
  owns it.
- **011's mutation thread has narrowed to oracle rules.** ADR-003 and its plan are about what the
  invariant families check, not about how mutants are produced or judged.
- **There is precedent.** 023 and 035 were each opened around one outside source with a research
  note.
- **039 is the next free number.** 038 is taken on a branch.

If it should live in 011 after all, it is a two-file move.

## What the research note says

- **Motoko already uses the paper's kill criterion.** A mutant counts as killed only when the
  check written for the broken rule fails. The 011 spike reproduced the paper's main result
  without setting out to: nine of eleven mutants turn `make dst` red, and the invariant set on the
  corpus flags none.
- **Four things are missing:** mutants nobody chose, a verdict per mutant and per family that
  includes "this family cannot see it", a score, and one runner.
- **The paper's score would mislead if taken literally.** If the property is the checker as
  implemented, a mutant the checker cannot see leaves the denominator, and the spike's main
  finding disappears. The property has to be the rule as a decision document states it.
- **Three more sources change the proposals.** Google reports a few mutants on the lines a change
  touches, at review, and computes no score. Meta has a model write mutants for a stated concern.
  A Trail of Bits post warns that an agent writing a test from a surviving mutant may pin a bug.
- **Three proposals, for a plan to fix:** a pilot of about 30 drawn mutants in the driver's
  recovery code once `corpus_judge` exists; a retrospective coupling check on past fixes, which
  needs no new gate; and, if drawn mutants pay, a few mutants on the changed lines of each core
  change.

## What the thesis note says

It is kept apart from the survey because it is a claim with a novelty argument, and it will
change as evidence arrives. 011's `NOTE-dst-substrate-versus-oracle.md` is the precedent.

- **The claim.** Mutants are the ground truth a simulation harness lacks: for the strength of each
  invariant family, the quality of a generation policy, and the value of each corpus member. And
  determinism gives mutation three measurements where it usually has one: whether the run reached
  the mutated code, whether it differed from the original under the same seed, and whether a rule
  fired.
- **The loop.** Those three measurements give a verdict per mutant, and each verdict feeds a
  different part of the harness: a world for the generator, a candidate corpus member, a rule, or
  a recorded kill.
- **Prior art.** Four web queries found no study combining simulation testing of the FoundationDB
  kind with systematic source mutation. The note says that is absence in a shallow search, and
  marks how each neighbour was read. Most were a search result or a title.
- **What a paper would need.** Seven rows of evidence with today's state, and the objections a
  reviewer would raise first.
- **Where it belongs eventually.** A results section in the DST report, or an experience report
  of its own. Not decided, and nothing is edited into the report.

## Predicted outcome

- **A session planning mutation work has one place to start from.** Checked by the next such plan
  citing the research note for the verdict vocabulary and the cost tiers. 011 §3.3 and 035 §6.5
  do not point here yet.
- **The thesis has a home that is not the report.** Checked by the report's next revision either
  taking a claim from the thesis note or leaving it, with the evidence table saying which rows
  exist by then.
- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` outside
  `.agent/` is empty.
- **Nothing is decided.** Both notes propose. The pilot waits for `corpus_judge`; the coupling
  check does not.

## Test evidence

- [x] **The paper was read from its arXiv TeX source**, sections 2 to 7. Its definitions and its
  results table are quoted from there.
- [x] **The Google study was read from its TeX source**: the system description, the fault
  coupling result (1,043 of 1,502 bugs) and the redundancy result.
- [x] **The Meta paper's abstract, its mutant-table totals and the quoted passages** were read
  from its TeX source.
- [x] **Facts about this repository were checked at `93fb002e`.** `corpus_judge` is named in no
  Makefile, script or workflow. 14 `scripts/dst/*.ail` files mention a mutant. The spike's
  `mutants.tsv` holds the ids the research note lists. 037's `p5`, `p6` and `r3` tables carry a
  column for the check expected to fail. `039` is used by no fetched branch.
- [x] **Every figure in the thesis note is quoted from the spike findings.** The control's
  1,609 identical lines, the three wire-difference counts, `T3`'s three requests against none,
  and nine of eleven by five kinds of check.
- [x] **Every relative link in both notes resolves, and every link label is defined.** A loop over
  the reference definitions, run from the notes' directory.
- [ ] No mutant was run. Every Motoko figure is inherited from the spike findings or the plan.
- [ ] The Meta paper was read only in part, and the Trail of Bits post through a tool that
  summarises. The research note's header says so.
- [ ] The thesis note's prior-art search is four web queries. Etna, the model-checking coverage
  work, *Vacuity in testing* and *State Field Coverage* were not read; its table says how far
  each was.
- [ ] The count of fix commits touching `src/core` (71, of which 22 touch a test or a DST script)
  is a grep. No commit in it was read.
- [ ] Not reviewed by a second session.
- [ ] The discipline's status line says it "has not yet been applied to a part". 037's later
  tables show it has. The line is not edited here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
