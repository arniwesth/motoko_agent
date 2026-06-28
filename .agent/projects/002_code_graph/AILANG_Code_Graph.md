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

---

## ⚠️ Flags for the user — two ADR points that did not survive binary validation

Per the handoff's grounding rule ("if you find an ADR decision that is wrong or
contradictory, flag it for the user — do not silently diverge"), two items in
ADR-002 require a decision before Phase 0 closes. **Neither blocks the plan** (both
have validated fallbacks built in), but both change a stated ADR mechanism, so they
are conversations, not silent edits.

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

**Proposed correction (built into this plan):** derive the seed catalog at
**module granularity** from `builtins list --by-effect` alone, which maps every
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
are missed by a line parser — so it is a Phase-2 refinement layered **on top of**
the module-granular seed, never a replacement.

**Decision needed:** ratify module-granular seeding (with per-symbol as a later
precision upgrade), or invest Phase-0 effort chasing a working stdlib-`iface` path
(e.g. an upstream `ailang-feedback` ask for `iface --stdlib <name>`). Recommended:
ratify the fallback; file the upstream ask in parallel.

### FLAG 2 (minor) — stdlib source location is real but brittle

Stdlib `.ail` source **is** on disk at `~/.local/share/ailang/std/*.ail` (validated;
`export func httpGet(url: string) -> string ! {Net}` is greppable there). But that
path is install-specific, undocumented as stable, not env-overridable via any flag
surfaced in `ailang --help`, and blocked from `iface` by MOD010. The plan therefore
treats `builtins list --by-effect` (a stable CLI contract) as authoritative and uses
the stdlib source only as an **optional** Phase-2 precision input, with the path
resolved at runtime and the build degrading gracefully if it is absent.

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
├── extract.sh                 # orchestrator: structural pass → typed pass → effect pass → viz; records built_at + ailang_version
├── .gitignore                 # ".out/"
├── extractor/
│   ├── __init__.py
│   ├── slugs.py               # slug construction + (table,slug) uniqueness asserts; dup-import flagger
│   ├── source_parser.py       # HARDENED PoC: imports, func spans, call resolution, ctor decls, interpolation scan
│   ├── iface_pass.py          # drives `ailang iface`, ok/failed/partial classifier
│   ├── seed_catalog.py        # builds stdlib module→effect map from `builtins list --by-effect`
│   ├── effects.py             # backward propagation + oracle check → effects.csv, effect_edges.csv
│   ├── roots.py               # programmatic root-set assembly (TS scan, registry, globs) for unimported detection
│   ├── emit.py                # writes all CSVs + extraction_status.csv (built_at, ailang_version, graph_schema)
│   └── config.py              # roots (src, scripts, examples), std-module filter, GRAPH_SCHEMA constant
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
└── .out/                      # GITIGNORED — generated CSVs + .mmd/.svg
    ├── modules.csv  funcs.csv  types.csv  ctors.csv
    ├── imports.csv  invokes.csv  uses.csv
    ├── effects.csv  effect_edges.csv
    ├── extraction_status.csv
    └── *.mmd  *.svg
```

**Language: Python** (ADR §"Architecture"; the PoC is Python). No compiled host.

**Reuse, not copy:**
- `viz/visualize.py` imports/reuses only the `render_svg(mmd_path)` path from
  repo-root `code-graph/visualize.py` (it shells `bun tools/mmd2svg/mmd2svg.ts in out`
  — validated to exist). Its namespace-coarsening graph-building is **not** reused
  (AILANG modules are path-based, not `namespace.Type`).
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
`{module}#{name}`. `module` columns are repo-relative paths without `.ail`. Booleans
emit as `0`/`1`. Empty/unknown effect or status fields emit as empty string, never
`NULL`. Every file carries a header even when zero rows.

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

**`funcs.csv`**
| column | type | notes |
|---|---|---|
| `slug` | string | `{module}#{name}` |
| `module` | string | module slug |
| `name` | string | function name, case-preserving |
| `exported` | int | `1` if `export func` |
| `is_internal` | int | `1` if discovered by source parse but absent from `iface` funcs |
| `type_sig` | string | from `iface` (exported, `ok` only); else `` |
| `declared_effects` | string | pipe-joined `iface` effects array, e.g. `Env|FS|Net`; `` if none/unknown |
| `pure` | int | passthrough from `iface`; `` if unknown (ADR: no signal today) |
| `iface_status` | string | `ok` / `partial` / `failed` / `internal` (the owning module's status, or `internal`) |

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

**`imports.csv`** — module → module (std-filtered, alias-aware)
| column | notes |
|---|---|
| `from_module` | importing module slug |
| `to_module` | imported module slug (repo modules only; `std/*` excluded from this table) |
| `alias` | alias if `import … as X`, else `` |
| `symbols` | pipe-joined selective symbols, e.g. `readFile|writeFile`, else `` |
| `is_std` | `1` if target was `std/*` (kept here for the seed pass, filtered from module-dep views) |

**`invokes.csv`** — func → func (approximate; whole-program; hydration-free)
| column | notes |
|---|---|
| `from_slug` | caller func slug |
| `to_slug` | callee func slug |
| `resolution` | `local` / `import` / `alias` / `interpolation` |
| `approximate` | always `1` in v1 (label) |

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

**`extraction_status.csv`** — staleness + classification + provenance (one row per module + a header/meta convention)
| column | notes |
|---|---|
| `module` | module slug |
| `iface_status` | `ok` / `partial` / `failed` |
| `iface_detail` | short reason, e.g. `empty_funcs` / `no_json` / `warning_prefixed` |
| `built_at` | ISO-8601 UTC of this extraction run (same for all rows in a run) |
| `ailang_version` | `ailang --version` string at build time |
| `graph_schema` | integer `GRAPH_SCHEMA` constant; bump invalidates cache |
| `iface_schema` | `ailang.iface/v1` (per-row, for future migration) |

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
2. **Build the seed catalog** (`extractor/seed_catalog.py`) — see FLAG 1.
   - Parse `ailang builtins list --by-effect` (validated; 18 effect groups incl.
     `FS(33)`, `Env(3)`, `Net(2)`, `Process(4)`, `Clock(5)`, `IO(6)`, `Pure(209)`).
     Each line is `<primitive>  <module>`; the `# Effect (n)` headers give the effect.
   - Produce `module → set(effect)` (drop the `Pure` group). Persist as
     `seed_catalog.json` under `.out/` with the `ailang_version` it was built from.
   - **Gate the open mechanism (FLAG 1):** record in the catalog file which source
     produced each mapping (`builtins_by_effect`), so a later per-symbol upgrade is
     additive.
3. **Snapshot `iface` JSON** for a representative module set (`types`, `version`,
   `compaction` = `ok`; `runtime`, `agent_loop_v2` = `failed` pre-hydration) into
   `tests/fixtures/iface/`. Pin the `ailang.iface/v1` shape:
   funcs = `{name, type, effects[], pure}`; types = `{name, ctors[]?}`
   (validated against the live binary).
4. **Ship the `ok/failed/partial` classifier** (`extractor/iface_pass.py`) with golden
   fixtures (see §"Classifier" below). The classifier is pure (stdout string → verdict)
   and unit-tested independent of the binary.
5. **Build the precision/recall harness** (`tests/test_precision_recall.py`) against
   the hand-validated 3-module `sample3/` corpus. The harness loads
   `sample3/<mod>.expected_invokes.json` (hand-curated true edge set) and compares
   against the parser output → precision, recall, and a per-case false-positive /
   false-negative breakdown. **Must include `agent_loop_v2`** (which `iface` cannot
   load — proves the hydration-free path). The numbers are recorded in §"Acceptance"
   below before v1 is Accepted.
6. **File upstream asks** via the `ailang-feedback` skill: (a) `ailang debug ast --json`
   (call-graph precision upgrade — Phase 4); (b) `pure`-semantics question; (c) **NEW
   from this plan:** a machine-readable way to get stdlib public-function effect rows
   (`iface --stdlib <name>` or equivalent), since `iface` on stdlib paths fails (FLAG 1).

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
   - **Imports:** std-filtered for the module-dep graph but **retained with
     `is_std=1`** in `imports.csv` (the effect seed pass needs them); alias-aware;
     selective-symbol lists parsed into `symbols`.
   - **Func discovery:** all top-level `func` (col-0), exported + internal.
   - **Alias-only-qualified resolution (DO):** map `import std/x as X (f)` calls
     written `X.f(` to the import; do **not** also map a bare `f(` to it unless `f`
     was selectively imported (fixes the PoC's over-tolerant `imp[s]=mod` on line 37,
     which can create false edges).
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
3. **Emit** `modules.csv`, `funcs.csv` (with `is_internal=1`, `iface_status=internal`
   for now), `imports.csv`, `invokes.csv`, `ctors.csv` (`source=source`).
4. **Query via chDB** (`query/cgq.py`, minimal form) — enough to run the
   module-dependency and "who calls X" queries.
5. **Viz** (`viz/visualize.py`): module-dependency and call-graph Mermaid → SVG via
   the reused `render_svg` path.

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

---

## Phase 2 — Typed Layer + Effect Graph

**Goal:** add the `iface`-derived typed layer and the backward-propagated,
oracle-checked effect graph. Annotations degrade gracefully where `iface` failed;
structure from Phase 1 stays intact.

### Ordered tasks

1. **`iface` pass** (`extractor/iface_pass.py`): run `ailang iface` per module,
   classify (Phase 0 classifier), and backfill `funcs.csv` (`exported`, `type_sig`,
   `declared_effects`, `pure`, `iface_status`), emit `types.csv`, merge `iface` ctors
   into `ctors.csv` (`source=iface`, cross-checking the source-derived set), emit
   `uses.csv` (parse type references out of `type_sig` strings — **type names only,
   never effects**; ADR §"Effects come from the `effects` array, full stop"), and
   emit `extraction_status.csv` (with `built_at`, `ailang_version`, `graph_schema`,
   `iface_schema`).
2. **Declared effects → `effects.csv`** (the oracle): one row per exported func per
   effect in its `iface` `effects` array.
3. **Seed + backward propagation → `effect_edges.csv`** (`extractor/effects.py`):

   **Seeding (distance 0).** For each func `F` and each call `F → s` where `s` is a
   symbol imported via `import std/X (…)` (read from `imports.csv`, `is_std=1`) and
   `effects(std/X)` from the seed catalog is non-empty: emit one
   `effect_edges` row per `e ∈ effects(std/X)` with
   `(func_slug=F, effect=e, source_func_slug=F, distance=0, derivation=primitive_seed)`.

   **Backward propagation (distance > 0).** Build the reverse `invokes` graph
   (callee→caller). For each seeded `(func, effect)`, BFS **backward** over callers;
   each caller `C` at hop `d` gets
   `(func_slug=C, effect=e, source_func_slug=<original seed func>, distance=d,
   derivation=backward_reachable)`, keeping the **minimum** `distance` per
   `(func, effect, source)`. Terminate per ADR's directionality: effects flow
   callee→caller only (never the reverse).

   *(Algorithm is sound-superset given FLAG-1 module-granular seeding; over-seeding is
   surfaced by the oracle, below.)*

4. **Oracle check** (`tests/test_effects_oracle.py` + a build report): for every
   `ok` module's exported func `F`, compute `reachable(F) = { effect : ∃ effect_edges
   row for F }` and compare to `declared(F)` from `effects.csv`:
   - `reachable ⊇ declared` is the **target** (every declared effect is reached).
     A **missing** declared effect (`declared \ reachable ≠ ∅`) = **call-graph
     incompleteness** → the precision metric; enumerate, don't wave away.
   - `reachable ⊋ declared` (over-reach) = **over-seeding** from module-granular
     seeds (FLAG 1) or a wrong call edge; enumerate separately.
   - Emit `oracle_report.json` to `.out/`: per-module divergence counts + a global
     "oracle holds for N/M ok modules."
5. **Effect-graph viz**: "what reaches `{Net}/{FS}/{Env}`" Mermaid → SVG.

### Acceptance gate (Phase 2)

- Each module classified `ok/failed/partial`; **no module silently loses its typed
  layer** (a `failed` module still has Phase-1 structure + a `failed` status row).
- `effect_edges.csv` populated with correct `distance`/`derivation` provenance; a
  spot fixture (a func that directly calls `getEnv`) shows a `distance=0,
  primitive_seed` row and its caller a `distance=1, backward_reachable` row.
- **Oracle report generated**; the oracle holds (reachable ⊇ declared) for the
  `ok`-module exported funcs on the `sample3/` corpus, with all divergences listed
  and explained (ADR Acceptance: "divergences enumerated and explained").
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
  `.out/*.csv`, `CREATE VIEW <name> AS SELECT * FROM file('.out/<name>.csv','CSVWithNames')`,
  then run the query via `chdb.query(sql, "JSON")`.
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
| `module-deps [module]` | module-dependency graph / one module's deps | `imports` (is_std=0) |
| `importers <module>` | **DST R3/R13** transitive importers of e.g. `src/core/ext/registry_generated` | recursive closure over `imports` (sound, hydration-free — labeled exact) |
| `callers <func>` | **DST R8** who calls `dispatch_step`; **R15** who calls `try_emergency_compaction` | reverse `invokes` (approximate; labeled) |
| `reaches <effect>` | **DST R7** funcs reaching `{Net}/{FS}/{Env}` | `effect_edges` filtered by effect (approximate + coverage/INCOMPLETE) |
| `effects-of <func>` | declared vs reachable for one func (oracle view) | join `effects` ⨝ `effect_edges` |
| `unimported` | modules not in the import-closure from the root set | §"Unimported" below |
| `fan <module>` | fan-in / fan-out counts | `imports` aggregates |

### Unimported-module detection (ADR §"Root Set" — sound, labeled, never "dead")

- **Root set assembled programmatically** (`extractor/roots.py`), with provenance in
  `modules.csv` (`is_root`, `root_reason`):
  1. **TS-host runtime entries** — scan `src/tui/src/*.ts` (and `index.ts`,
     `runtime-process.ts`) string literals for `src/core/*.ail` paths
     (`supervisor`, `config`, `rpc`, `version`, `agent_loop_v2`, `ext/runtime`, …).
  2. **Extension entries** — `src/core/ext/registry_generated.ail` + `ailang.toml`
     `[extensions].order` / active profile `config.json`.
  3. **`func main` modules** under `scripts/` and `examples/`.
  4. **Test modules** — `*_test.ail`, `src/core/test/*`, modules containing test funcs.
  5. **Generated** — `registry_generated.ail` itself.
- Output every result labeled **"unimported (not reachable via static imports from
  declared roots)"** — never "dead"/"safe to delete." Two residual unsoundness
  sources documented in the output footer (dynamic load the scan missed; liveness via
  higher-order/type-class dispatch).

### Ordered tasks

1. Finalize `cgq.py` (banners, coverage, named queries, truncation).
2. Implement `roots.py` + the `unimported` query.
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
  truncation, staleness, INCOMPLETE.
- Root-set assembly test (synthetic TS + toml + globs → expected roots).

---

## Phase 4 (later) — Precision + Type-Class Model

**Goal (deferred):** when upstream `ailang debug ast --json` lands, replace the
heuristic call graph with a type-resolved one (R7/R8/R15 become exact); optionally
model `inherits`/`implements` from type classes/instances into the reserved empty
columns. Also the place to revisit FLAG-1 per-symbol stdlib seeding once a working
stdlib-`iface` exists. No work scheduled until the upstream `--json` ask is delivered.

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
ailang lock                     # precondition for the TYPED layer (shared w/ ADR-001)
tools/code-graph/extract.sh     # -> .out/*.csv + *.svg
  # fails loudly if any module's iface_status is UNEXPECTEDLY 'failed'
  #   (expected-failed set is a checked-in allowlist; new failures break CI)
# advisory (once stable):
#   - no NEW unimported modules (sound; imports closure)
#   - effect-diff: a func that NEWLY reaches Net/FS/Env (self-evolution signal)
```

- The structural pass runs **without** hydration (CI can run it even when `ailang
  lock` / registry hydration is unavailable — it just skips the typed layer and marks
  modules `failed`).
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
| Call-graph **precision** on `sample3/` | high bar — false edges mislead agents (ADR: "false positives hurt more") | _to measure_ |
| Call-graph **recall** on `sample3/` | bar agreed before Accept; R8/R15 claimed only to this | _to measure_ |
| Oracle: `ok` modules where reachable ⊇ declared | report as N/M + divergence list | _to measure_ |
| Over-seed rate (reachable ⊋ declared) | FLAG-1 cost; informs per-symbol upgrade ROI | _to measure_ |
| `sample3/` composition | must include `agent_loop_v2` + one `ok` module + one `partial`/`failed` | _to fix_ |

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
- **FLAG 1 seed granularity** (this plan): default = module-granular seeding from
  `builtins list --by-effect`; per-symbol stdlib-signature parse is a Phase-2
  precision upgrade gated on the over-seed rate measured by the oracle. **Needs user
  ratification** (see top).
```
