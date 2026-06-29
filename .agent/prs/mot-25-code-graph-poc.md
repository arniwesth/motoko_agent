# MOT-25 Code Graph POC

Base branch: `origin/main`

## Summary

This branch adds a proof-of-concept AILANG code graph and source index under
`tools/code-graph/`. It extracts module, import, function, call, type, and effect
metadata into CSVs, queries them through embedded chDB, and adds project-memory
semantic/concept graph experiments for `.agent` documentation.

The branch also includes compaction hardening in the agent loop: system messages are
pinned outside compaction, compaction tiers can use provider-reported input token
counts, and token estimates account for serialized tool-call payloads plus output
headroom.

## Changes

- Adds `tools/code-graph/` with:
  - profile-aware extraction for core, smoke, and all-source graphs;
  - structural parsing for AILANG modules, imports, functions, constructors, calls,
    std calls, and source chunks;
  - optional `ailang iface` enrichment for typed signatures, type usage, declared
    effects, and reachable effect edges;
  - chDB-backed query CLI with status metadata, staleness detection, source search,
    effect queries, and model-derived concept-edge queries;
  - visualization and Marimo notebook experiments for code, embedding, and concept
    graph exploration;
  - tests and smoke fixtures for parser, source index, query, staleness, classifier,
    and effect-oracle behavior.
- Adds `.agent/tools/code-graph-refresh.ts` and `.agent/tools/code-graph-query.ts`
  wrappers for refreshing and querying the code graph from agent workflows.
- Adds code-graph ADRs, handoff notes, research notes, and session summaries covering
  the architecture, ClickHouse/chDB source index, embeddings, and concept-edge work.
- Adds `tools/mmd2svg/`, a small Bun/Mermaid utility for rendering Mermaid diagrams
  to SVG.
- Updates install prerequisites to require AILANG `0.26.0` and install `chdb`.
- Updates `.gitignore` and `.marimo.toml` for code-graph outputs, Python caches,
  Marimo artifacts, and local visualization state.
- Hardens runtime compaction by:
  - separating system messages from mutable conversation history before extension and
    structural compaction;
  - re-prepending the system prefix before provider calls;
  - tracking the provider's last `input_tokens`;
  - using actual input-token usage for compaction thresholds when available;
  - counting tool-call argument payloads in fallback token estimates;
  - reserving output headroom when computing usage percentage.
- Adds an Ollama compaction profile at `.motoko/config/ollama/compaction_ai.json`.
- Includes MOT-24 deterministic simulation testing research/ADR material that is
  present on this branch.

## Verification

- `python3 -m pytest tools/code-graph/tests`
