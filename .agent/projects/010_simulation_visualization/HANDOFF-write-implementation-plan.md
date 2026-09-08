# Handoff: write the simulation-visualization implementation plan

Audience: a fresh agent session. You are deliberately fresh — see
`../004_phase_core_refactor/NOTE-plan-authoring-session-choice.md`. Freshness is a test: **if you
cannot plan this from the ADR + the notes + the code alone, there is a gap — record it in a
"gaps found" section of the plan, don't guess around it.**

## Mission

Write `PLAN-map-and-overlay-p1-p3.md` in this directory (`010_simulation_visualization/`): the
implementation plan for phases **P1–P3** of `ADR-001-zoomable-map-and-trace-overlay.md` —

1. **P1 — layout projections**: deterministic containment layout (`layout` table) and precomputed
   LOD edge aggregation (`edges_agg`) over the existing `ailang-graph` store, plus the CI validator
   for the aggregation invariant.
2. **P2 — viewer**: the D7 spike (fastplotlib rendering the full L0–L2 map with pan/zoom + picking),
   the go/no-go gate against the named fallbacks, then the L0–L2 map proper: LOD thresholds, edge
   bundling, hover/click-to-editor.
3. **P3 — overlay foundations**: the D9 export script, the 30-key event-subject table with its
   tool→module auxiliary map, the `activity` table build, the static heat overlay, and the `cgq.py`
   query extensions (D8).

P4–P6 (scrubber, divergence, corpus views) get an **outlook section only** — sequencing and open
prerequisites, no task breakdown. P7 and everything upstream-gated (semantic-trace attribution) is
out of the plan entirely; it is deferred in the ADR and the gate is external (streaming trace
export upstream).

Do NOT start implementing. Plan only.

Note: P3 depends on P1 but **not** on P2 (the heat overlay renders statically over `layout`; the
ADR says so explicitly). Plan P2 and P3 as parallel tracks after P1 — do not serialize them out of
habit.

## Hard scope guardrails (read before anything else)

Any plan that violates one of these is wrong:

- **No changes to 009's surfaces.** This project is a *read-only consumer* of the ledger trace. No
  edits to the event vocabulary, the wire projection, `LedgerRecord`, the drivers, or any
  `src/core/dst_*` / `src/core/phase_vocab.ail` code. The D9 exporter is a **new script** built on
  exported pure functions only (`to_schema_v1`, `event_variant_id`, record pattern-matching).
  Driver-emitted subject tags are **rejected** in the ADR (D5) — do not resurrect them.
- **No force-directed layout, anywhere** (ADR D2). Containment + determinism are hard requirements.
- **No in-canvas code editing/rendering** beyond L4's static preview (ADR D3). Click-through opens
  the real editor.
- **Approximation honesty reaches the pixels** (ADR D4): approximate edges render visually distinct
  from exact ones; `incomplete=true` renders as *unknown*. If a plan task draws `invokes` edges the
  same as `imports` edges, the task is mis-specified.
- **Store discipline** (ADR D1/D8): new tables land beside the existing CSVs in
  `tools/code-graph/.out/`; agent access extends `cgq.py`; **no new CLI**, no parallel store. The
  map consumes the **`all` profile** (`--profile=all`), not the default `core`.
- **Exporter topology** (ADR D9, forced by the Q3 probe): one profile + one seed per invocation.
- **Do not re-open the answered questions.** Q1–Q3 were answered empirically on 2026-08-08 (see
  reading order). The 30-key table shape, the rule kinds, the export format ownership, and the
  one-seed-per-process topology are decided. If you believe one is wrong, that is a finding for the
  gaps section with evidence — not a silent re-decision.

## Decisions the plan MUST make (they are open on purpose)

The ADR leaves these to plan/spike time. The plan either decides them with a stated rationale or
defines the experiment that decides them, with a decision point in the task sequence:

1. **Q4 — layout area metric**: function count (ADR-leading) vs LOC vs exports. `funcs.csv` and
   `source_chunks.csv` carry what's needed either way.
2. **Q5 — viewer host**: marimo/Jupyter first vs Qt. marimo is already in use under
   `tools/code-graph/notebooks/`. The ADR leans notebook-first for P2–P4.
3. **Q7 — refresh coupling**: does `extract.sh` grow layout generation, or is layout a separate
   step keyed to `extraction_status.built_at`?
4. **D2 sub-choice**: circle packing vs squarified treemap.
5. **The P1 stability metric**: the ADR's acceptance sketch requires a *measured* displacement
   metric with a threshold calibrated by a P1 probe — the plan must specify the metric, the probe,
   and where the number is recorded.
6. **D7 gate criteria**: what, concretely, makes the fastplotlib spike a pass? Name the criteria
   (e.g., full L0–L2 render at interactive framerates on the dev machine, picking latency, text
   labels at L2 density) and the fallback procedure (datashader+panel, or web stack) if it fails.

## Reading order

1. `ADR-001-zoomable-map-and-trace-overlay.md` (this directory) — **normative**. D1–D9 are the
   decisions; the acceptance sketch is your acceptance-criteria seed; Q4/Q5/Q7 are your open
   decisions. Note the status is *Scoping draft* — your plan should state that it implements the
   draft's decisions and that plan acceptance is contingent on the ADR graduating.
2. `NOTE-q1-event-subject-pass.md` (this directory) — the settled 30-row subject table (P3 builds
   exactly this), the rule kinds, the tool→module auxiliary map requirement, and the **Q3 probe
   results** (topology, the OOM kill, the stdout wire stream and why it was rejected).
3. `.agent/research/simulation_visualization/zoomable_map_and_simulation_overlay.md` — background
   and argument; not normative where it disagrees with the ADR (the ADR corrected it twice).
4. The substrate (re-verify at HEAD — see discipline below):
   - `tools/code-graph/AGENTS.md` — the `ailang-graph` contract: profiles, staleness metadata,
     `cgq.py` query surface, the join rules (`func_slug`, not `chunk_slug`), and the
     "approximate ≠ compiler-derived fact" discipline the map inherits.
   - `tools/code-graph/extract.sh`, `extractor/`, `query/cgq.py`, `.out/` — what exists; your P1
     tables sit beside these CSVs.
   - `src/core/phase_vocab.ail` — `LedgerRecord` (:594), `ledger_append` (:604),
     `to_schema_v1` (:817), `StepDecision` (:448), the checkpoint seam (:263). Line numbers
     recorded 2026-08-08.
   - `src/core/dst_result.ail` — run results carry `ledger_trace` (:95) / `partial_ledger_trace`
     (:110); this is what the D9 exporter serializes.
   - `src/core/dst_event_vocabulary.ail` — the 34 rows, `reaches_trace_today`, and the payload
     schemas the `payload_routed` rules read.
   - One DST script end-to-end for the exporter's shape — `scripts/dst/driver_only_dst.ail` or
     `scripts/dst/discovery_dst.ail`, plus the Makefile DST targets for invocation patterns.
     **Trap**: the Makefile shows `--caps IO`, but runs now require `--caps IO,Trace` (verified
     2026-08-08); budget for that discrepancy, don't inherit it.
5. `../002_code_graph/ADR-002-ailang-code-graph-architecture.md` — for the acceptance/validation
   style this project family uses (oracles, labeled approximations, staleness banners), which your
   plan's validation tasks should mirror.

## Known traps (each cost us a finding already — do not rediscover them)

- **Emitter ≠ subject.** 26 of 28 event variants are constructed in `session.ail`/`phase_vocab.ail`
  regardless of subject. The subject table in the NOTE is the answer; do not re-derive subjects
  from construction sites.
- **The stdout `^{` stream is not the returned trace.** It is the emission-witness side (a `Trace`
  effect). D9 rejected it with reasons. The exporter reads the *returned* `ledger_trace`.
- **DISPLAY-ONLY variants and the two gaps never appear in the overlay's input.** All 6
  DISPLAY-ONLY rows plus `ScratchpadResult` and `SessionSuspend` have `reaches_trace_today: false`.
  Consequence for testing: a heat-overlay test can't use those variants as fixtures.
- **`StreamDelta` has two wire names** (`reasoning_delta`/`thinking_delta`, payload-dependent). Any
  exporter/table code keyed on wire names must handle it; keying on the *variant* avoids the issue.
- **`phase_vocab` is not projection-only** — it owns the checkpoint seam. The NOTE records this
  correction; don't reintroduce the broken heuristic.
- **Semantic tracing OOM-kills full DST scripts** (both tiers, buffered-until-exit). Nothing in
  P1–P3 needs semantic traces; if a plan task depends on them, the task is out of scope.
- **`edges_agg` weights must be exact sums of children** (D3 invariant) and must be precomputed —
  a render-time aggregation task is mis-specified by definition.

## What the plan must contain

Follow the shape of `../006_compactor_strategy/PLAN-compactor-strategy.md` (workstreams → ordered
tasks with file-level touch lists → validation → risks):

1. **Workstreams** mapped to P1 / P2 / P3, with the P2∥P3 parallelism explicit.
2. **Per task**: deliverable files (concrete paths), the decision or invariant it implements
   (cite `ADR D<n>`), how it is verified, and rough size.
3. **The open-decision schedule** — where in the sequence each item from "Decisions the plan MUST
   make" gets decided, and by what evidence.
4. **Validation strategy**: the `edges_agg` CI validator; layout determinism (byte-identical at
   same commit) and the stability probe; the heat-vs-SQL agreement check (picture and query never
   disagree — ADR acceptance); the D4 honesty check (golden image or code review rule).
5. **Toolchain prerequisites**: fastplotlib install/GPU requirements in this devcontainer for the
   P2 spike — if the environment can't run wgpu, the spike design must say how it will be run
   (host machine? fallback first?). This is a real unknown; plan it, don't assume it.
6. **Outlook** for P4–P6 (sequencing only) and the standing upstream ask (streaming trace export)
   with what it unblocks (P7 semantic-trace attribution).
7. **Gaps found** — anything the ADR + notes + code did not let you decide. An empty section is a
   claim, not a default.

## Discipline

- **Re-verify every code fact at HEAD before citing it.** Line numbers above were recorded
  2026-08-08 on branch `arniwesth/mot-82-...`; the repo moves fast (a concurrent mutant overwrote
  a fix during WI-D19 — that class of drift is normal here). A plan that cites a stale line is a
  plan that gets reviewed against the wrong code.
- **Convergence over completeness theater**: state what you verified and what you assumed,
  distinctly. The project's meta-decision on review loops
  (`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`)
  applies to plans too: prefer a checkable invariant over a prose promise wherever one exists.
- The ADR qualifies foreign decisions as `009/Dn`; keep that convention in the plan.
