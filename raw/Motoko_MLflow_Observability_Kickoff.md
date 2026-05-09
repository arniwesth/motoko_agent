# Kick-off Prompt: Motoko MLflow Observability (Phase 1)

Implement `.agent/plans/Motoko_MLflow_Observability_Plan.md` end-to-end for Phase 1 only, with zero behavior regressions in Motoko runtime/TUI.

## Constraints
- Do not change user-visible behavior or protocol semantics.
- Observability must be best-effort and non-fatal.
- Default OFF behind feature flag (`MOTOKO_OBSERVABILITY=0`).
- Do not log secrets or sensitive payloads.
- Keep telemetry volume bounded.

## Phase 1 Deliverables
1. Telemetry schema + IDs
   - Define event schema for `session`, `turn`, `tool_call`.
   - Ensure propagation of `session_id`, `turn_id`, `tool_call_id`, `correlation_id` across boundaries.

2. Instrumentation points
   - Add lightweight event emission hooks at:
     - runtime session/turn boundaries
     - tool call start/end/error
     - turn finalize
   - Target modules:
     - `src/core/rpc.ail`
     - relevant `src/tui/*`
     - env-server boundary code (TypeScript).

3. MLflow writer (best-effort)
   - Add a minimal telemetry sink that writes to MLflow-compatible run/trace records.
   - If direct trace API is not feasible in this phase, log structured artifacts + metrics in MLflow runs.
   - Failures in writer must not affect request handling.

4. Redaction + limits
   - Implement redaction for obvious secrets/tokens/auth headers.
   - Truncate large stdout/stderr payload logging with byte counts + hash.
   - Add sampling/rate-limiting guard for high-frequency events.

5. Config and docs
   - Add config flags:
     - `MOTOKO_OBSERVABILITY=0/1`
     - optional `MOTOKO_OBSERVABILITY_SAMPLE_RATE`
   - Document enable/disable and where data is stored.
   - Add a short “how to inspect a session by session_id” section.

## Acceptance Criteria
- With observability OFF: behavior matches current baseline.
- With observability ON: each session yields correlated telemetry records.
- Tool failures/timeouts appear with correlation IDs.
- No crashes when telemetry sink fails.
- Redaction is applied to logged artifacts/events.

## Validation Checklist
- Build/type/syntax checks pass for changed files.
- Manual smoke test:
  1) start session
  2) run at least one tool call
  3) induce one failing tool call
  4) verify records contain IDs and status transitions.
- Confirm no secret-like values are present in logged artifacts.

## Return Format
- Files changed
- Event schema summary
- Example telemetry record (redacted)
- Verification results
- Known limitations and Phase 2 recommendations
