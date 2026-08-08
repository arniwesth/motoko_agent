# ADR-001: Zoomable Architecture Map with DST Trace Overlay

Date: 2026-08-08
Status: **Scoping draft** — decisions below are marked *(settled by research)*, *(proposed)*, or *(open)*. Not yet ready for review; open items need probes or a decision before this graduates to Proposed.

Research basis: `.agent/research/simulation_visualization/zoomable_map_and_simulation_overlay.md` (2026-08-08). This ADR extracts the decisions; the research doc holds the full argument and the empirical probes.

## TL;DR

Build a semantically-zoomable spatial map of Motoko's architecture — packages when zoomed out, modules, then functions when zoomed in — and make it an *instrument* by rendering DST activity on it: replay scrubbing, coverage heat, divergence localization, fault blast radius, and a declared-vs-performed architecture overlay.

- **Foundation is adoption, not construction:** the extractor, graph store, and agent query surface already exist (`tools/code-graph/` — `ailang-graph`, ADR-002/ADR-003 of project 002). This project adds three things: a **deterministic layout engine**, a **viewer**, and an **event → subject attribution** layer for DST traces.
- **The map is a coordinate system.** Once every module has a stable (x, y), any code-attributable event stream becomes renderable. DST determinism makes traces ideal payload: a seed is an exactly-reproducible movie on logical time.
- **Attribution v1 is an external static table** (event variant + payload → subject module). It requires **no change to the D6-governed trace schema** (ADR-001 of project 009) — this project is a read-only consumer of `trace.jsonl`. The verified upgrade path is AILANG semantic-trace correlation (span trees exist in v0.33.0; ordinal join guaranteed by determinism).
- **Renderer candidate: fastplotlib** (GPU, pygfx/wgpu, Python). Not needed for the static map (~1k modules); justified by the overlay, where corpus-scale scrubbing reaches millions of instanced elements. *(open — see D7)*

## Context

Motoko is ~973 `.ail` files / ~137k lines, roughly doubled by its DST world: core mechanisms and their `dst_*` counterparts, drivers, fault catalogues, invariants. Structural navigation questions are answerable today via `cgq.py`; *dynamic* questions are not spatially answerable at all:

- Which modules does DST actually exercise, and which does it never touch?
- Where did two runs of the same seed diverge after a change?
- Does runtime flow match the declared import structure?

Assets this project builds on, all existing:

| Asset | Where | What it provides |
|---|---|---|
| `ailang-graph` store | `tools/code-graph/.out/` | `modules`, `imports` (exact), `funcs`, `invokes` (approximate + metadata), `effect_edges`, `source_chunks`, `extraction_status` |
| Query CLI | `tools/code-graph/query/cgq.py` | `q importers/callers/reaches/search`, raw SQL |
| Event vocabulary | `src/core/dst_event_vocabulary.ail` | 34 `LedgerEvent` variants, wire names, payload schemas, LOGICAL/DISPLAY-ONLY — a versioned compatibility surface (009 ADR-001 D6) |
| Replay machinery | `src/core/dst_replay.ail` | `ReplayMismatch`, `ReconstitutionFinding` — first-divergence data |
| Coverage & faults | `dst_profile_coverage`, `dst_fault_catalogue`, `dst_invariants` | Aggregation targets for the overlay views |
| AILANG semantic traces | `ailang run --emit-trace jsonl` (v0.33.0, verified) | Span tree: `function_enter`/`exit` with `span_id`/`parent_span_id`, args, results, durations; `effect` events; OTel export |

## Empirical grounding (2026-08-08)

- Semantic-trace probe (AILANG v0.33.0): a 3-function program emits a well-formed span tree; effects recorded inside enclosing spans; stdlib names qualified (`std/io.println`), **local names bare** (`helper`) — qualification is a known gap needing a small compiler patch.
- `tools/code-graph/.out/` inspected: all tables listed above present; `module_deps.mmd/svg` render path works.
- Scale: 973 files / 137,219 lines counted at HEAD of `arniwesth/mot-82-...`.

## Relationship to existing work

- **Project 002 (`ailang-graph`)** — the substrate. This ADR adds *projections* (`layout`, `edges_agg`, `activity`) beside its CSVs and extends `cgq.py`; it does not fork or replace the extractor. ADR-002's approximation-honesty discipline (approximate results labeled, never laundered into facts) is inherited and extended to pixels (D4).
- **Project 009 (DST, ADR-001)** — this project is a **consumer** of the recorded trace surface. Nothing here writes to or versions the D6 vocabulary. The one deferred idea that would (driver-emitted subject tags) is explicitly out of scope until it can be argued as a vocabulary amendment on its own merits.
- **Root `/code-graph/` (C# original)** — history/reference only; still targets `src/Zeus.csproj`; nothing built on it.
- **`omnigraph/`, `concept_edges`** — out of scope. Noted as far-future convergence (project memory and code in one space).

## Decisions

### D1. Build on the `ailang-graph` store *(settled by research)*

New tables land beside the existing CSVs in `tools/code-graph/.out/`, generated not committed, refreshed alongside `extract.sh`:

```
layout(node_id, level, x, y, radius, snapshot)
edges_agg(level, src_agg, dst_agg, kind, weight, exactness)
activity(seed, event_idx, variant, subject_id, confidence)
```

The viewer is a second client of the existing store. Agent access extends `cgq.py` (D8), not a parallel surface.

### D2. Deterministic containment layout *(proposed)*

Nested circle packing (or squarified treemap — *open sub-choice*) over the directory tree. Sibling order fixed by name hash; area by function count (*open sub-choice*, D9.3). No force-directed layout anywhere: containment and cross-session stability are hard requirements — the map must build spatial memory, and overlay recordings from different days must share coordinates. Layout is a pure function of the snapshot; same tree ⇒ same picture.

### D3. LOD contract: aggregation is precomputed and conservative *(proposed)*

Zoom levels L0 (top-level dirs) → L1 (subpackages) → L2 (modules) → L3 (functions) → L4 (signature + docstring + dimmed preview). Invariant: **edge weight at level n equals the sum of its children edges at level n+1**, precomputed into `edges_agg` — never aggregated at render time. Cross-hierarchy edges use hierarchical edge bundling along the containment tree.

**L4 explicitly excludes in-canvas code editing/rendering** beyond a static preview; click-through opens the real editor. (Text at document scale is the weak point of GPU plotting; rebuilding an editor is the classic rabbit hole here.)

### D4. Approximation honesty reaches the pixels *(proposed)*

`ailang-graph` labels `invokes`/effect results `approximate`/`stale`/`coverage`/`incomplete`. The map must render these distinctions — approximate edges visually distinct from exact ones, stale snapshots bannered, `incomplete=true` rendered as *unknown*, not absent. A map that draws an approximate edge the same as an exact one is lying at a glance, which is worse than lying in a table.

### D5. Attribution: external static subject table first *(proposed)*

v1 is a curated table: event variant (+ payload-field rules, e.g. tool name) → subject module(s). ~34 rows plus refinements; sibling of `dst_attribution_table`. Chosen because it requires **zero changes** to the D6 compatibility surface and unblocks the first two overlay views.

Upgrade path *(verified mechanism, deferred)*: run the DST driver under `--emit-trace`; the k-th ledger-append span in the semantic trace **is** the k-th event in `trace.jsonl` (ordinal join guaranteed by determinism); walking `parent_span_id` yields the call stack at emission, making attribution *derived* and demoting the curated table to a validation target. Gated on: trace volume management (tiers / per-module filtering / trace-on-demand), local-name qualification (compiler patch), lambda/recursion frame-naming probes.

Driver-emitted subject tags: **rejected for this project** (vocabulary versioning cost; the ordinal join gets the same result for free).

### D6. Overlay views and their data contracts *(proposed)*

Four views, in build order, each a pure function over `activity` + `layout`:

1. **Static heat** — groupby(subject) over one trace. First deliverable; forces the attribution design with no animation machinery.
2. **Replay scrubber** — scrub position = row range; windowed aggregation with exponential glow decay (no per-event strobing).
3. **Divergence view** — anti-join of two seeds' activity; divergence index from `ReplayMismatch`.
4. **Corpus aggregation** — coverage dead zones (`dst_profile_coverage` spatially), fault blast radius per fault class, and **declared-vs-performed**: performed flow edges with no declared import edge (hidden coupling) and declared edges never lit (dead/untested), rendered as first-class defect classes.

### D7. Renderer: fastplotlib *(open — leading candidate, not committed)*

For: Python-native (matches extractor/query/notebooks), pan/zoom/picking free, instanced rendering headroom for corpus-scale overlays, OTel-shaped future. Against: young library; no UI chrome (needs Qt/imgui or notebook host); weak large-volume text (mitigated by D3's L4 punt). Decision gate: a P2 spike rendering the full L0–L2 map with pan/zoom + picking. Fallback candidates: datashader + panel, or a web stack (deck.gl/sigma.js) at the cost of leaving Python.

### D8. Agent surface: extend `cgq.py` *(proposed)*

New queries over `activity`: `q touched <seed>`, `q divergence <seedA> <seedB>`, `q coverage-gaps <corpus>`. The attribution layer is agent-readable before it is human-viewable; the viewer and the agent consume the same tables. No new CLI.

## D9. Open questions blocking graduation to Proposed

1. **Multi-subject events** — do interaction-shaped variants attribute to a set of modules? Needs a pass over all 34 variants against the vocabulary. *(small, do first)*
2. **Trace-run topology** — does the DST harness's process model align one seed ↔ one semantic trace? Affects the ordinal join. *(probe)*
3. **Layout area metric** — function count (leading) vs LOC vs exports. *(decide in P1)*
4. **Viewer host** — marimo/Jupyter first vs Qt; marimo already in use under `tools/code-graph/notebooks/`. *(decide at D7 spike)*
5. **Fidelity-ladder rendering** — how the map shows *disagreement* between approximate static calls, compiler-exact calls (future), and observed dynamic calls. *(design sketch needed; can trail P7)*
6. **Refresh coupling** — does `extract.sh` grow layout generation, or is layout a separate step keyed to `extraction_status.built_at`? *(decide in P1)*

## Phasing

| Phase | Deliverable | Status |
|---|---|---|
| P0 | Extractor + store + query CLI | **exists** (project 002) |
| P1 | `layout` + `edges_agg` generation, deterministic packing | scoped here |
| P2 | Viewer spike (D7 gate), then L0–L2 map: pan/zoom, LOD, bundling, picking, click-to-editor | scoped here |
| P3 | Subject table + static heat overlay | scoped here |
| P4 | Replay scrubber | scoped here |
| P5 | Divergence view | scoped here |
| P6 | Corpus aggregation + declared-vs-performed | scoped here |
| P7 | L3 function zoom (approximate, honestly labeled); semantic-trace attribution upgrade | future |

## Acceptance sketch (to be firmed before Proposed)

- Layout determinism: two extractions at the same commit produce byte-identical `layout`; a one-module addition moves no unrelated node by more than its own radius. *(criterion needs a probe to calibrate)*
- LOD soundness: every `edges_agg` weight equals the sum of its children, checked by a validator in CI.
- Attribution coverage: every LOGICAL variant has a subject rule; unattributed events render as unattributed, never dropped.
- Overlay correctness: heat view totals equal `SELECT count(*) GROUP BY subject` for the same trace — the picture and the query never disagree.
- D4 honesty: no rendering path draws an approximate edge in the exact style (reviewable as code, testable by golden image).

## Not in scope

In-canvas code editing; animated LOD transitions; vocabulary/schema changes of any kind; `omnigraph`/`concept_edges` integration; general-purpose (non-Motoko) mapping.
