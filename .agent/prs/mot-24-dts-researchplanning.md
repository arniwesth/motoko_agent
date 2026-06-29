# Deterministic Simulation Testing Research Plan

Base branch: `origin/main`

## Summary

This branch adds research and an ADR for a Deterministic Simulation Testing
(DST) architecture for Motoko. The goal is to make multi-step agent-loop,
compaction, provider telemetry, extension-hook, and harness-boundary behavior
testable without relying on live providers or model-specific prose.

## Changes

- Adds DST research for agent-loop compaction, focused on actual provider token
  telemetry, system-message pinning, provider-call recording, and tool-shape
  preservation.
- Adds generalized DST research covering layered scenario tests for pure policy,
  loop state, harness boundaries, and end-to-end deterministic harness behavior.
- Adds `ADR-001` proposing a layered DST architecture with scripted fakes,
  normalized traces, stable scenario ids, and structural invariants.
- Updates `.gitignore` for local code-graph, Python cache, marimo, and related
  generated artifacts.

## Verification

Documentation-only change. No tests were run.
