# 2026-08-03 Cluster 10: WI-A13 stage 4 — D2's seeded generator

## Context

Branch: `arniwesth/mot-51-execute-wi-a13`

Session span: `0f5d017` → `9909eeb`, **3 commits**, one of them production source. Input was
`HANDOFF-execute-a13-stage-4-seeded-generator.md`, executed cold against HEAD. Tenth code session of
project 009, following clusters 1, 4, 6, 3, 2, 5, 7, 8 and 9.

Re-grounding first, as the handoff instructed: `git diff --stat 65ed0b0..HEAD -- src packages scripts
Makefile` was **empty**, so the handoff's verified-input table held without re-measurement.

**Partial completion at a clean stage boundary**, as clusters 7, 8 and 9 were. Nothing half-built
carried across the stop.

| | |
|---|---|
| Stage 1 — types + pure structural validator | landed (cluster 7) |
| Stage 2 — discovery recording against `driver_only` | landed (cluster 8) |
| Stage 3 — strict replay | landed (cluster 9) |
| Stage 4 — **the seeded generator** | **landed, green** |
| Stage 5 — regression replay + D8's generator canary | not started |
| Stage 6 — D8 persistence obligations | not started |

The handoff carried a **planning defect of its own author's**, stated openly: the original five-stage
split described stage 2 as "discovery — record what the driver requests", which is only half of D2's
discovery. D2 is seed-driven — a generator *chooses*, the world *records* — and the choosing half was
never any stage's. Verified at HEAD before starting, and confirmed: nothing drew from a seed, and
`discovery_dst.ail:543-545` wrote `generator_id`, `generator_version` and `seed: 0` onto
hand-authored worlds. The corrected staging (4 generator, 5 regression replay + canary, 6
persistence) stands.

## What landed

| Commit | Item | Gate |
|---|---|---|
| `f77adf1` | **stage 4** — the generator, the generating seams, the acceptance suite, the `driver_only` re-issue | `make seeded_generator` |
| `7eb6a6b` | execution report + four corrections | note |
| `9909eeb` | propagation: standing rule **S8**, the fourth S6 data point, the two scope items A14 inherits | plan |

New files: `src/core/dst_generator.ail` (965), `scripts/dst/seeded_generator_dst.ail` (1050).
Modified: `src/core/ports.ail` (+169), `src/core/test/stub_step.ail` (+74), `Makefile` (+71),
`src/core/dst_driver_only.ail` (+21), `src/core/dst_program.ail` (+17), `src/core/session.ail` (+9),
plus the attribution-table re-measurement.

`make seeded_generator` is wired into the `dst` aggregate. **`make dst` exits 0** on the committed
tree, read as an exit status per cluster 7's process amendment — **387 checks, 47 of them new**
(340 at stage 3). `make check_core` exits 0, 46 modules.

## The order the work took

S1 was followed literally, and — as in cluster 9 — that is what produced the session's result.

1. **The assertion first, and it is the top of the file.** `dst_generator.ail`'s Part 1 is
   `check_seed_sensitivity` with five inline row sets, one of them a seed-ignoring generator that
   must go **red**. Written and run before a line of the generator below it existed. 14/14 green on
   the first run, including the seed-ignoring row.
2. **The PRNG**, with its two silent failure modes asserted (zero is a Lehmer absorbing state, and
   `seed: 0` is the literal every program in this project already carried; and the stream must move
   and not immediately cycle).
3. **The choices**, each returning a record of primitives so the generator names no `ports` type.
4. **The generating seams**, each *supplying* one queue entry and then delegating to its stage-2
   recording counterpart.
5. **The acceptance script**, then the seed sweep, then the Makefile target, then the measurements.

Two design constraints shaped everything and both came from existing artifacts rather than from D2:

- **`GeneratorState` rides in `WorldState`, threaded and never captured** — cluster 6's F6 lesson.
  A pinned *generator* is worse than a pinned script, because its output is still a valid,
  replayable, perfectly reproducible program; it is simply the same program for every seed.
- **`dst_generator` imports nothing but std**, so `ports.ail` can name it — the identical constraint
  stage 2 solved by splitting `dst_interaction` out of `dst_program`. `GeneratorBounds` moved down
  for the same reason and is re-exported from `dst_program`.

`std/rand` was never an option: `make world_state` forbids it in `src/core/*.ail`, and
`src/core/test/dst_gen.ail` — `pick_int(xs) -> int ! {Rand}` — is exactly the prohibited shape,
serving the older phase-C gates. Putting the generator in `src/core` means the existing guard covers
it with no new guard to write.

## The two silent sites, and neither was found by a check written for it

### Site 20 — an interleaved end-of-input approval is a world that cannot exist

The first generator chose independently at each approval request, so a run could read end-of-input at
approval #3 and be served at approval #5.

| Gate | Verdict |
|---|---|
| the generator's 15 inline tests | **green** |
| stage 1's structural validator over the generated program | green |
| `validate_bounds` | green |
| stage 3's `reconstitution_balance`, **both directions** | **green** |
| determinism | green |
| **seed sensitivity** | **green** |
| `strict_replay_findings` | **red** — `replay-outcome-differs` at #22, then eight cascading `replay-wrong-kind` |

The reconstitution balance being green is the sharp part: `approvals_of` produced exactly the right
**number** of queue entries, because it counts served approvals and the count was right. What a count
cannot express is the **position** of the end-of-input among them. That is cluster 9's site-19 lesson
arriving on a new surface, and it is the third time a count-shaped check has been shown blind to a
content-shaped defect in this project.

The cause is that `ports.WorldState.approvals` is a queue and `scripted_approval` reports
end-of-input exactly when it is empty. A queue empty at read #3 is empty at read #5; the channel is
the operator's stdin and a closed stdin does not reopen. So the generator was choosing an
**incompatible response** — D2's own word — and the fix went into the generator (`approvals_closed`
in its explicit state), not into the replay. Stage 3's fail-closed refusal path is what produced it,
which is the second consecutive cluster where a stage's own guard caught the *next* stage's defect.

### Site 21 — the generator responded to its seed through a decorative string, and the axis passed

This one was found by **mutation-testing the guard**, not by the guard.

`choose_provider` built its prose as `"g${g.seed}-d${g.draws}-..."`. Patching `seed_state` to ignore
its seed entirely — every choice now identical across seeds — produced:

- three seeds with **the same interaction count (14), the same draw count (21), the same clock (7)**:
  the trajectories were identical in shape;
- and **three different outcome digests**, because the seed was printed into a payload;
- so **axis A passed**, and so did the out-of-process Makefile comparison.

A generator that reads its seed only to print it satisfies every statement of seed sensitivity that
compares programs. The remedy is structural rather than a better assertion: everything the generator
writes is now derived from a **draw**, so a seed that reaches no choice reaches no byte of the
program. The same mutation now turns axis A red with four findings.

Both sites are the project's usual shape — two implementations type-check and the wrong one is
silent — bringing the running total to **21 across ten clusters**, with determinism still at
**0-for-21**.

## What the acceptance suite asserts

Ten axes, 46 checks, over five honest generated runs and three seed-ignoring mutant runs:

- **A. Seed sensitivity**, content-shaped, with its own **anti-count control**: at least one
  differently-seeded pair must have the *same* interaction count and different recorded outcomes.
  Seeds 9 and 13 are that pair and their class censuses agree in every column, so nothing but the
  outcomes can tell them apart.
- **B. The mutant, and it is a real driver run** — same driver, same recorder, generator handed a
  constant while the row records the seed that was asked for. Must go red naming
  `generator-ignores-its-seed`, **and for that reason alone**.
- **C.** The generator was consulted: every cursor starts empty and `gen.draws` grew.
- **D.** Declared bounds in both directions — zero failures on the honest bounds, and a tightened
  `max_interactions` produces the named failure **and** a bounded run.
- **E/F/G.** Generated programs pass stage 1's validator, reconstitute, **strictly replay**, and the
  replayed run is graded by stage 2's independent witnesses (stage 3's tautology control, carried
  forward).
- **H.** S7's two obligations on seed **94**: every protected shape present, and provider 11 /
  approval reads 10 / served 8 / dispatches 3 / tool ok 2 / tool fault 1 — pairwise distinct.
- **I.** C5 mutations on every guard this stage adds, ending with the unmutated fixture surviving.
- **J.** Determinism, last and least — the one property a seed-ignoring generator satisfies *best*.

Plus an **out-of-process `SEEDROW` comparison** in the Makefile, anchored to the emitted line's
syntactic form, re-deriving the central claim by a second author. It was mutation-tested in isolation
(by making `wire_witness` collide two digests while `main` stayed honest) and fires correctly.

**The S7 fixture was searched for, not authored.** Sweeping 260 seeds and filtering on S7's own two
obligations turned "which fixture carries every shape with pairwise-distinct quantities" from a
design decision into a query — exactly two seeds qualify, and 94 is the richer.

## Corrections propagated to the plan

**S8 (new standing rule).** *When a guard asserts that X influences Y, check that X cannot reach Y
except through the mechanism under test.* The first rule here that mutation testing structurally
could not produce: the guard **could** fire and **did** fire on the mutant it was designed against,
and still passed on a weaker one. A14's latency pair, A15's corpora and stage 5's canary all have the
same exposure.

**S6's fourth data point.** Four recorded bindings against stages 1–3's three, at ~1.5× stage 3 —
the count predicted 1.33× and the direction holds. What it missed: **two of the four were
*discovered by running*, not decided by reading.** Proposed refinement, no sixth model: S6's second
term inherits S5's uncertainty when the composition is over something that **runs** rather than
something that **validates**.

**Two scope items named for A14.** `ScriptedStep` has neither an error case nor an `advance_ms`, so
the generator chooses no provider fault and no provider latency — both one field away, restored on
replay from `TimedOutcome.advance_ms` with no codec change, at ~30 literal sites. That is WI-A14's D4
latency pair by name. The dead `advance_ms` field was **removed** rather than left chosen-and-unused,
because that is the same smell as an ignored seed. Separately, `max_resource_size` is the one
declared bound with no mutation row.

**The A5 anchor cascade, sharpened against cluster 9.** Cluster 9 concluded the cascade "is avoidable
by an author who knows the anchor exists". Half right. `stub_step.ail:161` was never disturbed — the
`sed -n '161p'` check caught one violation immediately, a two-line comment that had shifted it — but
a new `StepProvider` variant forces a match arm in `ported_provider` that **cannot** move below the
four `session.ail` clock sites it precedes. `driver_only` re-issued at **v3**, same claim, moved
coordinates. The avoidable half is now demonstrably avoided; what remains is structural, so the case
for building the coordinate-independent anchor is *restored*.

**Honesty fix.** `discovery_dst` and `strict_replay_dst` now record
`generator_id: "hand_authored_discovery"`. Those three literals were not merely unused — they were a
claim, and stage 5's canary should pin the seeded programs' axes instead, which
`seeded_generator_dst` asserts are read off the world's own generator state.

## Calibration

**Time: ~60 minutes.** Recorded bindings: **four**.

1. **How the request participates in the choice.** D2 names "the bounded request projection" as an
   input and does not say how it enters. The weak reading is **unfalsifiable** — under it a generator
   driven by nothing but a call counter satisfies D2. The strong reading (the projection perturbs the
   stream) is taken and tested; the cost is stated in-source, that request projection strings are now
   part of the generator's observable contract.
2. **What `max_resource_size` bounds** — the synthetic environment's entry count, the one modelled
   logical resource `initial_world` names.
3. **End-of-input is terminal** (site 20). Not derivable from D2; derived from the world model and
   delivered by a red gate.
4. **Where the generator's choice surface stops** — provider fault and latency are A14's, and the
   decision was to remove the dead field.

Bindings 1 and 2 were identifiable from D2 in advance, exactly like every binding in stages 1–3.
**Bindings 3 and 4 both arrived as red gates.**

**Round trips: 3 compiler (all loud), 2 gate, 2 silent.**

- **Compiler.** A `let ... ;` binding inside a `&&` chain does not parse (the error points at the
  closing brace, not the `let`). `==` on an ADT constructor — replaced with a `match` before testing
  whether it works. One placeholder signature left behind during a refactor.
- **Gate.** The A5 attribution cascade, and the strict-replay refusal that produced site 20.
- **Silent.** Sites 20 and 21.

**Judgement ratio, split:**

- **Machinery — the PRNG, the bounds, the adapters: ~45%.** The highest of any stage. D2 fixes the
  five inputs and the five bounds but specifies **no distribution, no choice surface and no
  arithmetic**, and the Lehmer absorbing-state hazard is in no artifact.
- **Content — the seeds and the fixture: ~85%.** *Lower* than stage 3's ~90%, because the fixture was
  searched for rather than authored. The undetermined part is the shape list and the choice of
  quantities, not the fixture. **A15's corpora should be selected the same way**: state the
  obligations as a filter, sweep, pin the survivors.

## Tooling notes

- The parallel `ailang check` closure tool ran in **~2.0 s over 13 modules**; rebuilt at session
  start, per seven prior clusters, and deleted with the probe directory at the end.
- Arithmetic was probed before being relied on: `%` exists, integer division truncates toward zero,
  and ints are 64-bit (`1000000007 * 1000000007` evaluates exactly), which is what makes
  `48271 * 2147483646` safe from silent wrap. `std/string` supplies `foldChars` and `charCode` for
  the request hash.
- Probes lived in an in-repo `probe/` directory, never `/tmp`, and were removed before the commit.
- `make dst`'s **exit status** caught the attribution cascade: four ✗ lines among 382 ✓ under
  `--keep-going`. Third consecutive cluster where this mattered.
- No `.ailang/cache` contradiction arose; the cache was cleared once before the final full run.
- Pin: v0.26.0.

## For stage 5

1. **Regression replay is still exactly what cluster 9 described** — `strict_replay_findings` with
   `ProjectionDiffers`/`OutcomeDiffers` demoted. Nothing in stage 4 touched `compare_at`. It does
   **not** need the generator.
2. **The canary must pin CHOICES, not literals.** Site 21 sharpens the handoff's own warning: pinning
   a digest against a version is only meaningful if the digest cannot be reached except through a
   choice. `seeded_generator_dst`'s axis A is the model, and both its anti-count control and its
   whole-state mutant are load-bearing.
3. **A `generator_version` bump moves the whole stream**, because the version is mixed into
   `seed_state`. D2 permits the difference; this implementation asserts it, and the `versioned` row
   is where the canary should attach.
4. **The pinned seeds are 9, 13 and 94**, and the reason each was chosen is asserted rather than
   described. A change to the generator, to a request projection string, or to the driver's control
   flow moves all of them and the failure is loud. **Re-sweep and re-pin; do not relax the check.**
5. **`stub_step.ail:161` is still an A5 anchor**; `session.ail`'s four moved to 948 / 1053 / 2290 /
   2400, and `driver_only` is now **v3**. A stage-5 edit that adds another `StepProvider` variant
   pays the re-issue again; one that does not, does not.
