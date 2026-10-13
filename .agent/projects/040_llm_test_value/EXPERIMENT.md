# Do agent-written unit tests add value to Motoko CI?

Status: preregistered design, 2026-10-09. No LLM trial has been run. This study is separate from project 039, which is proposed in open PR #227 and is not assumed to be on `main`.

## Question

[Kun Chen's post](https://x.com/kunchenguid/status/2108030810691629403) reports that forbidding an agent to write tests did not lower success on a coding-task benchmark, while saving time and tokens. In a [follow-up](https://x.com/kunchenguid/status/2108244512808243470), he says a 44-task subset with existing tests disabled showed no more regressions in those tasks. He also argues that mutation testing can make tests sensitive to changes without telling whether the asserted behavior is intended. That is a claim about **autonomously** written tests, not tests written from human-specified cases. Neither result measures whether tests generated during a task catch later, independently chosen CI regressions.

> When an LLM implements a Motoko task and writes tests on its own initiative, do those tests detect independently chosen future faults once applied to the correct implementation? Does development-mutant feedback improve that detection on held-out faults enough to justify its cost?

The claim is local to a declared model, prompt, Motoko revision, task sample and budget. A null result cannot prove that all agent-written tests are useless. One killed mutant cannot establish broad value.

## Arms and estimand

For each task, freeze the original request, the **pre-change** repository snapshot, a separately reviewed correct reference revision and the existing CI. Coding agents start from identical pre-change snapshots:

| Coding arm | Test policy | Feedback available while implementing |
|---|---|---|
| `no_tests` | Do not write or modify tests | Original request, public code and ordinary existing-test output |
| `plain` | Normal agent behavior; tests allowed but not requested | Same material as `no_tests` |
| `mutguided` | Normal agent behavior; tests allowed but not requested | Same material, plus a fixed mutation tool and its development-mutant results |

All coding arms use the same model, token/time cap, source scope and number of attempts. Run them in separate fresh sessions. Randomize arm order per task. Give none the reference implementation, evaluator's contract, held-out faults, historical fix or results from another arm. The original request is their only task-specific statement of intended behavior. Measure each arm's immediate task success with a hidden, independent acceptance check.

Freeze the test-only diffs produced **spontaneously** by `plain` and `mutguided`, including empty diffs. Record SHA-256 digests before unsealing held-out faults. Each test is classified as unit or integration by a fixed rubric, blind to fault outcomes: a unit test exercises a narrow component with isolated dependencies; a test crossing a compiler, service, or process boundary is integration. Mixed or inseparable changes are assigned to integration, never unit. Record this classification and the test paths in the ledger before evaluating faults.

Construct the evaluation baseline deterministically: start with the correct reference **source and configuration**, then replace only test files changed by the historical task with their pre-change versions. Include all other pre-existing tests. A second reviewer checks this test-only reversal before agent diffs are seen; reject the candidate if source and tests share inseparable hunks or the constructed baseline cannot run. The `baseline` matrix verdict is this constructed suite, not the historical reference's newly written tests and not the `no_tests` coding arm. Apply each agent's test-only diff, based on pre-change test files, to that baseline without semantic repair. If application fails, record `apply_conflict` on clean and give zero catches. If the added suite fails on clean, record `fail` and give zero catches. Preserve raw logs and count both as unusable for CI. Run a unit-only patch and an integration-only patch separately from the same baseline; an empty category gets the baseline verdict. Do not run the two patches together for the primary score.

**Primary estimand:** for each generated arm, the mean across tasks of the fraction of independently validated, baseline-missed faults caught by its *unit-only* suite. Each arm uses its own assessable fault denominator; infrastructure-inconclusive fault runs do not become misses. Clean `inconclusive` excludes only that arm's task. A clean failure or patch conflict is a scored zero for that task's baseline-missed faults. A catch requires a test assertion witnessing the fault's stated behavior; compilation errors, unrelated failures, timeouts and flaky outcomes are `inconclusive`. The direct `mutguided - plain` difference uses only faults assessable in both arms and is reported separately. Equal task weights prevent one task with many faults from dominating. Report baseline catches on all valid faults, including baseline-inconclusive counts, so the conditional denominator stays visible.

**Secondary outcomes:** the same detection analysis for integration-only patches; immediate task success and regressions in each coding arm; false failures on clean and behavior-preserving controls; spontaneous unit versus integration test counts; patch conflicts; added CI wall time; LLM tokens and elapsed time; development-mutant kill rate; and baseline-caught faults that the added patch stops catching. The scorer also reports fault catches unique to either generated suite and catches shared by both on the jointly assessable set. Record CI wall time and mutant statistics in a separate ledger; `score.py` aggregates the defined matrix and coding-outcome fields, not those raw metrics. Do not count a mutant kill as an independent validation fault if its text or result was shown during test writing.

Record one `outcomes.csv` row per task and coding arm: `task_id,arm,acceptance,regression_count,tokens,elapsed_seconds,new_unit_tests,new_integration_tests`. `acceptance` is `pass`, `fail`, or `inconclusive` under the same hidden check for all arms. `score.py` reports paired `no_tests` versus `plain` success, discordant counts and an exact McNemar test; it reports `mutguided` separately. The follow-up's intervention that forbade *running* existing tests is outside these three arms.

## Task and fault construction

Pilot on six diverse tasks, then freeze the protocol and draw a **fixed 80-task confirmatory set** before any agent run. Search a prespecified pool of at most 160 candidates in a seeded random order; accept the first 80 that pass the pre-arm eligibility review. Before arm runs, each accepted task must have at least one independently validated fault missed by the constructed baseline. If fewer than 80 qualify, report the shortfall rather than replacing tasks after seeing outcomes. Record the candidate order and every exclusion. A negligible-gain decision requires at least 60 *scored* tasks per arm: at zero catches, 60 gives an exact one-sided 95% upper bound below 5%. If fewer survive infrastructure failures, report inconclusive; do not extend the sample after unsealing. Include AILANG core, TUI TypeScript and Python tooling with prespecified target counts and report each stratum. Sample merged task/revision pairs with an original request, pre-change snapshot and reviewed reference. Exclude before arm runs if the constructed baseline cannot build, lacks stable tests or an observable contract, or source/test changes cannot be separated.

For each accepted task, an independent fault author prepares 4–8 single-fault patches against the correct source. Exclude reversal of **that task's own historical fix**: it simply recreates the starting bug and overstates evidence for future CI value. Later, independently introduced regressions and realistic edits are eligible. Add operator-generated mutants as a separate fault-source stratum. The author must not see generated tests. An independent reviewer labels each fault against the task contract as `valid`, `equivalent`, or `uncertain`, and names the expected behavioral witness. Only `valid` faults enter detection rates. Preserve all candidates and exclusions; do not replace escaped faults after seeing results. Prepare at least one behavior-preserving control revision per task. Check each fault patch applies and its behavior is reachable on the constructed baseline. A compiler rejection alone is not a valid behavioral fault.

The `mutguided` arm gets a mutation tool with operators and budget fixed before the trial; it mutates that arm's own implementation. Development mutants are separate from held-out faults, which are prepared against the reference and never shown to agents. Record every development mutant and result. Give `plain` the same time and token budget for ordinary exploration.

The frozen evaluation runner applies one fault patch at a time to disposable copies of the constructed baseline, then each category-specific suite patch independently. Record raw logs, toolchain versions, time, exit code and assertion witness. Repeat potential catches or control failures once on a quiet host. A second reviewer, blind to arm, decides `caught`, `missed` or `inconclusive` from the fault contract and logs. No source, oracle, scorer or fault patch is edited after unsealing. A fault with infrastructure trouble in one arm is excluded only from that arm's primary denominator; the direct paired analysis uses the intersection.

## Decision rule

`score.py` reports task-level estimates and 95% cluster bootstrap intervals, resampling tasks. It computes an exact one-sided 95% upper bound for the fraction of tasks with **any** catch; this also bounds the mean per-task catch fraction. Declare a **10 percentage point** practical improvement threshold and a **5 point** negligible-gain margin:

- Evidence that an arm adds CI value: the lower bootstrap bound of its mean unit catch fraction exceeds zero, with zero clean failures or patch conflicts and no worse false-failure rate than baseline on jointly assessable behavior-preserving controls.
- Evidence for a material gain: that lower bound exceeds 10 points under the same clean/control conditions.
- Evidence consistent with negligible gain: the exact any-catch upper bound is below 5%, with at least 60 scored tasks. A zero-catch bootstrap interval alone never qualifies.
- Otherwise: inconclusive. Do not expand the fixed confirmatory sample after results are visible.

These are prespecified evidence labels, not proof of universal usefulness or uselessness. Report `mutguided - plain` with its interval and incremental token and CI cost regardless of threshold. The primary comparison uses **unit-only** patches; integration-only detection is secondary. Keep immediate coding success separate from future CI detection.

## Data contract and execution

`matrix.csv` has one row per task/revision/test category. Every task has matching rows for both `unit` and `integration`, with the same baseline verdict in each category:

```csv
task_id,fault_id,row_kind,test_kind,valid,baseline,plain,mutguided
```

`row_kind` is `fault`, `clean` or `control`; `test_kind` is `unit` or `integration`. `valid` is `yes`, `no` or `uncertain` for faults and blank otherwise. Fault verdicts are `caught`, `missed` or `inconclusive`; clean/control verdicts are `pass`, `fail` or `inconclusive`, with `apply_conflict` also allowed for generated-arm clean rows. Each task/category needs exactly one clean row, at least one control and one fault. An empty category patch repeats baseline outcomes. If clean is `apply_conflict`, fault rows are `inconclusive`; the scorer credits zero catches. `score.py` rejects malformed, duplicate, missing or cross-category-mismatched rows. It does not infer catches from exit status: independent adjudication is required.

Run `python3 .agent/projects/040_llm_test_value/score.py matrix.csv outcomes.csv --seed 20261009 --bootstrap 10000`. Archive both inputs, output, raw logs, suite and fault patches, digests, model settings, transcripts, revision pins and decisions. `python3 -m unittest discover .agent/projects/040_llm_test_value -p 'test_*.py'` checks the scorer on planted cases.

The pilot is calibration only: it should reveal build costs, flaky controls, ambiguity in `caught`, spontaneous test writing and availability of baseline-missed faults. Freeze any protocol revision before the confirmatory set. The existing [011 mutation spike](../011_improve_test_axises/NOTE-spike-findings-mutation-operator-feasibility.md) gives a reason to run this study: several plausible faults reached Motoko's driver without a relevant check firing. It is not evidence about *LLM-authored* tests, because those arms were never run there.
