# Motoko MLflow Observability Plan

## Objective
Use MLflow as the observability backbone for Motoko runtime sessions (TUI -> runtime JSONL -> env-server), while preserving current behavior and protocol semantics.

## Success Definition
A session can be traced end-to-end by `session_id`, with correlated turn/tool events, latency/error metrics, and redacted artifacts, without introducing runtime instability.

---

## Scope
In scope:
- Session/turn/tool-call telemetry model.
- Correlation IDs propagated across TUI, runtime, and env-server boundaries.
- MLflow-backed storage for metrics + structured artifacts.
- Redaction, truncation, sampling, and feature flags.

Out of scope (Phase 1):
- Hosted MLflow infra hardening (auth, RBAC, HA DB).
- Full transcript capture by default.
- Billing-grade cost accounting.

---

## Architecture
## Event flow
1. Runtime/TUI/env-server emit structured telemetry events.
2. Telemetry sink converts events into MLflow run data (metrics, params, artifacts).
3. Failures in telemetry sink are swallowed with warnings (non-fatal path).

## Ownership boundaries
- Runtime (`src/core/rpc.ail`): emits session/turn/tool lifecycle events and IDs.
- TUI (`src/tui/*`): emits user turn start/end and render-complete events.
- Env-server boundary (TypeScript): emits tool call start/end/error with payload sizes and exit status.
- Telemetry writer: centralized adapter (TypeScript preferred for Motoko runtime adjacency) that writes to MLflow.

## Deployment model (Phase 1)
- File-backed MLflow store in local/dev (`mlruns/` path).
- Optional Modal/shared path later.
- Feature flag disabled by default.

---

## Canonical IDs and Correlation
Required fields on every event:
- `session_id`
- `turn_id` (nullable only for session-level events)
- `tool_call_id` (nullable except tool events)
- `correlation_id` (stable across same request chain)
- `ts_utc` (ISO-8601)

ID rules:
- `session_id` created once at session start.
- `turn_id` created per user prompt.
- `tool_call_id` created per tool invocation.
- Retries retain `turn_id`, create new `tool_call_id`, increment `retry_index`.

---

## Event Schema (Phase 1)
## Common envelope
- `event_name: string`
- `ts_utc: string`
- `session_id: string`
- `turn_id: string | null`
- `tool_call_id: string | null`
- `correlation_id: string`
- `source: "runtime" | "tui" | "env_server"`
- `status: "start" | "success" | "error" | "cancelled"`
- `attrs: object`

## Required event names
Session:
- `motoko.session.start`
- `motoko.session.end`

Turn:
- `motoko.turn.start`
- `motoko.turn.model_request`
- `motoko.turn.model_stream_end`
- `motoko.turn.end`

Tool:
- `motoko.tool.start`
- `motoko.tool.end`
- `motoko.tool.error`

## Required attrs by event type
Turn attrs:
- `model`
- `provider`
- `latency_ms_total` (on end)
- `assistant_tokens_out` (if available)
- `retry_count`

Tool attrs:
- `tool_name`
- `latency_ms`
- `exit_code` (if process-backed)
- `stdout_bytes`
- `stderr_bytes`
- `error_kind` (on error)

---

## MLflow Mapping
One MLflow run per Motoko session.

Tags:
- `app=motoko`
- `runtime_version`
- `model`
- `provider`
- `workspace_hash` (best effort)
- `git_commit` (best effort)

Metrics (session-aggregated):
- `turn_count`
- `turn_success_count`
- `turn_success_rate`
- `tool_call_count`
- `tool_success_rate`
- `p50_turn_latency_ms`
- `p95_turn_latency_ms`
- `p50_tool_latency_ms`
- `p95_tool_latency_ms`
- `timeout_rate`
- `retry_rate`

Artifacts:
- `session_summary.json`
- `turn_metrics.jsonl`
- `tool_calls.jsonl` (redacted/truncated)

---

## Privacy, Redaction, and Volume Controls
Hard requirements:
- Never log API keys, bearer tokens, cookies, auth headers, secret env values.
- Redact known secret patterns in text payloads.
- Truncate stdout/stderr payloads above threshold; store hash + byte count only.

Recommended defaults:
- `MOTOKO_OBSERVABILITY=0`
- `MOTOKO_OBSERVABILITY_SAMPLE_RATE=0.2`
- `MOTOKO_OBSERVABILITY_MAX_PAYLOAD_BYTES=4096`

Sampling policy:
- Always keep `error`/`cancelled` events.
- Sample successful high-frequency stream events.

---

## Implementation Phases
## Phase 1 — Foundation (this plan’s execution target)
1. Define telemetry schema + ID generation helpers.
2. Instrument runtime/TUI/env-server boundaries for required events.
3. Implement MLflow writer adapter (best-effort, non-fatal).
4. Add redaction + truncation utilities.
5. Add feature flags and docs.

## Phase 2 — Dashboards and SLOs
1. Add query recipes / dashboard snippets.
2. Define SLOs for turn latency and tool failure rate.
3. Add alert thresholds (optional external integration).

## Phase 3 — Evaluation integration
1. Attach benchmark/eval outcomes to session runs.
2. Enable commit-to-commit regression comparisons.

---

## Acceptance Criteria (Phase 1)
1. Observability OFF: behavior is unchanged in smoke tests.
2. Observability ON: each session creates one MLflow run.
3. Turn/tool events are correlated by IDs and reconstructable.
4. Tool failures/timeouts are visible with error metadata.
5. Telemetry failures never break user request handling.
6. Redaction/truncation policy is demonstrably applied.

---

## Validation Plan
Automated:
- Build/type/syntax checks for modified AILANG + TS files.
- Unit tests for redaction/truncation helpers.

Manual smoke:
1. Start a session and complete one successful turn.
2. Execute one successful tool call.
3. Force one failing tool call (e.g., bad command/timeout).
4. Confirm MLflow run has expected metrics/artifacts.
5. Verify no secret-like strings exist in artifacts.

---

## Risks and Mitigations
Risk: telemetry overhead affects responsiveness.
- Mitigation: async buffered writer, sampling, capped payloads.

Risk: inconsistent ID propagation across boundaries.
- Mitigation: shared ID helpers and contract tests.

Risk: excessive artifact growth.
- Mitigation: strict payload caps and aggregated session artifacts.

---

## Rollback
- Set `MOTOKO_OBSERVABILITY=0` to disable all telemetry emission/writes.
- Keep instrumentation paths isolated and guard all writer calls.

