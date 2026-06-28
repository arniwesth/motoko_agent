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
| `lang` | `ailang` / `typescript` / `markdown` / `toml` / `json` / `shell` / `other` |
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
| `lang` | file language, denormalized from `source_files.lang` (lets `WHERE lang='ailang'` avoid a join on every text search; matches the existing choice to denormalize `module` here) |
| `line_no` | 1-based |
| `line` | raw line text, newline stripped |
| `is_comment` | best-effort per file kind |
| `profile` | extraction profile |

Note `lang` (file language: `ailang`/`typescript`/…) is distinct from
`source_chunks.kind` (chunk type: `func`/`type`/`module`/`file`); they are deliberately
different columns, not two spellings of one concept.

A `trimmed` column was dropped: it is fully derivable in SQL via `trimBoth(line)` and
doubles the largest table for no query power. `is_comment` is kept because it is *not*
cheaply derivable in SQL — it is computed per file kind during extraction. For AILANG,
reuse the existing comment rule in `source_parser._strip_comments_keep_newlines` (`--`
line comments) rather than inventing a second one.

**`source_chunks.csv`**

| column | notes |
|---|---|
| `chunk_slug` | stable, human-readable slug, e.g. `{module}#func:{name}` or `{path}#lines:{start}-{end}` |
| `func_slug` | graph join key: `symbol_slug(module, name)` = `{module}#{name}` for `kind=func`; empty otherwise |
| `path` | repo-relative path |
| `module` | module slug for `.ail`; empty otherwise |
| `kind` | `func` / `type` / `module` / `file` |
| `name` | symbol name when known |
| `start_line` | 1-based |
| `end_line` | inclusive |
| `text` | chunk text |

For AILANG, `source_chunks.csv` reuses the source parser's top-level spans
(`source_parser.func_spans`) so function chunks line up with the graph. Note that
`chunk_slug` is **not** the graph key: `funcs.slug` is `{module}#{name}` (see
`extractor/slugs.py:symbol_slug`), while a readable `chunk_slug` like
`{module}#func:{name}` deliberately differs. Joins to the graph must use the separate
`func_slug` column, which is emitted as exactly `symbol_slug(module, name)`. Emitting
`func_slug` from the same `func_spans` output guarantees it equals the value
`emit.py` writes into `funcs.slug`.

`func_spans` returns a half-open span `[start, end)` where `end` is the next
top-level declaration (or EOF). Map this to `start_line = start + 1` (1-based) and
`end_line = end` (inclusive of the last body line, exclusive of the next decl), and
trim trailing blank lines so adjacent function chunks do not overlap.

For non-AILANG files, v1 uses whole-file chunks (`kind=file`, empty `func_slug`) and
may add fixed-size line windows later. Non-AILANG chunks have no graph counterpart and
do not join to `funcs`/`effect_edges`.

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

**Verified contract (chDB 4.1.9, the version pinned in this repo):** a local check
confirmed `positionCaseInsensitive`, `match` (RE2, including `(?i)` and `\b`),
`extractAll`, `hasToken`, and `tokens` all work over `file(..., 'CSVWithNames')`
views, and that multiline quoted CSV fields (embedded `\n`, commas, and escaped
quotes written by Python's `csv` module) round-trip correctly. The version-pinning
caveat still stands for future chDB bumps, but v1 does not need to discover whether
these functions exist — only re-verify if the pinned version changes.

### Integration With `cgq.py`

The source layer is not free-standing; it must slot into the existing query CLI. Three
concrete touch points in `tools/code-graph/query/cgq.py`:

1. **Views.** `csv_tables()` globs `.out/*.csv`, so the new CSVs become views
   automatically. But the hardcoded `SCHEMAS` dict gives explicit typed columns; add
   entries for `source_files`, `source_lines`, and `source_chunks` so `line_no` /
   `start_line` are typed `Int64` rather than left to inference (inference returns
   `Nullable(...)`, which is workable but inconsistent with the other tables).
2. **Named queries.** Register `search`, `search-line`, `search-chunk`, and
   `search-effects` in `named_query()`. Source searches are *not* effect queries
   (`effect_query=False`) unless they join `effect_edges`, in which case pass
   `True` so the existing INCOMPLETE banner fires on stale/partial typed coverage.
3. **Staleness.** `status_meta()` currently derives freshness only from
   `SELECT path FROM modules` (`.ail` files only). If the source index also covers
   host files (`*.ts`, `ailang.toml`, `AGENTS.md`), edits to those will **not** be
   seen by the current staleness check. v1 must compute source freshness from
   `source_files.csv` (all indexed paths, compared by mtime and/or `sha256`), not from
   `modules.csv`. Add a `SOURCE_SCHEMA` constant and a `source_schema` column to
   `extraction_status.csv` (or a sibling `source_status.csv`) so a change to the
   source CSV format invalidates the index the same way `graph_schema` does today.

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
- Join search results to graph tables by `func_slug` (function granularity) and, where
  deliberately coarse, by `module`.
- Extend `cgq.py` staleness/profile metadata to cover indexed host files and a
  `SOURCE_SCHEMA` version (see "Integration With `cgq.py`").

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

Join text hits to the effect graph. Do this at **chunk/function granularity** via
`func_slug`, not at module granularity. A line-to-module join
(`source_lines.module = funcs.module`) attributes every line in a module to every
effect-reaching function in that module — it answers "this module mentions `httpGet`
*and somewhere* reaches `Net`", which is usually not what the caller means:

```sql
-- Functions whose own body text mentions httpGet AND that reach Net.
SELECT DISTINCT c.func_slug, c.path, c.start_line, e.effect
FROM source_chunks c
JOIN effect_edges e ON e.func_slug = c.func_slug
WHERE c.kind = 'func'
  AND positionCaseInsensitive(c.text, 'httpGet') > 0
  AND e.effect = 'Net'
ORDER BY c.path, c.start_line;
```

The coarse module-level join is still occasionally useful ("which modules mention X and
reach Net") but should be written deliberately and labeled as module-level, since it
does not locate the specific function.

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
  WHERE lang = 'ailang'
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
- Token-search behavior depends on the installed chDB/ClickHouse version. Verified on
  the pinned chDB 4.1.9 (see "Verified contract"); must be re-checked on version bumps.

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
- A function-level source search joins to `funcs`/`effect_edges` in one SQL query via
  `source_chunks.func_slug = funcs.slug` (= `effect_edges.func_slug`), with no rows
  lost to the `{module}#func:{name}` vs `{module}#{name}` slug mismatch.
- Staleness is profile-aware (editing a file outside the active profile does not stale
  the active source index) *and* covers every indexed path: editing an indexed host
  file (e.g. `AGENTS.md`, `ailang.toml`) marks the source index stale, since freshness
  is computed from `source_files.csv`, not `modules.csv`.
- A bump to `SOURCE_SCHEMA` marks the existing source index stale.
- CSV quoting handles multiline chunks and commas/quotes in source, verified by a
  round-trip read through chDB `CSVWithNames` (confirmed on chDB 4.1.9).
- No ClickHouse server is required for v1.
<!-- Reviewer: GLM 5.2 · 2026-06-28 · Verified against the working tree at review time. -->

## Review Comments — GLM 5.2

Grounded against the current repo (`tools/code-graph/extractor/source_parser.py`,
`extractor/slugs.py`, `query/cgq.py`, `scripts/install-prerequisites.sh`) and a live
chDB 4.1.9 probe.

### 🔴 Blocking — "the version pinned in this repo" is not pinned

**Ref:** "Verified contract (chDB 4.1.9, the version pinned in this repo)" (lines 147, 152,
289) and "must be re-checked on version bumps" (line 289).

`scripts/install-prerequisites.sh:327-338` (`install_chdb`) runs
`python3 -m pip install --user --break-system-packages chdb` with **no version
constraint**. There is no `requirements.txt`, constraints file, or lock pinning chDB
anywhere in the repo (`pip freeze` shows `chdb==4.1.9` incidentally; `chdb-core` is
`26.5.0`). So:

- The premise "v1 does not need to discover whether these functions exist — only
  re-verify if the pinned version changes" has no pin to detect a change against. A
  fresh install, a different machine, or a PyPI release silently swaps the version.
- A future chDB that drops/regresses `hasToken`/`tokens` would break the `search` named
  queries with no runtime guard, because `cgq.py` performs no version or
  feature check (verified: `status_meta` / `run_sql` issue chDB calls unconditionally).

The verification I ran confirms the functions work on 4.1.9 (`positionCaseInsensitive`,
`match` with `(?i)`/`\b`, `extractAll`, `hasToken`, `tokens`, and `trimBoth` all returned
expected results; multiline CSV fields round-trip), so the contract is *currently* sound —
but the "pinned" framing is wrong and the safety argument is hollow without one of:

1. Actually pin: add a `chdb==4.1.9` constraint to `install-prerequisites.sh` (or a
   committed `constraints.txt`) **and** assert the version at runtime in `cgq.py`
   (`import chdb; assert chdb.__version__ == "4.1.9"`), surfacing a clear error on drift;
   **or**
2. Drop the "pinned" claim and add a one-shot feature-detection query (e.g.
   `SELECT hasToken('a b','b')`) gated before any token-function named query, falling
   back to `positionCaseInsensitive` when unavailable.

Option (2) is more robust to the install reality; option (1) is simpler if the project
is willing to pin. Pick one before v1 lands.

### 🟠 The "Verified contract" list is incomplete and not committed

**Ref:** "Verified contract" block (lines 147-153) and the `trimmed`-drop note's
`trimBoth(line)` reference (line 82).

- `trimBoth` is cited as a derivable SQL helper but is **not** in the verified
  enumeration. I confirmed `SELECT trimBoth('  x  ')` returns `'x'` on chDB 4.1.9, so the
  claim holds — but the doc relies on a function it never lists as verified. Either add
  `trimBoth` to the contract or avoid referencing it.
- The "local check confirmed …" is asserted prose with no committed artifact. Since the
  *entire* v1 convenience ("does not need to discover whether these functions exist")
  rests on it, commit the check as a runnable smoke under `tools/code-graph/tests/`
  (or extend `smoke.sh`) so a chDB bump or new contributor can re-run it. Without a
  committed check, the contract is folklore and will rot the moment someone bumps the
  (currently unpinned) chDB.

### 🟠 Non-AILANG whole-file chunks double the line text

**Ref:** "For non-AILANG files, v1 uses whole-file chunks (`kind=file`, empty
`func_slug`)" (lines 116-118) and the bulki-CSV consequence (line 287).

`source_lines.csv` already stores every line of every indexed file. A `source_chunks`
row with `kind=file` and `text` = the entire host file re-stores that file's full text a
second time, for chunks that (by the doc's own admission) "have no graph counterpart and
do not join to `funcs`/`effect_edges`." For the proposed host set
(`src/tui/src/*.ts`, `AGENTS.md`, `ailang.toml`) a single `.ts` file can be hundreds of
KB, materialized twice with no join power the line table doesn't already provide. The
"Consequences" section flags bulkiness generically but does not address this specific
doubling. Recommend for v1: either drop the `text` column for `kind=file` rows (emit
`path`/`start_line`/`end_line` only, since line-level text already lives in
`source_lines`), or exclude non-AILANG files from `source_chunks` entirely and rely on
line-level search for them.

### 🟡 Schema asymmetry across the three tables

**Ref:** table column lists (lines 53-100).

`source_files` carries `profile` + `include_tests`; `source_lines` carries `profile`
but not `include_tests`; `source_chunks` carries neither `profile`, `include_tests`, nor
`lang`. The doc justifies denormalizing `lang`/`module` onto `source_lines` precisely to
let `WHERE lang='ailang'` avoid a join — then withholds the same convenience from
`source_chunks`, forcing any chunk-level `WHERE lang=...` to join `source_files`. Either
state the asymmetry is intentional (and why) or add `lang`/`profile` to
`source_chunks` for parity. Same question for `include_tests` on `source_lines`.

### 🟡 `is_comment` type unspecified

**Ref:** `source_lines` column notes (line 75) and the `SCHEMAS` integration note
(lines 160-164).

`is_comment` is described as "best-effort per file kind" but no type is given, while the
doc is explicit that `line_no`/`start_line` must be `Int64` rather than inferred
`Nullable(...)`. For consistency, state the type (`UInt8` or `Int64`) and include it in the
`SCHEMAS` entry spec so it is not left to chDB inference.

### 🟡 Staleness signal is under-specified

**Ref:** "compared by mtime and/or sha256" (line 173) vs. the acceptance criterion
(lines 324-327).

"and/or" is too vague to implement against. mtime-only is cheap but breaks under git
operations / checkouts that reset mtimes (a real concern for an agent-driven repo where
files are rewritten constantly); sha256 is exact but reads every indexed file on every
`cgq.py status`. The acceptance criterion asserts only the *outcome* ("editing
`AGENTS.md` marks stale"), not which signal produces it. Pick the v1 default (recommend
sha256, cached in `source_files.csv` and compared on `status`) and state it; mention the
other as an explicit fallback. Note `source_files.csv` already plans a `sha256` column, so
the exact-signal path is nearly free.

### 🟢 Minor — `\b` semantics in the duplicated-literals example

**Ref:** example query (lines 257-271).

`extractAll(line, '\\b[0-9]{3,}\\b')` uses RE2 `\b` word boundaries, so digit runs
adjacent to identifiers (`foo123`, `x1f2`) do **not** match — only standalone numeric
literals do. I verified this: `extractAll('a1 b22 c333', '\\b\\d{2,}\\b')` returns `[]`
because `22`/`333` are glued to letters with no word boundary. That may well be the intent
for "duplicated literals", but it is unstated; a reader expecting "any 3+ digit run" will
be surprised. Add a one-line caveat, or drop `\b` if the goal is any run of 3+ digits.

### 🟢 Minor — `func_spans` boundary is "any top-level keyword", not "next func"

**Ref:** "`func_spans` returns a half-open span `[start, end)` where `end` is the next
top-level declaration (or EOF)" (lines 111-114).

Accurate, but worth a clarifying note: `source_parser.TOPLEVEL_RE` (line 10) matches
`func`/`type`/`module`/`import`, so a `kind=func` chunk ends at the next `type`,
`module`, or `import` line, not only the next `func`. This is correct behavior (a
trailing `type` decl properly terminates the preceding function body) but the doc's
phrasing could be read as "next function". The `end_line = end` (inclusive, 1-based)
mapping is correct: `end` is the 0-based index of the boundary line, so 1-based last body
line is `end`. No action beyond a wording tweak.

### Summary

The design is sound and well-scoped; the slug/`func_slug` join discipline
(`{module}#{name}` vs `{module}#func:{name}`) is correctly handled and the
staleness-from-`source_files` insight is a real improvement over the current
`modules`-only check (confirmed: `cgq.py:106` keys freshness off `SELECT path FROM
modules`, which excludes host files). The blocking issue is narrowly factual: the
"pinned version" premise is false against the actual install path, which undermines the
only guard the doc proposes. Resolve the pin (🔴) and commit the verification (🟠) and v1
is ready to implement.

