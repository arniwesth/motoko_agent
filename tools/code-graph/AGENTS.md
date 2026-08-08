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
`*_test.ail`, and `src/core/test/**`. Use `--profile=all` for the broad graph
(`src/**`, `scripts/**`, `examples/**`, and `packages/**`) or `--include-tests` to include core tests. The full typed/effect pass uses
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

## Layout projections (`layout`, `edges_agg`)

`tools/code-graph/layout/build_layout.py` generates two further tables into
`.out/`, and `extract.sh` runs it as its last step (deliberately without
`|| true` — a broken layout fails the refresh):

```
layout(node_id, level, x, y, radius, snapshot)
edges_agg(level, src_agg, dst_agg, kind, weight, exactness)
```

They are a deterministic containment layout of the **all** profile: nested
circle packing over the directory tree, area = `modules.n_funcs`, sibling order
by `sha256(node_path)`, coordinates quantized to 9 decimals against a unit root
circle. Same tree ⇒ byte-identical tables.

LOD levels are **path-prefix classes**: L0 is the first path segment, L1 the
two-segment prefix, L2 the module. A module shallower than a level's prefix
depth is its own aggregate at that level. Directories deeper than two segments
are packing containers: they get `layout` rows at level 2 and never appear in
`edges_agg`. Edge weights roll up exactly — `weight(n, A→B)` equals the sum of
its level `n+1` children, checked by the validator, never aggregated at render
time. `exactness` is `exact` for `imports` and `approximate` for `invokes`; a
consumer that draws them alike is lying at a glance.

```bash
python3 tools/code-graph/layout/build_layout.py          # rebuild (self-validating)
python3 tools/code-graph/layout/validate_layout.py       # 5 named rules over .out/
python3 tools/code-graph/layout/stability_probe.py --check
```

Freshness is keyed by the `snapshot` column, not by mtime: `cgq.py` recomputes
it from the current `extraction_status` and prints a `STALE:` banner when a
query touches `layout`/`edges_agg` and the keys disagree. Rebuild rather than
trust a bannered layout.

## DST trace overlay (`activity`, `tool_modules`, traces, heat)

The overlay attributes DST ledger-trace records to subject modules so dynamic
questions ("which modules does DST actually exercise?") become answerable
against the same store. Three generated artifacts, none committed:

```
.out/vocabulary.json              34 event-vocabulary rows, exported from AILANG
.out/traces/<profile>/<seed>.jsonl  one run's returned ledger trace (overlay format v1)
activity(seed, event_idx, record_key, subject_id, rule_kind)
tool_modules(key, kind, module)   tool/extension -> module map
```

```bash
# 1. export the vocabulary (needed by the validators; never grep the source for
#    these counts — a test fixture at dst_event_vocabulary.ail:807 makes them wrong)
ailang run --caps IO,FS --entry main scripts/dst/export_vocabulary.ail
# 2. export one trace per seed (one profile + one seed per invocation, always)
scripts/dst/run_export_trace.sh --seed 7
# 3. build activity for ONE profile, then render and validate
python3 tools/code-graph/overlay/build_activity.py --profile driver_only
python3 tools/code-graph/overlay/render_heat.py --seed 7
python3 tools/code-graph/overlay/validate_overlay.py
python3 tools/code-graph/query/cgq.py q touched 7
python3 tools/code-graph/query/cgq.py q divergence 7 11
```

`activity` is **per profile**: the schema has no profile or run column, so the
same seed under two profiles collides on every key. One `activity.csv` covers one
profile, and `build_activity.py --profile` is required, not optional. For the
same reason `q divergence` answers the **two-seed** case only — the same seed
across two code versions is the primary case and cannot be held by this schema.

`rule_kind ∈ {fixed, payload_routed, correlated, unattributed}` records *how* a
subject was derived, so views can weight by attribution quality without a fuzzy
confidence number. Records are never dropped: an unmapped tool, extension or
`ErrorEvent.source` yields an explicit `unattributed` row **and** a counted token
in the build report. Treat a rising unattributed count as a curated map falling
behind, not as noise.

Freshness for `activity` is keyed to trace files, not to `extraction_status`, so
queries touching it report a trace-file count in `meta` rather than an
extraction-staleness banner. The heat renderer checks `layout` freshness itself
and banners the canvas.

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
