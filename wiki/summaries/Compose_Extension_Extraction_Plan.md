---
doc_type: short
full_text: sources/Compose_Extension_Extraction_Plan.md
---

This document details a phased plan for extracting the **Compose** tool from core runtime semantics so that core remains extension‑agnostic. It proposes moving all compose‑specific logic (policy, execution, retries, prompts) into a dedicated extension, leaving core to handle only generic `ToolCallEnvelope` routing.

## Key observations
- Core is currently coupled to Compose in multiple places: `rpc.ail` (orchestration), `types.ail` (ADT), `tool_runtime.ail` (error handling), and `prompts.ail` (policy prompts).
- The target architecture defines clear boundaries: core owns envelope dispatch, [[concepts/extension-hooks|extension hooks]] (policy, handle, intercept, finalize), and generic telemetry channels. The Compose extension owns its tool alias, policy decisions, execution, retries, and metadata formatting.
- The plan follows a six‑phase migration to safely disentangle these responsibilities while preserving behavioral and telemetry contracts.

## Migration strategy highlights
- **Phase 0** locks baseline behaviour with deterministic e2e tests for compose subagent, inline/off denial, and telemetry shape.
- **Phase 1** routes Compose calls through the extension handler with a temporary [[concepts/rollout-gate|rollout gate]] (`CORE_COMPOSE_EXTENSION_ONLY`), providing a fallback path and rollback playbook.
- **Phase 2** extracts compose‑specific policy (composition mode gating) into the extension’s `on_tool_policy` hook, leaving core with generic allow/deny semantics.
- **Phases 3‑4** remove `Compose` from core ADTs (`ToolCallReq`) and runtime code, enforcing separation via CI allowlist checks.
- **Phase 5** cleans up core prompts and ships compose guidance only through the extension’s prompt patch; user‑visible observation contracts (summary, attempts, validator outcome) are validated.
- **Phase 6** retires the rollout gate and all compatibility shims, leaving a single extension‑only compose dispatch path.

## Risks and mitigations
The plan anticipates behavior drift, telemetry regressions, policy confusion, hidden compile‑time coupling, and hard cutover failures. Mitigations include baseline semantic tests, stable telemetry event keys (`ext_tool_calls`, `ext_tool_results`), a single‑ownership rule for policy, CI‑enforced allowlists that forbid compose‑specific constructs in core paths, and the temporary rollout gate with documented rollback.

## Done definition
Extraction is complete when `rpc.ail`, `types.ail`, `tool_runtime.ail`, and `prompts.ail` contain no compose‑specific branches, constructors, or policy, and all compose behaviour flows exclusively through [[concepts/extension-hooks|extension hooks]] with e2e and telemetry tests passing.

The work is broken into five suggested pull requests and aims for a clean [[concepts/core-extension-boundary|core‑extension boundary]] that keeps core focused on generic tool routing and leaves compose as a pluggable, self‑contained extension.