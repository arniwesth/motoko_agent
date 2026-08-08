# ADR-001: Zoomable Architecture Map with DST Trace Overlay

Date: 2026-08-08
Status: **Scoping draft** — decisions below are marked *(settled by research)*, *(proposed)*, or *(open)*. Not yet ready for review; open items need probes or a decision before this graduates to Proposed.

Research basis: `.agent/research/simulation_visualization/zoomable_map_and_simulation_overlay.md` (2026-08-08). This ADR extracts the decisions; the research doc holds the full argument and the empirical probes.

## TL;DR

Build a semantically-zoomable spatial map of Motoko's architecture — packages when zoomed out, modules, then functions when zoomed in — and make it an *instrument* by rendering DST activity on it: replay scrubbing, coverage heat, divergence localization, fault blast radius, and a declared-vs-performed architecture overlay.

- **Foundation is adoption, not construction:** the extractor, graph store, and agent query surface already exist (`tools/code-graph/` — `ailang-graph`, ADR-002/ADR-003 of project 002). This project adds three things: a **deterministic layout engine**, a **viewer**, and an **event → subject attribution** layer for DST traces.
- **Two trace kinds, named once and used consistently below.** The **ledger trace** is the DST driver's returned trace of `LedgerEvent`s and its wire projection — the compatibility surface recorded by project 007 and carried by 009/D6. The **semantic trace** is AILANG's `--emit-trace jsonl` span tree, a language-level artifact. They are different objects; conflating them was an error in an earlier draft of this ADR.
- **The map is a coordinate system.** Once every module has a stable (x, y), any code-attributable event stream becomes renderable. DST determinism makes ledger traces ideal payload: a seed is an exactly-reproducible movie on logical time.
- **Attribution v1 is an external static table** mapping the 30 trace record keys to subject-*set* rules (fixed / payload-routed / correlated — see D5 and the Q1 pass). It requires **no change to the 009/D6-governed vocabulary** — this project is a read-only consumer of the ledger-trace surface, with its own export artifact (D9). The verified upgrade path is semantic-trace correlation (span trees exist in AILANG v0.33.0; ordinal join by determinism through the `ledger_append` chokepoint, with a reaches-trace filter — see D5).
- **Renderer candidate: fastplotlib** (GPU, pygfx/wgpu, Python). Not needed for the static map (~1k modules); justified by the overlay, where corpus-scale scrubbing reaches millions of instanced elements. *(open — see D7)*
- **The viewer is a host-side program.** The devcontainer has no GPU access (verified) and will not get it; all table generation stays container-side, and anything GPU-interactive runs on the host machine against the same file-based store, installed by a committed install script. *(D10)*

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
| Event vocabulary | `src/core/dst_event_vocabulary.ail` | 34 `LedgerEvent` variants (28 LOGICAL, 6 DISPLAY-ONLY), wire names, payload schemas — a versioned compatibility surface (009/D6) |
| Replay machinery | `src/core/dst_replay.ail` | `ReplayMismatch`, `ReconstitutionFinding` — first-divergence data |
| Coverage & faults | `dst_profile_coverage`, `dst_fault_catalogue`, `dst_invariants` | Aggregation targets for the overlay views |
| AILANG semantic traces | `ailang run --emit-trace jsonl` (v0.33.0, verified) | Span tree: `function_enter`/`exit` with `span_id`/`parent_span_id`, args, results, durations; `effect` events; OTel export |

## Empirical grounding (2026-08-08)

- Semantic-trace probe (AILANG v0.33.0): a 3-function program emits a well-formed span tree; effects recorded inside enclosing spans; stdlib names qualified (`std/io.println`), **local names bare** (`helper`) — qualification is a known gap needing a small compiler patch.
- `tools/code-graph/.out/` inspected: all tables listed above present; `module_deps.mmd/svg` render path works.
- Event vocabulary counts read from source: 34 variants; 28 LOGICAL of which **26 reach the returned trace today** — the two gaps are `d64_gap_register`'s remaining entries. Load-bearing for D5's join (below).
- The ledger trace is a **returned value plus wire projection** — grep confirms no `.jsonl` ledger artifact exists anywhere in `src/core/dst_*`. The overlay therefore needs a serialized export of the ledger trace that does not exist yet (resolved as D9).
- Trace structure read from source: `LedgerRecord = WireRecord(LedgerEvent) | CompactionStageRecord | DecisionRecord`; single append chokepoint `phase_vocab.ledger_append`; run results expose `ledger_trace` / `partial_ledger_trace` (`dst_result.ail`); wire projection exported as `phase_vocab.to_schema_v1`.
- Q3 probe (`discovery_dst.ail`, AILANG v0.33.0): baseline completes (exit 0, 364 wire-projected lines streamed to stdout via the `Trace` effect, all `session_id: session_0` across ≥6 driver runs); with `--emit-trace` at either tier the process is SIGKILLed before the buffered semantic trace flushes.
- Scale: 973 files / 137,219 lines counted at HEAD of `arniwesth/mot-82-...`.
- Dev-environment probe (2026-08-08, plan grounding): the devcontainer has **no GPU access and will not get it** — no `/dev/dri`, no Vulkan ICD, no `wgpu`/`fastplotlib` installed. Development happens inside the container; the container cannot host the interactive viewer. Resolved as D10.

## Relationship to existing work

- **Project 002 (`ailang-graph`)** — the substrate. This ADR adds *projections* (`layout`, `edges_agg`, `activity`) beside its CSVs and extends `cgq.py`; it does not fork or replace the extractor. ADR-002's approximation-honesty discipline (approximate results labeled, never laundered into facts) is inherited and extended to pixels (D4).
- **Project 009 (DST, ADR-001)** — this project is a **consumer** of the ledger-trace surface (recorded by project 007, carried by 009/D6). Nothing here writes to or versions the vocabulary. The one deferred idea that would (driver-emitted subject tags) is explicitly out of scope until it can be argued as a vocabulary amendment on its own merits. All references to 009's decisions in this document are qualified `009/Dn`; bare `Dn` always means a decision of *this* ADR.
- **Root `/code-graph/` (C# original)** — history/reference only; still targets `src/Zeus.csproj`; nothing built on it.
- **`omnigraph/`, `concept_edges`** — out of scope. Noted as far-future convergence (project memory and code in one space).

## Decisions

### D1. Build on the `ailang-graph` store *(settled by research)*

New tables land beside the existing CSVs in `tools/code-graph/.out/`, generated not committed; refresh coupling to `extract.sh` is Q7:

```
layout(node_id, level, x, y, radius, snapshot)
edges_agg(level, src_agg, dst_agg, kind, weight, exactness)
activity(seed, event_idx, record_key, subject_id, rule_kind)
```

`record_key` is record-kind aware (`WireRecord:<variant>` | `CompactionStageRecord` | `DecisionRecord` — see D5). `rule_kind ∈ {fixed, payload_routed, correlated, unattributed}` records *how* the subject was derived, so downstream views can weight or filter by attribution quality without a fuzzy "confidence" number. Multi-subject records produce one row per subject.

The viewer is a second client of the existing store. Agent access extends `cgq.py` (D8), not a parallel surface. Note the map consumes the **`all` profile** (`--profile=all`): the default `core` profile covers `src/core/**` only, and the map's whole point is the repo-wide picture including `scripts/dst/**` and `packages/**`.

### D2. Deterministic containment layout *(proposed)*

Nested circle packing over the directory tree. Sibling order fixed by name hash; area by function count. No force-directed layout anywhere: containment and cross-session stability are hard requirements — the map must build spatial memory, and overlay recordings from different days must share coordinates. Layout is a pure function of the snapshot; same tree ⇒ same picture.

**Both sub-choices closed in P1 (2026-08-08), on measurement — see `NOTE-p1-stability-probe.md`.** Circle packing stands: the squarified-treemap flip condition was "every candidate stability threshold vacuous or unmeetable", and single-module insertion is bounded tightly (mean outside-zone displacement 0.0045 of the unit root radius). Q4 stands at `modules.n_funcs`: an 11× radius spread over 225 modules shows no degeneracy, with `source_files.n_lines` recorded as the one-line alternative. Two candidate stabilizations (descending-radius sibling order; area-weighted centroid frame) were measured and rejected.

**Honest limit, recorded rather than smoothed over:** circle packing bounds *insertion* but not *deletion* or *re-areaing* (outside-zone mean 0.059 and 0.110 respectively). The acceptance criterion therefore distinguishes a **threshold** (a stability claim) from a **regression ceiling** (a guard that asserts nothing about stability). This costs less than it appears: the `snapshot` key means every overlay renders two runs over **one** layout, never two, so stability protects human spatial memory, not data correctness.

### D3. LOD contract: aggregation is precomputed and conservative *(proposed)*

Zoom levels L0 (top-level dirs) → L1 (subpackages) → L2 (modules) → L3 (functions) → L4 (signature + docstring + dimmed preview). Invariant: **edge weight at level n equals the sum of its children edges at level n+1**, precomputed into `edges_agg` — never aggregated at render time. Cross-hierarchy edges use hierarchical edge bundling along the containment tree.

**L4 explicitly excludes in-canvas code editing/rendering** beyond a static preview; click-through opens the real editor. (Text at document scale is the weak point of GPU plotting; rebuilding an editor is the classic rabbit hole here.)

### D4. Approximation honesty reaches the pixels *(proposed)*

`ailang-graph` labels `invokes`/effect results `approximate`/`stale`/`coverage`/`incomplete`. The map must render these distinctions — approximate edges visually distinct from exact ones, stale snapshots bannered, `incomplete=true` rendered as *unknown*, not absent. A map that draws an approximate edge the same as an exact one is lying at a glance, which is worse than lying in a table.

### D5. Attribution: external static subject table first *(proposed)*

v1 is a curated table mapping each trace record key to a **subject-set rule**. The Q1 pass (`NOTE-q1-event-subject-pass.md`) settled the shape:

- **30 keys, not 28**: the returned trace is `[LedgerRecord]` where `LedgerRecord = WireRecord(LedgerEvent) | CompactionStageRecord | DecisionRecord` (`phase_vocab.ail:594`) — the 28 LOGICAL variants plus the two non-wire record kinds. DISPLAY-ONLY variants have `reaches_trace_today: false` and need no rules.
- **Three rule kinds** (+ `unattributed` as the fail-open state): `fixed` (19 rows), `payload_routed` (10 — subject depends on `tool`/`ext_id`/`source`/`tool_calls[]`), `correlated` (1 — `V2ToolDispatchComplete` carries no `tool` and joins to its Start by `id`).
- **15 of 30 rows are multi-subject** — typically `{owning mechanism} ∪ {payload-named tool/ext module}` — so Q1's answer is yes: rules produce sets, and the viewer renders subject-set glow.
- **Auxiliary dependency**: a tool→module map derived from `tool_catalog` + the extension registry, needed by every `payload_routed` rule.
- The two D6.4 gaps are **`ScratchpadResult` and `SessionSuspend`**; their rows are written anyway so 009's gap closure needs no table change.

Chosen because it requires **zero changes** to the 009/D6 compatibility surface and unblocks the first two overlay views. All 30 rows are settled — the 8 probe flags from the first pass were resolved same-day by construction-site reads (see the NOTE, including one heuristic correction: `phase_vocab` is not projection-only; it owns the checkpoint seam).

**Naming hazard, stated here deliberately:** `src/core/dst_attribution_table.ail` already exists and is a *different mechanism* — the site-to-hook table under 009/D4 clause 3, defining profile-reachability. This project's table attributes *events to subject modules*, not sites to hooks. The artifact must be named to preclude conflation (working name: **event-subject table**), and this paragraph exists so no future reader assumes the two are one system.

Upgrade path *(verified mechanism, deferred)*: run the DST driver under `--emit-trace`; ledger appends become spans in the semantic trace, and determinism aligns the two streams ordinally. The append chokepoint exists and is single: `phase_vocab.ledger_append` (`phase_vocab.ail:604`) is the one append function, so append spans are exactly its frames — the join needs no heuristic span matching. **The join is over the reaches-trace subsequence, not raw appends:** 2 of 28 LOGICAL variants — `ScratchpadResult` and `SessionSuspend` — do not reach the returned trace today (`d64_gap_register` gaps), so the k-th *append* is not the k-th *trace event* — the join must filter append spans by variant against the vocabulary's reaches-trace facts (or wait on 009's D6.4 gap closure, which would make the naive join sound). With the join in place, walking `parent_span_id` yields the call stack at emission, making attribution *derived* and demoting the curated table to a validation target.

**The volume gate is now empirical, not hypothetical** (Q3 probe): `--emit-trace` at *either* tier SIGKILLs a real DST script before the buffered trace flushes, while the untraced baseline completes cleanly — semantic tracing buffers until exit and cannot survive a full script today. The probe also showed one DST script runs *many* driver runs in one process under a shared `session_id`, so the naive one-seed-one-trace assumption fails for existing scripts. Both problems have the same fix: trace-on-demand runs **one profile + one seed per process**. Remaining gates: upstream streaming/incremental trace export (the concrete ask), local-name qualification (compiler patch), lambda/recursion frame-naming probes.

Driver-emitted subject tags: **rejected for this project** — they carry a vocabulary-versioning cost, while both alternatives cover the need without touching the surface: the static table now, and the ordinal join later (not free — gated as listed above — but schema-neutral).

### D6. Overlay views and their data contracts *(proposed)*

Four views, in build order, each a deterministic function over store tables — `activity` + `layout` always; views 3–4 additionally consume `edges_agg`, `imports`, and replay/coverage outputs:

1. **Static heat** — groupby(subject) over one trace. First overlay deliverable; forces the attribution design with no animation machinery, and needs no interactive viewer (a static render over `layout` suffices), so it can proceed in parallel with P2.
2. **Replay scrubber** — scrub position = row range; windowed aggregation with exponential glow decay (no per-event strobing).
3. **Divergence view** — anti-join of two runs' activity (same seed across two code versions — the primary case — or two seeds); divergence index from `ReplayMismatch`.
4. **Corpus aggregation** — coverage dead zones (`dst_profile_coverage` spatially), fault blast radius per fault class, and **declared-vs-performed**: performed flow edges with no declared import edge (hidden coupling) and declared edges never lit (dead/untested), rendered as first-class defect classes.

### D7. Renderer: fastplotlib *(open — leading candidate, not committed)*

For: Python-native (matches extractor/query/notebooks), pan/zoom/picking free, instanced rendering headroom for corpus-scale overlays. Against: young library; no UI chrome beyond its imgui integration (which Q5's answer adopts: standalone app, imgui for GUI inputs); weak large-volume text (mitigated by D3's L4 punt). Decision gate: a P2 spike rendering the full L0–L2 map with pan/zoom + picking — run **on the host via D10's install script**, since the devcontainer cannot execute it. Fallback candidates: datashader + panel (CPU-only — would also dissolve most of the D10 constraint), or a web stack (deck.gl/sigma.js) at the cost of leaving Python.

### D8. Agent surface: extend `cgq.py` *(proposed)*

New queries over `activity`: `q touched <seed>`, `q divergence <seedA> <seedB>`, `q coverage-gaps <corpus>`. The attribution layer is agent-readable before it is human-viewable; the viewer and the agent consume the same tables. No new CLI.

### D9. Ledger-trace export: a DST-side script, an overlay-owned format *(proposed — answers Q2)*

The overlay's input artifact is produced by a new export script (working name `scripts/dst/export_trace.ail`) that runs a profile at a seed exactly as existing DST scripts do, takes the returned trace from the run result (`dst_result` carries `ledger_trace: LedgerTrace`, and `partial_ledger_trace` on failure), and writes JSONL — one line per `LedgerRecord`, preceded by a header line.

- **Format ownership**: the file is the **overlay trace format, v1 — owned and versioned by this project**, not by 009. For `WireRecord`s the payload object is exactly `phase_vocab.to_schema_v1(e)` — the existing wire projection, reused unmodified through its exported API; envelope fields (`event_idx`, `record_key`, `seed`) sit *outside* the projected object. `CompactionStageRecord` and `DecisionRecord` are not on the wire surface, so they get a minimal native encoding (`{step, ext_id, outcome}` / `{step, decision}`) that this format defines.
- **Header line**: run identity mirroring the recorded axes — seed, profile id + version, program schema, generator version, AILANG version, motoko commit — so `activity` rows are joinable to run identity without parsing filenames.
- **Compatibility posture**: read-only consumer built entirely on exported pure functions (`to_schema_v1`, `event_variant_id`, record pattern-matching). No core module changes; DST scripts untouched. Wire-projection drift propagates automatically and is already guarded by the round-trip in `scripts/dst/event_vocabulary_dst.ail`. One honest caveat: this creates a *new consumer* of trace semantics, which 009 should be aware of even though no obligation is created.
- **Location**: `tools/code-graph/.out/traces/<profile>/<seed>.jsonl`, consistent with D1's generated-not-committed convention.
- **One profile + one seed per invocation** — required by the Q3 topology finding (existing scripts run many driver runs per process under one `session_id`), and it keeps per-run boundaries trivial for the future semantic-trace join.
- **Considered and rejected: capturing the stdout wire stream.** The Q3 probe found the wire projection already streams to stdout during DST runs (an AILANG `Trace` effect — `--caps Trace` is required; the Makefile strips these lines with `grep -v '^{'`). Rejected as the overlay input because it is the *emission-witness* side, not the returned trace: parity between them is a checked invariant rather than an identity, it lacks the two non-wire record kinds, and it carries no run identity.

### D10. The viewer runs on the host; the devcontainer stays headless *(proposed)*

Development happens in a dev docker container that has **no GPU access** — no `/dev/dri`, no
Vulkan ICD (verified 2026-08-08) — and GPU passthrough is not planned. Consequence, split along
the existing layer boundary (D1's file-based store is what makes the split free):

- **Container-side (unchanged)**: extraction, layout/`edges_agg` generation, the D9 exporter,
  the `activity` build, the static heat render, `cgq.py` — all CPU-only, none need a display.
- **Host-side**: the interactive viewer (D7's fastplotlib canvas or its fallback) runs on the
  host machine, reading the same `tools/code-graph/.out/` tables through the shared workspace
  mount. No server, no protocol between the two — the store is the interface.
- **The install script is a first-class deliverable**: a committed script (working name
  `tools/code-graph/viewer/install_host.sh`) that, run on the host from a checkout, installs
  every viewer requirement — uv if absent, the pinned venv from the viewer's `pyproject.toml`,
  and a wgpu adapter probe that fails loudly with a diagnosis when the host GPU stack is
  unusable. The D7 spike must be launched **via this script** on the host; "works in my
  hand-built env" does not pass the gate. The script is idempotent and re-runnable after
  dependency bumps.
- **CI/testing consequence**: container-side tests for the viewer are limited to what needs no
  adapter (style-table unit tests) plus, if software rendering (lavapipe) turns out to work in
  the container, optional offscreen golden images — an opportunistic extra, never a gate,
  because the container is not the execution environment.

Rejected alternative: GPU passthrough into the container — not available on this setup
(macOS/OrbStack host; no `/dev/dri` to forward), and it would couple the dev environment to one
machine's hardware. Rejected alternative: remote rendering from container to host browser —
adds a serving layer for no gain over the shared-mount split.

## Open questions blocking graduation to Proposed (Q1–Q7)

1. ~~Multi-subject events~~ — **answered 2026-08-08** by the Q1 pass (`NOTE-q1-event-subject-pass.md`): yes — 14 of 30 record keys are multi-subject; rules produce subject sets under three rule kinds; the table has 30 keys (28 LOGICAL variants + 2 non-wire record kinds); a tool→module auxiliary map is required. Folded into D5. Residue: 8 probe-flagged rows refining which slug fills a cell.
2. ~~Ledger-trace export~~ — **answered 2026-08-08**: resolved as **D9** — a DST-side export script writing an overlay-owned JSONL format that reuses the wire projection unmodified for `WireRecord`s and defines minimal encodings for the two non-wire record kinds. Residue: 009 should be informed it has a new read-only consumer.
3. ~~Trace-run topology~~ — **answered 2026-08-08** by probe (Q3 section of the NOTE): one process = one semantic trace, but existing DST scripts run many driver runs per process under a shared `session_id`, and semantic tracing OOM-kills a full script at either tier (buffered-until-exit export). Resolution: one-profile-one-seed-per-process for both D9 and the future semantic-trace path; upstream ask filed in the NOTE: streaming/incremental trace export. Folded into D5 and D9.
4. ~~Layout area metric~~ — **answered 2026-08-08 in P1**: `modules.n_funcs`, already extracted and stable under reformatting. The probe's degeneracy eyeball found a healthy 11× radius spread (min 0.0058, median 0.0174, max 0.0656) over 225 modules, so no switch to `source_files.n_lines`; the alternative stays recorded as a one-line change plus a probe re-run. Folded into D2.
5. ~~Viewer host~~ — **answered 2026-08-08** (user decision during planning): a **standalone fastplotlib app** on the host machine (D10) — native window, not notebook-hosted, not Qt. GUI inputs, where needed, use **imgui** (fastplotlib's built-in imgui integration). marimo keeps its existing analysis-notebook role; it never hosts the canvas. Residue: how much chrome P2 actually needs is minimal (hover/click are native fastplotlib events); the imgui surface grows only when P4's scrubber demands it.
6. **Fidelity-ladder rendering** — how the map shows *disagreement* between approximate static calls, compiler-exact calls (future), and observed dynamic calls. *(design sketch needed; can trail P7)*
7. ~~Refresh coupling~~ — **answered 2026-08-08 in P1**: both. `extract.sh` runs `build_layout.py` as its last step, deliberately *without* `|| true` (a broken layout fails the refresh — the two-step variant invites exactly the silent graph/layout lag that makes a map distrusted), and the builder stays runnable standalone so layout iteration costs no re-extraction. Freshness is keyed by a `snapshot` column — sha256 over the sorted `extraction_status.built_at` set, the profile, and a `LAYOUT_VERSION` constant — which `cgq.py` recomputes and banners on mismatch. Bumping `LAYOUT_VERSION` is how a deliberate algorithm change declares itself stale.

## Phasing

| Phase | Deliverable | Status |
|---|---|---|
| P0 | Extractor + store + query CLI | **exists** (project 002) |
| P1 | `layout` + `edges_agg` generation, deterministic packing | scoped here |
| P2 | Viewer spike (D7 gate), then L0–L2 map: pan/zoom, LOD, bundling, picking, click-to-editor | scoped here |
| P3 | D9 export script + event-subject table (30 keys, 8 probe rows to settle) + static heat overlay (depends on P1 only — parallel with P2) | scoped here |
| P4 | Replay scrubber | scoped here |
| P5 | Divergence view | scoped here |
| P6 | Corpus aggregation + declared-vs-performed | scoped here |
| P7 | L3 function zoom (approximate, honestly labeled); semantic-trace attribution upgrade | future |

## Acceptance sketch (to be firmed before Proposed)

- Layout determinism: two extractions at the same commit produce byte-identical `layout`. Layout *stability* is measured, not asserted: the layout engine reports a displacement metric (max and mean normalized displacement of nodes outside the changed subtree) for every snapshot pair, and the threshold is calibrated by a P1 probe — an unqualified "nothing else moves" guarantee is likely unachievable under circle packing, where a grown child ripples through ancestor radii, so the criterion is a bound to be established, not assumed.
- LOD soundness: every `edges_agg` weight equals the sum of its children, checked by a validator in CI.
- Attribution coverage: every one of the 30 record keys has a subject rule; unattributed records render as unattributed, never dropped.
- Overlay correctness: heat view totals equal `SELECT count(*) GROUP BY subject` for the same trace — the picture and the query never disagree.
- D4 honesty: no rendering path draws an approximate edge in the exact style (reviewable as code, testable by golden image).
- D10 installability: on a host machine with a fresh checkout, the install script alone produces a working viewer environment (wgpu adapter probe passes, the map launches); the D7 spike verdict is only valid if obtained through it.

## Not in scope

In-canvas code editing; animated LOD transitions; vocabulary/schema changes of any kind; `omnigraph`/`concept_edges` integration; general-purpose (non-Motoko) mapping.
