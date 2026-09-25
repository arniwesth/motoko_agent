# Closeout: declare the chunk draw range (WI-1 route B, cluster A)

**Status:** Closed 2026-08-17. Four commits, `43bafa7`..`188558a`, on
`arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`, from `059dbd9`.
**Closes:** `HANDOFF-declare-the-chunk-draw-range.md` (the implementation discipline) and
`PLAN-resource-growth-relation.md`'s WI-1 route B, sequencing steps 1 and 3.
**Governed by:** `ADR-002-resource-growth-as-a-metamorphic-relation.md` as corrected; D2 (declared
bounds), D8 (version travels with the artifact).
**Toolchain:** AILANG v0.33.0. Every number below was measured in this session against the tree it
describes; none is inherited.
**Companion:** `NOTE-chunk-draw-lever-calibration.md` carries the lever's calibration table and the
three findings WI-3 needs. This note is the implementation record and does not repeat them.

---

## Verdict

Accepted, and the route gate it existed to close is closed **with data rather than with argument**.

The handoff opened with a conditional: route B was the recommendation but not yet chosen, and
*"if the route is still open, this cluster is the thing that closes it."* Route B's whole claim is
"the drawn values do not move, so no digest moves, so no `generator_version` bump is owed." That is
now a measurement:

| claim | evidence |
|---|---|
| no new red | `make dst` at every commit: **the same seven reds as the `059dbd9` baseline, identical list** |
| no digest moved | `seeded_generator` axis K green at **both** pinned versions — zero `generator-choices-remapped-without-a-version-bump`, zero seed-remapped, zero trajectory-reshaped across the whole sweep |
| #160 stays covered | `make depth_canary` PASS, all four rows, pins unmoved at 79/126/96 |
| core intact | `make check_core` 57/57 |
| the lever is real | records **1.65× / 1.71× / 1.82×** on seeds 7/11/23 with the trajectory held fixed |

So route A's price — six pinned digests, an 11-member corpus re-selection, and a D8
`generator_version` bump that re-rolls every seed through `seed_state` — was **not paid, and did not
need to be.** Route B cost a program-schema version bump and one expression.

---

## What landed

| commit | subject | churn |
|---|---|---|
| `43bafa7` | plumbing: the field, 17 literals, both codecs, `execution-program/2` → `/3` | 17 files, +458/−63 |
| `821e425` | the switch: `bounded_draw(…, 0, g.bounds.chunk_draw_hi, …)` | 1 file, +8/−1 |
| `8e316d2` | the lever: `CG_EXPORT_CHUNK_DRAW_HI`, opt-in, off by default | 4 files, +201/−20 |
| `188558a` | the plan and handoff committed; three stale ADR-002 pointers | 3 files, +778/−10 |

The three-way split was the handoff's and it earned itself. Commit 1 changes bytes and no behaviour;
commit 2 changes behaviour and no values; commit 3 is the first where a number is allowed to move.
Each was swept independently, so "commit 2 moved nothing" is an isolated observation rather than an
inference from a combined diff — which is the only reason the route verdict above is worth anything.

`188558a` was not in the handoff's scope and is explained in its own message: the three commits cite
the plan as their design record and the plan was untracked, which is the defect `059dbd9` was itself
a commit about fixing, one document further along.

---

## Planned surface versus landed surface

Per `../../meta-decisions/compare-speculated-end-state-to-actual.md`: the handoff's speculated
end-state for this cluster was a **site count and a work ratio**, so that is what gets compared.
Differences are classified, not scored.

| | handoff predicted | landed | classification |
|---|---|---|---|
| sites naming the field | 20 | 20, exactly | **confirmed** — the grep was right |
| record literals to edit | 17 | 17, plus 1 new record the migration required (`bounds_before_v3`) | **plan under-specified**, harmlessly |
| type declaration | 1 | 1 | confirmed |
| JSON reader | 1 | 1 | confirmed |
| positional decode | 1 | 1 | confirmed |
| files carrying the sites | 14 `.ail` files | all 14 touched, none missed | **confirmed** |
| files touched in total | not predicted | **18** non-`.agent` files | **plan blind spot**, below |
| new functions | not predicted | **13** | plan blind spot |
| existing signatures changed | not predicted | **6** | plan blind spot |
| schema bump confined to `dst_program` + `dst_persistence` + one fixture | yes | **yes for files, no for shape** | see "more than a decode path" |

**The two files the plan did not list**, both of which had to move and neither of which a
`max_chunks_per_interaction` grep could find:

- **`Makefile`** — the `program_persistence` fixture-presence guard enumerated only v1 and v0, so a
  new fixture would have had no presence gate at all, and its no-regeneration grep keyed on
  `v{0,1,2}_fixture_path`. Both now cover v3. The v2 gap was pre-existing and is fixed in passing.
- **`scripts/dst/run_depth_canary.sh`** and **`.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`**
  — both asserted, in prose, that the generator *has no records-per-step lever*. This cluster is
  what made those sentences false, so this cluster corrected them. WI-5 still owns ADR-002's
  Corrections section and its `Decision` body.

---

## The three traps: held, and what each actually cost

The handoff named three rules the session would break by accident. All three were real; two were
cheap once named, and one changed the shape of the work.

**1. Append the field, do not put it where it reads best.** Held. `GeneratorBounds`' record order
now matches the serialized line order deliberately, so the two cannot be read as disagreeing, and
the index-shift failure mode is written out at the encode site. Cost: a comment. **This was the
cheapest trap and the most expensive one to have got wrong** — the failure is silent, because
`int_at` answers `0` for anything it cannot find, so a v2 artifact would have decoded
`max_payload_bytes` as `chunk_draw_hi` and produced a legal-looking program that is not the one
recorded.

**2. The draw range and the declared bound are two quantities.** Held. `canary_bounds_tight` is now
the one record in the tree whose `chunk_draw_hi` is deliberately **not** tightened, and it says so
in place, next to the four fields that are. Collapsing them would have deleted a pinned path:
`bounded_draw` records a `BoundFailure` only when the draw *exceeds* the limit, and the tight canary
declares a limit of 1 against a 0..3 range precisely so that clamp fires into `failures_text`, which
`canary_walk` folds into the pinned digest. The canary would then have gone green the moment someone
re-pinned. Cost: a comment on each of the two records, and one deliberate non-edit.

**3. The wider range is opt-in or `depth_canary` reddens.** Held, and verified four ways rather than
one: knob unset **and** knob unparseable both report 79 records on seed 7; the default write path
still writes its trace; and a widened write-path run refuses, loudly, and wrote **0 files**. The
"unparseable falls back to the default" branch was not in the handoff and is there on purpose — a
typo in a bisection harness must not silently produce a narrower run than the one that was asked
for.

---

## The one place the plan's pricing was wrong: "machinery that already exists"

The plan chose route B over route A partly on this sentence: *"the format version axis is machinery
that already exists and already carries two live versions."* True, and it still justifies the
choice — but the handoff's stop-and-report #2 asked specifically whether the bump *"turns out to need
more than a decode path."* **It did.** Reported here rather than mid-flight, because the answer did
not change the route and none of it was expensive:

1. **`required_header_tags()`'s arity for `bounds` is version-dependent.** `parse_line` checks arity
   strictly, so a table saying six would refuse every frozen v2 specimen with `WrongArity`. The
   decoder now takes its required-tag table from the **artifact's** version
   (`required_header_tags_at`), computed once in `decode_body` and threaded down.
2. **`check_bounds_line`'s integer-field count is version-dependent** for the same reason — reading
   six fields off a v2 line reports the absent sixth as `NotAnInteger` rather than as the default it
   is.
3. **`parse_line` and `parse_lines` had to grow a parameter.** The table is passed in rather than
   derived per line, because those functions run once per line and rebuilding a nineteen-entry table
   inside each of them would put nineteen interpreter frames inside every line of a decode — which
   is the exact cost class this whole project exists to police.
4. **The frozen-specimen surface grew a tier, and the strict assertion had to MOVE.** WI-D22
   asserted byte identity for v2 and only informed about it for v1, on the explicit ground that *"the
   v2 bytes were frozen BY this encoder."* The bump makes that false. So v2 joins v1 as an artifact
   predating the encoder and reports a byte difference as the permitted backward-compatible change
   it now is, and `execution-program-v3.artifact` carries the strict assertion. **Weakening the v2
   row without re-homing the assertion is how a compatibility gate becomes prose**, and the check
   that the pair is complete is that the strict row now sits at the version
   `program_schema_version()` returns.
5. **`specimen_ints()`' pairwise-distinctness row forced a record split.** `chunk_draw_hi` could not
   be 3 in `specimen_bounds()` — it is 20, the gap in the 18/19/21/22 run — because a codec that
   writes one field and reads another round-trips perfectly when the two are equal. But the frozen
   bytes *mean* 3, so `bounds_before_v3()` exists, mirroring WI-D22's `frozen_v1_world` /
   `specimen_world` split one layer down and for the identical reason: **a field added after a
   freeze cannot be in the frozen bytes.**

**The generalisable lesson, and it is a candidate meta-decision rather than one I have filed:**
a field-name grep finds a positional codec's *producers and consumers* and is blind to its
*validators*. Arity tables, field-count checks, distinctness assertions and frozen-bytes comparisons
all constrain the new field without naming it. On a schema surface, count the validators separately
or the judgement half of the estimate is wrong by a factor.

Checked and **negative**, recorded so nobody re-derives it: the schema bump does **not** strand the
on-disk generated corpus store. `PersistCollision` would have fired on every stale v2 artifact, but
`corpus_pr`'s own recipe already `rm -rf`s `.ailang/dst-corpus` before each run.

---

## The calibration ask, answered

The handoff asked three questions. `../../meta-decisions/sequence-implementation-handoffs-by-source-surface.md`'s
calibration clause is why: *"that ratio is what the rest of the schedule rests on; discovering it is
wrong is worth far more early than late."* It is wrong.

### 1. Time, split mechanical versus judgement

**The 17:5 assumption is wrong in shape, not just in magnitude.** The 17 mechanical literal edits
were ~10 minutes and were exactly as advertised — one scripted pass with a per-site assertion that
each pattern matched once. The "~5 sites needing judgement" was really **~14**, and four of them were
invisible from the handoff: the arity table, the per-line arity check, the byte-identity assertion
having to move, and the distinctness-forced record split. Judgement was roughly **85%** of the
session's working time, against the ~25% the ratio implied.

**Read the rest of the plan's schedule as closer to 1:6 than 17:5** — and specifically, read *"17
mechanical, ~5 needing judgement"* as a count of *sites the field's name appears in*, which is a
different quantity from *decisions the change forces*.

Wall-clock is not a useful figure to carry forward from this session, because five full `make dst`
sweeps at 260–367s each dominated it and are a property of the acceptance bar, not the work. **Budget
one sweep per commit plus a final one: ~5 minutes each, and they are the schedule's real unit for
any cluster whose acceptance is "no new red."**

### 2. Files actually touched

Grounded by diffing the file set the handoff's own grep predicted at `059dbd9` against the file set
the three code commits actually changed:

- **14 `.ail` files** carry the 20 predicted sites. **All 14 were touched. None was missed, and none
  turned out not to need the edit** — the surface count was exact.
- **18 non-`.agent` files** changed in total. The four beyond the grep's reach: `dst_program.ail`
  (named by the handoff for the schema bump, invisible to a `max_chunks_per_interaction:` grep
  because its mention has no colon), the new v3 fixture (asked for), and **`Makefile` +
  `run_depth_canary.sh`, which nothing in the plan or handoff anticipated.**

**The schema bump stayed inside `dst_program.ail` + `dst_persistence.ail` + one new fixture for
files** — the prediction held — **but not for shape**, per the section above. The
`program_persistence_dst.ail` diff (+183) is the largest single file change in the cluster and almost
none of it is the field: it is the compatibility-tier rearrangement the bump forced.

### 3. Was commit 2 value-neutral in fact?

**Yes, and this is the cheapest real evidence anyone will get about how much of this codebase a
"no-op" change actually moves.** One expression, `+8/−1` including its comment. Zero canary findings
at either pinned version. Record counts unmoved at 79/126/96. The full sweep produced the identical
seven-red set. Value-neutral by reading, too, and the reading is the part worth keeping:
`draw_between(g, s, lo, hi)` consumes exactly one `draw(g, s, hi − lo + 1)` whatever `hi` is, so at
`hi == 3` the mixed state, the draw count and the returned value are the same three numbers they were
when the 3 was a literal. **A codebase where that argument can be made by reading one function is a
codebase where this class of change is cheap**; the sweep was confirmation, not discovery.

---

## What is still open

- **`anchors` and `attribution_table` remain red**, untouched, exactly as the handoff instructed.
  Five pinned `src/core/session.ail` line anchors no longer name a routed core clock site, from the
  #160 fix's own line drift. The repair is a D4 judgement that re-issues three profile versions
  across eleven files, and it belongs to whoever lands #160. **It is not this cluster's, and putting
  it inside a commit about generator bounds is precisely what it should not be.**
- **The five `agentcli` reds** are `.agent/projects/017_extension_handling/`'s subject.
  `ailang.lock` is still uncommitted at HEAD; left alone.
- **`make dst` exits 2 on a clean tree.** Cluster A neither caused nor fixed that, and "no new red"
  remains a judgement against a seven-item list rather than a check against zero. The plan's §5.2
  gate — whether the baseline is repaired first — is still the operator's and is still open.
- **`DST_KNOWN_RED` lists two targets that now pass** (`test_coverage`, `test_coverage_selftest`).
  The sweep summary says so on every run. One-line Makefile edit, nobody's cluster, worth doing
  before the list teaches a reader to ignore a real failure.

## What the next handoff owes

Per the sequencing meta-decision, the WI-2/WI-3 handoff is written **against the tree this cluster
leaves**, not against `059dbd9`, and its anchors must be re-observed — every file it will cite
(`dst_generator.ail`, `dst_persistence.ail`, `export_trace.ail`, `dst_program.ail`) moved here.
Three things it should carry that this session learned:

1. **The lever's driving instructions and its non-monotonicity**, from
   `NOTE-chunk-draw-lever-calibration.md` §1 and §4a. A WI-3 bisection harness that orders scale
   points by knob value rather than by measured record count will pass an invalid `lo`.
2. **Its own trap, found deliberately.** For WI-3 the candidate is Correction 10's: any measurement
   of the fault-present column must un-do **both** halves of the #160 fix, and un-doing only the fold
   measures nothing. That is the distinction a builder would naturally collapse.
3. **A corrected work ratio**, per the calibration answer above — and its own calibration ask back,
   because one cluster is one data point.
