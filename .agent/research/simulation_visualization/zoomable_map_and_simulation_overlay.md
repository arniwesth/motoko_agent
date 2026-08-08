# Simulation Visualization — the Zoomable Architecture Map and the Trace Overlay

**Date:** 2026-08-08
**Status:** Research / feasibility. No implementation exists.
**Context:** The codebase (~973 `.ail` files, ~137k lines at time of writing) has grown past the point where it can be navigated from memory. This doc explores a two-part idea: (1) a semantically-zoomable architecture map — high-level when zoomed out, progressively more detailed when zoomed in, possibly rendering code at max zoom — and (2) the part that makes it an *instrument* rather than documentation: rendering DST traces as live activity on the map. Candidate rendering substrate: [fastplotlib](https://github.com/fastplotlib/fastplotlib) (GPU-accelerated, pygfx/wgpu).

---

## 0. Verdict up front

Feasible, and cheaper than it looks — because AILANG has explicit grep-able imports, `ailang iface <module>` already emits normalized JSON interfaces, and we own the compiler, so extraction (the part that kills most such projects) is nearly free. The static map alone does **not** need a GPU at this scale; the simulation overlay does, which is what retroactively justifies fastplotlib.

The two things to get right early: **deterministic stable layout** and **edge aggregation across zoom levels**. The thing to resist: rendering real, editable code inside the GPU canvas.

The single genuinely new piece of plumbing is **event → subject-module attribution** (§7). Everything else is assembly of parts we already have precedents for (`code-graph/` did the same pipeline shape for the C# Zeus codebase: extract → chDB → visualize).

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

- Python-native, works in Jupyter/Qt/glfw — fits the existing tooling (`code-graph/load.py`, `metrics.py`, `visualize.py` are already Python).
- Pan/zoom, picking, and an event system come free.
- Headroom for the simulation overlay (§6), where element counts genuinely explode: thousands of seeds × hundreds–thousands of events each = millions of event-instances scrubbed at interactive framerates. That *is* the scientific-viz workload fastplotlib exists for.

**Conclusion:** fastplotlib is a defensible substrate, chosen for the overlay, tolerated for the map.

---

## 3. Architecture: four separated layers

```
ailang extractor  →  graph store (parquet / chDB, versioned)  →  layout engine (deterministic)  →  viewer (fastplotlib)
```

Keep the layers separable so the renderer is swappable and the store is independently useful.

### 3.1 Extraction

Two granularities, phased:

- **Module level (v1):** AILANG imports are explicit and syntactically regular (`import src/core/types as T`, `import std/list as List (length)`). A module-level dependency graph is a day of regex work, or cleaner via the compiler. Incremental re-extraction at this level is ~1s of grep — cheap enough to run on every change, which matters because *a stale map is a distrusted map* (see Sourcetrail's fate, §9).
- **Function level (v2):** `ailang iface <module>` already outputs a normalized JSON interface per module — exported functions, types, signatures. A call graph needs AST support; since we own the compiler, that is a feature request to ourselves (`ailang ai-check` already emits structured JSON, so the machinery for structured output exists). Do not attempt function-level extraction by regex.

### 3.2 Graph store

Columnar, versioned, queryable — parquet files or chDB, following the `code-graph/` precedent (Roslyn → CSV → chDB for Zeus). Schema sketch:

```
nodes(id, kind{package|module|function}, parent_id, path, name, loc, sig_hash)
edges(src_id, dst_id, kind{import|call}, weight)
snapshots(commit_sha, extracted_at)
```

**The store is arguably worth more than the visualization.** "What depends on `tool_phase`, transitively?" as a queryable table is something Motoko itself can consume when working on its own codebase — the viewer and the agent tool are two views over the same store. Build the store first; treat the viewer as one client. (This also connects to `omnigraph/` — the decision graph and the code graph could eventually share a query surface, but that is out of scope here.)

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
3. **AILANG effect-trace correlation (v3+).** `ailang replay <trace.jsonl>` operates on language-level effect traces; correlating those with ledger events would give *function-grained* attribution. Defer until L3 zoom exists and route 1/2 feel coarse.

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
- **In-repo:** `code-graph/` (Roslyn → CSV → chDB → mermaid/SVG for Zeus) validates the extract→store→visualize pipeline shape and the chDB choice. `omnigraph/` is adjacent (typed decision graph) but currently a stub; possible future convergence at the query layer, out of scope here.
- **fastplotlib** — young but active; built on pygfx/wgpu. Strengths: instanced rendering at scale, native pan/zoom, picking/events, Jupyter/Qt/glfw. Weaknesses: no graph layout (fine — layout is ours anyway), weak large-volume text (motivates the L4 punt), no UI widgets (pair with Qt/imgui).

---

## 10. Phasing

| Phase | Deliverable | Depends on | Rough size |
|---|---|---|---|
| **P1** | Module-level import extractor → parquet store; incremental refresh | — | days |
| **P2** | Deterministic packed layout + bundled edges; fastplotlib viewer with pan/zoom, 2–3 LOD thresholds, picking, click-to-editor | P1 | ~a week |
| **P3** | Subject attribution table (34 variants + payload rules); **static heat overlay** from one trace | P1, vocabulary | days |
| **P4** | Replay scrubber (single trace, glow decay) | P2, P3 | ~a week |
| **P5** | Two-trace diff view (divergence localization via `ReplayMismatch`) | P4 | days |
| **P6** | Corpus aggregation: coverage dead zones, fault blast radius, declared-vs-performed overlay | P3–P5 | 1–2 weeks |
| **P7** | Function-level graph (`ailang iface` / compiler AST), L3 zoom | P2, compiler work | open |
| **Deferred** | In-canvas code rendering (L4 beyond preview), animated LOD transitions, driver-emitted subject tags (vocabulary versioning) | — | — |

P3 is deliberately early and deliberately *static* — a heat-painted map from a single trace already answers "what does seed 12345 touch" with no animation machinery, and it forces the attribution design (the only novel plumbing) before any investment in the fancy views.

---

## 11. Open questions

1. **Subject attribution for ambiguous variants** — some events plausibly describe an *interaction* (two subjects). Does the table map to a set of modules, and does the viewer split the glow? Probably yes/yes; needs a pass over all 34 variants.
2. **Call-graph extraction** — what exactly should the compiler emit? A `calls(caller_fn, callee_fn)` relation from the typed AST seems right; scope it with the AILANG side.
3. **Layout area metric** — LOC, function count, or export count? LOC is honest but rewards verbosity; function count is probably the better default.
4. **Viewer host** — Jupyter (fast iteration, weak chrome) vs Qt app (proper scrubber/search UI). Likely Jupyter for P2–P4, Qt if it graduates.
5. **Where the store lives** — `.code-graph/`-style artifact directory vs committed snapshots. Traces are already artifacts; the graph store probably follows the same convention (generated, not committed).
6. **Does the agent get a query tool over the store in P1?** Strongly inclined yes — it is nearly free once the store exists, and it delivers navigation value before any pixel is rendered.
