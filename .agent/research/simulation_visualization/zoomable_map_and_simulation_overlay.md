# Simulation Visualization — the Zoomable Architecture Map and the Trace Overlay

**Date:** 2026-08-08
**Status:** Research / feasibility. No implementation exists.
**Context:** The codebase (~973 `.ail` files, ~137k lines at time of writing) has grown past the point where it can be navigated from memory. This doc explores a two-part idea: (1) a semantically-zoomable architecture map — high-level when zoomed out, progressively more detailed when zoomed in, possibly rendering code at max zoom — and (2) the part that makes it an *instrument* rather than documentation: rendering DST traces as live activity on the map. Candidate rendering substrate: [fastplotlib](https://github.com/fastplotlib/fastplotlib) (GPU-accelerated, pygfx/wgpu).

---

## 0. Verdict up front

Feasible, and cheaper than it looks — because the extraction layer (the part that kills most such projects) **already exists**: `tools/code-graph/` (`ailang-graph`) extracts a structural and effect graph from this repo's AILANG source today — exact module imports, function-level nodes, source-parsed approximate calls and reachable effects, an `ailang iface` typed pass, and a SQL query CLI (`cgq.py`), all landing in `tools/code-graph/.out/`. The static map alone does **not** need a GPU at this scale; the simulation overlay does, which is what retroactively justifies fastplotlib.

The two things to get right early: **deterministic stable layout** and **edge aggregation across zoom levels**. The thing to resist: rendering real, editable code inside the GPU canvas.

The genuinely new pieces are the **layout + viewer** (§3.3–§3.4) and **event → subject-module attribution** (§7). The store, extractor, and query surface are adoption, not construction.

---

## 1. The problem

Motoko is an agent with its own deterministic simulation world. That makes the codebase double-sized in a specific way: every core mechanism (`tool_phase`, the ledger, compaction, the store) has a DST counterpart (`dst_*` modules, `scripts/dst/*_dst.ail` drivers, fixtures, fault catalogues, invariants). Navigation questions that used to be answerable by directory listing now require holding a large graph in one's head:

- What depends on `tool_phase`? What does a change there reach?
- Which modules does DST actually exercise, and which does it never touch?
- Where did two runs of the same seed diverge after a change?
- Does the runtime flow of an agent turn match the declared import structure?

The first question is static. The last three are *dynamic* — and no static map answers them. That asymmetry drives the whole design: the map is the coordinate system; the traces are the payload.

---

## 2. Scale reality check

~1k modules, an estimated 5–15k functions. This is **small by GPU-rendering standards**. fastplotlib is built to scatter millions of points; 15k nodes + edges renders at 60fps in plain canvas, sigma.js, or anything else. So GPU acceleration is *not* the deciding factor for the static map, and choosing fastplotlib must be justified on other grounds:

- Python-native, works in Jupyter/Qt/glfw — fits the existing tooling (the `ailang-graph` extractor, query CLI, and viz are already Python; there are marimo notebooks in `tools/code-graph/notebooks/`).
- Pan/zoom, picking, and an event system come free.
- Headroom for the simulation overlay (§6), where element counts genuinely explode: thousands of seeds × hundreds–thousands of events each = millions of event-instances scrubbed at interactive framerates. That *is* the scientific-viz workload fastplotlib exists for.

**Conclusion:** fastplotlib is a defensible substrate, chosen for the overlay, tolerated for the map.

---

## 3. Architecture: four separated layers

```
ailang-graph extractor (EXISTS)  →  graph store: tools/code-graph/.out/ (EXISTS)  →  layout engine (deterministic, NEW)  →  viewer (fastplotlib, NEW)
```

Keep the layers separable so the renderer is swappable and the store is independently useful.

### 3.1 Extraction — already built: `ailang-graph`

`tools/code-graph/` extracts a structural **and effect** graph from this repo's AILANG source today (see its `AGENTS.md`). What it provides, and how much the map can trust each piece:

- **Module imports — exact.** Static repo imports parsed from source. This is the ground truth for the declared-architecture layer (§6.5).
- **Function-level nodes and calls — approximate.** `funcs.csv` / `invokes.csv` are source-parsed approximations; every answer carries `approximate` / `stale` / `coverage` / `incomplete` metadata, and the tool's own contract says agents must not treat call rows as compiler-derived facts (`incomplete=true` means *unknown*, not *no*).
- **Effect edges — a whole extra dimension.** `effect_edges.csv` / `effects.csv` record reachable effects per function (`cgq.py q reaches Net`). This is a graph layer the original sketch didn't anticipate: the map can color regions by reachable effect — "everything that can touch Net" as a spatial query.
- **Typed pass** via `ailang iface`; **profiles** (`core` = `src/core/**` minus tests; `all` = broad); **source index** with function-level `source_chunks` joined by `func_slug`.

Refresh is `tools/code-graph/extract.sh` — the incremental-freshness requirement (*a stale map is a distrusted map*, §9) is met by the existing staleness metadata rather than needing new machinery. The remaining extraction wish is a **compiler-derived exact call graph** to upgrade the approximate `invokes` (we own the compiler; `ailang ai-check` shows the structured-output machinery exists). The map must not launder approximations into facts: approximate edges should be visually distinct from exact ones.

### 3.2 Graph store — already built, needs layout projections

The store exists as CSVs in `tools/code-graph/.out/` (`modules`, `imports`, `funcs`, `invokes`, `effect_edges`, `types`, `uses`, `source_chunks`, `extraction_status`), SQL-queryable via `cgq.py sql "..."`. What the map adds to it, rather than replaces:

```
layout(node_id, level, x, y, radius)          -- deterministic, per snapshot (§3.3)
edges_agg(level, src_agg, dst_agg, weight)    -- precomputed per-LOD edge aggregation (§4)
activity(seed, event_idx, variant, subject)   -- the overlay (§8)
```

**The store is arguably worth more than the visualization — and this is already proven in practice:** `cgq.py q importers/callers/reaches` is exactly the agent-consumable query surface the original sketch called for. The viewer is a second client of an existing store, not a new system. (`concept_edges` — the LLM-extracted relation graph over `.agent` Markdown — is adjacent and out of scope here, though a far-future map could render project memory and code in one space.)

### 3.3 Layout — the real risk

Two hard requirements that rule out force-directed layouts:

1. **Containment.** Children render inside their parent: functions inside modules, modules inside packages/directories. This means nested treemap or circle packing anchored to the directory tree — not free-floating springs. The directory structure gives the aggregation hierarchy for free: `repo → {src, packages, scripts, tools, ...} → subdirs → module → function`.
2. **Stability.** A map is only useful if it builds spatial memory — `src/core` must be in the same place next week, and adding one module must not reshuffle the continent. Force layouts fail this catastrophically. The layout must be **deterministic**: seeded by stable keys (path hashes), positions perturbed minimally on incremental change. Given that Motoko's entire ethos is deterministic simulation, a deterministic layout is both fitting and practically necessary — and it is *load-bearing* for the overlay (§6), because activity recordings from different days are only comparable if coordinates are stable.

Concrete approach: circle packing (or squarified treemap) over the directory tree, with sibling order fixed by name hash, area proportional to LOC or function count. Layout is recomputed per snapshot but converges to the same picture for the same tree.

Cross-hierarchy edges (imports between packages) need **edge bundling** or they become spaghetti at coarse zoom — hierarchical edge bundling (Holten-style, routing edges along the containment tree) is the standard answer and composes naturally with the packed layout.

### 3.4 Viewer

fastplotlib scene graph:

- Nodes as instanced circles/rects (`ScatterGraphic` or custom), edges as line collections with per-vertex alpha for bundling.
- Pan/zoom native; **semantic zoom** implemented as LOD thresholds on camera scale (§4).
- Picking/hover → tooltip (module path, signature); click → **open in editor** via `$EDITOR`/IDE protocol.
- UI chrome (search box, breadcrumb, seed selector, time scrubber) via Qt or imgui alongside the canvas — fastplotlib provides none of this.

---

## 4. Semantic zoom / LOD design

The zoom hierarchy and what appears at each level:

| Zoom level | Nodes shown | Edges shown | Labels |
|---|---|---|---|
| L0 — continent | top-level dirs (`src`, `packages`, `scripts`, …) | bundled inter-package edges, weighted | package names |
| L1 — region | subpackages / directories | bundled inter-module edges | dir names |
| L2 — city | modules | module imports | module names |
| L3 — building | functions inside module footprints | calls (needs v2 extraction) | function names |
| L4 — interior | function signature + docstring + dimmed body preview | — | — |

Two design notes:

**Edge aggregation is the subtle part, not node aggregation.** At L1, the forty function-level calls between two packages must collapse into one weighted edge, and crossing a zoom threshold must feel consistent — the weight at level *n* is exactly the sum of the children edges at level *n+1*. Get this invariant wrong and the map lies at coarse zoom. Precompute aggregated edge tables per level in the store; do not aggregate at render time.

**Punt on real code at L4.** Syntax-highlighted, scrollable, selectable text inside a GPU canvas means rebuilding a bad text editor — text rendering is precisely the weak point of scientific plotting libraries (fastplotlib's `TextGraphic` is fine for labels, painful for documents). Signature + docstring + a dimmed low-detail body preview (even pre-rendered to a texture), with click-through to the real editor, is 95% of the value at 5% of the cost. Revisit only if the rest works.

---

## 5. The core move: the map as a coordinate system

Once every module has a fixed spatial coordinate, **any event stream attributable to code locations becomes renderable on the map.** This is the pivot from documentation to instrument.

A DST trace is an ordered sequence of ledger events — the event vocabulary (`src/core/dst_event_vocabulary.ail`) already binds all **34 `LedgerEvent` variants** to wire names, payload schemas, and LOGICAL/DISPLAY-ONLY classification, as a *versioned compatibility surface*. That means the trace format is stable enough to build tooling on — the vocabulary artifact is exactly the contract a visualizer needs.

Two properties make DST traces uniquely good visualization material:

1. **Determinism: a seed is a movie.** The animation for seed 12345 is exactly reproducible forever. Scrubbing is array indexing.
2. **Logical time.** The timeline is event index, not wallclock — no jitter, no clock skew, no sampling. Every frame of the animation is a well-defined prefix of the trace.

---

## 6. The four views the overlay unlocks

### 6.1 Replay scrubber

Load one trace, drag a timeline slider, watch an agent turn flow through `compose → dispatcher → tool_phase → store`. Nodes pulse as events touch them; handoffs glow along edges. Simultaneously a debugging tool and the best onboarding document the architecture could have — the difference between reading a subway map and watching a train run.

### 6.2 Coverage heat

Aggregate per-module event counts over a whole corpus run (`corpus_pr_dst`, `corpus_rotating_dst`): which modules are hot, which are **never touched**. `dst_profile_coverage` already computes coverage over profiles — this is that data painted spatially. Dead zones on the map directly answer "where do DST profiles need extending?" Architectural coverage (which modules the simulation exercises) is a different and complementary signal to line coverage.

### 6.3 Divergence localization

The replay machinery already produces the exact data needed: `ReplayMismatch` and `ReconstitutionFinding` in `src/core/dst_replay.ail` identify the first divergent event between two runs. Render both traces on the map — same seed before/after a change: identical glow until event *N*, then the paths visibly split *at a place*. Spatially localizing a divergence beats diffing JSONL, especially for concurrent-mutant regressions (cf. WI-D19, where a concurrent mutant silently overwrote a fix — precisely the class of bug where "where did behavior change" is the whole question).

### 6.4 Fault blast radius

The fault catalogue (`dst_fault_catalogue`) injects faults; the map shows propagation: which modules react, which invariant trips (`dst_invariants`), and where. Aggregated over many seeds this becomes an **empirical blast-radius map per fault class** — "this fault only ever reaches these four modules" is a containment claim that is currently only assertable, not observable.

### 6.5 The deep one: declared vs. performed, lifted to architecture

`scripts/dst/declared_vs_performed.ail` already embodies the principle at tool level. The same idea lifts to the whole map:

- **Declared architecture** = the import graph (static layer).
- **Performed architecture** = the trace flow (dynamic layer).

Overlay them:

- Runtime flow between two modules with **no corresponding import edge** → hidden coupling, typically smuggled through the world/store or the ledger itself.
- Declared edges that **never light up** across the entire corpus → dead or untested dependencies.

This is a continuous architecture-conformance check, obtained for free once both layers share coordinates. It is the strongest single argument for building both layers rather than either alone.

---

## 7. The one new piece of plumbing: attribution

Everything in §6 needs an `event → module` mapping, and there is a trap:

**Emitter attribution is nearly useless.** The DST driver appends most ledger events, so attributing events to their emitting module lights up the driver and nothing else. What the map needs is **subject attribution** — *which module's behavior does this event describe?* A `ToolCall` event's subject is `tool_phase`, not the ledger appender. (Anthropomorphized: the question is not "who wrote the diary entry" but "who is the entry about.")

Three routes, cheapest first:

1. **Static subject table (v1).** A hand-maintained (or AST-derived) map from event variant → subject module(s), refined by payload fields — the event vocabulary already records payload schemas, and payloads name tools and phases, so `ToolCall{tool: "..."}` can resolve to the specific tool module. ~34 rows plus payload-refinement rules. This is a natural sibling of `dst_attribution_table` and is sufficient to ship §6.1 and §6.2.
2. **Driver instrumentation (v2).** Tag events with their subject at emission. Exact, and we own every line of the driver. The cost is touching the trace schema — which is a *maintained compatibility surface* under ADR-001 D6, so this is a vocabulary-versioning event, not a casual edit. Route 1's external table avoids that cost entirely, which is another reason it goes first.
3. **AILANG semantic-trace correlation (v3+).** Verified empirically (2026-08-08, AILANG v0.33.0): `ailang run --emit-trace jsonl` emits a **span tree** — `function_enter`/`function_exit` with `span_id`/`parent_span_id`, args, results, durations, plus `effect` events inside their enclosing span (OTel export also available). See §7.1. Defer until L3 zoom exists, but this is a verified mechanism, not speculation.

### 7.1 Semantic-trace correlation in detail

The DST driver is itself an AILANG program. Run it under `--emit-trace`: every ledger append becomes a function-call span in the semantic trace. Because both the ledger and the interpreter record appends in the same deterministic order, **the k-th append span in the semantic trace is the k-th event in `trace.jsonl`** — an ordinal join guaranteed by determinism. No correlation IDs, no timestamps, no changes to the D6-governed trace schema. (Cross-checkable against payload args echoed in `function_enter`.)

Consequences:

- **Attribution becomes derived, not curated.** With each ledger event pinned to a span, walking `parent_span_id` yields the full call stack at emission. The emitter-vs-subject distinction dissolves — the stack contains both the driver frame and the `tool_phase`/dispatcher/store frames. "Subject" becomes a projection rule over the stack (e.g., deepest non-driver, non-stdlib frame). The route-1 static table then becomes a *validation target*: derive attribution from stacks, diff against the curated table, investigate disagreements.
- **Function-grained glow (L3) with real durations** — the span tree is literally a flame graph; projected onto map coordinates it is a spatial flame graph.
- **Sub-event scrubbing** — the semantic trace records everything that happens *between* ledger events; the ledger's 34 variants become waypoints in a continuous execution recording.
- **Function-grain coverage for free** — every `function_enter` is a coverage tick; §6.2 sharpens from module- to function-resolution with zero instrumentation.
- **A second divergence layer** — `ailang replay <trace.jsonl>` verifies a run against a recorded semantic trace, giving divergence detection *below* `ReplayMismatch`: when the ledger diverges at event N, the semantic traces localize the first differing function call underneath it.
- **No observer effect, structurally.** DST runs on logical time, so tracing overhead cannot change behavior — deep tracing of a deterministic simulation is the best case for this instrumentation; heisenbugs are impossible by construction.

Why it is still v3+:

- **Volume.** Deep tier records every call; a corpus run plausibly emits 10⁸+ events. Mitigations: the existing tier system (`standard`/`deep`), per-module trace filtering (compiler feature we can add), or trace-on-demand — deep-trace only the seed under investigation, which fits the debugging workflow anyway.
- **Name qualification.** Stdlib calls are qualified (`std/io.println`); local functions appear bare (`helper`). Module identity is recoverable from the enclosing `module_start` span, but the map wants fully-qualified names in the record — a small compiler patch.
- **Unknowns:** naming of lambda/closure frames, recursion behavior, and whether the DST harness's process model aligns per-seed with per-trace boundaries.

**Design note:** the attribution table is agent-readable before it is human-viewable. "Which modules did seed X touch, in what order" as a queryable table is something Motoko itself can consume when debugging its own DST failures. Build the attribution layer as a store table with two clients (viewer, agent), not as viewer-internal code.

---

## 8. Data path for the overlay

```
DST run → trace.jsonl (ledger events, wire vocabulary)
        → attribution join (subject table)      →  activity(seed, event_idx, variant, subject_module_id)
        → parquet / chDB
        → GPU buffers (instanced points; module_id → precomputed (x, y) from layout)
```

- Columnar tuples; a corpus run is millions of rows — trivial for parquet/chDB, and exactly what maps to instanced GPU rendering.
- Scrub position = row range `[0, N)`; heat = groupby(subject_module_id) over a range; diff = anti-join of two seeds' activity streams.
- **Visual overload is a real risk:** at high scrub speeds, per-event flashes are a strobe light. Use windowed aggregation with exponential glow decay (activity in the last *k* events, faded). Tuning problem, not feasibility problem.

---

## 9. Prior art

- **Sourcetrail** — indexed, zoomable code map; the closest thing to part 1 that ever shipped. Discontinued 2021. **CodeSee** — dependency-map product; also dead. The graveyard reflects the cost of being a *general product across languages* — per-language indexers are a treadmill. An internal tool for one codebase, in a language we own the compiler for, does not pay that cost. But the lesson stands: *the map must never be stale*, hence cheap incremental extraction (§3.1) is a day-one requirement, not a polish item.
- **CodeCity / software cartography** literature — established that stable spatial metaphors build navigational memory; supports the determinism requirement in §3.3.
- **Holten, hierarchical edge bundling (2006)** — the standard answer for cross-hierarchy edges over a containment layout.
- **In-repo:** two generations. `/code-graph/` at repo root is the *original C# version* (Roslyn → CSV → chDB → mermaid/SVG), ported from another project — its scripts still point at that project's solution and it is not wired to this codebase. `tools/code-graph/` (`ailang-graph`) is the *working AILANG adaptation*: same pipeline shape, AILANG-native extractor, plus effect edges, profiles, staleness metadata, and the `cgq.py` query CLI. The AILANG version is the foundation this project builds on; the C# version is history/reference. `omnigraph/` is adjacent (typed decision graph) but currently a stub; possible future convergence at the query layer, out of scope here.
- **fastplotlib** — young but active; built on pygfx/wgpu. Strengths: instanced rendering at scale, native pan/zoom, picking/events, Jupyter/Qt/glfw. Weaknesses: no graph layout (fine — layout is ours anyway), weak large-volume text (motivates the L4 punt), no UI widgets (pair with Qt/imgui).

---

## 10. Phasing

| Phase | Deliverable | Depends on | Rough size |
|---|---|---|---|
| **P0** | ~~Extractor + store~~ — **exists** (`ailang-graph`, `tools/code-graph/.out/`, `cgq.py`) | — | done |
| **P1** | Layout projections over the existing store: `layout` + `edges_agg` tables, deterministic packing over the module/dir tree | P0 | days |
| **P2** | fastplotlib viewer: pan/zoom, 2–3 LOD thresholds, bundled edges, picking, click-to-editor; approximate edges visually distinct from exact ones | P1 | ~a week |
| **P3** | Subject attribution table (34 variants + payload rules); **static heat overlay** from one trace | P0, vocabulary | days |
| **P4** | Replay scrubber (single trace, glow decay) | P2, P3 | ~a week |
| **P5** | Two-trace diff view (divergence localization via `ReplayMismatch`) | P4 | days |
| **P6** | Corpus aggregation: coverage dead zones, fault blast radius, declared-vs-performed overlay | P3–P5 | 1–2 weeks |
| **P7** | L3 function zoom over existing `funcs`/`invokes` (approximate); upgrade path: compiler-derived exact call graph, §7.1 semantic-trace attribution | P2 | open |
| **Deferred** | In-canvas code rendering (L4 beyond preview), animated LOD transitions, driver-emitted subject tags (vocabulary versioning) | — | — |

P3 is deliberately early and deliberately *static* — a heat-painted map from a single trace already answers "what does seed 12345 touch" with no animation machinery, and it forces the attribution design (the only novel plumbing) before any investment in the fancy views. Note that P7's *data* already exists in approximate form — what gates L3 zoom is layout/rendering work plus honest display of the approximation metadata, not extraction.

---

## 11. Open questions

1. **Subject attribution for ambiguous variants** — some events plausibly describe an *interaction* (two subjects). Does the table map to a set of modules, and does the viewer split the glow? Probably yes/yes; needs a pass over all 34 variants.
2. **Call-graph fidelity ladder** — three rungs now exist or are in reach: (a) `ailang-graph`'s source-parsed `invokes` (approximate, exists today), (b) a compiler-derived exact `calls` relation from the typed AST (feature request to the AILANG side), (c) the *dynamic* call graph from semantic traces (§7.1 — observed calls, per seed). The interesting question is no longer "how to get a call graph" but how the map renders the disagreement between rungs — e.g., approximate edges the compiler refutes, or dynamic edges the static graph lacks.
3. **Layout area metric** — LOC, function count, or export count? LOC is honest but rewards verbosity; function count is probably the better default. (`funcs.csv` and `source_chunks.csv` already carry what's needed either way.)
4. **Viewer host** — Jupyter/marimo (fast iteration, weak chrome; marimo already in use under `tools/code-graph/notebooks/`) vs Qt app (proper scrubber/search UI). Likely notebook for P1–P4, Qt if it graduates.
5. ~~Where the store lives~~ — **answered**: `tools/code-graph/.out/`, generated not committed, refreshed by `extract.sh`. Layout/activity tables should land beside the existing CSVs.
6. ~~Does the agent get a query tool over the store?~~ — **answered**: it already has one (`cgq.py q importers/callers/reaches/search`, plus raw SQL). The overlay work should extend `cgq.py` with activity queries (`q touched <seed>`, `q divergence <seedA> <seedB>`) rather than invent a parallel surface.
