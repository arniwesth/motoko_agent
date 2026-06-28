# ADR-002: AILANG Code & Effect Graph Architecture for Motoko

Date: 2026-06-27
Status: Proposed

## TL;DR

Build `ailang-graph`: a structural and effect graph of Motoko's own ~671 `.ail` source files, modeled on the existing C#/Zeus `code-graph` but thin, because AILANG ships the semantic layer (`ailang iface`) that C# lacked.

- **How (two sources):** (1) `ailang iface` per module for exported types/functions with type signatures and effect rows; (2) a **raw-source parser** for `import` edges and the internal-function **call graph**. Emit CSVs → query in-process with embedded **chDB** (ClickHouse SQL, `file(...)` over the CSVs) → reuse the SVG pipeline.
- **Headline feature:** an effect graph — "which functions can reach `Net`/`FS`/`Env`" — computed over the **approximate source-parsed call graph** and validated against `iface`'s authoritative declared effects, which the C# graph structurally cannot express.

> **Review comment (GPT-5.5):** "Real call graph" overclaims the v1 source. The ADR later says the graph is heuristic, source-parsed, and approximate, with known false positives and false negatives. Use "approximate source-parsed call graph" here and in any query output so agents do not treat the results as compiler-derived facts.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted.** "Real" → "approximate source-parsed call graph" here and throughout; the CLI surface labels call-graph and effect-reachability results as approximate (with coverage/staleness banners) so agents do not mistake them for compiler-derived facts.

- **Consumers:** Claude Code and Codex, via an agent-agnostic **CLI-first** surface documented in `AGENTS.md` (MCP may wrap it later; not a harness-specific plugin). The `.agent/tools/*.ts` scripts are reference-only.
- **v1 scope:** module/import edges, exported types/signatures/effects (from `iface`), **and an approximate internal-function call graph from source parsing** — no longer blocked on upstream. A PoC over `src/` produced 1058 call-edges across 415 functions in 0.1s with zero hydration, including modules `iface` cannot load.
- **Preconditions:** the call/import graph is pure text (no hydration). The `iface`-derived type/effect layer needs full package hydration (shared with ADR-001). The query engine is embedded **chDB** (`pip install chdb`, ~712 MB) — no server/binary, but a new prerequisite to add.
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
> **Review comment (GLM 5.2):** `pure` is dismissed without investigation... Either verify its meaning against the binary/docs and use it, or file an upstream question via `ailang-feedback` and note it as a future signal. Don't drop a compiler-emitted field unexamined.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted; investigated.** Empirically `pure: true` on all 78 exported functions sampled (incl. the `!{IO}` `print_version`) → zero variance, no discriminating power today. Not dropped: it is carried as a passthrough column in `funcs` so it becomes usable if a future version makes it vary, and an `ailang-feedback` question on its exact semantics is filed. Full detail in the Constraints `pure` bullet.
- **`ailang debug ast <file>`** — Core AST (ANF), **text output, not JSON**, and **too shallow to parse** (confirmed on both v0.24.2 and v0.26.0): it prints only top-level `*core.LetRec [#id]` nodes with no body or call detail, `--show-types` does not expand them, and `--json` is silently ignored (it is only wired for `debug cycles`). So the ANF dump is not a viable call-graph source.
- **Raw-source call-graph parsing is viable (PoC validated).** A heuristic source parser — segment top-level `func` decls (all at column 0), strip `--` comments and string literals, match `name(` calls, resolve against locally-defined and imported names — produced **1058 resolved call-edges across 415 functions in `src/` in 0.1s**, with **no compilation and no hydration**. It runs on `agent_loop_v2.ail`, which `iface` cannot load, and captures internal seams `iface` hides (`loop_v2 → dispatch_step`; `compact_step → try_emergency_compaction`). Known approximations: constructor calls (`Ok`/`Err`) appear as edges unless filtered via `iface` ctors; calls inside string interpolation (`${show(x)}`) are dropped; higher-order and type-class-dispatched calls resolve to the name, not the concrete target.
- **`ailang tree`** — works here; emits the package dependency tree (`local/motoko_agent` → `sunholo/*`). Package-level deps are available for free.
- **`import` lines** are explicit, one per line, grep-able. They include `std/*` (filtered out for the module graph) and support aliases / selective symbol lists (`import std/list as List (length)`), which the parser must handle.
- **`clickhouse` is an *external prerequisite*** — the reference query script spawns `clickhouse local` (the README's "chDB" wording notwithstanding). Verified: no `clickhouse` binary on PATH here. The pipeline is contingent on installing it.
- **The query mechanism is the reusable part.** In the reference script only the table list and CSV directory are Zeus-specific; view creation, the `clickhouse local` invocation, JSON parsing, and row truncation are target-agnostic. Re-implementing that mechanism over the AILANG-graph CSVs is straightforward; the refresh script's Zeus extraction has no reusable core and is superseded by the extractor this ADR proposes.

## Relationship To Existing Graph Tooling

Distinct from, and complementary to, the two graphs already in the repo.

**`code-graph/` (structural, C#/Zeus).** Same *artifact shape* (types + edges → ClickHouse SQL → Mermaid) and **same dialect** (embedded chDB instead of `code-graph`'s `clickhouse local`), different *target*. The genuinely reused pieces are the SVG-render path and the ClickHouse query idioms; the server-oriented `load.py`/`schema.sql` are not needed (chDB queries the CSVs directly). The Roslyn extractor (`Program.cs`) is replaced by the `iface`+source extractor, and the agent surface is a CLI usable by Claude Code and Codex (see Phase 3), not a port of the reference `.ts` scripts.

**`omnigraph/` (decision/architecture).** `omnigraph/schema.pg` defines `Decision`, `Component`, `Governs`, `Supersedes`, `DependsOn` — an ADR/architecture knowledge graph populated from docs and sessions. It captures *intent*, not code structure. They meet at the `Component` node: a future edge can link an omnigraph `Component` to the `.ail` modules realizing it, but that is out of scope for v1.

## Decision

Build an **AILANG code & effect graph extractor** for Motoko's own source, modeled on `code-graph` but thin, using **two complementary sources**: `ailang iface` for the typed public layer, and a **raw-source parser** for imports and the internal call graph.

The extractor will:

1. Enumerate Motoko `.ail` modules under configured roots (`src`, `scripts`, `examples`).
2. Run `ailang iface` per module to collect **exported** types (with constructors) and **exported** functions (with type signatures, effect rows). Detect and record extraction failures by parsing output, not exit code.
3. Parse raw source for `import` statements (filtering `std/*`, handling aliases/symbol lists) → module-dependency graph, and for `func` definitions and `name(` call sites → the **internal-function call graph** (`invokes`). Source parsing needs no compilation, so it covers every module including those `iface` cannot load, and every function including internal ones.
4. Build the **effect graph** with the corrected model below (declared effects from `iface`; reachable effects seeded at stdlib-primitive call sites and propagated **backward** over `invokes`; `iface` rows used as a validation oracle). Derive a **type-use graph** from exported function signatures.

> **Review comment (GPT-5.5):** Effect propagation is underspecified and may be directionally wrong. If `invokes` means `caller -> callee`, reachable effects normally propagate from callee back to caller: if `A` calls `B` and `B` can perform `Net`, then `A` reaches `Net`. Propagating exported `iface` effects forward to internal callees can falsely mark pure helpers as effectful. Define declared effects vs. reachable effects, call-edge direction, and the propagation algorithm before implementation.
> **Review comment (GLM 5.2):** The effect graph has a structural blind spot beyond call-graph heuristics. Effect *sources* are only exported functions whose `iface` `effects` array lists the effect — internal functions that directly call a `std/net`/`fs`/`env` primitive have no `iface` row and are not sources... [whether `iface` effect rows are direct-only or transitive] determines whether forward propagation double-counts... A Phase 0 experiment resolves it... before implementation, not during it.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted; both correct, model rewritten.** I ran the Phase-0 experiment. A module with exported `pub_calls_helper` reaching `IO` only through an *internal* `helper` reports `effects: ["IO"]` on the exported function — so **`iface` effect rows are transitive** (the type system forces effects up). Consequences:
> - **Direction (GPT):** correct — the original "forward-propagate exported effects to callees" was backwards and would falsely taint pure helpers. Propagation is **backward over `invokes` (callee → caller)**.
> - **Sources (GLM):** effect *sources* are **stdlib effect primitives**, not exported functions. The seed catalog comes from `ailang builtins list --by-effect` plus `iface` on stdlib modules (each stdlib fn carries its own transitive effect row). A source-parsed call to such a primitive seeds the effect on the calling function; it then propagates backward. This covers internal functions that call primitives directly.
> - **Double-counting (GLM):** since `iface` rows are transitive, we do **not** also propagate exported rows forward — that would double-count. Instead the exported row is the **oracle**: a function's *computed* backward-reachable effects must equal its `iface` `effects` array. Divergence is a measurable signal of call-graph incompleteness (this is the precision metric — see Acceptance).
> - **Residual blind spot (GLM):** effects confined entirely to internal-only call chains never reached by any exported function, *and* primitives the seed catalog misses. The oracle bounds the first; the catalog must be kept complete for the second. Stated in Constraints.

5. Emit CSVs, plus new `invokes` / `effects` / `effect_edges` tables, plus an `extraction_status` table recording per-module `iface` result **and a build timestamp + `ailang_version`** (source-derived edges are independent of `iface`).
> **Review comment (GLM 5.2):** No staleness or migration story... `extraction_status` should carry a build timestamp and `ailang_version`, and the query surface should warn or refuse on stale graphs. CSV format versioning is also unspecified...
>
> **Author response — accepted.** `extraction_status` carries `built_at`, `ailang_version`, and a `graph_schema` integer. The CLI surface compares `built_at` against the newest `.ail` mtime and the recorded `ailang_version` against the live binary, and prints a `STALE` banner (and refuses definitive effect answers) when either drifts. A `graph_schema` bump invalidates the cache and forces a refresh; `ailang.iface/v1` is recorded per-row so a future `v2` can be migrated or rejected rather than silently mixed.
6. Query in-process with embedded **chDB** (ClickHouse SQL over the CSVs); expose the graph to Claude Code and Codex through a **CLI-first** surface documented in `AGENTS.md` (MCP may wrap the CLI later).

Scoping decisions following validation:

- **Two layers with different coverage.** The typed layer (types, exported signatures, effect rows) comes from `iface` and is exports-only + hydration-dependent. The structural layer (imports, call graph, internal-function nodes) comes from source parsing and is whole-program + hydration-free. Internal functions are nodes carrying call edges but no `iface` type signature.
- **The call graph is approximate**, by source-parse heuristics (see Constraints). It is labeled as such wherever consumed.
- **Hydration is required only for the typed layer.** The structural/call/effect-source extraction proceeds without it; missing hydration degrades type/effect annotations, not the graph's existence.

Upstream `ailang debug ast --json` is **demoted from a blocker to a future precision upgrade**: the current ANF text dump is too shallow to parse, and the source parser already delivers a usable call graph. We will still file the request via the `ailang-feedback` channel so a precise, type-resolved call graph can replace the heuristic one later.

## Decision Drivers

- The downstream is light: chDB reads the CSVs directly (`file(...)`, no load step) using the ClickHouse dialect the operator already knows, and `visualize.py`'s SVG-render path reuses — though its namespace-based graph-building needs replacing for AILANG's path-based modules.
- `ailang iface` removes the dominant cost (semantic introspection) that made the C# extractor large.
- The effect graph answers capability questions C# tooling structurally cannot, and is the highest-value Motoko-specific edge — and propagating effect sources over the source-parsed call graph extends it to internal functions.
- The call graph ships in v1 without upstream changes: source parsing is hydration-free, sees internal functions, and a PoC ran the whole `src/` tree in 0.1s.
- A queryable structure + effect graph directly serves in-flight work, especially ADR-001 (DST).
- Module/import edges are extractable today with zero new AILANG features and zero hydration.

## Constraints

- Pinned to AILANG `v0.26.0`, schema `ailang.iface/v1` (schema unchanged from v0.24.2). Any minor bump must re-validate the extractor against actual emitted JSON and the `type`/`effects` string formats, not docs.
- **`iface` sees only exported symbols.** The *typed* layer (type signatures, declared effect rows) covers exports only. Internal functions still appear as call-graph nodes from source parsing, but without `iface` type signatures; their effects are inferred by propagation, not read directly.
- **Hydration: required for the typed layer; the structural layer is hydration-free for intra-module and direct-import cross-module edges only.** `iface` over modules with registry imports needs the full dependency set hydrated (same as ADR-001). Calls through re-exported symbols resolve to the re-exporter, not the origin, unless the re-exporting module's export list is consulted (which needs `iface`) — so re-export resolution is a typed-layer precision upgrade, not a hydration-free guarantee.

> **Review comment (GPT-5.5):** For the headline effect graph, missing typed extraction can hide effect sources entirely, not merely degrade annotations. Queries like "what reaches `Net`" can produce false negatives when `iface` failed on reachable modules. The query surface should include extraction coverage in answers, or refuse definitive effect answers when relevant typed data is missing.
> **Review comment (GLM 5.2):** "Hydration-free" overstates the structural layer... Narrow the claim to "intra-module and direct-import cross-module edges are hydration-free."
>
> **Author response (Opus 4.8, 2026-06-28) — both accepted.** GLM: claim narrowed above; re-export resolution moved to the typed-layer precision upgrades and flagged as a known R8/R15 edge-correctness risk. GPT: under the corrected effect model the seed catalog (stdlib primitives) does not depend on per-module `iface`, so a *failed* module no longer hides the primitive sources it calls — but its *internal call edges past a re-export* and its node's typed annotations can still be missing. Therefore every effect answer reports `coverage = ok_modules / total_modules` and the involved modules' statuses, and returns `INCOMPLETE` (refusing a definitive "does not reach Net") when any module on the relevant reverse-reachable frontier is `failed`/`partial`.

- **`iface` exits 0 on failure**, so classification is by output content (exit code ignored). The contract, adopting GLM's proposal:
  - `ok` = stdout parses as JSON with both `funcs` and `types` keys present.
  - `partial` = valid JSON, but `funcs` is empty/absent while the source parser found ≥1 function in that module (typed layer lost, structure intact).
  - `failed` = no valid JSON on stdout, regardless of exit code (covers the empty-stdout, warning-line-prefixed, truncated-JSON, and stderr-only cases).
  Note the real-world wrinkle found in validation: `iface` may print a `Warning: …` line to **stdout** before the JSON, so the parser must locate the first `{` rather than `json.load` the whole stream. Phase 0 ships golden fixtures for: empty stdout, warning-prefixed JSON, truncated JSON, valid JSON with empty `funcs`, and stderr-only failure.

> **Review comment (GPT-5.5):** The `ok` / `failed` / `partial` contract is load-bearing but undefined. Specify concrete classification rules and fixture tests...
> **Review comment (GLM 5.2):** Defining a load-bearing contract during implementation is too late — it belongs in the ADR. Proposed minimum... Fixture the stderr-only and truncated-JSON cases explicitly.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted, specified above.** GLM's rules adopted verbatim and promoted into the ADR with the fixture list. The warning-line-on-stdout case is added from direct observation during the v0.26.0 validation.

- **`pure` carries no usable signal in v1.** Empirically `pure: true` on all 78 exported functions sampled across `src/core` + extensions, *including* `print_version` which is `!{IO}`. With zero variance — and true even for effectful functions — it cannot discriminate anything today. Its exact meaning (referential transparency modulo tracked effects? no heap mutation?) is not documented; an `ailang-feedback` question is filed, and `pure` is recorded in `funcs` as a passthrough column so it becomes a usable signal *if* it ever varies. Declared effects derive solely from the `effects` array, never from `pure`.

> **Review comment (GLM 5.2):** `pure` is dismissed without investigation... Either verify its meaning against the binary/docs and use it, or file an upstream question via `ailang-feedback` and note it as a future signal. Don't drop a compiler-emitted field unexamined.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted; investigated.** Result above: invariant `true` across 78 functions incl. an `!{IO}` one, so no discriminating power in this codebase. Not dropped — recorded as a passthrough column and an upstream question filed. If a future version makes it vary (e.g. flagging heap mutation), it lights up as a real signal with no schema change.

- **The call graph is an approximate, source-parsed graph.** It resolves bare/qualified `name(` calls against locally-defined and imported names. Known imprecision, by case: selective imports and aliases (handled); same-name functions across modules and re-exports (may misresolve — re-export needs the typed layer); constructors (filtered via **source-derived** type-decl ctors, see below); string-interpolation calls (dropped); higher-order calls and type-class method dispatch (resolve to the name, not the concrete instance); `let`-shadowing of an imported name (may misresolve). v1 does not *guarantee* correctness on these — instead Acceptance requires golden parser fixtures for each case and a measured precision/recall (see Acceptance).

> **Review comment (GPT-5.5):** Import and symbol resolution complexity is still understated. Selective imports, aliases, reexports, same-name functions across modules, local bindings, shadowing, constructors, and type-class dispatch all affect resolution. The ADR should either narrow the v1 guarantees or require parser fixtures that demonstrate expected behavior for these cases.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted.** v1 makes no correctness guarantee on these; each is enumerated above with its expected behavior, and Acceptance now requires a golden fixture per case plus measured precision/recall before the ADR is marked Accepted.

- AILANG has no classes. No direct `inherits`/`implements` analog; the closest concepts are type classes and instances. v1 will not synthesize those edges (columns reserved, empty).
- **Effects come from the `effects` array, full stop.** No textual `type` parsing is used for effects. The `type` string is parsed only for the *type-use* graph (which type names a signature references); the effect set is read structurally from `effects`.
> **Review comment (GLM 5.2):** Contradiction with line 35: the `effects` array is treated as authoritative, yet this line depends on textual `(())->()!{IO}` parsing... Pick one and reconcile both lines.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted, reconciled.** The contradiction is removed: effects are the structured array; text parsing is confined to extracting type references for the `uses` graph and never touches effects. (If a future need arises to read handled/quantified effects the array omits, that would be a new, separately-specified parser — not in v1.)
- AILANG module identity is file/path-based (`src/core/types`), not `namespace.Type`. Slugs are module-or-symbol paths, not type FQNs.
- **chDB is the query engine** — embedded ClickHouse (in-process, `pip install chdb`), giving the ClickHouse SQL dialect with no server/CLI binary. It reads CSVs directly via `file('…','CSVWithNames')` and emits JSON/Pretty/CSV. It must be added to `install-prerequisites.sh` (it is not yet a prerequisite).
> **Review comment (GLM 5.2):** ClickHouse is unjustified for this workload... making the *agent surface* SQL-over-ClickHouse means every agent environment must install the binary... The `load.py`/`schema.sql` reuse defense is circular... SQLite or DuckDB would be zero-install, embedded, adequate, and keep the surface portable. Justify ClickHouse on real grounds or switch.
> **Review comment (GPT-5.5):** [Rejected-alternatives] does not justify ClickHouse over simpler embedded engines such as SQLite/DuckDB... evaluate a lighter embedded option.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted in substance; resolved with chDB, not DuckDB.** The reviewers' objection is precisely to the **`clickhouse` server/CLI binary** being non-portable to agent environments. **chDB removes that objection**: it is embedded ClickHouse, in-process, with no external binary — and it is what the `code-graph` README named all along ("loads it into chDB"); the reference scripts only diverged to `clickhouse local`. Verified here: `pip install chdb` (aarch64/py3.12 wheel), and `file('…','CSVWithNames')` queries run in-process and answer the DST R8 query correctly. This keeps the **ClickHouse SQL dialect the operator maintains in** (a real maintainability factor) and maximizes reuse of existing ClickHouse query idioms — while satisfying portability. **Accepted tradeoff:** chDB is ~712 MB installed (it bundles ClickHouse) vs DuckDB's ~50 MB CLI which is already present. DuckDB was the lighter option, but the dialect/familiarity win is decisive for the person who owns this tool. The reuse-of-`schema.sql`/`load.py` defense is still dropped as weak: chDB needs no load step (queries CSV directly), so the only genuinely reused `code-graph` piece remains the SVG-render path.

## Edge & Node Model

Nodes:

- **module** — one per `.ail` file. Slug = repo-relative module path (`src/core/agent_loop_v2`). Carries `extraction_status`.
- **type** — exported ADTs/records via `iface`, with constructors. Slug = `{module}#{TypeName}` (see Slug Scheme).
- **func** — all top-level functions (exported and internal), discovered by source parsing. Slug = `{module}#{func_name}`. Exported funcs additionally carry the `iface` signature and declared effects; internal funcs carry call edges and propagated effects only.

Edges:

| Edge | Source | Status in v1 |
|------|--------|--------------|
| `imports` | `import` lines (std-filtered, alias-aware) | ✅ module → module |
| `invokes` | source-parsed `name(` call sites, resolved to local/imported names | ✅ func → func (approximate; whole-program, hydration-free) |
| `uses` | types referenced in exported `func.type` signatures | ✅ func/module → type (exported signatures) |
| `effects` | **declared**: exported `func.effects` array (authoritative, transitive) | ✅ table: `func_slug, effect` |
| `effect_edges` | **reachable**: effects seeded at stdlib-primitive call sites, propagated backward over `invokes` | ✅ table: `func_slug, effect, source_func_slug, distance, derivation` |
| `inherits` / `implements` | type classes / instances | ⛔ deferred (empty columns) |
| `channels` | effects + extension-hook wiring | ⛔ deferred |

> **Review comment (GPT-5.5):** The `effect_edges` table is not concrete enough to implement safely. For audits, provenance matters: a useful schema likely needs `func_slug`, `effect`, `source_func_slug`, `distance`, and a confidence/source field. Otherwise consumers cannot distinguish a declared effect from a transitive, heuristic reachability result.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted.** `effect_edges` schema is now `func_slug, effect, source_func_slug, distance, derivation`, where `distance` = call-graph hops from the primitive source (0 = direct primitive call) and `derivation ∈ {primitive_seed, backward_reachable}`. Consumers distinguish a `declared` effect (from the `effects` table / `iface`) from a `reachable` one (here), and can audit the path. For exported functions, `effect_edges` is cross-checked against the authoritative `effects` row (the oracle).

The effect graph is the headline Motoko-specific capability: "which functions can reach `Net`/`FS`/`Env`" — computed by seeding effects at stdlib-primitive call sites and propagating **backward** over the approximate source-parsed call graph, then validating against `iface`'s authoritative declared-effect rows. A capability/security view the C# graph cannot express. Its precision is bounded by the call-graph heuristics and reported with every answer (coverage + staleness).

## Architecture / Components

```
src/{core,scripts,examples}/**.ail
  typed layer  → ailang iface (per module; failure-classified) → types, exported sigs, effect rows ─┐
  struct layer → source parse: imports, func defs, name( call sites, type-decl ctors → import + call graph ─┤
  effect graph → seed at stdlib-primitive calls, propagate BACKWARD over invokes, validate vs iface rows ─┴─→ extractor → tools/code-graph/.out/*.csv
  → chDB query (file(...) over CSVs, in-process ClickHouse SQL)   → result rows
  → visualize.py (SVG path reused; graph-building new) → .mmd → .svg
  → CLI surface (Phase 3)  → Claude Code & Codex (SQL queries via Bash, documented in AGENTS.md)
```

| Component | Role | New / Reuse |
|-----------|------|-------------|
| `ailang-graph` extractor | Drives `ailang iface` (typed layer) + raw-source parser (imports, call graph, ctors) + backward effect propagation, classifies `iface` results, emits CSVs | **New** (replaces `Program.cs`; call-graph parser PoC-validated) |
| chDB query | `file('…','CSVWithNames')` over `tools/code-graph/.out/*.csv`, in-process | Embedded ClickHouse; no `schema.sql`/`load.py` load step needed |
| `visualize.py` | Mermaid + SVG views | Partial reuse: SVG-render path reusable, but its graph-building is namespace-coarsening logic that does not map to AILANG's path-based modules — module-dep + effect views are largely new |
| CLI query surface | chDB `file(...)` + ClickHouse SQL, JSON out, staleness/coverage banners; callable via the agents' Bash tool | **New** (mechanism mirrors the reference script, same dialect via chDB) |
| `.agent/tools/*.ts` | Reference implementations (`clickhouse local`/Zeus) | Reference-only; possible base for a Motoko extension |
| `chdb` | Embedded ClickHouse query engine | **New prerequisite** (`pip install chdb`, ~712 MB) |

Extractor implementation language: Python (the PoC is ~70 lines of Python; shells `ailang iface` and parses source, no compiled host needed).

## How This Serves ADR-001 (DST)

With the call graph now in v1, most DST questions are served (the call graph approximately):

- **Registry-import precondition (DST R3/R13):** "all transitive importers of `registry_generated` / `init_runtime_with_config`" is one query over `imports`. Hydration-free — fully delivered in v1.
- **Recorder seam (DST R8):** "who calls `dispatch_step`" is one query over `invokes`. The PoC already returns `agent_loop_v2.loop_v2 → stub_step.dispatch_step`. Delivered in v1, approximately.
- **Emergency-compaction (DST R15):** `compact_step` / `compact_step_actual → try_emergency_compaction` are likewise in the PoC output. Delivered in v1, approximately.
- **Effect satisfaction (DST R7):** effects seeded at stdlib-primitive call sites and propagated **backward** over `invokes` (callee → caller), cross-checked against `iface`'s authoritative declared rows (e.g. `init_runtime_with_config : ! {Env, FS, Net}`). Delivered in v1; precision follows the call-graph heuristics and is reported with coverage.
- **Constant duplication (DST R5):** a literal scan over source can flag duplicated `75000` / tier constants across all functions, not just exported signatures.

The honest summary: v1 serves R3/R13 exactly and R7/R8/R15 approximately (bounded by call-graph heuristics). The upstream `--json` upgrade later makes R7/R8/R15 exact.

## Implementation Plan

### Phase 0: Setup + Contract Validation

- Hydrate the full registry dependency set for the **typed layer** (shared precondition with ADR-001); confirm `iface` succeeds on a heavy module (`agent_loop_v2`) after hydration. The structural layer needs no hydration. **(Done during v0.26.0 adoption.)**
- Add `chdb` to `install-prerequisites.sh` (`pip install chdb`); verify the `file('…','CSVWithNames')` path works in-process (done in spike — answers the DST R8 query).
- **Effect-model experiment (done):** confirmed `iface` effect rows are **transitive** and `pure` is invariant; this fixed the propagation direction (backward) and the source set (stdlib primitives, not exported funcs). See the GPT-67/GLM-68 resolution.
- Snapshot `iface` JSON for a representative module set; pin the `ailang.iface/v1` shape.
- Build the seed catalog: stdlib primitive → effect, from `ailang builtins list --by-effect` + `iface` on stdlib modules.
- Ship the `ok/failed/partial` classifier with its golden fixtures (see Constraints).
- Build the precision/recall harness against a hand-validated 3-module sample (see Acceptance).
- File the upstream `ailang debug ast --json` request and the `pure`-semantics question via `ailang-feedback` (future precision upgrade, not a blocker).

### Phase 1: Structural + Call Graph (no AILANG features, no hydration)

- Harden the PoC source parser: imports (std-filtered, alias-aware), `func` discovery (all functions), `name(` call resolution against local + imported names, and **source-derived** constructor filtering (parse `type T = Ok(_) | Err(_)` decls; exclude those names from `invokes`).

> **Review comment (GPT-5.5):** This contradicts the phase title. Constructor filtering via `iface` ctors uses the typed layer and can be hydration-dependent. Move constructor filtering to Phase 2, make it best-effort only when `iface` succeeds, or derive constructors from source in Phase 1.
> **Review comment (GLM 5.2):** The deeper fix is not "move to Phase 2" — the hydration-free path can *never* use `iface` ctors... Commit to source-derived constructor filtering for the structural layer; treat `iface` ctors as a precision upgrade only. Resolve Open Question rather than deferring it.
>
> **Author response (Opus 4.8, 2026-06-28) — GLM's deeper fix accepted.** Constructor filtering is **source-derived** in Phase 1 (parse `type` decls for ctor names), so the hydration-free path stays self-contained — GPT's contradiction is removed without deferring. `iface` ctors become a cross-check/precision upgrade in Phase 2, not a dependency. The corresponding Open Question is resolved and removed.

- Emit `funcs.csv`, `imports.csv`, `invokes.csv`.
- Query via chDB; add module-dependency and call-graph Mermaid/SVG views.
- This phase runs on the whole tree regardless of hydration.

### Phase 2: Typed Layer + Effect Graph

- Add the `iface` pass with failure classification; emit `code_types.csv`, `uses.csv`, `effects.csv`, `extraction_status.csv`.
- Seed effects at stdlib-primitive call sites and propagate **backward** over `invokes` to produce `effect_edges` (`func_slug, effect, source_func_slug, distance, derivation`); validate exported funcs against `iface` rows. Add the effect-graph view.
- Effect annotations degrade gracefully where `iface` failed; structure remains intact.

### Phase 3: Agent Surface (CLI-first)

- Build a **CLI** for Claude Code and Codex: chDB `file(...)` over the AILANG CSVs (ClickHouse SQL), SQL in, JSON out, row truncation, plus staleness + coverage banners. Callable via the agents' Bash tool with zero registration. MCP can wrap the CLI later.
- Document the surface and example queries in `AGENTS.md` so both agents discover it.
- Add **unimported-module detection** (transitive `imports` closure from a declared root set), fan-in/fan-out, the DST R3/R13 importer-reachability query, and the R8/R15 call-seam queries.

> **Review comment (GPT-5.5):** Dead-module detection is not defined. Deadness requires an explicit root set and exclusions for binaries, scripts, examples, tests, generated modules, extension entry points, and dynamically loaded modules...
> **Review comment (GLM 5.2):** Stronger than "undefined": dead-module detection over an approximate call graph is actively harmful in v1... an agent refactoring on this verdict receives false-negative deadness and may delete live code. Remove from Phase 3; restrict to "unimported modules" (transitive `imports` closure from a declared root set), which is at least sound, or defer entirely.
>
> **Author response (Opus 4.8, 2026-06-28) — GLM accepted.** "Dead-module detection" is replaced by **unimported-module detection**: the transitive `imports` closure from a declared root set (binaries/scripts/examples/tests/extension entry points as roots), which is sound regardless of call-graph precision. The output is explicitly labeled "unimported" (not "dead"/"safe to delete"), since higher-order/dynamic/type-class usage can keep an unimported module live. True deadness waits for the precise call graph (Phase 4).

### Phase 4 (later): Precision + Type-Class Model

- When `ailang debug ast --json` lands, replace the heuristic call graph with a type-resolved one; effect reachability and R7/R8/R15 become exact.
- Optionally design `inherits`/`implements` analogs from type classes and instances; populate the reserved columns.

## CI Shape

Extraction is a batch tool, not a fast-PR gate.

```bash
# precondition (shared with ADR-001)
ailang lock   # + explicit install of any unhydrated registry packages

# refresh graph (manual or nightly)
tools/code-graph/extract.sh            # -> tools/code-graph/.out/*.csv + *.svg (records built_at + ailang_version)
#   - fails loudly if any module's extraction_status is unexpectedly 'failed'

# advisory checks once stable
#   - no new unimported modules (sound; from imports closure)
#   - effect-graph diff: surface when a function newly reaches Net/FS/Env
```

Effect-graph diffs are a candidate future gate: a function that newly *reaches* `{Net}`/`{FS}` is a meaningful self-evolution signal. It is advisory while reachability follows the approximate call graph, and a candidate blocking gate once the `--json` precision upgrade (Phase 4) makes it exact.

## Acceptance Criteria

The first implementation is acceptable when:

- The structural extractor runs over `src/` with no hydration and produces `imports.csv` + `invokes.csv` for **all** modules, including those `iface` cannot load (e.g. `agent_loop_v2.ail`).
- The typed pass classifies each module's `iface` result ok/failed/partial and never silently drops a module's typed layer.
- The agent surface (CLI) answers, against Motoko's own source: a module-dependency query, "transitive importers of `registry_generated`" (DST R3/R13), "who calls `dispatch_step`" (DST R8), and "what reaches `{Net}`/`{FS}`/`{Env}`" (DST R7).
- **Golden parser fixtures pass** for: imports, aliases, selective imports, comments, strings, interpolation, source-derived constructors, local shadowing, qualified calls, same-name symbols across modules, and each `ok/failed/partial` `iface` case.
- **Measured call-graph precision/recall** against a hand-validated 3-module sample (including `agent_loop_v2`), with the numbers recorded in this ADR before it is marked Accepted. R8/R15 are only claimed to the measured recall.
- **The effect oracle holds**: for `ok` modules, each exported function's backward-computed reachable effects equal its `iface` `effects` row (divergences enumerated and explained, not waved away).

> **Review comment (GPT-5.5):** Spot-checking one sample module is too weak... require golden parser fixtures for [cases].
> **Review comment (GLM 5.2):** Speed and coverage are measured; precision and recall are not... Require precision/recall against a hand-validated 3-module sample, reported in the ADR before it is marked Accepted.
>
> **Author response (Opus 4.8, 2026-06-28) — both accepted.** The single spot-check is replaced by (a) per-case golden fixtures, (b) measured precision/recall on a 3-module hand-validated sample recorded in the ADR pre-Accept, and (c) the `iface` effect-oracle equality check, which gives an *independent* correctness signal the PoC could not. The ADR will not move to Accepted on speed/coverage alone.

- A module-dependency SVG and a call/effect SVG render.
- No step requires a network or a live model (typed-layer hydration aside).

## Consequences

Positive:

- Motoko gains a queryable map of its structure, call graph, and effect/capability surface — covering internal functions, not just the public interface.
- The structural/call layer needs no hydration and no upstream changes; the PoC runs the whole tree in 0.1s.
- chDB is embedded (no server/binary), so the agent surface stays portable to the agents it serves while keeping the operator's ClickHouse dialect; net new code is the extractor, the visualization's graph-building, and the CLI.
- DST R3/R13 are one-query answers, and R7/R8/R15 are served approximately in v1, each with a measured recall.
- The effect graph is a novel self-verification signal unavailable in the C# graph — and the `iface` effect-oracle gives it an independent correctness check.

Negative:

- The call graph is **heuristic** (constructor noise, dropped interpolation calls, higher-order/type-class imprecision). It is approximate until the upstream `--json` precision upgrade; consumers must treat it as such.
- The *typed* layer (signatures, declared effects) is still exports-only and hydration-dependent; CI must hydrate for it (shared cost with ADR-001). Coverage is uneven: a module can have call edges but no typed annotations.

> **Review comment (GPT-5.5):** This consequence should be reflected in the agent UX, not only documented here. Any effect query should report the number/list of modules with missing typed extraction and mark results as incomplete when missing modules could affect the answer.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted, made a surface contract.** Per the Constraints resolution, every effect answer carries `coverage`, the involved modules' statuses, and an `INCOMPLETE` flag when any module on the relevant reverse-reachable frontier is `failed`/`partial`. This is an Acceptance item (the surface must emit it), not just documentation.

- `inherits`/`implements` have no clean v1 analog; columns sit empty.
- The extractor is coupled to the `ailang.iface/v1` schema, to the `effects` array shape, and to AILANG source-syntax conventions (col-0 decls, `--` comments); minor AILANG bumps require re-validation.
- `chdb` (~712 MB) must be installed wherever the graph is queried — a new, heavyweight prerequisite. It is embedded (no server) and keeps the ClickHouse dialect, but it is far larger than DuckDB (~50 MB, already present), which was the lighter rejected option.
- Three graphs now coexist (this + `code-graph` + `omnigraph`); boundaries must stay documented.

## Rejected Alternatives

### Port `code-graph`'s Roslyn approach wholesale

Rejected. Roslyn's cost exists because C# lacks an introspection CLI. AILANG ships `iface`; reimplementing a semantic layer would be wasted effort.

### Ship the agent surface as a harness-specific plugin

Rejected. Binding the query surface to one harness's plugin format would exclude the agents that actually drive this repo. Claude Code and Codex both consume neutral channels (shell commands, `AGENTS.md`), so the surface is a **CLI** (MCP may wrap it later). The `.agent/tools/*.ts` scripts remain reference-only — useful as a base for a future Motoko extension, not as the consumption path.

### Parse the `ailang debug ast` ANF dump for the call graph

Rejected for v1. On both v0.24.2 and v0.26.0 the dump prints only top-level `*core.LetRec [#id]` nodes — too shallow to recover call edges. Raw-source parsing yields a usable call graph today; the upstream `--json` upgrade is the path to a precise one later.

### Defer the call graph until upstream `--json` (original plan)

Rejected. The PoC showed source parsing delivers an approximate call graph with zero hydration and no upstream dependency, including the internal seams DST needs (`dispatch_step`, `try_emergency_compaction`). Blocking v1 on upstream would needlessly delay R8/R15 coverage. The heuristic call graph ships now; `--json` upgrades it in place.

### Extend `omnigraph` to hold code structure

Rejected for v1. Different schema, different population mechanism, and it conflates intent with implementation. A future `Component → module` link is the right integration point.

### Pure grep-based extraction (no SQL engine)

Rejected. Imports are grep-able, but `uses`/effects/reachability need joins. A SQL engine gives the agent ad-hoc joins for free.

### `clickhouse` server/CLI binary as the engine (code-graph's approach)

Rejected. Requiring the standalone `clickhouse` binary in every agent environment makes the agent surface non-portable (the reviewers' core objection), and it is not installed here. Resolved by **chDB** — embedded ClickHouse, same dialect, no binary.

### DuckDB as the engine

Considered and rejected in favor of chDB. DuckDB is lighter (~50 MB, already installed) and reads CSV directly, but uses the DuckDB SQL dialect, not ClickHouse. Since the operator works primarily in ClickHouse SQL and the existing `code-graph` query idioms are ClickHouse, chDB's dialect match (and embeddedness) outweighs DuckDB's smaller footprint. If footprint or zero-install ever dominates, DuckDB remains the fallback — the schema and CSVs are engine-neutral.

> **Review comment (GPT-5.5):** This rejects grep-only extraction but does not justify ClickHouse over simpler embedded query engines such as SQLite or DuckDB... evaluate a lighter embedded option.
>
> **Author response (Opus 4.8, 2026-06-28) — accepted; embedded engine chosen (chDB).** SQLite and DuckDB were both evaluated as embedded options. chDB is also embedded but keeps the ClickHouse dialect the operator maintains in; the ~712 MB footprint is the accepted cost. The CSVs/schema stay engine-neutral so a switch to DuckDB later is cheap.

## Resolved During Review (2026-06-28)

These were Open Questions; the review settled them:

- **Agent surface → CLI-first** (GPT/GLM). Stateless, zero registration, portable; MCP can wrap it later. The ADR no longer leaves the consumption path open.
- **Query engine → chDB** (embedded ClickHouse). Satisfies the reviewers' portability objection (no server/CLI binary) while keeping the operator's ClickHouse dialect; DuckDB was the lighter runner-up.
- **Constructor handling → source-derived filtering** (GLM). Parse `type` decls; drop ctor names from `invokes`. (`constructs` as a separate edge type is a possible later refinement, not v1.)
- **Implementation language → Python** (PoC already is).
- **Effect propagation → backward, primitive-seeded, `iface`-validated** (GPT/GLM, via Phase-0 experiment).
- **Slug scheme → `{module}#{name}`, case-preserving, kind-separated tables** (see the Slug Scheme section). Module slug = file path; ctor names payload-stripped; uniqueness + duplicate-import asserted at emit.
- **Unimported-module roots → derived programmatically** from the dynamic-load sources (TS-host path scan, `registry_generated.ail` + `[extensions]`, `scripts/`/`examples/`/test globs); output labeled "unimported," never "dead" (see the Root Set section).
- **Location → `tools/code-graph/`.** Tooling (extractor, CLI, viz) lives at `tools/code-graph/` — the canonical home the user is establishing (alongside `tools/mmd2svg/`), which also matches the path the reference `.ts` scripts already expect (`tools/code-graph/bin`, `extract-only.sh`). Generated artifacts go to `tools/code-graph/.out/` (gitignored), not a root-level `.ailang-graph/`/`.code-graph/`. Consequence to confirm: the existing C# `code-graph/` at repo root should move under `tools/code-graph/` too for consistency (separate action, not done here).

## Slug Scheme (Decided)

Every node (module, type, func, constructor) needs a slug that is **unique** and **join-safe** — `invokes.to_slug` must resolve to exactly one func, `uses.to_slug` to exactly one type, etc. The naïve `{module}.{name}` the PoC uses has four collision/ambiguity modes, three of them grounded in this repo:

1. **Separator overload (`.`).** `.` is already AILANG's qualified-access and field-access operator in source (`List.length`, `Trace.event`, `m.content`), so reusing it as the module→symbol boundary is confusing and marginally unsafe. Module *paths* here are all `/`-separated and dot-free (verified), so the immediate risk is low — but the operator clash alone argues against `.`.
2. **Case folding.** `code-graph` lowercased every slug (`zeus.core.itradingengine`). AILANG types are PascalCase and funcs snake/camelCase, so lowercasing would fold a type `Message` and a hypothetical func `message` together.
3. **Cross-kind name reuse.** A type, a function, and a data constructor in the same module can share a base name space (e.g. constructor `Done` vs. a func `done`). A single global slug table would collide across kinds.
4. **Resolution-side ambiguity.** A duplicate unqualified import (`import a (f)` and `import b (f)`) or a `module` declaration that disagrees with the file path can silently mis-resolve an edge.

**Decision:**

- **Separator `#`** between module path and symbol — a character that cannot appear in AILANG paths (`[A-Za-z0-9_/]`) or identifiers: `src/core/compaction#compact_step`, `src/core/types#StepOutcome`, `std/trace#event`.
- **Case-preserving** slugs, always (never lowercase).
- **Kind-separated tables** (`modules`, `funcs`, `types`, `ctors`), each with its own slug space; edges join to the correct table *by edge type*, so cross-kind reuse (mode 3) cannot collide. A unified `nodes` view carries a `kind` column for convenience.
- **Module slug = repo-relative file path** (authoritative, one per file), with the `module` declaration validated to match it (catches mode 4's path mismatch).
- **Constructor names stripped of payload**: `iface` reports `Continue(AgentState)` / `BashExec({...})`; the slug is the bare ctor (`...#Continue`). (Source-derived ctors parse the same way.)
- **Extractor asserts uniqueness** of `(table, slug)` at emit time and **flags duplicate unqualified imports** within a module — turning a silent mis-join into a loud build error.

(Whether constructors also get a first-class `constructs` *edge* — vs. just being filtered out of `invokes` — remains the v1 "dropped" decision in Resolved During Review; this scheme reserves the `ctors` table either way.)

## Root Set for Unimported-Module Detection (Decided)

A module is "unimported" if it is not in the transitive `imports` closure from a declared **root set**. The detection is only as sound as that root set — and in Motoko the root set is unusually hard, because **the load graph is mostly dynamic, not static `import`**. Two mechanisms (both verified) bypass AILANG imports entirely:

- **The TypeScript host loads core modules by string path.** `src/tui/src/runtime-process.ts` loads `src/core/supervisor.ail` and `src/core/config.ail`; `index.ts` loads `src/core/rpc.ail` and `src/core/version.ail`; the comment block in `run-agent.sh` confirms `supervisor.ail`, `agent_loop_v2.ail`, and `ext/*.ail` are "loaded dynamically by the TS host." None of these are reachable by a static `import` from a single `main`.
- **Extensions load by name via the registry.** `src/core/ext/registry_generated.ail` (generated) wires the 9 extensions in the active profile's `[extensions].order`; they are dispatched through `register_with_config`, not statically imported from the runtime.

So a naïve "imports-closure from `main`" would mark almost the entire codebase unimported. The root set is therefore **assembled programmatically from the same sources that do the dynamic loading**, not hand-maintained. Roots are:

1. **Runtime entry modules the TS host loads by path** — `supervisor`, `config`, `rpc`, `version`, `agent_loop_v2`, `ext/runtime`, … — derived by scanning the host's `src/core/*.ail` string literals (or a single canonical loader manifest if one is introduced; see Open Questions).
2. **Extension entry modules** — from `registry_generated.ail` plus `ailang.toml [extensions]` / the profile `config.json` `order`.
3. **`func main` modules** under `scripts/` and `examples/` — each is its own CLI entry point run via `ailang run --entry main`.
4. **Test modules** — `*_test.ail`, `src/core/test/*`, and any module containing test functions (run by `ailang test <module>`).
5. **Generated modules** — `registry_generated.ail` itself.

**Decision:** derive the root set programmatically from these authoritative sources (host string-literal scan, `ailang.toml`/`config.json`, `registry_generated.ail`, and `scripts/`+`examples/`+test globs), record it with provenance in the output, and **label results "unimported (not reachable via static imports from declared roots)" — never "dead" or "safe to delete."** Two unsoundness sources remain even with a complete root set: a module loaded dynamically by a path/name the root scan missed (false positive), and liveness via higher-order or type-class dispatch (invisible to `imports`). True deadness waits for the precise call graph (Phase 4).

## Open Questions

- Whether the TS host should expose a single machine-readable load manifest, so runtime-entry roots aren't scraped from scattered `.ts` string literals (brittle). Small change in the host; would make root category 1 authoritative rather than heuristic.
- Policy for a module that has test functions but no importer and no `main` — auto-treat as a test root, or flag for review?

### Call-graph precision: how far to chase the heuristic before `--json`

Every precision fix to the source parser is **throwaway** once upstream `ailang debug ast --json` lands and replaces the heuristic call graph with a type-resolved one. So the question is ROI under uncertainty about that timeline. Three principles guide it:

- **False positives hurt more than false negatives.** A *wrong* edge misleads an agent making a decision; a *missing* edge is honestly labeled "approximate." Prioritize eliminating wrong edges even when rare; tolerate misses.
- **If a fix needs type information, it *is* `--json`'s job** — don't reimplement type inference heuristically.
- **Decide by measurement, not guesswork.** The Acceptance precision/recall on the 3-module sample plus the `iface` effect-oracle divergence are the stopping signal: fix only what moves those numbers; stop when the oracle matches on the sample and recall clears the agreed bar.

Grounded cut line for this repo (frequencies measured):

| Case | Kind | Measured here | Verdict |
|------|------|---------------|---------|
| Alias-only-qualified import resolution (don't map aliased imports to bare names) | wrong edge | — | **Do** (cheap; prevents false positives) |
| Source-derived constructor filtering | wrong edge | — | **Do** (already decided) |
| String-interpolation call scanning (`${ … f(x) … }`) | missing edge | 69 sites, **27 non-`show`** real edges (`substring`, `process_error_to_string`, `join_lines`, …) | **Do** (cheap, localized; recovers real edges) |
| `let`/lambda shadowing of imported names | wrong edge | **0 occurrences** | **Skip** (add only a guard; revisit if it ever appears) |
| Higher-order calls (function-valued params) | missing edge | pervasive by nature | **Wait for `--json`** (needs dataflow/types) |
| Type-class method dispatch → concrete instance | missing/wrong | — | **Wait for `--json`** (needs type resolution) |
| Re-export origin resolution | wrong edge | — | **Typed layer only** (use `iface` export lists; no deeper heuristic) |

So: do the three cheap, high-value fixes (alias semantics, ctor filtering, interpolation scanning); skip shadowing (zero occurrences); explicitly **defer the type-dependent cases to `--json`** rather than approximating them. Re-measure after these and stop unless the sample shows a real gap.
