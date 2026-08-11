# 2026-08-03 Cluster 11: WI-A13 stage 5 — regression replay and D8's generator canary

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `15c2e1a` → `7c82b09`, **4 commits**, two of them production source. Input was
`HANDOFF-execute-a13-stage-5-regression-replay-and-canary.md`, executed cold against HEAD. Eleventh
code session of project 009, following clusters 1, 4, 6, 3, 2, 5, 7, 8, 9 and 10.

Re-grounding first, as the handoff instructed: `git diff --stat a9257a2..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**Full completion of the stage** — the first WI-A13 session since cluster 7 that was not a partial
stop. Both pieces of the mission landed.

| | |
|---|---|
| Stage 1 — types + pure structural validator | landed (cluster 7) |
| Stage 2 — discovery recording against `driver_only` | landed (cluster 8) |
| Stage 3 — strict replay | landed (cluster 9) |
| Stage 4 — the seeded generator | landed (cluster 10) |
| Stage 5 — **regression replay + D8's generator canary** | **landed, green** |
| Stage 6 — D8 persistence obligations | not started |

## What landed

| Commit | Item | Gate |
|---|---|---|
| `177d0cb` | **regression replay** — D2's second mode, the demotion set, axis J | `make strict_replay` |
| `be8393c` | **D8's generator canary** — pure, pinned, axis K | `make seeded_generator` |
| `b7d91d3` | execution report + three corrections | note |
| `7c82b09` | propagation: S8's complement, S6's fifth data point, site 22 for stage 6, A15's filter | plan |

No new files. Modified: `src/core/dst_replay.ail` (+422, now 1294), `src/core/dst_generator.ail`
(+542, now 1507), `scripts/dst/strict_replay_dst.ail` (+151), `scripts/dst/seeded_generator_dst.ail`
(+90), `Makefile` (+12).

**`make dst` exits 0** on the committed tree, read as an exit status per cluster 7's process
amendment — **403 checks, 16 of them new** (387 at stage 4). The single `✗` in the log is the
`✗ Failed: 0` summary label of a passing `ailang test` run, checked rather than assumed. `make
check_core` exits 0, 46 modules. A5 anchors verified intact at the end (`stub_step.ail:161`,
`session.ail` 948/1053/2290/2400); `driver_only` stays at **v3**, since this stage added no
`StepProvider` variant — the handoff's rule held exactly.

## The order the work took

The handoff said to take regression replay first because it is cheaper, ready and independent, so it
converts to a clean stop if the session runs long. **That ordering paid, and not for the stated
reason.** Regression replay was landed and committed *before* the canary's first mutation escape, so
the expensive half ran with a clean stop already banked. This is **S3 applied across pieces rather
than across seams**, and it is the second time the rule has paid.

1. **The demotion set first, alone, before any walk plumbing (S1).** `regression_fatal` plus
   `test_the_demotion_set_is_exactly_the_two_projection_rules`, run green, then **mutated** —
   demoting `UnsafeIdentity` and promoting `OutcomeDiffers`, the exact wrong answer, which keeps the
   count at two. One row red, nothing else. That is the substance of the mode and everything after it
   is a walk that already existed.
2. **The walk**, parameterised by `ReplayMode`, with the correlation chain factored into
   `correlation_mismatch_at` **shared by both modes**.
3. **Axis J** in the acceptance script, over the same five real mutated logs axis E already rejects.
4. **The canary machinery**, then a 260-seed sweep, then the pins — three times, because two
   mutation escapes forced re-pinning.
5. **Axis K**, the sweep script deleted, the docs updated.

## The two results

### S8's first real test, and it earned its place

The handoff asked directly: *"if the canary would have passed under a weaker mutation before you
strengthened it, that is worth reporting."* **It would have.**

The first canary caught 5 of 6 mutants. The escape was mutating what `note_bound` **reports** — a
change to what a bound failure *says*, not to how many there are. Two independent causes:

1. **The trajectory never walked the branch.** One set of generous bounds meant the canary never
   spent its interaction budget and never tripped a limit, so every bound branch was outside what the
   digest could see.
2. **The digest folded a COUNT where the change was in a FIELD** — S7's record-level form, arriving
   on a digest rather than a codec.

Both remedies are structural rather than better assertions: a second walk under bounds tight enough
to bind **for every seed** (`max_interactions: 0`, so branch coverage is a property of the artifact
rather than of the seed), a wide clock bound low enough that the tool's duration draws can actually
reach it (20ms, not the 2000ms a *scenario* would use), and every field of every failure folded in.
**Nine mutants now, nine caught.**

This is a **complement** to S8, not an instance of it. Site 21 was X reaching Y *around* the
mechanism — a decorative path. This is X not reaching Y *at all*, because the mechanism has branches
the assertion never enters. **A pinned artifact certifies exactly the paths its trajectory walks; the
paths it does not walk are not pinned but absent, and absent reads identically to unchanged.** The
decorative path requires an author to write something decorative; the unwalked branch requires only
that they not think of it — so it is the cheaper of the two to fall into. Propagated into S8.

### Site 22 — the generator version is a seed offset

Found by the sweep, while looking for something else (pairwise-distinct pinned quantities).

`seed_state` is `in_range(salt_hash("${id}/${version}") + seed)`: the version hash and the seed are
**added**, so they are interchangeable. djb2's last step is `acc*33 + charCode(c)`, so two version
strings differing only in their final character hash to values differing by that character
difference.

**Measured across all 259 adjacent seed pairs, twice, under two different canary trajectories:**
version `"2"` at seed *s* is **byte-identical** to version `"1"` at seed *s+1* — same initial state,
same draw count, same choice digest. 259 of 259 both times.

| Gate | Verdict against the defect |
|---|---|
| `check_seed_sensitivity`'s `VersionIgnored` row | **green** |
| seed sensitivity (axis A), incl. the anti-count control | green |
| determinism, structural validity, declared bounds | green |
| strict replay over generated programs | green |
| **the canary's cross-version comparison** | **red** |

The `versioned` row compares one seed across two versions and requires the programs to **differ** —
and they do, because v2 at seed 9 is v1 at seed 10. The row is true and weak, and the weakness is
invisible from inside it. Only a check comparing across the **(version, seed) grid** can reach it.

**Reported, not repaired.** The fix is in `seed_state`, remaps the whole stream, and moves stage 4's
searched seeds 9, 13 and 94 — each with an *asserted* reason — requiring a 260-seed census re-sweep
through the real driver. That is a change to a landed stage's fixtures and is the plan owner's call.
It is **pinned instead** by `test_a_version_bump_is_currently_only_a_seed_offset`, a characterization
row that is *supposed to fail* when the defect is fixed, so the finding cannot be lost in a note.

## Three corrections to the plan

1. **The canary does NOT attach at `check_seed_sensitivity`'s `versioned` row**, contrary to cluster
   10's recommendation and the handoff. That row is a **real driver run**; a canary attached to it is
   red on every control-flow change, every request-projection edit, every scenario retune — and a
   canary that cries wolf acquires the regeneration target the handoff's central prohibition forbids.
   The canary therefore consults **no driver at all**, calling the four choice functions directly
   under a fixed adaptive schedule with **constant salts**. The `versioned` row keeps its own job,
   and site 22 is precisely the limit of what it can say.
2. **Regression mode records BOTH demoted differences at a position; strict still records one.** D2
   does not say and both readings type-check. Strict's findings are *failures* and a mutant tripping
   two rules proves neither; regression's are a *record*, and a position whose request and outcome
   both changed, reported as "the request changed", understates the thing the mode exists to report.
   Coarsest-first is preserved exactly where it earns its keep — the fatal chain, in both modes.
3. **The handoff's two structural claims were both exactly right**, recorded because calibration is
   worth as much when the plan is right. *"Stage 3 left the exact seam"* was correct to the line —
   `walk` and `compare_at` needed a mode parameter and nothing else, and the two walk arms needed no
   change at all, because both are fatal in both modes.

## Calibration

**Bindings: five — three decided, two discovered.** Cluster 10's decided/discovered split, used for
the first time as a planning instrument rather than a retrospective one.

- Decided: regression mode records both differences; the canary consults no driver; the canary's
  bounds are its own and there are two sets.
- Discovered: the coverage/count-vs-field boundary (an escaped mutant, twice); site 22 (the sweep).

**Cost ~0.9× stage 4 against a predicted ~1.25× — the first time the count OVER-predicted.** The
cause is legible: the two pieces are independent and one was nearly free. Regression replay carried
two bindings' worth of care and cost under a third of the stage; the canary took ~70%, all of it in
the discovered bindings and the three sweep-and-re-pin loops. **Propagated as an S6 refinement: price
per piece, not per stage, when a stage's pieces do not interact** — summing across independent pieces
averages two things that never meet.

**Round trips: 1 compiler, 2 gate, 2 silent.**

- **Compiler (1).** A missing `import std/string as Str (contains)`. Notably low.
- **Gate (2).** Both are mutant 4 escaping, before and after the first fix.
- **Silent (2).** Site 22, and the count-vs-field blindness. **Determinism caught neither —
  0-for-22 across eleven clusters.**

**Judgement ratio, split three ways** (the figure is the *undetermined* fraction), because this
stage's halves differ more than any previous stage's parts:

- **Regression-replay machinery: ~20%** — the lowest of any piece in this project. D2 fixes the
  demotion set, the handoff restated it as a table, the walk existed. When a specification and a
  handoff between them fix the answer, the work is transcription with one decision in it.
- **Canary machinery: ~60%** — higher than stage 4's ~45%. D8 says the version must travel with the
  artifact and says nothing about how to pin it: not the quantity, not the trajectory, not the
  bounds, not whether a driver is involved.
- **Content, the pins: ~25%** — down from stage 4's ~85%, and the drop is the interesting number.
  Stage 4 *searched for* its fixture; this stage searched **and derived the filter** from S7, D8 and
  site 22 rather than authoring it. Of 260 seeds, 894774 triples qualified; the only judgement left
  was preferring a triple that walks the trajectory extremes — the one axis a filter cannot express.

**The carry-forward:** stage 4 showed a fixture can be a query's answer instead of a design decision.
This stage shows the **filter** can be too. Propagated to WI-A15: state the obligations, derive the
filter from the standing rules, sweep, and prefer among survivors on the one axis the filter cannot
express — so the residual judgement lives in one visible place instead of spread across every pinned
value, which is what a rotating corpus needs.

## What stage 6 should know

1. **The canary is not pinned to the program encoding**, so stage 6 may change that encoding freely
   without false alarms. This was the handoff's third stop-and-report condition and it does not fire:
   the canary digests *decision records*, which are upstream of anything `dst_program` encodes.
2. **`RegressionReplay` is the natural consumer of a persisted program from an older build.** Its
   `differences` field is already typed `ReplayMismatch`, so D11 reporting needs no second projection.
3. **S7's record-level form applies directly to the encoding**, and this stage produced a fresh
   instance of it on a digest rather than a codec.
4. **Site 22 will matter for persistence.** If `(id, version, seed)` is the name a preserved artifact
   is filed under — and D8 says it is — that name is currently **not unique**. Stage 6 must either
   pay the `seed_state` fix and its stage-4 re-sweep, or record the collision as a known property of
   the artifact store. It must not file artifacts under a key it believes to be unique.
