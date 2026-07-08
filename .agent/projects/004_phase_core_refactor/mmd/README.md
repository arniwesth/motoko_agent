# Architecture & DST diagrams

Diagrams of the phase-oriented core delivered by ADR-001 / ADR-002 (post Phase C /
WI-C6). Each is a Mermaid `.mmd` source with its rendered `.svg` alongside. Edges are
grounded in the code-graph import graph (`tools/code-graph/.out/imports.csv`) plus the
`session → test/stub_step` provider seam the core profile omits.

| File | What it shows |
|------|---------------|
| `new-architecture` | Live module architecture, grouped by ADR-001 role: imperative shell (driver) · pure functional core · phases · ports seam · extensions · ledger. |
| `dst-capabilities` | The DST pipeline: one production code path, swappable ports (live vs scripted/fake), one trace that pure invariants + L1 scenarios assert over. |
| `dst-status` | Same DST pipeline as a **status map** — colour = implementation status (green landed · amber-dashed partial · gray-dashed designed), verified against `src/core` + `scripts/phase_c_l1_scenarios.ail` on 2026-07-06. |
| `abi-v3-rollout-implemented` | ABI v3 rollout implemented on 2026-07-07: operator decisions, durable `packages/` path deps, core artifact/telemetry threading, migrated compaction extensions, and the `make run` resolution path. Grounded with `tools/code-graph/extract.sh --profile=all` after enabling `packages/`, `Makefile`, `ailang.lock`, package manifests, and `.motoko/config/**/*.json` in the source index. |
| `conformance-kit-plan` | Plan 1 · conformance kit (`motoko_ext_conformance`), **planned** implementation from `PLAN-conformance-kit.md`: the law extracted from `phase_vocab` into `invariants.ail` (ABI-`Msg`) and imported back by `runtime.ail`; the ABI-only kit package (`invariants` · `harness` library · in-kit reject fixtures); the four scenarios; the two root scripts (self-test fail-then-pass, registry probe); and the registry/conformance gate class. Green = artifact to build, gray = frozen by Plan 2, purple = core file edited, teal = scenario, red-dashed = reject fixture, blue = gate, amber-dashed = decision. |
| `conformance-kit-end-state` | Plan 1 · conformance kit **as-built end state** (what exists once `PLAN-conformance-kit.md` is done). Import graph (edges = consumer→dependency): the new kit modules + root scripts, the edited core files, the frozen accept fixtures, all bottoming out at the single `motoko-ext-abi @ 3.0` leaf — the package never imports `src/core`, so the graph is acyclic (§4.0). Green = built by this plan, purple = core file edited, gray = frozen by Plan 2, blue = existing/gate, cyan = the ABI leaf. |

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark
canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts <name>.mmd <name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
