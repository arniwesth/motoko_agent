# Thesis: deterministic simulation and source mutation complete each other

Date: 2026-10-06. Status: a thesis, recorded. Partly evidenced by the 011 spike; nothing was run
for this note. Scope: a claim about method, separable from the survey in
[`RESEARCH-systematic-mutation-testing.md`][research], and possibly worth publishing once it has
evidence of its own.

_Written because the research note treats mutation as a practice to tidy up. The stronger reading
is that a deterministic simulation harness and source mutation each supply what the other lacks.
A shallow search found nobody who has written that down._

## The claim

A deterministic simulation (DST) system answers "does the real code survive this world?". It has
no standard answer to "would the checks notice if the code were wrong?". Motoko's own report says
so: reachability is not oracle strength. Source mutation asks exactly that question, and in
ordinary use it is noisy, gives one bit per mutant, and is slow to triage. Put together:

1. **Mutants are the ground truth a simulation harness lacks.** They measure three things it
   cannot otherwise measure: the strength of each invariant family, the quality of a generation
   policy, and the value of each corpus member.
2. **Determinism gives mutation three measurements where it usually has one.** Whether a run
   reached the mutated code, whether its behaviour differed from the original's under the same
   seed, and whether a check fired. Together they sort most survivors without a person reading
   code.

## What simulation gives mutation

- **No noise floor.** Ordinary mutation testing has flaky tests and timeouts to contend with. In
  the [spike][spike], a comment-only edit produced a corpus wire identical to the unmutated one:
  0 of 1,609 lines differ, with `duration_ms` masked.
- **An exact differential.** The same seed gives the original and the mutant the same world, so a
  difference between the two runs is the mutant's doing. The spike measured it as lines of the
  corpus wire that differ from the control's: `M1` 272, `M3` 14, `M4` 0.
- **Properties over traces.** The invariant families judge any run, so a kill can be attributed to
  a family and a rule. This is the property-based kill criterion the research note describes.
- **A generator and a replay.** A survivor can be chased with more seeds, and a kill is a recorded
  program that strict replay reproduces. Neither was used this way in the spike.

## What mutation gives simulation

- **Oracle strength, per family.** The kill matrix of 011 §3.3. Its first column is measured: at
  the driver's own bounds the invariant set on the corpus flags none of eleven mutants.
- **Generator quality.** Which generation policy kills more of a fixed mutant set, for the same
  budget. [035][r035] §6.5 proposes this comparison.
- **Corpus value.** Which members are the only killer of some mutant, and which add nothing. `M1`
  changes one member of sixteen, `seed-19`.
- **A check on the fault catalogue.** Each fault class claims to reach a named recovery branch.
  Mutating that branch asks whether reaching it is also judged.

## The loop

Run each mutant on the corpus with the original's seeds. Three measurements give a verdict, and
each verdict feeds a different part of the harness.

| Reached | Run differs | A rule fires | Verdict | What it produces |
|---|---|---|---|---|
| no | | | world gap | a request to the generator for a world that gets there |
| yes | no | | equivalent on this corpus | more seeds; one that shows a difference is a candidate corpus member |
| yes | yes | no | oracle gap | a ruling, then a rule |
| yes | yes | yes | killed | the member, the rule, and a program to shrink and keep |

Where each measurement comes from today:

- **Reached:** the corpus wire's record of each recovery branch, and probes that panic at a
  handoff.
- **Run differs:** a diff of the mutant's wire against the control's.
- **A rule fires:** the invariant set on each member's execution. The gate that does this on every
  member, `corpus_judge`, is planned and not built.

Promotion to the corpus is by hand today, and shrinking is proposed in 011 ADR-001 and not built.
The last column is what the loop would ask of them.

## Two findings of the spike that belong to the combination

1. **A single-channel oracle is blind to the defect simulation makes most natural.** The
   interaction log the families read is carried in the world. A mutant that drops a world
   successor drops its own evidence. With the approved call's successor dropped (`T3`), the wire
   shows three tool requests, the log records none, and the invariant set reports nothing. What
   catches it is a count held against a second channel.
2. **Where a mutant is caught says more than whether it is.** Nine of eleven mutants were caught,
   by five kinds of check. The invariant families on a real run caught none.

## Prior art, and how thin the search was

Four web queries on 2026-10-06 found no study that combines simulation testing of the
FoundationDB kind with systematic source mutation. That is absence in a shallow search, not a
result. The neighbours, with how each was read:

| Neighbour | What it does | Read how |
|---|---|---|
| Antithesis's agent skills, mutation step | A clean baseline, one realistic defect aimed at one property, check the property fails for the predicted reason. Guidance, not a system or a study | Through [035][r035], which cites it |
| *Property-Based Mutation Testing* (ICST 2023) | The kill criterion, on simulated control models. Its search uses a distance between the original's and the mutant's signals as an objective, not as a way to sort survivors | From source; see the research note |
| [Etna][etna] (ICFP 2023) | A platform for comparing property-based testing tools; mutation testing is among its keywords | Search result only |
| Mutation coverage in model checking | "In vacuity, mutations are in the specifications, whereas in coverage, mutations are in the system" ([abstract][sanity]). The report's vacuity accounting is the first half; mutation is the second | One abstract, through a search result |
| [*Vacuity in testing*][vacuity] | Unknown beyond its title | Title only |
| [*State Field Coverage*][sfc] (2025) | Proposes a metric for oracle quality | Title and a snippet |

The last suggests a cheaper complement. `M3` survived because no rule read the finish reason, and
`M1` because no family read the driver's own step numbers. An inventory of which fields of an
execution the invariant set reads might have named both without running a mutant. Not examined.

## What a paper would need

| Evidence | Today | What it takes |
|---|---|---|
| Mutants nobody chose | None. Every mutant so far was written by hand | The operator tool and the pilot (research note, §8.1) |
| A kill matrix with a verdict per family | One column: none of eleven. And the rows of the spike's part 5, with rules written from those mutants | `corpus_judge`, then the pilot |
| The differential as a classifier: how often "no difference" means equivalent, and "difference, no finding" a real gap | Six survivors' diffs, read by hand. Never used to sort mutants blind | The pilot records it per mutant; a second set of seeds for the survivors |
| Generation policies compared on a fixed mutant set | Proposed | 035's experiment |
| Kill sets per corpus member | One anecdote | A by-product of the pilot, if verdicts are kept per member |
| Coupling to real faults | None | The retrospective check (research note, §8.3) |
| A proper related-work search | Four queries | Reading the neighbours above, and the literature on oracle quality |

What a reviewer would raise first:

- **One system, one profile, one corpus of sixteen.**
- **The rules were written from the mutants.** The spike says so of its own 24-of-24 score.
- **Agents wrote the code, the tests and the mutants.** A blind round by a fresh agent is planned
  (ADR-003 plan, WI-4) and has not happened.
- **Cost.** A compile per mutant, because the driver module does not fit the compile cache.
- **A red baseline.** Four sweep targets fail on unmutated code.

## Where this belongs eventually

Two candidates, not decided:

- **The DST report.** `papers/motoko-dst-report/DRAFT-3.md` §9.2 lists a systematic mutation
  study among what would strengthen it, and §7.5 says each family still needs a sensitive oracle.
  A results section there, once the first three rows of the table above exist.
- **A paper of its own**, an experience report on measuring a simulation oracle by mutation, if
  the differential and the generator comparison hold up.

Nothing is edited into the report here, for the reason the 011 finding note gives: a draft with
its own snapshot discipline takes a claim from whoever owns its next revision, against the
revision's own HEAD.

## What this note does not claim

- **Not that the combination is new.** The search was shallow.
- **Not that the differential sorts correctly.** `M4` differs on no wire line and is not
  equivalent: it changes the returned trace. The differential has to cover every channel an
  oracle could read, and the spike diffed one.
- **Not that the loop exists.** Each measurement was taken by a spike script on a branch that
  never merges.
- **Not a plan.** The research note's §8 has the proposals.

## Related

- [`RESEARCH-systematic-mutation-testing.md`][research]: the sources, what is missing, the cost
  tiers and the proposed pilot.
- [011 spike findings][spike]: every measurement quoted here.
- [011 research note][r011], §3.3: the kill matrix.
- [`NOTE-dst-substrate-versus-oracle.md`][substrate] in 011: the earlier finding that the
  substrate was reusable and the oracle set was the gap. This note is its sequel: a way to
  measure that gap.

[research]: RESEARCH-systematic-mutation-testing.md
[spike]: ../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md
[r011]: ../011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md
[substrate]: ../011_improve_test_axises/NOTE-dst-substrate-versus-oracle.md
[r035]: ../035_antithesis_testing/RESEARCH-antithesis-inspired-testing.md
[etna]: https://icfp23.sigplan.org/details/icfp-2023-papers/30/Etna-An-Evaluation-Platform-for-Property-Based-Testing-Experience-Report-
[sanity]: https://cris.huji.ac.il/en/publications/sanity-checks-in-formal-verification/
[vacuity]: https://cris.huji.ac.il/en/publications/vacuity-in-testing/
[sfc]: https://arxiv.org/html/2510.03071v1
