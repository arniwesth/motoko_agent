# DST consolidation diagrams

Diagrams for project 007. Each is a Mermaid `.mmd` source with its rendered `.svg` alongside,
following the convention in `../../004_phase_core_refactor/mmd/README.md`.

`dst-as-built` maps the framework's *machinery* as it exists. The ADR diagrams map its *decisions*.

An earlier version of this note said a pipeline view was not worth drawing here, because 007's
ADR-001 is definitional and decides no implementation, so such a view would draw project 009's
architecture rather than this ADR's content. `dst-target-system` draws it anyway, and deliberately
spans both ADRs: 007 fixes the scope and the boundary (D1, D4) and 009 supplies the mechanism that
realizes them, so the *system* only exists as the pair. It is labelled as spanning both rather than
filed under either alone.

Those three form a **set with one overview and two detail views**, split by concern rather than by
ADR. `dst-target-system` is the map you open first. `dst-world-boundary` expands the seam in
*space* — what crosses it and what stays outside. `dst-discovery-replay` expands the system in
*time* — how a seed becomes a program and how that program replays. The detail views expand the
overview without repeating it, so a claim lives in exactly one of the three.

| File | What it shows |
|------|---------------|
| `dst-as-built` | The DST framework as built at HEAD: injected nondeterminism (live vs fake ports), production transition code, ledger-as-trace, the shared invariant/scenario harness, the failure contract, and the blocking CI gates. Verified 2026-07-12 against `src/core`, `scripts/dst/`, `packages/`, `.github/workflows/`. Documented in `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md`. Supersedes `../../004_phase_core_refactor/mmd/dst-status.svg`. |
| `dst-conformance-gate` | `ADR-001-motoko-dst-definition-and-taxonomy.md` D2 as a **status map** — colour = status at HEAD, not role (green met · amber-dashed partial · gray-dashed absent). The seven-pillar profile with each pillar's HEAD status and evidence, the two pillars excluded by D1 with their revisit tripwires, the six automated evidence criteria that make the gate enforceable, and the two naming outcomes either side of the bar (D3: HEAD is PBT; "logical-fault DST" only after the complete bar; "Soft DST" at no point). This is the view a reviewer opens when a PR claims the DST name. Grounded 2026-07-25 at `a7932c6`. |
| `dst-target-system` | **The agreed DST system** — what 007 decided the target *is*, realized by 009's architecture. Colour = role, not status (contrast `dst-conformance-gate`, where colour = status). Reads as a spine: three modes over one driver → the D1 world boundary and its state-threading rules → the seven-kind request surface D4 relocated the environment to → what the seed controls there (D3 faults, D4 clock, and streaming's intermediate emissions) → the real traced driver under a named profile and manifest, failing closed on unclassified effects → the D6 terminal result pair → D7 whole-execution invariants → the D8 program artifact and D11 corpora → back to D2's naming gate. Side nodes are constraints on the spine stage they attach to. **Nothing in it exists at HEAD** — this is the target, not the as-built. Grounded 2026-07-26 at 007 after RR1–RR10 and 009 at `7b9b4a4c`. |
| `dst-world-boundary` | **Detail view — the seam in space.** Opens with the test 009 D1 sets for whether an effect must cross at all (could its result change the next decision, history, a ledger record, retry/finalization, budget/timeout, or the terminal outcome?) and what may stay outside — diagnostics that cannot influence execution, but never as the *only* copy of an invariant-bearing fact. Then the transition shape, the rules that keep state visible rather than hidden in `SharedMem` or a global, what `world_state` contains beyond a cursor, the seven request kinds in full, faults and time entering through the same seam, the two adapters that are dispatch only, and the D5 profile fence with its fail-closed rule and why capability flags alone are insufficient. Grounded 2026-07-26. |
| `dst-discovery-replay` | **Detail view — the system in time.** `DiscoveryConfig` → the reactive discovery loop, where the real driver issues a request and the generator answers, so each choice changes which request arrives next → the resolved `ExecutionProgram`, with the six-kind interaction vocabulary and the two things every interaction carries (causal identity with its encounter ordinal, and a bounded request projection) → decode and pure structural validation → strict versus regression replay → what counts as a `HarnessFailure` rather than a simulated fault → D6 outcomes, the D7 invariants this lifecycle owns including the discovery contract, D8's precisely-stated reproducibility promise and generator-version rules, and D11's two corpora with promotion feeding back into the fixed bank. Grounded 2026-07-26. |
| `dst-adr-dependencies` | The decision chain `001 → 007 → 009` with declared relationships on the edges (what each ADR amends, preserves, and delegates), the acceptance blockers as currently written, the red-dashed cycle that re-review finding **RR1** identifies — 007 blocked on 009, 009 blocked on 007, 009 additionally blocked on an upstream AILANG API — and the RR1 ruling that dissolves it by re-partitioning residual item 3 into a half already decided in 009 D5 and a half tracked by 007. Grounded 2026-07-25 at `a7932c6`. |

The ADR diagrams are **dated evidence**, like the scorecard they depict: their `%%` headers carry
the grounding commit. Re-render them when the decisions change.

The RR1–RR10 edits landed on 2026-07-26. `dst-conformance-gate` was updated for two of them —
criterion 1 now requires the generated instructions to be *consumed by the real driver as responses
to production requests* (RR2), and pillar 5's bar reads "advanced by the world, observed by
production" (RR6). **`dst-adr-dependencies` is now partly historical**: the red-dashed cycle it
depicts is dissolved, because RR1's ruling has been applied and the ADR's blocking list is empty. It
is kept as-is because it documents why the residual list was re-partitioned; read it as a record of
the defect, not of the current state.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/007_dst_consolidation/mmd/<name>.mmd \
  .agent/projects/007_dst_consolidation/mmd/<name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
