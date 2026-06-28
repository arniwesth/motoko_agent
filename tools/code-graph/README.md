# ailang-graph

`ailang-graph` extracts a structural and effect graph from this repo's AILANG source.
It emits CSVs under `tools/code-graph/.out/`, queries them with embedded chDB, and can
render scoped Mermaid/SVG views.

The import graph is source-derived and exact for static repo imports. The call graph
and reachable effect graph are source-parsed approximations and must be read with the
coverage and staleness metadata emitted by `query/cgq.py`.

The source index is adjacent to the graph: it adds profile-aware SQL search over
indexed source files, lines, and AILANG function chunks. Use it when search needs SQL
aggregation or graph joins; `rg` is still preferred for quick exact lookup.

```bash
tools/code-graph/extract.sh
tools/code-graph/extract.sh --profile=all
python3 tools/code-graph/query/cgq.py status
python3 tools/code-graph/query/cgq.py q callers dispatch_step
python3 tools/code-graph/query/cgq.py q reaches Net
python3 tools/code-graph/query/cgq.py q search dispatch_step
python3 tools/code-graph/query/cgq.py q search-chunk try_emergency_compaction
python3 tools/code-graph/query/cgq.py q search-effects Net httpGet
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/viz/visualize.py --core-extensions
tools/code-graph/smoke.sh
```

Default extraction uses the `core` profile: `src/core/**`, excluding smoke scripts,
examples, `*_test.ail`, and `src/core/test/**`. `--profile=all` restores the broad
repo graph; `--profile=smoke` focuses on scripts/examples; `--include-tests` adds core
test modules to the core profile.

Source tables:

```sql
SELECT path, line_no, line
FROM source_lines
WHERE positionCaseInsensitive(line, 'dispatch_step') > 0
ORDER BY path, line_no;

SELECT chunk_slug, func_slug, path, start_line, text
FROM source_chunks
WHERE positionCaseInsensitive(text, 'try_emergency_compaction') > 0
ORDER BY path, start_line;
```

Join source chunks to graph/effect data at function granularity through `func_slug`,
not through the human-readable `chunk_slug`:

```sql
SELECT c.func_slug, f.name, e.effect, c.path, c.start_line
FROM source_chunks c
JOIN funcs f ON f.slug = c.func_slug
JOIN effect_edges e ON e.func_slug = c.func_slug
WHERE positionCaseInsensitive(c.text, 'httpGet') > 0
  AND e.effect = 'Net'
ORDER BY c.path, c.start_line;
```

Coarse module-level joins are possible through `source_lines.module`, but label them
as module-level because they attribute every matching line in a module to module
metadata, not to a specific function.

Other useful source SQL:

```sql
SELECT path, count() AS n
FROM source_lines
WHERE match(line, '(?i)TODO|FIXME')
GROUP BY path
ORDER BY n DESC, path;

SELECT line, count() AS n, groupArray(path) AS paths
FROM source_lines
WHERE match(line, '\\b[0-9]+\\b')
GROUP BY line
HAVING n > 1
ORDER BY n DESC, line;
```

`cgq.py status` reports graph and source row counts. Graph staleness and source
staleness are separate: source freshness is checked by comparing stored
`source_files.sha256` values with current file contents. Effect answers also keep the
ADR-002 `INCOMPLETE` metadata when typed extraction is failed, partial, or stale.

The `unimported` query means "not reachable via static imports from declared roots";
it never means dead or safe to delete.

The existing root-level `code-graph/` is the external Zeus/C# graph. It is intentionally
not moved by this tool; a future `tools/code-graph-csharp/` move is separate work.
