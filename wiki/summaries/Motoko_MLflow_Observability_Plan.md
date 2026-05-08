---
doc_type: short
full_text: sources/Motoko_MLflow_Observability_Plan.md
---

# Motoko MLflow Observability Plan — Summary

The document defines a phased plan to integrate **MLflow** as the observability backbone for **Motoko** runtime sessions, ensuring end‑to‑end traceability without disrupting existing behavior. 

## Key Concepts
- **[[MLflow Integration]]**: MLflow serves as the centralized repository for metrics and artifacts, mapped one‑to‑one with Motoko sessions.
- **[[Telemetry Correlation IDs]]**: Every event carries `session_id`, `turn_id`, `tool_call_id`, and `correlation_id` for full causal chain reconstruction.
- **[[Redaction]]** and **[[Sampling]]**: Privacy‑preserving controls enforce redaction of secrets and truncation of payloads; successful high‑frequency events are sampled while errors are always retained.
- **[[Motoko Runtime]]**: Instrumentation is added to `src/core/rpc.ail`, `src/tui/*`, and the env‑server TypeScript boundary.
- **[[Event Schema]]**: A common envelope with predefined `event_name` values (e.g., `motoko.session.start`, `motoko.turn.model_request`) and required attributes per event type.
- **Feature Flags**: `MOTOKO_OBSERVABILITY` defaults to `0`; when enabled, a non‑fatal telemetry writer feeds MLflow asynchronously.

## Architecture
- Telemetry events flow from runtime/TUI/env‑server into a **TypeScript‑based adapter** that writes to a file‑backed MLflow store (`mlruns/`).
- Failures in the telemetry sink are logged as warnings but never block user requests.
- Rollback is instantaneous: setting `MOTOKO_OBSERVABILITY=0` disables all emission.

## Phases
1. **Foundation** — schema, ID generation, instrumentation, redaction, writer, feature flags.
2. **Dashboards & SLOs** — query recipes, latency/failure SLOs, alert thresholds.
3. **Evaluation integration** — attach benchmark outcomes and enable regression comparisons.

## Acceptance Criteria
- With observability off, behavior is unchanged.
- Each session creates exactly one MLflow run with correlated turn/tool events.
- Tool failures carry metadata; redaction is demonstrably applied.
- Telemetry failures never break requests.

The plan balances **observability** needs with **performance** and **privacy**, using caps, sampling, and a fail‑safe adapter. See [[Validation Plan]] for manual smoke tests and automated checks.