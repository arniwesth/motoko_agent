# Core architecture for DST — diagrams

Diagrams for project 013, drawn from `../ADR-001-sequencing-the-dst-architecture-caps.md` (v3),
`../ADR-003-session-journal-and-resume.md` (v6.1, journal-only) and the measurements in
`../NOTE-002-re-read-2026-09-05.md`. Each is a Mermaid `.mmd` source with its rendered `.svg`
alongside, following the convention in `../../004_phase_core_refactor/mmd/README.md` as applied
by `../../007_dst_consolidation/mmd/`.

Three diagrams. The first is a **capability map** for ADR-001, not a mechanism map: it answers
"what does adopting the ADR let the project do that it cannot do today, and what proves it", and
it is as explicit about what the ADR leaves capped as about what it unlocks. The other two draw
ADR-003 v6.1: a **mechanism map** of the journal's lifecycle across the three processes that
touch it — the run emits, the host writes, the resumer folds — and a **state map** of one
session under suspend, resume and park, with the journal entry each transition writes. Both
were first drawn against v4.1's checkpoint design as `session-snapshot-*`, and re-rendered and
renamed to `session-journal-*` on 2026-09-07 for v6.1; nothing outside this directory linked to
the old names.

Colour is **role**: blue is a cap measured at HEAD; amber is the ADR; green is a decision that is
work now; purple is a decision relocated to 028 or deferred; teal is a capability unlocked by a
named gate; teal-dashed is potential, contingent on an upstream reply or a later phase;
gray-dashed is what stays capped, which is D7's disposition list. The `%%` header states the
legend.

| File | What it shows |
|------|---------------|
| `dst-arch-adr-unlocks` | **What the seven decisions unlock.** Top: the caps the ADR works — NOTE-165's sentinel and RESEARCH's B, D and E, with the numbers NOTE-002 §1 re-measured (198 `next_state` lines, 37 private emission sites in a 682-line effectful loop, ambient lifecycle at both ends, `context_limit: int` with `0` as the sentinel) — feeding the ADR node. Then the four decisions that are work, in their order (D6, D3, D1, D2), each followed by what it unlocks with the proving gate in italics: the disclosed sweep baseline; the three asks as issues; the fail-loud measurement boundary and its three-arm fixture, then the reason reaching `decide` with its three contract candidates; a dropped successor going red inside a framed run, then the two production drops repaired and shown red first, then the request inventory with its alias-bypass mutant. The relocated and deferred decisions (D5, D4) hang off the unlocks that oblige them — the exit repair is D5's obligation, the inventory collapses to one site under D4's interpreter — and each opens onto its potential: reachable lifecycle fault classes; sole emission as a type property, Row 7 decidable, multi-actor as an interpreter change, symbolic execution past `decide`. The asks open onto theirs, stated no wider than the cited designs support. Off to the side of the ADR, one gray node carries D7's still-capped list: §2.A's zero FS/env/clock faults and 9-of-12 census (spike first), §2.C's 1-of-40 coverage (after the pilot), extension-side drops, the `:3265` loop, `WorldM`, behaviour under `Unknown`, TUI rendering. Caps A and C therefore appear only there, which is the point. Grounded 2026-09-05 at `62cb753`, branch cut at `3fe71b0`. **Nothing in the green, teal or purple nodes exists at HEAD.** |

| `session-journal-mechanism` | **ADR-003 v6.1, the mechanism.** Top: the four losses verified at `97827bf` — the history dying at the `Fail` arm (`session.ail:2437` passes totals and step index to `c2_fail`, not the messages), the outer loops recursing with the pre-turn history, a log that is *about* the session (digests, notes, capped text, 23 of 37 emits reaching the trace), and two session ids beside a total `world_of_json` — feeding the ADR node. Off it, two gray-dashed nodes: what v5 **retired** from the checkpoint design (the child-written snapshot, `file_replace` and its class, the leaf module, the `written` field, the generation counter, the wake file) and what stays "Not decided". Then the three processes that touch the journal, each a subgraph: the **traced run** (D2's typed suspension unchanged; the journal-class events — `HistorySeeded` at the traced entry, `HistoryAppended` one message each at the nine sites with `replaces_previous` on the hybrid batch, `HistoryReplaced` as a checkpoint pointer, `StateDelta` with cumulative counts, an incremental `digest_after` — appended *and* emitted; D4's `final` projection at all seven terminal arms); the **conversation loop** (D5's identity — session id forwarded, resume count from the environment, a run id with no clock read — and D6's in-process resume); the **host**, the only writer (D3's host-lifetime `SessionJournal` with the three-arm seed rule, the digest rule into the JSONL log, the synchronous exit entry, the lease); and the **resumer** (D4's pure fold with the chain check, the pairing check and the trailing-call strip; D6's rebuild from the header's task with the profile switch accepted; D5's refusals and the frame opening exactly at the previous `final`). The journal file is the one gray cylinder, fed only by the host and read once by the resumer. Three teal unlocks carry their PLAN-003 gates in italics: the first judging number (P1), the `JournalFold` invariant on every fixture (P3), and the second judging number — a run that dies at step N resumes with N steps (P3). Purple D7 is park and wake as entries. Colour = role: blue a loss at HEAD · amber the ADR · green decided now · purple unscheduled · teal a capability with its gate · gray-solid the file · gray-dashed out of scope or retired. Grounded 2026-09-07 at `97827bf` after six reviews (`REVIEW-adr003-*-verdicts-fable.md`). **Nothing in the green, teal or purple nodes exists at HEAD.** |
| `session-journal-states` | **ADR-003 v6.1, one session's states.** A state map drawn as a flowchart, in four subgraphs in the order a session passes through them, with edge labels giving the event and, after a slash, the journal entry the host writes for it. **In memory** (green): fresh session at resume count 0, `Running` with every history change emitted as it happens, `Suspended (BudgetExhausted)` held by the conversation loop with input unlocked and herdr `blocked`, and `Between turns`; `continue` resets the step index and totals while carrying the counts; a model change is a `settings` entry. **The journal** (gray cylinders), the only thing that exists when no process holds the session: the leaf as the last entry on the active branch, the host-written `exit` entry with its reason and pending tool calls, and a crash leaving the journal at the last flushed entry, possibly an unpaired call. **A fresh child** (amber hexagon): `--resume` in its order — lease, ambient read, fold, runtime for the invoked profile, budget and prompt from the header's task, digest compare, `SessionResumed` — with the red node listing every `Refusal` variant and two returns keyed on the last entry: to between-turns with the folded history and any stripped call named, or to suspended with the folded continuation. **D7's park states** (purple, unscheduled): `ParkRequested` writing a `park` entry, path 1 back to `Running` when `wake_read` returns, path 2 under `--park-exits` to `SuspendedWaiting`, `WakeResolved` writing a `wake` entry as the park entry's child, and `Resuming` seeding the cursor so `wake_read` consumes it once; the teal-dashed `Lost` and `Aborted` exits; and the no-wake-child recovery back through the resumer. Grounded 2026-09-07 at `97827bf`. **Nothing here exists at HEAD.** |

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
six review rounds over two days; its two diagrams draw v6.1, the journal-only version PLAN-003
v3.1 is written against, and were re-rendered from their v4.1 checkpoint form on 2026-09-07.
Re-render them when the ADRs change — for ADR-001, if D2's inventory (its first deliverable)
changes the counted domain, or if the sweep D6 requires turns any "unlocked" gate into a
standing red; for ADR-003, if PLAN-003's P3 changes the entry types or the fold rules, if the
refusal table changes, or once D7 is scheduled and its states stop being purple.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
for n in dst-arch-adr-unlocks session-journal-mechanism session-journal-states; do
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
