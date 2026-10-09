# Do agent-written unit tests add value to Motoko CI?

Status: preregistered design, 2026-10-09. No LLM trial has been run. This study is separate from the systematic mutation-testing proposal in project 039.

## Question

[Kun Chen's post](https://x.com/kunchenguid/status/2108030810691629403) reports that forbidding an agent to write tests did not lower success on a coding-task benchmark, while saving time and tokens. In a [follow-up](https://x.com/kunchenguid/status/2108244512808243470), he says a 44-task subset with existing tests disabled showed no more regressions in those tasks. He also argues that mutation testing can make tests sensitive to changes without telling whether the asserted behavior is intended. That is a claim about **autonomously** written tests, not tests written from human-specified cases. Neither result measures whether tests generated during a task catch later, independently chosen CI regressions. This experiment asks:

> When an LLM implements a Motoko task and writes tests on its own initiative, do those test changes detect independently chosen future faults once applied to the correct implementation? Does development-mutant feedback improve that detection on held-out faults enough to justify its cost?

The claim is local to a declared model, prompt, Motoko revision, task sample and test budget. A null result cannot prove that all agent-written tests are useless. One killed mutant cannot establish broad value.

## Arms and estimand

For each task, freeze the original request, the **pre-change** code snapshot, a separately reviewed correct reference revision, and the existing CI. Coding agents start from identical pre-change snapshots:

| Coding arm | Test policy | Feedback available while implementing |
|---|---|---|
| `no_tests` | do not write or modify tests | original request, public code and ordinary existing-test output |
| `plain` | normal agent behavior; tests allowed but not requested | same material as `no_tests` |
| `mutguided` | normal agent behavior; tests allowed but not requested | same material, plus a fixed mutation tool and its development-mutant results |

All coding arms use the same model, token/time cap, source scope and number of attempts. Run them in separate fresh sessions. Randomize arm order per task. Give none the reference implementation, evaluator's contract, held-out faults, historical fix or results from another arm. The original request is their only task-specific statement of intended behavior. Measure each arm's immediate task success with a hidden, independent acceptance check; this reproduces the post's outcome separately from later CI value.

Freeze the test-only diffs produced **spontaneously** by `plain` and `mutguided`, including an empty diff if the agent wrote no tests. Record SHA-256 digests before unsealing held-out faults. Apply each test diff, without semantic repair, to a disposable checkout of the same correct reference revision. A diff that does not apply or fails on that clean revision earns zero CI catches and is reported as unusable. The `baseline` column in `matrix.csv` means the reference revision's existing CI, not the `no_tests` coding arm. This transplant holds implementation behavior fixed while assessing the added tests.

**Primary estimand:** mean, across tasks, of the fraction of independently validated, baseline-missed faults caught by `plain` and by `mutguided`. Equal task weights prevent one task with many faults from dominating. A catch requires a test assertion that witnesses the fault's stated behavior; compilation errors, unrelated failures, timeouts and flaky outcomes are `inconclusive`. The paired difference `mutguided - plain` measures the extra value of mutation feedback. Report baseline catch rate on *all* valid faults separately so the conditional denominator stays visible.

**Secondary outcomes:** immediate task success and regressions in each coding arm; false failures on clean and behavior-preserving control revisions; how often agents write unit versus integration tests unprompted; test diffs unusable on the reference; added CI wall time; LLM tokens and elapsed time; development-mutant kill rate; the number and kind of faults each test suite alone catches. Also report any baseline-caught faults that an added test diff stops catching. Do not count a mutant kill as an independent validation fault if its text or result was shown during test writing.

Record one `outcomes.csv` row per task and coding arm: `task_id,arm,acceptance,regression_count,tokens,elapsed_seconds,new_unit_tests,new_integration_tests`. `acceptance` is `pass`, `fail`, or `inconclusive` under the same hidden check for all arms. Compare paired `no_tests` versus `plain` success with the task as the unit, reporting the discordant counts and exact McNemar test; report `mutguided` separately. This coding outcome is not substituted for the later CI fault-detection outcome. The follow-up's separate 44-task intervention that forbade *running* existing tests is not replicated by these three arms.

## Task and fault construction

Pilot on 6 diverse Motoko tasks, then freeze the protocol and sample 60 fresh, independent tasks for the confirmatory run. The 60-task size permits a 95% upper bound below 5% on the chance of **any** incremental catch if there are zero catches; fewer tasks cannot establish that narrow negative result. Include AILANG core, TUI TypeScript, and Python tooling; report each stratum. Sample task/revision pairs from merged changes with an original task request, a pre-change snapshot and a correct reference revision, using a recorded search query and random seed. Exclude a candidate *before* seeing arm outcomes if it cannot build, has no stable test command, lacks a stated observable contract for independent adjudication, or the reference behavior cannot be judged. Publish the exclusion ledger. Keep source and test path scope small enough for a normal PR review.

For each accepted task, an independent fault author prepares 4–8 single-fault patches against the correct revision. Prefer a mixture of historical fix reversions and realistic faults in branches CI can execute. Add operator-generated mutants as a separate fault-source stratum. The author must not see generated test patches. An independent reviewer labels each fault against the task contract as `valid`, `equivalent`, or `uncertain`, and names the expected behavioral witness. Only `valid` faults enter detection rates. Preserve all candidates and exclusions in the ledger; do not replace escaped faults after seeing results. Prepare at least one comment-only or behavior-preserving control revision per task. Check that each fault patch applies and the affected behavior is reachable on the clean revision. A compiler rejection by itself is not a valid behavioral fault for this question.

The `mutguided` arm gets a mutation tool with its operators and budget fixed before the trial; it mutates that arm's own implementation after the agent has written it. Development mutants must be separate from held-out faults, which are prepared against the reference and never shown to agents. Record every development mutant and result. Give `plain` the same time and token budget for ordinary exploration, to avoid confusing extra compute with mutation feedback.

The frozen evaluation runner applies one fault patch at a time in disposable clean checkouts, then applies each suite patch. Run the unchanged CI command and the added tests; record raw logs, toolchain versions, time, exit code and assertion witness. Repeat any potential catch or control failure once on a quiet host. A second reviewer, blind to arm, decides `caught`, `missed`, or `inconclusive` from the fault contract and logs. No source, oracle, scorer or fault patch is edited after unsealing. A broken added suite on the clean revision earns no catches for that task; report its clean failure. A fault with infrastructure trouble in any arm is `inconclusive` for the paired comparison, with its raw results retained.

## Decision rule

Publish task-level paired estimates and a 95% cluster bootstrap interval, resampling tasks within the sampled task set. The included `score.py` computes the point estimate and interval from adjudicated rows. It also computes an exact one-sided 95% upper bound for the fraction of tasks with **any** catch; this conservative bound also bounds the mean per-task catch fraction. Before unsealing, declare a **10 percentage point** practical improvement threshold for incremental fault detection, and a **5 point** equivalence margin:

- Evidence that an arm adds CI value: the lower interval bound for its gain over `baseline` exceeds zero, with a clean/control false-failure rate no worse than baseline.
- Evidence for a material gain: that lower bound exceeds 10 points.
- Evidence consistent with negligible gain: the exact upper bound on tasks with any catch is below 5%. A zero-catch bootstrap interval alone never qualifies. This is a bounded result for this sample and setup, not proof of zero value.
- Otherwise: inconclusive; expand the sample according to the frozen sampling rule, rather than changing faults or thresholds after results.

Report `mutguided - plain` with its interval and incremental token and CI cost even if neither arm crosses a threshold. Do not collapse unit and integration tests into one count. The primary CI comparison uses the unit-test part of each spontaneous test diff; report integration-test diffs and their detection separately. Keep immediate coding-task success separate from future CI detection.

## Data contract and execution

`matrix.csv` has one row per task/fault, with columns:

```csv
task_id,fault_id,kind,valid,baseline,plain,mutguided
```

`kind` is `fault`, `clean`, or `control`. `valid` is `yes`, `no`, or `uncertain` for faults and blank for controls. A fault verdict is `caught`, `missed`, or `inconclusive`; a clean/control verdict is `pass`, `fail`, or `inconclusive`. Each task needs exactly one `clean` row. Fault IDs must be unique within a task. `score.py` refuses malformed, duplicate, missing-clean and out-of-vocabulary rows. It does not infer `caught` from process exit status: the independent adjudication is a required input.

Run `python3 .agent/projects/040_llm_test_value/score.py matrix.csv --seed 20261009 --bootstrap 10000`. Save the input, output, raw command logs, suite and fault patches, digests, model settings, generation transcripts, revision pins and adjudication decisions. `python3 -m unittest discover .agent/projects/040_llm_test_value -p 'test_*.py'` checks the scorer on planted data before a real matrix is scored.

The first pilot's output is calibration only: it should reveal build costs, flaky controls, ambiguity in `caught`, how often agents spontaneously write tests, and whether the task sample has enough baseline-missed faults. Freeze any protocol revision before expanding to the 60-task confirmatory set. The existing [011 mutation spike](../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md) supplies a reason to run this study: several plausible faults reached Motoko's driver without a relevant check firing. It is not evidence about *LLM-authored* tests, because those arms were never run there.
