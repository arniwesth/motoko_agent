# ADR-003: SQL Source Index for Motoko Code Search

Date: 2026-06-28
Status: Proposed

## TL;DR

Add a **source index** beside `ailang-graph`: load the repo's source text into
chDB/ClickHouse-queryable tables so agents can use SQL for code search instead of
only file-oriented tools such as `rg`/grep.

This is intentionally adjacent to, not a replacement for, ADR-002:

- `ailang-graph` answers structure/effect questions: imports, calls, typed exports,
  reachable effects.
- The source index answers text and context questions: lines/chunks containing terms,
  TODO inventories, duplicated literals, symbol-adjacent comments, and joins from text
  hits back to modules/functions/effects.

v1 should stay simple and CSV-backed through the existing chDB CLI. Native ClickHouse
full-text indexes are a later materialized-table upgrade, because chDB querying
`file(..., 'CSVWithNames')` over CSVs does not give persistent MergeTree text indexes.

## Context

Motoko now has `tools/code-graph/`, which emits CSVs and queries them with embedded
chDB. That gives agents ClickHouse SQL over structural data, but source text search is
still mostly file-based (`rg`, `grep`, editor search). File-based search is excellent
for fast local lookup, but it is awkward for questions that need aggregation and joins:

- Which modules mention a term and also reach `Net`?
- Which exported funcs have comments containing "deprecated" nearby?
- Which literals are duplicated across modules?
- Which files mention `ToolResultEnvelope`, grouped by graph module and root status?
- Which smoke/example files contain an old API shape?

ClickHouse has documented full-text search support built around text indexes and token
queries. That is attractive long-term. For this repo's current scale, however, the
first useful step is not to require a ClickHouse server or persistent database; it is
to expose source text as tables under the existing chDB/CSV query surface.

## Decision

Build a `source-index` layer under `tools/code-graph/` and emit source-text CSVs into
the same `.out/` directory as ADR-002 artifacts.

### Tables

All tables are `CSVWithNames` and keyed by repo-relative paths. The source profile
matches the active graph extraction profile (`core`, `all`, `smoke`, plus
`include_tests`) so staleness and search scope remain consistent.

**`source_files.csv`**

| column | notes |
|---|---|
| `path` | repo-relative path with extension |
| `module` | module slug for `.ail`; empty for non-AILANG files |
| `kind` | `ailang` / `typescript` / `markdown` / `toml` / `json` / `shell` / `other` |
| `bytes` | file size |
| `sha256` | content hash |
| `n_lines` | line count |
| `profile` | extraction profile |
| `include_tests` | `0`/`1` |

**`source_lines.csv`**

| column | notes |
|---|---|
| `path` | repo-relative path |
| `module` | module slug for `.ail`; empty otherwise |
| `line_no` | 1-based |
| `line` | raw line text, newline stripped |
| `trimmed` | stripped line text |
| `is_comment` | best-effort per file kind |
| `profile` | extraction profile |

**`source_chunks.csv`**

| column | notes |
|---|---|
| `chunk_slug` | stable slug, e.g. `{module}#func:{name}` or `{path}#lines:{start}-{end}` |
| `path` | repo-relative path |
| `module` | module slug for `.ail`; empty otherwise |
| `kind` | `func` / `type` / `module` / `file` |
| `name` | symbol name when known |
| `start_line` | 1-based |
| `end_line` | inclusive |
| `text` | chunk text |

For AILANG, `source_chunks.csv` should reuse the source parser's top-level spans so
function chunks join cleanly to `funcs.slug`. For non-AILANG files, v1 can use
whole-file chunks and optional fixed-size line windows later.

### Query Surface

Extend `tools/code-graph/query/cgq.py` with source search named queries:

```bash
python3 tools/code-graph/query/cgq.py q search dispatch_step
python3 tools/code-graph/query/cgq.py q search-line ToolResultEnvelope
python3 tools/code-graph/query/cgq.py q search-chunk "try_emergency_compaction"
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
```

Initial implementation should use ClickHouse string/token functions over CSV views,
for example:

```sql
SELECT path, line_no, line
FROM source_lines
WHERE positionCaseInsensitive(line, 'dispatch_step') > 0
ORDER BY path, line_no
LIMIT 200
```

When token semantics are better than substring semantics, use available ClickHouse
token functions (`hasToken`, `tokens`, or equivalent supported by the installed chDB
version) after validating them locally. Do not assume the full server feature set is
available in chDB without a contract check.

### Materialized Full-Text Upgrade

The ClickHouse full-text-search blog is a good direction for later, but native text
indexes require real ClickHouse tables, typically MergeTree-family tables with a text
index. CSV views via `file(...)` are stateless and do not persist indexes.

Therefore:

- v1 uses CSV-backed chDB search. This is enough for this repo's current size and keeps
  the same zero-server prerequisite as ADR-002.
- v2 may add `tools/code-graph/index.sh --materialize` to create a local
  ClickHouse/chDB database with indexed tables, if CSV scans become slow or token
  search quality matters.
- The CLI should report whether a query used `csv_scan` or `text_index` in `meta`.

## Scope

### In v1

- Index AILANG files in the active graph profile.
- Optionally include project metadata and host files that matter to root detection:
  `src/tui/src/*.ts`, `ailang.toml`, `config.json`, `AGENTS.md`, and selected scripts.
- Emit `source_files.csv`, `source_lines.csv`, and `source_chunks.csv`.
- Add named queries for line/chunk search.
- Join search results to graph tables by `module` and `func_slug` where available.
- Reuse `cgq.py` staleness/profile metadata.

### Out of Scope for v1

- Replacing `rg`. Agents should still use `rg` for quick exact file lookup.
- Persistent ClickHouse databases or server setup.
- Ranking/relevance claims beyond simple ordering and explicit SQL aggregates.
- Semantic embeddings or vector search.
- Parsing every host language deeply.

## Example Queries

Find code lines mentioning a symbol:

```sql
SELECT path, line_no, line
FROM source_lines
WHERE positionCaseInsensitive(line, 'dispatch_step') > 0
ORDER BY path, line_no;
```

Join text hits to the effect graph:

```sql
SELECT DISTINCT l.path, l.line_no, l.line, e.effect
FROM source_lines l
JOIN funcs f ON l.module = f.module
JOIN effect_edges e ON e.func_slug = f.slug
WHERE positionCaseInsensitive(l.line, 'httpGet') > 0
  AND e.effect = 'Net'
ORDER BY l.path, l.line_no;
```

Inventory TODO/FIXME by module:

```sql
SELECT module, count() AS n
FROM source_lines
WHERE match(line, '(?i)TODO|FIXME')
GROUP BY module
ORDER BY n DESC, module;
```

Find duplicated numeric literals in AILANG source:

```sql
SELECT literal, countDistinct(path) AS files, groupArrayDistinct(path) AS paths
FROM
(
  SELECT path, extractAll(line, '\\b[0-9]{3,}\\b') AS literals
  FROM source_lines
  WHERE kind = 'ailang'
)
ARRAY JOIN literals AS literal
GROUP BY literal
HAVING files > 1
ORDER BY files DESC, literal;
```

## Consequences

Positive:

- Agents can answer search questions with SQL joins instead of stitching grep output.
- Source hits become profile-aware and stale-aware like the graph.
- Text search can be combined with structural/effect metadata.
- The implementation is cheap because the code graph already has chDB, CSV emission,
  staleness metadata, and a CLI.

Negative:

- CSV scans do not use ClickHouse native text indexes.
- SQL search is more verbose than `rg` for simple exact lookups.
- Large multiline chunks can make CSVs bulky; quoting must be correct.
- Token-search behavior depends on the installed chDB/ClickHouse version and must be
  validated locally.

## Rejected Alternatives

### Replace `rg` with SQL search

Rejected. `rg` remains the fastest and simplest tool for many exact lookups. The
source index is for joins, aggregation, stable machine-readable results, and
profile-aware search.

### Store source only in one giant `source_text` table

Rejected for v1. Line-level results are easier to display, chunk-level rows are better
for function/module context, and file-level rows are needed for hashes/staleness.

### Start with a persistent ClickHouse database and text indexes

Deferred. It is the right performance path if the corpus grows, but it adds a local
database lifecycle and may not fit the current chDB-only portability goal. CSV-backed
tables are enough to prove value first.

### Add vector/embedding search

Rejected for this ADR. Embeddings solve a different problem, add model/runtime
dependencies, and are not needed for deterministic code search.

## Acceptance Criteria

- `tools/code-graph/extract.sh` emits `source_files.csv`, `source_lines.csv`, and
  `source_chunks.csv` for the active profile.
- `cgq.py status` reports source row counts and the active profile.
- `cgq.py q search dispatch_step` returns line hits with path and line number.
- A source search can join to `funcs`/`effect_edges` in one SQL query.
- Staleness is profile-aware: editing a file outside the active profile does not stale
  the active source index.
- CSV quoting handles multiline chunks and commas/quotes in source.
- No ClickHouse server is required for v1.

