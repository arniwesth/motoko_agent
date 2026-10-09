# Do agent-written unit tests add value to Motoko CI?

Status: preregistered design, 2026-10-09. No LLM trial has been run. This study is separate from the systematic mutation-testing proposal in project 039.

## Question

[Kun Chen's post](https://x.com/kunchenguid/status/2108030810691629403) reports that forbidding an agent to write tests did not lower success on a coding-task benchmark, while saving time and tokens. It does **not** measure whether those tests catch later regressions in CI, and the accessible post does not describe a mutation-testing arm. This experiment tests that separate Motoko question:

> Given the same already-correct code and the same existing CI, do unit tests written by an LLM detect independently chosen future faults? Does feedback from *development* mutants improve that detection on *held-out* faults enough to justify its cost?

The claim is local to a declared model, prompt, Motoko revision, task sample and test budget. A null result cannot prove that all agent-written tests are useless. One killed mutant cannot establish broad value.

## Arms and estimand

For each task, freeze one correct code revision and its existing CI. Use the same revision for all arms:

| Arm | Added tests | Feedback available while writing |
|---|---|---|
| `baseline` | none | none |
| `plain` | LLM-written unit tests | task contract, public code, existing tests and ordinary test output |
| `mutguided` | LLM-written unit tests | exactly the `plain` material, plus development mutants and their outcomes |

Both LLM arms use the same model, token/time cap, test-only edit scope and number of attempts. Run them in separate fresh sessions. Randomize arm order per task. Give neither session the held-out faults, their diffs, expected failures, historical bug fixes, or results from the other arm. The suites must pass on the clean revision before fault evaluation. Freeze test patches and record their SHA-256 digests before unsealing held-out faults.

**Primary estimand:** mean, across tasks, of the fraction of independently validated, baseline-missed faults caught by `plain` and by `mutguided`. Equal task weights prevent one task with many faults from dominating. A catch requires a test assertion that witnesses the fault's stated behavior; compilation errors, unrelated failures, timeouts and flaky outcomes are `inconclusive`. The paired difference `mutguided - plain` measures the extra value of mutation feedback. Report baseline catch rate on *all* valid faults separately so the conditional denominator stays visible.

**Secondary outcomes:** false failures on clean and behavior-preserving control revisions; total new test cases; added CI wall time; LLM tokens and elapsed time; development-mutant kill rate; the number and kind of faults each arm alone catches. Do not count a mutant kill as an independent validation fault if its text or result was shown during test writing.

## Task and fault construction

Pilot on 6 diverse Motoko tasks, then freeze the protocol and sample 60 fresh, independent tasks for the confirmatory run. The 60-task size permits a 95% upper bound below 5% on the chance of **any** incremental catch if there are zero catches; fewer tasks cannot establish that narrow negative result. Include AILANG core, TUI TypeScript, and Python tooling; report each stratum. Sample task/revision pairs from merged changes and documented contracts using a recorded search query and random seed. Exclude a candidate *before* seeing arm outcomes if it cannot build, has no stable test command, lacks a stated observable contract, or the reference behavior cannot be adjudicated. Publish the exclusion ledger. Keep source and test path scope small enough for a normal PR review.

For each accepted task, an independent fault author prepares 4–8 single-fault patches against the correct revision. Prefer a mixture of historical fix reversions and realistic faults in branches CI can execute. Add operator-generated mutants as a separate fault-source stratum. The author must not see generated test patches. An independent reviewer labels each fault against the task contract as `valid`, `equivalent`, or `uncertain`, and names the expected behavioral witness. Only `valid` faults enter detection rates. Preserve all candidates and exclusions in the ledger; do not replace escaped faults after seeing results. Prepare at least one comment-only or behavior-preserving control revision per task. Check that each fault patch applies and the affected behavior is reachable on the clean revision. A compiler rejection by itself is not a valid behavioral fault for this question.

Development mutants for `mutguided` are generated at separate sites or with separate operators from the held-out faults. They can guide test writing, but cannot enter the primary outcome. Record the exact mutant list before test generation. Give `plain` an equal opportunity to spend its budget on ordinary exploration, to avoid confusing extra compute with mutation feedback.

The frozen evaluation runner applies one fault patch at a time in disposable clean checkouts, then applies each suite patch. Run the unchanged CI command and the added tests; record raw logs, toolchain versions, time, exit code and assertion witness. Repeat any potential catch or control failure once on a quiet host. A second reviewer, blind to arm, decides `caught`, `missed`, or `inconclusive` from the fault contract and logs. No source, oracle, scorer or fault patch is edited after unsealing. A broken added suite on the clean revision earns no catches for that task; report its clean failure. A fault with infrastructure trouble in any arm is `inconclusive` for the paired comparison, with its raw results retained.

## Decision rule

Publish task-level paired estimates and a 95% cluster bootstrap interval, resampling tasks within the sampled task set. The included `score.py` computes the point estimate and interval from adjudicated rows. It also computes an exact one-sided 95% upper bound for the fraction of tasks with **any** catch; this conservative bound also bounds the mean per-task catch fraction. Before unsealing, declare a **10 percentage point** practical improvement threshold for incremental fault detection, and a **5 point** equivalence margin:

- Evidence that an arm adds CI value: the lower interval bound for its gain over `baseline` exceeds zero, with a clean/control false-failure rate no worse than baseline.
- Evidence for a material gain: that lower bound exceeds 10 points.
- Evidence consistent with negligible gain: the exact upper bound on tasks with any catch is below 5%. A zero-catch bootstrap interval alone never qualifies. This is a bounded result for this sample and setup, not proof of zero value.
- Otherwise: inconclusive; expand the sample according to the frozen sampling rule, rather than changing faults or thresholds after results.

Report `mutguided - plain` with its interval and incremental token and CI cost even if neither arm crosses a threshold. Do not collapse unit and integration tests into one count. The main comparison is about unit tests; if an agent writes integration tests, record them separately and exclude them from the main arm under the test-only scope.

## Data contract and execution

`matrix.csv` has one row per task/fault, with columns:

```csv
task_id,fault_id,kind,valid,baseline,plain,mutguided
```

`kind` is `fault`, `clean`, or `control`. `valid` is `yes`, `no`, or `uncertain` for faults and blank for controls. A fault verdict is `caught`, `missed`, or `inconclusive`; a clean/control verdict is `pass`, `fail`, or `inconclusive`. Each task needs exactly one `clean` row. Fault IDs must be unique within a task. `score.py` refuses malformed, duplicate, missing-clean and out-of-vocabulary rows. It does not infer `caught` from process exit status: the independent adjudication is a required input.

Run `python3 .agent/projects/040_llm_test_value/score.py matrix.csv --seed 20261009 --bootstrap 10000`. Save the input, output, raw command logs, suite and fault patches, digests, model settings, generation transcripts, revision pins and adjudication decisions. `python3 -m unittest discover .agent/projects/040_llm_test_value -p 'test_*.py'` checks the scorer on planted data before a real matrix is scored.

The first pilot's output is calibration only: it should reveal build costs, flaky controls, ambiguity in `caught`, and whether the task sample has enough baseline-missed faults. Freeze any protocol revision before expanding to the 24-task confirmatory set. The existing [011 mutation spike](../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md) supplies a reason to run this study: several plausible faults reached Motoko's driver without a relevant check firing. It is not evidence about *LLM-authored* tests, because those arms were never run there.
