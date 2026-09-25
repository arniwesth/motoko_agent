# Cluster 3 execution report — WI-A6, WI-A7, WI-A8, and plan corrections

Executed 2026-08-02 against HEAD `c67c7d9` (anchors re-measured; `git diff aa55aa0..HEAD -- src
packages scripts Makefile` was empty, so the handoff's table held without re-measurement).

Three commits, three artifacts, each with a fail-closed validator:

| | Commit | Lines | Files |
|---|---|---|---|
| WI-A6 coverage floor + disclosure | `935bd46` | 849 | 4 (2 new) |
| WI-A7 D3 fault catalogue | `a7d70b5` | 1037 | 7 (2 new) |
| WI-A8 D6 event vocabulary | `c873002` | 1200 | 4 (2 new) |

`make --keep-going compaction_dst conformance phase_c_l1 terminal_trace world_state
profile_coverage fault_catalogue event_vocabulary smoke_driver` exits 0, 108 checks green.

## This is the first calibration run on new-artifact work, and the site model does not transfer

**It does not transfer because the UNIT does not transfer, and the direction of the surprise is the
opposite of the one the plan hedged against.** The plan warned that new-artifact work is not
measured by three widen-and-converge runs and that its estimates stand unrevised. Correct — but the
reason is not that new-artifact sites are dearer. They are markedly *cheaper* per site:

| | Sites | Build time | Sites/min |
|---|---|---|---|
| Cluster 1 (A1+A2, widen-and-converge) | 48 | ~14 min | 3.4 |
| **WI-A6** | **38** | **~5 min** | **7.6** |
| **WI-A7** | **68** | **~11.5 min** | **5.9** |
| **WI-A8** | **158** | **~8 min** | **19.8** |

A converge site costs a compiler round-trip; an artifact row does not. You author the whole artifact
in one write and the validator reports every defect at once. Both new modules type-checked on the
first `ailang check` and A8's 34-variant round-trip passed on the first run.

**So sites/min is the wrong predictor here. The right one is: cost tracks the number of rows that
required an independent SOURCE INVESTIGATION, not the number of rows.** A7 and A8 are the controlled
comparison. A7 has 68 sites and took 11.5 minutes; A8 has 158 and took 8. The difference is that
every one of A7's eleven rows needed a recovery branch located and confirmed in the driver — eleven
separate greps and reads — while A8's thirty-four rows were transcription from a projection function
already open in front of me, plus one classification judgement each.

**Sizing rule for A13, A14 and B2:** count the rows whose content must be *discovered* rather than
*transcribed*, and price those at roughly one minute each. Price transcribed rows at negligible.
A7's real cost was 11 investigations; A8's was 34 cheap judgements over one open file.

**Definitions used, stated so the numbers are comparable next time.** A *site* is one independently
authored declaration that could be individually wrong — an enumeration member, a catalogue row, a
validator rule, a fixture, an inline test, a migrated call site. *Judgement* is a site where the
source did not determine the answer.

## Judgement ratio: 30%, exactly the corrected predictor's high band

| | Sites | Judgement | Ratio |
|---|---|---|---|
| WI-A6 | 38 | 6 | 16% |
| WI-A7 | 68 | 30 | 44% |
| WI-A8 | 158 | 44 | 28% |
| **Combined** | **264** | **80** | **30%** |

The corrected predictor — *the band is set by whether the change introduces a value that did not
previously exist*, high band ~30% — **holds exactly, and it holds for the right reason.** All three
items introduce values that did not exist, and the aggregate lands on 30%.

The spread is instructive and confirms the same axis the predictor names. A6 came in at 16%, below
the band, because D5 fixes its rules verbatim: the work was transcription plus one discovery. A7
came in at 44%, above it, because every row carries *two* fields the source does not determine — the
recovery branch and the logical transition — so a row is two judgements, not one. **A7 is the shape
to expect from A13 and A14; A6 is the shape to expect from a rules-fixed item.**

## Sites where both alternatives type-check and the wrong one is silent

Four. All four are artifact-level rather than construction-level, which is the form S1 predicted for
constructed artifacts.

**1. `on_describe_tools` is coverable or it is unconditionally dispatched — and D5 says the wrong
one.** Caught by not trusting a count: D5 states "six of the eight ABI hook slots are dispatched by
an unconditional fold ... only `on_tool_handle` is gated". Six plus one is seven, and the eighth
went unnamed. Grepping for the missing dispatch found it in `tool_catalog.ail:114`, outside the
`ext/runtime.ail` the ADR surveyed. See correction C1 — this is the finding of the cluster.

**2. My own `partial_disclosure` fixture asserted a rule that could not fire.** The first version
put a duplicated slot in an eight-entry covered list and expected both the disjointness *and* the
exhaustion rule; but that arrangement leaves nothing unaccounted, so only one fired. The inline test
caught it. Worth recording because the defect was in the *fixture*, not the code: a set-completeness
fixture that cannot reach the state it claims to test is green while testing nothing, which is
cluster 4's C1b defect one level up.

**3. Classifying A8's 34 variants by SURVEY rather than by SEMANTICS.** Both produce a complete,
validating artifact. Only 13 of the 34 reach the returned trace today, so a survey-based
classification declares 21 events display-only — and D6.4's parity obligation becomes vacuous,
blessing the exact gap it exists to close. Nothing mechanical catches this; it was caught by reading
D6.4's obligation ("every logical event *reaches* the returned trace") as a requirement on the
future rather than a description of the present. The artifact keeps the survey in a separate field,
`reaches_trace_today`, so the two can never be confused again, and
`logical_variants_not_in_trace()` makes the distance countable — **15 variants**, for WI-A14.

**4. Inventing fresh snake_case ids beside the three existing `fault_class` literals.** The handoff
named this one in advance and it was real: both spellings type-check and neither was validated. The
catalogue adopts the literals verbatim; the call sites now reference the constants. The check that
makes it stick is asserted **on the wire, not in the source** — `fault_catalogue_dst` drives
`tool_outcome_message` and reads the emitted `fault_class` back out, because "both sides reference
the same constant" is a claim about source, not output.

## What set completeness caught that row shape did not

Each artifact's sharpest fixture, per the handoff's requirement:

- **A6 — `partial_disclosure`.** Both lists disjoint, every id a real ABI slot, each list
  individually well-formed, and **eight entries across the two, which is the correct count** — while
  `on_solver_candidate` is classified nowhere. A shape-and-disjointness validator accepts it. Only
  counting per *slot* rather than per *entry* separates "eight entries" from "eight slots".
- **A7 — `test_catalogue_missing_one_class_fails`.** Every remaining row is perfect, so every
  row-shape check passes; one required class is simply absent. Asserted alongside
  `not has_rule(rs, "row-field-empty")` so the test cannot pass because a *different* rule fired.
- **A8 — the three Makefile count guards.** The compiler forces an arm in `event_variant_id` for a
  35th variant but cannot force a row or a sample, so a new variant could be fully compile-clean and
  absent from the artifact. The guards tie the row list to the **type declaration** and to the
  **golden set**, not to each other: `variants in LedgerEvent == rows == variants with a golden`.

**Mutation-tested rather than assumed.** Renaming one declared payload key and one declared wire
name each turn `make event_vocabulary` red. `ailang check` stays green for both.

Every acceptance script also carries a **negative control** asserting the validator is capable of
rejecting at all, because a green check from a validator that never rejects is cluster 4's C1b
defect and all three of these were structurally able to have it.

## Plan and ADR corrections

**C1. D5 undercounts the unconditionally-dispatched hook slots: seven, not six.** *(Load-bearing;
amend D5.)* The eighth slot D5 leaves unnamed is `on_describe_tools`, and it is unconditional:
`tool_catalog.ail:114` `collect_ext_schemas` folds every registered hook, `:125`
`tools_with_extensions` calls that fold, and `stub_step.ail:133` `live_ports` calls it on **every
model step**. The ADR's survey looked only in `ext/runtime.ail`, where six dispatches live; the
seventh builds the tool catalogue rather than driving the loop. **Consequence:** a profile excluding
`on_describe_tools` must be rejected, and under the ADR's stated six it would have loaded clean.
Closed by `test_seven_slots_are_unconditional` and the `describe_tools_excluded` fixture rather than
by prose. **WI-A10 must not re-derive the six from D5.**

**C2. The max-steps code change is WIRE-visible, not merely caller-visible.** *(Amend D6.2's
amendment and WI-A7's row.)* WI-A9 declined giving the step-budget `Fail` its own code because it
would change a caller-visible `AIError` code. That was right, and the ground is stronger than
stated: the driver's `Fail` code does not stop at the returned `Result` — it is emitted as an
`error` ledger event (`ErrorEvent { code: e.code }`, `session.ail:2506` and `:2576`) that the
TypeScript TUI consumes. A new code changes a wire event on every max-steps run. **A7 therefore
decided NOT to change it**, and removed the fragility without the wire change: the literal lives
once as `max_steps_discriminator_message()` in the catalogue, referenced by both the `step_machine`
`Fail` that emits it and the `session` matcher that reads it. What remains open is stated in both
places — the discrimination is still by message, not by type.

**C3. D3's provider "protocol-inconsistent typed result" has only one of its two named forms
reachable.** D3 gives two: a malformed `ToolCall.arguments` string, and an inconsistent
`StepResult`. The first has a real branch (`tool_call_to_envelope`'s `Err(_) => jo([])`, which
degrades to an empty object). The second has **none** — `model_phase.phase_from_result` projects a
`StepResult` into a `ProviderResult` event without validating it, so a result whose `finish_reason`
disagrees with its `tool_calls`, or which repeats a tool-call id, reaches the loop unremarked.
Recorded as a machine-readable coverage gap, printed by `make fault_catalogue` every run.

**C4. D3's approval-deadline class has no clock-driven branch in production at all.** The only
no-response branch is `resolve_approval`'s `eof` arm, which is *channel closure* and which the code
itself labels `"timeout — no approval received"`. No production policy declares an elapsed-time
approval deadline. The class is legitimately conditional, so this is not a defect — but a profile
claiming it covers a *timed* deadline would be over-claiming, and the condition is now named in the
artifact so a waiver is readable.

**C5. D6's logical/display-only binary does not cleanly classify `DoneEvent`.** *(Reported per the
handoff's stop rule, not decided beyond the artifact.)* D6.3 requires the returned outcome, the
`DoneEvent` and the `RunSummary` to **agree** — an invariant over its content, which is exactly what
display-only denies. But D6.1 requires the `RunSummary` to be the **final** record, and the driver
projects the `DoneEvent` after `c2_finalize` has appended it. So D6.4's obligation on a logical
event and D6.1's final-record invariant cannot both hold by appending it where it is emitted. The
resolution is available — append the `DoneEvent` before finalizing — but it is a change to a
terminal path and therefore **WI-A14's call against its invariant set, not this artifact's**.
Classified `Logical` and recorded in `classification_findings()`, printed every run, so the
classification is not mistaken for a decision that the append is free.

**C6. `ExtInterceptHandled`'s wire projection is lossy.** `ToolHandledInfo` carries `stream_id` and
`id`; the `ext_intercept_handled` arm emits neither. Recorded in the payload schema as the fact it
is, rather than corrected — correcting it would change the wire.

**C7. The handoff's "37 goldens" figure is right, and they cover all 34 variants.** Recorded so the
next session does not repeat the wasted step: an obvious recount using `grep '&& golden('` returns
30, because the **first** golden in the block has no leading `&&`. The tree was not wrong; the grep
was. `make event_vocabulary` now asserts the 34-way coverage structurally so the question does not
need re-answering.

**C8. WI-A6's acceptance line is satisfiable but under-specifies the valuable fixture.** The plan
names "a fixture profile installing an all-excluded extension is rejected". That fixture is easy and
weak. The set-completeness fixture the standing rule S1 calls for — a disclosure with the right
entry count that classifies one slot nowhere — is the one that separates this validator from a
row-shape validator, and it is the one worth naming in acceptance lines for A10 and A13.

## Standing rules: all three held, and S3 got a fourth confirmation by accident

**S1 held and paid.** Every validator and its failing fixtures landed with its artifact. The four
silent-wrong-answer sites above are the return.

**S3 ("route the cheap instance of a seam before the awkward one") generalises to artifacts.** A6
was built first, and it is the artifact whose rules D5 fixes verbatim. Building it first surfaced
the ABI-record structural-guard pattern (`count the `on_*` fields`) which A8 then reused twice
against the `LedgerEvent` declaration and the golden set, at no design cost. Had A8 run first, that
pattern would have been invented against the harder case.

**S2 was not exercised** — no seam in this cluster had an un-routable option.

## Handoff notes for cluster 5 (WI-A10) and beyond

- A10 consumes all three. `dst_profile_coverage.disclosure_from_ids` is the load-time parse that
  fails closed on an unknown hook id; `dst_fault_catalogue.conditional_class_ids` and
  `waiving_condition` give the waiver list P4 requires; `dst_event_vocabulary.event_vocabulary_version()`
  is the manifest's fifth axis.
- **A13 gets A7's stable class ids from `required_class_ids()`.** They are the eleven in D3's table;
  three of them are PascalCase because they were adopted from a live wire surface, and that
  inconsistency is deliberate and documented.
- **A14 gets its work list from `logical_variants_not_in_trace()` — 15 variants today** — and must
  resolve C5's `DoneEvent` tension before it can schedule the D6.4 parity invariant.
- The parallel `ailang check` closure tool was rebuilt before editing, per all three prior clusters.
  **4.6 s** over 22 modules at baseline (cluster 1: 12 s, cluster 4: 2.6 s, cluster 6: 4.7 s). It was
  used once, after A7's three-file reconciliation — new-artifact work does not produce the
  convergence wave it exists for, which is itself a small argument that the tool matters less for
  A13/A14 than it did for A1/A2/A12.
