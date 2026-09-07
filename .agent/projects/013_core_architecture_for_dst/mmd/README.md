# Core architecture for DST — diagrams

Diagrams for project 013, drawn from `../ADR-001-sequencing-the-dst-architecture-caps.md` (v3),
`../ADR-003-session-snapshot-and-resume.md` (v4.1) and the measurements in
`../NOTE-002-re-read-2026-09-05.md`. Each is a Mermaid `.mmd` source with its rendered `.svg`
alongside, following the convention in `../../004_phase_core_refactor/mmd/README.md` as applied
by `../../007_dst_consolidation/mmd/`.

Three diagrams. The first is a **capability map** for ADR-001, not a mechanism map: it answers
"what does adopting the ADR let the project do that it cannot do today, and what proves it", and
it is as explicit about what the ADR leaves capped as about what it unlocks. The other two draw
ADR-003: a **mechanism map** of the snapshot's lifecycle across the four processes that touch
it, and a **state map** of one session under suspend, resume and park.

Colour is **role**: blue is a cap measured at HEAD; amber is the ADR; green is a decision that is
work now; purple is a decision relocated to 028 or deferred; teal is a capability unlocked by a
named gate; teal-dashed is potential, contingent on an upstream reply or a later phase;
gray-dashed is what stays capped, which is D7's disposition list. The `%%` header states the
legend.

| File | What it shows |
|------|---------------|
| `dst-arch-adr-unlocks` | **What the seven decisions unlock.** Top: the caps the ADR works — NOTE-165's sentinel and RESEARCH's B, D and E, with the numbers NOTE-002 §1 re-measured (198 `next_state` lines, 37 private emission sites in a 682-line effectful loop, ambient lifecycle at both ends, `context_limit: int` with `0` as the sentinel) — feeding the ADR node. Then the four decisions that are work, in their order (D6, D3, D1, D2), each followed by what it unlocks with the proving gate in italics: the disclosed sweep baseline; the three asks as issues; the fail-loud measurement boundary and its three-arm fixture, then the reason reaching `decide` with its three contract candidates; a dropped successor going red inside a framed run, then the two production drops repaired and shown red first, then the request inventory with its alias-bypass mutant. The relocated and deferred decisions (D5, D4) hang off the unlocks that oblige them — the exit repair is D5's obligation, the inventory collapses to one site under D4's interpreter — and each opens onto its potential: reachable lifecycle fault classes; sole emission as a type property, Row 7 decidable, multi-actor as an interpreter change, symbolic execution past `decide`. The asks open onto theirs, stated no wider than the cited designs support. Off to the side of the ADR, one gray node carries D7's still-capped list: §2.A's zero FS/env/clock faults and 9-of-12 census (spike first), §2.C's 1-of-40 coverage (after the pilot), extension-side drops, the `:3265` loop, `WorldM`, behaviour under `Unknown`, TUI rendering. Caps A and C therefore appear only there, which is the point. Grounded 2026-09-05 at `62cb753`, branch cut at `3fe71b0`. **Nothing in the green, teal or purple nodes exists at HEAD.** |

| `session-snapshot-mechanism` | **ADR-003 v4.1, the mechanism.** Top: the four losses verified at `97827bf` — the history dying at the `Fail` arm (`session.ail:2437` passes totals and step index to `c2_fail`, not the messages), the outer loops recursing with the pre-turn history, two session ids in one log because every traced run derives its own, and a total `world_of_json` beside an uncalled `history_from_resume` — feeding the ADR node. Then the four processes that touch a snapshot, each a subgraph: the **traced run** (D2's typed suspension with the additive `suspended` and `written` fields, D1's two objects under one envelope, D3's ported atomic writer with its own request class and the plus-two rule); the **conversation loop** (D5's identity rule — session id forwarded, run id with no clock read, generation advancing on every write — and D6's in-process resume); the **host** (D5's lease with its own exit hooks, D2's wire change with herdr seeing `blocked`); and the **resumer** (D4's strict decode, D6's rebuild from the stored task with the profile switch accepted, D5's refusal table and the `SessionResumed` seam). The snapshot file is the one gray cylinder between them, with the writer rule on its edges: the child writes turn-end, budget, park and restart; the host writes abort after the child exits. Three teal unlocks carry their PLAN-003 gates in italics: the judging number (P1), the plus-two asserted once (P2), a session surviving its process (P3). Purple D7 hangs off the ADR as what ADR-002 v3's D6 now points at; gray-dashed is ADR-003's "Not decided". Colour = role: blue a loss at HEAD · amber the ADR · green decided now · purple unscheduled · teal a capability with its gate · gray-solid a file on disk · gray-dashed out of scope. Grounded 2026-09-06 at `97827bf` after four reviews (`REVIEW-adr003-*-verdicts-fable.md`). **Nothing in the green, teal or purple nodes exists at HEAD.** |
| `session-snapshot-states` | **ADR-003 v4.1, one session's states.** A state map drawn as a flowchart, in four subgraphs in the order a session passes through them. **In memory** (green): fresh session at generation 0, `Running` under a `RunIdentity`, `Suspended (BudgetExhausted)` held by the conversation loop with input unlocked and herdr `blocked`, and `Between turns`; edge labels give the event and, after a slash, the snapshot written with its generation and writer — so `continue` resets the step index and totals while carrying the counts, and a non-budget error writes nothing and bumps the run ordinal. **On disk** (gray cylinders): the child-written `Restart` update including the no-snapshot-yet fallback, the host-written `Abort` update after the child exits, and the last in-run write that a crash or container restart leaves behind. **A fresh process** (amber hexagon): `--resume` in its five-step order, with the red refusal node listing every `Refusal` variant, and its two returns — a turn snapshot to between-turns with history on screen, a continuation to suspended with the head prefix replaced and artifacts reset on a profile switch. **D7's park states** (purple, unscheduled): `ParkRequested` → path 1 back to `Running` when `wake_read` returns, or path 2 under `--park-exits` to `SuspendedWaiting`, `WakeResolved(g)`, `Resuming(g)` with the seeded wakes cursor and rewritten request id, plus the teal-dashed `Lost` and `Aborted` exits its v3 review asked for, and the no-wake-file recovery back through the resumer. Grounded 2026-09-06 at `97827bf`. **Nothing here exists at HEAD.** |

A layout note lives in each source header: this renderer lays same-rank nodes in a row and
ignores invisible links, so the ADR-001 unlocks are chained where "then" is honest and D7's items
are one node. A first draft with a seven-node unlocked band rendered 4,880 px wide; this one is
under half that. In the ADR-003 pair, the four processes are subgraphs so the writer rule is
visible, and two cycle edges (the resumer seeding the loop, the loop re-entering the run) are
stated in node text rather than drawn, because drawing them pulled the conversation loop above
the run it feeds; a first draft of the state map without subgraphs floated the park states to
the top. Node labels avoid square brackets, which this parser reads as a shape delimiter: a first
render of the mechanism map lost the strict-decode node's class to `Result[Snapshot, Refusal]`.

These diagrams are **dated evidence**: each `%%` header carries the grounding commit and the ADR
version. v1 and v2 of ADR-001 were rejected on review; its diagram draws v3. ADR-003 went through
four review rounds the same day; its two diagrams draw v4.1, the version PLAN-003 is written
against. Re-render them when the ADRs change — for ADR-001, if D2's inventory (its first
deliverable) changes the counted domain, or if the sweep D6 requires turns any "unlocked" gate
into a standing red; for ADR-003, if PLAN-003's P1 gate moves the judging number's form, if the
writer rule or the refusal table changes, or once D7 is scheduled and its states stop being
purple.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
for n in dst-arch-adr-unlocks session-snapshot-mechanism session-snapshot-states; do
  bun tools/mmd2svg/mmd2svg.ts \
    .agent/projects/013_core_architecture_for_dst/mmd/$n.mmd \
    .agent/projects/013_core_architecture_for_dst/mmd/$n.svg --theme tokyo-night
done
```

To eyeball a render without a browser, headless Chromium rasterises the SVG (no `rsvg-convert`
or `cairosvg` on the box): `chromium --headless=new --no-sandbox --hide-scrollbars
--window-size=<w>,<h> --screenshot=out.png file://$PWD/<name>.svg`, with the size read from the
SVG's `viewBox`.

See `tools/mmd2svg/README.md` for other themes.
