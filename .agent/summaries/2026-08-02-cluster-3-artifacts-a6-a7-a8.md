# 2026-08-02 Cluster 3: WI-A6, A7, A8 — three constructed artifacts, and the first calibration on new-artifact work

## Context

Branch: `arniwesth/mot-47-execute-wi-a12`

Session span: `c67c7d9` → `6153785`, **4 commits**, three of them production source. Input was
`HANDOFF-execute-a6-a7-a8-artifacts-and-validators.md`, executed cold against HEAD. Fourth code
session of project 009, following cluster 1
(`2026-08-02-cluster-1-first-code-a1-p6-a2-port-widenings.md`), cluster 4
(`2026-08-02-cluster-4-terminal-trace-a16-a9.md`) and cluster 6
(`2026-08-02-cluster-6-wi-a12-world-state-threading.md`).

The three items are grouped by *shape*, not by files: a constructed, versioned artifact plus a
validator that fails closed. The cluster sits on Milestone A's critical path twice — A13 needs A7's
stable class ids directly, and A10 needs all three before A13 can consume its manifest. A8
additionally gates A14.

Re-grounding first: `git diff --stat aa55aa0..HEAD -- src packages scripts Makefile` was empty, so
the handoff's anchor table held without re-measurement.

## What landed

| Commit | Item | Artifact + gate |
|---|---|---|
| `935bd46` | **WI-A6** | `src/core/dst_profile_coverage.ail`, `make profile_coverage` |
| `a7d70b5` | **WI-A7** | `src/core/dst_fault_catalogue.ail`, `make fault_catalogue` |
| `c873002` | **WI-A8** | `src/core/dst_event_vocabulary.ail`, `make event_vocabulary` |
| `6153785` | report | costs, 30% ratio, seven plan/ADR corrections |

**Green:** `make --keep-going compaction_dst conformance phase_c_l1 terminal_trace world_state
profile_coverage fault_catalogue event_vocabulary smoke_driver` exits 0, 108 checks. `check_core`
37→38 modules. No wire change; no golden changed.

All three targets added to `make dst` and to CI's DST gate line.

## The finding that answers the schedule question

**The site model does not transfer to new-artifact work — and the direction is the opposite of the
hedge the plan carried.**

The plan said three widen-and-converge runs measure nothing about A7, A8, A10, A13, A14 and B2, and
that their estimates stand unrevised. Right about the transfer, wrong about the direction. New-
artifact sites are markedly **cheaper** per site:

| | Sites | Build time | Sites/min |
|---|---|---|---|
| Cluster 1 (A1+A2, widen-and-converge) | 48 | ~14 min | 3.4 |
| WI-A6 | 38 | ~5 min | 7.6 |
| WI-A7 | 68 | ~11.5 min | 5.9 |
| WI-A8 | 158 | ~8 min | 19.8 |

A converge site costs a compiler round-trip; an artifact row does not. You author the artifact once
and the validator reports every defect at once. Both new modules type-checked on the first `ailang
check`, and A8's 34-variant round-trip passed on the first run.

**So sites/min is the wrong predictor for this class. Cost tracks the number of rows whose content
must be DISCOVERED rather than TRANSCRIBED.** A7 and A8 are the controlled comparison inside one
session: 68 sites in 11.5 min against 158 sites in 8 min. Every one of A7's eleven rows needed a
recovery branch located and confirmed in the driver — eleven separate greps and reads — while A8's
thirty-four rows were transcription from a projection function already open, plus one classification
judgement each.

**Sizing rule handed to A13, A14 and B2:** count the rows requiring an independent source
investigation, price those at ~1 minute each, price transcribed rows at negligible.

Total elapsed: **~30 minutes** for three artifacts, plus ~4 minutes final gate verification.

## Judgement ratio: 30%, exactly the corrected predictor's high band

| | Sites | Judgement | Ratio |
|---|---|---|---|
| WI-A6 | 38 | 6 | 16% |
| WI-A7 | 68 | 30 | 44% |
| WI-A8 | 158 | 44 | 28% |
| **Combined** | **264** | **80** | **30%** |

The corrected predictor — the band is set by *whether the change introduces a value that did not
previously exist*, high band ~30% — **holds exactly and for the right reason.** No revision needed.

The spread confirms the same axis. A6 came in *below* the band at 16% because D5 fixes its rules
verbatim: transcription plus one discovery. A7 came in *above* it at 44% because every row carries
**two** fields the source does not determine — the recovery branch and the logical transition — so a
row is two judgements, not one. **A7's shape is what A13 and A14 should be sized against.**

Definitions used, recorded so the next run is comparable: a *site* is one independently authored
declaration that could be individually wrong (enumeration member, catalogue row, validator rule,
fixture, inline test, migrated call site); *judgement* is a site where the source did not determine
the answer.

## Four sites admitted two type-checking answers with a silent wrong one

All four are **artifact-level rather than construction-level** — the form S1 predicted for
constructed artifacts. Determinism and the compiler caught none of them.

**1. `on_describe_tools`: coverable, or unconditionally dispatched?** D5 says the wrong one. Caught
by not trusting a count — see the correction below.

**2. My own `partial_disclosure` fixture asserted a rule that could not fire.** The first version put
a duplicated slot in an eight-entry covered list and expected both the disjointness *and* the
exhaustion rule; that arrangement leaves nothing unaccounted, so only one fired. The inline test
caught it. Worth recording because the defect was in the **fixture**, not the code: a
set-completeness fixture that cannot reach the state it claims to test is green while testing
nothing — cluster 4's C1b defect, one level up.

**3. Classifying A8's 34 variants by SURVEY rather than by SEMANTICS.** The sharpest of the four.
Only 13 of the 34 reach the returned trace at HEAD, so a survey-based classification declares 21
events display-only, validates cleanly, and makes D6.4's parity obligation **vacuous** — blessing
the exact gap it exists to close. Nothing mechanical catches this. Caught by reading D6.4's
obligation as a requirement on the future rather than a description of the present. The artifact now
keeps the survey in a separate `reaches_trace_today` field so the two can never be confused, and
`logical_variants_not_in_trace()` makes the distance countable: **15 variants, which is A14's work
list.**

**4. Inventing fresh snake_case ids beside the three existing `fault_class` literals.** The handoff
named this in advance and it was real: both spellings type-check and neither was validated. The
catalogue adopts the literals verbatim as class ids and the call sites reference the constants. The
check that makes it stick is asserted **on the wire, not in the source** — `fault_catalogue_dst`
drives `tool_outcome_message` and reads the emitted `fault_class` back out, because "both sides
reference the same constant" is a claim about source, not output.

## What set completeness caught that row shape did not

- **A6 — `partial_disclosure`.** Both lists disjoint, every id a real ABI slot, each list
  individually well-formed, and **eight entries across the two, which is the correct count** — while
  `on_solver_candidate` is classified nowhere. A shape-and-disjointness validator accepts it. Only
  counting per *slot* rather than per *entry* separates "eight entries" from "eight slots".
- **A7 — `test_catalogue_missing_one_class_fails`.** Every remaining row perfect, so every row-shape
  check passes; one required class simply absent. Asserted alongside `not has_rule(rs,
  "row-field-empty")` so it cannot pass because a different rule fired. An empty catalogue also
  fails, which is the limiting case.
- **A8 — three Makefile count guards.** The compiler forces an arm in `event_variant_id` for a 35th
  variant but cannot force a row or a sample, so a new variant could be fully compile-clean and
  absent from the artifact. The guards tie the row list to the **type declaration** and the **golden
  set**, not to each other: `variants in LedgerEvent == rows == variants with a golden`.

**A8's round-trip was mutation-tested rather than assumed.** Renaming one declared payload key and
one declared wire name each turn `make event_vocabulary` red; `ailang check` stays green for both.

Every acceptance script also carries a **negative control** asserting the validator can reject at
all — all three were structurally able to have cluster 4's C1b defect otherwise.

## Corrections folded into the plan and ADR

**C1. D5 undercounts the unconditionally-dispatched hook slots: SEVEN, not six.** *(Load-bearing.)*
D5 says six unconditional plus one gated and leaves the eighth unnamed. It is `on_describe_tools`,
dispatched by an unconditional fold at `tool_catalog.ail:114`, reached by `live_ports` on **every
model step** — outside the `ext/runtime.ail` the ADR surveyed. A profile excluding it must be
rejected; under "six" it would have loaded clean. General lesson recorded in the ADR: **when a count
and an enumeration disagree by one, the enumeration is the claim — find the missing member before
trusting the count. WI-A10 must not re-derive the six from D5.**

**C2. The max-steps code change is WIRE-visible, not merely caller-visible.** A9 declined giving the
step-budget `Fail` its own code because it changes a caller-visible `AIError` code. Right, and the
ground is stronger: that code is emitted as an `error` ledger event (`ErrorEvent { code: e.code }`,
`session.ail:2506`/`:2576`) which the TypeScript TUI consumes, so a new code changes a wire event on
every max-steps run. **A7 therefore decided against the change** and removed the fragility without
it — the literal lives once as `max_steps_discriminator_message()` in the catalogue, referenced by
both the emitter and the matcher. Still open, stated in both places: the discrimination is by
message, not by type.

**C3. D3's provider protocol-inconsistent class names two forms and only one is reachable.** Nothing
validates a `StepResult` for internal consistency anywhere — `phase_from_result` projects it into a
`ProviderResult` without checking it.

**C4. D3's approval-deadline class has no clock-driven branch in production at all.** The only
no-response branch is channel closure, which `resolve_approval` itself labels `"timeout"`.

**C5. D6's logical/display-only binary does not cleanly classify `DoneEvent`.** Reported per the
handoff's stop rule, not decided beyond the artifact. D6.3 requires an invariant over its content
(agreement with outcome and `RunSummary`), which display-only denies; D6.1 requires the `RunSummary`
to be final, and the driver projects the `DoneEvent` after `c2_finalize` appends it. Classified
`Logical`, tension recorded in `classification_findings()` and printed every run. **The resolution —
append before finalizing — is A14's call against its invariant set.**

**C6. `ExtInterceptHandled`'s wire projection is lossy** (drops `stream_id` and `id` present in
`ToolHandledInfo`). Recorded in the payload schema rather than corrected; correcting it changes the
wire.

**C7. The handoff's "37 goldens" figure is right and they cover all 34 variants.** Recorded so the
next session does not repeat a wasted step: an obvious `grep '&& golden('` recount returns 30,
because the **first** golden in the block has no leading `&&`. The tree was not wrong; the grep was.
`make event_vocabulary` now asserts the 34-way coverage structurally.

**C8. WI-A6's acceptance line names the weak fixture.** "An all-excluded extension is rejected" is
easy and shallow. The set-completeness fixture is the one worth naming in A10's and A13's acceptance
lines.

## Standing rules

**S1 held and paid.** Every validator and its failing fixtures landed with its artifact. The four
silent-wrong-answer sites above are the return.

**S3 generalises from seams to artifacts.** A6 was built first and it is the artifact whose rules D5
fixes verbatim. Building it first surfaced the ABI-record structural-guard pattern (count the `on_*`
fields), which A8 then reused twice — against the `LedgerEvent` declaration and the golden set — at
no design cost. Had A8 run first, that pattern would have been invented against the harder case.

**S2 was not exercised** — no seam in this cluster had an un-routable option.

## Tooling

The parallel `ailang check` closure tool was rebuilt before editing, per all three prior clusters:
**4.6 s** over 22 modules at baseline (cluster 1: 12 s, cluster 4: 2.6 s, cluster 6: 4.7 s).

It was used **once**, after A7's three-file reconciliation. New-artifact work does not produce the
convergence wave the tool exists for — a small argument that it matters less for A13/A14 than it did
for A1/A2/A12, and worth re-testing rather than assuming next run.

## Handoff notes for cluster 5 (WI-A10)

- A10 consumes all three artifacts. `dst_profile_coverage.disclosure_from_ids` is the load-time parse
  that fails closed on an unknown hook id; `dst_fault_catalogue.conditional_class_ids` and
  `waiving_condition` give the waiver list P4 requires; `dst_event_vocabulary.event_vocabulary_version()`
  is the manifest's fifth axis.
- **A13 gets A7's stable class ids from `required_class_ids()`** — the eleven in D3's table. Three
  are PascalCase because they were adopted from a live wire surface; the inconsistency is deliberate
  and documented in the module header.
- **A14 gets its work list from `logical_variants_not_in_trace()` — 15 variants today** — and must
  resolve C5's `DoneEvent` tension before scheduling the D6.4 parity invariant.
- `driver_only`'s routed-set claim remains untouched, per the handoff: it still needs cluster 2's
  attribution table under D4's scheduling prohibition.
