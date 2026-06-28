# Implementation Plan: `ailang-graph` (AILANG Code & Effect Graph)

Date: 2026-06-28
Status: Plan (derived from ADR-002, accepted-pending-validation)
Source of truth: `.agent/projects/002_code_graph/ADR-002-ailang-code-graph-architecture.md`
Pinned: AILANG **v0.26.0** (commit `3b52a24`), iface schema `ailang.iface/v1`
Validated against: the local `/home/motoko/.local/bin/ailang` binary on 2026-06-28

This plan turns ADR-002 into ordered, phased, gated work. It is a **plan, not an
implementation** — it specifies file layout, exact CSV schemas, the classifier and
its fixtures, the seed-catalog build + backward-propagation algorithm + oracle, the
CLI contract, the test/precision plan, prerequisite/CI changes, and the `AGENTS.md`
task. The extractor itself is not written here.

## TL;DR

Build `ailang-graph` under **`tools/code-graph/`** (Python extractor + chDB query CLI
+ SVG viz) in four phases, sequenced so the hydration-free graph ships first.

- **Phase 0 — contracts before code:** add `chdb` to the prereq script; build the
  stdlib-effect **seed catalog**; ship the `ok/failed/partial` `iface` classifier with
  golden fixtures; stand up the precision/recall harness on a 3-module sample (incl.
  `agent_loop_v2`); file upstream asks.
- **Phase 1 — structural + call graph (no hydration, whole-program):** harden the PoC
  source parser (`#`-slugs, alias resolution, source-derived ctor filtering,
  interpolation scanning), emit `modules/funcs/imports/invokes/ctors` CSVs, gate on
  golden parser fixtures. Works on modules `iface` can't load.
- **Phase 2 — typed layer + effect graph:** `iface` pass (types, sigs, declared
  effects), then seed effects at stdlib call sites and propagate **backward**
  (callee→caller) into `effect_edges`, validated against `iface`'s transitive effect
  rows — the **oracle**.
- **Phase 3 — agent surface:** a CLI (`cgq.py`) over the CSVs with staleness +
  coverage/`INCOMPLETE` banners, canned DST queries (R3/R7/R8/R13/R15) + sound
  "unimported" (never "dead") detection, documented in `AGENTS.md`.
- **Phase 4 (later):** swap the heuristic call graph for a type-resolved one when
  upstream `ailang debug ast --json` lands.

**Engine:** embedded **chDB** (ClickHouse SQL over CSVs, in-process). **All
call-graph/effect output is labeled approximate** with coverage + staleness.
**Accept gate:** golden fixtures pass + measured precision/recall recorded + the
effect oracle holds.

**Decided (FLAG 1, below):** the ADR's seed-catalog source — `iface` on stdlib
modules — **does not work on the v0.26.0 binary**, so v1 uses **module-granular
seeding** from `builtins list --by-effect` (sound superset; over-seeding measured by
the oracle). The clean per-symbol fix is filed upstream as an `ailang-feedback`
feature request and **pre-wired to a one-line switch** (`SEED_GRANULARITY`) so
adoption needs no schema/consumer/CSV changes when AILANG ships it.

---

## ⚠️ Flags for the user — two ADR points that did not survive binary validation

Per the handoff's grounding rule ("if you find an ADR decision that is wrong or
contradictory, flag it for the user — do not silently diverge"), two items in
ADR-002 diverged from the binary's actual behavior. Both are now **resolved**
(decided 2026-06-28): v1 uses module-granular effect seeding from
`builtins list --by-effect`, and the clean per-symbol fix is filed upstream and
pre-wired to a one-line switch. The flags are retained below as the rationale + the
upstream-adoption path, not as open decisions.

### FLAG 1 (substantive) — the seed-catalog source in ADR Phase 0 does not work as written

ADR-002 Phase 0 and the GLM-68 resolution say the stdlib-primitive→effect seed
catalog comes from *"`ailang builtins list --by-effect` **plus `iface` on stdlib
modules** (each stdlib fn carries its own transitive effect row)."*

The `builtins list --by-effect` half **works perfectly** (validated — see Phase 0).
The **`iface` on stdlib modules half does not work** on v0.26.0. Verified, every form
fails:

| Invocation | Result |
|---|---|
| `ailang iface std/net` | `Error: cannot read file 'std/net.ail'` |
| `ailang iface ~/.local/share/ailang/std/net.ail` | `Error MOD010: module 'std/net' doesn't match file path 'home/.../std/net'` |
| `AILANG_RELAX_MODULES=1 ailang iface <abs path>` | same MOD010 (env var not honored by `iface`) |
| `ailang iface --relax-modules <path>` | `flag provided but not defined: -relax-modules` |
| `cd ~/.local/share/ailang && ailang iface std/net` | `module name contains invalid characters … net.ail` |

So app code never calls the `_net_*` primitives directly either — it imports the
**public wrappers** (`import std/net (httpGet)`, `import std/fs (readFile)`,
`import std/env (getEnv)`), and we cannot read those wrappers' effect rows via
`iface`.

**DECISION (ratified 2026-06-28): module-granular seeding.** Derive the seed catalog
at **module granularity** from `builtins list --by-effect` alone, which maps every
primitive to its `(module, effect)`. Group by module → each `std/X` gets an effect
set (`std/net→{Net}`, `std/fs→{FS}`, `std/env→{Env}`, `std/process→{Process}`,
`std/clock→{Clock}`, `std/io→{IO}`, pure modules→∅). Then **seed by import
provenance**: any app call to a symbol imported via `import std/X (…)` seeds
`effects(std/X)` onto the calling function. This is a **sound superset** (never
misses a real effect on an effectful module) and is fully hydration-free.

This differs from the ADR's *per-public-function* granularity. The cost is
**over-seeding** when an effectful module also exports pure helpers (e.g. a pure
URL-encode in `std/net` would seed `Net`). That over-seeding is exactly what the
**iface oracle measures** (computed ⊋ declared = divergence), so it is bounded and
reported, not hidden. A *per-symbol* precision upgrade (parse stdlib source
signatures for `! {E}`) is available but **incomplete** on its own — validated:
`std/process` annotates `0/4` public funcs inline and `std/net`'s multi-line sigs
are missed by a line parser — so it is layered **on top of** the module-granular
seed if/when AILANG exposes the data cleanly, never a replacement.

#### Upstream feature request — file it, and pre-wire the adoption

The clean per-symbol fix belongs in AILANG, not in a brittle stdlib-source scraper.
**File this via the `ailang-feedback` skill** (Phase-0 task 6 carries the ready-to-
submit text); it is the proper home for the data and removes FLAG 2's brittleness too.

> **Ask (one line):** a machine-readable way to read **public stdlib function → effect
> row** mappings — e.g. `ailang iface --stdlib std/net` (accept a stdlib module name
> and emit the standard `ailang.iface/v1` JSON with each public fn's `effects`
> array), **or** extend `ailang builtins list --by-effect --public` to include the
> exported wrapper functions (not only the `_`-prefixed primitives). Today `iface`
> on a stdlib path fails (MOD010 / invalid-characters / file-not-found, every form),
> so app-callable stdlib effect rows are not machine-readable.

**Adoption is pre-wired to a one-line switch — when the feature lands, no schema, no
consumer, and no CSV changes:**

- The catalog exposes a single resolver the seeding pass calls and **never** changes:
  `effects_for(catalog, std_module, symbol) -> set[effect]`. Today it ignores
  `symbol` and returns the module set; per-symbol mode returns the symbol set when
  present, else falls back to the module set.
- A single flag in `extractor/config.py` — `SEED_GRANULARITY = "module"` — flips to
  `"symbol"`. The **only** new code needed at that point is one builder function,
  `parse_stdlib_public_iface()`, that fills the `(std_module, symbol) → effects` map
  from the new AILANG command. The consumer (`effects.py`), `std_calls.csv` (which
  **already records `symbol`**), `effect_edges.csv`, the oracle, and the CLI are all
  untouched.
- `seed_catalog.json` records `"granularity"` and `"source"`, so the oracle/CLI label
  which mode produced the effects, and the **over-seed metric in `oracle_report.json`
  auto-quantifies the precision gain** the moment the switch is flipped — the upgrade
  proves itself with no extra test scaffolding.

### FLAG 2 (minor) — stdlib source location is real but brittle

Stdlib `.ail` source **is** on disk at `~/.local/share/ailang/std/*.ail` (validated;
`export func httpGet(url: string) -> string ! {Net}` is greppable there). But that
path is install-specific, undocumented as stable, not env-overridable via any flag
surfaced in `ailang --help`, blocked from `iface` by MOD010, **and incomplete as a
source** (validated: `std/process` annotates `0/4` public funcs inline; multi-line
sigs are missed). **Decision:** v1 does **not** scrape stdlib source at all — it relies
solely on `builtins list --by-effect` (a stable CLI contract). The per-symbol
precision path is the **upstream feature request** (FLAG 1 / Phase-0 task 6(c)), not
source scraping. This flag collapses into FLAG 1's FR and needs no separate handling.

---

## 0. Decisions inherited from ADR-002 (do not relitigate — cited, not re-argued)

These are fixed inputs to this plan (ADR §"Resolved During Review", §"Slug Scheme",
§"Root Set", §"Constraints", §"Edge & Node Model"):

- **Two sources.** `iface` = typed layer (exported types/sigs/effect rows;
  hydration-dependent; exit 0 on failure → classify by output). Raw-source parser =
  imports + call graph + ctors (hydration-free, whole-program, approximate).
- **Engine: chDB** (embedded ClickHouse, `pip install chdb`, ~712 MB) querying CSVs
  in-process via `file('…','CSVWithNames')`. DuckDB is the engine-neutral fallback.
- **Surface: CLI-first**, documented in `AGENTS.md`, called via the agents' Bash
  tool. MCP may wrap later.
- **Location: `tools/code-graph/`**; generated artifacts in `tools/code-graph/.out/`
  (gitignored).
- **Effect model: backward.** Seed at stdlib call sites, propagate **callee→caller**
  over `invokes`. `iface` effect rows are **transitive** → the **validation oracle**,
  never forward-propagated. (Validated: `print_version` reports `effects:["IO"]`,
  `pure:true`, type `(())->()!{IO}`; `compaction` exports report `effects:[]`.)
- **Slug scheme:** `{module}#{name}`, **case-preserving**, **kind-separated tables**
  (`modules`/`funcs`/`types`/`ctors`). Module slug = repo-relative file path,
  validated against the `module` decl. Ctor names payload-stripped. Assert
  `(table, slug)` uniqueness + flag duplicate unqualified imports at emit.
- **Unimported roots derived programmatically** (TS-host string-literal scan;
  `registry_generated.ail` + `[extensions].order`; `scripts/`+`examples/`+test
  globs). Output labeled **"unimported," never "dead."**
- **Call-graph precision cut line** (ADR §"Call-graph precision"): **Do**
  alias-only-qualified resolution, source-derived ctor filtering, interpolation-call
  scanning (27 measured real edges). **Skip** `let`-shadowing (0 occurrences).
  **Defer to upstream `--json`**: higher-order + type-class dispatch. Re-export
  origin via typed layer only.
- **`pure`** carries no signal today (invariant `true` across 78 funcs) — passthrough
  column; upstream question filed.
- **`debug ast`** confirmed too shallow on v0.24.2 **and** v0.26.0 — not a call-graph
  source.

---

## 1. File layout under `tools/code-graph/`

The canonical home (ADR §"Resolved During Review"). The repo already has an empty
`tools/code-graph/` and a sibling `tools/mmd2svg/` (the SVG renderer). The C# graph
still sits at repo-root `code-graph/`.

```
tools/code-graph/
├── README.md                  # what this is, how to run, how agents query it
├── extract.sh                 # orchestrator: structural → typed → effect → viz; records built_at + ailang_version; `--structural-only` skips the typed+effect passes (no hydration)
├── .gitignore                 # ".out/"
├── extractor/
│   ├── __init__.py
│   ├── slugs.py               # slug construction + (table,slug) uniqueness asserts; dup-import flagger
│   ├── source_parser.py       # HARDENED PoC: imports, func spans, call resolution, ctor decls, interpolation scan
│   ├── iface_pass.py          # drives `ailang iface`, ok/failed/partial classifier
│   ├── seed_catalog.py        # builds stdlib effect map; exposes effects_for(catalog, std_module, symbol); module-granular today, symbol-granular behind SEED_GRANULARITY (one-line switch on AILANG fix)
│   ├── effects.py             # backward propagation + oracle check → effects.csv, effect_edges.csv
│   ├── roots.py               # (Phase 1) programmatic root-set assembly (TS scan, registry, globs) → modules.csv is_root
│   ├── emit.py                # writes all CSVs + extraction_status.csv (built_at, ailang_version, graph_schema)
│   └── config.py              # roots (src, scripts, examples), std-module filter, GRAPH_SCHEMA, SEED_GRANULARITY ("module"→"symbol")
├── query/
│   └── cgq.py                 # chDB CLI: SQL/named-query in, JSON out, staleness+coverage banners, truncation
├── viz/
│   └── visualize.py           # module-dep + call + effect Mermaid → .mmd → .svg (reuses code-graph/visualize.py render_svg path)
├── tests/
│   ├── fixtures/
│   │   ├── parser/            # *.ail golden inputs + *.expected.json (one per resolution case)
│   │   ├── iface/             # captured stdout streams for ok/failed/partial classifier
│   │   └── sample3/           # the hand-validated 3-module precision/recall corpus (incl. agent_loop_v2)
│   ├── test_source_parser.py
│   ├── test_classifier.py
│   ├── test_slugs.py
│   ├── test_seed_catalog.py
│   ├── test_effects_oracle.py
│   └── test_precision_recall.py
└── .out/                      # GITIGNORED — generated CSVs + reports + .mmd/.svg
    ├── modules.csv  funcs.csv  types.csv  ctors.csv
    ├── imports.csv  invokes.csv  std_calls.csv  uses.csv
    ├── effects.csv  effect_edges.csv
    ├── extraction_status.csv
    ├── seed_catalog.json       # stdlib module→effect map (Phase 0 build input, cached here)
    ├── oracle_report.json      # Phase 2 reachable-vs-declared divergence report
    └── *.mmd  *.svg
```

**Language: Python** (ADR §"Architecture"; the PoC is Python). No compiled host.

**Reuse, not copy:**
- `viz/visualize.py` imports/reuses only the `render_svg(mmd_path)` path from
  repo-root `code-graph/visualize.py` (it shells `bun tools/mmd2svg/mmd2svg.ts in out`
  — validated to exist). Its namespace-coarsening graph-building is **not** reused
  (AILANG modules are path-based, not `namespace.Type`).
  - **Scoping is mandatory, not optional.** The tree is ~68 modules / ~415 funcs
    (measured), so a whole-repo func-level SVG is unreadable. Views take a scope:
    a `--scope <dir-prefix>` (e.g. `src/core/ext`) and/or a seed
    `--around <module|func> --depth N`. The module-dependency view additionally
    offers **directory-level coarsening** (collapse `src/core/ext/*` to one node) as
    the AILANG analog of the C# namespace coarsening. Default render set = one
    coarsened module-dep graph + per-effect reachability graphs (naturally small).
- `query/cgq.py` reuses the *mechanism* of `.agent/tools/code-graph-query.ts`
  (auto-create a view per existing CSV, query, JSON-parse, truncate at N rows) but
  swaps `clickhouse local` for in-process `chdb.query(sql, "JSON")`. The `.ts`
  scripts stay reference-only.

**Existing `code-graph/` (C#) migration (ADR flags this as a separate action):**
This plan **does not** move it. Add a one-line task to Phase 3 docs: note in
`tools/code-graph/README.md` that the root `code-graph/` is the *external Zeus/C#*
graph and a future move to `tools/code-graph-csharp/` is tracked separately. Moving
it now would touch `.agent/tools/*.ts` path assumptions and is out of scope.

---

## 2. CSV schemas (exact columns)

All CSVs are `CSVWithNames` (header row = column names). Slugs are case-preserving,
`{module}#{name}`. `module` columns are repo-relative paths without `.ail`. Every
file carries a header even when zero rows.

**Typing rule (chDB CSV inference).** chDB infers a column's type from its values, so
a column that mixes integers with empty strings infers as `String` and silently
breaks numeric predicates. Therefore: a numeric column that is **always present**
(`n_funcs`, `decl_matches_path`, `distance`) emits as a bare integer; a flag/number
that can be **unknown** (`pure`) emits as a **string** `'1'`/`'0'`/`''` and is
compared as a string. Booleans that are always known emit `0`/`1` (integer). Unknown
text fields emit empty string, never `NULL`.

### Node tables (kind-separated; each its own slug space)

**`modules.csv`**
| column | type | notes |
|---|---|---|
| `slug` | string | repo-relative path, no extension: `src/core/agent_loop_v2` |
| `path` | string | repo-relative file path with `.ail` |
| `module_decl` | string | the `module` declaration as written (for the mismatch check) |
| `decl_matches_path` | int | `1` if `module_decl` == `slug`, else `0` (mode-4 guard) |
| `n_funcs` | int | functions found by source parser |
| `is_generated` | int | `1` for `registry_generated` etc. |
| `is_root` | int | `1` if in the unimported-detection root set |
| `root_reason` | string | provenance: `ts_host` / `extension` / `script_main` / `example_main` / `test` / `generated` / `` |

**`funcs.csv`** — note the deliberate split between *source facts* (always present)
and *typed facts* (present only when `iface` provided this func). `exported` and
`is_internal` are **source-derived** (a `func` is internal iff it has no `export`
keyword), so an `export func` in a module `iface` couldn't load is correctly
`exported=1, is_internal=0, has_typed_sig=0` — never mislabeled internal.
| column | type | notes |
|---|---|---|
| `slug` | string | `{module}#{name}` |
| `module` | string | module slug |
| `name` | string | function name, case-preserving |
| `exported` | int | `1` if source has `export func` (source fact) |
| `is_internal` | int | `1` iff `exported=0` (source fact; kept for query convenience) |
| `has_typed_sig` | int | `1` if `iface` emitted a signature for this func (only ever `1` in `ok`/`partial` modules, and only for exported funcs) |
| `type_sig` | string | from `iface` when `has_typed_sig=1`; else `` |
| `declared_effects` | string | pipe-joined `iface` effects array, e.g. `Env\|FS\|Net`; `` if none or `has_typed_sig=0` |
| `pure` | string | `'1'`/`'0'` passthrough from `iface`; `''` if `has_typed_sig=0` (ADR: no signal today) |
| `module_iface_status` | string | owning module's classification: `ok` / `partial` / `failed` (so a func's typed-data availability is queryable) |

**`types.csv`**
| column | type | notes |
|---|---|---|
| `slug` | string | `{module}#{TypeName}` |
| `module` | string | |
| `name` | string | PascalCase preserved |
| `kind` | string | `adt` / `record` / `alias` (best-effort from `iface`; `` if unknown) |
| `n_ctors` | int | |

**`ctors.csv`**
| column | type | notes |
|---|---|---|
| `slug` | string | `{module}#{CtorName}` (payload stripped: `Continue(AgentState)`→`Continue`) |
| `module` | string | |
| `name` | string | bare ctor name |
| `type_slug` | string | owning type's slug |
| `source` | string | `iface` or `source` (which pass found it) |

### Edge tables (join to node tables by edge type)

**`imports.csv`** — **repo** module → **repo** module (alias-aware). `std/*` imports
are intentionally **not** here: they carry no repo-module edge, and effect seeding
reads call-level `std_calls.csv` instead. (The parser still reads `std/*` import lines
in-memory to resolve which calls are std calls.)
| column | notes |
|---|---|
| `from_module` | importing module slug |
| `to_module` | imported repo module slug |
| `alias` | alias if `import … as X`, else `` |
| `symbols` | pipe-joined selective symbols, e.g. `readFile\|writeFile`, else `` |

**`invokes.csv`** — **repo** func → **repo** func (approximate; whole-program;
hydration-free). Calls to `std/*` symbols do **not** appear here — they go to
`std_calls.csv` so this table stays a clean repo-only call graph for the `callers`
query and call-graph viz.
| column | notes |
|---|---|
| `from_slug` | caller func slug |
| `to_slug` | callee func slug (a repo func) |
| `resolution` | `local` (same module) / `import` (cross-module, incl. aliased) / `interpolation` (call inside `${…}`) |
| `approximate` | always `1` in v1 (in-band label) |

**`std_calls.csv`** — func → stdlib symbol (the **effect-seed source**; source-parsed,
hydration-free). Every call resolved to a symbol imported from `std/*` (selective,
aliased, or qualified form) emits one row. This is what Phase 2 joins against the seed
catalog; the specific `symbol` is recorded for the future per-symbol precision upgrade
even though module-granular seeding only needs `std_module`.
| column | notes |
|---|---|
| `from_slug` | calling repo func slug |
| `std_module` | the `std/X` the symbol was imported from, e.g. `std/env` |
| `symbol` | the called symbol, e.g. `getEnv` |
| `resolution` | `selective` / `alias` / `qualified` (how the import was written) |

**`uses.csv`** — func → type (from exported `iface` signatures only)
| column | notes |
|---|---|
| `from_slug` | func slug |
| `type_slug` | referenced type slug (resolved within module + imports; unresolved → `?#Name`) |
| `resolved` | `1` if `type_slug` resolved to a known type, else `0` |

**`effects.csv`** — DECLARED (authoritative, transitive, from `iface`; the oracle)
| column | notes |
|---|---|
| `func_slug` | exported func slug |
| `effect` | one row per effect, e.g. `Net` |

**`effect_edges.csv`** — REACHABLE (computed; ADR-mandated provenance schema)
| column | notes |
|---|---|
| `func_slug` | func that reaches the effect |
| `effect` | the effect |
| `source_func_slug` | the func whose stdlib call site seeded it (the primitive call site's caller) |
| `distance` | call-graph hops from the seed; `0` = this func directly calls the stdlib symbol |
| `derivation` | `primitive_seed` (distance 0) or `backward_reachable` (distance > 0) |

**`extraction_status.csv`** — one row per module; the four build-metadata columns are
**denormalized onto every row** (identical within a run) so any single row answers
"how fresh is this graph?" without a side file.
| column | notes |
|---|---|
| `module` | module slug |
| `iface_status` | `ok` / `partial` / `failed` |
| `iface_detail` | short reason, e.g. `empty_funcs` / `no_json` / `warning_prefixed` |
| `built_at` | ISO-8601 UTC of this extraction run (identical on every row) |
| `ailang_version` | `ailang --version` string at build time (identical on every row) |
| `graph_schema` | integer `GRAPH_SCHEMA` constant; bump invalidates cache (identical on every row) |
| `iface_schema` | `ailang.iface/v1` (identical on every row; lets a future `v2` be migrated/rejected) |

> A `graph_schema` bump forces a full refresh; the CLI rejects a cache whose
> `graph_schema` differs from the running extractor's constant.

---

## Phase 0 — Setup + Contract Validation (front-loaded)

**Goal:** every load-bearing contract (prereq, seed catalog, classifier, precision
harness) exists and is tested *before* any CSV is emitted, so later phases build on
validated ground. Mirrors ADR Phase 0.

### Ordered tasks

1. **Add `chdb` to prerequisites.** In `scripts/install-prerequisites.sh`, add an
   `install_chdb()` function modeled on the existing `install_python_data_science_packages()`
   (line 305, which already does `python3 -m pip install --user --break-system-packages polars`).
   Use `python3 -m pip install --user --break-system-packages chdb`; add a
   `chdb_ok()` guard (`python3 -c "import chdb"`); call it from `main()` near the
   other data tooling (after `install_duckdb`, ~line 694). Document the ~712 MB cost
   in the function's log line.
   - **Validate** the `file('…','CSVWithNames')` in-process path with a throwaway
     2-row CSV and `chdb.query("SELECT … FROM file(...)","JSON")`.
   - **Validate `WITH RECURSIVE`** in the bundled chDB (needed for transitive
     `importers`/`callers` closures — the DST R3/R13/R8 answers). ClickHouse gates
     recursive CTEs behind the analyzer (`SET enable_analyzer=1` / `allow_experimental_analyzer`
     on older builds); confirm the exact setting for this wheel. **Fallback if
     unsupported or unstable:** compute the closure in Python (iterate the edge table
     to a fixed point) and hand chDB only the resolved frontier. Record which path
     works so Phase 3 doesn't rediscover it.
2. **Build the seed catalog** (`extractor/seed_catalog.py`) — module-granular per the
   FLAG-1 decision, structured so the per-symbol upgrade is a one-line switch.
   - Parse `ailang builtins list --by-effect` (validated; 18 effect groups incl.
     `FS(33)`, `Env(3)`, `Net(2)`, `Process(4)`, `Clock(5)`, `IO(6)`, `Pure(209)`).
     Each line is `<primitive>  <module>`; the `# Effect (n)` headers give the effect.
   - Produce `module_effects: {std_module → set(effect)}` (drop the `Pure` group).
   - **Resolver boundary (the adoption seam).** Expose exactly one function the
     seeding pass calls — `effects_for(catalog, std_module, symbol) -> set[effect]` —
     and a `build_catalog()` that branches on `config.SEED_GRANULARITY`:
     `"module"` (today) fills only `module_effects`; `"symbol"` (post-AILANG-fix) also
     fills `symbol_effects: {(std_module, symbol) → set(effect)}` via a single new
     `parse_stdlib_public_iface()` builder, and `effects_for` prefers the symbol set,
     falling back to the module set. Nothing downstream of `effects_for` ever changes.
   - Persist `seed_catalog.json` under `.out/` with `ailang_version`, `granularity`
     (`"module"`/`"symbol"`), and per-mapping `source` (`builtins_by_effect`), so the
     oracle/CLI can label provenance and the over-seed metric can be compared across
     granularities.
3. **Snapshot `iface` JSON** for a representative module set (`types`, `version`,
   `compaction` = `ok`; `runtime`, `agent_loop_v2` = `failed` pre-hydration) into
   `tests/fixtures/iface/`. Pin the `ailang.iface/v1` shape:
   funcs = `{name, type, effects[], pure}`; types = `{name, ctors[]?}`
   (validated against the live binary).
4. **Ship the `ok/failed/partial` classifier** (`extractor/iface_pass.py`) with golden
   fixtures (see §"Classifier" below). Signature: `classify(stdout: str, source_func_count: int) -> verdict`.
   JSON-validity (`ok` vs `failed`) is a pure function of stdout; the `partial`
   refinement additionally needs the module's source-parsed func count (an `ok`-shaped
   JSON with empty `funcs` is only `partial` if source found ≥1 func). Both inputs are
   in-memory, so it is still unit-tested independent of the binary.
5. **Build the precision/recall harness** (`tests/test_precision_recall.py`) against
   the hand-validated 3-module `sample3/` corpus. The harness loads
   `sample3/<mod>.expected_invokes.json` (hand-curated true edge set) and compares
   against the parser output → precision, recall, and a per-case false-positive /
   false-negative breakdown. **Must include `agent_loop_v2`** (which `iface` cannot
   load — proves the hydration-free path). The numbers are recorded in §"Acceptance"
   below before v1 is Accepted.
6. **File upstream asks** via the `ailang-feedback` skill. Three, with (c) the one
   that unlocks the FLAG-1 precision upgrade — file it explicitly, not as an aside:
   - (a) `ailang debug ast --json` (call-graph precision upgrade — Phase 4).
   - (b) `pure`-semantics question (why invariant `true`; what it means).
   - (c) **Machine-readable public-stdlib-function effect rows** (the FLAG-1 fix).
     Submit the ready-to-file text from the FLAG-1 box verbatim: ask for
     `ailang iface --stdlib <module>` emitting `ailang.iface/v1` JSON with each public
     fn's `effects`, **or** `builtins list --by-effect --public` including the exported
     wrappers. Note in the issue that adopting it on the Motoko side is a one-line
     `SEED_GRANULARITY` flip (link this plan), so AILANG maintainers see the consumer
     is already pre-wired. **Record the issue URL/number in this plan and in
     `seed_catalog.py`'s docstring** so the switch's owner can track when it lands.

### Acceptance gate (Phase 0)

- `python3 -c "import chdb"` succeeds after running the prereq script; the throwaway
  `file(...)` query returns the 2 rows as JSON.
- `seed_catalog.json` lists a non-empty effect set for `std/net`, `std/fs`,
  `std/env`, `std/process`, `std/clock`, `std/io`, and ∅ for at least one pure module
  (`std/list`).
- Classifier passes all golden fixtures (below).
- The precision/recall harness runs end-to-end on `sample3/` and emits numbers (the
  *values* are graded at v1 Accept, but the harness must execute in Phase 0).

### Test/fixture deliverables (Phase 0)

- `tests/fixtures/iface/` snapshots (ok/partial/failed).
- Classifier golden fixtures (next section).
- `sample3/` corpus with hand-curated expected edges.
- `seed_catalog.json` + `test_seed_catalog.py`.

### The `ok / failed / partial` classifier (ADR §"Constraints" — rules verbatim)

Input is the **raw stdout stream** of `ailang iface <module>` (exit code **ignored**
— validated: failures exit 0). Locate the first `{` and `json.loads` from there
(validated wrinkle: a `Warning: …` line may precede the JSON on **stdout**).

| Verdict | Rule |
|---|---|
| `ok` | first-`{` slice parses as JSON **and** both `funcs` and `types` keys present |
| `partial` | valid JSON, but `funcs` empty/absent **while the source parser found ≥1 func** in that module (typed layer lost, structure intact) |
| `failed` | no valid JSON on stdout (covers empty-stdout, warning-prefixed-but-still-unparseable, truncated-JSON, stderr-only) |

**Golden fixtures** (`tests/fixtures/iface/`, one captured stream each):
`empty_stdout.txt`, `warning_prefixed_json.txt` (must classify `ok`),
`truncated_json.txt` (→ `failed`), `valid_empty_funcs.txt` (→ `partial`),
`stderr_only.txt` (→ `failed`), `valid_full.txt` (→ `ok`).

---

## Phase 1 — Structural + Call Graph (no AILANG features, no hydration)

**Goal:** ship the hydration-free structural + approximate call graph that works on
**every** module including those `iface` cannot load (e.g. `agent_loop_v2.ail`).
This phase is the load-bearing v1 deliverable (ADR sequencing: "the hydration-free
structural+call graph ships first").

### Ordered tasks

1. **Harden the PoC source parser** (`extractor/source_parser.py`), starting from
   `.agent/projects/002_code_graph/poc_callgraph.py`, with these specific upgrades
   (ADR cut line):
   - **Slugs → `#` separator, kind-separated** (replace the PoC's `{mod}.{name}`).
   - **Imports:** repo→repo edges to `imports.csv` (std excluded); `std/*` import
     lines are still parsed in-memory to drive std-call resolution (→ `std_calls.csv`);
     alias-aware; selective-symbol lists parsed into `symbols`.
   - **Func discovery:** all top-level `func` (col-0), exported + internal.
     `exported` = the `export` keyword precedes the decl — note the real order is
     `export pure func …` (validated: `compaction.ail` uses `export pure func`, so a
     naïve `^export func` test gives 0; the PoC's `(?:export\s+)?(?:pure\s+)?func`
     regex is correct). Cross-check the `export`-keyword set against `iface`'s exported
     set for `ok` modules as a consistency assertion.
   - **Alias-only-qualified resolution (DO):** map `import std/x as X (f)` calls
     written `X.f(` to the import; do **not** also map a bare `f(` to it unless `f`
     was selectively imported (fixes the PoC's over-tolerant `imp[s]=mod` on line 37,
     which can create false edges).
   - **Split repo calls from std calls (DO):** a call resolved to a repo module → an
     `invokes` row; a call resolved to a `std/*` symbol → a `std_calls` row (not
     `invokes`). This keeps `invokes` a clean repo-only graph and gives Phase 2 its
     seed source. Handle all three std-import forms (selective, aliased, qualified).
   - **Source-derived ctor filtering (DO):** parse `type T = Ctor(...) | …` decls →
     `ctors.csv` with `source=source`; exclude those names from `invokes`. (Hydration-
     free — no `iface` dependency, resolving the GLM ctor concern.)
   - **Interpolation-call scanning (DO):** within `"… ${ … f(x) … }"`, scan for
     `name(` and emit `invokes` rows with `resolution=interpolation` (ADR measured 27
     real edges, e.g. `substring`, `process_error_to_string`, `join_lines`). The PoC
     currently drops these by blanking string literals (line 18).
   - **`let`/lambda shadowing (SKIP):** 0 occurrences measured — add only a guard +
     a comment; do not implement resolution.
   - **Higher-order / type-class dispatch (DEFER to `--json`):** resolve to the name,
     not the concrete target; never invent an edge.
2. **Slug + integrity layer** (`extractor/slugs.py`): assert `(table, slug)`
   uniqueness at emit; **flag duplicate unqualified imports** (`import a (f)` +
   `import b (f)`) within a module as a loud build error; emit `decl_matches_path`.
3. **Root-set assembly** (`extractor/roots.py`) — moved here (it is pure
   source/config scanning, hydration-free, and `modules.csv` carries `is_root`).
   Populate `is_root` / `root_reason` (categories + detection in §Phase-3
   "Unimported", which consumes this data). The *query/labeling* stays Phase 3; the
   *data* is produced here so `modules.csv` is complete in one pass.
4. **Emit** `modules.csv` (incl. `is_root`/`root_reason`), `funcs.csv` (source columns
   only: `exported`, `is_internal`, `has_typed_sig=0`, `module_iface_status=''` — Phase 2
   backfills the typed columns), `imports.csv`, `invokes.csv`, `std_calls.csv`,
   `ctors.csv` (`source=source`).
5. **Query via chDB** (`query/cgq.py`, minimal form) — enough to run the
   module-dependency and "who calls X" queries.
6. **Viz** (`viz/visualize.py`): module-dependency and call-graph Mermaid → SVG via
   the reused `render_svg` path. **Scoped** (see viz note below) — a whole-repo
   415-func call graph is unreadable.

### Acceptance gate (Phase 1)

- Runs over `src/`, `scripts/`, `examples/` with **no hydration** and produces
  `imports.csv` + `invokes.csv` for **all** modules, including `agent_loop_v2`.
- The PoC's two known internal seams reproduce: `agent_loop_v2#loop_v2 →
  stub_step#dispatch_step` and `compaction#compact_step* → compaction#try_emergency_compaction`.
- All **golden parser fixtures pass** (next section).
- `(table, slug)` uniqueness holds; a seeded duplicate-import fixture triggers the
  build error.
- Module-dependency SVG renders.

### Test/fixture deliverables (Phase 1) — golden parser fixtures

One `*.ail` input + `*.expected.json` per case (ADR Acceptance list), in
`tests/fixtures/parser/`:

| Fixture | Asserts |
|---|---|
| `imports_basic` | plain `import a/b` → one `imports` row |
| `imports_alias` | `import a/b as B` → `alias=B`, qualified `B.f(` resolves |
| `imports_selective` | `import a/b (f, g)` → `symbols=f|g`; bare `f(` resolves; `h(` does not |
| `comments` | `--` line comments stripped; no edges from commented calls |
| `strings` | calls inside plain string literals dropped |
| `interpolation` | `${ f(x) }` → `invokes` row, `resolution=interpolation` |
| `ctors_source` | `type T = Ok(_) | Err(_)` → `ctors`, and `Ok(`/`Err(` NOT in `invokes` |
| `shadowing` | local `let f = …` shadowing an import → guard holds (no false edge) |
| `qualified` | `Mod.fn(` resolves to `Mod`'s module |
| `same_name` | `f` defined locally AND imported → local wins; documented behavior |
| `dup_import` | two unqualified imports of `f` → build error raised |
| `std_call` | `import std/env (getEnv)` + `getEnv(` → a `std_calls` row (`std/env`), **not** an `invokes` row |

Plus a **root-set assembly test** (`roots.py`): synthetic TS string-literals + `ailang.toml [extensions]` + `scripts`/`examples`/`*_test.ail` globs → the expected
`is_root`/`root_reason` set, including the `test "…"`/`property "…"` detection.

---

## Phase 2 — Typed Layer + Effect Graph

**Goal:** add the `iface`-derived typed layer and the backward-propagated,
oracle-checked effect graph. Annotations degrade gracefully where `iface` failed;
structure from Phase 1 stays intact.

### Ordered tasks

1. **`iface` pass** (`extractor/iface_pass.py`): run `ailang iface` per module,
   classify (Phase 0 classifier), and backfill `funcs.csv` typed columns
   (`has_typed_sig`, `type_sig`, `declared_effects`, `pure`, `module_iface_status`;
   `exported`/`is_internal` are source facts already set in Phase 1), emit `types.csv`,
   merge `iface` ctors
   into `ctors.csv` (`source=iface`, cross-checking the source-derived set), emit
   `uses.csv` (parse type references out of `type_sig` strings — **type names only,
   never effects**; ADR §"Effects come from the `effects` array, full stop"), and
   emit `extraction_status.csv` (with `built_at`, `ailang_version`, `graph_schema`,
   `iface_schema`).
2. **Declared effects → `effects.csv`** (the oracle): one row per exported func per
   effect in its `iface` `effects` array.
3. **Seed + backward propagation → `effect_edges.csv`** (`extractor/effects.py`):

   **Seeding (distance 0).** Read `std_calls.csv`. For each row `(F, std_module, …)`
   where `effects(std_module)` from the seed catalog is non-empty: emit one
   `effect_edges` row per `e ∈ effects(std_module)` with
   `(func_slug=F, effect=e, source_func_slug=F, distance=0, derivation=primitive_seed)`.
   (`std_calls.csv` is the dedicated seed source emitted in Phase 1 — no re-parsing.)

   **Backward propagation (distance > 0).** Build the reverse `invokes` graph
   (callee→caller). For each seeded `(func, effect)`, BFS **backward** over callers;
   each caller `C` at hop `d` gets
   `(func_slug=C, effect=e, source_func_slug=<original seed func>, distance=d,
   derivation=backward_reachable)`, keeping the **minimum** `distance` per
   `(func, effect, source_func_slug)`. A `(func, effect)` pair may therefore have
   multiple rows (one per seed source/path) — that is the audit trail; `reaches`
   queries `DISTINCT` on `(func, effect)`. Effects flow callee→caller only.

   *(Algorithm is a sound superset given FLAG-1 module-granular seeding; over-seeding
   is surfaced by the oracle, below.)*

4. **Oracle check** (`tests/test_effects_oracle.py` + `oracle_report.json`): for every
   `ok` module's exported func `F`, compute `reachable(F) = { effect : ∃ effect_edges
   row for F }` and compare to `declared(F)` from `effects.csv`. The two divergence
   directions are **not symmetric** — they measure different things, which is what
   makes the oracle useful despite the deliberate seed over-approximation:
   - `declared \ reachable ≠ ∅` (a declared effect we did **not** reach) is a **clean
     call-graph-incompleteness signal**: since module-granular seeding is a *superset*,
     the only way to miss a *declared* effect is a **missing call edge**. This
     direction is independent of seed granularity → it is **the** call-graph precision
     metric. Enumerate every instance; don't wave away.
   - `reachable \ declared ≠ ∅` (we reached an effect not declared) mixes two causes:
     **over-seeding** (FLAG 1 — a pure helper in an effectful module) and a **wrong
     call edge**. Report it separately as the over-seed/false-edge signal; it informs
     the per-symbol-seeding ROI but is *expected* to be non-zero in v1.
   - `oracle_report.json`: per-module divergence lists for both directions + globals
     "declared-effects reached: X/Y" and "funcs with zero over-reach: N/M".
5. **Effect-graph viz**: "what reaches `{Net}/{FS}/{Env}`" Mermaid → SVG.

### Acceptance gate (Phase 2)

- Each module classified `ok/failed/partial`; **no module silently loses its typed
  layer** (a `failed` module still has Phase-1 structure + a `failed` status row).
- `effect_edges.csv` populated with correct `distance`/`derivation` provenance; a
  spot fixture (a func that directly calls `getEnv`) shows a `distance=0,
  primitive_seed` row and its caller a `distance=1, backward_reachable` row.
- **Oracle report generated repo-wide** over **all** `ok`-module exported funcs (not
  just `sample3/` — the oracle is the independent global correctness signal). It holds
  (declared ⊆ reachable) with all divergences listed and explained (ADR Acceptance:
  "divergences enumerated and explained"). Note the check is only non-trivial for
  funcs with a **non-empty** declared-effects row (e.g. `version#print_version` →
  `[IO]`); `sample3/`'s `ok` module is chosen to include at least one such func.
- `uses.csv` references only type names (no effect leakage from text parsing).

### Test/fixture deliverables (Phase 2)

- `iface` classifier fixtures exercised end-to-end on real modules.
- Effect oracle test over `sample3/`.
- A minimal seed/propagation fixture pair (direct-call func + 1-hop caller).

---

## Phase 3 — Agent Surface (CLI-first)

**Goal:** a portable CLI (`tools/code-graph/query/cgq.py`) that Claude Code and Codex
call via Bash with zero registration, documented in `AGENTS.md`, answering the DST
questions with staleness + coverage banners.

### CLI contract (`cgq.py`)

```
cgq.py sql "<ClickHouse SQL>"        # raw SQL over the CSV views
cgq.py q <named-query> [args…]       # canned queries (below)
cgq.py status                        # extraction status, coverage, staleness
  flags: --format {json|table}  (default json)
         --limit N                (default 200; hard cap)
         --no-banner              (suppress banners; banners still in JSON meta)
```

- **View preamble** (mechanism from the reference `.ts`): for each existing
  `.out/*.csv`, `CREATE VIEW <name> AS SELECT * FROM file('<ABS>/.out/<name>.csv','CSVWithNames')`,
  then run the query via `chdb.query(sql, "JSON")`. Paths are **absolute** (resolved
  from the tool's own location, like the reference `.ts`'s `path.join(worktree,…)`) —
  `file()` resolves relative to CWD, so a relative path would break when an agent runs
  the CLI from elsewhere.
- **Transitive queries** (`importers`, `callers`, `unimported`) use `WITH RECURSIVE`
  if Phase 0 confirmed support, else the Python fixed-point fallback (Phase 0 note).
  Either way the closure is exact over the (exact) `imports` graph / (approximate)
  `invokes` graph.
- **Output JSON shape:**
  ```json
  {
    "data": [ … up to limit rows … ],
    "meta": {
      "rows_returned": N,
      "rows_total": M,
      "truncated": true|false,
      "built_at": "…",
      "ailang_version": "v0.26.0",
      "graph_schema": 1,
      "stale": true|false,
      "stale_reason": "newer .ail mtime" | "ailang_version drift" | null,
      "approximate": true,                       // always true while call graph is heuristic
      "coverage": { "ok": K, "failed": F, "partial": P, "total": T },
      "incomplete": true|false,                  // effect queries only
      "incomplete_modules": [ "src/core/runtime", … ]
    }
  }
  ```
- **Staleness** (ADR §"extraction_status"): compare `built_at` to the newest `.ail`
  mtime and `ailang_version` to the live `ailang --version`. On drift set
  `stale=true`, print a `STALE` banner to stderr, and **refuse definitive effect
  answers** (return rows but with `incomplete=true` + a refusal note in `meta`).
- **Coverage / `INCOMPLETE`** (ADR §"Constraints", GPT resolution): for effect
  queries, if any module on the relevant reverse-reachable frontier is
  `failed`/`partial`, set `incomplete=true`, list `incomplete_modules`, and **refuse
  a definitive "does not reach Net"** (answer is "unknown / incomplete", not "no").
- **Truncation:** hard cap at `--limit` (default 200); set `truncated` + `rows_total`
  (mirrors the reference `.ts` 200-row behavior).
- A `graph_schema` mismatch between the cache and the running tool → refuse with a
  "stale schema, re-run extract.sh" error.

### Named queries (canned) — must answer the DST questions

| Name | Answers | Mechanism |
|---|---|---|
| `module-deps [module]` | module-dependency graph / one module's deps | `imports` (already repo-only) |
| `importers <module>` | **DST R3/R13** transitive importers of e.g. `src/core/ext/registry_generated` | recursive closure over `imports` (sound, hydration-free — labeled exact) |
| `callers <func>` | **DST R8** who calls `dispatch_step`; **R15** who calls `try_emergency_compaction` | reverse `invokes` (approximate; labeled) |
| `reaches <effect>` | **DST R7** funcs reaching `{Net}/{FS}/{Env}` | `effect_edges` filtered by effect (approximate + coverage/INCOMPLETE) |
| `effects-of <func>` | declared vs reachable for one func (oracle view) | join `effects` ⨝ `effect_edges` |
| `unimported` | modules not in the import-closure from the root set | §"Unimported" below |
| `fan <module>` | fan-in / fan-out counts | `imports` aggregates |

### Unimported-module detection (ADR §"Root Set" — sound, labeled, never "dead")

- **Root set** is assembled in **Phase 1** (`extractor/roots.py`) and stored in
  `modules.csv` (`is_root`, `root_reason`); Phase 3 only adds the *query* (the
  transitive `imports` closure from the roots) and the labeling. The root categories
  and detection rules (consumed by `roots.py`):
  1. **TS-host runtime entries** — scan `src/tui/src/*.ts` (and `index.ts`,
     `runtime-process.ts`) string literals for `src/core/*.ail` paths
     (`supervisor`, `config`, `rpc`, `version`, `agent_loop_v2`, `ext/runtime`, …).
  2. **Extension entries** — `src/core/ext/registry_generated.ail` + `ailang.toml`
     `[extensions].order` / active profile `config.json`.
  3. **`func main` modules** under `scripts/` and `examples/` (validated: e.g.
     `scripts/smoke_v2_compaction_ai.ail`).
  4. **Test modules** — detected by the **real AILANG test convention** (validated
     against `ailang test --help`): the `*_test.ail` glob (what `ailang test --package`
     discovers), plus `src/core/test/*`, plus any module containing a
     `test "…" = …` or `property "…" (…) = …` declaration. (Note: `func test_*` is
     only a helper-naming convention, **not** the test mechanism — do not key on it.)
  5. **Generated** — `registry_generated.ail` itself.
- Output every result labeled **"unimported (not reachable via static imports from
  declared roots)"** — never "dead"/"safe to delete." Two residual unsoundness
  sources documented in the output footer (dynamic load the scan missed; liveness via
  higher-order/type-class dispatch).

### Ordered tasks

1. Finalize `cgq.py` (banners, coverage, named queries, truncation).
2. Implement the `unimported` query (transitive `imports` closure from the Phase-1
   root set) + its "unimported, not dead" labeling.
3. Add fan-in/fan-out + the four DST canned queries.
4. **Document in `AGENTS.md`** (next section).

### Acceptance gate (Phase 3)

- Against Motoko's own source, `cgq.py` answers: a module-dependency query, R3/R13
  (`importers registry_generated`), R8 (`callers dispatch_step`), R7
  (`reaches Net`/`FS`/`Env`) — each with correct `meta` banners.
- An effect query touching a `failed` module returns `incomplete=true` +
  `incomplete_modules`, not a false "does not reach."
- A deliberately stale `.out/` (touch a `.ail`) flips `stale=true` and the effect
  refusal.
- `unimported` runs with a non-empty, provenance-labeled root set and the
  "unimported, not dead" labeling.
- Call/effect SVG renders.

### Test/fixture deliverables (Phase 3)

- `query/` unit tests over a tiny fixture `.out/` (deterministic rows): banner logic,
  truncation, staleness, INCOMPLETE, and the `unimported`-closure result + labeling.

---

## Phase 4 (later) — Precision + Type-Class Model

**Goal (deferred):** when upstream `ailang debug ast --json` lands, replace the
heuristic call graph with a type-resolved one (R7/R8/R15 become exact); optionally
model `inherits`/`implements` from type classes/instances into the reserved empty
columns. No work scheduled until the upstream `--json` ask is delivered.

**Independent, smaller upgrade — FLAG-1 per-symbol seeding** (decoupled from `--json`;
ships whenever the Phase-0 task-6(c) feature request lands): implement
`parse_stdlib_public_iface()` and flip `config.SEED_GRANULARITY` to `"symbol"`. By
design this touches **only** `seed_catalog.py` — no schema, consumer, or CSV change —
and `oracle_report.json`'s over-seed metric immediately quantifies the precision gain.
This is the cheapest precision win in the plan; do it the moment AILANG ships the data.

---

## 3. Prerequisite + CI changes

### Prerequisite (`scripts/install-prerequisites.sh`)

- Add `install_chdb()` + `chdb_ok()` (modeled on `install_python_data_science_packages`,
  line 305) using `python3 -m pip install --user --break-system-packages chdb`; wire
  into `main()` after `install_duckdb` (~line 694). Log the ~712 MB footprint.

### CI (`extract.sh` orchestration + advisory checks; ADR §"CI Shape")

`extract.sh` ordering: structural pass (Phase 1) → typed+effect pass (Phase 2) → viz;
records `built_at` + `ailang_version` into `extraction_status.csv`. Batch tool, **not**
a fast-PR gate.

```bash
# Two run modes — the loud iface gate applies ONLY to the hydrated mode.
#
# (a) structural-only (no hydration; always runnable, incl. minimal CI):
tools/code-graph/extract.sh --structural-only   # imports/invokes/std_calls/ctors/roots
  # typed columns stay empty; NO module-failed gate (every typed module is expected-failed here)
#
# (b) full (typed layer; needs the registry hydrated — shared precondition w/ ADR-001):
ailang lock                                      # + install any unhydrated registry packages
tools/code-graph/extract.sh                      # -> .out/*.csv + reports + *.svg
  # fails loudly if a module's iface_status is 'failed' AND it is NOT in the
  # checked-in expected-failed allowlist (a NEW typed-layer regression breaks CI)
#
# advisory (once stable; either mode):
#   - no NEW unimported modules (sound; imports closure)
#   - effect-diff: a func that NEWLY reaches Net/FS/Env (self-evolution signal)
```

- The structural pass runs **without** hydration. The loud "unexpected `failed`" gate
  is **only meaningful in the hydrated full run** — in structural-only mode every
  hydration-dependent module is expected to be `failed`, so the gate is disabled
  there. The allowlist therefore enumerates modules that fail **even with full
  hydration** (genuine `iface` bugs/limitations), not the hydration-pending set.
- Effect-diff + unimported checks are **advisory** while the call graph is
  approximate (ADR: candidate blocking gate only after the Phase-4 `--json` upgrade).

---

## 4. `AGENTS.md` documentation task (Phase 3)

`AGENTS.md` is currently empty (0 bytes). Add a **"Code & Effect Graph (`ailang-graph`)"**
section that gives both agents a copy-pasteable entry point:

- One-line what/why + the "approximate, hydration-free call graph; exact import
  graph" caveat.
- How to refresh: `tools/code-graph/extract.sh` (and the `ailang lock` precondition
  for the typed layer).
- How to query, with worked examples mapping to the DST questions:
  ```
  python3 tools/code-graph/query/cgq.py q importers src/core/ext/registry_generated   # R3/R13
  python3 tools/code-graph/query/cgq.py q callers dispatch_step                        # R8
  python3 tools/code-graph/query/cgq.py q reaches Net                                  # R7
  python3 tools/code-graph/query/cgq.py sql "SELECT * FROM invokes WHERE to_slug LIKE '%try_emergency_compaction' LIMIT 50"
  ```
- The banner contract: results carry `approximate`, `stale`, `coverage`,
  `incomplete` — agents must **not** treat call-graph/effect output as
  compiler-derived facts, and must treat `incomplete=true` as "unknown," not "no."
- The "unimported ≠ dead" warning for the `unimported` query.

---

## 5. Acceptance Criteria for v1 "Accepted" (ADR §"Acceptance")

v1 is Accepted only when **all** hold (the ADR will not move to Accepted on
speed/coverage alone):

1. Structural extractor runs over `src/` with no hydration → `imports.csv` +
   `invokes.csv` for **all** modules incl. `agent_loop_v2`.
2. Typed pass classifies every module `ok/failed/partial`; never silently drops a
   typed layer.
3. CLI answers (against Motoko's own source): module-dependency, R3/R13 importers,
   R8 `callers dispatch_step`, R7 `reaches {Net}/{FS}/{Env}` — with correct banners.
4. **All golden parser fixtures pass** (Phase-1 table) **and** all classifier
   fixtures (Phase-0 table).
5. **Measured call-graph precision/recall** on the `sample3/` corpus (incl.
   `agent_loop_v2`), recorded in the table below **before** Accept. R8/R15 are
   claimed only to the measured recall.
6. **Effect oracle holds**: for `ok` modules, each exported func's backward-computed
   reachable effects ⊇ its `iface` `effects` row, with all divergences (both missing
   and over-seeded — FLAG 1) enumerated and explained.
7. A module-dependency SVG and a call/effect SVG render.
8. No network or live model required (typed-layer hydration aside).

### Numbers to record before Accept (filled in during Phase 0–2, then copied to the ADR)

| Metric | Target / note | Value (TBD) |
|---|---|---|
| Call-graph **precision** on `sample3/` | high bar — false edges mislead agents (ADR: "false positives hurt more") | 1.0 (3/3 true positives; 0 false positives) |
| Call-graph **recall** on `sample3/` | bar agreed before Accept; R8/R15 claimed only to this | 1.0 (3/3 true positives; 0 false negatives) |
| Oracle: `ok` modules where reachable ⊇ declared | report as N/M + divergence list | 74/108 ok exported funcs on 2026-06-28; **not accepted**, divergences in `tools/code-graph/.out/oracle_report.json` |
| Over-seed rate (reachable ⊋ declared) | FLAG-1 cost; informs per-symbol upgrade ROI | 0/108 over-reached funcs in current run; missing-declared is the blocker |
| `sample3/` composition | `agent_loop_v2` (failed/hydration-free proof) + one `ok` module **with ≥1 declared effect** (non-trivial oracle) + one `partial`/`failed` | Fixture corpus under `tools/code-graph/tests/fixtures/sample3/`: `agent_loop_v2`, `stub_step`, `ok_effect` |

---

## 6. Open questions carried from the ADR (resolve in design or explicitly defer)

- **TS-host load manifest** (ADR Open Q): v1 **scrapes** `.ts` string literals for
  runtime-entry roots (root category 1). **Deferred** — file an `ailang-feedback`/host
  ask for a canonical manifest; until then the scrape is the source, with provenance
  recorded so a manifest can replace it without schema change.
- **Test-only module with no importer and no `main`** (ADR Open Q): v1 policy =
  **auto-treat as a test root** (root category 4: "any module containing test
  functions"), labeled `root_reason=test`, so it is never reported "unimported."
  Revisit only if a no-importer/no-test/no-main module appears (flag-for-review).
- **FLAG 1 seed granularity** — **DECIDED (2026-06-28): module-granular seeding** from
  `builtins list --by-effect`. The per-symbol upgrade is filed upstream
  (Phase-0 task 6(c)) and pre-wired to the `SEED_GRANULARITY` one-line switch
  (Phase-4 "Independent upgrade"); no longer open.
```
