# Effect disclosure for tool faults — diagrams

Diagrams for project 034, drawn from `../ADR-001-effect-disclosure-for-tool-faults.md` (Proposed,
2026-10-02) and, where the ADR defers to it, `../NOTE-scope-effect-unknown-tool-faults.md`. Each is
a Mermaid `.mmd` source with its rendered `.svg` alongside, following the convention in
`../../004_phase_core_refactor/mmd/README.md` as applied by `../../013_core_architecture_for_dst/mmd/`.

Three diagrams. The first is a **decision map**: what holds at HEAD, the nine decisions grouped by
the phase a plan would sequence them into, and what each phase makes true with its gate. The other
two are **mechanism maps**, one per half of the ADR: the live path, from what the harness observed
to the `fault` object the model reads (Phase 0), and the deterministic world, where "the update
applied and the call still faulted" lives and why it cannot reach the model (Phases 1–2).

Colour is **role**, and each `%%` header states its own legend. Across the set: blue holds at HEAD;
amber is the ADR, or the two values it defines; green is proposed; purple is proposed with a
condition, or later; teal is something a phase makes true, with its gate or oracle in italics;
teal-dashed is contingent on an upstream reply; red is a mutation fixture; gray-solid is a log or
an object on the wire; amber-dashed is open or a hazard; gray-dashed is out of scope.

| File | What it shows |
|------|---------------|
| `effect-disclosure-decisions` | **The nine decisions, by phase.** Top: the four facts the ADR starts from — one typed signal for "never started" and "ran", case A (a command that exited 0, returned as `SpawnFailed`), a catalogue whose every tool fault row says the update did not happen, and no driver retry. Then four columns off the ADR node. **Phase 0** chains D5 (ships alone, first), D1 (two values), D2 (the mapping) and D3 (the object and where it is stated) into what Phase 0 makes true, with §2's four-part acceptance as the gate; **Phase 0b** hangs below it with D6 and the wrapper's own probe and baseline pass. **Upstream** is D7's four asks, purple because filing waits for the ruling, opening onto what each ask would change. **Phase 1** chains D9 (009 D3 is not reopened), D4 (two world-only rows) and D8 (the conditional batch, purple) into the world that can hold the case, then **Phase 2**'s P1–P3 with their mutation fixtures and **Phase 3**'s report. Each decision carries its `ruling N` from §6; D1 has none of its own. Two nodes hang off the ADR to the side: §5's "not established anywhere, and needed" list (amber-dashed) and §3's out-of-scope list (gray-dashed). |
| `effect-disclosure-mapping` | **D1–D3, the live path.** A call's path as a spine: refused before dispatch, refused at validation, then by tool. `ReadFile`/`Search` have no update to apply; a `WriteFile`/`EditFile` whose write was started; and `BashExec`/`RunTests`, fanning into the `ProcessError` arms with the probe case that grounds each. Every observation states the value it renders, and the edges into the two amber value nodes say the same. The two blue-dashed arms are the provisional ones: `NotAllowed` and `PermissionDenied` render `unknown` (solid edge) until a probe row or an upstream statement lets them render `none` (dashed edge). `SpawnFailed` carries the note's reading it replaces. Below the values: the typed layer in `types.ail` (13 + 4 construction sites forced to choose), the two renderers that reach the model for native tools, the `fault` object with its field rules, the reason it is emitted first (a tool message keeps its first 65,536 bytes), and 030's diagnostics as the same shape later. `Ok` with any exit code goes round all of it: no disclosure. |
| `effect-disclosure-world` | **D4 and §2, the deterministic world.** Four bands in the order one scripted tool call passes through them. **The catalogue**: the two wire rows left unedited, the two world-only rows each naming its twin, and the visibility field `validate_catalogue` checks. **The program**: `choose_tool` drawing `applied`, and `ScriptedTool` gaining `applied` and a stage under the next schema version. **The world**: `scripted_tool_outcome` staying a function of the observation fields, with the applied update going to the new effect log and the served call to the existing interaction log. **The driver and the wire**: `ToolOutcome` gaining a dispatch stage on `ToolFailed` only and nothing that carries `applied`, the projected tool message with the lexical guard, and the hazard the types leave open — the driver does hold `next_state`. Then P1, P2 and P3, each fed by exactly what its oracle reads, each with its mutation fixture in red. Phase 3's duplicate-effect-key count is gray-dashed: a metric, not a verdict. |

Layout notes live in each source header. This renderer lays same-rank nodes in a row and ranks by
edges, so the decision map chains each phase's decisions down to what the phase makes true; a first
draft with unwrapped labels rendered 3,215 px wide, and this one is 2,643. In the mapping diagram
the refusals feed `none` as one edge from their subgraph, the write tools are two nodes, and the
exec tools are declared before the write tools. Each of those replaced a render that misread: an
edge routed round the far side of the exec arms, an edge that ran *behind* the `NotAllowed` node,
and an `unknown` edge that crossed `NotFound`'s edge to `none`. One crossing remains, between the
`Ok` arm's edge and the started write's; both nodes state their value in text. Node labels avoid
square brackets, which this parser reads as a shape delimiter.

These diagrams are **dated evidence**. The ADR is **Proposed**: the operator has ruled on nothing,
and nothing in the green, purple, teal or red nodes exists at HEAD. They draw the ADR as written on
2026-10-02 against `4023bf08`, and were drawn on 2026-10-03 at `21ba95c9`; only `src/tui` changed
between the two, so the ADR's `src/core` coordinates were not re-checked one by one. One coordinate
was read for the drawing: `cap_tool_message_content` (`src/core/phase_vocab.ail:1559–1568`) keeps
the first 65,536 bytes of a tool message, which is what "emitted before `stdout` and `stderr`"
relies on. Re-render when the operator rules (§6) — a ruling against D2 or D4 changes the mapping
or the catalogue band — when a probe row or an upstream reply moves `NotAllowed` or
`PermissionDenied`, or when Phase 0 lands and its nodes stop being proposals.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
for n in effect-disclosure-decisions effect-disclosure-mapping effect-disclosure-world; do
  bun tools/mmd2svg/mmd2svg.ts \
    .agent/projects/034_ambiguous_tool_outcomes/mmd/$n.mmd \
    .agent/projects/034_ambiguous_tool_outcomes/mmd/$n.svg --theme tokyo-night
done
```

To eyeball a render without a browser, headless Chromium rasterises the SVG: `chromium
--headless=new --no-sandbox --hide-scrollbars --window-size=<w>,<h> --screenshot=out.png
file://$PWD/<name>.svg`, with the size read from the SVG's `viewBox`.

See `tools/mmd2svg/README.md` for other themes.
