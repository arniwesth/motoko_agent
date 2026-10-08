# RESEARCH: Antithesis-inspired testing with Motoko's own harness

Date: 2026-10-02
Updated: 2026-10-03, in response to [Claude Fable 5.1's review][review]; individual dispositions are recorded there.
Status: Reviewed research; proposed experiments, no architecture decision or implementation yet.
Initially grounded at: Motoko HEAD `4023bf0896a09cd556e5711e9972346f3fe09ce2`, with source inspection of the working tree. Review-related source anchors rechecked at `21ba95c9f3d04bdb03846036a34269918922e979` on 2026-10-03; this was not a fresh full-system survey.
External source: [antithesishq/antithesis-skills][upstream], pinned at `1fd8470d36a9629a75bda4619a5589d679a40d7c`.
Constraint: adopt useful testing methods without Antithesis's software, SDK, CLI, hosted service, or account.
Evidence level: source review. No test suite, seed sweep, mutation campaign, or comparative benchmark was run for this note.

## 1. Research question and initial conclusion

Which practices in Antithesis's agent skills could improve how Motoko designs,
explores, and evaluates tests using its existing tooling?

The strongest initial candidate is **variation in the generator's policy between
runs**. Motoko already draws different outcomes from different seeds, but several
choice probabilities remain fixed. A generator that sometimes favors sustained
successful work and sometimes favors repeated recovery could explore a different
distribution of session states within the same compute budget. Whether that
improves coverage or defect detection is an experiment, not an established result.

Three supporting practices are also useful: connect each property to its evidence;
measure whether a deliberate defect triggers its intended assertion; and develop
generated workloads around one stateful feature at a time. Much of this already
exists in Motoko. The work is to connect and extend those mechanisms while keeping
their current distinctions between reproduction, reachability, and correctness.

This project studies the workflow expressed in the external skills. It does not
invoke or install them. Their setup, launch, SDK instrumentation, and hosted
debugging steps are outside this project's scope. Native assertions, the existing
world and replay machinery, local processes, and CI can support the proposed work.

## 2. Relationship to existing Motoko research

The ideas have substantial overlap with earlier work. These documents provide
context and constraints; their historical status and measurements need checking
before implementation.

| Existing work | Relationship to this project |
| --- | --- |
| [009: deterministic test-world architecture][p009] | Governs modeled faults, profile boundaries, discovery/replay, versioning, and retained reproduction artifacts. |
| [011: test axes beyond DST][p011] | Already inventories mutation evidence and proposes a production-mutation matrix with surviving controls. This project applies that design to a comparison of generation policies and adds property-level evidence fields. Its [ddmin shrinking design][p011-shrinking] remains proposed and unimplemented in the inspected core/scripts. |
| [013: FoundationDB simulation cross-check][p013-fdb] | Already proposes configuration randomization, separate workload/fault dimensions, lifecycle testing, and better search economics. Per-run action probabilities complement its configuration-knob proposals. |
| [013: journal architecture][p013-journal] | Defines the session and resume contracts that a lifecycle workload must actually test. |
| [031: ABI-8 implementation plan][p031] | Contains proposed program-format changes that must be reconciled before assigning a schema version. |
| [032: Dream-RSI research][p032] | Discusses evaluating exploration policies and the limitations of scoring them against previously recorded histories. A generator comparison here requires fresh discovery. |
| [034: ambiguous tool outcomes, proposed ADR][p034] | Proposes world-only effects and fault disclosures, and conditionally batches generator changes with the earlier knob widening. It is a proposal in the current working tree, not shipped behavior. |

In particular, configuration widening is not a new discovery of project 035.
The incremental contribution here is a bounded comparison of generation strategies,
paired with explicit evidence about what was reached and which bugs were detected.
Any implementation should reconcile its scope and version changes with projects
013, 031, and 034 rather than assigning a future schema version in advance.

## 3. What transfers from the external repository

The four source areas below were inspected at the pinned upstream revision.
Their methods can be expressed independently of their Antithesis integration.

| Source | Transferable practice | Motoko adaptation to investigate |
| --- | --- | --- |
| [Research property catalog][up-properties] | State concrete properties with source evidence, assumptions, priorities, and open questions. | Link existing invariant and fault identifiers to scenario, observation, and falsification evidence. |
| [Input-generation review][up-inputs] | Review whether fixed action distributions, narrow data domains, or fixed initial conditions restrict exploration; vary the policy between runs. | Audit `dst_generator.ail`, then compare its current distribution with a versioned distribution that selects probabilities per run. |
| [Mutation testing][up-mutations] | Establish a clean baseline, introduce a realistic defect aimed at one property, and inspect whether that property fails for the predicted reason. | Extend existing mutation practice into an explicit property-by-mutant evidence table using isolated checkouts. |
| [Feature workloads][up-feature] | Build a focused workload with feature properties and checks that important behaviors are reached; iterate on missing reach. | Extend one existing fixture family into a generated workload, starting with park/wake/resume if its seams are sufficient. |

The skills are procedural guidance, not evidence that a particular generation
strategy will improve Motoko. Their assertion names also need no local imitation:
Motoko can express safety checks, bounded progress, and reach observations using
its current types and runners.

## 4. Current implementation: useful starting points

These are observations about checked-in code, not fresh passing results.

| Mechanism | Source anchor | Implication |
| --- | --- | --- |
| Explicit seeded generator state, bounded draws, seed-sensitivity checks, version canaries | [dst_generator.ail][generator]: `GeneratorState`, `check_seed_sensitivity`, `check_canary` | New exploration settings must remain explicit, reproducible, and versioned. |
| Recorded execution programs and strict/regression replay | [dst_program.ail][program], [dst_replay.ail][replay] | Preserve resolved interactions; a seed alone depends on the generator retaining its meaning. |
| Thirteen single-execution invariant families and a separate determinism relation | [dst_invariants.ail][invariants]: `evaluate`, `family_evidence`, `discovery_contract_findings` | Existing checkers can evaluate the experiment. Adding a second global assertion framework would duplicate them. |
| Fault-class and recovery-branch reach observations | [dst_run_report.ail][report]: `ReachStatus`, `ClassCoverage`, `BranchCoverage` | Reports already distinguish reached behavior, gaps, and waivers. |
| Fixed PR corpus and scheduled rotating corpus | [dst_corpus.ail][corpus], [CI workflow][ci] | Run an exploratory comparison separately before changing the blocking bank or scheduled policy. |
| Mutation checks for guard contracts | [verify_contract_mutations.sh][contract-mutations] | The project already checks assertion sensitivity. This script mutates files in place and therefore belongs in an isolated checkout during a campaign. |
| Park/wake/resume fixtures and wire checks | [park_resume_dst.ail][park-resume], [run_park_resume.sh][park-wire] | Existing examples supply lifecycle contracts and control cases for a generated extension. |
| Host journal tests | [session-journal.test.ts][host-journal] | Host-written bytes and process recovery require evidence beyond a synthetic core journal. |

### 4.1 Concrete generator findings

In `choose_provider`, the current implementation draws:

- a termination choice with a fixed denominator of four;
- a tool from `T`, `BashExec`, and `Read`;
- one retryable and one non-retryable provider-fault outcome from a twelve-way draw;
- malformed arguments from one outcome of an eight-way draw;
- token counts and argument values from fixed numeric ranges.

These are choice rules, not measured frequencies of completed runs: production
control flow, budgets, and earlier faults affect what is ultimately observed.

`choose_tool` uses five successful outcomes and one each for failure, correlation
mismatch, and lateness in an eight-way draw. Its late duration is derived from the
requested timeout. `choose_environment` already draws a tool timeout, and
`GeneratorBounds` already separates some generation ranges from hard limits.
Consequently, a claim that Motoko has no variable configuration would be wrong.

**Hypothesis H1:** changing the distribution of these choices between runs can
increase useful state exploration. For example, frequent early termination can
reduce opportunities to accumulate history; a run that sustains successful tool
work may reach states that a recovery-heavy run does not. Conversely, prolonged
recovery pressure may expose a different class of bookkeeping errors.

**Hypothesis H2:** additional seeds cannot reach values outside a generator's
domain. The three-tool menu and compact payload construction are concrete bounds
on this generator. That does not establish that the corresponding behavior is
untested elsewhere: dedicated scripts and extension profiles must be inventoried
before describing a repository-wide gap.

### 4.2 Reachability is already represented, but its granularity matters

`ReachStatus` names five states: `Reached`, `UnreachableStructurally`,
`UnreachableUntilChange`, `CoveredNotExercised`, and `Waived`. Preserve these
distinctions. A structurally absent production branch requires implementation or
a revised property; a larger seed window cannot create it.

`family_evidence` records family-level evaluation and input counts. Some families
use total trace or interaction counts, so those numbers alone do not establish
that a specific property precondition occurred. The proposed extension is to link
important properties to concrete observations such as a second resume consuming
a newly issued wake, or a retry following a retryable provider error.

For bounded progress, record the premise and bound: recovery or a named terminal
outcome within a declared number of decisions. Reaching a success case somewhere
in the corpus does not establish that every eligible run makes progress.

### 4.3 Assertion sensitivity has several different test subjects

Keep separate evidence for mutations of a checker, a generator, a replay adapter,
and the production driver. A malformed trace rejected by an invariant proves
something useful about the checker. A production mutation detected after a real
driver run establishes a different connection between execution and observation.

The current contract-mutation script establishes another connection: a changed
predicate is rejected by its contract. There is already an inventory and concrete
production-mutation evidence to build on:

- [Project 011, baseline table and section 3.3][p011], inventories inline mutant
  rows in about 19 DST gates, the coverage-deriver mutations, and a recorded
  147-site literal-mutation loop. These are historical inventory counts. It also
  proposes the production-mutation matrix and requires surviving controls.
- [Project 009's D23 results, section 4][p009-d23], records three exit-code
  propagation mutants, the specific rows that detected them, byte-identical
  restoration, and a return to green. These are prior reported results, not runs
  repeated for this research note.
- `choose_provider` in [dst_generator.ail][generator] documents a seed-sensitivity
  defect exposed by generator mutation: embedding the seed in a payload made
  output differences look like evidence of different choices.
- [verify_contract_mutations.sh][contract-mutations] already removes
  `&& remaining_step_budget > 1` from `should_retry_stream_error` and requires a
  contract violation. This existing mutation can anchor the execution-level
  extension described below.

The remaining work is to revalidate relevant evidence at the experiment revision
and connect it to the selected properties and runners. Project 011 reports a
196-second full sweep at `-j8` and estimates about 5.5 hours for 100 mutants; those
historical figures motivate limiting scope, but current costs must be measured
before setting the experiment budget.

## 5. Proposed evidence structure

Start with a small property catalog for the experiment. Reuse canonical rule and
fault identifiers wherever they exist. Keep design rationale in Markdown and
execution facts in runner output; avoid a manually maintained second source of
coverage counts.

Each property should connect these fields:

| Field | Question it answers |
| --- | --- |
| Contract and scope | What must hold, under which profile, premises, and bounds? |
| Production and observation sites | Where does the behavior happen, and which independently observable facts check it? |
| Reach condition | What proves the relevant state was actually encountered? |
| Verdict | Did the check pass, fail, or remain unevaluated? |
| Falsification | Which deliberate defect should violate it, and what finding is expected? |
| Control | Which valid behavior must continue to pass? |
| Reproduction | Which revision, toolchain, profile, initial inputs, program bytes, and run artifacts support the result? |
| Open questions | Which assumptions or missing observations still limit the claim? |

Reach, verdict, and falsification should remain separate fields. A passing check
with no relevant input supplies no assertion-sensitivity result. A valid mutation
that was never exercised supplies no evidence that the assertion is weak.

Candidate property rows, grounded in existing behavior, include:

| Property to document precisely | Deliberate defect to investigate | Necessary control |
| --- | --- | --- |
| A request's returned world successor is carried into subsequent execution. | Retain the predecessor at one production handoff. | A sequence that legitimately leaves unrelated state unchanged. |
| A tool result is associated with the correct call. | Replace one correlation identity at a selected boundary. | Successful, denied, and failed calls with valid identities. |
| Provider retries respect their declared bound. | Reuse the existing `should_retry_stream_error` contract mutation and investigate detection during driver execution by `BoundedProgress`. | The unmutated driver and a valid retry within budget; the existing contract mutation is a separate sensitivity reference. |
| A consumed wake is not offered again by a later resume. | Re-seed the consumed wake when planning a second resume. | A genuinely new wake for a later park. |

The retry edit already exists at the contract level; its execution-level detection
is unmeasured here. `bounded_progress_findings` is the intended family to investigate,
but its decision/retry limits and repeated-step checks must be shown to detect
that exact mutation under the selected runner. A contract failure alone does not
establish that connection. The other rows remain candidate mutations.
Before crediting a result, identify the exact checker and observation that make
the property falsifiable. Where no independent observation exists, report that
as an evidence gap instead of inferring success from replay agreement alone.

## 6. First experiment: compare generation policies

### 6.1 Scope and prerequisites

Use one current generated-driver profile, initially `driver_only`, and retain
the same production revision and invariant set across the two arms. First map
which configuration values, initial inputs, and generation choices that runner
actually consumes. Do not infer coverage from a field merely existing in a type.

Record the existing seed bank, rotation behavior, target bounds, and observed
execution costs. `scheduled_rotation()` currently specifies seeds 1–1024 and a
240-seed window. That finite rotation is an implementation fact, not evidence
that scheduled CI has completed any window. The workflow contains a historical
comment saying it had not run; its current execution history has not been checked.
Produce the baseline locally at the pinned experiment revision. If CI artifacts
are used instead, first identify a completed run, its revision, full seed window,
and retained outputs.

**Proposed experiment seed space:** use explicit finite windows independent of
the scheduled rotation: tuning seeds 10,001–10,960 and evaluation seeds
20,001–20,960, each partitioned into four consecutive 240-seed windows. Use the
same numeric windows for both arms. This proposes 960 tuning and 960 evaluation
seeds per arm before any mutation runs. The window size is provisional until
feasibility measurements establish its cost. If those measurements require smaller
windows, revise and freeze both partitions before inspecting comparative results.
Disjoint seed ranges are sampling partitions, not a proof of statistical independence.

The experiment plan must also enumerate the supported policy configurations and
their selection probabilities before execution. With `K` supported configurations,
a 240-seed window can realize at most `min(240, K)` distinct policies, and each
960-seed partition at most `min(960, K)`. Measure the actual number, frequencies,
and unobserved configurations; distinct seeds can select the same policy. Cycling
through every selected seed is not exhaustive coverage of the policy or state space.

This addresses [013's sections 3.1 and 3.5][p013-fdb]: the search-space and
failure-triage questions precede adopting broader knob randomization in scheduled
CI. The isolated comparison investigates feasibility; it does not resolve that
adoption question by increasing the seed count alone.

### 6.2 Comparison arms

**A — current policy.** Use the current generator and its existing distributions.

**B — per-run policy.** Derive an explicit configuration once from the seeded
world, then draw outcomes under that configuration. Candidate settings are the
termination weight, provider-fault mix, malformed-argument rate, and tool-outcome
weights. Vary a small subset first so the result remains interpretable.

Both arms keep finite production budgets and generator bounds. A reduced early
termination rate must not turn ordinary runs into generator-bound failures.
Count such failures separately and diagnose them; do not relax a hygiene check
to make the experimental arm appear productive.

A later experiment can vary initial history, token sizes, tool subsets, and
ordinary runtime configuration. Adding all of them in the first comparison would
make it difficult to identify which change contributed any improvement.

### 6.3 Reproduction and compatibility

The experimental policy is part of generator identity and state. Any change
that remaps seeds needs the generator-version treatment required by the current
architecture. Keep baseline canaries and retained programs meaningful; do not
overwrite their expectations as if the new generator were unchanged.

Distinguish regenerating choices from replaying a retained execution. Given the
same generator implementation, id/version, seed, initial inputs, and deterministic
request sequence, policy settings drawn from that stream can be regenerated.
The id/version/seed triple initializes the stream; it is not the complete set of
inputs to an arbitrary generated execution. A second copy of the policy settings
is useful for audit and comparison, not an additional source of randomness.

Record the realized settings in the experiment report, linked to its resolved
execution program and exact initial inputs. If they need to enter the program
format, make an explicit compatibility decision rather than assume a schema
change is necessary. `GeneratorBounds` is serialized positionally today;
[dst_persistence.ail][persistence]'s `version_has_chunk_draw_hi`, `bounds_arity_at`,
and `chunk_draw_hi_before_v3` show the precedent: append the field, decode by
version, and preserve the older versions' meaning. Retained program bytes and
interpretation metadata remain required for durable replay across generator changes.

Strict replay consumes the recorded outcomes and must remain independent of
generation. A matching numeric seed across arms is a bookkeeping correspondence,
not a claim that the two arms will encounter the same requests or consume equal
numbers of draws.

### 6.4 Measurements and decision rule

Compare both equal completed-run counts and equal wall-clock budgets, reporting
actual work in each case. Include warm-up and setup treatment so longer runs or
different compilation costs do not silently decide the result.

| Measure | Purpose |
| --- | --- |
| Completed runs, interactions, elapsed time, and execution-depth distribution | Expose the cost and amount of work behind any coverage gain. |
| Realized policy configurations, frequencies, and unsupported or unobserved regions | Show what the finite seed windows actually sample; separate seed completion from policy coverage. |
| Fault classes and recovery branches reached | Use existing reporting to measure concrete behavior. |
| Property preconditions reached and checks evaluated | Separate useful exercise from vacuous success. |
| Selected transition combinations | Detect interactions missed by aggregate branch counts; define these combinations before the comparison. |
| Intended properties triggered by valid production mutants | Measure defect detection with a fixed mutation set. |
| Harness failures, replay mismatches, and false alarms on controls | Account for the experiment's own failures. |
| Reproduction and investigation effort for each finding | Assess whether additional exploration is operationally usable. |

Choose tuning windows and reserve separate evaluation windows before inspecting
results. Keep the property definitions, controls, and mutation set fixed during
the comparison. Report per-property outcomes and variability across windows;
one favorable seed or a count of distinct trace hashes is insufficient.

The experiment supports adoption if it provides reproducible gains in previously
unreached behavior or intended mutation detections at an acceptable measured cost,
while controls and replay checks remain valid. Set the actual budget and coverage
criteria in the experiment plan before running it. An inconclusive or negative
result is a useful outcome and leaves the current CI policy as the baseline.

### 6.5 Mutation verdicts

Apply [project 011's section 3.3 mutation-matrix design][p011] to the selected
properties, using its surviving controls and the existing evidence in section 4.3.
The extension here is to compare both generation policies against the same fixed
mutants and record property premises, observation boundaries, and detection reasons.
Revalidate old mutation sites and measure the chosen runner's current cost before
using them; neither historical line numbers nor the 196-second sweep are current
execution evidence.

Use a clean baseline for the exact revision under test and one mutation per
isolated checkout. Record the target property and predicted observation before
execution. Revert the mutation and rerun the reproducer as a control.

Distinguish: intended detection; detection only by another property; mutation not
exercised; invalid or behaviorally ineffective mutation; observed violation missed
by the checker; and a property whose assumptions need revision. Compilation
failure, an unrelated timeout, or a replay refusal before the target state is
reached does not establish the intended property's sensitivity.

If a mutation changes the driver's request sequence, use fresh discovery or an
explicitly compatible replay mode. Record why the selected mode is appropriate;
do not treat an incompatible baseline recording as an assertion failure.

## 7. Follow-on workload: park/wake/resume

The existing `park_resume_dst.ail` scenarios already cover journal cuts after
park and wake, aborted and mismatched replies, and multiple resumes. Extend this
family by selecting cut positions, repeated lifecycle transitions, and valid
initial states within a declared bound. Start from these known scenarios so the
first generated workload has established controls.

Candidate obligations are that a consumed wake is offered once, a later wake
remains usable, stale identities do not attach to the wrong park, and the folded
history and counters agree with the corresponding resumed execution. Each needs
an explicit reach condition and a stated comparison boundary.

Use distinct evidence for three layers:

| Layer | What it can establish |
| --- | --- |
| Synthetic journal cuts and core resume runs | Fold/refusal behavior and resumed-driver behavior for the modeled journal inputs. |
| Real host writer and child-process interruption | Behavior of actual written bytes and the host/child recovery protocol at controlled interruption points. |
| Filesystem durability and power-loss behavior | Requires a defined durability contract and an appropriate storage fault model; a synthetic cut or process kill alone is insufficient. |

The current `JournalFold` invariant constructs journal lines from trace records
using the AILANG writer twin. That is a useful core consistency check, but it does
not by itself execute the TypeScript writer. Host tests must supply that evidence.

Do not represent an interrupted execution as an ordinary completed execution and
then weaken the terminal-summary invariant to accept it. Define the lifecycle
boundary and the obligations for its interrupted and resumed segments explicitly,
reconciling any new fault semantics with the existing architectural decisions.

## 8. Limits and open questions

- **Simulation scope:** explicit ports and logical time cover the environment
  they model. They do not provide whole-machine deterministic scheduling,
  arbitrary host fault injection, or automatic exploration of callback races.
- **Model quality:** generated model replies test harness handling. They do not
  measure whether a live model chooses good tools or completes a user task.
- **Correlated oracles:** matching records can share a defective projection.
  Reuse existing independent wire witnesses and add independent observations
  where the proposed property requires them.
- **Catalog maintenance:** should the per-property evidence table be derived
  from source identifiers, maintained as a small manifest, or assembled by the
  runner? Prototype the smallest useful form before adding another schema.
- **Generation structure:** should workload choices and fault choices have
  independent seeded streams, as project 013 suggests? That would aid controlled
  comparisons but changes draw semantics and needs its own evidence.
- **Coverage scope:** which profiles and dedicated scripts already cover the
  generator's narrow domains? Complete that inventory before claiming omissions.
- **Mutation practicality:** which candidate production mutations compile,
  preserve meaningful execution, and actually violate the named contract?
- **Lifecycle readiness:** can existing world and resume seams express the
  proposed generated sequences without changing production semantics?
- **Failure reduction:** what causal reductions are valid for an execution
  program? Build on [project 011's proposed ddmin design][p011-shrinking], which
  remains unimplemented in the inspected core/scripts. An invalid shorter program
  or an earlier harness refusal is not a smaller reproduction of the original defect.
- **Concurrent projects:** coordinate any widening with project 034's proposed
  effect model and project 031's program-format work. This research allocates no
  schema version and treats neither proposal as implemented.

## 9. Suggested next artifacts and evidence record

1. **Input audit:** list the selected runner's actual choice dimensions, fixed
   domains, existing controls, and missing reach observations, with source anchors.
2. **Experiment plan:** choose the small policy change, bounds, seed windows,
   budgets, mutation set, and decision criteria before execution.
3. **Results note:** retain baseline and experimental outputs, reproduction
   commands, failures, control outcomes, and a per-property comparison.
4. **Architecture decision if warranted:** decide whether to adopt the generator
   change, expand property evidence reporting, and proceed with the lifecycle
   workload. A general testing skill is a possible later packaging step once the
   workflow has been exercised successfully.

For this initial note, the external files listed in section 3 were read and
their repository revision pinned. The local generator, replay and reporting
interfaces, invariant evaluator, corpus workflow, mutation script, lifecycle
fixtures, and related project documents were inspected. The working tree had
pre-existing changes, including `Makefile` and research documents; HEAD is a
reference point, not a claim that every inspected document was committed there.
No current pass rate, mutation score, speedup, or newly confirmed production bug
is claimed. All experimental work above remains proposed.

The 2026-10-03 revision responds to the six findings in [REVIEW-001][review].
Related source and historical evidence were rechecked. CI execution history and
current timing remain unverified; no additional suite or mutation run was performed.

[review]: REVIEW-001-claude-fable-5.1.md
[upstream]: https://github.com/antithesishq/antithesis-skills/tree/1fd8470d36a9629a75bda4619a5589d679a40d7c
[up-properties]: https://github.com/antithesishq/antithesis-skills/blob/1fd8470d36a9629a75bda4619a5589d679a40d7c/antithesis-research/references/property-catalog.md
[up-inputs]: https://github.com/antithesishq/antithesis-skills/blob/1fd8470d36a9629a75bda4619a5589d679a40d7c/antithesis-review-inputs/references/anti-patterns.md
[up-mutations]: https://github.com/antithesishq/antithesis-skills/blob/1fd8470d36a9629a75bda4619a5589d679a40d7c/antithesis-mutation-testing/SKILL.md
[up-feature]: https://github.com/antithesishq/antithesis-skills/blob/1fd8470d36a9629a75bda4619a5589d679a40d7c/antithesis-feature-workload/SKILL.md
[p009]: ../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md
[p009-d23]: ../009_motoko_dst_execution/NOTE-d23-the-exit-code-reaches-the-caller.md
[p011]: ../011_improve_test_axises/RESEARCH-test-axes-beyond-dst.md
[p011-shrinking]: ../011_improve_test_axises/ADR-001-adopt-program-shrinking.md
[p013-fdb]: ../013_core_architecture_for_dst/NOTE-fdb-simulation-cross-check-2026-09-08.md
[p013-journal]: ../013_core_architecture_for_dst/ADR-003-session-journal-and-resume.md
[p031]: ../031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md
[p032]: ../032_dream_rsi/RESEARCH-dream-rsi-implications.md
[p034]: ../034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md
[generator]: ../../../src/core/dst_generator.ail
[program]: ../../../src/core/dst_program.ail
[persistence]: ../../../src/core/dst_persistence.ail
[replay]: ../../../src/core/dst_replay.ail
[invariants]: ../../../src/core/dst_invariants.ail
[report]: ../../../src/core/dst_run_report.ail
[corpus]: ../../../src/core/dst_corpus.ail
[ci]: ../../../.github/workflows/dst-corpora.yml
[contract-mutations]: ../../../scripts/verify_contract_mutations.sh
[park-resume]: ../../../scripts/dst/park_resume_dst.ail
[park-wire]: ../../../scripts/dst/run_park_resume.sh
[host-journal]: ../../../src/tui/src/session-journal.test.ts
