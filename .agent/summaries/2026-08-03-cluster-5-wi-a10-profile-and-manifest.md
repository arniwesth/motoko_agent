# 2026-08-03 Cluster 5: WI-A10 — the profile definition, the execution manifest, and `driver_only` v1

## Context

Branch: `arniwesth/mot-50-execute-wi-a10`

Session span: `d57ca4c` → `7654b29`, **3 commits**, two of them production source. (The branch
continued past this session's work with `777edbe` and `8cef7a6` — A13's plan row updated to inherit
A10's exports, and the cluster 7 handoff written. Both build on what is recorded here.) Input was
`HANDOFF-execute-a10-profile-and-manifest.md`, executed cold against HEAD. Sixth code session of
project 009, following clusters 1, 4, 6, 3 and 2.

**This was the last item before A13, and Milestone A's independent work is now complete.** Every
input A10 needed existed at HEAD: A4's call inventory, A5's attribution table, A6's coverage rules,
A7's fault catalogue, A8's event vocabulary, A9's result types.

Re-grounding first: `git diff --stat 86a46e6..HEAD -- src packages scripts Makefile` was empty, so
the handoff's input table held without re-measurement.

**This is the first calibration run on *composition* work** — a fourth kind after
widen-and-converge (clusters 1, 4, 6), constructed artifacts (cluster 3) and detectors (cluster 2).
It needed a fifth sizing model, and the judgement-ratio predictor needed splitting.

## What landed

| Commit | Item | Gate |
|---|---|---|
| `fd4f4bd` | **the machinery** — definition, manifest, exclusion check | `make profile_definition` |
| `dafe898` | **`driver_only` v1** — the first conformant profile | `make driver_only` |
| `7654b29` | report + propagation | plan, ADR, S6 |

Committed separately as the handoff required: the machinery is reusable and the profile is one
instance of it, and **a reviewer needs to see the validator reject before seeing the definition that
passes it.**

Both targets are in `make dst` and in CI. `make check_core` is green (41 modules). The full artifact
set — `profile_coverage profile_definition driver_only fault_catalogue event_vocabulary
attribution_table terminal_trace ext_call_inventory_selftest` — exits 0.

New files: `src/core/dst_profile.ail` (1559), `src/core/dst_driver_only.ail` (353),
`scripts/dst/profile_definition_dst.ail` (574), `scripts/dst/driver_only_dst.ail` (274),
`tools/profile_definition/check_fixtures.py` (165).

## The two decisions, which are the item's durable output

Cluster 2 declined both deliberately, as scope questions rather than wording. Both are now taken and
recorded in three places — the plan, the ADR, and the source that implements them.

### Decision 1. An unrouted *reachable core* site IS conformant — when DECLARED and INSTRUMENTED

Routing completeness is all-or-nothing over `{routed} ∪ {declared-and-instrumented}`. Three
rejections, and the third is what makes it a set check rather than a rubber stamp:

- `unrouted-site-undeclared` — reachable, unrouted, and not declared;
- `unrouted-site-without-instrument` — declared with a blank instrument;
- `declared-site-not-reachable` — a declaration for a site that is no longer reachable-and-unrouted,
  so a site that gets routed or moves cannot leave a stale declaration reading as if the gap were live.

**The strict reading was rejected on three grounds, not one.**

1. It makes conformance unachievable at HEAD **by construction**. `session.ail:796` cannot be routed
   on the pin at all — `ExtPorts.clock_now` is zero-argument and AILANG has no zero-arg lambdas in
   expression position. Under the strict reading no profile ever loads, D5's machinery is vacuous
   until Milestone B's ABI major, and A13 has no profile to consume.
2. **It inverts S2**, which deliberately chose the ambient read over a frozen snapshot precisely so a
   future caller trips a gate. A conformance rule that punishes the loud option — and would have
   rewarded the silent frozen cursor, invisible to every gate — reverses the rule that produced the
   site.
3. It makes A5's `routed` flag dead. A flag no conformant profile may ever set to `false` states
   nothing.

**Why it is not a loophole: the instrument is real and already green.** `make world_state` runs the
Clock poison *pair* — the deterministic entry point completes with `Clock` withheld (so it reaches
neither site) and the live world dies with it withheld (so the first half is not vacuous). That is
*stronger* than a routing claim: it demonstrates non-reach rather than asserting routing.

**The sub-question is answered the same way rather than scoped away.** `stub_step.ail:146` sits
inside `live_ports`, which is not the adapter a deterministic run binds — so it is tempting to say it
is not in the reachable set at all. Rejected: D4's "profile-reachable" is **installation-scoped, not
execution-scoped**, and carving it out on execution-scope grounds would put a fail-open exception
into an installation-scoped rule that would have to be re-litigated for every future site.
**One rule, two sites, no exceptions** — and the profile's declaration for `:146` says so at the
site, not only in the report.

*The handoff's stop-and-report condition was not triggered:* decision 1 resolves to "conformant", so
`driver_only` is conformant at HEAD.

### Decision 2. The routed-set claim is COMPUTED; no count is recorded anywhere

`routed_set_claim` derives the partition from `reachable_core_sites(installed)` at the revision the
profile binds. **At HEAD: 7 reachable = 5 routed + 2 declared-unrouted.** Every assertion on it is a
*partition* assertion, never a comparison against a literal.

**This was not hypothetical. P4 says "a reachable clock set of the four driver sites", and four is
wrong at HEAD** — A12 routed a fifth site (`tool_phase.ail:342`) and A5 declared the two unrouted
ones. Writing `4` into the profile would have type-checked, validated, and been silently wrong.
**That is P3's `4 / 12 / 13` defect recurring one artifact later**, which is the evidence that P3
names a standing hazard rather than a one-off. P4 is corrected.

## The composition defect: where it was waiting, and what caught it

The handoff named the canonical instance. It was live, and two more were.

**1. The seven/one dispatch split.** The obvious way to write the "each unconditional slot excluded
is rejected" sweep is to list the slots. Listing them from D5's older prose gives six, the sweep
passes against its own six-list, and a profile excluding `on_describe_tools` loads clean and then
fails closed on the first model step. **What caught it: the sweep iterates `all_hook_slots()`,
consults `hook_dispatch` per slot, and asserts `seen == 7`.** No number is written down; the seven is
derived over the artifact, so a ninth slot or a changed dispatch kind is picked up without an edit.

**2. P4's "four driver sites"** — caught by decision 2. Both readings type-check.

**3. The `ProfileDefinition` field-count guard.** I wrote `14`; `awk` said `15`. A wrong constant in
a structural guard does not fail to compile — the guard just becomes wrong in the fail-open
direction. Caught by running it, which is the only thing that catches it.

**Nothing else admitted two type-checking answers with a silent wrong one, and that is because of a
policy taken once rather than a check applied many times:** every fact readable from an artifact at
runtime is read. **Twenty of the twenty-three cross-artifact bindings are reads.** The three that
could not be read are where all the risk went.

### The three recorded bindings, and what stands behind each

| Binding | Why not readable | What keeps it honest |
|---|---|---|
| the attribution table identity | recording it is the *point*; calling `table_identity()` makes the check a tautology | literals in `dst_driver_only.ail`, compared against the live pair at load |
| classifier 2's membership + unrouted sets | derived from source by a Python tool, not declared in AILANG | `check_fixtures.py` re-derives both and fails on disagreement |
| which installable extensions call a classifier-2 field | same, plus it needs `ailang.toml`'s install-eligible set | the same guard asserts every installable caller is **omitted by name** in the profile |

**All three were mutation-tested in session and all three go red:** correcting a hashed field of the
attribution table (a `reviewer`) → red; dropping `proc_exec` from the fixture → red; renaming
`driver_only`'s `compaction_ai` omission → red.

**D4's re-issue rule is now mechanical rather than aspirational.** `validate_at_load` catches a stale
source-revision *binding*; it cannot catch a table whose rows changed at the *same* revision, because
it has no idea what the profile recorded. The mutation test does exactly that and is caught only by
the identity comparison.

**The third guard is the one that will earn its keep.** `driver_only`'s omission list is otherwise a
guess frozen at authoring time; with the guard, the day a second extension calls a state-threading
seam the target goes red instead of the profile quietly claiming coverage it lacks. It is scoped to
`[extensions] packages` entries deliberately — the tool also finds a call site in
`motoko_ext_conformance/fixtures`, which is not installable and must not force an omission.

## Sizing: composition is a fifth model, and its unit is the INPUT ARTIFACT

**MEASURED: ~30 min, 9 files (5 new), 2925 lines, 77 sites of which 26 needed judgement — 34%.**

**Round trips: 4, all loud.** Three on the machinery (empty import selector `as X ()`; a cons pattern
with a constructor head; a record literal in cons position) and one on the profile. Every one a parse
error with a line number. **Zero silent defects in the code** — both AILANG modules passed their
inline tests on the first green compile (30/30 and 6/6), as did both acceptance scripts on their
first run.

### Why S4 and S5 both mispredict this

S5 prices a detector by round trips weighted for loudness. Four loud round trips price at near-zero,
so **S5 predicts minutes and it took thirty.** S4 prices a constructed artifact by discovered rows —
which prices the `driver_only` half correctly (19 content rows, ~3.5 min) and the machinery half at
nothing.

**Neither prices what dominated: reading the inputs well enough to know what not to re-derive.**
Roughly **15 of the 30 minutes was grounding** — five artifacts' exports, D5 in the ADR, WI-A10 and
P4 in the plan, plus running the A4 tool and the attribution script to see their live output. S4 and
S5 both assume you already know the source you are working in. **Composition does not: its whole job
is to be correct about somebody else's artifact.**

Landed as a new standing rule:

> **S6. Size a COMPOSITION by the number of INPUT ARTIFACTS whose exports must be read before a line
> can be written — roughly 2–3 minutes each — plus its RECORDED bindings, which are the only ones
> that cost anything after that.** A read binding is free; a recorded binding is where the item's
> entire risk lives.

This predicts what S5 would not: **a composition with many inputs and no recorded bindings is cheap
regardless of size**, and one with a single input and three recorded bindings is not. Site count
predicts neither — 2925 lines at four round trips.

### The judgement ratio came in at 34% against a ~16% prediction, and the metric needs splitting

**The prediction was right about what it was measuring.**

| | Sites | Judgement | Ratio |
|---|---|---|---|
| the machinery (rules) | 58 | 8 | **14%** |
| `driver_only` (content) | 19 | 18 | **95%** |
| combined | 77 | 26 | 34% |

**The machinery half came in at 14% — below A6's 16%, so the three D5 amendments DID settle what
they appeared to.** Every rule arrived as a read and cost nothing. The eight judgement calls are the
two decisions plus six shape choices.

**The 95% is not a specification failure and no amendment could have reduced it.** D5 says "record
the profile's adapter/parser boundaries, resource models, diagnostic projections, forbidden
capabilities". *Which* boundaries this profile has is a fact about the driver, discovered, not
determined. That is an S4 cost sitting inside a composition item.

**Correction carried to A13:** the judgement ratio tracks how much the spec leaves undetermined
**about the RULES**, and is a clean signal only for an all-rules item. For an item shipping machinery
*and* an instance, report the two separately — a combined number reads as "the spec was vague" when
the truth is "half of this item was content, and content is never in the spec."

## Corrections propagated

**Plan** (`PLAN-implementation-deterministic-test-world.md`):

- **P4 amended** — "the four driver sites" is wrong; the claim is computed, 7 = 5 + 2.
- **Both decisions recorded in full** under WI-A10's decision list, with their reasoning.
- **S6 added** to the standing rules, with the judgement-ratio corollary.
- **WI-A10's acceptance line** now requires each structural guard to be **mutation-tested**, and
  records the exclusion check's un-threaded call site as a scope judgement rather than a gap.
- **The three added D5 fields** named, for A13 and C5 to carry.

**ADR** (`ADR-001...`), D5 amended:

- D5's **ten definition fields are not decidable as stated**; three more are required —
  `unrouted_reachable_sites` (decision 1), `scan_roots` (obligation 2's roots), and
  `exercised_fault_classes` (D3's waiver complement is not recoverable from the waiver list alone).
- **The ten fields are TWELVE record fields.** Id/version is one field and two records; field 2
  (extension ids *and* per-hook classifications) is two records, with field 9's disclosure a third.
  An implementer counting ten merges the disclosure into the classifications and loses the
  distinction the disclosure exists to carry.

`make predicate_anchors` stays green — the amendment is not a normative statement of the predicate.

**Confirmed, not corrected:** cluster 3's "four non-vacuous fields for an empty install list". All
four carry real content in `driver_only`; no fifth was found, so that stop-rule is not triggered.

## Scope: one judgement stated rather than buried

**The runtime exclusion check is built and tested but its call site is not threaded into the dispatch
folds.** `routing_violation_at` returns A9's `RoutingViolation` with the interaction position and
partial trace, and is tested for the violating case, the **non**-violating case (a guard that failed
closed on everything would pass the first test and break every run), and the vacuous case.

What it is not is *called* from `fold_prompt_hooks` and friends. Threading a profile there needs
either a field on `ExtRuntime` — which lives in the ABI package, so a Milestone B change — or a new
parameter through every fold. At HEAD there is no consumer: the load-time rules mean the only slot a
conformant profile may exclude is the one gated slot, and no profile excludes it. **A parameter with
no consumer is the dead-rider cost P2 rejects.** A13 establishes the profile and is where the call
lands; C5 is the first profile that makes it non-vacuous. Recorded in the plan's acceptance line so
it is a decision on the record and not a missing row discovered at the gate.

**The D6.6 complement cannot be asserted from inside.** A raw capability bypass must stay a non-zero
run rather than become a typed value; on the pin a denied effect terminates evaluation, so a passing
script cannot observe it. `make world_state` and `make terminal_trace` assert it from outside, and
the acceptance script *prints* this rather than silently omitting it.

**Not built, deliberately:** discovery/replay/programs (A13's); the interprocedural
attribution-necessity validator (D4 leaves it unbuilt; necessity rests on the recorded named reviewer
as a stated exception, and the ADR withdrew one mechanical attempt); widening `ExtPorts` (Milestone
B's ABI major); a second profile (WI-C5, needs B2).

**The scan-root gate exists and its exposure is nil**, as anticipated. Every `[extensions] packages`
entry is a path dependency under `packages/`; `ailang.toml:9`'s registry-resolved `sunholo/logging`
is outside the roots but is a library, not an extension. The fixture is built anyway, and the guard
additionally fails if an installable extension ever loses its path dependency.

## For the next session (A13)

Now written up as `HANDOFF-execute-a13-discovery-and-replay.md` (`8cef7a6`). The exports below are
what A13 inherits.

- `driver_only()` is the definition; `validate_driver_only(loading_against, discovered, calls,
  catalogue)` is the whole load gate in one call.
- `driver_only_manifest(source_revision, toolchain, abi_version, normalized_configuration,
  classifier_2_set, unrouted_fields, scan_root_commit)` builds the per-run manifest; everything
  readable from an artifact is read inside it.
- `replay_metadata_of(manifest)` **projects** A9's `ReplayMetadata` rather than restating it — use
  it, so a result cannot carry a profile id that disagrees with its manifest.
- `routing_violation_at(...)` is the guard to call at the dispatch site once the profile is
  established. `Option[DstResult]`; `None` means proceed.
- **The measured inventory and the classifier-2 call set are arguments everywhere.** Do not hardcode
  them; `tools/profile_definition/check_fixtures.py` is the pattern for keeping a necessarily-copied
  fact honest.

## Traps confirmed

`ailang iface` still cannot parse this repo's package files (MOD010, filed upstream
`fb_6c81854baf59b316`) — not needed; classifier 2's approach was used instead. Pin is v0.26.0.
Three pin-level parse limitations cost the item's only round trips, all loud: an empty import
selector `as X ()` is rejected, a cons pattern cannot take a constructor as its head
(`Ctor(x) :: _`), and a record literal cannot sit in cons position without a `let` binding.
