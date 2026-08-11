# NOTE — D7 spike verdict: fastplotlib passes the gate

Date: 2026-08-08
Status: **Decision record. D7 is decided: fastplotlib.** Closes ADR-001 (010) D7
(*open — leading candidate, not committed*) and the plan's task 2.1. The fallback
ladder (datashader + panel → web stack) is **not** engaged and is retired to a
contingency, not a plan.
Environment: macOS `Darwin arm64 25.5.0`, Apple M1 Pro, Metal backend, Python
3.13.12 — produced entirely by `tools/code-graph/viewer/install_host.sh` from a
fresh checkout, which is itself an acceptance criterion (ADR D10).
Evidence: `host-probe-report.json`, `host-spike-report-{auto-real,auto-stress1000,interactive-real}.json`,
combined by `spike_l0l2.py --summarize` into `host-spike-verdict.json`.

## Verdict

**PASS — six of six criteria, none unmeasured.**

| # | Criterion | Verdict | Measurement |
|---|---|---|---|
| 1 | Full L0–L2 scene, both edge kinds in distinct styles | **pass** | 4 / 61 / 232 nodes, 1150 edge segments; `kinds_visually_distinct: true` |
| 2 | Sustained pan/zoom ≥ 30 fps at L2 density | **pass** | real scene **56.29 median / 50.79 p5**; stress **57.73 / 55.64** |
| 3 | Click → identity < 100 ms; hover shows module path | **pass** | **0.005 ms max** over 12 real pointer events; tooltip returned `packages/motoko-ext-a2a/config` |
| 4 | LOD switching with ≤ 1 dropped-frame hitch | **pass** | real: 4 crossings, **0 hitches** (worst 19.53 ms); stress: 4 crossings, **1 hitch** (worst 85.66 ms) |
| 5 | ≥ 200 simultaneous L2 labels without dropping below (2) | **pass** | 232 real / **1160** at stress, both above 30 fps |
| 6 | Standalone glfw window, host-side, from the shared-mount store | **pass** | all three runs; launched only via `install_host.sh`'s printed command |

**Headroom is the story, not the margin.** 50.79 fps at the *fifth percentile*
against a 30 fps floor, and the 5×-density stress run was **faster** than the
real scene (55.64 vs 50.79 p5) — the scene is nowhere near the GPU's limit at
this scale, so the corpus-scale overlay D7 was really chosen for has room.

## Scale note, recorded deliberately

Criterion 2 names "~1k module nodes". The all profile has **225**, so the real
scene is 4× *below* the density the criterion assumes. `--stress 1000` replicates
the scene to 1160 L2 nodes / 5750 edge segments so the criterion could be graded
at the density it actually names. **Stress numbers are synthetic and are recorded
beside the real ones, never substituted for them** — both appear in the table
above, and the combined verdict cites both.

## Timebox

3 working days budgeted. Spent: one session, four host runs. The meta-decision's
convergence rule ("a spike that keeps almost-passing is a fail signal") did not
trigger — the three failed runs failed on *instrumentation bugs that the
instrumentation itself caught*, and each fix was a one-shot, not a re-negotiation
of the criteria.

## The failed runs are the interesting part

The gate was designed so that a broken measurement cannot read as a pass. It was
tested against that four times, and reported honestly each time. All four
failures were in **our** code; the host stack was healthy from the first run.

| Run | Reported | Actual cause |
|---|---|---|
| 1 | probe `fail` | `Figure.show()` does not render on an offscreen canvas — it registers `_render` and returns unless `RTD_BUILD=1` (`fastplotlib/layouts/_figure.py:679-693`), so `snapshot()` hit a `None` target texture. Fixed by forcing `canvas.draw()`, which also returns the frame — so "blank frame" became distinguishable from "exception". |
| 2 | spike `pass` (**inadmissible**) | Criterion 3 was graded from the synthetic fallback: 0.16 ms for our own identity lookup, `hover_tooltip_sample: null`, no pointer event ever fired. The gate cleared "click → identity round trip" having proven neither half. Also, the `--stress` run overwrote the real-scene report, destroying numbers the plan forbids substituting. |
| 3 | criterion 3 `not-measured` | Real bug: `pygfx` materials default to `pick_write=False` (`pygfx/materials/_base.py:161`), and fastplotlib sets it for line/text/image but **not** scatter — our pick targets emitted no events at all. Compounded: markers were 6 *screen* pixels at circle centres while the eye sees the ring, so a user clicking a module hit nothing. |
| 4 | **pass** | — |

**Run 2 is the one worth remembering.** It reported `overall: pass` on all six
criteria and was wrong, because a criterion graded from a measurement that does
not measure it is indistinguishable from a real pass *in the output*. The
existing guard (`test_a_spike_that_measured_nothing_does_not_pass`) covered the
empty case and left the plausible-looking-but-hollow case open. Synthetic picks
now grade `not-measured`, never `pass`; a real pick without a hover sample
`fail`s, because the tooltip is half the criterion and not a nicety.

**Two process rules earned here, both now in the plan (Gaps 17–18):**

1. When a deliverable can only execute across an expensive boundary, read the
   pinned dependency's source *before* the first ask, not after the first
   failure. Runs 1 and 3 were both diagnosable from the wheels, offline.
2. A detector that cannot say *why* it is empty is half a detector. Run 3's
   report could not distinguish "the handler never fired" from "it fired and
   resolved nothing", and telling those apart cost a whole round-trip.
   `pointer_events_received` is now counted before any resolution is attempted.

## Why the combination is script-produced

The gate spans two run *shapes* by construction: the scripted sweep owns
throughput (a human's idle gaps land in frame timings and read as stalls that
never happened), and only an interactive session can grade a real click/hover
round trip. So `--summarize` combines every report into one verdict — a criterion
passes iff some run graded it `pass` and none graded it `fail`, and anything
still `not-measured` leaves the gate **open** rather than silently absent.
Eyeballing three JSON files and declaring a pass is precisely the vibes-grading
the written criteria exist to prevent.

## What this unblocks and what it does not

- **Unblocked: task 2.2**, the L0–L2 map proper. The spike is disposable by
  design; what survives it is this verdict and the wiring facts below.
- **Not settled here**: bundled edge rendering, click-to-editor, and the
  on-canvas stale banner are 2.2's work — the spike drew straight edges, which
  criterion 1 permits and D3 does not.
- **`chdb` installs cleanly on macOS arm64**, so D8's "the viewer and the agent
  read the same tables through the same layer" is available to 2.2 rather than
  aspirational. The spike deliberately read CSVs directly to keep the gate about
  rendering; 2.2 should move to the shared layer.

### Wiring facts 2.2 must inherit (each cost a round-trip to learn)

- Scatter graphics need `world_object.material.pick_write = True` set explicitly;
  fastplotlib does not set it for scatter.
- Pick targets must be **world-space sized** to the node, or the visible circle
  and the clickable region are different objects.
- `pick_info` carries `vertex_index`, **not** a world position
  (`pygfx/objects/_more.py:148`); with vertex order equal to the node-id list,
  identity resolution is an exact O(1) lookup rather than a hit test.
- Depth must be staggered by LOD level so a zoomed-in module wins the pick over
  the container circle it sits inside.
- `fastplotlib[imgui]==0.6.1` → `wgpu[imgui]` → `imgui-bundle` is real at the
  pinned version, so Q5's imgui chrome is available when P4's scrubber needs it.

## Retired risks

- ADR Gap 2's residual unknown — "whether the *host's* wgpu stack renders
  acceptably" — is **closed**: one Metal adapter, a real offscreen frame
  (145,563 non-zero pixels), and 56 fps sustained.
- D7's "against" column: *young library* is not disproven, but it is no longer
  speculative — the failure modes met in practice were undocumented defaults
  (`pick_write`) and an offscreen path that needs an explicit draw, both found by
  reading source and both one-line fixes. *Weak large-volume text* was not
  reproduced at 1160 labels; D3's L4 punt still stands as the mitigation for
  document-scale text, which this did not test.
