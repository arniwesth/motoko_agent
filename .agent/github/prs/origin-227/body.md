---
repo: arniwesth/motoko_agent
pr: 227
branch: docs/039-systematic-mutation-testing-research
ticket: null
title: "docs(039): research note — systematic mutation testing, and what property-based mutation testing adds"
---

## Summary

Opens project 039 with one research note. It asks what *Property-Based Mutation Testing*
(Bartocci et al., ICST 2023) adds to how Motoko mutates its own source, and what it would take to
make that practice systematic. The operator asked for the note on 2026-10-06. Putting it in a new
project, and not in 011 or 035, was this session's recommendation; the reasons are below. Nothing
is built and no mutant was run.

## Changes

- docs(039): research note — systematic mutation testing

1 file changed.

## Governing docs

- `.agent/projects/039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md`

What it builds on, none of it edited here:

- `.agent/projects/011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md`, §3.3: the kill
  matrix the note takes over.
- `.agent/projects/011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md`:
  every measurement of a source mutant against the driver.
- `.agent/projects/011_improve_test_axises/PLAN-judge-recoveries-on-real-runs.md`: the gate
  `corpus_judge`, which the proposed pilot waits for.
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

If it should live in 011 after all, it is a one-file move.

## What the note says

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

## Predicted outcome

- **A session planning mutation work has one place to start from.** Checked by the next such plan
  citing this note for the verdict vocabulary and the cost tiers. 011 §3.3 and 035 §6.5 do not
  point here yet.
- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` outside
  `.agent/` is empty.
- **Nothing is decided.** The note proposes. The pilot waits for `corpus_judge`; the coupling
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
  `mutants.tsv` holds the ids the note lists. 037's `p5`, `p6` and `r3` tables carry a column for
  the check expected to fail. `039` is used by no fetched branch.
- [x] **Every relative link in the note resolves, and every link label is defined.** A loop over
  the reference definitions, run from the note's directory.
- [ ] No mutant was run. Every Motoko figure is inherited from the spike findings or the plan.
- [ ] The Meta paper was read only in part, and the Trail of Bits post through a tool that
  summarises. The note's header says so.
- [ ] The count of fix commits touching `src/core` (71, of which 22 touch a test or a DST script)
  is a grep. No commit in it was read.
- [ ] Not reviewed by a second session.
- [ ] The discipline's status line says it "has not yet been applied to a part". 037's later
  tables show it has. The line is not edited here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
