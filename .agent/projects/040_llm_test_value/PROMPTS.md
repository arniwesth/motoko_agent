# Trial packets and fixed prompts

Build one packet per historical Motoko task. Archive the original user request verbatim, pre-change snapshot, reviewed correct reference, constructed evaluation baseline and independent fault manifest before launching any coding arm. Preserve the repository's `AGENTS.md` in agent sandboxes. Give each arm an isolated, writable **synthetic one-commit Git repository** made from the pre-change snapshot, with a local bare `origin` whose `main` points to that same synthetic commit. This lets repository worktree instructions and `tools/worktree/new.sh` operate without exposing the historical fix. Use separate containers or equivalent isolation, fresh home and agent memory, no host repository mounts, and no GitHub egress; only the model API and pinned toolchain are available. Preflight that `git log --all` and `git fetch origin main` reveal only the starting snapshot. Record the synthetic snapshot digest and environment image. Archive the exact prompt and transcript for each run.

The agent-visible packet contains only material available when the original task arrived:

```yaml
task_id: <stable ID>
original_user_request: <verbatim request, not rewritten as acceptance tests>
allowed_source_paths: [<path>, ...]
allowed_test_paths: [<path>, ...]
existing_test_command: [<argv>, ...]
time_limit_minutes: <same in all coding arms>
token_limit: <same in all coding arms>
```

Do not include the historical commit SHA or a public remote URL in the visible packet. All arms get the original request and repository instructions. Do not append a test-writing instruction to `plain` or `mutguided`; spontaneous test creation is under study. The `no_tests` arm gets: “Do not create or modify tests; you may run the existing tests.” The `mutguided` arm gets: “A mutation-testing tool is available to assess tests against variants of your implementation; you may use it within your task budget.” The `plain` arm gets neither sentence. Apart from these treatment differences, tools, model settings, source scope and budgets are identical. Handle requests for human input by the same prerecorded rule in every arm; do not supply new acceptance examples to one arm.

The evaluator-only packet is sealed from coding arms:

```yaml
task_id: <ID>
prechange_revision: <historical commit SHA>
reference_revision: <correct commit SHA>
constructed_baseline_sha256: <tree digest>
reversed_historical_test_paths: [<path>, ...]
owner_reviewed_contract: <behavioral obligations for fault adjudication>
hidden_acceptance_command: [<argv>, ...]
heldout_fault_manifest_sha256: <hash>
faults: [<fault ID and patch hash>, ...]
behavior_preserving_control: <patch hash>
```

Generate development mutants for `mutguided` from its own evolving implementation, with fixed operators and budget. Record all mutants, including ones that fail to apply or compile. Do not expose the correct reference or held-out faults through this tool. The other arms retain equal overall time and token limits.

After coding ends, extract each test-only diff, including empty diffs. Classify its tests as unit or integration using the frozen rubric, before fault outcomes are opened; inseparable mixed tests count as integration. Freeze and hash the whole diff and each category patch. Apply each patch separately to the **constructed evaluation baseline**, which has correct source/configuration and pre-change versions of the historical task's test files. No semantic repair is allowed. A conflict is `apply_conflict` on clean and earns zero catches; a clean runtime failure is `fail` and also earns zero catches. An empty category patch repeats baseline verdicts. A test that cannot be isolated from source edits is unusable and earns zero catches for its category.

The independent fault reviewer receives a packet without arm names or generation transcripts. For each task, randomize the suite-to-A/B mapping with a frozen seed and keep the mapping sealed until all adjudications are locked:

```yaml
task_id: <ID>
fault_id: <ID>
fault_source: later_regression | independent_edit | operator
validity: yes | no | uncertain
behavioral_witness: <expected difference from correct behavior>
test_kind: unit | integration
baseline_result: <log path and exit code>
suite_A_result: <log path and exit code>
suite_B_result: <log path and exit code>
adjudicated_results: <caught | missed | inconclusive for each suite>
reason: <named assertion, or why an exit was not a valid catch>
```

Only after verdicts are frozen should a coordinator map A/B back to `plain`/`mutguided` and fill `matrix.csv`. Preserve failures and empty test diffs. Run the scorer without changing the protocol or thresholds after results are visible.
