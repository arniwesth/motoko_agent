## Code & Effect Graph (`ailang-graph`)

`tools/code-graph/` extracts a structural and effect graph for this repo's AILANG
source and emits a profile-aware SQL source index beside it. Static repo imports are
exact; calls and reachable effects are source-parsed approximations and every answer
carries metadata for staleness, coverage, and incomplete typed extraction.

Refresh the default core graph:

```bash
tools/code-graph/extract.sh
```

The default profile is `core`: `src/core/**`, excluding smoke scripts, examples,
`*_test.ail`, and `src/core/test/**`. Use `--profile=all` for the old broad graph or
`--include-tests` to include core tests. The full typed/effect pass uses
`ailang iface`; run `ailang lock` first when registry hydration is needed. Generated
artifacts live in `tools/code-graph/.out/`.

Query examples:

```bash
python3 tools/code-graph/query/cgq.py q importers src/core/ext/registry_generated
python3 tools/code-graph/query/cgq.py q callers dispatch_step
python3 tools/code-graph/query/cgq.py q reaches Net
python3 tools/code-graph/query/cgq.py q search dispatch_step
python3 tools/code-graph/query/cgq.py q search-chunk try_emergency_compaction
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/query/cgq.py sql "SELECT * FROM invokes WHERE to_slug LIKE '%try_emergency_compaction' LIMIT 50"
```

`ailang-graph` answers structural/effect questions. The source index answers
profile-aware SQL source search questions over `source_files`, `source_lines`, and
AILANG function-level `source_chunks`. Use `rg` for quick exact lookup; use SQL source
search when you need aggregation, stale-aware metadata, or joins.

Graph/effect joins from source chunks must use `source_chunks.func_slug = funcs.slug`
or `effect_edges.func_slug`; do not join through `chunk_slug`. Coarse joins through
`source_lines.module` are module-level and must be labeled that way.

Result metadata includes `approximate`, `stale`, `source_stale`, `coverage`, and
`incomplete`. Agents must not treat call/effect rows as compiler-derived facts, and
must treat `incomplete=true` as "unknown", not "no".

The `unimported` query means "not reachable via static imports from declared roots";
it never means dead or safe to delete.

## Project-memory concept edges (`concept_edges`)

`concept_edges` is a directed relation graph between `.agent` Markdown sections,
extracted by an LLM over semantic-nearest-neighbour candidate pairs. It answers
project-memory questions ("which plan implements this?", "what supersedes this
ADR?", "what is a prerequisite of this design?") rather than code questions.

Generate (embeddings must exist first; see `agent_semantic_poc.py`):

```bash
# directed relations -> JSONL cache (OpenRouter; ~$1.6, ~25 min for all .agent)
python3 tools/code-graph/query/agent_concept_edges.py --strategy llm \
  --backend openrouter --model deepseek/deepseek-chat \
  --cache tools/code-graph/.out/agent_concept_edges_llm.jsonl
# flatten the cache into the chDB-queryable CSV table
python3 tools/code-graph/query/agent_concept_edges.py \
  --cache tools/code-graph/.out/agent_concept_edges_llm.jsonl \
  --export-csv tools/code-graph/.out/concept_edges.csv
```

Query:

```bash
python3 tools/code-graph/query/cgq.py q implements source-index
python3 tools/code-graph/query/cgq.py q prereqs ADR-003
python3 tools/code-graph/query/cgq.py q supersedes Native_Tool_Calling
python3 tools/code-graph/query/cgq.py q edges dst
python3 tools/code-graph/query/cgq.py sql "SELECT from_path, to_path, confidence FROM concept_edges WHERE relation='implements' AND from_path != to_path ORDER BY confidence DESC LIMIT 20"
```

`concept_edges` rows are MODEL-DERIVED, not facts: each carries `relation`,
`confidence`, and `similarity`. cgq.py prints a `MODEL-DERIVED` banner and sets
`meta.model_derived`. Treat low-confidence rows as suggestions and audit before
relying on them. Relations are `prerequisite`, `implements`, `supersedes`,
`references` (undirected; `from_path`/`to_path` blank), and `none`. Many edges
are intra-document section pairs; add `from_path != to_path` for document-level
provenance. The table is a separate artifact from the AILANG graph and source
index — its freshness is not tracked by `extraction_status`.
