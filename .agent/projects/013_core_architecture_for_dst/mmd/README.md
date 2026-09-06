# Core architecture for DST — diagrams

Diagrams for project 013, drawn from `../ADR-001-sequencing-the-dst-architecture-caps.md` (v3)
and the measurements in `../NOTE-002-re-read-2026-09-05.md`. Each is a Mermaid `.mmd` source with
its rendered `.svg` alongside, following the convention in
`../../004_phase_core_refactor/mmd/README.md` as applied by `../../007_dst_consolidation/mmd/`.

One diagram so far. It is a **capability map**, not a mechanism map: it answers "what does
adopting the ADR let the project do that it cannot do today, and what proves it", and it is as
explicit about what the ADR leaves capped as about what it unlocks.

Colour is **role**: blue is a cap measured at HEAD; amber is the ADR; green is a decision that is
work now; purple is a decision relocated to 028 or deferred; teal is a capability unlocked by a
named gate; teal-dashed is potential, contingent on an upstream reply or a later phase;
gray-dashed is what stays capped, which is D7's disposition list. The `%%` header states the
legend.

| File | What it shows |
|------|---------------|
| `dst-arch-adr-unlocks` | **What the seven decisions unlock.** Top: the caps the ADR works — NOTE-165's sentinel and RESEARCH's B, D and E, with the numbers NOTE-002 §1 re-measured (198 `next_state` lines, 37 private emission sites in a 682-line effectful loop, ambient lifecycle at both ends, `context_limit: int` with `0` as the sentinel) — feeding the ADR node. Then the four decisions that are work, in their order (D6, D3, D1, D2), each followed by what it unlocks with the proving gate in italics: the disclosed sweep baseline; the three asks as issues; the fail-loud measurement boundary and its three-arm fixture, then the reason reaching `decide` with its three contract candidates; a dropped successor going red inside a framed run, then the two production drops repaired and shown red first, then the request inventory with its alias-bypass mutant. The relocated and deferred decisions (D5, D4) hang off the unlocks that oblige them — the exit repair is D5's obligation, the inventory collapses to one site under D4's interpreter — and each opens onto its potential: reachable lifecycle fault classes; sole emission as a type property, Row 7 decidable, multi-actor as an interpreter change, symbolic execution past `decide`. The asks open onto theirs, stated no wider than the cited designs support. Off to the side of the ADR, one gray node carries D7's still-capped list: §2.A's zero FS/env/clock faults and 9-of-12 census (spike first), §2.C's 1-of-40 coverage (after the pilot), extension-side drops, the `:3265` loop, `WorldM`, behaviour under `Unknown`, TUI rendering. Caps A and C therefore appear only there, which is the point. Grounded 2026-09-05 at `62cb753`, branch cut at `3fe71b0`. **Nothing in the green, teal or purple nodes exists at HEAD.** |

A layout note lives in the source header: this renderer lays same-rank nodes in a row and ignores
invisible links, so the unlocks are chained where "then" is honest and D7's items are one node.
A first draft with a seven-node unlocked band rendered 4,880 px wide; this one is under half that.

This diagram is **dated evidence**: its `%%` header carries the grounding commit and the ADR
version. v1 and v2 of the ADR were rejected on review; the diagram draws v3. Re-render it when the
ADR changes — in particular if D2's inventory (its first deliverable) changes the counted domain,
or if the sweep D6 requires turns any "unlocked" gate into a standing red.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/013_core_architecture_for_dst/mmd/dst-arch-adr-unlocks.mmd \
  .agent/projects/013_core_architecture_for_dst/mmd/dst-arch-adr-unlocks.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
