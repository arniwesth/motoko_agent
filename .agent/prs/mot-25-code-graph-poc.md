# MOT-25 Code Graph POC

Base branch: `origin/main`

## Summary

This branch adds a proof-of-concept AILANG code graph and source index under
`tools/code-graph/`. It extracts module, import, function, call, type, and effect
metadata into CSVs, queries them through embedded chDB, and adds project-memory
semantic/concept graph experiments for `.agent` documentation.

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
- Adds the `.agent` semantic search PoC (`agent_semantic_poc.py`) and semantic
  benchmark queries for embedding-backed project-memory retrieval.
- Adds `tools/mmd2svg/`, a small Bun/Mermaid utility for rendering Mermaid diagrams
  to SVG.
- Updates the project AILANG requirement and lockfile to `0.26.0`.
- Updates install prerequisites to install `chdb` for embedded ClickHouse queries.
- Adds `.marimo.toml` for large graph/notebook visualization output.

## Notes

- Runtime `src/core/` compaction changes are intentionally not part of this PR.
- `.motoko/config/ollama/` changes are intentionally not part of this PR.
- Agents currently need to be pointed at `tools/code-graph/AGENTS.md` to know how
  to use the code-graph tooling.
- There are pending AILANG feature requests that would improve precision: structured
  `ailang debug ast --json` output for replacing the heuristic source-parsed call
  graph, and public stdlib iface/per-symbol effect data for finer effect seeding.
  These are called out in
  `.agent/projects/002_code_graph/AILANG_Code_Graph.md` under "Upstream feature
  request" and "Phase 4: AST/JSON Upgrade", and the stdlib iface ask is also noted
  in `tools/code-graph/extractor/seed_catalog.py`. Until those land, call/effect
  answers are explicitly approximate and carry coverage metadata.

## Verification

- `python3 -m pytest tools/code-graph/tests`
