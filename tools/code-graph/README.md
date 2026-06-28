# ailang-graph

`ailang-graph` extracts a structural and effect graph from this repo's AILANG source.
It emits CSVs under `tools/code-graph/.out/`, queries them with embedded chDB, and can
render scoped Mermaid/SVG views.

The import graph is source-derived and exact for static repo imports. The call graph
and reachable effect graph are source-parsed approximations and must be read with the
coverage and staleness metadata emitted by `query/cgq.py`.

```bash
tools/code-graph/extract.sh
tools/code-graph/extract.sh --profile=all
python3 tools/code-graph/query/cgq.py status
python3 tools/code-graph/query/cgq.py q callers dispatch_step
python3 tools/code-graph/query/cgq.py q reaches Net
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/viz/visualize.py --core-extensions
tools/code-graph/smoke.sh
```

Default extraction uses the `core` profile: `src/core/**`, excluding smoke scripts,
examples, `*_test.ail`, and `src/core/test/**`. `--profile=all` restores the broad
repo graph; `--profile=smoke` focuses on scripts/examples; `--include-tests` adds core
test modules to the core profile.

The existing root-level `code-graph/` is the external Zeus/C# graph. It is intentionally
not moved by this tool; a future `tools/code-graph-csharp/` move is separate work.
