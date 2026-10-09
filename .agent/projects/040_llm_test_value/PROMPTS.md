# Trial packets and fixed prompts

Use one packet per task. Fill its fields and seal the development/held-out fault lists before creating either agent session. Archive the exact packet and prompt after substitution. Give agents a source snapshot without Git history; historical fixes and held-out fault patches must not be discoverable with `git log` or local search. The agent has permission to read task-scoped source, existing tests and task contract only.

```yaml
task_id: <stable ID>
revision: <full correct commit SHA>
contract: <observable requirements written before fault outcomes>
source_paths: [<path>, ...]
test_paths: [<path>, ...]
baseline_test_command: [<argv>, ...]
added_test_command: [<argv>, ...]
time_limit_minutes: <same in both arms>
token_limit: <same in both arms>
development_mutant_manifest_sha256: <hash, shown only to guided arm>
heldout_fault_manifest_sha256: <hash, never shown to either arm>
```

`plain` agent prompt, with the task packet appended:

> Write unit tests for the specified Motoko behavior. You may edit only the listed test paths. Keep the implementation fixed. Use the contract, source and existing tests in this snapshot. Run the baseline and added test commands as needed within the stated budget. Each added assertion should check an observable behavior named by the contract, including boundary and error cases where relevant. Finish with the test patch and the exact commands and results you observed. Do not create integration or end-to-end tests.

`mutguided` agent prompt is exactly the `plain` prompt plus:

> You may inspect and run the supplied development mutants and use their results to improve your unit tests. A mutant kill counts during development only if the clean revision passes and the test fails on the mutant for the contract behavior it targets. Record which mutant each revised assertion addresses. The held-out faults used for evaluation are separate and unavailable to you.

Give the guided arm a fixed read-only directory of development mutant patches and a documented command that runs one patch at a time in a disposable checkout. Record every mutant attempted, including those that fail to apply or compile. The plain arm gets the same time and token limits and may run the ordinary tests. Do not let either agent modify source code, existing tests, CI configuration or the task packet. If the test patch fails on the clean code at the limit, keep it and mark the clean verdict `fail`; do not repair it after unsealing faults.

The independent fault reviewer receives a packet without arm names or generation transcripts:

```yaml
task_id: <ID>
fault_id: <ID>
fault_source: historical_fix_reversal | independent_edit | operator
validity: yes | no | uncertain
behavioral_witness: <expected observable difference from the correct revision>
baseline_result: <log path and exit code>
suite_A_result: <log path and exit code>
suite_B_result: <log path and exit code>
adjudicated_results: <caught | missed | inconclusive for each suite>
reason: <named assertion, or why an exit was not a valid catch>
```

Only after all fault verdicts are frozen should a coordinator map A/B back to `plain`/`mutguided` and fill `matrix.csv`. Preserve failures that do not support the preferred conclusion. Run the scorer on the resulting matrix without editing this protocol or its thresholds.
