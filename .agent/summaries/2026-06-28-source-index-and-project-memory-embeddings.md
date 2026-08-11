# 2026-06-28 - Source index and project-memory embeddings

## Context

This session started from the reviewed ADR-003 handoff to implement the SQL source
index beside `ailang-graph`, then expanded into a project-memory research thread:
loading `.agent` research, ADRs, plans, handoffs, and summaries into searchable
tables and semantic embeddings.

The motivating split remained:

- `ailang-graph` answers structural and effect questions over AILANG source.
- The source index answers profile-aware, stale-aware SQL source search questions.
- The project-memory prototype explores semantic recall over `.agent` documents.

## Source index outcome

Implemented the ADR-003 source index under `tools/code-graph/`.

Generated source tables:

- `source_files.csv`
- `source_lines.csv`
- `source_chunks.csv`

Important behavior:

- CSV-backed chDB remains the storage/query model.
- `source_files.sha256` drives source staleness; mtimes are not correctness signals.
- Host files are indexed as file and line rows only.
- AILANG function chunks use `source_parser.func_spans`.
- Graph joins use `source_chunks.func_slug = funcs.slug`; `chunk_slug` is human-readable only.
- Search feature-detects token support and falls back to substring search with explicit metadata.

Query surface additions:

```sh
python3 tools/code-graph/query/cgq.py q search dispatch_step
python3 tools/code-graph/query/cgq.py q search-line dispatch_step
python3 tools/code-graph/query/cgq.py q search-chunk try_emergency_compaction
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
```

The status output now reports both graph and source metadata. Source staleness is
separate from graph/effect staleness.

## Source index verification

The focused test suite and smoke passed during implementation:

```sh
pytest -q tools/code-graph/tests
tools/code-graph/smoke.sh
```

Key acceptance behavior was covered:

- multiline CSV round-trip
- quote/comma/newline handling
- comment detection by file kind
- AILANG chunk boundaries at top-level `func`, `type`, `module`, and `import`
- host-only line indexing
- profile and `include_tests` filtering
- hash-based stale detection for an indexed host fixture named `AGENTS.md`
- token-probe fallback metadata
- source/effect joins through `func_slug`

## Project-memory research doc

Added and iteratively expanded:

```text
.agent/projects/002_code_graph/RESEARCH-project-memory-index.md
```

The research note proposes loading `.agent` docs, git history, and existing
source/code graph evidence into a ClickHouse/chDB-backed project-memory index.

Core design principle:

> ClickHouse stores inspectable evidence, not final conclusions.

The simple v1 shape stays CSV-backed and SQL-first:

- `agent_docs`
- `agent_doc_sections`
- `agent_doc_refs`
- `git_commits`
- `git_changed_files`
- `git_hunks`
- derived evidence tables such as `plan_code_evidence`

The document also records when CSV-backed chDB is enough, when to materialize local
ClickHouse tables, and when additional layers such as graph traversal, vectors, or
LLM reranking become justified.

## Embedding PoC

Added:

```text
tools/code-graph/query/agent_semantic_poc.py
```

The PoC embeds Markdown sections from `.agent/**/*.md` and searches them by cosine
similarity. It supports:

- Ollama/local EmbeddingGemma
- OpenRouter embeddings
- `google/gemini-embedding-2`
- batched embedding calls
- cache files under `tools/code-graph/.out/`
- context-prefixed section text
- tiny-section merging via `--min-section-chars`
- optional lexical boosting
- timing, token, and cost reporting

Ollama had to be run on the Mac host to use local hardware acceleration. Port
`11434` was occupied by VS Code's host process, so Ollama was started on another
port:

```sh
OLLAMA_HOST=127.0.0.1:11435 ollama serve
```

## OpenRouter/Gemini findings

OpenRouter access to Gemini Embedding 2 worked with:

```sh
--backend openrouter --model google/gemini-embedding-2 --dimension 768
```

Measured cold indexing run over `.agent/**/*.md`:

```text
sections: 2990
embedding_requests: 48
elapsed_seconds: 55.041
embedded_chars: 3,149,796
api_usage.prompt_tokens: 861,939
estimated_cost_usd: 0.172388
```

Warm cached query:

```text
cache_misses: 0
embedding_requests: 1
elapsed_seconds: 1.544
api_usage.prompt_tokens: 12
estimated_cost_usd: 0.000002
```

The practical finding was that full `.agent` reindexing is cheap enough to do
occasionally with OpenRouter/Gemini, while day-to-day queries are nearly free once
document vectors are cached.

## Marimo embedding map

Added:

```text
tools/code-graph/notebooks/agent_embedding_map.py
tools/code-graph/notebooks/.marimo.toml
```

The notebook visualizes cached `.agent` section embeddings with Bokeh. It defaults
to dark mode and supports:

- backend selection: `ollama` or `openrouter`
- model and dimension controls
- derived cache path selection
- color-by mode: area, project, or kind
- PCA projection
- t-SNE projection
- t-SNE perplexity control

Run command:

```sh
.venv-marimo/bin/marimo edit tools/code-graph/notebooks/agent_embedding_map.py --host 0.0.0.0 --port 2718
```

Marimo install needed a virtual environment because system Python is externally
managed.

## Semantic benchmark

Added:

```text
tools/code-graph/query/agent_semantic_benchmark.py
tools/code-graph/query/agent_semantic_benchmark_queries.json
```

The benchmark evaluates expected-hit retrieval over `.agent/**/*.md` and reports:

- recall@k
- MRR@k
- cache misses
- embedding request count
- elapsed time
- estimated and API-reported token/cost data

OpenRouter/Gemini benchmark result from the user run:

```text
queries: 12
sections: 2990
k: 10
recall_at_k: 1.0
mrr_at_k: 0.9583
query_cache_misses: 12
embedding_requests: 12
elapsed_seconds: 8.39
api_usage.prompt_tokens: 201
estimated_cost_usd: 0.000040
```

Local EmbeddingGemma was good enough for private local recall, but Gemini Embedding
2 ranked several expected results better and produced a visually cleaner embedding
map in the notebook.

## DST overlap query

Used the cached OpenRouter document embeddings to compare `.agent/projects/001_DST/`
sections against the rest of `.agent`.

Strong DST-family overlaps:

- `.agent/research/DST/motoko-dst-generalized-system.md`
- `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md`
- `.agent/plans/DST_v1_Motoko_Core.md`

Most meaningful non-DST overlap:

- `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md`

The ADR-002 overlap is real rather than merely lexical: the code graph was designed
to answer DST questions about import reachability, `dispatch_step` callers, and
effect reachability.

Other weaker adjacent hits included local evaluation, multi-profile config, and
MLflow observability plans, mostly through shared test/invariant/acceptance-criteria
language rather than direct DST design dependency.

## Useful commands

Semantic search with cached OpenRouter/Gemini vectors:

```sh
python3 tools/code-graph/query/agent_semantic_poc.py \
  --backend openrouter \
  --model google/gemini-embedding-2 \
  --dimension 768 \
  --cache tools/code-graph/.out/agent_section_embeddings_openrouter_benchmark.jsonl \
  "plans related to source_chunks and func_slug"
```

Benchmark:

```sh
python3 tools/code-graph/query/agent_semantic_benchmark.py \
  --backend openrouter \
  --model google/gemini-embedding-2 \
  --dimension 768 \
  --cache tools/code-graph/.out/agent_section_embeddings_openrouter_benchmark.jsonl \
  --k 10
```

## Follow-up ideas

- Formalize document-to-document overlap as a reusable command instead of an ad hoc
  Python snippet.
- Add graded benchmark relevance labels; the ClickStack case showed that strict
  expected-hit labels can undercount legitimate alternate top results.
- Add ClickHouse-backed `.agent` tables before relying too heavily on vectors.
- Keep OpenRouter/Gemini and local EmbeddingGemma as interchangeable recall backends.
- Use a local generative model such as DeepSeek V4 Flash for reranking, summaries,
  entity extraction, and explanation, rather than as the primary vector index.
