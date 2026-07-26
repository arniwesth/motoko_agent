# DST consolidation diagrams

Diagrams for project 007. Each is a Mermaid `.mmd` source with its rendered `.svg` alongside,
following the convention in `../../004_phase_core_refactor/mmd/README.md`.

`dst-as-built` maps the framework's *machinery*. The two ADR diagrams map its *decisions* — this
project's ADR-001 is definitional and decides no implementation, so a pipeline view of it would
draw project 009's architecture rather than this ADR's content.

| File | What it shows |
|------|---------------|
| `dst-as-built` | The DST framework as built at HEAD: injected nondeterminism (live vs fake ports), production transition code, ledger-as-trace, the shared invariant/scenario harness, the failure contract, and the blocking CI gates. Verified 2026-07-12 against `src/core`, `scripts/dst/`, `packages/`, `.github/workflows/`. Documented in `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`. Supersedes `../../004_phase_core_refactor/mmd/dst-status.svg`. |
| `dst-conformance-gate` | `ADR-001-motoko-dst-definition-and-taxonomy.md` D2 as a **status map** — colour = status at HEAD, not role (green met · amber-dashed partial · gray-dashed absent). The seven-pillar profile with each pillar's HEAD status and evidence, the two pillars excluded by D1 with their revisit tripwires, the six automated evidence criteria that make the gate enforceable, and the two naming outcomes either side of the bar (D3: HEAD is PBT; "logical-fault DST" only after the complete bar; "Soft DST" at no point). This is the view a reviewer opens when a PR claims the DST name. Grounded 2026-07-25 at `a7932c6`. |
| `dst-adr-dependencies` | The decision chain `001 → 007 → 009` with declared relationships on the edges (what each ADR amends, preserves, and delegates), the acceptance blockers as currently written, the red-dashed cycle that re-review finding **RR1** identifies — 007 blocked on 009, 009 blocked on 007, 009 additionally blocked on an upstream AILANG API — and the RR1 ruling that dissolves it by re-partitioning residual item 3 into a half already decided in 009 D5 and a half tracked by 007. Grounded 2026-07-25 at `a7932c6`. |

Both ADR diagrams are **dated evidence**, like the scorecard they depict: their `%%` headers carry
the grounding commit. Re-render them when the decisions change — in particular after the RR1–RR10
edits land, since those change D2 evidence criterion 1, the pillar-5 wording, and the residual-item
partition.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/007_dst_consolidation/mmd/<name>.mmd \
  .agent/projects/007_dst_consolidation/mmd/<name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
