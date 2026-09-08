# Handoff: implement the simulation-visualization plan (P1–P3)

Audience: a fresh agent session executing `PLAN-map-and-overlay-p1-p3.md` (this directory).
The plan survived three review rounds (findings 7 → 9 → 1, converged 2026-08-08); every
`file:line` anchor in it was exact-verified at HEAD `a816bcd`. Your job is to build what it
says, in the order it says, and to route any disagreement into findings — not silent redesign.

## Mission

Execute the plan's three workstreams:

1. **WS1 (P1)** — the layout projections. Start here, and start with a fresh
   `tools/code-graph/extract.sh --profile=all` (the current `.out/` is core-profile and stale).
   Build `build_layout.py` + `validate_layout.py` together (the builder self-validates from its
   first run), then the Q7 coupling, then the stability probe + its NOTE.
2. **Then fork into two independent tracks** — do not serialize them:
   - **Track A (WS2/P2)**: 2.0 host toolchain (`pyproject.toml` + `install_host.sh`) → 2.1
     fastplotlib spike against the six written gate criteria → 2.2 map (or the fallback ladder).
     2.0 needs nothing from P1 and can start immediately.
   - **Track B (WS3/P3)**: 3.2 vocabulary export → 3.1 D9 exporter → 3.3 event-subject table +
     aux maps → 3.4 activity → 3.5 heat (the first P1-dependent step) → 3.6 cgq queries.

Tracks A and B are sized for separate sessions/PRs. If you are one session, finish P1, then
prefer Track B first (fully container-side, no user coordination needed) and interleave Track A
around host-run round-trips (see "The host boundary" below).

## Reading order

1. `PLAN-map-and-overlay-p1-p3.md` — **normative for you.** Task-level deliverables, pinned
   mechanisms, validation obligations, the open-decision schedule, and 10 recorded gaps.
2. `ADR-001-zoomable-map-and-trace-overlay.md` — the decisions (D1–D10) the plan implements.
   Status is *Scoping draft*: if you find a Dn wrong, that is a finding + proposed amendment,
   never a quiet workaround.
3. `NOTE-q1-event-subject-pass.md` — the 30-row subject table. Task 3.3 **transcribes it
   verbatim**; you are not re-deriving subjects.
4. `tools/code-graph/AGENTS.md` — store contract: profiles, staleness metadata, `func_slug`
   join rules, approximation discipline.
5. Skim `../006_compactor_strategy/PLAN-compactor-strategy.md` §7 and
   `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
   — the validation style you're expected to keep (detectors, two-sided assertions).

## Decisions already made — do not re-open

Q4 (area = `modules.n_funcs`), D2 sub-choice (circle packing), Q7 (layout in `extract.sh` +
standalone, snapshot-keyed banner), Q5 (**standalone fastplotlib app** — native glfw window on
the host, imgui via `fastplotlib[imgui]` for GUI inputs, no notebook hosting, no Qt; a direct
user decision), the stability metric (displacement outside the expected-motion zone), and the
D7 gate (six criteria, 3-day timebox, datashader → web-stack fallback ladder) are **decided
with recorded rationale**.
Each has a named decision point where evidence can flip it (e.g. the 1.4 probe NOTE flips
packing → treemap; the spike verdict NOTE triggers the fallback ladder). Flip only at those
points, with the evidence written into the NOTE. Q1–Q3 were answered empirically before the
plan; re-opening them requires new evidence in a Gaps addendum, nothing less.

## Hard guardrails (the plan is wrong if you catch yourself violating one)

- **No edits under `src/core/`, `packages/`, or existing `scripts/dst/` files.** New scripts
  only (`export_trace.ail`, `run_export_trace.sh`, `export_vocabulary.ail`), built on exported
  pure functions. The blast-radius table in the plan is exhaustive — a file not on it is a
  scope question, stop and record it.
- **No force-directed layout. No render-time edge aggregation. No new CLI** (extend
  `cgq.py:223` `named_query`). **No driver-emitted subject tags** (rejected in ADR D5).
- **The exporter reads the returned trace** (`ledger_trace`/`partial_ledger_trace`,
  `dst_result.ail:95,:110`), **never the stdout `^{` stream**, and writes **via FS**
  (`std/fs.writeFileResult` + `mkdirAllResult`), never stdout.
- **One profile + one seed per exporter invocation.** Non-negotiable (Q3 probe: OOM + shared
  `session_id` topology).
- **D4 honesty is a unit-tested style table**, not a convention: one
  `style_for(kind, exactness, stale, incomplete)` function; approximate ≠ exact styles asserted
  pairwise-distinct; `incomplete=true` renders as *unknown*.
- **No artifact is written that fails its validator** — `validate_layout.py` runs inside the
  builder, `validate_overlay.py` gates the overlay outputs.

## The host boundary (D10) — your workflow constraint

You are working **inside the devcontainer, which has no GPU and never will** (ADR D10). You can
build and unit-test everything in Track B and all of Track A's *code*, but you **cannot execute
`install_host.sh`, the wgpu adapter probe, or the spike yourself** — those run on the user's
host machine (macOS/OrbStack; the workspace mount is shared, so `.out/` needs no sync).

Work with that, don't fight it:

1. Write `install_host.sh` so its output is self-reporting: the adapter probe and the spike
   print structured results (fps, picking latency, label count) to a file under
   `.agent/projects/010_simulation_visualization/` or to stdout the user can paste back.
2. When a host run is needed, hand the user **one command** and say exactly what output you
   need back. Batch host asks; each round-trip is expensive.
3. Grade the D7 gate only from script-produced host output — a hand-run or partial result is
   not a verdict. Record whatever comes back, pass or fail, in `NOTE-d7-spike-verdict.md`.
4. The container-side lavapipe extra is opportunistic. If `mesa-vulkan-drivers` + offscreen wgpu
   works in-container, add golden images; if not, drop it without ceremony. It is never a gate.

## Traps — each already cost a finding; do not rediscover them

- **`dst_event_vocabulary.ail:807` is a test fixture**, not a vocabulary row. Any count you
  need comes from the exported `event_vocabulary()` (`:238`) via task 3.2's JSON, never from
  grepping source. Real counts: 28 LOGICAL + 6 DISPLAY-ONLY; 8 real `reaches_trace_today:false`.
- **`generated_world` / `generated_world_at` are script-local** in `corpus_pr_dst.ail`
  (`:309,:313`) — **replicate** the wiring from `dst_generator` exports; you cannot import it.
- **`activity` is built per profile** (`build_activity.py --profile`), because the D1 schema has
  no profile/run column — same seed under two profiles collides. Cross-profile and
  same-seed-two-versions both wait on Gap 10's resolution at P5; `q divergence` covers the
  two-seed case only, and its docstring should say so.
- **Emitter ≠ subject.** The NOTE's table is the answer; construction sites are evidence only.
- **Key on `event_variant_id` (exported from `dst_event_vocabulary.ail:142`, *not*
  `phase_vocab`), never on wire names** — `StreamDelta` has two.
- **DISPLAY-ONLY variants and the two gap rows (`ScratchpadResult`, `SessionSuspend`) never
  appear in real traces** — don't build heat/activity test fixtures from them; synthetic-trace
  unit tests may use the gap rows deliberately.
- **Caps**: copy the Makefile `discovery` target's set verbatim
  (`--caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub`, `Makefile:391`).
  Several older targets still show `--caps IO` — stale, don't inherit.
- **JSON encoding** is `std/json.encode` — the idiom is `encode(to_schema_v1(e))`, already used
  in `phase_vocab.ail:1202`'s golden tests.
- **`extract.sh --help` is stale** (omits `packages` from the `all` profile;
  `extractor/config.py:15` is truth). Fix the help text in passing during task 1.5 (Gap 8).
- **The level mapping for variable-depth paths is pinned in task 1.1** (prefix classes; shallow
  modules are their own aggregates; deep dirs are containers with no `edges_agg` rows). Follow
  it exactly — the validator's coverage rule assumes it.

## Discipline

- **Re-verify anchors at your HEAD before leaning on them.** The plan was grounded at `a816bcd`
  on 2026-08-08; this repo moves fast (a concurrent mutant overwrote a fix during WI-D19). A
  drifted anchor is a finding for the plan doc, not something to absorb silently.
- **Findings go in writing.** Anything the plan didn't anticipate: append to the plan's Gaps
  section (numbered, with evidence) or the relevant NOTE. The two probe NOTEs
  (`NOTE-p1-stability-probe.md`, `NOTE-d7-spike-verdict.md`) are deliverables, not
  documentation debt — P1 sign-off and the D7 verdict are *defined* as those NOTEs existing
  with numbers in them.
- **Keep assertions two-sided** (the meta-decision): determinism byte-identity is paired with
  the probe's mutated-tree movement; the subject-table validator checks both that required
  rules exist and that forbidden ones don't; heat-vs-SQL equality is paired with
  different-seeds-differ. When you add a check, name the direction it tests and add its
  opposite.
- **On landing the exporter (task 3.1)**: include the 009 cross-reference line in the PR
  description (Gap 9 — 009 gains a new read-only consumer of trace semantics; they should hear
  it from us).
- Commit style: follow the repo's existing `feat(010)`/`docs(010)` convention; keep the plan's
  task numbers in commit messages so the review trail maps back.

## Definition of done, per phase

- **P1**: `layout.csv` + `edges_agg.csv` generated for the all profile; all five validator
  rules green; `extract.sh` integration + staleness banner live; probe NOTE written with the
  calibrated threshold (or the recorded treemap flip).
- **P2**: install script meets its acceptance (fresh host checkout → script alone → probe
  passes → spike launches); spike verdict NOTE with measurements against all six criteria;
  then either the L0–L2 map with the style-table tests green, or the fallback ladder engaged
  and recorded.
- **P3**: exporter deterministic at repeated seeds with D6.1 parity on completed runs;
  vocabulary JSON + subject-table coverage validator green (26+2 rules present, gap rows
  present, DISPLAY-ONLY absent); per-profile `activity.csv` with unattributed preserved; heat
  SVG whose totals the SQL agreement check confirms; `q touched` / `q divergence` answering
  from the same tables.
