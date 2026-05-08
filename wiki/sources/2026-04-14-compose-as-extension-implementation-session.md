# 2026-04-14 Summary: Implementation of `.agent/plans/Compose_As_Extension.md`

## Scope
This summary covers the implementation work completed in this session for the Compose-as-extension plan, with emphasis on architecture migration, runtime integration, and stabilization needed for production behavior.

## Plan Goal
Move Compose from ad hoc/legacy handling into the extension framework so Compose is:
- discovered/ordered via extension registry,
- executed through extension hooks,
- visible in runtime/TUI telemetry,
- safe under retries/checking/claimcheck,
- compatible with hybrid tool flow.

## Implementation Delivered

### 1) Extension hook model and runtime plumbing
Implemented/expanded extension interfaces and runtime orchestration so extensions can participate in all key phases.

Updated:
- `src/core/ext/types.ail`
- `src/core/ext/registry.ail`
- `src/core/ext/runtime.ail`
- `src/core/ext/test_dummy/dummy.ail`
- `src/core/ext/test_dummy/dummy_test.ail`

Core behavior introduced/solidified:
- `on_tool_policy`: allow/deny/no-op decisions
- `on_tool_handle`: extension-owned handling (Compose path)
- `on_response_intercept`: optional inline-intercept path
- richer extension context values (step/model/workdir/etc.)

### 2) Compose extension module set
Implemented Compose as a dedicated extension module family.

Added/updated:
- `src/core/ext/compose/compose.ail`
- `src/core/ext/compose/types.ail`
- `src/core/ext/compose/prompts.ail`
- `src/core/ext/compose/guard.ail`
- `src/core/ext/compose/validator.ail`
- `src/core/ext/compose/retry.ail`
- `src/core/ext/compose/store.ail`
- `src/core/ext/compose/claimcheck.ail`
- `src/core/ext/compose/telemetry.ail`

Compose extension responsibilities now include:
- tool ownership for `Compose` requests,
- author/check/run/retry loop,
- structured compose event emission,
- summary/telemetry production,
- claimcheck gating and corrective retry hints,
- stdout storage/elision behavior.

### 3) Core runtime migration to extension dispatch
Refactored `src/core/rpc.ail` integration path so Compose is no longer hard-coded in legacy env-server route logic.

Key runtime outcome:
- extension chain handles Compose via standard flow,
- explicit fallback error when no Compose handler is registered,
- tool routing remains consistent with hybrid execution design.

### 4) Local run activation for Compose extension
`Makefile` local test entry was updated to ensure Compose extension is active in expected developer flow.

Updated target:
- `run_test_local` sets:
  - `CORE_EXT_ORDER=compose`
  - `HYBRID_TOOLS=1`

This resolved the “Compose tool unregistered” behavior in local runs.

## TUI/Observability Work Needed for Plan Completion
To make Compose-as-extension usable in practice (not just wired), session implementation included TUI handling updates:

Updated:
- `src/tui/src/ui.ts`
- `src/tui/src/index.ts`

Delivered behavior:
- internal compose AI streams do not leak into main think transcript,
- compose card receives incremental internal deltas (author/summary/claimcheck),
- compose progress remains visible during streaming,
- duplicate content from stream+snapshot events is merged/suppressed.

## Stability Fixes That Were Necessary for Plan Success
These fixes were made while validating the implementation and are part of practical completion:

1. Error-noise compaction in compose checks
- Reduced diagnostic clutter in repeated retries.

2. Snippet wrapper/module-path correctness
- Removed invalid module injection patterns.
- Introduced valid module-path strategy using `tmp/<name>.ail` + `module tmp/<name>`.
- Switched execution/check paths to matching relative paths.

3. Claimcheck input normalization
- Strips runtime boilerplate (`Type checking`, `Effect checking`, `Running ...`) before evaluation.
- Improved prompts for observed-output interpretation.
- Vacuous-output handling now drives corrective retries instead of false accept.

## Regression Tests Added During Implementation
To lock in behavior:

- `src/core/ext/compose/compose_test.ail`
  - protects against invalid/undesired module header behavior

- `src/core/ext/compose/claimcheck_test.ail`
  - protects normalized-output behavior (boilerplate stripping)

`Makefile` `test_core` updated to include both tests.

## Verification Performed
The following checks passed during session:
- `ailang check src/core/ext/compose/compose.ail`
- `ailang check src/core/ext/compose/claimcheck.ail`
- `cd src/tui && npm run build`
- `cd src/tui && npm test -- --runInBand` (14/14 suites, 81/81 tests)
- `make test_core` (including new compose regressions)

## Final State vs Plan Intent
By end of session, Compose is implemented as an extension-centric flow and actively used through extension ordering, with runtime/TUI support and regression coverage. The implementation now aligns with the architectural direction in `.agent/plans/Compose_As_Extension.md` and includes additional hardening discovered during live session validation.
