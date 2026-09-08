# Handoff: write the implementation plan for ADR-001 (Accepted)

Audience: a fresh, source-grounded session. You are **authoring**, not reviewing. Both gating ADRs are
Accepted — project-007's taxonomy on 2026-07-26, ADR-001 on 2026-08-02 — so the plan is authorised and
the sequencing below is decided rather than open.

## Mandate

Write the implementation plan for
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`.

**The ADR already contains its own `## Implementation handoff` section with the three-item ordering,
the measurements to cite, and the survey list. Start there and do not restate it — your plan extends
it into work items, sequencing, and acceptance evidence.**

## Read this first: the failure mode this project has already paid for

ADR-001 took nineteen review sections and 154 findings before acceptance, and **the loop diverged for
six rounds** — findings per delta round went 15, 12, 16, 16, 17, 19, 20 while every individual round
looked like progress. The diagnosis is in
`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
and the project record in `NOTE-review-loop-retrospective.md`. Read both; they are short.

The single most transferable finding, and the one most likely to bite a plan author:

> **You cannot specify a detector to buildability in prose.** Classifier 1 was rewritten four times
> and found fail-open every time. It was then built in an afternoon, ran correctly first time, and
> immediately produced a fact four prose revisions had missed.

**Your plan is a build order, not a second specification.** Where the ADR names a mechanism, the plan
schedules building it and states its acceptance evidence. If you find yourself writing a paragraph
that refines *how* a detector should decide something, stop and schedule a spike instead.

Two corollaries:

- **Probe the case you do not already believe.** Three separate ADR passes asserted a category
  property without checking the artifact, and each was caught by someone building the probe the author
  should have built.
- **Re-ground every anchor you inherit.** Per `re-ground-inherited-anchors-before-building.md`. The
  ADR shipped anchor errors in five consecutive passes. Its anchors are clean now, but they are
  point-in-time measurements and your plan will be source-dense.

## What is settled — do not re-open, do not re-derive

The architecture: **D1–D11**, confirmed by every review round since the F1–F6 verifications, reopened
by none, and ruled sound by both acceptance reviewers. Also settled and executable-verified:

- **F1–F6** and their dispositions; **D6.1**'s zero-`RunSummary` claim at HEAD.
- **`ProviderState`'s home is `src/core/ports.ail`** and is buildable — two independent three-module
  probes typechecked clean on the pin. **`ScriptedStep` must relocate** there or below;
  `scripted_ports.ail` imports `ports`, `stub_step` *and* `session`, so both required consumers close
  a module cycle (`LDR002`). `ScriptedPortsState`/`scripted_model_next` is a **design precedent, not
  reusable code**.
- **The clock inventory**: 13 repo-wide `now()` sites — 4 driver, 1 `ext/runtime.ail:190`, 8
  `motoko-ext-compose`. **Nothing is routed at HEAD**; `ExtPorts.clock_now` has zero call sites.
  Per-profile obligation is 4 / 12 / 13 post-attribution-table, 5 / 13 / 13 before it.
- **The ABI facts**: `ExtensionHooks` is closed with eight hooks; three carry no effect row,
  `on_budget_plan` is `! {Env, FS}`, four are at the nine-effect row. **Six of eight are dispatched by
  unconditional fold**; only `on_tool_handle` is gated. A rowless row does **not** bound effects
  reached through a function-valued record field — that is an upstream soundness gap, see *File
  upstream* below.
- **Configuration**: fourteen checked-in configs, all installing `compaction_ai`; `compose` in one;
  `test_dummy` in none; `motoko_ext_conformance` non-registrable.
- **Two `.ai_step(` call sites** repo-wide: `compaction_ai.ail:106`, `reject_fixtures.ail:90`.

**Cite the spike's measurements rather than re-estimating them** — M1 (the `Message` migration: 14
minutes, 28 files, 69 additive sites, 7 needing genuine judgement a grep-derived estimate misses) and
M2 (the repin: 381 effect-row edits across 71 files, three of them in `motoko-ext-abi/types.ail`) are
in `NOTE-spike-findings-real-driver-vertical.md`.

## What is built

**Classifier 1** — `tools/effect-inventory/derive.py`, `make effect_inventory`,
`make effect_inventory_selftest`. Independently run by both acceptance reviewers against its published
criterion: 0 unresolved imported modules, `agree=43 disagree=0`. Its output is a profile/manifest
input, and re-derivation is a required step of every repin. **Do not re-specify it; extend it if a
profile needs more.**

## What you must schedule building

Four artifacts, each with an acceptance criterion already stated in the ADR. **None blocks the ADR;
all block the DST name.**

| Artifact | Where its criterion lives |
|---|---|
| **Classifier 2** — `ExtPorts` typed-call inventory | *Gate mechanisms: built, and deferred* |
| **Site-to-hook attribution table** | same, plus D4 clause 3 |
| **Coverage-floor validation** | same; simplified — the carve-out was deleted at acceptance |
| **D3's fault catalogue** and **D6's event vocabulary** | in D3 and D6 respectively; both are fail-closed-validated constructed artifacts, tracked in their own decisions rather than the gate table |

D6 carries a **scheduling prohibition** you must honour: no D7 parity invariant or acceptance row
depending on the logical/display-only classification may be scheduled before the vocabulary exists.
D4 carries the analogous one for the attribution table and routing-completeness claims.

## The sequencing the ADR already fixes

1. **Widen `Ports.model_step`'s result with an emission log.** Behaviour-preserving, `emissions: []`
   at every construction site, testable entirely against `Scripted` providers. **Does not enable
   item 2** — a successor cursor is not an emission.
2. **Fix the scripted cursor (main loop only).** A *second, bidirectional* widening of the same field:
   state in as well as out. Not behaviour-preserving. Budget the concrete `ProviderState`, the
   `ScriptedStep` relocation, and `ported_provider` returning an initial-state pair.
   `scripts/dst/spike_scripted_cursor_probe.ail` exits 1 by design today and becomes a passing
   regression test for the main-loop path.
3. **Sequence the repin as its own milestone**, budgeting the extension-ABI major it forces — the
   `Trace`/`Rand` row edits *and* the world-token widening of `ExtPorts.ai_step` plus the hook results,
   which is the larger of the two.

Item 2 does **not** fix the extension model path. `ext_ai_step` (`src/core/session.ail:662`) reaches
the same seam through an ABI that cannot return a successor, so an `ai_step`-calling extension is
**omitted from a conformant profile's install list**, not installed-and-excluded — because six of its
eight hooks dispatch unconditionally and reaching an exclusion fails closed. Plan accordingly: **the
first interim profile is the real driver plus the main-loop cursor, covering no extension behaviour.**

## Decisions the plan owns, that the ADR deliberately left open

- `ProviderState`'s concrete shape (record vs sum) — either composes.
- **Whether the approval and clock cursors ride along in the interim widening or are separate later
  ones.** The ADR poses this and does not answer it; guessing wrong reproduces the bidirectional
  widening a second time.
- The order in which the 13 clock sites are routed, and which profile is the first to claim a routed
  set.
- **Naming the first purpose-built narrow conformant profile.** Still unnamed. It cannot install
  `compaction_ai`, and under the declared-row rule its coverable surface is the three rowless ABI
  slots.
- The `stub_step.ail:171-173` stale-comment deletion, with this ADR's anchors into that file
  re-grounded in the same change.

## File upstream, independently of this plan

- **Effect propagation through function-valued record-field calls.** A rowless function calling an
  effectful record field type-checks and performs the effect on the pin; direct and named-helper calls
  are correctly caught. This is a soundness gap and D5's rowless-slot coverability rests on the
  runtime hermeticity probe because of it.
- **`ailang iface`**: `pure` contradicts `effects` on 12 `std/ai` exports; the documented
  `iface <module>` invocation does not work; `std/secret.ail` fails `MOD010` outside a temp directory
  and *auto-relaxes inside one*, so a probe run from `/tmp` reports a clean walk that CI would not see.

Use the `ailang-feedback` skill for routing.

## Known traps

- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors**, reproducibly across a compiler
  version change. Clear every `.ailang/cache` before believing a type error that contradicts the
  source you are reading.
- **Do not run probes from `/tmp`** and conclude a stdlib walk is clean — see the `MOD010` auto-relax
  above.
- **Do not treat the throwaway spike branch as HEAD state.** It carries driver surgery that is not in
  the tree; importing its measurements as HEAD facts is a defect this ADR paid for repeatedly.
- **Do not treat the `arniwesth/ailang` fork as the upstream gate cleared.** D1 requires a *release*.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`, with a Makefile guard
  against drift.

## Output

A plan document in this directory, `PLAN-*.md`, following the conventions of
`PLAN-spike-real-driver-vertical.md`. It should carry:

- work items with explicit dependencies, sized against M1/M2 rather than re-estimated;
- for each deferred artifact, the build step **and** its acceptance evidence;
- the milestone boundaries — pre-repin, repin, post-upstream — and what each unblocks;
- the survey the ADR's `## Implementation handoff` requires, executed rather than restated;
- what the first conformant profile is, by name.

**Do not append review sections to the ADR.** It is Accepted; corrections to it now go through a
normal amendment, not another review round.
