# ADR-002: AILANG Code & Effect Graph Architecture for Motoko

Date: 2026-06-27
Status: Proposed

## TL;DR

Build `ailang-graph`: a structural and effect graph of Motoko's own ~671 `.ail` source files, modeled on the existing C#/Zeus `code-graph` but thin, because AILANG ships the semantic layer (`ailang iface`) that C# lacked.

- **How (two sources):** (1) `ailang iface` per module for exported types/functions with type signatures and effect rows; (2) a **raw-source parser** for `import` edges and the internal-function **call graph**. Emit CSVs → load into ClickHouse → reuse the existing `load.py` and SVG pipeline.
- **Headline feature:** an effect graph — "which functions can reach `Net`/`FS`/`Env`" — computed over the real call graph, which the C# graph structurally cannot express.

> **Review comment (GPT-5.5):** "Real call graph" overclaims the v1 source. The ADR later says the graph is heuristic, source-parsed, and approximate, with known false positives and false negatives. Use "approximate source-parsed call graph" here and in any query output so agents do not treat the results as compiler-derived facts.

- **Consumers:** Claude Code and Codex, via an agent-agnostic CLI and/or MCP surface documented in `AGENTS.md` (not a harness-specific plugin). The `.agent/tools/*.ts` scripts are reference-only.
- **v1 scope:** module/import edges, exported types/signatures/effects (from `iface`), **and an approximate internal-function call graph from source parsing** — no longer blocked on upstream. A PoC over `src/` produced 1058 call-edges across 415 functions in 0.1s with zero hydration, including modules `iface` cannot load.
- **Preconditions:** the call/import graph needs neither hydration nor `clickhouse` (pure text). The `iface`-derived type/effect layer needs full package hydration (shared with ADR-001); loading into ClickHouse needs the `clickhouse` binary.
- **Serves ADR-001 (DST):** answers import-reachability (R3/R13), the effect inventory (R7), and — now that the call graph ships in v1 — the internal call-seam questions (R8 `dispatch_step`, R15 `try_emergency_compaction`), approximately.
- **Upstream `ailang debug ast --json`:** demoted from a blocker to a future *precision* upgrade for the call graph (its current ANF text dump is too shallow to parse).

## Context

Motoko's own source is ~671 `.ail` files with ~2848 `import` lines across `src/core`, `src/tui`, `src/core/ext`, `scripts`, and `examples`. As the harness self-evolves, no human-curated map of that structure exists. Recurring development questions — "who imports `registry_generated`?", "which exported functions carry `{Env, FS, Net}` effects?", "is this module dead?" — are answered today by ad-hoc grep, which is slow, lossy, and not queryable.

A working precedent exists in this repo: `code-graph/` extracts a type-level dependency graph from the *external* Zeus C# codebase using Roslyn, loads it into ClickHouse, and renders Mermaid/SVG. Two reference tool scripts, `code-graph-query.ts` and `code-graph-refresh.ts`, sit at `.agent/tools/`. They are **reference-only** and Zeus-targeted (refresh extracts `src/Zeus.csproj`; query views a Zeus table list), but they document a reusable *query mechanism*: auto-create ClickHouse views over whatever CSVs exist in a directory, then run `clickhouse local --output-format JSON`. That mechanism — not the scripts themselves — is what this design borrows, and it could equally seed a future Motoko extension. There is still no structural code graph of Motoko's own AILANG source.

The graph must be consumable by the coding agents that drive this repo — **Claude Code and Codex** — not by any one harness's plugin format. Both consume tools through the same neutral channels already present here: shell commands (their Bash tool), MCP servers (`.mcp.json` already wires `ailang-docs`), and instructions in `AGENTS.md`. The agent surface for `ailang-graph` is therefore a small CLI and/or an MCP server documented in `AGENTS.md` — deliberately agent-agnostic.

The `code-graph` extractor is large (~50 KB of `Program.cs`) largely because C# has no introspection CLI — it must drive MSBuild Workspaces and Roslyn semantic models by hand. AILANG removes most of that cost: it ships structured introspection as first-class CLI commands. This ADR's central bet is to treat that introspection as the semantic layer instead of reimplementing it.

### Validated Against AILANG v0.26.0

All capability claims below were verified directly against the local binary. The repo adopted `v0.26.0` (commit `3b52a24`) on 2026-06-28, re-validated with `make check_core` (24/24 modules, 4/4 extensions) and `make test_core` (19/19). The introspection findings were first established on `v0.24.2` and **re-confirmed identical on v0.26.0** — notably `debug ast` remains shallow across the two-minor jump. This grounding, and its caveats, are load-bearing:

- **`ailang iface <module>` → JSON, schema `ailang.iface/v1`.** Emits `module`, `types` (each with optional `ctors`), and `funcs` (each with `name`, `type` signature string, `effects` array, `pure` flag). Cleaner than any single Roslyn API.
- **`iface` emits only EXPORTED symbols.** Verified: `src/core/compaction.ail` has 5 exported and 11 internal top-level functions, but `iface` returns only the 5 marked `export`. Internal helpers (`try_emergency_compaction`, `elide_walk`, `count_tool_msgs`, …) are invisible to it. The `iface`-derived *typed* layer is therefore exports-only; whole-program coverage (internal functions, call edges) comes from the source parser below.
- **`iface` requires full dependency resolution.** Verified: `iface src/core/agent_loop_v2.ail` fails with `registry package … cache not found` / `requires ailang.toml and ailang.lock` unless every transitive registry package is hydrated. The heaviest, most interesting modules are exactly the ones that fail without hydration — this is the *same* precondition as ADR-001 (DST).
- **`iface` exits 0 even on failure.** Verified: a failed extraction prints an error and empty/partial stdout but returns exit code 0. Failure detection must parse output, not trust the exit code.
- **`pure` is NOT "effect-free".** Verified: `print_version` reports `pure: true` *and* `effects: ["IO"]`, type `(())->()!{IO}`. The effect graph must be built from the `effects` array; the `pure` flag means something else and must not be used as an effect signal.
> **Review comment (GLM 5.2):** `pure` is dismissed without investigation. In many effect systems `pure` denotes referential transparency modulo tracked effects, or absence of heap mutation — either would be a useful additional graph signal (e.g. distinguishing `!{IO}`-tagged but otherwise-pure functions). Either verify its meaning against the binary/docs and use it, or file an upstream question via `ailang-feedback` and note it as a future signal. Don't drop a compiler-emitted field unexamined.
- **`ailang debug ast <file>`** — Core AST (ANF), **text output, not JSON**, and **too shallow to parse** (confirmed on both v0.24.2 and v0.26.0): it prints only top-level `*core.LetRec [#id]` nodes with no body or call detail, `--show-types` does not expand them, and `--json` is silently ignored (it is only wired for `debug cycles`). So the ANF dump is not a viable call-graph source.
- **Raw-source call-graph parsing is viable (PoC validated).** A heuristic source parser — segment top-level `func` decls (all at column 0), strip `--` comments and string literals, match `name(` calls, resolve against locally-defined and imported names — produced **1058 resolved call-edges across 415 functions in `src/` in 0.1s**, with **no compilation and no hydration**. It runs on `agent_loop_v2.ail`, which `iface` cannot load, and captures internal seams `iface` hides (`loop_v2 → dispatch_step`; `compact_step → try_emergency_compaction`). Known approximations: constructor calls (`Ok`/`Err`) appear as edges unless filtered via `iface` ctors; calls inside string interpolation (`${show(x)}`) are dropped; higher-order and type-class-dispatched calls resolve to the name, not the concrete target.
- **`ailang tree`** — works here; emits the package dependency tree (`local/motoko_agent` → `sunholo/*`). Package-level deps are available for free.
- **`import` lines** are explicit, one per line, grep-able. They include `std/*` (filtered out for the module graph) and support aliases / selective symbol lists (`import std/list as List (length)`), which the parser must handle.
- **`clickhouse` is an *external prerequisite*** — the reference query script spawns `clickhouse local` (the README's "chDB" wording notwithstanding). Verified: no `clickhouse` binary on PATH here. The pipeline is contingent on installing it.
- **The query mechanism is the reusable part.** In the reference script only the table list and CSV directory are Zeus-specific; view creation, the `clickhouse local` invocation, JSON parsing, and row truncation are target-agnostic. Re-implementing that mechanism over the AILANG-graph CSVs is straightforward; the refresh script's Zeus extraction has no reusable core and is superseded by the extractor this ADR proposes.

## Relationship To Existing Graph Tooling

Distinct from, and complementary to, the two graphs already in the repo.

**`code-graph/` (structural, C#/Zeus).** Same *artifact shape* (types + edges → ClickHouse → Mermaid), different *target*. This ADR reuses the language-agnostic downstream pieces that genuinely exist here — `load.py`, the `schema.sql`/ClickHouse model, the SVG-render path, and the view-and-query mechanism documented by the reference query script — and replaces the Roslyn extractor (`Program.cs`). The agent surface is a CLI/MCP usable by Claude Code and Codex (see Phase 2), not a port of the reference `.ts` scripts.

**`omnigraph/` (decision/architecture).** `omnigraph/schema.pg` defines `Decision`, `Component`, `Governs`, `Supersedes`, `DependsOn` — an ADR/architecture knowledge graph populated from docs and sessions. It captures *intent*, not code structure. They meet at the `Component` node: a future edge can link an omnigraph `Component` to the `.ail` modules realizing it, but that is out of scope for v1.

## Decision

Build an **AILANG code & effect graph extractor** for Motoko's own source, modeled on `code-graph` but thin, using **two complementary sources**: `ailang iface` for the typed public layer, and a **raw-source parser** for imports and the internal call graph.

The extractor will:

1. Enumerate Motoko `.ail` modules under configured roots (`src`, `scripts`, `examples`).
2. Run `ailang iface` per module to collect **exported** types (with constructors) and **exported** functions (with type signatures, effect rows). Detect and record extraction failures by parsing output, not exit code.
3. Parse raw source for `import` statements (filtering `std/*`, handling aliases/symbol lists) → module-dependency graph, and for `func` definitions and `name(` call sites → the **internal-function call graph** (`invokes`). Source parsing needs no compilation, so it covers every module including those `iface` cannot load, and every function including internal ones.
4. Derive a **type-use graph** from exported function signatures; build the **effect graph** from `iface` effect rows as sources, propagated over the call graph so internal functions inherit reachable effects.

> **Review comment (GPT-5.5):** Effect propagation is underspecified and may be directionally wrong. If `invokes` means `caller -> callee`, reachable effects normally propagate from callee back to caller: if `A` calls `B` and `B` can perform `Net`, then `A` reaches `Net`. Propagating exported `iface` effects forward to internal callees can falsely mark pure helpers as effectful. Define declared effects vs. reachable effects, call-edge direction, and the propagation algorithm before implementation.
> **Review comment (GLM 5.2):** The effect graph has a structural blind spot beyond call-graph heuristics. Effect *sources* are only exported functions whose `iface` `effects` array lists the effect — internal functions that directly call a `std/net`/`fs`/`env` primitive have no `iface` row and are not sources, so they (and their callers) are invisible to "reaches `{Net}`" unless reverse-reachable from an exported function that already declares the effect. This yields systematic false negatives even when `iface` succeeds on every module, independent of call-graph precision. Separately, the ADR never establishes whether `iface` effect rows are direct-only or transitive — a load-bearing unknown that determines whether forward propagation double-counts (if transitive, an exported row already carries the helper's effect, so propagating it forward to the helper's other callers is double-counting). A Phase 0 experiment resolves it: take an exported function reaching an effect through an internal helper, and check whether the helper's effect appears in the exported row. This must happen before implementation, not during it.

5. Emit CSVs in the `code-graph` schema, plus new `invokes` / `effects` / `effect_edges` tables, plus an `extraction_status` table recording per-module `iface` success/failure (source-derived edges are independent of it).
> **Review comment (GLM 5.2):** No staleness or migration story. For agents treating this graph as the codebase map, staleness is a correctness bug, not cosmetics. The `extraction_status` table should carry a build timestamp and `ailang_version`, and the query surface should warn or refuse on stale graphs. CSV format versioning is also unspecified — what happens to loaded data when `ailang.iface/v1` bumps?
6. Load via the reused ClickHouse pipeline; expose the graph to Claude Code and Codex through an agent-agnostic surface (CLI and/or MCP) documented in `AGENTS.md`.

Scoping decisions following validation:

- **Two layers with different coverage.** The typed layer (types, exported signatures, effect rows) comes from `iface` and is exports-only + hydration-dependent. The structural layer (imports, call graph, internal-function nodes) comes from source parsing and is whole-program + hydration-free. Internal functions are nodes carrying call edges but no `iface` type signature.
- **The call graph is approximate**, by source-parse heuristics (see Constraints). It is labeled as such wherever consumed.
- **Hydration is required only for the typed layer.** The structural/call/effect-source extraction proceeds without it; missing hydration degrades type/effect annotations, not the graph's existence.

Upstream `ailang debug ast --json` is **demoted from a blocker to a future precision upgrade**: the current ANF text dump is too shallow to parse, and the source parser already delivers a usable call graph. We will still file the request via the `ailang-feedback` channel so a precise, type-resolved call graph can replace the heuristic one later.

## Decision Drivers

- The language-agnostic downstream pieces already exist: `load.py` and the ClickHouse/`schema.sql` model reuse directly; `visualize.py`'s SVG-render path reuses, though its namespace-based graph-building needs replacing for AILANG's path-based modules.
- `ailang iface` removes the dominant cost (semantic introspection) that made the C# extractor large.
- The effect graph answers capability questions C# tooling structurally cannot, and is the highest-value Motoko-specific edge — and propagating effect sources over the source-parsed call graph extends it to internal functions.
- The call graph ships in v1 without upstream changes: source parsing is hydration-free, sees internal functions, and a PoC ran the whole `src/` tree in 0.1s.
- A queryable structure + effect graph directly serves in-flight work, especially ADR-001 (DST).
- Module/import edges are extractable today with zero new AILANG features and zero hydration.

## Constraints

- Pinned to AILANG `v0.26.0`, schema `ailang.iface/v1` (schema unchanged from v0.24.2). Any minor bump must re-validate the extractor against actual emitted JSON and the `type`/`effects` string formats, not docs.
- **`iface` sees only exported symbols.** The *typed* layer (type signatures, declared effect rows) covers exports only. Internal functions still appear as call-graph nodes from source parsing, but without `iface` type signatures; their effects are inferred by propagation, not read directly.
- **Package hydration is required for the typed layer only.** `iface` over modules with registry imports needs the full dependency set hydrated (same as ADR-001). The structural layer (imports, call graph) is hydration-free, so the graph always exists; missing hydration degrades type/effect annotations, not structure.

> **Review comment (GPT-5.5):** For the headline effect graph, missing typed extraction can hide effect sources entirely, not merely degrade annotations. Queries like "what reaches `Net`" can produce false negatives when `iface` failed on reachable modules. The query surface should include extraction coverage in answers, or refuse definitive effect answers when relevant typed data is missing.
> **Review comment (GLM 5.2):** "Hydration-free" overstates the structural layer. Intra-module and direct-import cross-module edges are hydration-free, but correct cross-module resolution in the presence of re-exports needs the re-exporting module's export list — i.e. `iface`, which may need hydration. A call through a re-exported symbol resolves to the re-exporter, not the origin, silently degrading R8/R15 edge correctness. Narrow the claim to "intra-module and direct-import cross-module edges are hydration-free."

- **`iface` exits 0 on failure.** The extractor must classify each module's `iface` result as `ok` / `failed` / `partial` from output content and persist it, so consumers know where the typed layer is missing.

> **Review comment (GPT-5.5):** The `ok` / `failed` / `partial` contract is load-bearing but undefined. Specify concrete classification rules and fixture tests for empty stdout, malformed JSON, valid JSON with diagnostics, missing `funcs`, missing `effects`, stderr-only failures, and partial module output.
> **Review comment (GLM 5.2):** Defining a load-bearing contract during implementation is too late — it belongs in the ADR. Proposed minimum: `ok` = valid JSON with `funcs`/`types` keys; `partial` = valid JSON whose `funcs` is empty/missing on a module that source-parse found functions for; `failed` = no valid JSON on stdout regardless of exit code. Fixture the stderr-only and truncated-JSON cases explicitly.

- **`pure` ≠ effect-free.** Declared effects derive solely from the `effects` array.
- **The call graph is heuristic.** Source parsing resolves bare/qualified `name(` calls against locally-defined and imported names. Known imprecision: constructor calls (`Ok`/`Err`) need filtering via `iface` ctors; calls inside string interpolation are dropped; higher-order calls and type-class method dispatch resolve to the name, not the concrete instance; `let`-shadowing of an imported name can misresolve. These are acceptable for an approximate graph and are the reason the upstream `--json` precision upgrade is still wanted.

> **Review comment (GPT-5.5):** Import and symbol resolution complexity is still understated. Selective imports, aliases, reexports, same-name functions across modules, local bindings, shadowing, constructors, and type-class dispatch all affect resolution. The ADR should either narrow the v1 guarantees or require parser fixtures that demonstrate expected behavior for these cases.

- AILANG has no classes. No direct `inherits`/`implements` analog; the closest concepts are type classes and instances. v1 will not synthesize those edges (columns reserved, empty).
- Effect-row parsing depends on the textual `type` signature format (e.g. `(())->()!{IO}`) and must be re-validated on upgrades.
> **Review comment (GLM 5.2):** Contradiction with line 35: the `effects` array is treated as the authoritative structured source, yet this line depends on textual `(())->()!{IO}` parsing. If the array is complete, no text parsing is needed; if it isn't, the ADR must specify what the text parser extracts that the array omits (e.g. handled/quantified effects). Pick one and reconcile both lines.
- AILANG module identity is file/path-based (`src/core/types`), not `namespace.Type`. Slugs are module-or-symbol paths, not type FQNs.
- `clickhouse` (`clickhouse local`) is an external prerequisite that must be installed; reuse of the pipeline is contingent on it.
> **Review comment (GLM 5.2):** ClickHouse is unjustified for this workload. The graph is small (671 files, ~1k edges); ClickHouse is an OLAP engine built for billions of rows. Worse, making the *agent surface* SQL-over-ClickHouse means every agent environment that queries the graph must install the binary — the tool whose purpose is agent consumption becomes non-portable to the agents it serves. The `load.py`/`schema.sql` reuse defense is circular (`schema.sql` is ClickHouse DDL; generic CSV loading is ~20 lines). SQLite or DuckDB would be zero-install, embedded, adequate, and keep the surface portable. Justify ClickHouse on real grounds or switch.

## Edge & Node Model

Nodes:

- **module** — one per `.ail` file. Slug = repo-relative module path (`src/core/agent_loop_v2`). Carries `extraction_status`.
- **type** — exported ADTs/records via `iface`, with constructors. Slug = `{module}.{TypeName}`.
- **func** — all top-level functions (exported and internal), discovered by source parsing. Slug = `{module}.{func_name}`. Exported funcs additionally carry the `iface` signature and declared effects; internal funcs carry call edges and propagated effects only.

Edges:

| Edge | Source | Status in v1 |
|------|--------|--------------|
| `imports` | `import` lines (std-filtered, alias-aware) | ✅ module → module |
| `invokes` | source-parsed `name(` call sites, resolved to local/imported names | ✅ func → func (approximate; whole-program, hydration-free) |
| `uses` | types referenced in exported `func.type` signatures | ✅ func/module → type (exported signatures) |
| `effects` | exported `func.effects` array | ✅ new table: `func_slug,effect` |
| `effect_edges` | declared effects propagated over `invokes` | ✅ reachability over the call graph (approximate, follows call-graph precision) |
| `inherits` / `implements` | type classes / instances | ⛔ deferred (empty columns) |
| `channels` | effects + extension-hook wiring | ⛔ deferred |

> **Review comment (GPT-5.5):** The `effect_edges` table is not concrete enough to implement safely. For audits, provenance matters: a useful schema likely needs `func_slug`, `effect`, `source_func_slug`, `distance`, and a confidence/source field. Otherwise consumers cannot distinguish a declared effect from a transitive, heuristic reachability result.

The effect graph is the headline Motoko-specific capability: "which functions can reach `Net`/`FS`/`Env`" — computed by propagating `iface`-declared effects over the source-parsed call graph, a capability/security view the C# graph cannot express. Its precision is bounded by the call-graph heuristics (see Constraints), which must be carried wherever it is queried.

## Architecture / Components

```
src/{core,scripts,examples}/**.ail
  typed layer  → ailang iface (per module; failure-classified) → types, exported sigs, effect rows ─┐
  struct layer → source parse: imports, func defs, name( call sites → import + call graph         ─┤
               → effect propagation (iface effects over call graph)                                ─┴─→ extractor → .ailang-graph/*.csv
  → ClickHouse load (reuse load.py/schema.sql)   → OLAP tables
  → visualize.py (SVG path reused; graph-building new) → .mmd → .svg
  → CLI / MCP surface (Phase 2)  → Claude Code & Codex (SQL queries, documented in AGENTS.md)
```

| Component | Role | New / Reuse |
|-----------|------|-------------|
| `ailang-graph` extractor | Drives `ailang iface` (typed layer) + raw-source parser (imports, call graph) + effect propagation, classifies `iface` failures, emits CSVs | **New** (replaces `Program.cs`; call-graph parser PoC-validated) |
| `schema.sql` | ClickHouse table defs (+ `invokes`, `effects`, `effect_edges`, `extraction_status`) | Extend existing |
| `load.py` | Load CSVs into ClickHouse | Reuse (generic; 0 Zeus coupling) |
| `visualize.py` | Mermaid + SVG views | Partial reuse: SVG-render path reusable, but its graph-building is namespace-coarsening logic that does not map to AILANG's path-based modules — module-dep + effect views are largely new |
| CLI / MCP query surface | SQL over the Motoko graph for Claude Code & Codex, documented in `AGENTS.md` | **New** (reuses the reference script's view-and-query mechanism) |
| `.agent/tools/*.ts` | Reference implementations of the query/refresh mechanism | Reference-only; possible base for a Motoko extension |
| `clickhouse` (`clickhouse local`) | OLAP engine | External prereq (install) |

Extractor implementation language is an open question; the leading option is a small script (Python or Bun/TS) that shells `ailang iface` and parses source, since no compiled host is needed. The PoC is ~70 lines of Python.

## How This Serves ADR-001 (DST)

With the call graph now in v1, most DST questions are served (the call graph approximately):

- **Registry-import precondition (DST R3/R13):** "all transitive importers of `registry_generated` / `init_runtime_with_config`" is one query over `imports`. Hydration-free — fully delivered in v1.
- **Recorder seam (DST R8):** "who calls `dispatch_step`" is one query over `invokes`. The PoC already returns `agent_loop_v2.loop_v2 → stub_step.dispatch_step`. Delivered in v1, approximately.
- **Emergency-compaction (DST R15):** `compact_step` / `compact_step_actual → try_emergency_compaction` are likewise in the PoC output. Delivered in v1, approximately.
- **Effect satisfaction (DST R7):** exported effect rows from `iface` (e.g. `init_runtime_with_config : ! {Env, FS, Net}`) propagated over `invokes` to internal callees. Delivered in v1; precision follows the call-graph heuristics.
- **Constant duplication (DST R5):** a literal scan over source can flag duplicated `75000` / tier constants across all functions, not just exported signatures.

The honest summary: v1 serves R3/R13 exactly and R7/R8/R15 approximately (bounded by call-graph heuristics). The upstream `--json` upgrade later makes R7/R8/R15 exact.

## Implementation Plan

### Phase 0: Setup + Contract Validation

- Hydrate the full registry dependency set for the **typed layer** (shared precondition with ADR-001); confirm `iface` succeeds on a heavy module (`agent_loop_v2`) after hydration. The structural layer needs no hydration.
- Install `clickhouse` (the `clickhouse local` binary).
- Snapshot `iface` JSON for a representative module set; pin the `ailang.iface/v1` shape and the `type`/`effects` string formats.
- Define the `iface` failure-classification rule (ok/failed/partial).
- File the upstream `ailang debug ast --json` request via the `ailang-feedback` skill as a **future precision upgrade** (not a blocker — its current dump is too shallow to parse).

### Phase 1: Structural + Call Graph (no AILANG features, no hydration)

- Harden the PoC source parser: imports (std-filtered, alias-aware), `func` discovery (all functions), `name(` call resolution against local + imported names, constructor filtering via `iface` ctors.

> **Review comment (GPT-5.5):** This contradicts the phase title. Constructor filtering via `iface` ctors uses the typed layer and can be hydration-dependent. Move constructor filtering to Phase 2, make it best-effort only when `iface` succeeds, or derive constructors from source in Phase 1.
> **Review comment (GLM 5.2):** The deeper fix is not "move to Phase 2" — the hydration-free path can *never* use `iface` ctors, so constructor noise is permanent there unless constructors are source-derived (parsing `type T = Ok(_) | Err(_)` decls). Commit to source-derived constructor filtering for the structural layer; treat `iface` ctors as a precision upgrade only. Resolve Open Question (line 302) in the design rather than deferring it.

- Emit `funcs.csv`, `imports.csv`, `invokes.csv`.
- Load into ClickHouse; add module-dependency and call-graph Mermaid/SVG views.
- This phase runs on the whole tree regardless of hydration.

### Phase 2: Typed Layer + Effect Graph

- Add the `iface` pass with failure classification; emit `code_types.csv`, `uses.csv`, `effects.csv`, `extraction_status.csv`.
- Propagate declared effects over `invokes` to produce `effect_edges`; add the effect-graph view.
- Effect annotations degrade gracefully where `iface` failed; structure remains intact.

### Phase 3: Agent Surface

- Build the surface for Claude Code and Codex, reusing the reference script's mechanism (auto-views over the AILANG tables; `clickhouse local --output-format JSON`; row truncation). Ship as a CLI (callable via the agents' Bash tool) and/or an MCP server alongside the existing `ailang-docs` entry in `.mcp.json`.
- Document the surface and example queries in `AGENTS.md` so both agents discover it.
- Add dead-module detection, fan-in/fan-out, the DST R3/R13 importer-reachability query, and the R8/R15 call-seam queries.

> **Review comment (GPT-5.5):** Dead-module detection is not defined. Deadness requires an explicit root set and exclusions for binaries, scripts, examples, tests, generated modules, extension entry points, and dynamically loaded modules. Without that contract, the feature will produce noisy or dangerous recommendations.
> **Review comment (GLM 5.2):** Stronger than "undefined": dead-module detection over an approximate call graph is actively harmful in v1. The heuristic misses higher-order calls, type-class dispatch, and dynamic loading — exactly the patterns that keep a "dead" module alive — so an agent refactoring on this verdict receives false-negative deadness and may delete live code. Remove from Phase 3; restrict to "unimported modules" (transitive `imports` closure from a declared root set), which is at least sound, or defer entirely to Phase 4 behind the precise call graph.


### Phase 4 (later): Precision + Type-Class Model

- When `ailang debug ast --json` lands, replace the heuristic call graph with a type-resolved one; effect reachability and R7/R8/R15 become exact.
- Optionally design `inherits`/`implements` analogs from type classes and instances; populate the reserved columns.

## CI Shape

Extraction is a batch tool, not a fast-PR gate.

```bash
# precondition (shared with ADR-001)
ailang lock   # + explicit install of any unhydrated registry packages

# refresh graph (manual or nightly)
scripts/ailang-graph/extract.sh        # -> .ailang-graph/*.csv + *.svg
#   - fails loudly if any module's extraction_status is unexpectedly 'failed'

# advisory checks once stable
#   - no new dead modules
#   - effect-graph diff: surface when an exported function newly gains Net/FS/Env
```

Effect-graph diffs are a candidate future gate: a function that newly *reaches* `{Net}`/`{FS}` is a meaningful self-evolution signal. It is advisory while reachability follows the approximate call graph, and a candidate blocking gate once the `--json` precision upgrade (Phase 4) makes it exact.

## Acceptance Criteria

The first implementation is acceptable when:

- The structural extractor runs over `src/` with no hydration and produces `imports.csv` + `invokes.csv` for **all** modules, including those `iface` cannot load (e.g. `agent_loop_v2.ail`).
- The typed pass classifies each module's `iface` result ok/failed/partial and never silently drops a module's typed layer.
- The agent surface (CLI/MCP) answers, against Motoko's own source: a module-dependency query, "transitive importers of `registry_generated`" (DST R3/R13), "who calls `dispatch_step`" (DST R8), and "what reaches `{Net}`/`{FS}`/`{Env}`" (DST R7).
- The call graph is spot-checked against hand-read source for a sample module, and its approximation limits are documented in the surface's output.

> **Review comment (GPT-5.5):** Spot-checking one sample module is too weak for a heuristic parser that will drive architecture decisions. Acceptance should require golden parser fixtures for imports, aliases, selective imports, comments, strings, interpolation, constructors, local shadowing, qualified calls, same-name symbols, and failed `iface` output.
> **Review comment (GLM 5.2):** Speed and coverage are measured; precision and recall are not. An approximate call graph that is fast but wrong is not an asset, and "approximately delivered" for R8/R15 is unbounded without a measured sample. Require precision/recall against a hand-validated 3-module sample, reported in the ADR before it is marked Accepted — not deferred to implementation, and not a single spot-check.

- A module-dependency SVG and a call/effect SVG render.
- No step requires a network or a live model (typed-layer hydration aside).

## Consequences

Positive:

- Motoko gains a queryable map of its structure, call graph, and effect/capability surface — covering internal functions, not just the public interface.
- The structural/call layer needs no hydration and no upstream changes; the PoC runs the whole tree in 0.1s.
- The ClickHouse load model reuses directly and the reference scripts' query mechanism is reused as logic; net new code is the extractor, the visualization's graph-building, and the CLI/MCP agent surface.
- DST R3/R13 are one-query answers, and R7/R8/R15 are served approximately in v1.
- The effect graph is a novel self-verification signal unavailable in the C# graph.

Negative:

- The call graph is **heuristic** (constructor noise, dropped interpolation calls, higher-order/type-class imprecision). It is approximate until the upstream `--json` precision upgrade; consumers must treat it as such.
- The *typed* layer (signatures, declared effects) is still exports-only and hydration-dependent; CI must hydrate for it (shared cost with ADR-001). Coverage is uneven: a module can have call edges but no typed annotations.

> **Review comment (GPT-5.5):** This consequence should be reflected in the agent UX, not only documented here. Any effect query should report the number/list of modules with missing typed extraction and mark results as incomplete when missing modules could affect the answer.

- `inherits`/`implements` have no clean v1 analog; columns sit empty.
- The extractor is coupled to the `ailang.iface/v1` schema and the textual `type`/`effects` formats, and to AILANG source-syntax conventions (col-0 decls, `--` comments); minor AILANG bumps require re-validation.
- `clickhouse` must be installed wherever the graph is loaded.
- Three graphs now coexist (this + `code-graph` + `omnigraph`); boundaries must stay documented.

## Rejected Alternatives

### Port `code-graph`'s Roslyn approach wholesale

Rejected. Roslyn's cost exists because C# lacks an introspection CLI. AILANG ships `iface`; reimplementing a semantic layer would be wasted effort.

### Ship the agent surface as a harness-specific plugin

Rejected. Binding the query surface to one harness's plugin format would exclude the agents that actually drive this repo. Claude Code and Codex both consume neutral channels (shell commands, MCP, `AGENTS.md`), so the surface is a CLI and/or MCP server. The `.agent/tools/*.ts` scripts remain reference-only — useful as a base for a future Motoko extension, not as the consumption path.

### Parse the `ailang debug ast` ANF dump for the call graph

Rejected for v1. On both v0.24.2 and v0.26.0 the dump prints only top-level `*core.LetRec [#id]` nodes — too shallow to recover call edges. Raw-source parsing yields a usable call graph today; the upstream `--json` upgrade is the path to a precise one later.

### Defer the call graph until upstream `--json` (original plan)

Rejected. The PoC showed source parsing delivers an approximate call graph with zero hydration and no upstream dependency, including the internal seams DST needs (`dispatch_step`, `try_emergency_compaction`). Blocking v1 on upstream would needlessly delay R8/R15 coverage. The heuristic call graph ships now; `--json` upgrades it in place.

### Extend `omnigraph` to hold code structure

Rejected for v1. Different schema, different population mechanism, and it conflates intent with implementation. A future `Component → module` link is the right integration point.

### Pure grep-based extraction (no ClickHouse)

Rejected. Imports are grep-able, but `uses`/effects/reachability need joins. Reusing ClickHouse gives the agent SQL.

> **Review comment (GPT-5.5):** This rejects grep-only extraction but does not justify ClickHouse over simpler embedded query engines such as SQLite or DuckDB. For a repo-local graph over hundreds of files, ClickHouse adds an external binary and CI friction. If reuse is the main reason, say so explicitly and accept the cost; otherwise evaluate a lighter embedded option.

## Open Questions

- Extractor implementation language: Python or Bun/TS? (PoC is Python; leaning that way.)
- Output directory: `.ailang-graph/` vs. namespacing inside `.code-graph/`.
- Agent surface: CLI only, MCP only, or both? MCP matches the existing `.mcp.json` pattern and gives structured discovery; a CLI is simpler and works through the agents' Bash tool with zero registration.

> **Review comment (GPT-5.5):** The primary agent surface should probably not remain open for v1 acceptance. Pick CLI-first or MCP-first so implementation, documentation, tests, and examples target one stable consumption path.
> **Review comment (GLM 5.2):** Decide CLI-first for v1. It is stateless, works through the agents' Bash tool with zero registration and no running process, and is the boring portable choice. MCP can wrap the CLI later for structured discovery. Leaving the surface open guarantees that Phase 3 implementation, tests, docs, and `AGENTS.md` examples all target a moving contract.

- Slug scheme for symbols vs. modules — confirm collision-free path encoding.
- Constructor handling: drop `Ok`/`Err`/etc. from `invokes`, or keep them as a separate `constructs` edge type?
- How aggressively to chase call-graph precision before `--json` lands — e.g. parse string interpolation, resolve `let`-shadowing — vs. accepting the heuristic and waiting for the upstream upgrade?
