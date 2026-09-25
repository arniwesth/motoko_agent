# Make `src/core` contract verification honest and enforcing

## Summary

This branch turns `ailang verify` from an advisory green check into an enforcing,
measurable contract gate for `src/core`.

It replaces dead or aspirational verification predicates with contracts on the functions
that own the behavior, distinguishes contracts that constrain an implementation from ones
that merely verify, adds mutation coverage for guard predicates, and enforces a checked
contract-or-excuse policy for new pure functions.

The resulting tree has:

- 11 contracts proved by Z3;
- 9 contracts classified as substantive;
- 2 registered tautologies, retained but counted as zero;
- 1 attempted contract outside the current SMT fragment;
- 5 guard contracts falsified by mutation tests;
- no unstated, violated, or errored core contracts.

## Changes

### Enforcing core verification

- Makes `make verify_core` enforcing in CI by removing `continue-on-error`.
- Reports contracts by outcome instead of ticking any file that mentions a contract:
  - `proven` for VERIFIED contracts;
  - `unstated` for `requires` without `ensures`, which fails the gate;
  - `blocked` for a stated obligation rejected by the SMT fragment, which remains visible
    without punishing the attempt;
  - `bare` for files with no contracts.
- Fails explicitly on per-function verifier `ERROR` output. AILANG v0.33 can return zero for
  encoding or solver errors unless strict mode is used, so the gate parses those verdicts
  rather than trusting the process status alone.
- Applies the same error and unstated-contract handling to `make verify_ext`.

### Computed contract classification

- Adds `tools/verify_classify/classify.py` and the generated
  `tools/verify_classify/contracts.register`.
- Classifies every core contract with two generated Z3 probes:
  - `TAUT` asks whether the postcondition holds for every possible result;
  - `DETERMINE` asks whether the postcondition admits only the body's exact answer.
- Counts a contract as `substantive` only when both probes produce a counterexample: the
  obligation is falsifiable and permits more than a restatement of the implementation.
- Preserves the function's original `requires` clauses on both probes. This prevents an
  `ensures` implied entirely by its precondition from being mislabeled substantive.
- Includes preconditions in the contract pin, so changing a function's domain invalidates
  its register entry.
- Fails closed when a probe reports ERROR or produces no verdict; those cases can no longer
  be silently converted to the permitted `unclassified` bucket.
- Adds regression tests, including a solver-backed fixture proving that a precondition-only
  postcondition classifies as a tautology.

### Contract adoption in `src/core`

Adds or strengthens contracts around behavior callers and safety guards rely on:

- `agents_md.is_root`: a root classification can only hold for a short root form.
- `compress.truncate_with_suffix` and `compress_output`: output never exceeds the requested
  maximum length.
- `recovery.should_retry_stream_error`: retry approval requires a retryable provider error
  and remaining step budget.
- `session.trace_sensitive_key`: every named sensitive trace key remains redacted.
- `tool_runtime.has_shell_tokens`: every supported shell metacharacter is detected.
- `tool_runtime.is_absolute_path` and `starts_with_root_dir`: path-guard recall and precision
  properties replace implementation restatements.
- `tool_runtime.shell_command_needs_wrap`: shell names, embedded spaces, and metacharacters
  force wrapping through a primitive-argument helper that Z3 and property testing can both
  execute.

The full `ProcessExecReq` shell decision still contains a recursive list walk that the SMT
fragment cannot encode. It now carries a checked recursive excuse, while explicit runtime
examples cover the record boundary, token-bearing arguments, and a safe negative case.

### Mutation checks

Adds `make verify_mutations`, which temporarily removes a required body disjunct and asserts
that the corresponding contract changes from VERIFIED to VIOLATION.

The suite covers:

- `has_shell_tokens`;
- `shell_command_needs_wrap`;
- `starts_with_root_dir`;
- `should_retry_stream_error`;
- `trace_sensitive_key`.

Sources are restored on success, failure, or interruption.

### New-function policy and survey tooling

- Adds `make new_contract_policy BASE=<ref>`.
- Requires each new `pure func` under `src/core` to carry either an `ensures` clause or an
  adjacent `-- contracts: ...` explanation.
- Checks explanations by synthesizing a trivial contract and confirming that the verifier
  really rejects the function; a free-text excuse on a verifiable function fails.
- Adds `make verify_survey` to probe which existing functions are inside the current SMT
  fragment without turning that survey into a gate.

### CI

- Installs Z3 in `verify-extensions.yml`; previously the advisory verification step could not
  actually solve any contract in that job.
- Runs `verify_core`, mutation checks, computed-classification checks, and the new-function
  policy as enforcing steps.
- Uses a full checkout so the policy can resolve its comparison base.
- Compares pull requests against their base branch and pushes against
  `github.event.before`. Comparing a push with `origin/main` after checkout would compare HEAD
  with itself and silently report an empty diff.

### Documentation and generated artifacts

- Documents the contract classes, authoring guidance, mutation checks, and survey workflow in
  `CONTRIBUTING.md`.
- Records implementation findings under `.agent/projects/027_z3_contracts/`.
- Regenerates the computed contract register.
- Re-baselines the five `session.ail` attribution anchors moved by the trace-redaction
  contract and reissues the three profiles that pin the table. The routed clock set and
  anchored expressions are unchanged; this is line-offset drift, not a routing change.

## Validation

Run locally against AILANG v0.33.0 and Z3 4.8.12:

```text
make check_core
  56 passed, 0 failed

make verify_core
  11 contracts proven, 0 unstated, 1 blocked; 0 files failed, 48 bare

make verify_classify_check
  5 classifier regression tests passed
  12 contracts agree with the generated register
  9 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified

make verify_mutations
  5 falsified, 0 unfalsified

make test_coverage_selftest test_coverage
  self-test: 0 failures
  446 of 450 passed; 4 skips matched recorded upstream limitations

make verify_ext
  0 failed

make predicate_anchors
  no drift
```

Additional checks:

- focused `tool_runtime.ail` type, verification, and property tests;
- Python classifier compilation and unit tests;
- mutation-script syntax validation;
- `git diff --check`.

## Review notes

- `proven` is intentionally not the headline metric. Only `substantive` contracts count as
  evidence that the specification constrains the body.
- `blocked` means the verifier emitted a real SKIPPED verdict for a stated obligation. ERROR
  and missing verdicts fail closed.
- `compress_output` is the sole remaining unclassified contract because its body reaches the
  currently unencodable `std/string.split` path. Its length property still runs through
  generated property testing.
- The two tautologies (`isSome` and `is_native_backend`) remain visible in the register rather
  than being deleted or counted as useful coverage.
- After changing a contract, its preconditions, or its body, regenerate the pin with
  `make verify_classify` and confirm it with `make verify_classify_check`.
