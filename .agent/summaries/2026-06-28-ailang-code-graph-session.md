# Session Summary: `ailang-graph` Implementation and Follow-ups

Date: 2026-06-28

## Main Outcome

Implemented `ailang-graph` under `tools/code-graph/` from the plan in
`.agent/projects/002_code_graph/AILANG_Code_Graph.md`.

The tool now extracts Motoko AILANG code structure, typed iface metadata, declared
effects, reachable effects, queryable CSVs, and SVG diagrams.

## Key Files Added

- `tools/code-graph/extract.sh`
- `tools/code-graph/README.md`
- `tools/code-graph/smoke.sh`
- `tools/code-graph/extractor/`
  - `config.py`
  - `source_parser.py`
  - `iface_pass.py`
  - `seed_catalog.py`
  - `effects.py`
  - `roots.py`
  - `emit.py`
  - `slugs.py`
- `tools/code-graph/query/cgq.py`
- `tools/code-graph/viz/visualize.py`
- `tools/code-graph/tests/`
- `.agent/projects/002_code_graph/ADR-003-clickhouse-source-index.md`

## Existing Files Updated

- `scripts/install-prerequisites.sh`
  - Added `chdb` prerequisite installation.
- `.gitignore`
  - Kept root `code-graph/` ignored while unignoring `tools/code-graph/**`.
  - Kept `tools/code-graph/.out/` ignored.
- `AGENTS.md`
  - Added code/effect graph usage docs.
- `.agent/projects/002_code_graph/AILANG_Code_Graph.md`
  - Recorded current measurement numbers.
- `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md`
  - Recorded current implementation measurement note.

## Extraction Behavior

Default extraction is now the clean core profile:

```bash
tools/code-graph/extract.sh
```

It extracts:

- `src/core/**`
- excludes smoke scripts
- excludes examples
- excludes `*_test.ail`
- excludes `src/core/test/**`

Opt-ins:

```bash
tools/code-graph/extract.sh --profile=all
tools/code-graph/extract.sh --profile=smoke
tools/code-graph/extract.sh --include-tests
```

`--structural-only` is guarded so it cannot accidentally overwrite a full typed/effect
cache unless `--force` is supplied:

```bash
tools/code-graph/extract.sh --structural-only --force
```

## Current Default Graph Metrics

After the final run, the default core graph was:

```text
profile=core
modules=24
funcs=378
imports=48
invokes=479
std_calls=550
effects=174
effect_edges=472
coverage: 24 ok, 0 partial, 0 failed
stale=false
```

## Query CLI

Main entry point:

```bash
python3 tools/code-graph/query/cgq.py status
python3 tools/code-graph/query/cgq.py q callers dispatch_step
python3 tools/code-graph/query/cgq.py q reaches Net
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/query/cgq.py sql "SELECT * FROM invokes LIMIT 10"
```

The CLI reports:

- profile
- include-tests mode
- row counts
- coverage
- staleness
- incomplete effect answers
- truncation

`q failures` uses persisted `iface_error` snippets from extraction status.

## SVG Rendering

Rendered diagrams include:

- `tools/code-graph/.out/module_deps.svg`
- `tools/code-graph/.out/calls.svg`
- `tools/code-graph/.out/effect_Net.svg`
- `tools/code-graph/.out/core_modules_extensions.svg`

Core/extensions SVG is now first-class:

```bash
python3 tools/code-graph/viz/visualize.py --core-extensions
```

## Tests and Verification

Commands run successfully:

```bash
pytest -q tools/code-graph/tests
python3 -m py_compile tools/code-graph/extractor/*.py tools/code-graph/query/cgq.py tools/code-graph/viz/visualize.py
tools/code-graph/smoke.sh
```

Test result:

```text
8 passed
```

Smoke result:

```text
code-graph smoke ok
```

## chDB Validation

Installed `chdb` and validated:

- `file(..., 'CSVWithNames')` works.
- Recursive CTEs work with `UNION ALL`.
- `UNION DISTINCT` inside recursive CTEs is unsupported in the installed chDB, so
  canned recursive queries use bounded `UNION ALL` with outer `DISTINCT`/aggregation.

## Important Design Decisions / Caveats

- `effects.csv` contains declared effects from `ailang iface`.
- `effect_edges.csv` contains reachable effects propagated backward from stdlib
  effect seeds.
- Call/effect graph output remains approximate.
- The default core profile has clean typed coverage.
- `--profile=all` still shows failures/partials from stale smoke/example/test code;
  this is expected and now opt-in.
- `--structural-only` intentionally clears typed/effect data, but is now guarded.

## Known Blockers / Not Done

- The upstream `ailang-feedback` issue for public stdlib function effect rows was not
  filed because the `ailang-feedback` skill was unavailable in this session.
- `seed_catalog.py` records this limitation and keeps the `SEED_GRANULARITY` seam for
  a future per-symbol upgrade.
- The full broad `--profile=all` oracle still has divergences; the default core
  profile is the recommended day-to-day graph.

## New ADR

Added:

```text
.agent/projects/002_code_graph/ADR-003-clickhouse-source-index.md
```

It proposes a source-text index adjacent to `ailang-graph`:

- `source_files.csv`
- `source_lines.csv`
- `source_chunks.csv`

Initial version should use CSV-backed chDB SQL search. Native ClickHouse full-text
indexes are deferred to a later materialized-table mode because CSV `file(...)` views
do not provide persistent MergeTree text indexes.

