---
doc_type: short
full_text: sources/2026-04-14-compose-as-extension-implementation-session.md
---

# Compose as Extension Implementation Summary

This session completed the migration of Compose from ad-hoc handling to an extension-driven architecture, as described in `.agent/plans/Compose_As_Extension.md`. Compose is now fully integrated into the [[concepts/extension-framework|extension framework]], with hooks for tool policy, handling, and response interception.

## Key delivered components
- **Extension hooks & runtime plumbing**: enriched extension interfaces (`on_tool_policy`, `on_tool_handle`, `on_response_intercept`) and context propagation allow Compose to participate in all critical runtime phases. See [[concepts/extension-framework]].
- **Compose extension module set**: dedicated modules (`compose.ail`, `types.ail`, `guard.ail`, `validator.ail`, `retry.ail`, `store.ail`, `claimcheck.ail`, `telemetry.ail`) encapsulate the full author–check–run–retry loop, claimcheck gating, summary/telemetry emission, and stdout storage. This becomes the canonical implementation of a [[concepts/compose-extension]].
- **Core runtime migration**: `src/core/rpc.ail` no longer hardcodes Compose; the extension chain handles it via standard dispatch. A clear fallback error occurs when no handler is registered, maintaining compatibility with [[concepts/hybrid-tool-flow|hybrid tool execution]].
- **Local run activation**: `Makefile` target `run_test_local` sets `CORE_EXT_ORDER=compose` and `HYBRID_TOOLS=1`, ensuring the extension is active during development.
- **TUI/observability**: internal compose AI streams are prevented from leaking into the main transcript; the compose card receives incremental deltas (author/summary/claimcheck) and merges/ suppresses duplicate events. See [[concepts/tui-observability]].
- **Stability fixes**:
  - Reduced error-noise in compose checks during repeated retries.
  - Corrected module-path injection by switching to `tmp/<name>.ail` strategy.
  - Normalized claimcheck inputs by stripping runtime boilerplate (`Type checking`, `Effect checking`, `Running …`), and added vacuous-output corrective retries. See [[concepts/claimcheck-normalization]].
- **Regression tests**: new tests in `compose_test.ail` (module headers) and `claimcheck_test.ail` (boilerplate stripping) integrated into `make test_core`.

## Outcome
By the end of the session, Compose is fully extension‑centric, with runtime integration, TUI visibility, and regression coverage. The implementation matches the architectural intent of the plan and includes hardening discovered during live validation.