## Code & Effect Graph (`ailang-graph`)

`tools/code-graph/` extracts a structural and effect graph for this repo's AILANG
source. Static repo imports are exact; calls and reachable effects are source-parsed
approximations and every answer carries metadata for staleness, coverage, and
incomplete typed extraction.

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
python3 tools/code-graph/query/cgq.py q failures
python3 tools/code-graph/query/cgq.py sql "SELECT * FROM invokes WHERE to_slug LIKE '%try_emergency_compaction' LIMIT 50"
```

Result metadata includes `approximate`, `stale`, `coverage`, and `incomplete`. Agents
must not treat call/effect rows as compiler-derived facts, and must treat
`incomplete=true` as "unknown", not "no".

The `unimported` query means "not reachable via static imports from declared roots";
it never means dead or safe to delete.
