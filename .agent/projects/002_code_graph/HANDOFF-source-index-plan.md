# Handoff: Write the source-index implementation plan

Date: 2026-06-28
For: the agent producing the source-index implementation plan
From: ADR-003 design and GLM review resolution

## Your task

Turn **ADR-003** into a concrete, phased implementation plan for the SQL source index
beside `ailang-graph`. The plan should extend the existing code-graph project, not
replace it: `ailang-graph` answers structural/effect questions, while the source index
adds profile-aware, stale-aware SQL search over source files, lines, and AILANG
function chunks.

You are **planning, not implementing**. Write ordered tasks, critical files,
acceptance gates, and tests/smokes. Do not build the extractor or edit `cgq.py` yet.

## Read first, in this order

1. `.agent/projects/002_code_graph/ADR-003-clickhouse-source-index.md` — the
   authoritative source-index design. Read it fully, including the GLM review comments
   and author responses.
2. `.agent/projects/002_code_graph/AILANG_Code_Graph.md` — the current implemented
   plan for ADR-002. The source-index plan must fit its file layout, phases, schemas,
   and CLI conventions.
3. `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md` — the
   structural/effect graph design. Use it for terminology, staleness/coverage rules,
   and approximate-call/effect caveats.
4. `tools/code-graph/query/cgq.py` — current query surface and metadata behavior.
   Pay attention to `SCHEMAS`, `csv_tables()`, named queries, effect-query banners,
   and `status_meta()`.
5. `tools/code-graph/extractor/source_parser.py` and `tools/code-graph/extractor/slugs.py`
   — current parser spans and slug contract. The source chunks must reuse these rather
   than inventing independent function-boundary or slug logic.
6. `scripts/install-prerequisites.sh` — chDB install behavior. Do not assume chDB is
   pinned.

## Decisions already made — do not relitigate

- **Location:** implement under `tools/code-graph/`; emit generated CSVs into
  `tools/code-graph/.out/`.
- **Storage/query model:** v1 is CSV-backed chDB using `file(..., 'CSVWithNames')`.
  No ClickHouse server, persistent database, native text index, embeddings, or vector
  search in v1.
- **Tables:** emit `source_files.csv`, `source_lines.csv`, and `source_chunks.csv`.
  Tables are keyed by repo-relative path and must carry the active profile context.
- **Schema parity:** `source_lines` includes `include_tests`; `source_chunks` includes
  `lang`, `profile`, and `include_tests`. `is_comment` is `UInt8`.
- **Function joins:** `chunk_slug` is human-readable and may be `{module}#func:{name}`;
  graph joins must use `func_slug = symbol_slug(module, name) = {module}#{name}`.
  Joins to `funcs`/`effect_edges` go through `source_chunks.func_slug`, never through
  `chunk_slug`.
- **AILANG chunks:** reuse `source_parser.func_spans`. Remember its boundary is any
  top-level `func`/`type`/`module`/`import`, not only the next function.
- **Non-AILANG chunks:** v1 does **not** emit whole-file chunk text rows for host files.
  Host files are searched via `source_lines`; line-window chunks can be a later upgrade.
- **Search functions:** because chDB is not pinned, token searches must feature-detect
  support at runtime and fall back to `positionCaseInsensitive` with explicit metadata
  such as `meta.search_mode = "substring_fallback"`.
- **Staleness:** source freshness is computed from `source_files.csv` using stored
  `sha256` values for every indexed path. mtime may only be an optimization before
  hashing, not the correctness signal.
- **Schema versioning:** add `SOURCE_SCHEMA`; a schema bump must stale the index.
- **Search semantics:** `\b` in the duplicated-literals example intentionally means
  standalone numeric literals, not digit runs embedded in identifiers.

## What the plan must specify

1. **File layout changes** under `tools/code-graph/`: source-index extraction module,
   integration point in `extract.sh`, query CLI changes, tests/smokes, and README/AGENTS
   documentation updates.
2. **Exact CSV schemas** and `cgq.py SCHEMAS` entries for:
   - `source_files`: `path`, `module`, `lang`, `bytes`, `sha256`, `n_lines`, `profile`,
     `include_tests`.
   - `source_lines`: `path`, `module`, `lang`, `line_no`, `line`, `is_comment`,
     `profile`, `include_tests`.
   - `source_chunks`: `chunk_slug`, `func_slug`, `path`, `module`, `lang`, `kind`,
     `name`, `start_line`, `end_line`, `text`, `profile`, `include_tests`.
3. **Extractor behavior:** active profile matching, language classification,
   comment detection by file kind, AILANG function chunk extraction, trailing blank
   trimming, multiline CSV quoting, and non-AILANG line-only indexing.
4. **`cgq.py` integration:** views, named queries (`search`, `search-line`,
   `search-chunk`, `search-effects`), token-feature probe/fallback metadata, row
   truncation, stale banners, and effect-query `INCOMPLETE` handling when joining
   `effect_edges`.
5. **Staleness/status behavior:** source row counts in `cgq.py status`, active profile
   reporting, source-schema mismatch, sha256 comparison for indexed paths, and the rule
   that files outside the active profile do not stale the active source index.
6. **Committed verification:** a runnable chDB smoke proving the string/token functions
   used by named queries and multiline CSV round-trip behavior. Include `trimBoth`.
7. **Tests/fixtures:** small source fixtures for comments, multiline strings/chunks,
   quotes/commas/newlines in CSV, chunk boundaries at `type`/`module`/`import`, slug
   joins, non-AILANG line-only indexing, profile/include-tests filtering, and stale
   detection for an indexed host file such as `AGENTS.md`.
8. **Acceptance gates:** each phase should have concrete commands and expected outputs,
   including `cgq.py q search dispatch_step`, a function-level search joined to
   `effect_edges` through `func_slug`, stale detection after editing an indexed host
   file, and fallback behavior when token probes fail.

## Recommended phase shape

1. **Phase 0: contracts and smokes.** Add/plan the chDB feature probe smoke, CSV
   round-trip smoke, exact schemas, `SOURCE_SCHEMA`, and source-profile rules.
2. **Phase 1: extraction.** Emit `source_files`, `source_lines`, and AILANG
   `source_chunks`; integrate with `extract.sh`; verify CSV quoting and chunk spans.
3. **Phase 2: query surface.** Add `cgq.py` schemas and named queries, token fallback,
   metadata, truncation, and source-aware status/staleness.
4. **Phase 3: graph joins and docs.** Add `search-effects`, function-level join
   examples, `AGENTS.md` guidance, and README examples.
5. **Phase 4: optional later upgrades.** Materialized ClickHouse/chDB tables with text
   indexes, non-AILANG windows, ranking, or richer host-language parsing. Keep these
   out of v1 unless the ADR changes.

## Grounding rules

- Treat ADR-003 as source of truth. If a plan step needs to diverge, flag that for the
  user instead of silently changing the design.
- Do not weaken ADR-002 metadata discipline: every answer that depends on approximate
  call/effect data still carries coverage/staleness/incomplete context.
- Use repo-local helpers and parser functions where they exist. Do not create a second
  slug format, comment rule, or AILANG span parser.
- Keep `rg` in the workflow. The source index complements file search; it does not
  replace `rg` for quick exact lookup.
- Make the implementation plan concrete enough that another agent can execute it
  without rereading the review debate.

## Deliverable shape

Write a phased implementation plan with:

- goal per phase;
- ordered tasks;
- critical files with repo-relative paths;
- tests/smokes and fixture names;
- acceptance gate commands;
- explicit non-goals and later upgrades.

End with a short checklist mapping each GLM review comment in ADR-003 to the plan item
that resolves it.
