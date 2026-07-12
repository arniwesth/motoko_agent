# Architecture & DST diagrams

Diagrams of the phase-oriented core delivered by ADR-001 / ADR-002 (post Phase C /
WI-C6). Each is a Mermaid `.mmd` source with its rendered `.svg` alongside. Edges are
grounded in the code-graph import graph (`tools/code-graph/.out/imports.csv`) plus the
`session → test/stub_step` provider seam the core profile omits.

| File | What it shows |
|------|---------------|
| `new-architecture` | Live module architecture, grouped by ADR-001 role: imperative shell (driver) · pure functional core · phases · ports seam · extensions · ledger. |
| `dst-capabilities` | The DST pipeline: one production code path, swappable ports (live vs scripted/fake), one trace that pure invariants + L1 scenarios assert over. |
| `dst-status` | Same DST pipeline as a **status map** — colour = implementation status (green landed · amber-dashed partial · gray-dashed designed), verified against `src/core` + `scripts/phase_c_l1_scenarios.ail` on 2026-07-06. **Superseded 2026-07-12**: everything in its "designed" band has landed; the current as-built map is `../../007_dst_consolidation/mmd/dst-as-built.svg`, documented in `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`. |
| `abi-v3-rollout-implemented` | ABI v3 rollout implemented on 2026-07-07: operator decisions, durable `packages/` path deps, core artifact/telemetry threading, migrated compaction extensions, and the `make run` resolution path. Grounded with `tools/code-graph/extract.sh --profile=all` after enabling `packages/`, `Makefile`, `ailang.lock`, package manifests, and `.motoko/config/**/*.json` in the source index. |
| `conformance-kit-plan` | Plan 1 · conformance kit (`motoko_ext_conformance`), **planned** implementation from `PLAN-conformance-kit.md`: the law extracted from `phase_vocab` into `invariants.ail` (ABI-`Msg`) and imported back by `runtime.ail`; the ABI-only kit package (`invariants` · `harness` library · in-kit reject fixtures); the four scenarios; the two root scripts (self-test fail-then-pass, registry probe); and the registry/conformance gate class. Green = artifact to build, gray = frozen by Plan 2, purple = core file edited, teal = scenario, red-dashed = reject fixture, blue = gate, amber-dashed = decision. |
| `conformance-kit-end-state` | Plan 1 · conformance kit **as-built end state** (what exists once `PLAN-conformance-kit.md` is done). Import graph (edges = consumer→dependency): the new kit modules + root scripts, the edited core files, the frozen accept fixtures, all bottoming out at the single `motoko-ext-abi @ 3.0` leaf — the package never imports `src/core`, so the graph is acyclic (§4.0). Green = built by this plan, purple = core file edited, gray = frozen by Plan 2, blue = existing/gate, cyan = the ABI leaf. |
| `conformance-kit-implemented` | Plan 1 · conformance kit **implemented end state**, refreshed after the code landed. Grounded with `tools/code-graph/extract.sh --profile=all` plus source-index import lines for `pkg/sunholo/motoko_ext_conformance/...`: the moved ABI-typed law, main-less harness, reject fixtures, self-test, registry probe, edited core consumers, frozen accept fixtures, and `make conformance` gate. |
| `checkpoint-trigger-plan` | Plan 3 · checkpoint trigger **planned** implementation from `PLAN-checkpoint-trigger.md` (grounded at HEAD `4371de0`): the five operator-signed decisions (D3-1..D3-5) driving the artifacts, the frozen mechanics/law/ABI reused (not touched), the core edits (`StepPolicy` fields, `mk_policy`, the `call_model_or_fail` gate), the new pure helpers (`history_usage_percent`, `checkpoint_would_relieve`, `checkpoint_summary`, `should_checkpoint`), the scenario + in-module test changes, and the `PASS count=15` / `make check_core` / D7-amendment gate. Green = artifact to build, gray = frozen, purple = core edited, teal = scenario/test, blue = gate, amber-dashed = decision. |
| `checkpoint-trigger-end-state` | Plan 3 · checkpoint trigger **expected end state** from `PLAN-checkpoint-trigger.md` (grounded at HEAD `4371de0`). A **control-flow** view (not an import graph): the two new `StepPolicy` fields (default OFF), the `should_checkpoint` gate wired into `call_model_or_fail` (not `decide`'s `else`), the `checkpoint_would_relieve` sole spin-guard, the structural summary, the frozen `apply_checkpoint`/`checkpoint` handler and the pressure-cleared termination loop, checkpoint-output validation split across the shared `validate_compactor_output` law (non-system segment) and `history_valid_transcript` (full history), and the `PASS count=15` + `make check_core` acceptance gate. Green = built by this plan, purple = core file edited, gray = frozen (D7/handler), blue = existing, cyan = shared law reused, amber = the decision, red = terminal (Fail / SealExhausted). |
| `checkpoint-trigger-implemented-end-state` | Plan 3 · checkpoint trigger **actual implemented end state** after `c611a78`, refreshed with `tools/code-graph/extract.sh` (`core`: clean 34 modules/601 funcs/810 invokes; `all`: fresh source index 166 modules/1691 funcs/2170 invokes, with unrelated iface failures called out). Control-flow/obligation view: `call_model_or_fail` gate, `StepPolicy` defaults, pure usage/relief helpers, restored live `history_messages(cp.state.history)` threading, validation split, scenario/in-module/repro locks, and observed gates. |

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark
canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts <name>.mmd <name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
