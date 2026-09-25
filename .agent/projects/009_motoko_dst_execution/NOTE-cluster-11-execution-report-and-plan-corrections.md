# Cluster 11 execution report — WI-A13 stage 5, and three corrections

Eleventh calibration run. **Both pieces of the mission landed, green and committed.** Stage 6 —
D8's persistence obligations — is not started and nothing half-built is carried across the stop.

Commits:

- `177d0cb` feat(A13): stage 5 — regression replay, and the rule it may not demote
- `be8393c` feat(A13): stage 5 — D8's generator canary, and the version that is only a seed offset

**`make dst`: exit 0** — read as an exit status. **403 green checks, 16 of them new** (387 at stage
4). **`make check_core`: exit 0**, 46 modules. The single `✗` in the `dst` log is the
`✗ Failed: 0` summary label of a passing `ailang test` run, checked rather than assumed.

No source drift at session start (`git diff --stat a9257a2..HEAD -- src packages scripts Makefile`
was empty).

**A5 anchors undisturbed.** `stub_step.ail:161` and `session.ail`'s 948/1053/2290/2400 all verified
intact at the end; `driver_only` stays at **v3**. This stage added no `StepProvider` variant, and
the handoff's rule — *"a stage-5 edit adding another variant pays the re-issue; one that does not,
does not"* — held exactly. `make predicate_anchors` is inside `make dst` and was green.

---

## What landed

### Regression replay (`177d0cb`)

**`src/core/dst_replay.ail`** — `ReplayMode`, `regression_fatal`, `RegressionReplay`,
`regression_replay_findings`/`_ok`, `regression_report`. **8 new inline rows, 21 total** (13 at
stage 3).

The structural decision is that **the correlation chain is now one function, `correlation_mismatch_at`,
shared by both modes rather than copied into a regression variant.** The alternative arrangement —
a second comparison function for regression mode — is the one in which weakening the identity check
in the regression copy leaves strict mode green and every existing test passing. With one chain, an
edit that lets a differing identity through reddens strict replay's mutation rows immediately.

**`scripts/dst/strict_replay_dst.ail`** — axis J, over the **same five real mutated logs axis E
already rejects**. Both modes read one set of inputs on purpose: a regression mode given its own
quietly different fixtures could disagree with strict mode for reasons having nothing to do with the
demotion set.

### D8's generator canary (`be8393c`)

**`src/core/dst_generator.ail`** Part 5 — `CanaryRow`, `CanaryFinding` (six variants),
`canary_row_from`/`canary_row`, `check_canary`, `check_canary_version_axis`, two pinned tables, and
**6 new inline rows, 21 total** (15 at stage 4). **`scripts/dst/seeded_generator_dst.ail`** — axis K,
6 checks.

No regeneration target, no `--update`, no `ACCEPT=1`, and the sweep script that produced the pins was
**deleted after use** rather than left in the tree as a convenience that becomes a habit.

---

## The result the handoff asked for: S8's first real test, and it earned its place

The handoff said: *"S8 was written from site 21 and this stage's canary is its first real test — if
the canary would have passed under a weaker mutation before you strengthened it, that is worth
reporting as S8 earning its place."*

**It would have, and the mutation is a new shape.**

The first canary was mutation-tested against six mutants and caught five. The escape:

| Mutant | First canary | After strengthening |
|---|---|---|
| `seed_state` ignores its seed | caught | caught |
| one fault-code string changes | caught | caught |
| stream re-phased by a discarded draw | caught | caught |
| the Lehmer multiplier changes | caught | caught |
| `clamp_text`'s threshold moves | caught | caught |
| **`note_bound` reports a different quantity** | **MISSED** | caught |

Two independent causes, and both are worth stating because they are different failures:

1. **The trajectory never walked the branch.** With one set of generous bounds, the canary's
   trajectory never spent its interaction budget and never tripped a declared limit, so every bound
   branch was outside what the digest could see.
2. **The digest folded a COUNT where the change was in a FIELD.** Even once the branch was reached,
   `|F${List.length(failures)}` is blind to a mutation that changes what a bound failure *says*
   without changing how many there are. This is **S7's record-level form** — *a projection that
   ignores a field is blind to exactly the change that field records* — arriving on a digest rather
   than a codec.

Both fixes are structural rather than a better assertion, which is S8's own prescription: a second
walk under bounds tight enough to bind **for every seed** (`max_interactions: 0`, so bound coverage
is a property of the artifact rather than of the seed), a wide clock bound low enough that the tool's
duration draws can actually reach it (20ms, not the 2000ms a *scenario* would use — a limit no draw
can reach is a branch the digest cannot certify), and every field of every failure folded in.

**Nine mutants now, nine caught.**

**The generalisable addition, and it is a refinement of S8 rather than a new rule:** S8 says check
that X cannot reach Y except through the mechanism under test. Site 21's failure was a **decorative
path** — X reaching Y around the mechanism. This one is the complement: **the mechanism has branches
the assertion's trajectory never enters, so X could not reach Y at all.** A pinned digest certifies
exactly the paths its trajectory walks, and the paths it does not walk are not pinned — they are
*absent*, which reads identically to *unchanged*. Recommend S8 gain a second sentence to that effect,
because **A14's latency pair and A15's corpora both have this exposure and it is the cheaper of the
two to fall into**: the decorative path requires an author to write something decorative, while the
unwalked branch requires only that they not think of it.

---

## Site 22 — the generator version is a seed offset, and only this canary could see it

Found by the sweep, not by a check written for it.

`seed_state` is `in_range(salt_hash("${id}/${version}") + seed)`: the version hash and the seed are
**added**, so they are interchangeable. djb2's last step is `acc*33 + charCode(c)`, so two version
strings differing only in their final character hash to values differing by exactly that character
difference — `"1"` and `"2"` differ by 1.

**Measured across all 259 adjacent seed pairs, twice, under two different canary trajectories:**
version `"2"` at seed *s* is **byte-identical** to version `"1"` at seed *s+1* — same initial state,
same draw count, same choice digest. 259 of 259 both times. A version bump is not a new stream; it is
the same stream re-indexed.

**Why nothing else in this project can see it:**

| Gate | Verdict against the defect |
|---|---|
| `check_seed_sensitivity`'s `VersionIgnored` row | **green** |
| seed sensitivity (axis A), including the anti-count control | green |
| determinism (axis J) | green |
| structural validity, declared bounds | green |
| strict replay over generated programs | green |
| **the canary's cross-version comparison** | **red** |

The `VersionIgnored` row compares one seed across two versions and requires the programs to
**differ** — and they do differ, because v2 at seed 9 is v1 at seed 10. The row is true and weak, and
the weakness is invisible from inside it. **Only a check that compares across the (version, seed)
GRID can reach this**, and the canary is the first thing in the project that does.

**Why it matters for D8:** a preserved artifact is named by (id, version, seed), and under this
seeding that name is not unique — an artifact recorded at (v1, seed 4) and one at (v2, seed 3) are
the same program while claiming different generator versions. Reproduction still works. What is
weakened is the version axis itself, in the exact way `VersionDidNotRemap`'s own message describes.

**Reported rather than fixed, deliberately.** The repair is in `seed_state` — mix the identity
through a Lehmer step instead of adding it to the seed, so the two inputs stop being interchangeable.
That remaps the whole stream and moves stage 4's seeds 9, 13 and 94, **each of which has an asserted
reason** (the equal-census anti-count pair; the one S7 fixture in 260 seeds), requiring a 260-seed
census re-sweep *through the real driver*. That is a change to a landed stage's searched fixtures and
is the plan owner's call, not this session's.

**It is pinned instead.** `test_a_version_bump_is_currently_only_a_seed_offset` asserts the defective
identity holds today and is **supposed to fail when the defect is fixed**, so whoever repairs
`seed_state` sees it go red, reads the comment above it, and deletes it deliberately. Pinning the
behaviour is what stops the finding from being lost in a note — which is the same argument S7 makes
for asserting a fixture's coverage rather than describing it.

---

## Correction 1 — the canary does NOT attach at the `versioned` row, and it must not

Cluster 10 recommended, and the handoff repeated, that *"`check_seed_sensitivity`'s `versioned` row
already asserts it, and that row is where the canary attaches."*

**It is not, and the reason is the one the handoff itself gives two paragraphs earlier.** The
`versioned` row is a **real driver run**. A canary attached to it is red every time the driver's
control flow moves, every time a request-projection string is edited, every time a scenario is
retuned — and a driver change is not a seed remap. **A canary that cries wolf acquires a regeneration
target**, and the handoff's central prohibition then fails not because anyone disagreed with it but
because the artifact made itself unusable.

The canary therefore **consults no driver at all**. It calls `choose_provider`, `choose_tool`,
`choose_approval` and `choose_environment` directly under a fixed, adaptive schedule with **constant
salts**, so the only route from seed to digest runs through `seed_state` into `rng` and out through
`draw`. The driver may be rewritten entirely without moving a pinned number.

This is not a weakening of the S8 obligation, it is what makes it satisfiable: the salts carry no
seed and no version, and every digested field is draw-derived (stage 4's site-21 remedy, inherited).
The three things S8 asks for are structural rather than asserted.

**The `versioned` row keeps its job** — it is the run-side statement that a version bump changes a
generated program — and site 22 is precisely the limit of what it can say.

## Correction 2 — regression mode records BOTH demoted differences at a position; strict still records one

D2 does not say, and the two readings type-check.

Strict mode keeps exactly one finding per position, coarsest first, because **its findings are
failures** and a mutant that trips two rules proves neither — the discipline stage 3 states at
`compare_at`. Regression mode's findings are **a record**, and D2 requires the differences to be
recorded rather than discarded. A position whose request *and* outcome both changed, reported as
"the request changed", is a report that understates the very thing the mode exists to report.

So the coarsest-first discipline is preserved exactly where it earns its keep — the **fatal** chain,
in both modes — and relaxed only across the two demoted rules. Recorded in-source at `compare_at`
and asserted by `test_both_demoted_differences_at_one_position_are_recorded`, which checks the same
input produces two findings in regression and one in strict.

## Correction 3 — the handoff's two structural claims were both exactly right

Stated because calibration is worth as much when the plan is right as when it is wrong, and this is
the third cluster running where the handoff's *"stage N left the exact seam"* claim held.

- **"Regression replay does not need the generator; stage 3 left the exact seam."** Correct to the
  line. `walk` and `compare_at` needed a mode parameter and nothing else; the two walk arms needed no
  change at all, because `ProgramExhausted` and `UnusedInteraction` are fatal in both modes — so
  neither arm consults the mode, which is D2's demotion set read structurally.
- **"Take regression replay first: it is cheaper, ready, and independent."** Correct, and the ordering
  mattered: regression replay was landed and committed before the canary's first mutation escape,
  so the session had a clean stop available throughout the expensive half. This is **S3 applied
  across pieces rather than across seams**, and it is the second time the rule has paid.

---

## Sizing — S6's second term, and the decided/discovered split cluster 10 introduced

**Recorded bindings: five — three decided, two discovered.** Cluster 10 proposed the split; this is
its first use as a planning instrument rather than a retrospective one.

**Decided (3)** — identifiable from the artifacts before writing code:

1. **Regression mode records both demoted differences at a position.** Correction 2.
2. **The canary consults no driver.** Correction 1. D8 fixes nothing about how to pin; the handoff
   fixed *what* must be reachable, not *from where*.
3. **The canary's bounds are its own, and there are two sets.** A script's bounds are a scenario's
   choice and may be retuned; these are part of what the pinned numbers mean, so they live beside
   them. The second set exists only after binding 4 forced it.

**Discovered (2)** — arrived by running the thing:

4. **A pinned digest certifies only the paths its trajectory walks, and folding a COUNT is blind to a
   change in a FIELD.** Arrived as an escaped mutant, twice: once for the unwalked branch, once more
   for the count-shaped fold after the first fix. Not derivable from D8 or from S8 as written.
5. **Site 22.** Arrived from the sweep's own output while looking for something else entirely
   (pairwise-distinct pinned quantities).

**Cost against stage 4: roughly 0.9×**, against a binding count that predicted ~1.25×. **The count
over-predicted for the first time**, and the reason is legible: the two pieces are independent and
one of them was nearly free. Regression replay cost well under a third of the stage despite carrying
two of the five bindings' worth of care, because **stage 3 had left a seam that fitted a parameter**.
The canary was ~70% of the session, all of it in the discovered bindings and the three sweep/re-pin
loops they forced.

**Refinement this suggests, and it is small:** S6's second term should be applied **per piece**, not
per stage, when a stage's pieces are independent. Summing bindings across independent pieces and
comparing the total to a previous stage's total mixes a cheap piece into an expensive one and
predicts the average of two things that do not interact.

**Round trips: 1 compiler, 2 gate, 2 silent.**

- **Compiler (1).** A missing `import std/string as Str (contains)` in `dst_replay`. Loud, immediate.
  Notably low — the two modules edited are both std-only and the shapes were already established.
- **Gate (2).** Both are mutant 4 escaping, before and after the first fix. Neither is a compiler
  round trip and neither would have been found by re-reading the code.
- **Silent (2).** Site 22, and the count-vs-field blindness inside binding 4. **Determinism caught
  neither** — twenty-two sites across eleven clusters, determinism still 0-for-22.

**Judgement ratio, split — and reported per piece, because this stage's halves differ more than any
previous stage's parts.** (The figure is the *undetermined* fraction.)

- **Machinery, regression replay: ~20%.** The lowest of any piece in this project. D2 fixes the
  demotion set, the handoff restated it as a table, the walk already existed, and the only genuinely
  open question was correction 2. When a specification and a handoff between them fix the answer,
  the work is transcription with one decision in it.
- **Machinery, the canary: ~60%.** D8 says the version must travel with the artifact and says nothing
  whatever about how to pin it — not the quantity, not the trajectory, not the bounds, not whether a
  driver is involved. Higher than stage 4's ~45%, and for the same reason one level out.
- **Content, the pins: ~25%.** **Down from stage 4's ~85%, and the drop is the interesting number.**
  Stage 4 searched for its fixture and called that a pleasing reduction. This stage searched *and the
  filter itself was derived rather than authored* — S7 supplies pairwise distinctness, D8 supplies
  "both layers must remap", and the adjacency constraint falls out of site 22. Of 260 seeds, 894774
  triples qualify; the only judgement left was preferring a triple that walks the trajectory extremes
  (83 draws, the schedule cap; 18, the minimum).

**And that is the carry-forward.** Stage 4 showed that a fixture can be a query's answer instead of a
design decision. This stage shows the **filter** can be too — read off the standing rules and the
specification rather than invented. **A15's corpora should be selected this way**: state the
obligations, derive the filter from them, sweep, and prefer among the survivors on the one axis the
filter cannot express (here, path coverage). The residual judgement then lives in one visible place
instead of being spread across every pinned value.

---

## D2/D8 findings carried forward

1. **`approval_deadline_exceeded` remains unreachable** by a discovered, generated or replayed
   program (stages 2, 3 and 4's finding, unchanged).
2. **The provider fault class is still unreachable by a generated program** — cluster 10's correction
   2, unchanged. Still one `ScriptedStep` field away, still A14's.
3. **`max_resource_size` is bound to the synthetic environment's entry count.** Cluster 10's finding
   4, unchanged — but note the canary's tight walk now sets `max_resource_size: 1` and **does** trip
   it, so the bound has a mutation row for the first time. It is still a bound that measures nothing
   in a real run, and A14 should still either give it a resource that can grow or delete it.
4. **Site 22** — above. New, and it is D8's.
5. **The canary pins the generator, not the generated program.** Deliberate (correction 1), and the
   consequence should be stated: a change to the driver, to a request-projection string, or to a
   scenario's bounds moves stage 4's seeds 9/13/94 and **does not** move the canary. The two
   artifacts answer different questions and neither substitutes for the other.

---

## What is unblocked, and what stage 6 should know

**Unblocked.** Stage 6 (D8's persistence obligations — secret redaction before persistence, and the
deterministic diffable encoding with its compatibility policy) has everything it needs. Nothing in
this stage touched the program encoding, which was the handoff's stated risk to check.

Four things stage 6 should know:

1. **The canary is NOT pinned to the program encoding**, so stage 6 may change that encoding freely
   without producing canary false alarms. This was the handoff's third stop-and-report condition and
   it does not fire: the canary digests *decision records*, which are `dst_generator`'s own types and
   are upstream of anything `dst_program` encodes.
2. **`RegressionReplay` is the natural consumer of a persisted program from an older build**, which is
   what regression replay is for. Its `differences` field is already a list of typed
   `ReplayMismatch`, so D11 reporting can read it without a second projection.
3. **S7's record-level form applies directly to the encoding**, and this stage produced a fresh
   instance of it on a digest rather than a codec (the failure-count fold). A field the encoder writes
   and the decoder ignores is the same shape.
4. **Site 22 will matter for persistence.** If (id, version, seed) is the name a preserved artifact is
   filed under — and D8 says it is — then that name is currently not unique. Stage 6 should either
   fix `seed_state` (paying the stage-4 re-sweep) or record the collision as a known property of the
   artifact store, but it should not file artifacts under a key it believes to be unique.
