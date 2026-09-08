# Handoff: make the chunk draw range declared — WI-1 route B, cluster A

Date: 2026-08-17
From: the session that authored `PLAN-resource-growth-relation.md` and measured every number in it
For: a fresh session grounded against HEAD
Deliverable: three commits ending in one green state, and a measured records-per-step lever

**This is cluster A of five work items, and it is the only handoff written.**
`../../meta-decisions/sequence-implementation-handoffs-by-source-surface.md` says to write only the
handoff you can ground honestly: cluster A edits `dst_generator.ail`, `dst_persistence.ail`,
`ext_world.ail`, `dst_program.ail` and `export_trace.ail`, which are precisely the files a
handoff for WI-2/WI-3 would cite. Those get written after this lands, against the tree this
session leaves.

**Build this; do not re-plan it.** `PLAN-resource-growth-relation.md` is the spec and its numbers
are measured, not inherited. If you think the plan is wrong, say so as a finding against it rather
than by building something else.

---

## The gate that comes before your first edit

**This handoff assumes route B, and the route is not yet chosen.** The plan's §5.1 is an operator
decision with four options; route B is the recommendation and this handoff implements it.

> **If the operator has picked route A** (widen `dst_generator.ail:600`'s literal), **stop — this
> handoff is void.** Route A is a D8 compatibility event: a `generator_version` bump that re-rolls
> every seed through `seed_state`, invalidating the 11-member corpus bank. It needs its own plan
> and its own handoff.
>
> **If the operator has picked route C** (hook count rather than the generator), **stop — this
> handoff is void**, and C1 additionally needs the exporter to accept a second profile, which is
> its own decision (plan §5.3).
>
> If the route is still open, **this cluster is the thing that closes it with data.** Commits 1
> and 2 are the falsification: route B's whole claim is "the drawn values do not move, so no
> digest moves, so no version bump is owed." Land them, sweep, and the operator has a measurement
> instead of an argument. If they redden anything, route B is off the table and you have saved the
> rest of the plan from being built on it.

## Your task

> Make the chunk draw's range a **declared** quantity that defaults to today's value, so record
> volume becomes a lever, and prove the default costs nothing.

Three commits. The split is deliberate: commit 1 changes bytes and no behaviour, commit 2 changes
behaviour and no values, commit 3 is the first one where a number is allowed to move.

**Commit 1 — plumbing.** Add `chunk_draw_hi: int` to `GeneratorBounds`; every construction site
declares `3`; serialization, JSON codec and validation carry it; `program_schema_version()` moves
to `execution-program/3` with a decode path for `/2`. **No drawn value changes.**

**Commit 2 — the switch.** `dst_generator.ail:600`'s `bounded_draw(…, 0, 3, …)` reads
`g.bounds.chunk_draw_hi` instead of the literal `3`. Still no drawn value changes, and that is
provable by reading rather than by hoping: `draw_between(g, s, 0, 3)` is the same call however the
`3` arrives.

**Commit 3 — the lever.** `export_trace.ail` learns to declare a wider range, **opt-in via
environment, off by default**. This is the first commit where records move, and only under the
knob.

## Read first, in order

1. **`PLAN-resource-growth-relation.md`** — §1 (what route A would have cost, and why you are not
   doing it), §4's WI-1 route B including the schema trap, and §4's *Sequencing*. §2's Corrections
   9–12 matter for WI-3, not for you; read them anyway so you do not "helpfully" restore the
   ADR's claim that the healthy slope is zero.
2. **`ADR-002-resource-growth-as-a-metamorphic-relation.md`** — *Corrections* only. Its body is
   superseded in three places by its own corrections and in two more by the plan.
3. `NOTE-spike-findings-resource-growth.md` §Q2 — the measurement that established the draw range
   is a clamp and not a scale. It is the reason this cluster exists.

You do **not** need the issue record or the substrate note to build this.

## Current grounding

Re-verified 2026-08-17 against `059dbd9`. **Run this first; if any line disagrees, re-measure
before trusting anything below** — these anchors are one session old and
`../../meta-decisions/re-ground-inherited-anchors-before-building.md` applies to them exactly as
it applied to the ones this session found stale.

```bash
sed -n '600p' src/core/dst_generator.ail   # the draw:  bounded_draw(d_arg.state, "${salt}|chunks", 0, 3,
sed -n '513p' src/core/dst_persistence.ail # the bounds header line, five \t-separated fields
sed -n '777,779p' src/core/dst_persistence.ail  # int_at, and its 0 default
sed -n '99p'  src/core/dst_program.ail     # program_schema_version() -> "execution-program/2"
sed -n '119p' src/core/dst_program.ail     # decodable_schema_versions()
sed -n '107p' scripts/dst/export_trace.ail # the exporter's local bounds() literal
grep -h "max_chunks_per_interaction:" $(git ls-files '*.ail') | wc -l   # expect 20
```

**The surface, counted rather than estimated:** 20 sites mention the field. One is the type
declaration (`dst_generator.ail:289`), one is the JSON reader (`ext_world.ail:472`), one is the
positional decode (`dst_persistence.ail:1114`), and **17 are record literals that must each gain
`chunk_draw_hi: 3`** — ten in `scripts/dst/*`, seven in `src/core/*`. Eight further sites read the
field. That ratio — 17 mechanical, ~5 needing judgement — is the estimate the plan rests on and
the calibration ask below asks you to correct it.

**What is already built and must not be rebuilt:** the `CG_EXPORT_PHASE=driver` seam
(`export_trace.ail:334-335`), `make depth_canary` and its two tiers, and the #160 fix. All three
are green at HEAD and verified so by this session.

## The rules you will break by accident

Every cluster has one; this one has three, and the first is the expensive one.

**1. Append the new field to the serialized `bounds` line. Do not put it where it reads best.**
`dst_persistence.ail:513` writes bounds as five positional `\t`-separated fields and
`:1110-1116` reads them **by index**. The natural placement — `chunk_draw_hi` right after
`max_chunks_per_interaction`, where a reader would look for it — shifts every later index, so a
`/2` artifact decodes `max_payload_bytes` as `chunk_draw_hi`, `max_resource_size` as
`max_payload_bytes`, and so on. Nothing complains: `int_at` returns **0** for anything it cannot
find or parse (`:777-779`), so the failure is a legal-looking program that is not the one that was
recorded. **Append at the end, and write the `/2` decode path with an explicit `chunk_draw_hi = 3`
default rather than letting `int_at`'s zero answer it** — zero means "this program never draws
chunks", which is a different program.

**2. The draw range and the declared bound are two quantities. Do not collapse them.**
The obvious simplification is to drop `chunk_draw_hi` and have the draw range *be*
`max_chunks_per_interaction` — it is what the name has always implied and it is one field instead
of two. **It silently deletes a pinned path.** `bounded_draw` (`:429-437`) records a
`BoundFailure` only when the draw *exceeds* the limit; `canary_bounds_tight` (`:925-936`) sets
`max_chunks_per_interaction: 1` against a 0..3 draw precisely so that clamp fires, and
`canary_walk` (`:1087`) folds `failures_text` into the pinned digest. Make the range equal the
bound and the chunk clamp can never fire, the failures text loses its entries, and D2's
bound-failure path stops being certified by the artifact built to certify it — while the canary
goes green again the moment someone re-pins. **The gap between the two numbers is the thing
`bounded_draw` exists to record.**

**3. The wider range is opt-in or `depth_canary` reddens.** Commit 3 is the temptation:
`export_trace.ail:107`'s `bounds()` is a plain literal and widening it there is one character. Do
that and the default export path changes, tier 1's three pinned record counts (79/126/96) stop
matching, and the next move looks like bumping them. **It is not.** Put the wider range behind an
environment knob with today's value as the default, the same shape as the `CG_EXPORT_PHASE` seam
next to it, and the default path stays byte-identical.

## Definition of done, per commit

| commit | runnable check | expected |
|---|---|---|
| 1 | `make check_core` | 57/57 |
| 1 | `ailang check` on each edited module | clean |
| 1 | `make program_persistence` | green, **including** the frozen-v2 row (see below) |
| 1 + 2 | `make dst` | **the same seven reds as the baseline and no others** |
| 2 | `make depth_canary` | PASS, all four rows, pins untouched |
| 2 | `make seeded_generator` | green — axis K reports no `generator-choices-remapped-…`, which is the whole claim of route B |
| 3 | `make depth_canary` | PASS, still 79/126/96 with the knob unset |
| 3 | driver phase at the widened knob, seeds 7/11/23 | records ≥ 1.6× the c=0 baseline of 63/106/88, with decision, provider-call and tool-batch counts **constant across the sweep** |

**Commit 3's last row is the acceptance that matters and it is a two-sided check.** The plan's
whole relation rests on trajectory length being held fixed while records move; the spike verified
this rather than assuming it, and so must you. If the decision count moves with the knob, the
lever is changing the trajectory and the slope it produces would be meaningless.

**The frozen-v2 row will fail before you fix it, and the module tells you what to do.** Adding a
field to the bounds line changes the encoder, so
`scenario_the_frozen_v2_specimen_still_decodes` (`program_persistence_dst.ail:1314`) stops
matching. Its own message is the instruction:

```
✗ THE FROZEN v2 SPECIMEN NO LONGER DECODES: …
    This build changed the encoding without moving program_schema_version().
    Add a decode path and bump to execution-program/3. Do NOT regenerate this file.
```

So: bump `program_schema_version()` to `execution-program/3`, add `/3` to
`decodable_schema_versions()` (`dst_program.ail:119`), keep the `/2` decode path with the explicit
default from trap 1, and freeze a **new** `scripts/dst/fixtures/execution-program-v3.artifact`
beside the existing three. **Do not regenerate v0, v1 or v2** — the module says the response of
regenerating is the one that is not available, and it is right: those bytes are the only evidence
that the encoder has not drifted.

## The baseline is red before you touch it

`make dst` at HEAD exits 2 with **seven** targets red, from two unrelated causes. Neither is
yours, and "no new red" is measured against this list rather than against zero.

**Five are the `agentcli` extension** — `declared_vs_performed`, `driver_plus_compose`,
`driver_plus_no_ops`, `ext_ambient_inventory_selftest`, `ext_hook_scope_selftest`. Signature:

```
FAIL: extension(s) ['agentcli'] are in ailang.toml's [extensions] packages and appear in
      neither this profile's install list nor its omissions.
FAIL YIELD: expected 15 extensions, got 16
```

That is `.agent/projects/017_extension_handling/`'s subject and `ailang.lock` is uncommitted at
HEAD. Leave it alone.

**Two are line drift from the #160 fix** — `anchors` and `attribution_table` are one recipe
(`Makefile:2378`, `:2383`) and one failure:

```
✗ src/core/session.ail:1111 no longer a routed core clock site — the attribution table describes a site that moved
✗ src/core/session.ail:1370 …   ✗ :1476 …   ✗ :2942 …   ✗ :3052 …

An anchor moved. Do NOT re-baseline it without deciding which site is 'the'
attributed one — that is a D4 judgement with other consumers, and correcting
the table re-issues every referring profile — THREE of them since WI-D27
```

**Do not fix this and do not re-baseline it.** It belongs to whoever lands the #160 branch, the
repair re-issues three profile versions across eleven files, and doing it inside this cluster
would put a D4 judgement in a commit about generator bounds. Report it as still open.

## Stop and report rather than deciding

- **If commit 1 or 2 reddens anything beyond the seven.** That falsifies route B's central claim
  and the route decision goes back to the operator with your measurement attached. Do **not**
  re-pin a digest to get green — the plan's guardrail and `run_depth_canary.sh`'s own header both
  say a pin moves as a deliberate act with a recorded reason, and "my change moved it" is a
  diagnosis, not a reason.
- **If the schema bump turns out to need more than a decode path** — a migration, a re-encode of
  stored corpus artifacts, a second fixture tier. The plan priced it as "machinery that already
  exists and already carries two live versions." If that is wrong, the comparison that chose route
  B over route A is wrong with it.
- **If the widened knob does not reach 1.6× records**, or reaches it only by moving the decision
  count. Either way the lever is not what the plan measured and WI-3's threshold — calibrated at
  1.65–1.82× — has no basis.
- **If you find yourself wanting a second profile.** You should not need one on route B; wanting
  one means you have drifted toward route C, which is a different decision (plan §5.3) and
  `export_trace.ail:38-43` says it is argued, not forked.

## Guardrails

- **`make depth_canary` is green at HEAD and must be green at every commit you push.** It is the
  only thing covering motoko_agent#160 until WI-3 lands, and WI-3 is two clusters away.
- **Nothing here retires tier 0.** Correction 10 measured why: restore the frame-per-record fold
  with the fix's name guard intact and tier 1 stays green on all three seeds, because no generated
  world ever calls `MotokoRuntimeStatus`. Tier 0 is the only guard on that function.
- **You are not building the relation.** No slope, no threshold, no new gate in this cluster. If
  commit 3 tempts you into measuring a slope because the data is right there — write the numbers
  into a note for WI-3 and stop.

## Calibration ask back

The plan's schedule past this cluster is reasoned, not measured, and it says so. Report, when you
land:

1. **Actual time**, split between the 17 mechanical literal edits and the ~5 sites that needed a
   judgement. The plan assumed roughly 17:5 and the rest of the schedule rests on that ratio.
2. **Files actually touched**, against the 20 sites counted above — and specifically whether the
   schema bump stayed inside `dst_program.ail` + `dst_persistence.ail` + one fixture, or spread.
3. **Whether commit 2 was value-neutral in fact**, not just in argument. It is the cheapest real
   evidence anyone will get about how much of this codebase a "no-op" change actually moves.
