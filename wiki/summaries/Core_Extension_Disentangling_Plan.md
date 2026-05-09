---
doc_type: short
full_text: sources/Core_Extension_Disentangling_Plan.md
---

# Core/Extension Disentangling Plan Summary

This document outlines a phased plan to make the core runtime **extension-agnostic** by removing all extension-specific semantics (aliasing, coercion, policy, handler dispatch) from core modules. The goal is a stable core that hosts the LLM loop, generic tool-call envelope parsing, and lifecycle hooks, while extensions like Omnigraph own their own domain logic.

## Key Objectives
- Introduce generic tool contracts (`ToolCallEnvelope`, `ToolResultEnvelope`) as the sole interface between core and extensions.
- Move all Omnigraph-specific aliases, coercion, and result shaping out of core parser, ADTs, RPC/telemetry, and dispatch.
- Preserve behavioral parity and telemetry compatibility during migration.
- Defer descriptor-based extension registration to a follow-up; keep the current enum-based registry for this effort.

## Current Coupling Hotspots
1. **Parser** (`src/core/parse.ail`) contains Omnigraph aliases and coercion.
2. **Core ADTs** (`src/core/types.ail`) import Omnigraph-specific request/result types.
3. **RPC/Telemetry** (`src/core/rpc.ail`) has Omnigraph-specific serialization and display shaping.
4. **Extension Dispatch** (`src/core/ext/runtime.ail`) hardcodes Omnigraph tool names and dispatch branches.
5. **Extension Implementations** consume core constructors directly.

## Target Architecture
- Core owns only stable, type‑level envelopes and hooks.
- Extensions own normalization, coercion, policy, tool execution mapping, and metadata schemas.
- Core responsibilities: event loop, hook registry, generic telemetry emission, policy merge/dispatch.

## Phased Migration (8 phases)
1. **Phase 0** – Golden tests and deterministic telemetry assertions freeze current behavior.
2. **Phase 1** – Introduce `src/core/tool_contract.ail` with generic envelopes co-existing with legacy types.
3. **Phase 2** – Add generic parse path (`parse_tool_calls_envelope`) alongside legacy parser.
4. **Phase 3** – Generic dispatch in `runtime.ail` with fallback; validate `compose`/`test_dummy` extensions.
5. **Phase 4** – Move Omnigraph normalization/coercion out of core into `src/core/ext/omnigraph/normalize.ail`.
6. **Phase 5** – Make RPC telemetry emit `ext_tool_calls`/`ext_tool_results` solely from generic envelopes.
7. **Phase 6** – Replace Omnigraph ADT constructor matching in `tool_runtime.ail` with generic envelope routing.
8. **Phase 7** – Remove Omnigraph types from `core/types.ail`; keep native tool ADTs.
9. **Phase 8** – Retire compatibility shims, docs, and legacy paths.

## Key Risks & Mitigations
- **Regression from alias/coercion moves** – mitigated by golden tests at each phase.
- **Telemetry schema breakage** – stable top-level keys; additive metadata changes only.
- **Tool-name conflicts** – deterministic resolution via registry order and startup checks (to be added later).
- **Dual-path divergence** – limited to 1–2 phases with strict removal milestone.
- **Registry model instability** – explicitly defer descriptor migration to a separate plan.

## Cross-Cutting Concepts
This plan establishes patterns that can be reused across other extensions:
- [[concepts/extension_contract]] – the core/extension boundary via envelopes and hooks.
- [[concepts/generic_tool_envelope]] – the `ToolCallEnvelope` and `ToolResultEnvelope` data models.
- [[concepts/generic_dispatch]] – extension dispatch using only tool name and generic payloads.
- [[concepts/telemetry_generic]] – extension-agnostic telemetry emission from core.
- [[concepts/extension_registry_enum]] – current enum‑based registry, deferred descriptor migration.

## Acceptance Criteria
When complete, no core module (parse, types, rpc, runtime, tool_runtime) will contain Omnigraph‑specific logic, and all existing e2e tests and telemetry checks remain green. The new extension contract becomes the only path for communication between core and any extension.