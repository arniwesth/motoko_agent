# Handoff: Build `ailang-graph` from the plan

Date: 2026-06-28
For: the agent implementing the code graph
From: ADR-002 + implementation-plan work (Opus 4.8)

## Your task

Implement **`ailang-graph`** — a structural + effect graph of Motoko's own AILANG
source — by executing **`AILANG_Code_Graph.md`** (the implementation plan) in this
directory. Build it under **`tools/code-graph/`**, phased, gated. You are
**implementing**, not redesigning: the plan specifies the file layout, exact CSV
schemas, the classifier, the seed catalog + propagation algorithm, the CLI contract,
and the test plan. Follow it. Where the plan says "validated," trust it but re-confirm
against the local binary if you touch that behavior.

## Read first (in this order)

1. **`.agent/projects/002_code_graph/AILANG_Code_Graph.md`** — the plan. This is your
   spec. Read it **fully**. Load-bearing sections: the two **FLAG** boxes (decided —
   see below), **§1 File layout**, **§2 CSV schemas** (all 11 tables), and **Phases
   0–4** each with goal / ordered tasks / critical files / acceptance gate / test
   deliverables. The **Acceptance Criteria** + the "Numbers to record before Accept"
   table define done.
2. **`ADR-002-ailang-code-graph-architecture.md`** — the authoritative design and the
   *why* behind every decision. Read it when the plan cites it; don't relitigate it.
3. **`poc_callgraph.py`** — your **starting code** for the Phase-1 source parser
   (`python3 poc_callgraph.py $(find src/core -name '*.ail')` → ~1019 edges, 0.1s, no
   hydration). The plan's Phase 1 hardens this; the existing regexes already handle the
   `export pure func` ordering and import aliases.
4. **`.agent/tools/code-graph-query.ts`** — reference-only. Borrow the *query
   mechanism* (auto-create a view per CSV, query, JSON-parse, truncate) for `cgq.py`;
   swap `clickhouse local` for in-process `chdb.query(sql, "JSON")`.
5. **`code-graph/visualize.py`** (repo root, C#/Zeus) — reuse **only** its
   `render_svg(mmd_path)` path (it shells `bun tools/mmd2svg/mmd2svg.ts`); the
   namespace-coarsening graph-building does **not** apply to path-based AILANG modules.

## Decisions already made — DO NOT relitigate (cite the plan/ADR)

- **FLAG 1 — DECIDED: module-granular effect seeding.** The ADR's stated source
  (`iface` on stdlib modules) **does not work on v0.26.0** (verified, every form). v1
  seeds from `ailang builtins list --by-effect` at **module granularity** (`std/X →
  {effects}`), seeded by import provenance, sound-superset. **Build the
  `effects_for(catalog, std_module, symbol)` resolver + `SEED_GRANULARITY` switch
  exactly as the plan specifies** so the per-symbol upstream fix is a one-line
  adoption later. (Plan: FLAG 1 box + Phase-0 task 2 + Phase-4 "Independent upgrade".)
- **FLAG 2 — DECIDED:** v1 does **not** scrape stdlib source (incomplete anyway);
  per-symbol precision is the upstream FR only.
- **Two sources:** `iface` (typed layer, hydration-dependent, exit 0 on failure →
  classify by output) + raw-source parser (imports, call graph, ctors; hydration-free,
  whole-program, approximate).
- **Engine: chDB** (`pip install chdb`, ~712 MB, a new prerequisite). Query CSVs
  in-process via `file('…','CSVWithNames')`. Schema stays engine-neutral.
- **Surface: CLI-first** (`cgq.py`), documented in `AGENTS.md`. Not a harness plugin.
- **Location: `tools/code-graph/`**; artifacts in `tools/code-graph/.out/` (gitignored).
- **Effect model: backward.** Seed at stdlib call sites, propagate **callee→caller**
  over `invokes`; `iface` effect rows are **transitive** → the **validation oracle**,
  never forward-propagated.
- **Slugs:** `{module}#{name}`, case-preserving, kind-separated tables; assert
  `(table, slug)` uniqueness + flag duplicate unqualified imports at emit.
- **Call-graph cut line:** Do alias resolution, source-derived ctor filtering,
  interpolation scanning. Skip `let`-shadowing (0 occurrences). Defer higher-order +
  type-class dispatch to the upstream `--json` upgrade. Never invent an edge.
- **Unimported, never "dead."** Roots assembled programmatically (plan §Phase-3
  "Unimported"); output labeled "unimported (not reachable via static imports …)."

## Validated binary facts (v0.26.0) — don't re-derive, but know them

These are confirmed against `/home/motoko/.local/bin/ailang`. Re-check only if you
change code that depends on them.

- `ailang iface <module>` → JSON, schema `ailang.iface/v1`. `funcs` = `{name, type,
  effects[], pure}`; `types` = `{name, ctors[]?}`. **Exits 0 even on failure.** May
  print a `Warning:` line on **stdout** before the JSON → locate the first `{`, don't
  `json.load` the whole stream.
- `iface` **ok** on `src/core/types`, `version`, `compaction`; **fails (no JSON)** on
  `runtime`, `agent_loop_v2` (need full registry hydration).
- Export syntax is `export pure func …` (export **before** pure) — a naïve
  `^export func` test returns 0 on `compaction.ail`. The PoC regex
  `(?:export\s+)?(?:pure\s+)?func` is correct.
- `ailang builtins list --by-effect` **works**: 18 effect groups (incl. `Net(2)`,
  `Env(3)`, `FS(33)`, `Process(4)`, `Clock(5)`, `IO(6)`, `Pure(209)`). Lines are
  `<primitive>  <module>`; `# Effect (n)` headers give the effect. This is the seed
  catalog source.
- App code imports **public wrappers**, not `_`-primitives: `import std/env (getEnv)`,
  `import std/fs (readFile, writeFile, …)`, `import std/net (httpGet)`,
  `import std/process (exec, spawnProcess)`. (Why module-granular seeding is needed.)
- `iface` on a stdlib path **fails every form** (MOD010 / invalid-characters /
  not-found). Do not depend on it.
- AILANG tests are `test "…" = expr` / `property "…" (…) = …`; `*_test.ail` is what
  `ailang test --package` discovers. **`func test_*` is only a helper convention** —
  do not key root detection on it.
- `func main` modules exist under `scripts/` (e.g. `smoke_v2_compaction_ai.ail`).
- Scale: ~68 `.ail` files under `src`/`scripts`/`examples`; PoC found ~415 funcs /
  ~1019 edges in `src/`. A whole-repo func-level SVG is unreadable → viz must scope.
- **chDB `WITH RECURSIVE` support is UNKNOWN** — the transitive `importers`/`callers`
  closures (DST R3/R13/R8) depend on it. **Validate in Phase 0**; Python fixed-point
  fallback is specified if unsupported.
- `chdb` is **not yet installed** here; `pip install chdb` is a Phase-0 prerequisite
  task (add to `scripts/install-prerequisites.sh`, modeled on the polars install).

## Sequencing & definition of done

Build in plan order; each phase has a hard gate — **do not start the next phase until
the current gate is green.**

- **Phase 0 (front-loaded):** chdb prereq + `file()`/`WITH RECURSIVE` validation; seed
  catalog with the `effects_for`/`SEED_GRANULARITY` seam; `iface` snapshots; the
  `ok/failed/partial` classifier + golden fixtures; the precision/recall harness on the
  `sample3/` corpus; **file the upstream asks** (esp. task 6(c), the FLAG-1 fix — record
  the issue URL in the plan and `seed_catalog.py`).
- **Phase 1 (ships first — the load-bearing deliverable):** the hydration-free
  structural + approximate call graph. Emits `modules/funcs/imports/invokes/std_calls/
  ctors` + roots. **Gate:** runs over `src`/`scripts`/`examples` with no hydration for
  **all** modules incl. `agent_loop_v2`; the two PoC seams reproduce; all golden parser
  fixtures pass; module-dep SVG renders.
- **Phase 2:** `iface` typed layer + backward-propagated, oracle-checked effect graph.
  **Gate:** classifier on real modules; `effect_edges` provenance correct; the **oracle
  holds repo-wide** (declared ⊆ reachable) for `ok`-module exported funcs, divergences
  enumerated.
- **Phase 3:** `cgq.py` CLI (banners, coverage/`INCOMPLETE`, truncation, staleness) +
  canned DST queries (R3/R13/R8/R7) + sound `unimported` + **`AGENTS.md`** docs.
- **Phase 4 (later):** the `--json` call-graph upgrade; and — independently, whenever
  task-6(c) lands — flip `SEED_GRANULARITY` to `"symbol"` (one-line, zero schema churn).

**v1 is Accepted only when** the plan's Acceptance Criteria all hold **and** the
"Numbers to record before Accept" table is filled (measured precision/recall on
`sample3/` incl. `agent_loop_v2`; oracle holds; over-seed rate recorded) and copied
into ADR-002 — the ADR does not move to Accepted on speed/coverage alone.

## Grounding rules (non-negotiable)

- **Validate AILANG-behavior claims against the local v0.26.0 binary**, never
  docs/memory. The facts above are a head start, not a substitute.
- **Label all call-graph / effect output approximate**, with coverage + staleness, in
  every CLI answer. The import graph is exact; the call/effect graph is not.
- **The `iface` effect-oracle is the correctness check** — compute and report it
  (`oracle_report.json`), don't assume it.
- **Phase 1 must work hydration-free** on modules `iface` can't load. Don't let any
  Phase-1 path depend on `iface`.
- If you find a plan step that is wrong or contradicts the binary, **flag it for the
  user** — the plan is the spec; changing it is a conversation, not a silent edit.

## Still open for you to resolve or carry

- **Upstream FR not yet filed.** Phase-0 task 6(c) (the FLAG-1 stdlib-effect-rows ask)
  has ready-to-submit text in the plan; file it via the `ailang-feedback` skill and
  record the issue URL. (a) `debug ast --json` and (b) the `pure`-semantics question
  are lower priority.
- **The existing C# `code-graph/` at repo root is not moved** (plan §1 — separate
  action). Leave it; just note it in `tools/code-graph/README.md`.
- The two ADR Open Questions (TS-host manifest; test-only-no-importer policy) are
  **resolved in the plan** (§6) — implement as stated, no decision needed.
