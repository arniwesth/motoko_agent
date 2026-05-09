---
doc_type: short
full_text: sources/2026-04-14-compose-author-premise-tools-plan-implementation.md
---

**Source:** [[sources/2026-04-14-compose-author-premise-tools-plan-implementation]]

# Summary: Compose Author Premise Tools Plan Implementation

## Overview
This document captures the implementation status of the **Compose Author Premise Tools** plan as of the 2026-04-14 session. It covers four planned phases, session-specific refinements, verification steps, and remaining work. The implementation spans several core modules in the `src/core/ext/compose/` directory and introduces cross-cutting concepts like [[concepts/premise-ledger]], [[concepts/author-loop]], and [[concepts/validator-binding]].

## Phase-Level Implementation Status

### Phase 1 — Tool Infrastructure
- Read‑only author tool dispatcher and whitelist (`author_tools.ail`).
- Sandbox/path controls via `AILANG_COMPOSE_AUTHOR_TOOLS_DENY_GLOBS`.
- Tool‑call parsing and typed malformed‑call handling.
- Premise ledger with budget accounting and helper queries (`ledger.ail`).
- Tests present in `ledger_test.ail`.

### Phase 2 — Author Loop Integration
- Multi‑turn author loop in `author_loop.ail` with one‑action‑per‑turn fence protocol (accepts `tool_call` or `ailang` fences).
- Budget‑aware continuation and terminal conditions.
- Event emission for TUI/runtime: `compose_author_tool_call`, `compose_author_tool_result`, `compose_author_ledger_snapshot`.
- Compose extension toggles and budget knobs wired in `compose.ail` (`AILANG_COMPOSE_AUTHOR_TOOLS`, `AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET`, etc.).

### Phase 3 — Validator Binding
- Certificate/premise binding logic in `validator.ail` — classifies points as ledger‑bound, snippet‑bound, or unbound.
- `validate_expected_output_with_context` returns both validation result and premise binding counters.
- Tests passing in `validator_test.ail`.

### Phase 4 — SF2/SF5 Interaction and Telemetry
- Compose telemetry enriched with premise binding counts (`premise_binding.ledger_bound`, `.snippet_bound`, `.unbound`).
- SF2 witness source tracked (`sf2_witness_source`).
- Ledger‑aware informalization toggle for claimcheck (`AILANG_COMPOSE_CLAIMCHECK_LEDGER_IN_INFORMALIZER`).

### Prompt and Protocol Support
- Author prompt documents tool‑call behavior in `prompts.ail`.
- Author‑loop prompt construction includes a summary of prior reads from the premise ledger.

## Session‑Specific Implementation Deltas
While working within the plan architecture, this session introduced:
- **Prompt conditioning quality**: Improved metadata fidelity, error‑context compaction to prevent retry‑prompt bloat.
- **Retry robustness**: Repeated‑signature reset handling for parse loops and type/effect‑row loops; targeted‑edit retry mode using previous snippet context before full reset.
- **Observability**: Sidecar snippet archival in `.motoko-store/snippets`, per‑invocation archive‑key behaviour to avoid cross‑run overwrites.
- **Completion quality gate**: Minimum substantive observed‑output gate (`AILANG_COMPOSE_MIN_OBSERVED_CHARS`) for analyse/summarise intents.

## Verification Performed
- Successful `ailang check` and `ailang test` runs on `prompts.ail`, `author_loop.ail`, `compose.ail`, `compose_test.ail`, `validator_test.ail`.
- Operational verification with `scripts/analyze_compose_meta.py` confirmed prompt‑size stabilization and improved archive‑key behaviour.

## Remaining Work (Relative to Original Plan)
- Default flip of `AILANG_COMPOSE_AUTHOR_TOOLS=1` not yet enacted (still env‑controlled).
- Documentation updates in `README.md` / `CLAUDE.md` not completed.
- Additional strict conformance fixtures for plan edge cases not fully produced.

## Key Files
- `src/core/ext/compose/author_tools.ail`
- `src/core/ext/compose/ledger.ail`
- `src/core/ext/compose/author_loop.ail`
- `src/core/ext/compose/prompts.ail`
- `src/core/ext/compose/validator.ail`
- `src/core/ext/compose/claimcheck.ail`
- `src/core/ext/compose/compose.ail`
- `src/core/ext/compose/compose_test.ail`
- `src/core/ext/compose/validator_test.ail`
- `scripts/analyze_compose_meta.py`

## Cross‑Document Concepts
This implementation touches several areas that may warrant dedicated concept pages:
- [[concepts/compose-author-tools]] — overall tool infrastructure and dispatch.
- [[concepts/premise-ledger]] — budget, reads history, and helper queries.
- [[concepts/author-loop]] — multi‑turn loop with fences and event emission.
- [[concepts/validator-binding]] — premises tied to ledger vs. snippet logic.
- [[concepts/claimcheck-ledger]] — ledger‑aware informalisation toggle.
- [[concepts/prompt-conditioning]] — techniques for prompt fidelity and error‑context compaction.
- [[concepts/snippet-archival]] — sidecar storage and archive‑key design.