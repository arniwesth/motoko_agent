# ADR-002: AILANG Code & Effect Graph Architecture for Motoko

Date: 2026-06-27
Status: Proposed

## Context

Motoko's own source is ~671 `.ail` files with ~2848 `import` edges across `src/core`, `src/tui`, `src/core/ext`, `scripts`, and `examples`. As the harness self-evolves, no human-curated map of that structure exists. Questions that recur during development — "who imports `registry_generated`?", "which functions carry `{Env, FS, Net}` effects?", "what calls `dispatch_step`?", "is this module dead?" — are answered today by ad-hoc grep, which is slow, lossy, and not queryable.

A working precedent already exists in this repo: `code-graph/` extracts a type-level dependency graph from the external Zeus C# codebase using Roslyn, loads it into chDB, and renders Mermaid/SVG. It exposes structural queries to the agent via the `code_graph_query` OMP tool (auto-views over `code_types`, `uses`, `inherits`, `implements`; `invokes`/`channels` via `file()`). It also integrates Slicito for method-level CFG, data-flow, and call-graph analysis.

That tool analyzes an *external* target (C#), not Motoko's own AILANG source. There is no structural code graph of Motoko itself.

The `code-graph` extractor is large (~50 KB of `Program.cs`) largely because C# has no introspection CLI — it must drive MSBuild Workspaces and Roslyn semantic models by hand. AILANG removes most of that cost: it ships structured introspection as first-class CLI commands.

This ADR is grounded against the local AILANG binary `v0.24.2` (commit `f88ff4e`), verified directly. Observed capabilities:

- `ailang iface <module>` — normalized JSON interface. Schema `ailang.iface/v1`. Emits `module`, `types` (each with optional `ctors`), and `funcs` (each with `name`, `type` signature string, `effects` array, `pure` flag). This is cleaner and more directly usable than any single Roslyn API.
- `ailang debug ast <file>` — Core AST in ANF form. Flags `--show-types` and `--compact`. Output is **text, not JSON**.
- `ailang debug cycles <file> --json` — cyclic type-reference detection, JSON output.
- `ailang ai-check <file>` — unified check+verify JSON (for AI tooling).
- `ailang tree` — package-level dependency tree.
- `import` statements are explicit, one per line, and trivially extractable.
- Function signatures carry **effect rows** (`!{IO}`, `{Env, FS, Net}`) — a typed capability surface C# does not expose.

## Relationship To Existing Graph Tooling

This system is distinct from, and complementary to, the two graphs already in the repo.

**`code-graph/` (structural, C#/Zeus).** Same *shape* of artifact (types + edges → chDB → Mermaid), different *target*. This ADR deliberately reuses its downstream pipeline — chDB load, `visualize.py`, the `code_graph_query` OMP tool, and the CSV-edge schema — rather than rebuilding it. The only new work is the AILANG-specific extractor that replaces `Program.cs`.

**`omnigraph/` (decision/architecture).** `omnigraph/schema.pg` defines `Decision`, `Component`, `Governs`, `Supersedes`, `DependsOn` — an ADR/architecture knowledge graph populated from docs and sessions. It captures *intent*, not code structure. The AILANG code graph captures *structure*. They meet at the `Component` node: a future `Implements`-style edge can link an omnigraph `Component` to the concrete `.ail` modules that realize it, but that linkage is out of scope for v1.

## Decision

Build an **AILANG code & effect graph extractor** for Motoko's own source, modeled on `code-graph` but thin, by treating AILANG's native introspection as the semantic layer instead of reimplementing it.

The extractor will:

1. Enumerate Motoko `.ail` modules under configured roots (`src`, `scripts`, `examples`).
2. Run `ailang iface` per module to collect types (with constructors), functions (with type signatures, effect rows, purity).
3. Parse `import` statements to build the module-dependency graph.
4. Derive a **type-use graph** from function signatures and an **effect graph** from effect rows.
5. Emit CSVs in the existing `code-graph` schema, plus new `effects` / `effect_edges` tables.
6. Reuse the existing chDB load, Mermaid/SVG visualization, and `code_graph_query` plumbing.

The **call/invokes graph is deferred** (see Phases): `ailang debug ast` is ANF text, not JSON, and an ANF parser is a separate, larger effort. We will instead request `ailang debug ast --json` upstream via the `ailang-feedback` channel before committing to call-graph extraction.

## Decision Drivers

- The downstream pipeline (chDB, Mermaid, `code_graph_query`) already exists and is language-agnostic; only the extractor is target-specific.
- AILANG's `ailang iface` removes the dominant cost (semantic introspection) that made the C# extractor large.
- The effect graph answers questions C# tooling structurally cannot, and is the highest-value Motoko-specific edge.
- A queryable structure + effect graph directly serves in-flight work, especially ADR-001 (DST).
- Module/import edges are extractable today with zero new AILANG features.

## Constraints

- Pinned to AILANG `v0.24.2`. The `iface` schema is `ailang.iface/v1`; any minor bump must re-validate the extractor against the actual emitted JSON, not docs.
- `ailang iface` requires the module to type-check or resolve enough to produce an interface. Modules that fail to check may yield partial or empty interfaces; the extractor must record extraction failures rather than silently dropping modules.
- AILANG has no classes. There is no direct `inherits`/`implements` analog; the closest concepts are type classes and instances. v1 will **not** synthesize `inherits`/`implements` edges; those CSV columns will exist but stay empty until a type-class model is designed.
- `ailang debug ast` output is text ANF. No call-graph edges until `--json` exists upstream or an ANF parser is written.
- Effect-row parsing depends on the textual `type` signature format in `iface` (e.g. `(())->()!{IO}`). This is a string-parse contract and must be re-validated on AILANG upgrades.
- AILANG module identity is **file/path-based** (`src/core/types`), not `namespace.Type`. Slugs and granularity differ from the C# graph; the schema's `slug` becomes a module-or-symbol path, not a type FQN.

## Edge & Node Model

Nodes:

- **module** — one per `.ail` file. Slug = repo-relative module path (`src/core/agent_loop_v2`).
- **type** — ADTs/records discovered via `iface`, with constructors. Slug = `{module}.{TypeName}`.
- **func** — top-level functions via `iface`, with signature, effects, purity. Slug = `{module}.{func_name}`.

Edges (CSV, `from_slug,to_slug` unless noted):

| Edge | Source | Status in v1 |
|------|--------|--------------|
| `imports` | `import` lines | ✅ module → module |
| `uses` | types referenced in `func.type` signatures | ✅ func/module → type |
| `effects` | `func.effects` array | ✅ new table: `func_slug,effect` |
| `effect_edges` | transitive effect reachability via `imports`+calls | ⚠️ approximate from imports in v1; exact after call graph |
| `inherits` / `implements` | type classes / instances | ⛔ deferred (empty columns) |
| `invokes` | `debug ast` ANF bodies | ⛔ deferred (needs `--json` upstream) |
| `channels` | effects + extension-hook wiring | ⛔ deferred |

The effect graph is the headline Motoko-specific capability: "which functions, transitively, can touch `Net`/`FS`/`Env`" — a capability/security view the C# graph cannot express.

## Architecture / Components

```
src/{core,scripts,examples}/**.ail
  → ailang iface (per module, JSON)   ─┐
  → import-line parse                  ├─→ extractor → .ailang-graph/*.csv
  → effect-row parse (from iface)     ─┘
  → chDB load (reuse)        → in-memory OLAP tables
  → visualize.py (reuse)     → .mmd → .svg
  → code_graph_query OMP tool (reuse)
```

| Component | Role | New / Reuse |
|-----------|------|-------------|
| `ailang-graph` extractor | Drives `ailang iface` + import/effect parsing, emits CSVs | **New** (replaces `Program.cs`) |
| `schema.sql` | chDB table defs (+ `effects`, `effect_edges`) | Extend existing |
| chDB load / `load.py` | Load CSVs into OLAP | Reuse |
| `visualize.py` | Mermaid + SVG (add effect-graph view) | Extend |
| `code_graph_query` OMP tool | Agent-facing SQL surface | Reuse (point at new CSVs) |

Extractor language choice is an open question (see below); the leading option is a small script (AILANG or Python/Bun) that shells `ailang iface`, since no Roslyn-equivalent host is needed.

## How This Serves ADR-001 (DST)

The structure + effect graph would directly answer blocking questions raised in the DST ADR review:

- **Effect satisfaction (DST R7):** enumerate every function carrying `{Env, FS, Net}` — that *is* the effect graph.
- **Registry-import precondition (DST R3/R13):** "all transitive importers of `registry_generated` / `init_runtime_with_config`" is one query over `imports`.
- **Recorder seam (DST R8):** "who calls `dispatch_step`" — answerable once the call graph lands; approximable today via `imports` + signature `uses`.
- **Constant duplication (DST R5):** a literal-`uses` scan can flag the duplicated `75000` / tier constants the DST ADR warns about.

## Implementation Plan

### Phase 0: Validate Introspection Contracts

- Snapshot `ailang iface` JSON for a representative module set; pin the `ailang.iface/v1` shape and the `type`/`effects` field formats.
- Confirm behavior on modules that fail to check (partial vs. empty vs. error).
- File an upstream request via the `ailang-feedback` skill for `ailang debug ast --json` (call-graph prerequisite).

### Phase 1: Module + Effect Graph (no new AILANG features)

- Build the extractor: enumerate `.ail`, run `iface`, parse imports, parse effect rows.
- Emit `code_types.csv`, `funcs.csv`, `imports.csv`, `uses.csv`, `effects.csv`.
- Load into chDB; reuse `code_graph_query`.
- Add a module-dependency Mermaid view and an effect-graph view.

### Phase 2: Effect Reachability + Agent Surface

- Compute approximate transitive effect reachability over `imports` + signature `uses`.
- Wire `code_graph_query` (or a sibling tool) to the new CSVs so the agent can query the Motoko graph.
- Add dead-module detection and fan-in/fan-out reports.

### Phase 3: Call Graph (gated on upstream)

- If `ailang debug ast --json` lands: extract `invokes` edges, compute exact effect reachability, enable the DST recorder-seam query.
- Otherwise: evaluate an ANF text parser as a separate, scoped effort.

### Phase 4: Type-Class / Instance Model (optional)

- Design `inherits`/`implements` analogs from type classes and instances; populate the reserved columns.

## CI Shape

Extraction is a batch tool, not a fast-PR gate. Proposed:

```bash
# refresh graph (manual or nightly)
scripts/ailang-graph/extract.sh        # -> .ailang-graph/*.csv + *.svg

# advisory checks once stable
#  - no new dead modules
#  - no module gains Net/FS effect unexpectedly (effect-graph diff)
```

Effect-graph diffs in CI are a candidate future gate: surfacing when a previously-pure module acquires `{Net}`/`{FS}` is a meaningful self-evolution signal for the harness.

## Acceptance Criteria

The first implementation is acceptable when:

- The extractor runs over `src/`, produces CSVs, and loads cleanly into chDB.
- `code_graph_query` answers a module-dependency query against Motoko's own source.
- The effect graph correctly lists functions carrying `{Env, FS, Net}` for a spot-checked sample.
- Module extraction failures are recorded, not silently dropped.
- The `imports`-based query "transitive importers of `registry_generated`" returns a non-empty, spot-verified set (serving DST R3/R13).
- A module-dependency SVG and an effect-graph SVG render.
- No step requires a network or a live model.

## Consequences

Positive:

- Motoko gains a queryable map of its own structure and capability/effect surface.
- The entire `code-graph` downstream pipeline is reused; net new code is small.
- DST preconditions (effect inventory, registry-import reachability) become one-query answers.
- The effect graph is a novel self-verification signal unavailable in the C# graph.

Negative:

- The high-value `invokes` call graph is blocked on an upstream AILANG feature (`debug ast --json`).
- `inherits`/`implements` have no clean v1 analog; schema columns sit empty.
- The extractor is coupled to the textual `iface` `type`/`effects` format and the `ailang.iface/v1` schema; AILANG minor bumps require re-validation.
- Two structural graphs (this + `code-graph`) and one decision graph (`omnigraph`) now coexist; their boundaries must stay documented to avoid confusion.

## Rejected Alternatives

### Port `code-graph`'s Roslyn approach wholesale

Rejected. Roslyn's cost exists because C# lacks an introspection CLI. AILANG ships `iface`; reimplementing a semantic layer would be wasted effort.

### Write an ANF parser for `debug ast` now

Deferred, not rejected. The module + effect graph delivers most value with zero parsing risk. Requesting `--json` upstream is cheaper than maintaining an ANF parser against an evolving compiler.

### Extend `omnigraph` to hold code structure

Rejected for v1. `omnigraph` is a decision/architecture graph with a different schema and population mechanism. Forcing code structure into it conflates intent with implementation. A future `Component → module` link is the right integration point.

### Pure grep-based extraction (no chDB)

Rejected. Imports are grep-able, but `uses`/effects/reachability need joins. Reusing chDB + `code_graph_query` gives the agent SQL for free.

## Open Questions

- Extractor implementation language: AILANG script, Python, or Bun/TS? (Leaning script-over-`iface`, since no compiled host is needed.)
- Output directory: `.ailang-graph/` vs. reuse `.code-graph/` with a namespace?
- Should `code_graph_query` gain a target switch (Zeus vs. Motoko), or should a sibling tool be added?
- Slug scheme for symbols vs. modules — confirm collision-free path encoding.
- Is approximate import-based effect reachability trustworthy enough for a CI gate before the exact call graph exists?
- Should the effect-graph diff become a blocking CI signal, and at what threshold?
