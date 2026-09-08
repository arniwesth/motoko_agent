# DST execution-architecture diagrams

Diagrams for project 009. Each is a Mermaid `.mmd` source with its rendered `.svg` alongside,
following the convention in `../../007_dst_consolidation/mmd/README.md`.

All five depict `ADR-001-deterministic-test-world-architecture.md` and nothing else. They are
**dated evidence**, like the ADR itself: their `%%` headers carry the grounding commit. Re-render
them when the decisions change.

`dst-resulting-system` maps the *machinery* the ADR produces. The other four map its *decisions*
and the state of those decisions.

## How these relate to the 007 diagrams

Project 007's `dst-target-system`, `dst-world-boundary`, and `dst-discovery-replay` already draw the
*agreed target* — the world seam in space, the seed-to-program-to-replay lifecycle in time, and the
decision spine connecting them. Those three deliberately span both ADRs, because 007 fixes the scope
and the boundary while 009 supplies the mechanism, so the target only exists as the pair. Redrawing
them here would produce diagrams making the same claims under a different project number.

Four of these five draw the ADR as a **document under active review** instead: what each decision
owns, which parts are blocked, which corrections overturned earlier ones, and what the near-term
implementation actually turns on. Where a claim already lives in a 007 diagram it is referenced
rather than repeated, so a claim still lives in exactly one place across the two sets.

The fifth, `dst-resulting-system`, is the one deliberate overlap, and it is a different *kind* of
view: it stands to 007's `dst-target-system` as 007's `dst-as-built` stands to its ADR diagrams. Not
"what was decided" but **what code, types, and artifacts will exist** once the decisions land —
named modules and fields, which band each thing belongs to, what this ADR retires, and which parts
arrive only with an external event.

| File | What it shows |
|------|---------------|
| `dst-resulting-system` | **The system the ADR results in**, as a machinery map in the register of 007's `dst-as-built`. Eight bands: three modes over one driver · the production code and the widened `ports.ail` · the one semantic seam · the `LiveWorld`/`DeterministicWorld` adapter pair · the test-only code that may not reimplement transitions · the six versioned artifacts (five recorded axes plus D3's fault catalogue) · results, oracle, and the automated gate · and what arrives only with the upstream release or the ABI major. Carries an explicit **retired** node — `C2LoopState.provider`, the history-derived scripted index, the stringly `tool_exec`, `Ports.hooks_runtime`, 004's stream-delta ledger-append handle, normalization as a time strategy, and any reliance on `--virtual-time`. Colour = provenance: production · test-only · artifact · seam · gated · retired. |
| `dst-execution-decisions` | **Overview of the decisions.** The ADR as a decision map: lineage (depends on accepted 007, amends 001 and 004 — including 004's stream-delta ledger-append handle, replaced as *unbuildable*), the two acceptance blockers and why they differ in kind, then D1–D11 with what each owns and delegates, into the eleven-question acceptance test and the name it unlocks. Colour = role; dashed amber marks what is blocked or not citable as gate evidence. |
| `dst-model-step-widening` | **Detail — the one field the near-term plan turns on.** `Ports.model_step` at HEAD, the two independent defects it causes (F2's discarded emission channel, F6's history-derived cursor that *pins* under a folding compactor and kills the run as budget exhaustion), and the **two separate widenings** D1 requires of that single field on two separately stated grounds. Carries the loss-channel rule's narrow scope, the three mechanical constraints review found (the `ProviderState` module cycle and the `ScriptedStep` relocation it forces, the live/`Ported` identity contract, the excluded extension model path), the consequence that **no checked-in configuration is conformance-eligible in the interim**, and what the upstream gate actually blocks — one closure in `live_ports` and the parity proof, not the migration. |
| `dst-hermeticity-detectors` | **Detail — what must be routed, and what can detect a gap.** D4's all-or-nothing rule and why it has no exemption, the repo-wide 13-site clock inventory with nothing routed at HEAD, the installation-scoped definition of *profile-reachable* and its three clauses, per-profile counts (4 · 12 · 13), and D5's five-part hermeticity gate. Then obligation 1 (make the defect unrepresentable — the fix that actually landed), obligation 2 (a conservative textual site inventory, with its toolchain-derived classifier, target-module matching rule, and three-limit soundness boundary), obligation 3, and the `Clock`-capability backstop with the correction that it is a run-time check catching *performed* reads only. **Both earlier framings of obligation 2 are drawn as rejected**, including the misdiagnosis that survived into a fix. |
| `dst-trace-and-oracle` | **Detail — the returned trace becomes the oracle.** The HEAD state that contradicts the contract (zero `RunSummary` in the returned trace on every path, because `ledger_emit` is a projection and `ledger_append` is never called with one), the two disjoint result classes, the eight contract items with item 4's parity-not-shared-transition rule and its named stream exception, and item 6's split between an in-runner violation that can return a typed value and a raw capability bypass that cannot. Then the event-vocabulary artifact as the fifth versioned axis — 34 variants, `ledger_record_name` naming 3 of them, and the scheduling prohibition that follows — into D7's invariants, D8's reproducibility promise, and D11's two corpora with class-reached and branch-reached kept separate. |

## Status at the time of drawing

The ADR is **Proposed**, not accepted, and **nothing it decides exists at HEAD**. Two acceptance
blockers stand: the upstream recorded-stream API is a release event outside this repo, and the
fourth correction pass has not been independently verified. `dst-hermeticity-detectors` carries the
consequence of the second on its face — D5's routing audit is not citable as name-adoption gate
evidence until a delta review confirms the replacement detector.

All diagrams are dark-themed (`tokyo-night`); their `classDef` fills are tuned for a dark canvas and
match 007's palette, so a role reads the same colour across both sets.

## Re-render

Requires Bun (`cd tools/mmd2svg && bun install`). From the repo root:

```sh
bun tools/mmd2svg/mmd2svg.ts \
  .agent/projects/009_motoko_dst_execution/mmd/<name>.mmd \
  .agent/projects/009_motoko_dst_execution/mmd/<name>.svg --theme tokyo-night
```

See `tools/mmd2svg/README.md` for other themes.
