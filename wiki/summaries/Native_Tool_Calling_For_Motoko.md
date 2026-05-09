---
doc_type: short
full_text: sources/Native_Tool_Calling_For_Motoko.md
---

# Structured Tool-Call Authoring for AILANG (Option 2) — Plan

## Overview
This plan introduces a **structured tool-call authoring surface** to replace free-text emission of the Motoko-like [[AILANG]] during Compose authoring loops. It targets the `google/gemma-4-26B-A4B-it` model to eliminate syntax-level errors and improve code generation reliability by leveraging [[concepts/native-tool-calling|native tool calling]].

## Motivation
AILANG is out-of-distribution for Gemma 4, causing high parse-error rates. The model struggles to simultaneously handle syntax, types, effects, scope, and task semantics. By moving syntax and effect-row correctness into a deterministic [[concepts/dispatcher-renderer|dispatcher]], we exploit Gemma's tool-calling strength and collapse parse errors to near zero.

## Approach
- **Tool surface**: Define JSON-schema authoring tools (`set_module`, `add_import`, `define_func`, `build_block`, `finalize`, etc.) that the model invokes natively via the provider API.
- **Dispatcher**: Accumulates an in-memory program representation from tool calls, validates each call, and renders canonical AILANG at `finalize()`.
- **Free-text bodies**: Function bodies and expression leaves remain free-text strings, parsed and validated on receipt by the dispatcher, so parse errors are returned as structured tool-call results.
- **Protocol**: Each author turn emits one or more tool calls or `finalize()`. A budget of 40 authoring tool calls per snippet exists; fallback to the existing free-text path remains for providers without native tool calling.
- **Repair tools** (Phase 3): Functions like `replace_func_body` and `rename_var_in_body` allow model-driven correction after failed finalize.

## Tool Surface (Phase 1)
Surface A: `set_module`, `add_import`, `add_type_alias`, `define_type`, `define_func`, `set_main`, `finalize`. Optional block/expression builders deferred to Phases 3 or 5.

## Dispatcher Responsibilities
- JSON Schema validation, reference integrity, import symbol checks, effect-row well-formedness, scope checking, rendering to canonical AILANG, and final `ailang check`.

## Phases
1. **Phase 0** – Inventory failure modes, draft tool schemas, confirm provider tool-call support.
2. **Phase 1** – Implement state, dispatcher, renderer, stdlib manifest; round-trip tests.
3. **Phase 2** – Integrate with the [[concepts/compose-author-loop|Compose author loop]] behind a capability flag; provider adapter layer.
4. **Phase 3** – Add repair tools and improve error classification with `error_class`, `suggestion`, `did_you_mean`.
5. **Phase 4** – Measure parse-error rate, first-attempt success, and budget usage; decide on default-on for Gemma 4.
6. **Phase 5** (conditional) – Introduce finer expression builders if body parse errors remain dominant.

## Risks
- Gemma tool-calling flakiness → verified early, fallback remains.
- Schema cognitive load → minimal surface first, gradual expansion.
- Body parse errors → dispatcher rejects at tool level; repair tools close the loop.
- Dispatcher divergence → round-trip corpus test and final authoritative `ailang check`.

## Related Documents
- [[research/AILANG_performance_evidence_gates]] — lever analysis and rationale.
- [[summaries/2026-04-14-compose-author-premise-tools-plan-implementation]] — existing author loop.
- [[summaries/2026-04-14-compose-regression-investigation-and-hardening]] — prior parse/type-loop hardening.
- [[concepts/native-tool-calling]], [[concepts/structured-authoring]], [[concepts/effect-row-wellformedness]], [[concepts/dispatcher-renderer]], [[concepts/tool-call-authoring]].