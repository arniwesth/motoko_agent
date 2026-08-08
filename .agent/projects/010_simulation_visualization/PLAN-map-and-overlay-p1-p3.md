# PLAN: zoomable map and trace overlay — phases P1–P3

**Status**: Plan (not started). Implements the decisions of
`ADR-001-zoomable-map-and-trace-overlay.md` (status: *Scoping draft*) — **plan acceptance is
contingent on that ADR graduating to Proposed/Accepted**; if a Dn changes at graduation, the tasks
citing it are re-planned, not silently adjusted.
**Branch**: `arniwesth/mot-84-wi-d22-execution-program2-and-the-freeze-it-finally-makes`
**Grounded at**: HEAD `a816bcd` (every `file:line` anchor below re-verified at this commit — the
handoff's anchors were checked, not inherited; one was corrected, see Gaps §7.4).
**Normative sources**: the ADR (D1–D10, acceptance sketch; D10 added 2026-08-08 by user input
during planning — the devcontainer has no GPU access, so the viewer is host-side with a committed
install script), `NOTE-q1-event-subject-pass.md` (30-key table, rule kinds, Q3 probe). The
research doc is background only where it disagrees.
**Convention**: `Dn` means a decision of ADR-001 (010); foreign decisions are qualified `009/Dn`,
per the ADR.

---

## TL;DR

Three workstreams. **WS1 (P1)** builds the deterministic layout and precomputed LOD edge
aggregation as new generated tables beside the existing `ailang-graph` CSVs, with a validator that
runs at generation time. **WS2 (P2)** and **WS3 (P3)** then run **in parallel**: WS2 is the
fastplotlib go/no-go spike and the L0–L2 interactive map; WS3 is the ledger-trace exporter (D9),
the 30-key event-subject table with its auxiliary maps, the `activity` table, the static heat
overlay (which renders over `layout` with **no viewer dependency** — the ADR says so explicitly,
D6 view 1), and the `cgq.py` query extensions (D8).

Decisions the ADR left open are decided here with rationale: **Q4** area = function count
(`modules.n_funcs`, already extracted); **D2 sub-choice** = circle packing (the D1 schema is
circle-native: `layout.radius`); **Q7** = layout generation appended to `extract.sh` *and*
standalone, with a `snapshot` staleness key banner-checked by `cgq.py`; **Q5** = Jupyter-first for
the fastplotlib canvas (marimo is not a Jupyter host; it keeps the analysis notebooks); **P1
stability metric** = normalized displacement outside the changed subtree, threshold calibrated by
a named probe; **D7 gate** = six concrete criteria plus a timebox, with the fallback procedure
written before the spike runs.

One environment fact shapes WS2 and is now a decision, not a workaround: **the devcontainer has
no GPU access and will not get it** (`/dev/dri` absent, no Vulkan ICD, no `wgpu` — verified;
user-confirmed as permanent). Per **ADR D10**, the viewer is a **host-side program**: all table
generation stays container-side, the interactive canvas runs on the host against the same
file-based `.out/` store through the shared workspace mount, and a committed **host install
script** (`tools/code-graph/viewer/install_host.sh`) is a first-class deliverable — the D7 spike
verdict only counts if the spike was launched through it. Container-side lavapipe software
rendering is an opportunistic CI extra, never the execution environment.

**Nothing in this plan touches 009's surfaces**: no core module edits, no vocabulary changes, no
driver changes. Every AILANG deliverable is a *new script* built on exported pure functions. The
full file-touch list below confirms it.

---

## Blast radius — every file touched

All deliverables are new files except two well-bounded edits (`extract.sh` +1 invocation,
`cgq.py` schema/query additions). **Zero edits under `src/core/`, `packages/`, or existing
`scripts/dst/` files.**

| File | WS | Kind | What |
|------|----|----|------|
| `tools/code-graph/layout/build_layout.py` | 1 | **new** | Deterministic circle packing → `layout.csv`; imports/invokes rollup → `edges_agg.csv`; writes `snapshot` key; self-validates before writing (calls the validator) |
| `tools/code-graph/layout/validate_layout.py` | 1 | **new** | The D3/D2 validator: rollup-sum equality, containment, sibling non-overlap, coverage, double-build byte-identity. Standalone CLI + imported by the builder |
| `tools/code-graph/layout/stability_probe.py` | 1 | **new** | The stability probe: builds layouts for mutated trees, reports the displacement metric |
| `tools/code-graph/extract.sh` | 1 | edit | +1 line invoking `build_layout.py` after `visualize.py` (same pattern, `|| true` **not** used — layout failure must fail the extraction, see Q7) |
| `tools/code-graph/query/cgq.py` | 1,3 | edit | `SCHEMAS` entries for `layout`/`edges_agg`/`activity`; layout-staleness banner; `q touched <seed>`, `q divergence <seedA> <seedB>` in `named_query` (`cgq.py:223`) |
| `tools/code-graph/viewer/pyproject.toml` | 2 | **new** | uv-managed, **pinned** dependency set for fastplotlib/wgpu/jupyter — the single source of truth both the host install and any container-side extras install from |
| `tools/code-graph/viewer/install_host.sh` | 2 | **new** | **ADR D10's install script.** Run on the *host* from a checkout: installs uv if absent, builds the pinned venv from `pyproject.toml`, runs a wgpu adapter probe (fails loudly with diagnosis if the host GPU stack is unusable), prints the launch command. Idempotent; re-run after dependency bumps |
| `tools/code-graph/viewer/spike_l0l2.py` | 2 | **new** | The D7 spike scene (disposable by design; findings outlive it) |
| `tools/code-graph/viewer/map_view.py` (+ helpers) | 2 | **new** | The L0–L2 map proper, if the gate passes |
| `.agent/projects/010_simulation_visualization/NOTE-p1-stability-probe.md` | 1 | **new** | Probe numbers + calibrated threshold (decision record for acceptance criterion) |
| `.agent/projects/010_simulation_visualization/NOTE-d7-spike-verdict.md` | 2 | **new** | Spike measurements against the gate criteria; the go/no-go record |
| `scripts/dst/export_trace.ail` | 3 | **new** | D9 exporter: one profile + one seed per invocation; writes JSONL via FS |
| `scripts/dst/run_export_trace.sh` | 3 | **new** | Wrapper: caps set, `--ai-stub`, destination dir, run-identity env injection |
| `scripts/dst/export_vocabulary.ail` | 3 | **new** | Emits the 34-row vocabulary (`variant`, `wire_names`, `classification`, `reaches_trace_today`) as JSON for the Python-side validator — same read-only posture as D9 (exported pure `event_vocabulary()`) |
| `tools/code-graph/overlay/event_subjects.py` | 3 | **new** | The 30 subject-set rules (NOTE table, verbatim), rule kinds, payload routing |
| `tools/code-graph/overlay/data/native_tool_modules.csv` | 3 | **new, committed** | Curated seed map: native tool name → handler module (small; see task 3.3) |
| `tools/code-graph/overlay/data/error_sources.csv` | 3 | **new, committed** | Curated `ErrorEvent.source` → module map (2 known values today; see task 3.3) |
| `tools/code-graph/overlay/build_activity.py` | 3 | **new** | Traces × rules → `activity.csv`; multi-subject fan-out; `unattributed` preserved |
| `tools/code-graph/overlay/render_heat.py` | 3 | **new** | Static heat SVG over `layout` — matplotlib/svgwrite, **no fastplotlib dependency** |
| `tools/code-graph/overlay/validate_overlay.py` | 3 | **new** | Coverage-vs-vocabulary check, heat-vs-SQL agreement check |
| `tools/code-graph/.out/…` | 1,3 | generated | `layout.csv`, `edges_agg.csv`, `activity.csv`, `tool_modules.csv`, `vocabulary.json`, `traces/<profile>/<seed>.jsonl`, `heat/<profile>/<seed>.svg` — generated, not committed (D1) |

Guardrail check against the hard scope list: no D5 driver tags, no force-directed layout, no
in-canvas editing, no new CLI (everything queries through `cgq.py`), all new tables in `.out/`,
exporter is one-profile-one-seed (D9), and the 30-key table is taken from the NOTE as settled.

---

## Verified substrate (at `a816bcd`) — what this plan stands on

**Verified by direct read/grep this session:**

- `phase_vocab.ail`: `checkpoint` seam `:263`, `StepDecision` `:448`, `LedgerRecord` `:594`,
  `ledger_append` `:604`, `to_schema_v1_kvs` `:778`, `to_schema_v1` `:817`. All exported.
- `event_variant_id` is exported from **`dst_event_vocabulary.ail:142`**, *not* `phase_vocab`
  (handoff imprecision, corrected — see Gaps §7.4).
- `dst_result.ail`: `SystemRun.ledger_trace` `:95`, `HarnessFailure.partial_ledger_trace` `:110`,
  `DstResult = RunCompleted | RunFailed` `:114`, `completed_run` `:130`.
- Vocabulary counts: 28 LOGICAL + 6 DISPLAY-ONLY real rows; exactly **8** real
  `reaches_trace_today: false` rows (6 DISPLAY-ONLY + `ScratchpadResult` `:249` +
  `SessionSuspend` `:393`). A ninth grep hit at `:807` is a **test fixture** inside
  `test_duplicate_row_is_rejected`, not a vocabulary row — anyone grepping counts must exclude it.
- The run-result path the exporter serializes: `session.run_v2_session_traced` →
  `TracedSessionResult{result, trace, world, emissions}` (`session.ail:173`) →
  `dst_execution.execution_of`/`result_of` (`dst_execution.ail:100,:128`) →
  `completed_run(run.result, run.trace, …)`. Seed-parametrized runs exist in
  `scripts/dst/corpus_pr_dst.ail`: `generated_world(seed)` `:309` →
  `Session.run_v2_session_traced` `:355`; `generator_version()` pinned per script (`:299`).
- Caps trap status: the Makefile's `discovery` target already runs
  `--caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub` (`Makefile:391-393`),
  but several targets still show `--caps IO` (`:226,:273,:339`). The exporter wrapper copies the
  discovery target's full caps set; it does not inherit the stale ones.
- Store schemas: `modules.csv` carries **`n_funcs`** (Q4 needs no new extraction);
  `source_files.n_lines` exists (LOC alternative); `imports.csv` is module-level exact;
  `invokes.csv` carries `approximate`; `extraction_status` carries `built_at`, `profile`,
  `include_tests`. `cgq.py` is chdb `file()` views over `.out/*.csv` with a `SCHEMAS` dict and a
  `named_query` dispatch (`cgq.py:223`) — both are the intended extension points.
- Profiles: `all` = `("src", "scripts", "examples", "packages")` (`extractor/config.py:15`).
  `extract.sh --help` text omits `packages` — stale help text, the code includes it. The current
  `.out/` was built at profile `core` (52 modules, built 2026-08-04) — **P1 begins with a fresh
  `--profile=all` extraction**.
- `ErrorEvent.source` construction sites today: `"system_prompt"` (`session.ail:2496`) and
  `"agent_loop_v2"` (golden test `phase_vocab.ail:1241`) — two values, so the source→module map
  starts tiny (task 3.3).
- Environment: **no `/dev/dri`, no `nvidia-smi`, no Vulkan ICDs, no `wgpu`/`fastplotlib`/
  `marimo`/`datashader` installed**; Python 3.12.3 system-wide with `chdb 4.2.1`, `numpy`,
  `pandas`; `uv` available. CI workflows: `dst-corpora.yml`, `verify-extensions.yml` — **no
  code-graph CI exists today** (see Gaps §7.1).

**Assumed (flagged, each with its resolution point):**

- fastplotlib's in-notebook rendering path is `jupyter_rfb` (a Jupyter widget), which marimo does
  not host — from model knowledge, not verified against installed code. Resolved at spike step 0
  (task 2.0).
- wgpu-py can render offscreen on a software Vulkan adapter (mesa lavapipe,
  `mesa-vulkan-drivers`) in a GPU-less container — plausible and standard, unverified here.
  Resolved at task 2.0; the spike design does not depend on it succeeding (host path exists).
- The exporter can mirror `corpus_pr_dst`'s `run_generated` shape for an arbitrary
  profile-at-a-seed. The functions exist and are exported (verified above); the exact
  profile-selection wiring is implementation detail resolved in task 3.1.

---

## WS1 — P1: layout projections (everything else waits on this)

### Task 1.1 — decide-and-build: deterministic containment layout → `layout.csv`

**Deliverable**: `tools/code-graph/layout/build_layout.py`; `.out/layout.csv` with the D1 schema
`layout(node_id, level, x, y, radius, snapshot)`.
**Implements**: D1 (store discipline), D2 (containment + determinism; sub-choice decided below),
Q4 (decided below).

- **Input**: `modules.csv` + `extraction_status.csv` from a **`--profile=all`** extraction (D1:
  the map is the repo-wide picture). The hierarchy is derived from module path segments:
  L0 = top-level dirs (`src`, `packages`, `scripts`, `examples`, `tools` if present), L1 =
  subpackage dirs, L2 = modules. L3/L4 are out of P1–P3 scope (ADR phasing).
- **Q4 decided: area = function count.** `modules.n_funcs` is already extracted (verified column),
  is stable under reformatting (LOC is not), and is the ADR-leading option. Zero-func modules get
  `area = max(n_funcs, 1)` so they remain visible. The stability probe (1.4) includes a
  degeneracy eyeball — if n_funcs produces pathological area variance, LOC
  (`source_files.n_lines`) is the recorded alternative; switching is a one-line change and a
  probe re-run, decided in the probe NOTE, not silently.
- **D2 sub-choice decided: circle packing.** The D1 schema is circle-native (`radius`); nested
  circles read containment at a glance; and the ADR's own acceptance sketch reasons about circle
  packing ripple. Squarified treemap is the **named fallback** if the stability probe (1.4)
  cannot calibrate an acceptable threshold — that is the decision point, with evidence.
- **Determinism spec** (the part that makes D2 checkable): sibling order = ascending
  `sha256(node_path)`; packing algorithm pure over the (tree, areas) input; coordinates
  normalized to a unit root circle and emitted with **fixed decimal quantization** (e.g. 9
  decimal places, formatted, not float-repr'd) so byte-identity is well-defined across platforms;
  no RNG anywhere; no dict-iteration-order dependence (sort every collection before iteration).
- **`snapshot`**: `sha256` over (sorted `extraction_status.built_at` values, profile,
  a `LAYOUT_VERSION` constant in the builder). Bumping `LAYOUT_VERSION` is how a deliberate
  algorithm change declares itself; the staleness banner (1.5) compares snapshot inputs.

**Verified by**: validator (1.3) run as the builder's last step; determinism double-build check;
stability probe (1.4). **Size**: 2–3 days.

### Task 1.2 — precomputed LOD edge aggregation → `edges_agg.csv`

**Deliverable**: same builder, second output; `.out/edges_agg.csv` with the D1 schema
`edges_agg(level, src_agg, dst_agg, kind, weight, exactness)`.
**Implements**: D3 (precomputed, conservative aggregation), D4 (exactness carried in-band).

- **Base levels defined exactly** (the invariant needs a defined floor):
  - `kind=imports`, `exactness=exact`: base is L2 — one edge per distinct
    (`from_module`, `to_module`) pair in `imports.csv`, `weight=1`. L1 and L0 rows are sums of
    child-pair weights (a pair of L1 nodes aggregates all L2 edges whose endpoints map into
    them; intra-node edges collapse to self-loops and are kept — the viewer decides whether to
    draw them, the table does not lie by omission).
  - `kind=invokes`, `exactness=approximate`: base is L2 — function-level `invokes.csv` rows
    rolled up to (from-module, to-module), `weight` = count of function-pair edges. Aggregated
    identically to L0/L1. This exists in P1 deliberately so **D4 has a real target in P2**: the
    map renders `imports` (exact) and `invokes` (approximate) in visibly distinct styles from
    day one.
- **The D3 invariant, stated as the validator checks it**: for every `kind`, for every edge at
  level *n* < 2: `weight(n, A→B) == Σ weight(n+1, a→b)` over children `a∈A, b∈B` — exact integer
  equality, no tolerance. Render-time aggregation is out by definition (hard guardrail).

**Verified by**: validator (1.3). **Size**: 1 day (shares tree code with 1.1).

### Task 1.3 — the validator (CI-shaped, runs at generation)

**Deliverable**: `tools/code-graph/layout/validate_layout.py` — standalone CLI over `.out/`, and
imported by the builder so **no artifact is ever written that fails it**.
**Implements**: the ADR acceptance sketch's "checked by a validator in CI"; the meta-decision's
"build the detector, don't specify it".

Checks, each a named rule (ADR-002 oracle style — enumerated findings, not a boolean):

1. **rollup-sum** — the D3 equality above, per kind, per level pair.
2. **containment** — every child circle strictly inside its parent (`dist + r_child <= r_parent`,
   quantization-aware epsilon).
3. **sibling-overlap** — no two siblings overlap.
4. **coverage** — every `modules.csv` module has exactly one L2 layout row; every `edges_agg`
   endpoint exists in `layout` at its level; every L2 node's ancestors exist at L1/L0.
5. **determinism** — rebuild in a temp dir from the same `.out` inputs; byte-compare
   `layout.csv`/`edges_agg.csv`. (This is the *sameness* direction; the probe (1.4) supplies the
   *movement* direction — a mutated tree must move the metric. Two-sided per the meta-decision.)

**Where "CI" is**: there is no code-graph CI today (Gaps §7.1). The validator runs (a) inside
every build — generation-time gating covers every path that produces the artifact — and (b) as a
standalone target for whatever workflow later adopts it. Proposal recorded, not implemented here:
a fixture mini-tree under `tools/code-graph/tests/` so a workflow can run builder+validator
hermetically in seconds without a full extraction. **Size**: 1 day.

### Task 1.4 — the stability probe (decides the P1 acceptance threshold)

**Deliverable**: `tools/code-graph/layout/stability_probe.py` + `NOTE-p1-stability-probe.md`.
**Implements**: the ADR acceptance sketch's "threshold calibrated by a P1 probe".

- **Metric (decided)**: for a snapshot pair (A, B), over nodes present in both and **outside the
  changed subtree** (changed subtree = the set of ancestors of any added/removed/re-areaed node),
  report `d_i = ‖pos_B(i) − pos_A(i)‖` in unit-root coordinates; the probe records **max** and
  **mean** `d_i`, plus the same for radius change.
- **Probe fixtures**: synthetic mutations of the real all-profile tree — add 1 module to a deep
  dir; add 10 modules to one package; delete a mid-size dir; grow one module's n_funcs by 5× —
  plus one historical pair (re-extract at an older commit if cheap; skip if not, recorded).
- **Output**: the NOTE records the numbers and **sets the threshold** the acceptance criterion
  uses (e.g. "mean outside-subtree displacement ≤ X for single-module insertion"). If circle
  packing's ripple makes every candidate threshold vacuous or unmeetable, that is the evidence
  that flips the D2 sub-choice to squarified treemap — the named decision point.

**Size**: 1 day. **Sequencing**: after 1.1–1.3; blocks P1 sign-off but not the start of WS2/WS3
(the spike and the exporter don't consume the threshold).

### Task 1.5 — Q7: refresh coupling + staleness surfacing

**Decision (Q7)**: layout generation is **appended to `extract.sh`** (after `visualize.py`,
*without* the `|| true` — a broken layout must fail the refresh loudly, per the "a stale map is a
distrusted map" lesson the ADR inherits) **and** remains a standalone script keyed to
`extraction_status.built_at`. Rationale: the two-step variant invites silent lag between graph
and layout — exactly the Sourcetrail failure mode; the integrated call costs seconds; the
standalone entry keeps layout iteration cheap during development without re-extracting.

**Deliverable**: the `extract.sh` edit; `cgq.py` staleness banner — when any query touches
`layout`/`edges_agg`/`activity` and the stored `snapshot` inputs disagree with the current
`extraction_status.built_at` set, print the existing-style `STALE:` banner (mirrors
`cgq.py`'s current stale/source_stale banners). **Size**: 0.5 day.

---

## WS2 — P2: viewer (parallel with WS3 after P1)

### Task 2.0 — the host toolchain: install script + environment bring-up (blocks 2.1)

**Implements**: **D10** (host-side viewer; the devcontainer stays headless — user-confirmed
permanent, now an ADR decision, not an environment accident).

- **Deliverable 1 — `viewer/pyproject.toml`**: the pinned dependency set (`fastplotlib`, `glfw`,
  `jupyter_rfb`, `jupyterlab`), uv-managed. Single source of truth for every environment that
  runs viewer code.
- **Deliverable 2 — `viewer/install_host.sh`** (D10's install script, the load-bearing piece):
  run **on the host** from a checkout, it (a) installs uv if absent, (b) creates/updates the
  pinned venv from `pyproject.toml`, (c) runs a **wgpu adapter probe** — enumerate adapters,
  render one offscreen frame — failing loudly with a diagnosis (no adapter / driver hint) rather
  than letting the spike discover a broken stack mid-measurement, and (d) prints the launch
  command for the spike/map. Idempotent and re-runnable after dependency bumps. Acceptance
  (mirrors the ADR's new D10 criterion): **on a fresh checkout on the host, the script alone
  produces an environment where the adapter probe passes and the spike launches** — no
  hand-installed prerequisites beyond a shell and network.
- **Data path**: the host viewer reads the same `tools/code-graph/.out/` tables through the
  shared workspace mount (OrbStack; macOS host) — no server, no sync step; the store is the
  interface (D10). The install script asserts the `.out/` tables it needs exist and prints the
  container-side command (`extract.sh --profile=all`) if not.
- **Container-side extras (opportunistic, never a gate)**: optionally probe lavapipe
  (`mesa-vulkan-drivers`) software rendering in-container for CI golden images. Works → golden
  images join Validation §5.4. Doesn't → container tests stay style-table-only. Either outcome
  is fine; the container is not the execution environment (D10).
- **Q5 decided: Jupyter-first for the canvas, on the host.** fastplotlib's notebook path is
  `jupyter_rfb` (verify on install — flagged assumption); marimo is not a Jupyter widget host,
  so the ADR's "marimo/Jupyter first" resolves to **Jupyter for the fastplotlib canvas**; the
  existing marimo notebooks keep their analysis role; Qt is deferred until P4 needs chrome.
  The host-side glfw native window is the recorded alternative if Jupyter adds untenable
  latency — measured at the spike, not debated.

**Size**: 1 day. **This task can start the moment P1's schema exists (even before the probe
NOTE lands).**

### Task 2.1 — the D7 spike, with the gate written down first

**Deliverable**: `viewer/spike_l0l2.py` + `NOTE-d7-spike-verdict.md`.
**Implements**: D7 (open — this is the decision experiment).

**Gate criteria (decided now, so the spike cannot be graded on vibes).** The spike **passes** iff,
**on the host machine, in the environment produced by `install_host.sh` and nothing else** (D10 —
a verdict from a hand-built env is invalid):

1. Renders the full all-profile L0–L2 scene: all L0/L1/L2 nodes + `edges_agg` line collections
   (both kinds, distinct styles).
2. Sustained pan/zoom at **≥ 30 fps** at L2 density (~1k module nodes + module-level edges).
3. Picking: click→node identity round-trip **< 100 ms**; hover tooltip shows module path.
4. LOD switching on camera-scale thresholds without visible re-upload stalls (> 1 dropped-frame
   hitch at threshold crossing fails).
5. Text: ≥ 200 simultaneous L2 labels without dropping below criterion 2 (labels may be
   decimated by zoom, but the L2 view must be labelable).
6. Runs end-to-end on the host from `.out/` tables through the shared mount, launched exactly as
   `install_host.sh` printed it (Jupyter canvas or host glfw).

**Timebox**: 3 working days. Timebox exhausted without all six = **fail** (the meta-decision's
convergence rule applied to spikes: a spike that keeps almost-passing is a fail signal).

**Fallback procedure on fail** (written before the spike, per the handoff): first fallback is
**datashader + panel** — server-rendered CPU raster, no GPU dependency at all (also erases the
2.0 environment problem); re-run criteria 1–4 with relaxed 3 (server round-trip picking
< 300 ms); text and LOD become HTML-layer concerns. If that fails interactivity, the web stack
(deck.gl/sigma.js) is the second fallback and is an **ADR amendment** (leaving Python is a cost
D7 explicitly prices), not a plan-level swap. The verdict NOTE records measurements against each
criterion either way.

**Size**: 3 days timeboxed.

### Task 2.2 — L0–L2 map proper (gate-conditional)

**Deliverable**: `viewer/map_view.py` (+ small helpers), consuming `layout.csv` + `edges_agg.csv`
through the same chdb access layer `cgq.py` uses (no parallel store surface — D1/D8).
**Implements**: D3 (LOD contract), D4 (honesty at the pixels).

- LOD thresholds on camera scale: L0 → L1 → L2 node/edge/label sets swapped from precomputed
  buffers (never re-aggregated at render time — D3 hard rule).
- **Edge rendering**: hierarchical bundling along the containment tree (D3). Implementation note:
  bundle control points are computable at build time from the layout tree — precompute polylines
  into the viewer's load step, keep the render loop dumb.
- **D4 rules, enforced as a single style table** (one function `style_for(kind, exactness,
  stale, incomplete)` with unit tests — this is what makes "honesty reaches the pixels"
  *reviewable as code*): `exact` solid; `approximate` visually distinct (dashed/desaturated);
  `incomplete=true` renders as **unknown** (distinct "unknown" treatment, never blank); stale
  snapshot ⇒ persistent on-canvas banner mirroring `cgq.py`'s banner text.
- Hover → module path + counts tooltip; click → open in real editor via `$EDITOR`/IDE URL
  (D3: L4 preview and anything in-canvas beyond it is out of scope).

**Verified by**: style-table unit tests (container-runnable); golden images if 2.0 Outcome A;
manual acceptance walk on the host against the acceptance sketch. **Size**: ~1 week.

---

## WS3 — P3: overlay foundations (parallel with WS2; only 3.5 needs P1)

### Task 3.1 — D9 exporter: `scripts/dst/export_trace.ail` + wrapper

**Deliverable**: the export script + `run_export_trace.sh`.
**Implements**: D9 in full (topology, format ownership, location, rejected-alternative posture).

- **One profile + one seed per invocation** (Q3 probe finding — hard requirement). Profile and
  seed arrive as arguments; the script builds the seeded world and runs the driver **exactly as
  `corpus_pr_dst.ail` does** (`generated_world(seed)` → `Session.run_v2_session_traced`,
  verified shape), then serializes the **returned** trace from the result — `ledger_trace` on
  `RunCompleted`, `partial_ledger_trace` on `RunFailed` (`dst_result.ail:95,:110`), with the
  failure case marked in the header. **Never the stdout `^{` stream** (emission-witness side —
  rejected in D9 with reasons; known trap).
- **Output**: `tools/code-graph/.out/traces/<profile>/<seed>.jsonl`, written **via the FS
  effect** — not stdout, which the wire `Trace` stream already pollutes during runs (Q3 probe:
  364 `^{` lines in a baseline run; a stdout-JSONL exporter would need fragile grep hygiene).
  One header line (seed, profile id + version — `driver_only_id`/`driver_only_version`-style
  exported accessors; generator version; program schema; AILANG version and motoko commit
  injected by the wrapper via `Env`), then one line per `LedgerRecord` with envelope fields
  `event_idx`, `record_key`, `seed` **outside** the payload object:
  - `WireRecord(e)` → payload is exactly `to_schema_v1(e)` (`phase_vocab.ail:817`), reused
    through its exported API; `record_key = "WireRecord:" ++ event_variant_id(e)`
    (`dst_event_vocabulary.ail:142`).
  - `CompactionStageRecord` → `{step, ext_id, outcome}`; `DecisionRecord` → `{step, decision}` —
    the overlay-owned v1 encodings D9 defines. Format version in the header
    (`overlay_trace_version: 1`).
- **Wrapper** copies the discovery target's caps verbatim
  (`--caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub`, `Makefile:391`) —
  the stale `--caps IO` in older targets is the known trap, budgeted not inherited.
- **StreamDelta hazard**: keyed on the *variant* (`event_variant_id`), never on wire names, so
  the two-wire-name variant (`reasoning_delta`/`thinking_delta`) is a non-issue by construction.

**Verified by**: run it at 2–3 seeds; assert (a) exactly one final `RunSummary` per D6.1 via the
file (parity with `has_exactly_one_final_run_summary` semantics), (b) every line's payload for
`WireRecord`s round-trips against the wire projection (the existing
`event_vocabulary_dst.ail` round-trip already guards projection drift upstream — the exporter
test only checks *its own* envelope), (c) re-running the same seed is byte-identical
(determinism). **Size**: 1.5–2 days.

### Task 3.2 — vocabulary export for the Python side

**Deliverable**: `scripts/dst/export_vocabulary.ail` → `.out/vocabulary.json` (34 rows:
`variant`, `wire_names`, `classification`, `reaches_trace_today`).
**Why**: the P3 validators need the vocabulary machine-readably without parsing AILANG source
with regexes (the grep pitfall found during grounding — a test fixture row shadows naive
counting). Same posture as D9: a new script over the exported pure `event_vocabulary()`.
**Verified by**: row count 34; the 8 known `reaches_trace_today:false` rows present.
**Size**: 0.5 day.

### Task 3.3 — the event-subject table + auxiliary maps

**Deliverable**: `overlay/event_subjects.py` — the **30 rows of the NOTE's table, transcribed
verbatim** (19 fixed / 10 payload_routed / 1 correlated, + `unattributed` fail-open) — plus the
two curated seed CSVs and the derived `tool_modules.csv`.
**Implements**: D5 (external static table; the answered Q1 — **not re-derived**, hard guardrail:
emitter ≠ subject, the table is the answer).

- Naming: **event-subject table** throughout (the D5 naming hazard —
  `dst_attribution_table.ail` is a different mechanism and is not touched or referenced as
  kin).
- Rules produce **subject sets**; `build_activity` fans out one row per subject (15 of 30 rows
  are multi-subject).
- **tool→module map** (required by every `payload_routed` rule): generated
  `.out/tool_modules.csv` from two sources — (a) the committed curated seed
  `data/native_tool_modules.csv` for the 7 native tools (`tool_catalog.tools()`,
  `tool_catalog.ail:76` — the catalog names tools but not handler modules, so this seed is
  curated; validated by code review against dispatch sites, recorded in the CSV's header
  comment); (b) extension tools mechanically: registry name → `pkg/sunholo/motoko_ext_<name>`
  (pattern verified against `registry_generated.ail:7-21`), each checked to exist in the
  all-profile `modules.csv` (detector, not prose).
- **`ErrorEvent.source` map**: committed `data/error_sources.csv` seeded with the two values
  found at HEAD (`system_prompt`, `agent_loop_v2`); unknown sources at activity-build time route
  to `unattributed` **and are counted in the build report** so growth is noticed, not swallowed.
- The **correlated** rule (`V2ToolDispatchComplete`): join to its `V2ToolDispatchStart` by `id`
  within the same trace during activity build; a Complete with no matching Start routes
  `unattributed` (fail-open, counted).
- **Validator** (in `validate_overlay.py`, vs `.out/vocabulary.json`): every LOGICAL variant with
  `reaches_trace_today: true` (26) + the 2 non-wire record kinds have a rule; the 2 gap variants
  (`ScratchpadResult`, `SessionSuspend`) have rules **written but unreachable today** — the
  validator asserts their presence so 009's D6.4 gap closure needs no table change (NOTE
  headline 6); DISPLAY-ONLY variants have none and the validator asserts they *don't* (a rule
  for an unreachable variant other than the two named gaps is a finding — two-sided check).

**Size**: 1.5–2 days.

### Task 3.4 — `activity` table build

**Deliverable**: `overlay/build_activity.py` → `.out/activity.csv` with the D1 schema
`activity(seed, event_idx, record_key, subject_id, rule_kind)`, rebuilt from all files under
`.out/traces/`.
**Implements**: D1 (schema, record-kind-aware `record_key`), D5 (rule_kind provenance in-band).

- Fixture note for its tests (known trap, planned around): DISPLAY-ONLY variants and the two gap
  variants **cannot appear in real traces** — test fixtures use reachable variants only; a
  synthetic-trace unit test may use gap variants precisely to assert they'd be handled if 009
  closes the gaps.
- `cgq.py` gets the `activity` schema entry + staleness story: activity is keyed to trace files,
  not to `extraction_status` — its banner compares against `layout.snapshot` only where joined
  (heat); raw activity queries carry a trace-file-count line in `meta` instead.

**Verified by**: `unattributed` rows present-not-dropped (ADR acceptance: "unattributed records
render as unattributed, never dropped"); multi-subject fan-out counts match rule arity on a
hand-checked fixture trace. **Size**: 1 day.

### Task 3.5 — static heat overlay (the only P3 task needing P1)

**Deliverable**: `overlay/render_heat.py` → `.out/heat/<profile>/<seed>.svg` — a static render of
`layout` circles colored by `groupby(subject)` counts over one trace. Matplotlib/svgwrite;
**deliberately no fastplotlib dependency**, which is what makes P3 ∥ P2 real (D6 view 1: "needs
no interactive viewer").
**Implements**: D6 view 1; D4 for the overlay (unattributed rendered as a distinct "unknown"
style, never omitted; modules with zero activity visually distinct from unattributed).

**Verified by**: the **heat-vs-SQL agreement check** in `validate_overlay.py` — the renderer's
per-subject totals are computed by the *same shared query function* the `q touched` CLI uses,
and the validator independently recomputes `SELECT subject_id, count(*) … GROUP BY subject_id`
via chdb and asserts equality (picture and query never disagree — ADR acceptance, checked not
promised). Movement direction: two different seeds' heat outputs must differ (guards a renderer
that ignores its input). **Size**: 1 day.

### Task 3.6 — D8: `cgq.py` query extensions

**Deliverable**: `q touched <seed>` (subjects + counts for one seed) and
`q divergence <seedA> <seedB>` (anti-join over `activity` — first index where the subject
sequences diverge + per-subject count diff), added to `named_query` (`cgq.py:223`). No new CLI
(D8 hard rule). `q coverage-gaps <corpus>` is **deferred to P6** with the corpus views — it
needs corpus-scale trace inventories that don't exist until P4–P6.
**Verified by**: `q touched` against the same fixture trace as 3.5's agreement check.
**Size**: 0.5–1 day.

---

## Open-decision schedule (the six the handoff requires)

| # | Decision | Decided | Where / by what evidence |
|---|----------|---------|--------------------------|
| Q4 | Layout area metric | **Now: function count** (`modules.n_funcs`, verified extracted) | Task 1.1; degeneracy check in the 1.4 probe NOTE; LOC is the recorded alternative |
| D2 sub | Circle packing vs treemap | **Now: circle packing** (D1 schema is circle-native) | Task 1.1; flips to treemap only if the 1.4 probe cannot calibrate a sane threshold — evidence recorded in the probe NOTE |
| P1 stability metric | Metric + threshold | **Metric now** (normalized displacement outside changed subtree, max+mean); **threshold by probe** | Task 1.4 → `NOTE-p1-stability-probe.md` |
| Q7 | Refresh coupling | **Now: in `extract.sh` + standalone**, snapshot-keyed staleness banner | Task 1.5; rationale: never-stale-map lesson |
| Q5 | Viewer host | **Now: Jupyter-first for the canvas, running on the host machine per ADR D10** (marimo isn't a Jupyter host — flagged assumption), Qt deferred to P4 | Task 2.0 verifies the jupyter_rfb assumption via the install script |
| D7 | Spike gate | **Criteria + timebox + fallback now** (six criteria, 3 days, datashader→web-stack ladder) | Task 2.1 → `NOTE-d7-spike-verdict.md` |

---

## Validation strategy (mirrors 002's oracle discipline)

1. **`edges_agg` rollup validator** (1.3): exact integer sum equality per level pair per kind;
   named findings, not booleans; runs at generation so no bad artifact ever lands.
2. **Layout determinism**: double-build byte-identity (sameness) **paired with** the probe's
   mutated-tree displacement (movement) — two-sided per the standing meta-decision.
3. **Stability**: measured displacement metric, threshold set by the 1.4 probe and recorded in a
   NOTE — a bound established, not asserted (the ADR's own framing).
4. **D4 honesty**: a single `style_for(kind, exactness, stale, incomplete)` function with unit
   tests asserting pairwise-distinct styles for exact/approximate/unknown — checkable without a
   GPU (this is the code-review-rule form); golden images added only if 2.0 lands software
   rendering (Outcome A). A task drawing `invokes` like `imports` fails a unit test, not a
   review comment.
5. **Attribution coverage**: rule coverage validated against the exported vocabulary
   (3.2 + 3.3) — 26 reachable LOGICAL + 2 record kinds have rules; the 2 gap rows exist;
   DISPLAY-ONLY rows don't; unknown `ErrorEvent.source`s counted, never dropped.
6. **Heat-vs-SQL agreement** (3.5): shared query function + independent recomputation; plus the
   different-seeds-differ movement check.
7. **Exporter determinism and D6.1 parity** (3.1): same-seed byte-identity; exactly one final
   `RunSummary` per completed-run file.

## Toolchain prerequisites (ADR D10 — the container/host split)

Verified and now decided (ADR D10): the devcontainer has no GPU access and will not get it — the
viewer is a **host-side program**. Consequences the plan enforces:

- P1 and P3 **never** touch GPU dependencies (chdb/matplotlib-only) and run entirely
  container-side; the split follows the layer boundary the store already provides.
- All viewer dependencies live in the pinned `viewer/pyproject.toml` and are installed **on the
  host** by `install_host.sh` (task 2.0) — the committed, idempotent install script the ADR now
  requires. The extractor's system-Python environment in the container is untouched.
- The host reads `.out/` through the shared workspace mount (OrbStack, macOS host → Metal via
  wgpu); no server or sync layer exists or is planned.
- The D7 spike and every later interactive milestone are only valid when launched from the
  script-produced environment — installability is itself an acceptance criterion (ADR
  acceptance sketch, D10 bullet).
- If the host's wgpu stack turns out unusable (the install script's adapter probe is the
  detector), D7 fails at criterion 6 and the datashader fallback (CPU-only, runnable anywhere)
  takes over — the plan remains executable end-to-end without any GPU.

## Outlook — P4–P6 (sequencing only) and the upstream ask

- **P4 replay scrubber**: needs P2 (interactive canvas) + P3 (`activity`). First real consumer of
  windowed aggregation / glow decay; also where the multi-subject *rendering* choice (split vs
  duplicate glow — a design choice the NOTE explicitly parked for P4) gets made, and where Qt
  chrome gets re-evaluated (Q5's deferred half).
- **P5 divergence view**: needs P4 + two exported runs of the same seed across code versions;
  `q divergence` (3.6) already gives the data answer; `ReplayMismatch` supplies the divergence
  index. Prerequisite: exporting the *same seed at two commits* — a small orchestration wrapper
  over 3.1, not new machinery.
- **P6 corpus views**: needs many-seed export orchestration (a loop over 3.1's
  one-seed-per-process invocations — the topology decision makes this embarrassingly parallel),
  `dst_profile_coverage` outputs, and the fault catalogue. This is where `q coverage-gaps`
  lands, and where declared-vs-performed gets its first corpus-scale render.
- **Standing upstream ask** (filed in the NOTE, restated here as the P7 gate): **streaming /
  incremental semantic-trace export** in AILANG — today `--emit-trace` at either tier buffers
  until exit and OOM-kills a full DST script (empirical, exit 137). Until it lands, everything
  semantic-trace-shaped (P7 attribution upgrade, L3 dynamic call grain, sub-event scrubbing)
  stays out of every plan, including this one. Secondary asks recorded with it: local-name
  qualification; lambda/recursion frame naming.

## Gaps found (the freshness test's output)

1. **"CI validator" had no home — there is no code-graph CI at all.** The ADR's acceptance
   sketch says "checked by a validator in CI"; the only workflows are `dst-corpora.yml` and
   `verify-extensions.yml`, and neither touches `tools/code-graph`. Decided here:
   generation-time gating (validator inside the builder) + a standalone CLI + a proposed
   fixture mini-tree for future workflow adoption (task 1.3). Whether a dedicated GitHub
   workflow is added is left to P1 execution — flagged, not silently decided.
2. **The devcontainer cannot run the D7 spike at all — and that was in no document.** Found
   during grounding (no `/dev/dri`, no Vulkan ICD, nothing installed) and user-confirmed as
   permanent: the container will not get GPU access. **Resolved by ADR amendment same day**:
   D10 makes the viewer a host-side program with a committed install script
   (`install_host.sh`, task 2.0) as a first-class deliverable and an acceptance criterion.
   Residual unknown: whether the *host's* wgpu stack renders acceptably — detected by the
   install script's adapter probe before the spike, not during it.
3. **Q5 as posed ("marimo/Jupyter first") conflates two hosts.** fastplotlib's notebook path is
   a Jupyter widget (`jupyter_rfb`); marimo is not a Jupyter host, and marimo isn't even
   installed in this container despite the notebooks directory. Decided: Jupyter for the canvas,
   marimo keeps analysis notebooks. The jupyter_rfb claim is model-knowledge — verified at 2.0.
4. **Handoff anchor correction**: `event_variant_id` is exported from
   `dst_event_vocabulary.ail:142`, not `phase_vocab.ail` (the handoff/ADR list it among the
   exporter's imports without a module; the D9 task above imports it from the right place).
   Related grep hazard: a vocabulary-shaped **test fixture** at `dst_event_vocabulary.ail:807`
   makes naive `grep -c` counts wrong by one — which is exactly why task 3.2 exports the
   vocabulary through its API instead of parsing source.
5. **Native tool → handler module has no machine-readable source.** `tool_catalog.tools()`
   yields names and schemas, not handler modules; the 7-row native seed map must be curated
   (task 3.3) and is validated only by review against dispatch sites. Small, but it is the one
   place in P3 where a human-maintained mapping can silently rot; the build report's
   unknown-name counter is the detector.
6. **`ErrorEvent.source` value set is nowhere enumerated.** Construction-site grep at HEAD finds
   two values (`system_prompt`, `agent_loop_v2`); nothing guarantees closure. Fail-open to
   `unattributed` + counted in the build report (task 3.3). If 009 ever wants a closed set,
   that's a vocabulary-side conversation this project doesn't start (read-only consumer).
7. **The exporter's profile-generality is assumed, not proven.** The verified seed-run path is
   `corpus_pr_dst`'s (`generated_world(seed)` → `run_v2_session_traced`); whether every profile
   the exporter should accept runs through an identical shape is resolved at 3.1
   implementation. If some profile needs different wiring, the exporter starts with the
   generated-corpus path and records the limitation in its header — it does not grow
   per-profile forks silently.
8. **Stale doc detail (trivial)**: `extract.sh --help` omits `packages` from the `all` profile
   description; `extractor/config.py:15` includes it. Worth a one-line doc fix in passing during
   task 1.5's `extract.sh` edit.
9. **009 notification residue (from the ADR, restated as an action)**: D9 creates a new
   read-only consumer of trace semantics; the ADR says 009 "should be informed". Concrete form:
   one line in 010's first PR description cross-referencing 009's ADR, plus a NOTE pointer —
   assigned to task 3.1's landing, so it doesn't evaporate.

## Suggested implementation order

1. **P1 sequence**: fresh `--profile=all` extraction → 1.1 + 1.2 (one builder) → 1.3 validator →
   1.5 coupling/banners → 1.4 probe + NOTE. P1 sign-off = validator green + probe NOTE's
   threshold recorded.
2. **Fork into two tracks** (explicitly parallel, per the ADR's P3-depends-on-P1-only):
   - **Track A (WS2)**: 2.0 toolchain probe → 2.1 spike (timeboxed, verdict NOTE) → gate →
     2.2 map or fallback ladder.
   - **Track B (WS3)**: 3.2 vocabulary export → 3.1 exporter → 3.3 subject table + aux maps →
     3.4 activity → 3.5 heat (first P1-dependent step) → 3.6 cgq queries.
3. Tracks re-join at P4 (scrubber = viewer + activity), which is outlook-only here.

Rough total: P1 ≈ 5 days; Track A ≈ 5–8 days (gate-dependent); Track B ≈ 6 days. Tracks A and B
are independent enough for separate sessions/PRs without coordination beyond P1's landed tables.
