# Trial packets and fixed prompts

Build one packet per historical Motoko task. Archive the original user request verbatim, the pre-change source snapshot, the later correct reference revision, and the independent fault manifest before launching any coding arm. Agents receive a writable pre-change snapshot **without Git history**; the reference fix and held-out faults must not be discoverable with `git log`, local search or remote access. Archive the exact prompt and transcript for each run.

The agent-visible packet contains only material a normal agent would have had when the task arrived:

```yaml
task_id: <stable ID>
original_user_request: <verbatim request, not rewritten as acceptance tests>
starting_revision: <full pre-change commit SHA>
allowed_source_paths: [<path>, ...]
allowed_test_paths: [<path>, ...]
existing_test_command: [<argv>, ...]
time_limit_minutes: <same in all coding arms>
token_limit: <same in all coding arms>
```

All three coding arms get the original request and the repository instructions. Do not append a test-writing instruction to `plain` or `mutguided`; spontaneous test creation is the behavior under study. The `no_tests` arm gets one additional sentence: “Do not create or modify tests; you may run the existing tests.” The `mutguided` arm gets one additional capability statement: “A mutation-testing tool is available to assess tests against variants of your implementation; you may use it within your task budget.” The `plain` arm gets neither sentence. Apart from those treatment differences, tool access, model settings, source scope and budgets are identical. If the agent asks for human input, handle it by the same prerecorded rule in every arm; do not provide new acceptance examples in only one arm.

The evaluator-only packet is sealed from all coding arms:

```yaml
task_id: <ID>
reference_revision: <full correct commit SHA>
owner_reviewed_contract: <behavioral obligations for fault adjudication>
hidden_acceptance_command: [<argv>, ...]
heldout_fault_manifest_sha256: <hash>
faults: [<fault ID and patch hash>, ...]
behavior_preserving_control: <patch hash>
```

Generate development mutants for `mutguided` only from its own evolving implementation, with the mutation operators and execution budget fixed before the trial. Record every mutant attempted, including those that fail to apply or compile. Do not expose the correct reference or held-out faults through that tool. The `plain` and `no_tests` arms retain equal overall time and token limits.

After coding ends, extract the test-only diff from `plain` and `mutguided`, including an empty diff if the agent wrote no tests. Freeze and hash it. Apply it to the correct reference revision with no semantic repair. If it fails to apply, classify its clean result as `fail` and give it no credited fault catches. Run added unit and integration tests as separate groups where possible, so the unit-test question is not answered with integration-test results.

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

Only after all fault verdicts are frozen should a coordinator map A/B back to `plain`/`mutguided` and fill `matrix.csv`. Preserve failures and empty test diffs. Run the scorer without editing the protocol or thresholds after results are visible.
