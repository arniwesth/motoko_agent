# Considerations for a paper, or a post, on oracle qualification

Date: 2026-10-07. Status: considerations, nothing decided. Nothing was run for this note.
Scope: everything about turning the narrowed thesis into something public: the claim, the name,
the evidence owed, how to position it against the nearest prior work, the objections to expect,
where it could go, timing, and the checks that come first. The findings themselves stay in
[the thesis note][thesis]; the prior art stays in [the literature review][review].

_Split out on 2026-10-07 so that the thesis note records what is known and this note records
what publishing it would take._

## The claim a paper could make

A transfer and a measurement, not a method. The thesis note's "What is left" has the detail.

- **The transfer.** The sort hardware verification has used since 2007, non-activated /
  non-propagated / non-detected / detected, applied where the stimulus is a seeded simulated
  world running production software, with the difference taken over the whole trace on the same
  seed.
- **The measurement.** How well that differential works as a classifier when used blind: how
  often "reached, no difference" is truly equivalent, and how often "difference, no finding" is a
  real weakness of the checks. The review found no published number for this on a simulation
  harness.

A paper that claims more will be answered with Certitude, the unit-test work and the Antithesis
post.

## What to call it

**Recommended: oracle qualification.** Source mutants used to qualify a harness's invariants,
run inside the deterministic world.

- It names what is measured, not the mechanism. Ordinary mutation testing grades a test suite;
  here the mutants grade the invariant families, the seeded generator and the corpus.
- It echoes the two nearest precedents without claiming them. Hardware calls its version
  "functional qualification", and the Antithesis skill states its purpose as "Validate the
  *oracle*, not the system under test".
- The phrase is already used in the research literature in this sense, for qualifying test
  oracles, and nobody owns it as a product or a competing definition.
- It extends: the not-reached class qualifies the world, so "world qualification" and "corpus
  qualification" follow when the text gets to those.

Alternatives, if the mechanism should be in the name:

| Name | What it stresses | Risk |
|---|---|---|
| Seed-paired mutation testing | The one measurement the review did not find elsewhere: original and mutant on one seed, whole trace compared | Hardware's differential fault simulation is the same idea at declared outputs; say so |
| Harness qualification | Oracle, generator and corpus together | Flatter than "oracle"; readers may hear test fixtures |
| Property-based mutation testing under deterministic simulation | The kill criterion, with its citation | Long, and the paper's authors own the first half |

Two names to avoid:

- **"Oracle gap"** as a verdict. It is published with another meaning: coverage minus mutation
  score, per code element (2023).
- **"Mutation testing" unqualified near "DST" or "fuzzing".** In that world "mutation" means
  mutating inputs. Write "source mutants" or "mutants of the production code" the first time.

The lineage, in one sentence for any public text: hardware has sorted injected faults this way
since 2007, Antithesis published the pairing with simulation in September 2026, and Motoko adds
the paired run on one seed and the measurement of how well that sorts.

## Evidence owed

| Evidence | Today | What it takes |
|---|---|---|
| The differential used blind, with its confusion matrix | Six survivors' diffs, read by hand | A drawn population; each mutant classified by the differential first and by a person second |
| How many non-propagated mutants convert on fresh seeds | None | A second set of seeds for that class |
| The kill-reason split for drawn mutants: panic, intended invariant, other check, survived | None | The operator tool and the pilot ([research note][research], §8.1) |
| How often a mutant makes the same seed a different world | One anecdote (`M2`) | A count of draws or requests per run, compared with the control's |
| Kill sets per corpus member | One anecdote (`seed-19`) | A by-product of the pilot, if verdicts are kept per member |
| Generation policies compared on a fixed mutant set | Proposed in 035 §6.5 | 035's experiment |
| Coupling to real faults | None | The retrospective check ([research note][research], §8.3) |
| Rules written before the mutants are seen | The spike's rules were written from its mutants | The blind round the ADR-003 plan asks for (WI-4), and the drawn population |

The most valuable single number is the first row.

## What stays distinct, and what a paper must do differently

Moved here from the literature review on 2026-10-07, as the review's report writer wrote it. "The thesis" is the first version of the thesis note; "the first-hand check" and "the coordinator" are the session that ran the review.

The defensible residue is a transfer and a measurement, not a method. The transfer: the hardware sort, applied where the stimulus is a seeded simulated world running production software, with the difference taken over the whole canonical trace. The measurement: how well that differential works as a classifier. Neither appears in any source read. A paper that claims more than this will be answered with Certitude, Reneri and the Antithesis post.

**Against Antithesis.** Antithesis owns per-property falsification on a DST platform, the baseline gate, the verdict ladder and the routing of fixes. A contribution has to differ in four ways the first-hand check supports. It must take the middle measurement by paired execution, original and mutant on the same seed with an automatic trace diff, where Antithesis infers divergence from an agent-placed marker and one randomized run. It must use mutants nobody chose, at population scale, and report a distribution of verdicts; Antithesis designs one realistic mutant per property and reports no score. It must answer Antithesis's objection to syntactic mutants with data, by reporting for an operator-generated population what share die by panic, what share by the intended invariant, and what share survive, which is Du et al.'s kill-reason split applied to DST. And it must score things Antithesis leaves unscored: members of a fixed seed corpus and competing generation policies. It should state that the skill's asset scripts and the hosted platform were not examined.

The full read of the skill removes two things from that list and adds two. Writing the prediction before the run, and counting a kill only when the targeted check fails for the predicted reason, are not differences: the skill does both, and its attribution rule is stricter than a single-run harness needs. What it adds: first, the skill's own stated limit, that it mutates only for properties that exist, is the gap a drawn mutant population addresses, and the paper should say so in the skill's words. Second, the thesis's source system has a finding the skill would discard. A dropped world successor carries away the interaction log the invariants read, so the mutant removes its own evidence without touching any check. The skill files that under mutants to redesign; the source system read it as a blind spot of an oracle with one channel, and answered with counts held against a second channel. That reading is a claim a paper can defend with data, and no source here makes it. A third, practical difference follows from the fixed corpus: re-running a fixed corpus of sixteen seeds costs under a minute per mutant in the source system's own measurements, against a search of tens of minutes per run, at the price of judging only against that corpus.

**Against hardware functional qualification.** The classification must be credited to that field and the claim limited to what the field lacks. Two things qualify. Certitude compares at declared observation points, and Brownell says the Non-Propagated / Non-Detected boundary is only that declaration; a whole-trace differential removes the choice, and the paper should show what that changes. And hardware gives no ratio between "missing tests" and "redundant code" for the Non-Propagated class. A paper that reruns its "equivalent on this corpus" survivors on fresh seeds and reports how many convert, against Schuler and Zeller's 75% precision and 56% recall and Görz et al.'s 11 equivalents in 100 stubborn mutants, would supply a number neither community has. The label itself needs a defence, since practitioners read that class as a probable weakness.

**Against the unit-test work on reach, infection, propagation and oracle.** Reneri and Ripples have the three measurements and the survivor classes; what they lack is a single baseline. The contribution is to show the cost difference concretely (one control run and exact equality against ten reruns and exclusion lists) and to defend the differential's soundness against the two threats this literature raises: a mutant that changes the number of random draws or the set of enabled events makes the same seed a different world, and a mutant can break the harness's determinism outright. Both need a guard and a measured rate. The paper must also say where its observation point sits, because Reneri and Ripples separate no-propagation from weak-oracle and the thesis's "differed / check fired" pair collapses them unless the trace compared is exactly what the invariants read. System-level results give it a prediction to test: pseudo-tested code and failed error propagation are both worse at system level than at unit level (both read as abstracts only: [Niedermayr et al. 2016](https://doi.org/10.1145/2896941.2896944); [Jahangirova et al., Exa copy](https://exa.ai/library/publication/wb15tdl7jdw)), so a DST harness should show a large reached-but-unchecked class.

**Against the two Raft repositories.** They establish that grading DST oracles with planted defects is in the air, on weak provenance. A paper differs by scale and by independence: operator-generated mutants in production code, not eight to twelve hand-planted defects; rules written before the mutants are seen, since the thesis's system so far has hand-written mutants and rules written from them, the same weakness Chronicle admits; a fixed corpus scored per member; and the reach and difference measurements neither repository takes. Hand-seeded faults are the least validated category of injected defect: Andrews et al. found operator mutants similar to real faults and hand-seeded ones different ([Andrews et al. 2005](https://dl.acm.org/doi/10.1145/1062455.1062530), abstract only), so a coupling check against real past faults of the system matters more here than usual.

Four further points from the notes belong in any write-up. The complementary check is missing from the thesis: vacuity mutates the oracle, not the system, and Ball and Kupferman's definition for run-time monitors ("a test suite passes vacuously if it passes also with a monitor with fewer transitions") applies directly to invariants over traces ([Ball and Kupferman 2008](https://www.cs.huji.ac.il/~ornak/publications/tap08.pdf)). An LLM used to judge equivalence for the "reached, no difference" class is unvalidated on a new codebase: a 2026 replication found LLM equivalence detectors degrade on additional datasets and names data leakage as a key factor ([Tandon et al. 2026](https://dl.acm.org/doi/10.1145/3832250), abstract only). Closing an oracle gap by asserting the observed value repeats a known failure of generated oracles, which "capture the actual program behaviour rather than the expected one" (abstract only) ([Konstantinou et al. 2024, Exa copy](https://exa.ai/library/publication/z13kg7gl8qz)). And a fixed mutant set used to tune a generator invites the overfitting that fuzzing benchmarks warn about.

## Objections to expect

- **One system, one profile, one corpus of sixteen.**
- **The rules were written from the mutants.** The spike says so of its own 24-of-24 score, and
  Chronicle admits the same of its incidents.
- **Agents wrote the code, the tests and the mutants.** A blind round is planned and has not
  happened.
- **Cost.** A compile per mutant, because the driver module does not fit the compile cache.
- **A red baseline.** Four sweep targets fail on unmutated code at the plan's baseline.
- **Hand-seeded faults are the least validated kind of injected defect**, so the coupling check
  matters more than usual.
- **Overfitting** once a generator is tuned against a fixed mutant set.

## Where it could go

Three candidates, not decided:

- **The DST report.** `papers/motoko-dst-report/DRAFT-3.md` §9.2 lists a systematic mutation
  study among what would strengthen it. A results section there would credit the classification
  to hardware verification and the pairing with simulation to Antithesis, and report the
  measurement.
- **A short paper of its own**, on the differential as a classifier in a simulation harness, if
  the confusion matrix is worth reporting. The natural venue is a testing venue's workshop on
  mutation analysis or an experience-report track; this is a judgement, not something the review
  established.
- **A post on Motoko**, which needs the name and the lineage sentence above and none of the
  evidence table, as long as it claims no more than the thesis note does.

Nothing is edited into the report from here.

## Timing

Antithesis published eleven days before the review. Two small repositories that grade a Raft
simulation harness against planted bugs appeared in the ten weeks before it, and Chronicle is a
September 2026 preprint. The idea is arriving from several directions at once, and the window in
which a seed-paired differential on a simulation harness is unpublished may be short.

## Before any public statement of novelty

Three checks, all cheap and all outstanding:

- **A citation-index pass** on *Property-Based Mutation Testing*, on the hardware functional
  qualification papers and on the unit-test tools. The review used semantic search only.
- **The Antithesis skill's shell scripts and its hosted platform.** Its eight markdown files were
  read in full; a seed-pinned replay could exist outside them.
- **A full read of every source the review labels a lead.**

## What this note does not decide

- Whether to publish at all, or in which of the three places.
- The name, beyond a recommendation.
- Any of the evidence rows. Each needs the pilot or an experiment the research note proposes.

## Related

- [`NOTE-dst-and-mutation-testing-as-one-method.md`][thesis]: the narrowed thesis, with what the
  first version got wrong and the threats the review adds.
- [`RESEARCH-prior-art-dst-and-mutation-testing.md`][review]: the literature review.
- [`RESEARCH-systematic-mutation-testing.md`][research]: the pilot and the coupling check.

[thesis]: NOTE-dst-and-mutation-testing-as-one-method.md
[review]: RESEARCH-prior-art-dst-and-mutation-testing.md
[research]: RESEARCH-systematic-mutation-testing.md
