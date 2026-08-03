# Cluster 5 execution report — WI-A10, the two decisions, and plan corrections

Executed 2026-08-03 against HEAD `d57ca4c`. `git diff 86a46e6..HEAD -- src packages scripts
Makefile` was empty, so the handoff's input table held without re-measurement.

Two commits, as the handoff required — the machinery first, so a reviewer sees the validator reject
before seeing the definition that passes it:

| | Commit | Lines | Files |
|---|---|---|---|
| The machinery + manifest + exclusion check | `fd4f4bd` | 2298 | 5 (3 new) |
| `driver_only` v1 | `dafe898` | 627 | 4 (2 new) |

`make profile_definition` and `make driver_only` both exit 0 and are wired into `dst` and CI.
`make check_core` is green (41 modules). The full artifact set —
`profile_coverage profile_definition driver_only fault_catalogue event_vocabulary attribution_table
terminal_trace ext_call_inventory_selftest` — exits 0.

---

## The two decisions, which are this item's durable output

### Decision 1. A profile with an unrouted *reachable core* site IS conformant — but only when the site is DECLARED and carries a named INSTRUMENT

Routing completeness is all-or-nothing over `{routed} ∪ {declared-and-instrumented}`. An unrouted
reachable site that is undeclared is a rejection (`unrouted-site-undeclared`); one declared with a
blank instrument is a rejection (`unrouted-site-without-instrument`); and — the half that makes it a
set check rather than a rubber stamp — a declaration for a site that is no longer
reachable-and-unrouted is *also* a rejection (`declared-site-not-reachable`).

**The strict reading was considered and rejected on three grounds, not one.**

1. **It makes conformance unachievable at HEAD by construction rather than by accident.**
   `session.ail:796` cannot be routed on the pin *at all* — `ExtPorts.clock_now` is zero-argument
   and AILANG has no zero-arg lambdas in expression position. Under the strict reading no profile
   can ever load, D5's entire machinery is vacuous until Milestone B's ABI major, and A13 has no
   profile to consume. That is not a conservative choice; it is a machinery that cannot be exercised.
2. **It inverts standing rule S2.** S2 deliberately chose the ambient read over a frozen snapshot
   *precisely so* a future caller trips a gate instead of being served a stale value. A conformance
   rule that punishes the loud option — and would have rewarded the silent frozen cursor, which is
   invisible to every gate — reverses the rule that produced the site.
3. **It makes A5's `routed` flag dead.** A5 added it "precisely so the gap is stated rather than
   absent". A flag no conformant profile may ever set to `false` states nothing.

**Why the weaker reading is not a loophole: the instrument is real, and it is already green.**
`make world_state` runs the Clock poison *pair* — the deterministic entry point completes with
`Clock` withheld (so it reaches neither site) and the live world dies with `Clock` withheld (so the
capability is genuinely load-bearing and the first half is not vacuous). That is *stronger* evidence
than a routing claim: it does not assert the sites are routed, it demonstrates that the deterministic
profile never reaches them. Containment, falsifiably. The blank-instrument rejection is what stops
the field degrading into a way to declare any gap away.

**The sub-question is answered the same way rather than scoped away.** `stub_step.ail:146` sits
inside `live_ports`, which is not the adapter a deterministic run binds, so it is tempting to say it
is not in a deterministic profile's reachable set at all. **Rejected.** D4's "profile-reachable" is
INSTALLATION-scoped, not execution-scoped: a site in a core module is in the set under clause 1
whether or not any given run reaches it. Carving it out on execution-scope grounds would put a
fail-open exception into an installation-scoped rule, and it would have to be re-litigated for every
future site. It stays in the set and is discharged by the same declaration-plus-instrument rule as
`:796`. **One rule, two sites, no exceptions** — and the profile's declaration for `:146` says
exactly this, so the reasoning is readable at the site rather than only here.

*This is not a milestone-level finding.* Decision 1 resolves to "conformant", so `driver_only` is
conformant at HEAD and the handoff's stop-and-report condition is not triggered.

### Decision 2. `driver_only`'s routed-set claim is COMPUTED, and no count is recorded anywhere

`routed_set_claim` derives the partition from `reachable_core_sites(installed)` at the revision the
profile binds. **At HEAD: 7 reachable = 5 routed + 2 declared-unrouted.**

Every assertion on it is a *partition* assertion (`total == routed + unrouted`, and `total` equals
what the table returns), never a comparison against a literal — so a table correction moves the
claim instead of leaving a stale number behind.

**This is not hypothetical: P4 says "a reachable clock set of the four driver sites", and four is
wrong at HEAD.** A12 routed a fifth site in `tool_phase.ail:342` and A5 declared the two unrouted
ones explicitly. Writing `4` into the profile would have type-checked, validated, and been silently
wrong — P3's worked example (`4 / 12 / 13`) recurring one artifact later, which is exactly what P3
predicted would happen.

The one thing the profile *does* record is the declared-unrouted **set**, because that is a claim
about intent that no analysis can recover. Both directions are checked against the computed set.

---

## The composition defect: where it was waiting, and what caught it

The handoff named the canonical instance. It was live, and two more were.

**1. The seven/one dispatch split.** The obvious way to write the "each unconditional slot excluded
is rejected" sweep is to list the slots. Listing them from D5's older prose gives six, the sweep
passes against its own six-list, and a profile excluding `on_describe_tools` loads clean and fails
closed on the first model step. **What caught it: the sweep iterates `all_hook_slots()`, consults
`hook_dispatch` per slot, and asserts `seen == 7` at the end.** No number is written down and the
seven is a *derived* count over the artifact. A ninth slot, or a slot whose dispatch kind changes, is
picked up without editing the sweep. The `on_describe_tools` case is now green from three independent
directions (A6's inline test, A6's fixture, this sweep).

**2. P4's "four driver sites".** Caught by decision 2 above. Both readings type-check.

**3. The `ProfileDefinition` field-count guard.** I wrote `14`; `awk` said `15`. A wrong constant in
a structural guard does not fail to compile — the guard just becomes wrong in the fail-open
direction. Caught by running it, which is the only thing that catches it.

**Nothing else in the item admitted two type-checking answers with a silent wrong one, and that is
because of a policy taken once rather than a check applied many times:** every fact that could be
read from an artifact at runtime is read, so it cannot go stale. Twenty of the twenty-three
cross-artifact bindings are reads. The three that could not be read are where all the risk went, and
each got a purpose-built comparison — see below.

### The three bindings that could not be read, and what stands behind each

| Binding | Why not readable | What keeps it honest |
|---|---|---|
| the attribution table identity | recording it is the *point*; calling `table_identity()` makes the comparison a tautology | recorded as literals in `dst_driver_only.ail`; compared against the live pair at load. **Mutation-tested:** changing a hashed field of the table (a `reviewer`) turns `make driver_only` red with a message naming the fix |
| classifier 2's membership + unrouted sets | derived from source by a Python tool, not declared in AILANG | `tools/profile_definition/check_fixtures.py` re-derives both from the tool and fails on disagreement. **Mutation-tested:** dropping `proc_exec` from the fixture goes red |
| which installable extensions call a classifier-2 field | same, plus it needs `ailang.toml`'s install-eligible set | the same guard asserts every installable caller is **omitted by name** in the profile. **Mutation-tested:** renaming the `compaction_ai` omission goes red |

**The third one is the one that will earn its keep.** `driver_only`'s omission list is otherwise a
guess frozen at authoring time; with the guard, the day a second extension calls a state-threading
seam the target goes red instead of the profile quietly claiming coverage it does not have. The guard
is scoped to `[extensions] packages` entries deliberately — the tool also finds a call site in
`motoko_ext_conformance/fixtures`, which is not installable and must not force an omission.

**D4's re-issue rule is now mechanical rather than aspirational, and it needed the content hash to be
so.** `validate_at_load` catches a stale source-revision *binding*; it cannot catch a table whose
rows changed at the same revision, because it has no idea what the profile recorded. The mutation
test above changes a row at the *same* revision and is caught only by the identity comparison.

---

## Sizing: composition is a FIFTH model, and its unit is the INPUT ARTIFACT

**Measured: ~30 min wall clock, 9 files (5 new), 2925 lines, 77 sites of which 26 needed
judgement — 34%.**

**Round trips: 4, all loud.** Three on the machinery (empty import selector `as X ()`; a cons pattern
with a constructor head; a record literal in cons position) and one on the profile (the same empty
selector). Every one was a parse error with a line number. **Zero silent defects in the code**, and
both new AILANG modules passed their inline tests on the first green compile — 30/30 and 6/6 — as did
both acceptance scripts on their first run.

### Why S4 and S5 both mispredict this, and what does predict it

S5 prices a detector by defect-discovery round trips weighted for loudness. Four loud round trips
should price at near-zero — and by S5 this item should have taken minutes. It took thirty.

S4 prices a constructed artifact by rows whose content must be *discovered*. That prices the
`driver_only` half correctly (19 discovered content rows, ~3.5 min, right on S4's ~1 min/discovered-
row after the grounding was already done) and prices the machinery half at nothing.

**Neither prices the thing that actually dominated: reading the inputs well enough to know what not
to re-derive.** Roughly **15 of the 30 minutes was grounding** — the exports of A5/A6/A7/A8/A9, D5 in
the ADR, WI-A10 and P4 in the plan, and running the A4 tool and the attribution script to see their
live output. That is a cost S4 and S5 both assume away, because both assume you already know the
source you are working in. Composition does not: **its whole job is to be correct about somebody
else's artifact.**

**So: a fifth model, and its unit is the INPUT ARTIFACT, not the site.**

> **S6. Size a composition by the number of INPUT ARTIFACTS whose exports must be read before a line
> can be written — roughly 2–3 minutes each — plus its RECORDED bindings, which are the only ones
> that cost anything after that.** Six inputs × ~2.5 min ≈ 15 min of grounding, then three recorded
> bindings × one purpose-built comparison each ≈ most of the remaining construction. **A read
> binding is free; a recorded binding is where the item's entire risk lives.** Twenty of this item's
> twenty-three bindings cost nothing measurable once the read-don't-restate policy was taken.

Note what this predicts and S5 would not: **a composition with many inputs and no recorded bindings
is cheap regardless of its size**, and a composition with one input and three recorded bindings is
not. Site count predicts neither (2925 lines at 4 round trips).

### The judgement ratio came in at 34%, and the handoff predicted ~16%

**The prediction was right about what it was measuring and the metric is measuring two different
things at once.** Split it and both halves are unsurprising:

| | Sites | Judgement | Ratio |
|---|---|---|---|
| the machinery (rules) | 58 | 8 | **14%** |
| `driver_only` (content) | 19 | 18 | **95%** |
| combined | 77 | 26 | 34% |

**The machinery half came in at 14% — below A6's 16%, exactly as the handoff predicted, and the
three amendments DID settle what they appeared to.** Every rule arrived as a read and cost nothing:
the seven/one split, the floor, the disclosure, the omission rule, the waiver conditions. The eight
judgement calls are the two decisions plus six shape choices (three added fields; modelling D5 fields
2 and 9 as three separate records; stating the classifier-2 rule in D5's "installed while any hook is
un-excluded" form rather than the "installed at all" shortcut; the reverse direction of the unrouted
check).

**The 95% is not a specification failure and no amendment could have reduced it.** D5 says "record
the profile's adapter/parser boundaries, resource models, diagnostic projections, and forbidden
capabilities". *Which* boundaries this profile has is not a fact about D5 — it is a fact about the
driver, and it is discovered, not determined. That is an S4 cost sitting inside a composition item.

**Correction to the predictor, worth carrying to A13:** the judgement ratio tracks how much the
specification leaves undetermined **about the rules**, and it is only a clean signal for an item that
is *all* rules. For an item that ships both machinery and an instance, **report the two ratios
separately** — a combined number reads as "the spec was vague" when the truth is "half of this item
was content, and content is never in the spec."

---

## Scope: what was built, what was not, and why

**Built and green.** The machinery (15-field definition, 16-field manifest, 14 typed rejections);
every rejection the handoff's definition-of-done names, each with a fixture, each naming its rule;
the field-drop sweep over *every* required field rather than one representative; the
set-completeness fixture in A6's `partial_disclosure` shape (eight entries, seven slots — a
row-shape validator accepts it); negative controls throughout; `driver_only` v1; the anti-
transcription guard; two `make` targets in `dst` and CI.

**The runtime exclusion check is built and tested but its call site is not threaded into the dispatch
folds, and that is a scope judgement worth stating rather than burying.** `routing_violation_at` is
complete, returns A9's `RoutingViolation` with the interaction position and partial trace, is tested
for the violating case, the *non*-violating case (a guard that fails closed on everything would pass
the first test and break every run), and the vacuous case. What it is not is *called* from
`fold_prompt_hooks` and friends. Threading a profile there requires either a field on `ExtRuntime` —
which lives in the ABI package, so a Milestone B change — or a new parameter through every fold. At
HEAD there is no consumer: the load-time rules mean the only slot a conformant profile may exclude is
the one gated slot, and no profile excludes it. Adding a parameter with no consumer is the dead-rider
cost P2 rejects. **A13 establishes the profile and is the natural place the call lands; C5 is the
first profile that makes it non-vacuous.** Flagged here so it is a decision on the record and not a
missing acceptance row discovered at the gate.

**The D6.6 complement is asserted from outside, and cannot be asserted from inside.** A raw
capability bypass must stay a non-zero run rather than become a typed value. On the pin a denied
effect terminates evaluation, so a passing script cannot observe it — `make world_state` and
`make terminal_trace` assert it. The acceptance script prints this rather than silently omitting it.

**Not built, deliberately:** discovery/replay/programs (A13's); the interprocedural
attribution-necessity validator (D4 leaves it unbuilt and unscheduled; necessity rests on the
recorded named reviewer as a *stated* exception, and the ADR withdrew one mechanical attempt);
widening `ExtPorts` (Milestone B's ABI major); a second profile (WI-C5, needs B2).

**The scan-root gate exists and its exposure is nil, as the handoff anticipated.** Every entry in
`[extensions] packages` is a path dependency under `packages/`. `ailang.toml:9`'s registry-resolved
`sunholo/logging` is outside the roots but is a library dependency, not an extension, so it is not
installable and not this rule's business. The fixture is built anyway and the guard additionally
fails if an installable extension ever loses its path dependency.

---

## Corrections this cluster carries into the plan and the ADR

**C1. P4's "reachable clock set of the four driver sites" is wrong at HEAD and must not be restated.**
The computed answer is 7 reachable / 5 routed / 2 declared-unrouted. `driver_only` records no count;
`driver_only_routed_claim()` derives it. P4's sentence should say the profile states its reachable
clock set *by computing it*, not by naming a number. (Same defect class as P3's `4 / 12 / 13`, which
P3 already documents — this is its second occurrence, one artifact later, and the second occurrence
is the evidence that P3 is a standing hazard rather than a one-off.)

**C2. D5's definition field list needs three more fields to be decidable, and the plan's WI-A10 row
should name them.** `unrouted_reachable_sites` (decision 1 — D5 has no field for a declared-unrouted
site, so the all-or-nothing rule cannot distinguish a stated containment from a silent gap);
`scan_roots` (D5 obligation 2's roots, which the scan-root rule validates against); and
`exercised_fault_classes` (D3 requires a non-exercised conditional class to be *named* waived — the
complement is not recoverable from the waiver list alone, so an unstated waiver would be
indistinguishable from an exercised class). D5's ten map to **twelve** record fields, not ten:
id/version is one D5 field and two records, and D5 field 2 (extension ids *and* per-hook
classifications) is two records with field 9's disclosure a third.

**C3. Cluster 3's "four non-vacuous fields for an empty install list" is confirmed, and no fifth
was found.** All four carry real content in `driver_only`. The handoff's stop-rule for a fifth is
not triggered.

**C4. The `Env` poison pair is still deferred, and `driver_only` records that honestly.** Its
`forbidden_capabilities` entry names its instrument as *provenance-only*, matching the Makefile's own
note. Recording a weaker instrument as weaker is the point of requiring an instrument at all; a
future item closing the Env pair should update this string.

**C5. A10's acceptance line should name the mutation tests.** Three of this item's guards are
structural and a structural guard that never fires is the defect the item is about. All three were
mutation-tested in-session (table correction → red; fixture drift → red; omission drop → red) and the
results are in the table above. A13's line should carry the same requirement for its manifest
consumption.

---

## For A13

- `driver_only()` is the definition; `validate_driver_only(loading_against, discovered, calls,
  catalogue)` is the whole load gate in one call.
- `driver_only_manifest(source_revision, toolchain, abi_version, normalized_configuration,
  classifier_2_set, unrouted_fields, scan_root_commit)` builds the per-run manifest; everything
  readable from an artifact is read inside it, and the derived classifier sets are arguments because
  the tool derives them per run.
- `replay_metadata_of(manifest)` projects A9's `ReplayMetadata` from the manifest rather than
  restating it — use it, so a result cannot carry a profile id that disagrees with its manifest.
- `routing_violation_at(...)` is the guard to call at the dispatch site once the profile is
  established. It is `Option[DstResult]`; `None` means proceed.
- The measured inventory and the classifier-2 call set are **arguments everywhere**. Do not
  hardcode them; `tools/profile_definition/check_fixtures.py` is the pattern for keeping a
  necessarily-copied one honest.
