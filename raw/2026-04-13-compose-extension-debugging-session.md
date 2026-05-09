# 2026-04-13 Compose Extension Debugging Session

## Context
This session focused on implementing and stabilizing the Compose-as-extension architecture and fixing multiple regressions observed in live TUI runs. The user repeatedly tested via `make run_test_local` and shared long transcripts showing failures in Compose retries, noisy diagnostics, stream rendering issues, and eventual non-productive retry loops.

The work touched `src/core/ext/compose/*`, core runtime routing, TUI rendering, and test/Makefile wiring.

## Objectives Covered
1. Implement the plan in `.agent/plans/Compose_As_Extension.md`.
2. Ensure Compose is actually activated in local test flow.
3. Fix TUI/CLI rendering regressions around compose subagent streaming.
4. Reduce check error noise that cluttered long sessions.
5. Fix repeated retry failures caused by wrapper/runtime behavior.
6. Harden claimcheck so it evaluates substantive snippet output, not runtime boilerplate.
7. Add regression tests for all identified classes of failures.

## Major Implementation Work (Plan Execution)

### 1) Extension architecture and hook model
Implemented and integrated an extension-first hook chain:
- `on_tool_policy`
- `on_tool_handle`
- `on_response_intercept`

Expanded extension context and registry/runtime plumbing so Compose can run as a first-class extension rather than ad hoc special casing.

Updated key files:
- `src/core/ext/types.ail`
- `src/core/ext/registry.ail`
- `src/core/ext/runtime.ail`
- `src/core/ext/test_dummy/dummy.ail`
- `src/core/ext/test_dummy/dummy_test.ail`

### 2) Compose extension module suite
Added/updated Compose extension modules:
- `src/core/ext/compose/compose.ail`
- `src/core/ext/compose/types.ail`
- `src/core/ext/compose/prompts.ail`
- `src/core/ext/compose/guard.ail`
- `src/core/ext/compose/validator.ail`
- `src/core/ext/compose/retry.ail`
- `src/core/ext/compose/store.ail`
- `src/core/ext/compose/claimcheck.ail`
- `src/core/ext/compose/telemetry.ail`

### 3) Runtime routing in rpc
Refactored `src/core/rpc.ail` to route through extension chain:
- response intercept -> tool handle -> native/delegated fallback
- returns explicit tool error when `Compose` has no handler

### 4) TS env-server surface changes
`src/tui/src/env-server.ts` compose endpoints were disabled with endpoint-removed responses as part of migration away from legacy compose HTTP handling.

## Activation and Environment Fixes

### Problem
Compose tool appeared unhandled in early runs (`no handler registered for tool Compose`).

### Fix
Updated `Makefile` local run target to enable extension + hybrid mode:
- `run_test_local` now sets:
  - `CORE_EXT_ORDER=compose`
  - `HYBRID_TOOLS=1`

## TUI/Streaming Regressions and Fixes

### Problem A: Internal compose streams leaking/clobbering transcript
Long sessions showed broken rendering and leaked fenced snippets in transcript.

### Problem B: Internal compose deltas not shown incrementally
Compose content appeared only after completion.

### Fixes in `src/tui/src/ui.ts` (and related logger filtering in `src/tui/src/index.ts`)
1. Added internal stream ID parsing for compose phases:
   - `compose-author-*`
   - `compose-summary-*`
   - `compose-claimcheck-informalize-*`
   - `compose-claimcheck-compare-*`
2. Routed `thinking_delta` for internal compose stream IDs into compose card state (not main transcript).
3. Added merge logic to avoid duplicate data when final snapshot events (`compose_*_delta`) arrive after stream chunks.
4. Preserved hiding of internal compose streams from normal think transcript while restoring incremental compose card updates.

Result: streaming resumed correctly in compose card UI without transcript pollution.

## Error Noise and Retry Diagnostics

### Problem
`ailang check` diagnostics were extremely verbose (`Suggestion`, `Hint`, workaround blocks), cluttering TUI.

### Fix
In Compose check-failure emission (`compose.ail`):
- compacted diagnostics
- filtered high-noise helper lines
- capped emitted error lines

This preserved actionable parse/type errors while reducing session clutter.

## Critical Retry Failure #1: Invalid injected module declaration

### Symptom
Repeated parse failure on line 1 with:
- `expected IDENT, got .`

### Root cause
Compose wrapper wrote snippets with invalid header like:
- `module .motoko-store/snippets/<name>`

This is syntactically invalid and caused deterministic failure across retries.

### Fix
Removed invalid header injection and introduced sanitization helper:
- `compose_file_body(snippet)` strips only user-provided `module ...` lines.

Added regression test:
- `src/core/ext/compose/compose_test.ail`
  - `strips_existing_module_declaration`
  - `does_not_inject_dot_path_module`

Wired into `make test_core`.

## Claimcheck Behavior Analysis and Changes

### User-observed concern
Claimcheck repeatedly disputed runs as execution-log-like rather than architectural analysis.

### Root cause (first part)
Claimcheck/informalizer was evaluating raw stdout contaminated by runtime boilerplate:
- `→ Type checking...`
- `→ Effect checking...`
- `✓ Running ...`

### Fixes in `src/core/ext/compose/claimcheck.ail`
1. Added normalization that strips runtime boilerplate before claimcheck comparison.
2. Updated informalizer prompt to handle generic observed output, not only strict certificate-style input.
3. If normalized output is empty, marked as vacuous and generated corrective hint for retry.

Added regression tests:
- `src/core/ext/compose/claimcheck_test.ail`
  - `strips_runtime_boilerplate_lines`
  - `returns_empty_when_only_boilerplate`

Wired into `make test_core`.

## Critical Retry Failure #2: Endless “vacuous” after above fix

### Symptom
After boilerplate stripping fix, claimcheck reported:
- `retry: claimcheck vacuous: no substantive output after runtime boilerplate`
for many attempts.

### Deep root cause
Compose snippets were often executing with no user output because of module/path mismatch behavior. Repro showed snippets could type-check and still only output runtime boilerplate when run path/module semantics were wrong.

Specifically:
- Using absolute snippet paths with module names like `module tmp/x` caused `MOD010` mismatch behavior.
- Snippet execution path/header strategy needed to satisfy module path validation and actual `main` execution.

### Final execution-path fix in `src/core/ext/compose/compose.ail`
1. Compose now writes snippets to relative `tmp/<name>.ail`.
2. Compose injects valid module header matching path:
   - `module tmp/<name>`
3. `ailang check/run` are invoked with the same relative `tmp/<name>.ail` path.
4. Applied to both subagent compose path and inline intercept path.

### Validation repro
- `tmp/repro_exec.ail` with `module tmp/repro_exec` and `println(...)` now emits actual stdout (`HELLO_FROM_TMP`) under the same run path logic.

## Additional Observations from Session

1. Subagent prompt wiring remained active:
   - `on_build_system_prompt` appends `compose_subagent_prompt_card()`.
2. Retry context was passed correctly:
   - `prior_errors` propagated into author prompt construction.
3. Remaining model quality issue seen in logs:
   - frequent AILANG syntax mistakes (`;`, malformed lambdas, pseudo constructs).
   - system can recover via retries but quality varies by model behavior.

## Tests and Checks Run During Session

Repeatedly executed and passed across patches:
- `ailang check src/core/ext/compose/compose.ail`
- `ailang check src/core/ext/compose/claimcheck.ail`
- `cd src/tui && npm run build`
- `cd src/tui && npm test -- --runInBand` (14 suites, 81 tests)
- `make test_core`

Core test targets now include compose regressions:
- `src/core/ext/compose/compose_test.ail`
- `src/core/ext/compose/claimcheck_test.ail`

## Net Outcome
The session moved Compose from unstable/partially wired behavior to a significantly more robust extension path:
- Compose reliably activated in local runs.
- Internal compose streaming rendered correctly without transcript corruption.
- Check-error noise reduced.
- Invalid wrapper/module path bugs fixed.
- Claimcheck made context-aware and less brittle against runtime boilerplate.
- Regressions captured with dedicated core tests and integrated into `make test_core`.

Remaining practical risk is model authoring quality under repeated retries, but the runtime/extension plumbing and validation/claimcheck paths are now substantially more reliable and diagnosable.
