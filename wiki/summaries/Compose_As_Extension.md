---
doc_type: short
full_text: sources/Compose_As_Extension.md
---

## Summary

This document outlines a multi‑phase migration plan to convert the Compose subagent from its split TypeScript/AILANG implementation into a self‑contained AILANG extension (`src/core/ext/compose/`) built on a reshaped [[concepts/X1-Substrate]] (core extension system). The plan eliminates HTTP endpoints, moves ~80% of logic into AILANG, and preserves all existing TUI event names and telemetry fields.

### Key Assumptions
- Clean flip cutover with two destructive points (HTTP endpoint removal, final TS guard deletion); both tagged for rollback.
- Gold‑standard behavioral tests (`*.golden.test.ts`) will validate the ported AILANG extension via a thin shim with AI‑stub replays.
- `intent_kind` stays in core `ToolCall` metadata; Compose extension reads it without schema hooks.
- Event‑name stability is a frozen contract for `ui.ts` and `runtime‑process.ts` consumers.

### Phase‑Overview

**Phase 0 – X1 Substrate Reshape**  
Extends the core extension hooks to support full lifecycle integration: renames `on_tool_call` → `on_tool_policy`, adds `on_tool_handle`, `on_response_intercept`, enriched `ExtCtx`, and hook‑error isolation. Updates dummy extension and inlines tests. This is the foundation for hosting Compose.

**Phase 1 – Pure‑Logic Migration**  
Ports all pure TS logic to AILANG modules (`types`, `prompts`, `guard`, `validator`, `retry`, `telemetry`, `store`) using extracted golden fixtures. Each module is verified with `ailang test` and bit‑identical output to current `env‑server` paths.

**Phase 2 – Orchestration Layer**  
Replaces the TS subprocess bridge with direct `std/ai.callStreamResult` calls and `std/process.exec` for snippet checking. Deletes the `/compose` and `/exec‑ailang` HTTP endpoints. All `compose_*` events emitted via `println` preserve current TUI behaviour.

**Phase 3 – SF5 ClaimCheck Migration**  
Ports [[concepts/ClaimCheck]] (certificate‑vs‑intent comparison) to AILANG with strict separation invariants and JSON repair. Uses a replay harness for integration tests because inline `tests` cannot mock AI calls. Retains golden TS test for the full disputed‑retry loop.

**Phase 4 – Cutover and Cleanup**  
Removes all remaining TS guard, validator, and telemetry code. Updates documentation (`CLAUDE.md`, `README.md`, core extension plan). Verifies Compose loads, runs, and can be cleanly absent when `CORE_EXT_ORDER` is empty.

**Phase 5 – Optional AILANG Regex**  
Only triggered if a real `lines_regex` pattern exceeds the lowered subset. Two options: (A) pure AILANG Thompson NFA for language maturity, or (B) Go‑builtin wrapper (RE2) for safety and speed. Default recommendation is Option B.

### LLM‑Porting Strategy
- Golden fixtures frozen before any port, covering all existing Jest suites plus end‑to‑end recordings.
- One module per port session to limit blast radius.
- `requires`/`ensures` contracts on pure predicates where possible.
- Separation‑invariant tests for SF5 inspect prompt strings directly.
- Faithful 1:1 translation before any refactoring.

### Risks & Rollback
Semantic drift in the guards (SF2/SF3), AI streaming differences, and tool‑call hook conflict are mitigated by golden tests and single‑module ports. Two cutover points (Phase 2.6, Phase 4) are tagged for git‑based rollback; earlier phases are additive and revertable by branch discard.

### Relevant Cross‑Document Concepts
- [[concepts/X1-Substrate]] (core extension hooks and capabilities)
- [[concepts/Compose-Subagent]] (the Compose tool and its current TS implementation)
- [[concepts/Semi-Formal-Guards]] (SF2 effect‑set witness, SF3 output contracts)
- [[concepts/ClaimCheck]] (SF5 informalizer/comparator/repair pipeline)
- [[concepts/Golden-Testing]] (cross‑language behavioral test strategy)
- [[concepts/AILANG-Extension-Architecture]] (hook dispatch, registry, effect management)