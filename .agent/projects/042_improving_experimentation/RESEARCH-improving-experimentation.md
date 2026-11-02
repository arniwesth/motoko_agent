# Improving Motoko's Method of Experimentation

Date: 2026-11-02

Status: Research direction from a project discussion. Proposes a first experiment; no experiment
was run for this document and no implementation decision is recorded here.

Companion to [Deterministic Simulation Testing as a Path to Verified Recursive
Self-Improvement](../../../design_docs/planned/m-motoko-dst-recursive-self-improvement.md).

## Motivation

The operator still makes many small decisions about technical approaches, often responding with
"I will go with your recommendations." This suggests that some decisions could already belong
to Motoko. The challenge is to make its judgment dependable enough that fewer interruptions do
not become more corrections or a larger review burden later.

One promising direction is for Motoko to take responsibility for technical investigations and
learn from how they unfold. Within an agreed objective and scope, technical uncertainty should
usually trigger an investigation or experiment before it triggers a question to the operator.
The operator supplies objectives, priorities and constraints. Motoko chooses approaches,
gathers evidence, revisits assumptions and explains consequential decisions.

The research ambition is for those investigations to improve the method used by subsequent
investigations. Stronger foundation models, including Astra and Fable, are candidates for doing
this work. Whether they can do it reliably in Motoko is an experimental question.

## Research question

> Can Motoko become better at deciding what evidence to gather next, carry that improvement
> into unfamiliar investigations, and use the improved method to discover further improvements?

A successful repair resolves one defect. A reusable improvement changes how future problems
are investigated: which hypotheses are considered, which experiments are chosen, what gets
measured, or when an unsuccessful approach is abandoned.

The unit of progress is a versioned change to that method with a demonstrated effect on later
investigations. Possible artifacts include:

| Artifact | Example change | Evidence to seek |
|---|---|---|
| Diagnostic procedure | Check whether the failure is observable before generating more inputs | Faster correct diagnoses on unfamiliar failures |
| Experiment-selection policy | Choose the next probe using the unresolved explanations and previous results | More confirmed findings within the same resource budget |
| Measurement tool | Observe a quantity that existing traces omit | Detection of independently confirmed defects previously missed |
| Fault-generation strategy | Explore combinations that expose a recurring weakness | Better detection across withheld implementations or fault families |
| Stopping rule | Stop repeating experiments that no longer distinguish explanations | Lower cost without losing useful findings |

An artifact must be used by the successor. A retrospective that is stored but never changes
behavior does not establish improvement. Changing model weights is not required.

## Proposed starting point: why did the tests miss a defect?

Investigating a faulty implementation that passes an existing suite gives the agent a concrete
problem and several competing explanations. The [systematic mutation-testing
notes](../039_systematic_mutation_testing/NOTE-dst-and-mutation-testing-as-one-method.md)
provide a starting vocabulary:

| Possible explanation | An informative next action |
|---|---|
| The test did not reach the defective code | Measure reachability and construct a path to it |
| The code ran, but the inputs did not expose the defect | Vary the relevant conditions and compare behavior |
| Behavior changed outside the observations available to checks | Add or inspect an observation channel |
| The relevant behavior was observed, but the check did not reject it | Develop a discriminating check and a valid case it must accept |

These are hypotheses to investigate. A surviving mutant does not establish which explanation
applies; it can also be equivalent, invalid, or outside the stated property. An inconclusive
investigation should remain inconclusive.

Consider an illustrative episode. Motoko spends its budget generating more inputs for a
surviving mutant. It eventually discovers that the defect removes part of the execution record,
so the checks cannot observe the failure. It repairs the immediate gap and proposes a reusable
procedure: establish that the observation channel can expose the suspected failure before
expanding input generation.

That procedure is a candidate, not a conclusion. It may help with other observation failures
while wasting time on ordinary input-coverage problems. Evaluation must include both. The
example is motivated by recorded observation-channel concerns in project 039; it is not an
account of an autonomous improvement already demonstrated.

The first pilot should focus on diagnosis and experiment selection. Motoko may construct probes
and candidate checks as outputs of an investigation. The machinery that judges whether those
outputs are correct remains outside the candidate's control during that comparison.

## The first experiment

1. **Establish an incumbent method.** Run the current investigation procedure on a bounded set
   of tasks. Record the hypotheses, experiments, observations, conclusions, unsuccessful paths
   and costs. Each task should have an independently assessable outcome, such as a supported
   diagnosis with a reproducer that distinguishes faulty and valid behavior.
2. **Study the investigations.** Give Motoko the development histories and ask where effort
   failed to resolve uncertainty. It proposes a reusable change and states why that change
   should help, where it might hurt, and what evidence would count against it.
3. **Implement the candidate method.** Motoko owns the technical choices within the declared
   experiment scope. Preserve the incumbent and record exactly what the successor inherits:
   code, instructions, tools, procedures and any supplied memory.
4. **Compare on fresh tasks.** Evaluate incumbent and candidate with the same foundation model,
   comparable resource limits and the same starting task evidence. The candidate cannot read
   withheld answers, planted-fault metadata or future outcomes. Repeat enough trials to assess
   variation in live model behavior.
5. **Continue from the accepted successor.** Let it conduct new investigations and propose a
   further improvement. Retain unsuccessful candidates and plateaus as part of the result.

The incumbent remains an eligible outcome: a generation need not produce an accepted change.
Before running the pilot, specify its budget, acceptance criteria and stopping conditions.
Those values are not chosen by this discussion document.

Where an episode produces both an immediate repair and a reusable method change, compare the
incumbent, the version with only the repair, and the version with both. Keep other inherited
information comparable. This separates the benefit of fixing the known problem from the benefit
of improving how later problems are investigated.

## What would count as improvement?

The primary question is whether the candidate produces more independently confirmed, useful
investigation outcomes within a comparable budget. Report the dimensions separately before
choosing any combined score:

| Dimension | Measurement |
|---|---|
| Useful findings | Correct diagnoses and reproducible defects found, with duplicate findings distinguished |
| Incorrect conclusions | False defect reports, unsupported diagnoses and rejected valid behavior |
| Misses | Known defects left undetected within the allowed budget |
| Investigation cost | Model usage, simulation and tool executions, elapsed time and human adjudication effort |
| Human involvement | Technical interventions and review effort, together with resulting corrections |
| Transfer | Results on unfamiliar implementations, fault families and representative real failures |
| Development cost | Cost of proposing, implementing and evaluating the method change, including rejected candidates |

Fewer questions to the operator are useful only if outcomes and review burden remain acceptable.
More tests, more documents, or a larger number of reported findings do not establish progress.

Measure development cost separately from the cost of using the successor. A costly improvement
may pay off over repeated investigations, but the required number of uses should be visible.
Include regressions and uncertainty rather than reporting only the best successful lineage.

## Keeping the evidence credible

**Separate development from evaluation.** Motoko may inspect development tasks and their
outcomes while improving its method. During acceptance, the task set, grading rules, resource
limits and answer material are controlled outside the candidate. A different model acting as
reviewer is not sufficient independence if it relies on the same unsupported claims.

**Include valid cases.** A procedure that always reports a defect must lose on correct
implementations. Candidate checks need both a faulty case they reject for the intended reason
and valid behavior they accept. Crashes, timeouts and unrelated failures retain their own
outcomes; they do not silently become successful diagnoses.

**Test transfer beyond new seeds.** Additional seeds from the same narrow environment do not
establish generalization. Withhold implementations or fault families where practical, and use
historical real defects with solution leakage controlled. Repeated acceptance feedback can
expose a holdout indirectly, so later generations need fresh evaluation material.

**Keep model changes separate.** Pin and record the foundation model and relevant settings
within each comparison. A later model comparison can test whether a method transfers, but a
model upgrade must not be counted as evidence that the method improved. Simulation determinism
does not make live model reasoning deterministic.

**Respect the limits of replay.** Recorded runs can support diagnosis and comparisons within
their recorded support. If a candidate changes model inputs, requests or tool choices, old
responses cannot establish the quality of the new behavior. Use responsive simulations and
fresh live runs as appropriate. The same seed alone does not guarantee identical stimuli when
changed requests consume randomness differently.

**Version the basis of acceptance.** Retain parent and candidate identities, method artifacts,
task and evaluator versions, configuration, reproduction evidence, comparative results and
known limitations. If the evaluator later proves defective, those records should allow prior
acceptances to be reconsidered.

## From an improved method to recursive improvement

There are three increasingly demanding claims:

1. Motoko creates a reusable investigation method that helps on unseen tasks.
2. The successor is better at discovering useful changes to its own investigation method.
3. That advantage persists through further generations under comparable total budgets.

Success at the first does not establish the second or third. To investigate the second,
compare improvement campaigns starting from the incumbent and the successor, giving both the
same opportunity and budget to propose further method changes. Evaluate their descendants
independently. A higher task score alone does not show a better improvement process.

The longer-term ambition includes improving fault models, generators, checks and the evaluator
itself. Each proposed evaluator replacement would need a separate comparison against evidence
and criteria it cannot rewrite during its own acceptance. The standards can evolve through
explicit transitions; they need not be frozen forever.

The process may compound, plateau or become too expensive. A bounded experiment that establishes
where improvement stops is a useful result.

## Relation to existing work and next questions

This direction connects the [comparative self-evolution
research](../014_comparative_self_evolution/RESEARCH-godel-machine-lineage-for-motoko.md),
the [Dream-RSI analysis](../032_dream_rsi/RESEARCH-dream-rsi-implications.md), and
the [systematic mutation-testing
proposal](../039_systematic_mutation_testing/RESEARCH-systematic-mutation-testing.md).
Their dated observations are background, not a fresh inventory of implemented capabilities.
The [review-loop retrospective](../../meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md)
also supplies a practical constraint: count useful movement and build discriminating probes
before expanding a specification or adding review rounds.

The next design work should settle a small set of experimental questions:

- Which bounded family of investigations has enough valid cases and independently confirmed
  failures for a useful pilot?
- What is the simplest versioned representation of the method that a successor will actually
  use?
- What evidence establishes a correct diagnosis, and how much human adjudication does it need?
- What budget, trial count and acceptance criteria make the comparison informative?
- How will fresh evaluation material and failed candidates be retained across generations?

These questions should be resolved through repository inspection and small feasibility probes
where possible. They do not require the operator to choose every technical mechanism.

The proposed first milestone is: **Motoko discovers a weakness in how it investigates failures,
changes that method, and demonstrates better investigations on problems it had not seen.**
