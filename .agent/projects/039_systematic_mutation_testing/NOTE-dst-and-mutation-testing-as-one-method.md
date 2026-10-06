# Thesis, narrowed: what is left of "simulation and mutation complete each other"

Date: 2026-10-06. Status: revised the same day it was written, after a literature review. The
first version's claim to novelty was wrong. Nothing was run for this note. Scope: what the review
found, what the first version got wrong, what is left, and what a paper would have to measure.

_The first version said a deterministic simulation harness and source mutation each supply what
the other lacks, and that nobody seemed to have written that down. A [review][review] the same day
found the combination published eleven days earlier, and the classification it proposed in
commercial use in hardware verification since 2007. What survives is narrower, and it is a
measurement that can be made._

## What the first version claimed, and what the review found

Every element has a dated precedent. The [review][review] gives the sources and how far each was
read; "found" below means found in about 160 searches through one search engine, with no citation
index.

| Element of the first version | Status | Nearest prior work |
|---|---|---|
| Mutants measure the strength of each invariant | Old | Coverage by mutation in model checking, 1999. Kill matrices over property sets, 2014 to 2016. On a simulation harness: Antithesis, September 2026 |
| Mutants measure a seeded generator | Old | Property-based testing, 2013; a platform since 2023 |
| Mutants measure the value of a corpus member | Old in fuzzing, 2023 | Not found for the seed corpus of a simulator |
| Three measurements per mutant: reached, differed from the unmutated run, a check fired | Old | Hardware functional qualification: a product since 2007, with "differed" defined against "the same test with no fault inserted". Unit tests: 2019 and 2024, by diffing the two runs |
| The measurements sort survivors, and each class goes to a different fix | Old | Hardware routes the classes to tests, observation points and checkers. Antithesis routes survivors to workload, oracle, mutant or property |
| A kill counts only when the intended check fails; the prediction is written first | Old | *Property-Based Mutation Testing*, 2023. The Antithesis skill has both |
| Determinism is what makes it clean | Old for concurrent programs, 1993 | Not argued for a seeded simulation in anything read |
| The subject is an LLM agent loop | Nearest work is one month old | Chronicle, September 2026: source mutants under record-and-replay, not a seeded world |

## What the first version got wrong

Kept on the page, as the DST report keeps its superseded claims.

1. **"A shallow search found nobody who has written that down."** Antithesis published it on
   2026-09-25: source mutants injected into a system under deterministic simulation, each attempt
   labelled "Artificial bug was caught", "Buggy code never ran", "Bug ran, nothing noticed" or "No
   usable result". Hardware verification has sold the same sort since 2007.
2. **The Antithesis skill described as "guidance, not a system or a study".** It is a complete
   workflow with a verdict ladder, and the post reports a campaign on rqlite: 19 mutant injections
   over 46 runs, 11 of 13 safety properties falsified. The description came from one line in
   035's note. The skill was not read until after the first version was committed.
3. **"Oracle gap" as a verdict.** The term is published with another meaning: coverage minus
   mutation score, per code element (2023). This version uses the hardware names below.
4. **"Determinism gives mutation three measurements where it usually has one", presented as an
   observation of ours.** Hardware has had all three since 2007. The unit-test work has them too,
   and pays for nondeterminism with ten reruns of the original.
5. **Etna described as the same idea one level down.** It compares generators on hand-written
   mutants. Its properties are fixed and never scored and it records no coverage, so it cannot say
   which property is weak or why a mutant was missed.
6. **"Equivalent on this corpus" as the name of the middle class.** Hardware practitioners read
   that class first as missing tests. One paper reports up to 30 percent of faults there in the
   worst cases, all counted as covered by code coverage.

## The classification, with credit

The names are hardware verification's. The last column is what Motoko's spike used to measure
each.

| Class | Meaning | The spike's measure |
|---|---|---|
| Non-activated | No run reached the mutated code | The corpus wire's record of each branch; probes that panic at a handoff |
| Non-propagated | Reached, and the run does not differ from the same run without the mutant | A diff of the corpus wire against a comment-only control's |
| Non-detected | The run differs and no check fires | The invariant set on each member's execution |
| Detected | A check fires | The same, with the rule named |

## What is left

A transfer and a measurement, not a method.

1. **Paired execution on a simulation harness for software.** Run the original and the mutant on
   the same seed and compare the whole trace. Not found. Antithesis takes reach and divergence
   from a marker the mutant's author places, and from analysis of the run; the word "seed" occurs
   nowhere in its skill's eight files. Hardware compares at declared observation points, not over
   a whole trace.
2. **The differential measured as a classifier.** How often "reached, no difference" is truly
   equivalent, and how often "difference, no finding" is a real weakness of the checks. No
   published number for a simulation harness. The nearest is for unit tests: coverage change as
   an equivalence signal reached 75 percent precision and 56 percent recall (2013, read as
   abstract and introduction).
3. **Mutants nobody chose, run against such a harness.** Antithesis designs one mutant per
   property and says a sweep "cannot answer *is anything important unasserted?*, because there is
   nothing to mutate for a property nobody wrote". Its post also says simple syntactic mutants
   "mostly lead to run-time panics". A drawn population would answer both with a distribution:
   killed by a panic, killed by the intended invariant, killed by something else, survived. The
   spike's thirteen single-edit mutants all type-checked and ran, but they were chosen by hand.
4. **Kill sets per member of a fixed corpus, and generation policies compared on a fixed mutant
   set.** Old in fuzzing, and reported for driving simulation in a source read only as an
   abstract. Not found for a simulator's seed corpus.
5. **A realistic defect that removes its own evidence.** A dropped world successor carries away
   the interaction log the invariants read, without touching any check. The Antithesis skill
   files a mutant that "hides its own effect" under mutants to redesign. The spike read it as a
   blind spot of an oracle with one channel, and ADR-003 answers it with counts held against a
   second channel. The review did not search for this, so nothing is known about prior work.
6. **Cost.** Re-running a fixed corpus of sixteen seeds took under a minute per mutant in the
   spike. The Antithesis skill budgets a search of about 45 minutes per run, and about five runs
   per property. The price is judging only against that corpus.

The agent loop is a setting for the measurement and not a contribution by itself.

## Threats the review adds

- **The same seed may not be the same world.** A 2013 paper on concurrent mutants says running the
  original's schedules on a mutant "cannot be done", because the mutant may enable or disable
  schedules. A seeded simulator always yields a legal run, but Motoko's world reacts to the
  requests the driver makes, so a mutant that changes the requests changes the draws. `M2` took
  the corpus's retries from 4 to 33. A difference then shows that behaviour changed, and no longer
  where. No source measures how often this happens.
- **A mutant can break determinism.** One 2026 paper reports mutants inducing flakiness in 54
  percent of 28 Python projects (read as an abstract only). The control run needs to be repeated
  for mutants too, at least until a rate is known.
- **Where the comparison is taken decides the classes.** Hardware says the line between
  non-propagated and non-detected is only the declaration of what counts as output. `M4` changes
  no wire line and still changes the returned trace. The differential has to cover every channel
  a check could read, and the spike diffed one.
- **Hand-seeded faults are the least validated kind of injected defect.** One 2005 study found
  operator mutants similar to real faults and hand-seeded ones different (abstract only). The
  retrospective coupling check in the research note matters more for that.
- **A fixed mutant set invites overfitting** once a generator is tuned against it.
- **The complementary check is missing.** Mutating the system asks whether the checks notice a
  defect. Mutating the check asks whether the tests would pass with a weaker one. The second is
  vacuity in the model-checking sense, defined for run-time monitors in 2008, and it applies
  directly to invariants over traces. Neither version of this note covers it.

## What a paper would need

| Evidence | Today | What it takes |
|---|---|---|
| The differential used blind, with its confusion matrix | Six survivors' diffs, read by hand | A drawn population; each mutant classified by the differential first and by a person second |
| How many non-propagated mutants convert on fresh seeds | None | A second set of seeds for that class |
| The kill-reason split for drawn mutants: panic, intended invariant, other check, survived | None | The operator tool and the pilot (research note, §8.1) |
| How often a mutant makes the same seed a different world | One anecdote (`M2`) | A count of draws or requests per run, compared with the control's |
| Kill sets per corpus member | One anecdote (`seed-19`) | A by-product of the pilot, if verdicts are kept per member |
| Generation policies compared on a fixed mutant set | Proposed in 035 §6.5 | 035's experiment |
| Coupling to real faults | None | The retrospective check (research note, §8.3) |
| Rules written before the mutants are seen | The spike's rules were written from its mutants | The blind round the ADR-003 plan asks for (WI-4), and the drawn population |

Three checks come before any public statement of novelty:

- **A citation-index pass** on *Property-Based Mutation Testing*, on the hardware functional
  qualification papers and on the unit-test tools. The review used semantic search only.
- **The Antithesis skill's shell scripts and its hosted platform.** Its eight markdown files were
  read in full; a seed-pinned replay could exist outside them.
- **A full read of every source the review labels a lead.**

## Timing

Antithesis published eleven days before the review. Two small repositories that grade a Raft
simulation harness against planted bugs appeared in the ten weeks before it, and Chronicle is a
September 2026 preprint. The idea is arriving from several directions at once.

## Where this belongs eventually

Two candidates, not decided:

- **The DST report.** `papers/motoko-dst-report/DRAFT-3.md` §9.2 lists a systematic mutation
  study among what would strengthen it. A results section there would credit the classification
  to hardware verification and the pairing with simulation to Antithesis, and report the
  measurement.
- **A short paper of its own**, on the differential as a classifier in a simulation harness, if
  the confusion matrix is worth reporting.

Nothing is edited into the report here.

## What this note does not claim

- **Not that anything in "What is left" is new.** Each item is something the review looked for
  and did not find, or did not look for. Absence in those searches is weak evidence.
- **Not that the differential sorts correctly.** That is the open question.
- **Not that the loop exists.** Each measurement was taken by a spike script on a branch that
  never merges.
- **Not a plan.** The research note's §8 has the proposals.

## Related

- [`RESEARCH-prior-art-dst-and-mutation-testing.md`][review]: the literature review, with the
  sources and how far each was read.
- [`RESEARCH-systematic-mutation-testing.md`][research]: what is missing in Motoko's practice, the
  cost tiers and the proposed pilot.
- [011 spike findings][spike]: every measurement quoted here.
- [`NOTE-dst-substrate-versus-oracle.md`][substrate] in 011: the earlier finding that the
  substrate was reusable and the oracle set was the gap.

[review]: RESEARCH-prior-art-dst-and-mutation-testing.md
[research]: RESEARCH-systematic-mutation-testing.md
[spike]: ../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md
[substrate]: ../011_improve_test_axises/NOTE-dst-substrate-versus-oracle.md
