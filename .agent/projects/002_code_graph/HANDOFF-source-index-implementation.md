# Handoff: Build the SQL source index for `ailang-graph`

Date: 2026-06-28
For: the agent implementing the source index
From: ADR-003 + reviewed implementation plan

## Your task

Implement the SQL source index beside `ailang-graph` by executing
`.agent/projects/002_code_graph/AILANG_Source_Index.md`.

You are **implementing**, not redesigning. The plan has already been reviewed
iteratively against ADR-003, ADR-002, and the current `tools/code-graph/` code. Follow
it phase by phase. The source index extends the existing code-graph project; it does
not replace it:

- `ailang-graph` answers structural/effect questions.
- the source index adds profile-aware, stale-aware SQL search over source files,
  lines, and AILANG function chunks.

Do not implement persistent ClickHouse databases, native text indexes, embeddings,
vector search, host-language deep parsing, or non-AILANG whole-file chunks in v1.

## Read first, in this order

1. `.agent/projects/002_code_graph/AILANG_Source_Index.md` — the implementation plan
   and your primary spec. Read it fully before editing files.
2. `.agent/projects/002_code_graph/ADR-003-clickhouse-source-index.md` — source-index
   ADR and GLM review resolution. Use it for rationale and acceptance criteria.
3. `.agent/projects/002_code_graph/AILANG_Code_Graph.md` — current implemented
   ADR-002 plan. Match its layout, phase discipline, metadata style, and CLI
   conventions.
4. `tools/code-graph/query/cgq.py` — current query surface. Pay attention to
   `SCHEMAS`, `csv_tables()`, `view_preamble()`, `named_query()`, `wrap()`,
   `status_meta()`, stale banners, row truncation, and effect-query `INCOMPLETE`.
5. `tools/code-graph/extractor/source_parser.py` and
   `tools/code-graph/extractor/slugs.py` — reuse `func_spans`, `module_slug`, and
   `symbol_slug`. Do not create a second AILANG span parser or slug format.
6. `tools/code-graph/extractor/emit.py`, `tools/code-graph/extractor/config.py`, and
   `tools/code-graph/extract.sh` — integration points for extraction, status schema,
   active profiles, and generated CSVs.
7. `tools/code-graph/smoke.sh`, `tools/code-graph/README.md`, and root `AGENTS.md` —
   verification and agent-facing documentation surface.

## Decisions already made — do not relitigate

- **Location:** implement under `tools/code-graph/`; generated CSVs go to
  `tools/code-graph/.out/`.
- **Storage/query model:** v1 is CSV-backed chDB using
  `file(..., 'CSVWithNames')`. No ClickHouse server or persistent database.
- **Tables:** emit `source_files.csv`, `source_lines.csv`, and
  `source_chunks.csv`.
- **Schemas:** use the exact schemas in `AILANG_Source_Index.md`, including
  `is_comment UInt8`, `include_tests UInt8`, and `source_schema Int64` in
  `extraction_status.csv`.
- **AILANG chunks:** use `source_parser.func_spans`. Its boundary is the next
  top-level `func`, `type`, `module`, or `import`, not only the next function.
- **Slug joins:** `chunk_slug` is human-readable. Graph joins must use
  `source_chunks.func_slug = symbol_slug(module, name) = funcs.slug`. Never join
  graph tables through `chunk_slug`.
- **Host files:** v1 indexes host files through `source_lines` only. Do not emit
  non-AILANG whole-file `source_chunks` text rows.
- **Token search:** chDB is not pinned. Feature-detect token functions at runtime and
  fall back to substring search with explicit metadata.
- **Staleness:** source freshness is computed by comparing stored
  `source_files.sha256` values for every indexed path. mtime is not a correctness
  signal.
- **Metadata discipline:** source staleness and graph/effect incompleteness are
  distinct. Do not collapse source staleness into the existing graph `meta.stale`.
- **`rg` remains useful:** SQL source search complements `rg`; it does not replace it.

## Build sequence

Work in the phase order from `AILANG_Source_Index.md`. Do not skip the gates.

### Phase 0: contracts and smokes

Implement:

- `SOURCE_SCHEMA = 1` in `tools/code-graph/extractor/config.py`
- matching `SOURCE_SCHEMA = 1` in `tools/code-graph/query/cgq.py`
- profile-aware host-file include rules
- `source_schema Int64` in `extraction_status.csv` and `cgq.py SCHEMAS`
- `tools/code-graph/tests/smoke_chdb_source.py`
- `tools/code-graph/smoke.sh` integration for that smoke
- runtime token-feature probing contract in `cgq.py`

Gate:

```bash
python3 tools/code-graph/tests/smoke_chdb_source.py
tools/code-graph/smoke.sh
```

Expected:

```text
source chdb smoke ok
code-graph smoke ok
```

### Phase 1: extraction

Implement:

- `tools/code-graph/extractor/source_index.py`
- `source_files.csv`
- `source_lines.csv`
- AILANG-only `source_chunks.csv`
- integration in `tools/code-graph/extractor/emit.py`
- no new `extract.sh` flags; existing `--profile` and `--include-tests` apply

Required behavior:

- active profile matching
- deterministic row ordering
- language classification
- comment detection by file kind
- exact `sha256` hashing
- multiline CSV quoting through Python `csv`
- trailing blank trimming for chunks
- no host-file chunks

Gate:

```bash
tools/code-graph/extract.sh --profile=core
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_files"
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_lines"
python3 tools/code-graph/query/cgq.py --no-banner sql "SELECT count() AS n FROM source_chunks"
```

Expected:

- all three source tables exist
- `source_files` includes `AGENTS.md`
- host files have file/line rows but no chunk rows
- AILANG chunks join to `funcs` through `func_slug`

### Phase 2: query surface

Implement:

- source table `SCHEMAS`
- source-aware status metadata
- hash-based source staleness
- named queries:
  - `search TERM`
  - `search-line TERM`
  - `search-chunk TERM`
  - `search-effects EFFECT TERM`
- query descriptor or `QueryFlags` replacing the current
  `named_query() -> tuple[str, bool]` shape
- source stale banners
- token fallback metadata
- safe SQL literal escaping for user args
- chunk previews/truncation

Do not lose existing graph behavior. Existing named queries must keep working.
`search-effects` is both a source query and an effect query, so it must carry source
staleness metadata and preserve the existing `INCOMPLETE` banner behavior for
effect/typed coverage.

Gates:

```bash
python3 tools/code-graph/query/cgq.py q search dispatch_step
python3 tools/code-graph/query/cgq.py q search-chunk try_emergency_compaction
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
```

Also add a test path that forces token probing to fail. Expected metadata:

```json
"search_mode": "substring_fallback"
```

### Phase 3: graph joins and docs

Implement:

- README examples in `tools/code-graph/README.md`
- root `AGENTS.md` guidance
- source queries in `tools/code-graph/smoke.sh`
- stale detection smoke/tests using a temporary fixture repo or temporary `.out`
  copy, not by modifying the real workspace `AGENTS.md`

Required docs:

- `ailang-graph` answers structural/effect questions
- source index answers SQL source search questions
- `rg` remains preferred for quick exact lookup
- graph/effect joins use `func_slug`
- coarse module-level joins are labeled as module-level
- `unimported` does not mean dead or safe to delete
- call/effect rows remain approximate and carry coverage/staleness/incomplete
  metadata

Gate:

```bash
tools/code-graph/extract.sh --profile=core
python3 tools/code-graph/query/cgq.py status
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

- status reports graph and source row counts
- source schema matches `SOURCE_SCHEMA`
- source freshness is based on `source_files.sha256`
- function-level effect join uses `func_slug`, not `chunk_slug`

## Test and fixture requirements

Add focused fixtures under `tools/code-graph/tests/fixtures/source_index/`:

- `comments.ail`
- `comments.ts`
- `multiline_chunk.ail`
- `csv_quotes_commas_newlines.ail`
- `chunk_boundaries.ail`
- `slug_join.ail`
- `host_only.md`

Cover:

- comment detection by file kind
- multiline strings/chunks
- quotes, commas, and newlines in CSV
- chunk boundaries at top-level `type`, `module`, and `import`
- `chunk_slug != func_slug`
- graph joins through `func_slug`
- non-AILANG line-only indexing
- profile and `include_tests` filtering
- stale detection for an indexed host fixture named `AGENTS.md`

## Pitfalls to avoid

- Do not use `modules.csv` to determine source freshness. It excludes host files.
- Do not treat `mtime` as a correctness signal for source staleness.
- Do not let source staleness set graph `meta.stale`.
- Do not claim a fresh text/effect join when either source or graph/effect metadata is
  stale.
- Do not use `chunk_slug` for graph joins.
- Do not add whole-file chunks for host files.
- Do not assume token functions exist in the installed chDB.
- Do not silently weaken ADR-002 metadata discipline for effect queries.
- Do not make broad unrelated refactors to the existing code graph.

## Definition of done

Done means:

- `tools/code-graph/extract.sh` emits the three source CSVs for the active profile.
- `cgq.py status` reports source row counts, active profile, source schema, and
  source stale state.
- `cgq.py q search dispatch_step` returns line hits with path and line number.
- `cgq.py q search-chunk try_emergency_compaction` returns AILANG function chunks.
- `cgq.py q search-effects Net httpGet` joins through `func_slug` and carries both
  source and effect metadata.
- editing an indexed host fixture marks source stale by hash mismatch.
- editing a file outside the active source index does not stale it.
- token-probe failure falls back to substring search with explicit metadata.
- multiline CSV round-trip and query function smoke are committed and passing.
- existing graph queries and smoke still pass.
