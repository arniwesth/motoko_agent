# Handoff: execute WI-A10 — the profile definition, the execution manifest, and `driver_only` v1

Audience: a fresh session grounded against HEAD. Implementation is source-heavy work and belongs in
a session that just read HEAD; you are that session.

This is **cluster 5**, and it is the last item before A13. Five clusters have landed (1, 2, 3, 4, 6);
**Milestone A's independent work is complete and every input this item needs now exists.**

**Read the plan's `## Standing rules` first — S1 and S5 both bind here.**

## Mission

Build the profile-definition and execution-manifest machinery, define **`driver_only` v1**, and
install runtime routing's fail-closed exclusion check. One item, but **commit the machinery and the
profile separately** — the machinery is reusable and the profile is one instance of it, and a
reviewer needs to see that the validator rejects things before seeing the profile that passes it.

The plan is your specification — read WI-A10 and decision P4 there, plus D5 in the ADR.

## The rule you will break by accident

**This is the first item whose job is mostly *composition*, and composition's characteristic defect
is re-deriving a fact one of your inputs already computed — where both answers type-check and the
stale one is silent.**

The canonical instance is waiting for you, and it has already bitten this project once. **D5's prose
says six of eight ABI hook slots are unconditionally dispatched. It is seven.** Cluster 3 found the
eighth (`on_describe_tools`, dispatched from `tool_catalog.ail` on every model step, outside the
`ext/runtime.ail` the ADR surveyed) and the ADR is amended — but the wrong number is still readable
in older passages, and a validator built from prose would **accept a profile excluding
`on_describe_tools`, which then fails closed on the first model step.** Both versions type-check.
Nothing but the artifact catches it.

`dst_profile_coverage.hook_dispatch` is the authority: `Unconditional` for seven slots, `Gated` for
`OnToolHandle` alone. **Read it; do not re-derive it. The same applies to every input below.**

Second instance, from P3: **do not record a routed-site count as a constant.** D4's `4 / 12 / 13`
split described a tree that has since moved twice inside one milestone. A5 already does this right —
its completeness check takes the discovered set as an *argument*, never a constant. Any profile claim
must be computed the same way, at the revision the profile binds.

## Your inputs, verified to exist at HEAD

Every signature below was checked while writing this table. **Run
`git diff --stat 86a46e6..HEAD -- src packages scripts Makefile` first; if non-empty, re-verify.**

| Input | Export | Gives you |
|---|---|---|
| A5 | `dst_attribution_table.validate_at_load(loading_against: string, discovered: [CoreSite]) -> [AttributionRejection]` (`:462`) | the whole load-time gate in one call — binding, rows, and completeness |
| A5 | `table_identity() -> TableIdentity` (`:284`) | the `(source revision, content hash)` pair a profile records. **A table correction re-issues every referring profile** (D4) |
| A5 | `reachable_core_sites(installed: [string]) -> [CoreSite]` (`:502`) | unconditional core plus attributed-and-intersecting |
| A6 | `hook_dispatch(HookSlot) -> DispatchKind` (`:109`), `all_hook_slots()` (`:158`), `disclosure_from_ids(ext_id, covered, excluded)` (`:346`) | the seven/one dispatch split and the fail-closed disclosure parse |
| A7 | `required_class_ids()` (`:165`), `conditional_class_ids(rows)` (`:500`), `waiving_condition(rows, class_id)` (`:511`) | P4's waiver list, by stable id |
| A8 | `event_vocabulary_version()` (`:92`) | the manifest's fifth axis |
| A4 | `make ext_call_inventory --json` | `classifier_2_set` (**three** fields), `unrouted_fields`, `member_call_sites`, `unresolved`, per-field rationale |
| A9 | `dst_result` — `HarnessFailureKind` incl. `RoutingViolation`, unreferenced and reserved for you | the typed value the exclusion check returns |

**Classifier 2's set is three fields, not one** — `ai_step`, `proc_exec`, `env_get` — since A12 made
`Ports.tool_exec` and `Ports.env_get` thread successor state. `clock_now` is a distinct **`unrouted`**
state, not a non-member: the ext seam never reaches the port at all (ambient by design under S2, with
the `Clock` poison probe as its instrument). Take the set from the tool's output, which derives it
per run and consults no list.

## The two decisions this item owns

Cluster 2 declined both deliberately, as scope questions rather than wording. **Decide them
explicitly and record the reasoning — do not let the code answer them by accident.**

**1. Is a profile with an unrouted *reachable core* site conformant?** Exactly two exist, both
declared with `routed: false` in `dst_attribution_table.ail` at `:230` and `:232`:

- `session.ail:796` — `ext_unrouted_clock`, ambient **by design** under S2, because
  `ExtPorts.clock_now`'s zero-argument shape admits no world capture on this pin.
- `stub_step.ail:146` — inside `live_ports`.

D4's all-or-nothing routing rule points at non-conformant. **The live sub-question is whether
`stub_step.ail:146` is in a deterministic profile's reachable set at all** — `live_ports` is not the
adapter a deterministic run uses, but D4's "profile-reachable" is **installation-scoped, not
execution-scoped**, and a site in a core module counts under clause 1 whether or not any run reaches
it. That tension is exactly why this is a decision and not a lookup.

**2. `driver_only`'s routed-set claim**, which clusters 2 and 6 both routed toward and neither
recorded. The table now exists, so the scheduling prohibition is discharged. Compute the count; do
not write one down.

## Definition of done

**The machinery, green.** Load validation rejects, each with a fixture and each rejection naming its
rule: an installed extension with zero covered hooks; one with an **unconditionally-dispatched** hook
excluded (all seven, not six); covered/excluded sets not disjoint or not exhausting all eight slots;
an unknown hook id; a stale attribution binding; a discovered core site in neither the rows nor the
unconditional set; an installed extension calling a classifier-2 field with any hook un-excluded; an
installed package whose AILANG source lies outside the recorded scan roots.

**Per S1 and cluster 3's C8, the fixture that matters is the set-completeness one, not the easy one.**
A6's `partial_disclosure` is the shape: both lists disjoint, every id a real slot, **the correct
total entry count**, and one slot classified nowhere. A row-shape validator accepts it; only counting
per *slot* rather than per *entry* rejects it. Carry a **negative control** too — a definition that
must load clean — because a validator that only ever rejects passes a suite of only-failing fixtures
while being useless.

**The definition, green.** All ten D5 fields, distinct from the manifest's list: id/version;
included extensions with per-hook classifications; **included and excluded provider/tool adapter and
parser boundaries**; **logical resource models**; **permitted diagnostic projections**; **forbidden
ambient effects/capabilities**; waived D3 classes with conditions; the attribution-table reference;
per-extension covered/excluded hook **ids**; and **omitted extensions with reasons**. A fixture
missing any one field is rejected **naming the field** — "loads clean" cannot falsify a field the
validator was never told to require. Four are not vacuous for an empty install list; `driver_only`
must name the `compaction_ai` omission and its reason.

**The manifest, green.** D5's separate list: source revision, toolchain, extension package and ABI
versions, profile id/version, event-vocabulary version, normalized configuration — plus both derived
classifier sets and the scan-root commit.

**`driver_only` v1, green.** Empty install list; loads clean; names its omission; its waivers come
from A7's ids; its routed-set claim is computed.

**The runtime exclusion check, installed.** Dispatch reaching an excluded hook returns an in-runner
`HarnessFailure` using A9's `RoutingViolation` (D5, D6.6). Vacuous for `driver_only`, binding from
C5. **Keep it distinct from a raw capability bypass**, which terminates evaluation and returns no
typed value — D6.6 requires the two be distinguishable and A9 already tests them as distinct.

## Out of scope — actively do not do these

- **Discovery, replay, programs** — A13's, and it is the direct consumer of your manifest.
- **The interprocedural attribution-necessity validator.** Unbuilt and unscheduled by D4; necessity
  rests on the recorded named reviewer, a *stated* exception to the automated-gate promise. Do not
  build a mechanical necessity check — the ADR withdrew one attempt and explains why a check that
  fails its own worked example is worse than none.
- **Widening `ExtPorts`** to make `proc_exec`/`env_get` non-members. That is Milestone B's ABI major.
- **A second profile.** `compose`-bearing is WI-C5 and needs B2.

## Stop and report rather than deciding inline

- If decision 1 resolves to "non-conformant", `driver_only` cannot be conformant at HEAD, and that
  is a **milestone-level finding**, not a quiet failure. Report it before working around it.
- If a required D5 definition field has no sensible value for an empty install list, say which and
  why — cluster 3 showed four are non-vacuous, and a fifth would be a finding about D5.
- If the scan-root rule cannot be checked because nothing installs an out-of-root package today,
  build the fixture anyway and say the exposure is nil; the gate is the point, not the exposure.

## Traps

Clear `.ailang/cache` before believing a contradicting type error. Never probe from `/tmp`. `make dst`
and CI both use `--keep-going`; read exit status. `scripts/dst/probe_phase_vocab_sealed.ail` fails at
baseline (`IMP010`, pre-existing, in no target — WI-A17 owns it). Pin is v0.26.0, Makefile-guarded.
**`ailang iface` cannot parse this repo's package files at all** — MOD010, and both fixes its error
suggests are rejected by `iface` itself (filed upstream, `fb_6c81854baf59b316`); if you need parsed
interfaces, use classifier 2's approach, not `iface`.

## Report back

Sixth calibration run, and **the first on composition work** — a fourth kind after
widen-and-converge, constructed artifacts, and detectors.

- **Time and sites**, and which sizing model fit. S4 prices artifact rows by discovered-versus-
  transcribed; S5 prices detectors by round trips weighted for loudness. Composition may be a fifth
  model or may reduce to one of these — say which, and if it is new, name its unit.
- **Judgement ratio**, against the predictor that tracks *how much the specification leaves
  undetermined*. D5's rules are stated and now mostly correct after three amendments, so this should
  come in **low, like A6's 16%** — if it comes in high, the amendments did not settle what they
  appeared to.
- **Whether any site admitted two type-checking answers with a silent wrong one.** For composition
  the characteristic form is the one named above: a fact re-derived from prose that an input already
  computes correctly. Report what caught it.
- **The two decisions, with their reasoning** — those are the durable output of this item, more than
  the code.
