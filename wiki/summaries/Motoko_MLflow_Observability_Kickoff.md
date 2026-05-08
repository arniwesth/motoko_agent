---
doc_type: short
full_text: sources/Motoko_MLflow_Observability_Kickoff.md
---

# Motoko MLflow Observability Kick-off Summary

This document defines the kick-off for implementing Phase 1 of Motoko’s observability layer using [[concepts/mlflow|MLflow]]. The goal is to add non-intrusive, best-effort telemetry with no impact on existing runtime/TUI behavior.

## Key Constraints
- Observability is **disabled by default** behind `MOTOKO_OBSERVABILITY=0`.
- Failures in the telemetry pipeline must be non-fatal and silent.
- No secrets or large payloads should be logged; redaction and truncation are mandatory.

## Phase 1 Deliverables
1. **[[concepts/telemetry-schema|Telemetry Schema]]** – Event definitions for `session`, `turn`, `tool_call` with ID propagation (`session_id`, `turn_id`, `tool_call_id`, `correlation_id`).
2. **Instrumentation Points** – Lightweight hooks at runtime session/turn boundaries, tool call lifecycle, and finalize steps.
3. **[[concepts/mlflow|MLflow]] Writer** – Sink for structured artifacts and metrics, best-effort only.
4. **[[concepts/redaction|Redaction & Limits]]** – Strip tokens/auth headers, truncate stderr/stdout, and apply sampling/rate limiting.
5. **Config & Docs** – [[concepts/feature-flags-in-motoko|Feature flags]] (`MOTOKO_OBSERVABILITY`, `MOTOKO_OBSERVABILITY_SAMPLE_RATE`) and instructions for inspecting a session by ID.

## Acceptance Criteria
- No behavioral change when flag is off.
- Correlated telemetry records generated per session when on.
- Tool failures are linked via correlation IDs.
- Zero crashes if telemetry sink fails.
- All logged data is redacted for secrets.

## Example Artifacts
- Event schema summary
- Redacted telemetry record sample
- Verification checklist (build, smoke test, secret scan)

## Links to Other Concept Pages
The approach touches several cross-document themes: [[concepts/observability|Observability Design]], [[concepts/mlflow|MLflow Integration]], [[concepts/feature-flags-in-motoko|Feature Flagging]], and [[concepts/redaction|Sensitive Data Handling]]. These may become dedicated concept pages as the project matures.