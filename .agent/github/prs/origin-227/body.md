---
repo: arniwesth/motoko_agent
pr: 227
branch: docs/039-systematic-mutation-testing-research
ticket: null
title: "docs(039): systematic mutation testing — a research note, a literature review, the thesis it narrowed, and a note on publishing"
---

## Summary

Opens project 039 with four documents. The research note asks what *Property-Based Mutation
Testing* (Bartocci et al., ICST 2023) adds to how Motoko mutates its own source, and what it
would take to make that practice systematic. The thesis note recorded a claim that came out of
it: a deterministic simulation harness and source mutation each supply what the other lacks. The
literature review then tested that claim and found it published already, so the thesis note is
rewritten here to say what is left. A fourth note holds everything about publishing it, so that
the other three record what is known. The operator asked for each step on 2026-10-06 and
2026-10-07. Nothing is built and no mutant was run.

## Changes

- docs(039): research note — systematic mutation testing
- docs(039): thesis note — deterministic simulation and source mutation complete each other
- docs(039): literature review — prior art for combining DST with mutation testing
- docs(039): thesis note narrowed after the literature review
- docs(039): publication considerations in their own note

12 files changed.

## Governing docs

- `.agent/projects/039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md`
- `.agent/projects/039_systematic_mutation_testing/RESEARCH-prior-art-dst-and-mutation-testing.md`
- `.agent/projects/039_systematic_mutation_testing/NOTE-dst-and-mutation-testing-as-one-method.md`
- `.agent/projects/039_systematic_mutation_testing/NOTE-paper-considerations.md`
- `.agent/projects/039_systematic_mutation_testing/evidence/literature-review/README.md`, and the
  seven notes files it describes

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

It gets three small edits in the last commit: a pointer to the review, credit to hardware
verification for the stages in its §4.2, and "oracle gap" replaced, since that term is published
with another meaning.

## What the literature review says

- **The thesis is not new in its core.** Every element has a dated precedent.
- **The reach / differs / detected sort is hardware verification's.** A commercial tool has
  sorted injected faults into non-activated, non-propagated, non-detected and detected since
  2007, with "non-propagated" defined against the same test without the fault. Unit-test research
  rebuilt it in 2019 and 2024.
- **Mutants as a yardstick are a decade old**: for property sets, for generators and for corpora.
- **The pairing with simulation testing was published on 2026-09-25**, by Antithesis, as a post
  and an open agent skill. On rqlite it reports 19 mutant injections over 46 runs and 11 of 13
  safety properties falsified.
- **Looked for and not found:** a same-seed, whole-trace comparison of a mutant against the
  unmutated run on a simulation harness for software; a drawn mutant population run against one;
  kill sets per member of a fixed seed corpus; any of it on a seeded simulation of an agent loop.
- **How far to trust it.** About 160 searches through one search engine, no citation index. The
  engine's machine summaries were wrong repeatedly. Every "not found" is weak evidence, and a
  source read only as an abstract or a summary is labelled a lead.
- **It is findings only.** Its section on what a paper must do differently, and the publication
  advice in its conclusion, moved to the paper note in the last commit.

## What the thesis note says now

The first version is the second commit on this branch. It said nobody seemed to have written the
combination down. The last commit rewrites it, under the same filename.

- **Six corrections, kept on the page.** Among them: the novelty claim; the Antithesis skill
  described as "guidance, not a system or a study" from one line of 035's note, before the skill
  was read; and Etna described from a search result as doing something it does not.
- **The classification now carries hardware's names, with credit.**
- **What is left is a transfer and a measurement, not a method.** The same-seed differential on a
  simulation harness, used blind, with its confusion matrix. Mutants nobody chose, with the split
  of how they die. Kill sets per corpus member. And a realistic defect that removes its own
  evidence, which the nearest prior work files under mutants to redesign and the spike read as a
  blind spot of a single-channel oracle.
- **Threats the review adds.** The same seed may not be the same world once a mutant changes the
  driver's requests. A mutant can break determinism. Mutating the checks themselves is missing
  from both versions.
- **Publication material moved out.** The evidence table, the three checks before any public
  statement, timing and the candidate homes are in the paper note.

## What the paper note says

`NOTE-paper-considerations.md` holds every consideration about turning the narrowed thesis into
a paper or a post, so the other three documents record what is known.

- **The claim a paper could make:** a transfer and a measurement, not a method.
- **What to call it:** oracle qualification is recommended, with three alternatives and two names
  to avoid: "oracle gap", which is published with another meaning, and "mutation testing"
  unqualified near DST or fuzzing, where mutation means mutating inputs.
- **Evidence owed:** eight rows, the first being the differential used blind with its confusion
  matrix.
- **What stays distinct, and what a paper must do differently:** the review's section, moved
  verbatim.
- **Objections to expect, where it could go, timing**, and three checks before any public
  statement of novelty: a citation-index pass, the Antithesis skill's scripts and platform, and
  a full read of every source the review marks a lead.

## Predicted outcome

- **A session planning mutation work has one place to start from.** Checked by the next such plan
  citing the research note for the verdict vocabulary and the cost tiers. 011 §3.3 and 035 §6.5
  do not point here yet.
- **Nobody claims the combination as new on the strength of this repository.** Checked by the DST
  report's next revision crediting hardware verification and Antithesis if it reports mutation
  results.
- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` outside
  `.agent/` is empty.
- **Nothing is decided.** The notes propose. The pilot waits for `corpus_judge`; the coupling
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
- [x] **The two sources that overturn the first thesis note were fetched by the committing
  session**: the Antithesis post (title, author, date, outcome names and the rqlite figures) and
  the Chronicle abstract.
- [x] **All eight markdown files of the Antithesis mutation-testing skill were read in full**, at
  commit `1fd8470d`. The word "seed" occurs in none of them. The coordinator's note in the
  evidence folder has the quotes.
- [x] **The report was read in full by the committing session** and amended in six places after
  the skill was read.
- [x] **No search key is in the committed text.** A fixed-string search of the report and the
  notes for the key's value finds nothing.
- [x] **Every relative link in the four documents and the evidence README resolves, and every
  link label is defined.**
- [x] **The review lost nothing but publication advice.** Its section "What stays distinct, and
  what a paper must do differently" is in the paper note word for word, and the conclusion's
  verdict paragraph stays.
- [ ] No mutant was run. Every Motoko figure is inherited from the spike findings or the plan.
- [ ] The six researchers' notes were not read by the committing session. It read each
  researcher's summary and the report written from the notes.
- [ ] Most sources in the review were read as keyword passages, extracts or abstracts. The
  report's table says which.
- [ ] No citation index was used. Who cites the paper, the hardware work or the unit-test tools
  was answered by semantic search and is probably incomplete.
- [ ] The Antithesis skill's shell scripts and its hosted platform were not examined.
- [ ] The count of fix commits touching `src/core` (71, of which 22 touch a test or a DST script)
  is a grep. No commit in it was read.
- [ ] Not reviewed by a second session.
- [ ] The discipline's status line says it "has not yet been applied to a part". 037's later
  tables show it has. The line is not edited here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
