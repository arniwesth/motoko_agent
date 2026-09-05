# 2026-06-29 - 3D concept graph and LLM-extracted relation edges

## Context

Continued the project-memory thread from the 2026-06-28 session. Starting point was
the cached `.agent` section embeddings (EmbeddingGemma + OpenRouter/Gemini) and the
research note `RESEARCH-project-memory-index.md`. This session turned those embeddings
into an interactive 3D concept graph, then added a directed (LLM-extracted) relation
layer and wired it into the `cgq.py` / chDB query surface — the "v4 project-memory
graph" the research doc anticipated.

Driven largely by a reference visualization: The Palindrome's
"I Built the Knowledge Graph of Machine Learning" (`youtube WR-VyH0pIgs`,
`github.com/the-palindrome/ml-knowledge-graph`), which uses a directed prerequisite
DAG rendered with `3d-force-graph`/three.js in force/hierarchical/cluster/radial
layouts. Key insight taken from it: a *hierarchical order* needs *directed*
relations; cosine similarity is symmetric and cannot produce one.

## What was built

### Notebook: `tools/code-graph/notebooks/agent_concept_graph.py`

A new sibling to the 2D `agent_embedding_map.py`. Reuses the same cache-loading,
`split_markdown` chunking, and `area`/`project`/`kind` derivation. Adds:

- 3D projection (PCA / t-SNE) of normalized section vectors, rendered with Plotly.
- **kNN edges in cosine space** (not 2D proximity) so edges mean semantic similarity.
- **Concept coloring** instead of folder location:
  - k-means on vectors (count slider), and
  - graph-community detection on the kNN graph, with a **Community algorithm**
    dropdown: `louvain` (default, balanced, `resolution` + `seed`), `greedy
    modularity` (slower, larger communities), `label propagation` (fastest, can
    fragment/collapse).
  - Each concept auto-labeled by distinctive TF-IDF terms (headings weighted x2)
    with node count, e.g. `simulation, dst, deterministic (39)`.
- **`dag (hierarchical)` layout**: consumes directed edges (below), computes
  topological depth via **SCC condensation** (robust to LLM-introduced cycles —
  2,987 nodes condensed to 1,733 SCCs), lays nodes out on **one ring per level**
  ordered by concept + PCA-1 so same-concept arcs band together. This reproduces the
  reference video's tapered "spinning-top" shape (~32 levels on the full corpus).
- Controls added over the session: node-size slider, **max edges per node** (top-N by
  similarity, union rule, default 3 — trims 11.5k edges to ~6.4k), min relation
  confidence, directed-edges cache path.
- **Click-to-focus**: main graph wrapped in `mo.ui.plotly`; clicking a node (or using
  the searchable **Focus node** dropdown) renders a focus panel below showing only
  that node + its incident edges, split into Downstream / Upstream for DAG mode.

### Extraction script: `tools/code-graph/query/agent_concept_edges.py`

Turns undirected similarity into directed relations:
`prerequisite | implements | supersedes | references(undirected) | none`.

- Candidate pairs restricted to each section's kNN neighbours (18,241 pairs for all
  `.agent`, not O(n^2)).
- `--strategy llm` (OpenRouter or Ollama chat) classifies each pair batch; results
  cached to `.out/agent_concept_edges_llm.jsonl` keyed by the unordered section-hash
  pair (resume-safe, like the embedding cache).
- `--strategy structural` derives edges from heading nesting — free, deterministic,
  offline test path (shallow: ~3 levels vs. the LLM's 32).
- **Concurrency** via `ThreadPoolExecutor` (`--concurrency`, default 8); ~4.6x faster
  than sequential, per-batch error isolation, lock-guarded flushed writes.
- `--export-csv` flattens the JSONL cache into the chDB-queryable CSV.

### Query surface: `cgq.py` + `concept_edges` table

- `concept_edges.csv` (18,241 rows) registered in `SCHEMAS`, auto-discovered as a
  chDB view like every other table.
- Named queries: `q implements <term>`, `q prereqs <term>`, `q supersedes <term>`,
  `q edges <term>` (audit view), plus raw `sql`.
- **Evidence-first labeling** per AGENTS.md: concept queries print a `MODEL-DERIVED`
  banner, set `meta.model_derived`, carry `relation`/`confidence`/`similarity`; the
  irrelevant AILANG-graph staleness banner is suppressed for them.
- Documented in `tools/code-graph/AGENTS.md` (new "Project-memory concept edges"
  section: regenerate, query, caveats).

## Full sweep results

```
pairs judged:     18,241 (0 failed batches)
model:            deepseek/deepseek-chat (OpenRouter)
concurrency 12, batch-pairs 16, 1,128 requests
time:             ~23 min   cost: ~$1.56 total (incl. $0.018 trial)
relations:        6,872 prerequisite | 3,733 implements | 918 supersedes
                  5,555 references | 1,163 none  -> 11,511 directed edges
full DAG:         2,944 / 2,987 nodes in hierarchy, 32 levels deep
cross-doc only:   1,223 implements | 546 prerequisite | 529 supersedes
```

Spot-checked cross-document provenance is genuinely correct, e.g.
`AILANG_Source_Index` plan -> implements -> `HANDOFF-source-index-implementation`;
`Motoko_Benchmark_Harness` -> `2026-04-27-motoko-benchmark-harness`;
`ADR-001-deterministic-simulation-testing` -> `motoko-dst-generalized-system`.

## Decisions made

- **Notebook upgrade, not a standalone web app** (user choice). Trade-off: keeps the
  current workflow but Plotly is not a true graph engine — no in-place click-highlight
  or live force simulation. Focus shows in a panel below rather than dimming the main
  graph (avoids a marimo reactive loop).
- **LLM-extracted relations, not structural/centrality** (user choice). Structural
  stays as a free baseline/test path.
- **deepseek/deepseek-chat** chosen for extraction: the research doc nominates DeepSeek
  for reranking/extraction; the task is cheap structured classification where cost
  dominates. Validated on a 200-pair trial before the full sweep. The script is
  `--model`-agnostic; any OpenRouter chat model or local Ollama works.
- Build (b) (query surface) over (a) (more notebook controls): aligns with the
  project's actual center of gravity (an agent-queryable evidence warehouse), makes
  the $1.56 reusable beyond one notebook, and enforces evidence-first labeling.

## Gotchas / lessons

- **marimo multiple-definition rule**: a bare (non-`_`) variable assigned in two cells
  makes marimo refuse to run *both*, surfacing as a confusing `NameError` two cells
  away. Fix: prefix all cell-internal temporaries with `_`; only export bare names a
  cell genuinely shares. A standing AST check (no name defined in >1 cell) caught every
  regression this session.
- **3D Plotly clicks in marimo are best-effort** (box/lasso selection is 2D-only);
  the Focus-node dropdown is the reliable fallback. Click payload handled via
  `customdata` (df index) with coordinate-match fallback.
- Large figures hit marimo's output cap (~8.5 MB for 2,944 nodes + 11.5k edges). Fixed
  with `output_max_bytes = 25_000_000` in `.marimo.toml` + rounding coordinates to 3
  decimals (cuts edge-trace bytes ~3x).
- DAG mode must **not** random-sample to `max_points` (it would gut the hierarchy);
  sampling is skipped when projection is dag.
- Confidence from the model is uniformly high (~all >= 0.7), so the confidence slider
  does not thin the graph — the top-N-per-node similarity cap is the real density lever.

## Useful commands

Run the notebook (output cap raised for the dense DAG figure):

```sh
MARIMO_OUTPUT_MAX_BYTES=25000000 .venv-marimo/bin/marimo edit \
  tools/code-graph/notebooks/agent_concept_graph.py --host 0.0.0.0 --port 2723
```

Regenerate the directed edges and CSV:

```sh
export OPENROUTER_API_KEY=...
python3 tools/code-graph/query/agent_concept_edges.py --strategy llm \
  --backend openrouter --model deepseek/deepseek-chat \
  --batch-pairs 16 --concurrency 12 \
  --cache tools/code-graph/.out/agent_concept_edges_llm.jsonl
python3 tools/code-graph/query/agent_concept_edges.py \
  --cache tools/code-graph/.out/agent_concept_edges_llm.jsonl \
  --export-csv tools/code-graph/.out/concept_edges.csv
```

Query:

```sh
python3 tools/code-graph/query/cgq.py q implements source-index
python3 tools/code-graph/query/cgq.py q prereqs ADR-003
python3 tools/code-graph/query/cgq.py sql "SELECT from_path, to_path, confidence FROM concept_edges WHERE relation='implements' AND from_path != to_path ORDER BY confidence DESC LIMIT 20"
```

## Caveats on the data

`concept_edges` are cheap-model approximations, not facts (AGENTS.md is explicit that
model-derived rows must be labeled). Many edges are intra-document section pairs (add
`from_path != to_path` for document-level provenance), and prerequisite direction on
ambiguous pairs will not always be right. The `q edges` view and the per-row
confidence exist precisely for auditing before relying on any specific claim.

## Follow-up ideas

- Load `concept_edges` into the planned ClickHouse-materialized project-memory tables
  and join against `source_chunks` / `git_commits` (needs a `git_commits` CSV).
- Add directional arrowheads (Plotly cones) so DAG flow reads without relying on the
  vertical axis.
- Local-Ollama extraction backend to make re-runs free.
- A graded-relevance audit pass over a sample of edges to estimate precision per
  relation kind before trusting aggregates.
- Consider the standalone `3d-force-graph` web app if richer interaction
  (in-place upstream highlighting, force/radial layouts) becomes worth it.
