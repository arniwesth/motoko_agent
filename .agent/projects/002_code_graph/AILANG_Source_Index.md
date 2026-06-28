# Implementation Plan: SQL Source Index for `ailang-graph`

Date: 2026-06-28
Status: Plan, not implementation
Source of truth: `.agent/projects/002_code_graph/ADR-003-clickhouse-source-index.md`

This plan turns ADR-003 into concrete, phased work for a SQL source index beside
`ailang-graph`. It extends the existing `tools/code-graph/` project; it does not
replace the structural/effect graph. `ailang-graph` answers imports, calls, typed
exports, and reachable effects. The source index adds profile-aware, stale-aware SQL
search over source files, lines, and AILANG function chunks.

v1 remains CSV-backed through chDB `file(..., 'CSVWithNames')`. There is no
ClickHouse server, persistent database, native text index, embeddings, vector search,
or host-language deep parser in v1.

## Fixed Decisions

- Location: implement under `tools/code-graph/`; generated CSVs go to
  `tools/code-graph/.out/`.
- Tables: emit `source_files.csv`, `source_lines.csv`, and `source_chunks.csv`.
- Query model: chDB CSV views, using the existing `cgq.py` query surface.
- Profile model: source index scope follows the active graph profile and
  `--include-tests`.
- AILANG chunks: reuse `source_parser.func_spans`; do not invent a second span parser.
- Slugs: graph joins use `source_chunks.func_slug = symbol_slug(module, name)`, never
  `chunk_slug`.
- Host files: v1 indexes host files at line level only; no whole-file host chunks.
- Staleness: source freshness is based on stored `sha256` in `source_files.csv`.
  mtime may only be an optimization before hashing.
- chDB version: not pinned. Token search must feature-detect support and fall back to
  substring search with explicit metadata.
- Query metadata: source staleness and graph/effect incompleteness are distinct.
  Do not collapse them back into the current single `meta.stale` flag.

## Exact CSV Schemas

Add these `cgq.py SCHEMAS` entries exactly.

```python
"source_files": "path String, module String, lang String, bytes Int64, sha256 String, n_lines Int64, profile String, include_tests UInt8",
"source_lines": "path String, module String, lang String, line_no Int64, line String, is_comment UInt8, profile String, include_tests UInt8",
"source_chunks": "chunk_slug String, func_slug String, path String, module String, lang String, kind String, name String, start_line Int64, end_line Int64, text String, profile String, include_tests UInt8",
```

`source_files.csv` fields:

| field | type | notes |
|---|---:|---|
| `path` | String | repo-relative path |
| `module` | String | module slug for `.ail`, empty for host files |
| `lang` | String | `ailang`, `typescript`, `markdown`, `toml`, `json`, `shell`, or `other` |
| `bytes` | Int64 | byte length of file contents |
| `sha256` | String | exact content hash |
| `n_lines` | Int64 | line count |
| `profile` | String | active graph/source profile |
| `include_tests` | UInt8 | `0` or `1` |

`source_lines.csv` fields:

| field | type | notes |
|---|---:|---|
| `path` | String | repo-relative path |
| `module` | String | module slug for `.ail`, empty for host files |
| `lang` | String | denormalized file language |
| `line_no` | Int64 | 1-based |
| `line` | String | raw line text with newline stripped |
| `is_comment` | UInt8 | best-effort comment line flag |
| `profile` | String | active profile |
| `include_tests` | UInt8 | `0` or `1` |

`source_chunks.csv` fields:

| field | type | notes |
|---|---:|---|
| `chunk_slug` | String | human-readable slug, e.g. `{module}#func:{name}` |
| `func_slug` | String | graph join key: `{module}#{name}` for funcs, empty otherwise |
| `path` | String | repo-relative path |
| `module` | String | module slug |
| `lang` | String | `ailang` for v1 chunks |
| `kind` | String | `func` in v1 |
| `name` | String | function name |
| `start_line` | Int64 | 1-based |
| `end_line` | Int64 | inclusive |
| `text` | String | chunk text, multiline CSV quoted |
| `profile` | String | active profile |
| `include_tests` | UInt8 | `0` or `1` |

Update `extraction_status.csv` for source schema versioning:

```python
"extraction_status": "module String, iface_status String, iface_detail String, iface_error String, built_at String, ailang_version String, graph_schema Int64, source_schema Int64, iface_schema String, profile String, include_tests Int64",
```

`source_schema` is the `SOURCE_SCHEMA` value recorded on every status row. A schema
bump must make the source index stale.

## Phase 0: Contracts And Smokes

Goal: define the source-index contract and prove the chDB functions used by named
queries before extraction is added.

Ordered tasks:

1. Add source-index constants to `tools/code-graph/extractor/config.py`:
   - `SOURCE_SCHEMA = 1`
   - a small explicit host-file include set by active profile
2. Define the initial host-file set as profile-aware, not global:
   - every profile includes root operational metadata:
     - `AGENTS.md`
     - `ailang.toml`
     - `config.json`
     - `scripts/install-prerequisites.sh`
     - `tools/code-graph/README.md`
     - `tools/code-graph/**/*.py`
     - `tools/code-graph/**/*.sh`
   - `core` additionally includes host files that affect core/root detection when
     present, such as `src/tui/src/**/*.ts`
   - `all` includes the `core` host set plus scripts/examples host files selected by
     explicit globs
   - `smoke` includes only smoke/example host files plus root operational metadata
   - the extractor must record only the active set in `source_files.csv`; files not in
     that active set cannot stale the active source index
3. Extend extraction status with source schema metadata:
   - add `source_schema Int64` to `extraction_status.csv`
   - update the `cgq.py SCHEMAS["extraction_status"]` entry at the same time
   - add `SOURCE_SCHEMA = 1` to `cgq.py`, mirroring the existing standalone
     `GRAPH_SCHEMA = 1` constant
4. Add a committed chDB source smoke:
   - new file: `tools/code-graph/tests/smoke_chdb_source.py`
   - verify `positionCaseInsensitive`, `match` with `(?i)` and `\b`, `extractAll`,
     `trimBoth`, `hasToken`, and `tokens`
   - verify multiline CSV round-trip through `CSVWithNames` for embedded newline,
     comma, and escaped quote
5. Extend `tools/code-graph/smoke.sh` to run the new smoke.
6. Specify token feature probing in `cgq.py`:
   - probe once per process with `SELECT hasToken('a b', 'b')`
   - use token search only for named-query modes that intentionally request token
     semantics; plain `search` and `search-line` may stay substring-based to preserve
     expected code-symbol matches such as `dispatch_step`
   - otherwise fall back to `positionCaseInsensitive`
   - metadata includes `search_mode = "substring"`, `"token"`, or
     `"substring_fallback"` and `storage_mode = "csv_scan"`

Critical files:

- `tools/code-graph/extractor/config.py`
- `tools/code-graph/query/cgq.py`
- `tools/code-graph/tests/smoke_chdb_source.py`
- `tools/code-graph/smoke.sh`
- `scripts/install-prerequisites.sh`

Acceptance gates:

```bash
python3 tools/code-graph/tests/smoke_chdb_source.py
tools/code-graph/smoke.sh
```

Expected output includes:

```text
source chdb smoke ok
code-graph smoke ok
```

## Phase 1: Extraction

Goal: emit `source_files.csv`, `source_lines.csv`, and AILANG-only
`source_chunks.csv` for the active profile.

Ordered tasks:

1. Add `tools/code-graph/extractor/source_index.py`.
2. Reuse existing code:
   - `source_parser.discover_files(...)` for active-profile AILANG files
   - `source_parser.func_spans(...)` for AILANG function chunks
   - `slugs.module_slug(...)` for `.ail` module slugs
   - `slugs.symbol_slug(module, name)` for `source_chunks.func_slug`
3. Implement language classification:
   - `.ail` -> `ailang`
   - `.ts`, `.tsx` -> `typescript`
   - `.md` -> `markdown`
   - `.toml` -> `toml`
   - `.json` -> `json`
   - `.sh` and explicitly listed shell scripts -> `shell`
   - everything else -> `other`
4. Emit `source_files` rows:
   - compute `sha256` from exact file bytes
   - compute `bytes` from exact file bytes
   - set `module` only for `.ail`
   - carry active `profile` and `include_tests`
   - sort rows by `path` for deterministic CSV output
5. Emit `source_lines` rows:
   - one row per source line, 1-based `line_no`
   - strip only the line terminator
   - quote with Python `csv` writer, matching existing `emit.write_csv`
   - compute `is_comment` by language:
     - AILANG: left-trimmed line starts with `--`, matching
       `source_parser._strip_comments_keep_newlines`
     - TypeScript: left-trimmed line starts with `//`
     - shell/TOML: left-trimmed line starts with `#`
     - Markdown/JSON/other: `0`
   - sort rows by `(path, line_no)`
6. Emit AILANG `source_chunks` rows:
   - use `func_spans(text)` output
   - `kind = "func"`
   - `chunk_slug = f"{module}#func:{name}"`
   - `func_slug = symbol_slug(module, name)`
   - `start_line = start + 1`
   - `end_line` is inclusive after trailing blank trimming
   - `text` is the joined, trimmed chunk text
   - skip zero-length chunks only if trailing-blank trimming would leave no function
     declaration text, which should be treated as a fixture failure
   - sort rows by `(path, start_line, chunk_slug)`
7. Respect `func_spans` boundaries:
   - `TOPLEVEL_RE` treats top-level `func`, `type`, `module`, and `import` as
     boundaries
   - a function chunk ends at the next top-level declaration of any of those kinds,
     not only the next function
8. Do not emit non-AILANG `source_chunks` rows in v1.
9. Integrate with `tools/code-graph/extractor/emit.py`:
   - call the source-index builder after active profile resolution
   - write the three source CSVs into `.out/`
   - include source schema metadata in status rows
10. Integrate with `tools/code-graph/extract.sh` without adding new flags:
    - source indexing runs for full extraction and `--structural-only`
    - active `--profile` and `--include-tests` apply

Critical files:

- `tools/code-graph/extractor/source_index.py`
- `tools/code-graph/extractor/emit.py`
- `tools/code-graph/extractor/source_parser.py`
- `tools/code-graph/extractor/slugs.py`
- `tools/code-graph/extract.sh`

Tests and fixtures:

- `tools/code-graph/tests/fixtures/source_index/comments.ail`
- `tools/code-graph/tests/fixtures/source_index/comments.ts`
- `tools/code-graph/tests/fixtures/source_index/multiline_chunk.ail`
- `tools/code-graph/tests/fixtures/source_index/csv_quotes_commas_newlines.ail`
- `tools/code-graph/tests/fixtures/source_index/chunk_boundaries.ail`
- `tools/code-graph/tests/fixtures/source_index/slug_join.ail`
- `tools/code-graph/tests/fixtures/source_index/host_only.md`
- `tools/code-graph/tests/test_source_index.py`

Fixture coverage:

- comment detection by file kind
- multiline strings and multiline chunks
- quotes, commas, and newlines in CSV fields
- chunk boundaries at top-level `type`, `module`, and `import`
- `chunk_slug != func_slug`
- graph joins through `func_slug`
- non-AILANG line-only indexing
- profile and `include_tests` filtering

Acceptance gates:

```bash
tools/code-graph/extract.sh --profile=core
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_files"
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_lines"
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_chunks"
```

Expected:

- all three source tables exist
- `source_files` includes `AGENTS.md`
- host files produce `source_files` and `source_lines`, but no `source_chunks`
- AILANG chunks carry `func_slug` values that join to `funcs.slug`

## Phase 2: Query Surface

Goal: expose source search through `cgq.py` with typed schemas, stale metadata,
fallback metadata, truncation, and graph/effect joins.

Ordered tasks:

1. Add the three source `SCHEMAS` entries to `tools/code-graph/query/cgq.py`.
2. Keep using `csv_tables()` and `view_preamble()`; new CSVs become views
   automatically.
3. Add source-aware status metadata:
   - keep existing graph-oriented fields for backward compatibility:
     - `stale`
     - `stale_reason`
     - `coverage`
     - `incomplete`
   - `source_schema`
   - `source_stale`
   - `source_stale_reason`
   - `source_profile`
   - `source_row_counts`
   - `row_counts` may continue to include all tables, but source counts must also be
     easy to read without scanning unrelated graph tables
4. Implement source freshness:
   - read indexed paths and stored hashes from `source_files`
   - compare current `sha256` for every indexed path
   - missing indexed file means stale
   - hash mismatch means stale
   - files outside the active source index do not stale it
   - `SOURCE_SCHEMA` mismatch stales the source index
5. Keep graph and source stale states distinct:
   - effect/call graph answers still use ADR-002 metadata discipline
   - source search reports source staleness
   - `search-effects` reports both
   - for backward compatibility, `meta.stale` remains the graph stale flag used by
     existing graph/effect named queries
   - source named queries check `meta.source_stale` and print a source-specific
     banner; do not set graph `meta.stale` merely because source text is stale
6. Add named queries:
   - `search TERM`: default line-level source search
   - `search-line TERM`: explicit line search
   - `search-chunk TERM`: AILANG chunk search
   - `search-effects EFFECT TERM`: function-level chunk search joined to
     `effect_edges` through `source_chunks.func_slug`
7. Extend the `cgq.py` query plumbing so source metadata is not lost:
   - replace the current `named_query() -> tuple[str, bool]` contract with either a
     small query descriptor or `tuple[str, QueryFlags]`
   - flags must cover at least `effect_query`, `source_query`, and `search_mode`
   - `wrap(...)` passes those flags to `status_meta(...)`
   - `main()` uses those flags for stale and incomplete banners
   - raw `sql` still reports source metadata in `status_meta`, even though it cannot
     always know whether the SQL semantically depends on source tables
8. Add SQL literal escaping for user arguments. Do not interpolate raw args directly.
9. Add chunk result previews:
   - return `left(text, 500) AS text_preview` or truncate in Python
   - keep `--limit` row truncation behavior and metadata
10. Add source stale banners:
   - source query on stale source index prints `STALE: source index ...`
   - `search-effects` passes `effect_query=True`, preserving the existing
     `INCOMPLETE` banner when typed/effect data is stale, failed, or partial
   - `search-effects` also marks the source side stale when `source_stale=True`; it
     must not present a fresh text/effect join when either side is stale
11. Add token fallback metadata:
    - plain substring search: `meta.search_mode = "substring"`
    - success: `meta.search_mode = "token"`
    - fallback: `meta.search_mode = "substring_fallback"`

Critical files:

- `tools/code-graph/query/cgq.py`
- `tools/code-graph/tests/test_cgq_source_queries.py`
- `tools/code-graph/tests/test_cgq_source_staleness.py`

Acceptance gates:

```bash
python3 tools/code-graph/query/cgq.py q search dispatch_step
```

Expected:

- rows include `path`, `line_no`, `lang`, `module`, and `line`
- metadata includes source row counts, active profile, stale state, and search mode

```bash
python3 tools/code-graph/query/cgq.py q search-chunk try_emergency_compaction
```

Expected:

- rows are AILANG function chunks
- rows include both `chunk_slug` and `func_slug`

```bash
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
```

Expected:

- SQL joins through `source_chunks.func_slug = effect_edges.func_slug`
- query is marked as an effect query
- query is also marked as a source query
- existing `INCOMPLETE` behavior fires when typed/effect coverage is failed,
  partial, or stale
- source stale metadata and banner fire independently when indexed source text is
  stale

Fallback acceptance:

- add a test path that forces the token probe to fail
- expected metadata includes:

```json
"search_mode": "substring_fallback"
```

## Phase 3: Graph Joins And Docs

Goal: document the source index as part of the agent workflow and prove graph/source
joins work without weakening ADR-002 metadata discipline.

Ordered tasks:

1. Update `tools/code-graph/README.md` with examples:
   - line search
   - chunk search
   - TODO/FIXME inventory
   - duplicated standalone numeric literals using `\b`
   - function-level text search joined to `effect_edges` through `func_slug`
   - deliberately coarse module-level joins, labeled as module-level
2. Update root `AGENTS.md`:
   - `ailang-graph` answers structural/effect questions
   - source index answers profile-aware SQL source search
   - `rg` remains preferred for quick exact lookup
   - `unimported` does not mean dead or safe to delete
   - source-parsed calls/effects remain approximate and carry metadata
3. Extend `tools/code-graph/smoke.sh`:
   - run source extraction
   - run `q search dispatch_step`
   - run `q search-chunk try_emergency_compaction`
   - run `q search-effects Net httpGet`
   - run the chDB source smoke
4. Add stale detection smoke:
   - run against a temporary fixture repo or temporary copy of `.out/`, not by
     modifying the real workspace's `AGENTS.md`
   - include an indexed host fixture named `AGENTS.md`
   - verify `cgq.py status` reports source stale by hash mismatch
   - edit an unindexed file outside the active profile
   - verify active source index is not stale

Critical files:

- `tools/code-graph/README.md`
- `AGENTS.md`
- `tools/code-graph/smoke.sh`
- `tools/code-graph/tests/test_cgq_source_staleness.py`

Acceptance gates:

```bash
tools/code-graph/extract.sh --profile=core
python3 tools/code-graph/query/cgq.py status
```

Expected:

- status reports graph and source row counts
- active profile is `core`
- `source_schema` matches `SOURCE_SCHEMA`
- source stale state is computed from `source_files.sha256`

```bash
python3 tools/code-graph/query/cgq.py sql "
SELECT c.func_slug, f.name, e.effect, c.path, c.start_line
FROM source_chunks c
JOIN funcs f ON f.slug = c.func_slug
JOIN effect_edges e ON e.func_slug = c.func_slug
WHERE positionCaseInsensitive(c.text, 'httpGet') > 0
  AND e.effect = 'Net'
ORDER BY c.path, c.start_line
LIMIT 20"
```

Expected:

- join uses `func_slug`
- no dependency on `chunk_slug`
- metadata still reports approximate effect data and incomplete status when relevant

## Phase 4: Later Upgrades

Goal: keep non-v1 ideas explicit and out of the first implementation unless ADR-003
changes.

Non-goals for v1:

- replacing `rg`
- ClickHouse server setup
- persistent chDB/ClickHouse database
- native text indexes
- embeddings or vector search
- ranking/relevance scoring beyond simple SQL ordering
- whole-file host-language chunks
- host-language function parsing
- materialized tables
- exact compiler-derived call/effect semantics

Later upgrades:

- `tools/code-graph/index.sh --materialize`
- MergeTree/text-index-backed local database
- non-AILANG fixed-size line-window chunks
- ranking/scoring
- richer TypeScript/shell/Markdown parsing
- future exact AILANG AST/call graph integration if upstream supports it

## GLM Review Resolution Checklist

- Blocking, chDB not pinned: Phase 0 and Phase 2 add runtime token feature detection
  and substring fallback metadata.
- Verified contract not committed: Phase 0 adds `smoke_chdb_source.py`, including
  `trimBoth` and multiline CSV round-trip.
- Non-AILANG whole-file chunks duplicate line text: Phase 1 indexes host files at
  line level only.
- Schema asymmetry: the exact schemas carry `lang`, `profile`, and `include_tests`
  where required.
- `is_comment` type unspecified: exact schemas define `is_comment UInt8`.
- Staleness under-specified: Phase 2 uses stored `source_files.sha256` for every
  indexed path; mtime is not a correctness signal.
- `\b` numeric literal semantics: Phase 3 documents that it means standalone numeric
  literals, not digit runs embedded in identifiers.
- `func_spans` boundary wording: Phase 1 explicitly preserves the
  `func`/`type`/`module`/`import` top-level boundary behavior.
