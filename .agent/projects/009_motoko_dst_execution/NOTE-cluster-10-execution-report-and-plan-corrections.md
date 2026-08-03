# Cluster 10 execution report — WI-A13 stage 4, and four corrections

Tenth calibration run. **Partial completion at a clean stage boundary**, as clusters 7, 8 and 9
were. Stage 4 is landed, green and committed. Stage 5 is not started and nothing half-built is
carried across the stop.

Commit:

- `f77adf1` feat(A13): stage 4 — D2's seeded generator, and the seed it never read

**`make dst`: exit 0** — read as an exit status, not a scan of output. **387 green checks, 47 of
them new** (340 at stage 3). **`make check_core`: exit 0**, 46 modules.

No source drift at session start (`git diff --stat 65ed0b0..HEAD -- src packages scripts Makefile`
was empty).

---

## What landed

**`src/core/dst_generator.ail`** (new, std-only) — in this order, because the order is S1:

1. **The seed-sensitivity rule**, with five inline row sets, one of which is a seed-ignoring
   generator that must go red. Written and run before a line of the generator existed.
2. The declared bounds and the bound-failure record.
3. An explicit Lehmer PRNG — state in [1, m-1], `x' = 48271x mod (2^31 - 1)` — with `in_range`
   mapping every int including 0 and negatives into the non-absorbing range.
4. The per-class choices, each returning a record of primitives.

**`src/core/ports.ail`** — `WorldState.gen`, the generating tool and approval adapters, and the
provider-entry mapping. **`src/core/test/stub_step.ail`** — the generating provider and
`generating_ports`. **`src/core/session.ail`** — one `GeneratedWorld` arm.

**`scripts/dst/seeded_generator_dst.ail`** and **`make seeded_generator`**, wired into `dst`. Ten
axes, 46 checks.

**`GeneratorBounds` moved** from `dst_program` into `dst_generator` and re-exported, for the same
structural reason stage 2 moved `Interaction` into `dst_interaction`: the bounds are consulted
inside a port adapter, which is below `dst_program` in the import graph.

---

## The result the handoff asked for, and it arrived twice

The handoff said: *"If the seed-sensitivity assertion catches a generator that ignores its seed,
report it — that is this stage's central result."* **It did, and then it caught a second, subtler
one that the first version of the assertion passed on.** The second is the more useful finding.

### Site 20 — an interleaved end-of-input approval is a world that cannot exist

The first generator chose independently at each approval request, so a run could read end-of-input
at approval #3 and be served at approval #5.

**Measured, at the moment the generated program was first replayed:**

| Gate | Verdict against the incompatible generator |
|---|---|
| the generator's own inline tests (15) | **green** |
| stage 1's structural validator over the generated program | green |
| `validate_bounds` | green |
| stage 3's `reconstitution_balance`, both directions | **green** |
| determinism (two generations at one seed) | green |
| seed sensitivity | green |
| **`strict_replay_findings`** | **red** — `replay-outcome-differs` at #22, then eight cascading `replay-wrong-kind` |

The reconstitution balance being green is the sharp part, and it is cluster 9's site-19 lesson
repeating on a new surface: `approvals_of` produced exactly the right NUMBER of queue entries,
because it counts served approvals and the count was right. What it could not express was the
POSITION of the end-of-input among them.

The cause is that `ports.WorldState.approvals` is a queue and `scripted_approval` reports
end-of-input exactly when it is empty. A queue that is empty at read #3 is empty at read #5. The
channel is the operator's stdin, and a closed stdin does not reopen. So the generator was choosing
an **incompatible response** — D2's own word — and the fix belongs in the generator, which now
carries `approvals_closed` in its explicit state.

**This is the one constraint of this stage that no amount of reading D2 produced.** It is a property
of the world model that only a replay could reveal, and it is the strongest argument available for
the handoff's instruction to run generated programs through stage 3 rather than declaring victory at
a valid program.

### Site 21 — the generator responded to its seed through a decorative string, and the axis passed

This one was found by mutation-testing the guard rather than by the guard.

`choose_provider` built its prose as `"g${g.seed}-d${g.draws}-..."`. Patch `seed_state` to ignore
its seed entirely — every choice now identical across seeds — and:

- three seeds produced **the same interaction count (14), the same draw count (21), the same clock
  (7)**: the trajectories were byte-identical in shape;
- and **three different outcome digests**, because the seed was printed into a payload;
- so **axis A passed**, and so did the out-of-process Makefile comparison.

A generator that reads its seed only to print it satisfies every statement of seed sensitivity that
compares programs. The fix is that everything the generator writes is now derived from a **draw**,
so a seed that reaches no choice reaches no byte of the program; the same mutation now turns axis A
red with four findings.

**The generalisable rule, and it is new:** *when a guard asserts that X influences Y, check that X
cannot reach Y except through the mechanism under test.* A decorative copy of the input in the
output satisfies the assertion and tests nothing. This is distinct from S1 (which is about writing
the assertion first) and from C5 (which proves a guard can fire): the guard here **could** fire and
**did** fire on the intended mutant — axis B, the whole-generator-state mutant — and still passed on
the partial one. **Only mutating the implementation in a second, weaker way exposed it.**

Recommend adding this to the standing rules as **S8**, because A14's latency pair and A15's corpora
will both assert "this input influences that artifact" and both have the same exposure.

---

## Correction 1 — the staging defect the handoff declared was real, and the mission was right

The handoff stated its own planning defect: the generator fell between stage 2 and stage 4's canary.
Confirmed at HEAD before starting — `scripts/dst/discovery_dst.ail:543-545` recorded
`generator_id: "driver_only_discovery"`, `generator_version: "1"`, `seed: 0` on hand-authored
worlds, and the only `std/rand` mentions under `src/core` were comments about the guard forbidding
it. The corrected staging (4 generator, 5 regression replay + canary, 6 persistence) stands.

**One consequence worth recording:** those three literals were not merely unused, they were a claim.
Renamed to `hand_authored_discovery` in both `discovery_dst` and `strict_replay_dst`, with a pointer
to the real generator. Stage 5's canary should pin the SEEDED programs' axes, which are read off the
world's own generator state rather than written as literals — `seeded_generator_dst` asserts that
correspondence directly (*"the program's generator axes are the ones the run actually used"*).

## Correction 2 — the provider class has no latency channel, and that is A14's

D2 has the generator choose "a compatible response, fault, and latency". On the provider class this
generator chooses the **response only**, and both omissions are declared rather than absorbed:

- **No provider fault.** `ScriptedStep` has no error case, so a generated `AIError` has nowhere to
  be chosen into.
- **No provider latency.** `ScriptedTool.duration_ms` is the tool class's latency channel and
  `world_tool` advances the clock from it; `ScriptedStep` has no counterpart.

Both are **one field on `ScriptedStep` away** (`advance_ms`, restored on replay from
`TimedOutcome.advance_ms` exactly as the tool duration already is — no codec change). That is a
widening of a world-input type at roughly thirty literal sites across the smoke scripts, and it is
**WI-A14's D4 latency pair by name**, which this handoff put out of scope. `dst_program`'s design
note 3 does not stand in the way: `ScriptedStep` is a world input, not a field on the program.

Measured, not assumed: the first draft DID have the generator choose a provider `advance_ms`, and it
was silently discarded, because `recording_model_step` hard-codes `advance_ms: 0`. Advancing the
clock in the generating adapter instead would have turned `check_discovery`'s clock balance red —
correctly, since the log would then account for less time than the world spent. **The dead field was
removed rather than left in**, because a chosen-and-unused input is the same smell as an ignored
seed.

**What is NOT deferred is the clock bound.** `max_clock_advance_ms` is declared, enforced and
mutation-tested on the tool class, so D2's fifth bound is live rather than notional.

## Correction 3 — half of the A5 anchor cascade is NOT avoidable by care, and this is the data point A14/A15 wanted

Cluster 9 concluded that the cascade "is avoidable by an author who knows the anchor exists, which
makes the case for building the anchor weaker than cluster 8's experience alone suggests." **That is
half right, and this cluster separates the halves.**

- **`stub_step.ail:161` was NOT disturbed.** The `GeneratedWorld` explanation was written below the
  anchor, the `StepProvider` line was widened in place with a trailing comment, and three import
  lists were widened in place. One `sed -n '161p'` check after each edit — and it caught one
  violation immediately, a two-line comment block that had shifted the anchor by two.
- **The four `session.ail` anchors were disturbed anyway, and no amount of care avoids it.** A new
  `StepProvider` variant forces a new match arm in `ported_provider` (session.ail:843), exhaustively
  checked, and a match arm cannot be placed below the sites it precedes. `driver_only` was re-issued
  at **v3** — the second re-issue in three stages, same claim, moved coordinates.

**Recommendation, sharper than cluster 9's:** build the coordinate-independent anchor. The avoidable
half is now demonstrably avoided by a documented one-line check; what remains is structural, recurs
once per port-shaped change, and costs a profile version bump each time. The cost/benefit that
cluster 9 correctly weakened is restored by the part that care cannot reach.

Cost this cluster: 6 files (attribution table rows, the table's own completeness fixture, the
acceptance script's fixture, the Makefile anchor list, `driver_only_version`, the recorded content
hash). All loud, all with the remedy stated at the point of failure, ~6 minutes.

## Correction 4 — `make dst`'s exit status caught this, and a scan would not have

The attribution cascade produced **four ✗ lines among 382 ✓ lines** under `--keep-going`. Cluster
7's process amendment is what turned that into a red gate. Third consecutive cluster where this
mattered; it is no longer worth re-litigating.

---

## D2 findings carried forward

1. **`approval_deadline_exceeded` remains unreachable** by a discovered OR generated program
   (stages 2 and 3's finding, unchanged).
2. **`ToolCorrelationMismatch` and `ToolDeadlineExceeded` are now REACHED by generated programs**,
   which is a change from stage 3's *codec-covered, scenario-unreached*. The generator chooses all
   four tool outcome classes, and seed 94's fixture asserts every generated fault names one of D3's
   three tool classes. D11's counters should reflect this.
3. **The provider fault class is unreachable by a generated program** — see correction 2.
4. **`max_resource_size` is bound to the synthetic environment's entry count.** D2 lists
   "logical-resource size" and this program has no obvious logical resource; the environment is the
   one modelled logical resource `initial_world` names. Stated, because a bound that measures
   nothing can never fire. It is the one declared bound with no mutation row, since nothing this
   generator produces approaches it — **that is a real gap and A14 should either give it a resource
   that can grow or delete the bound.**

---

## Sizing — S6's second term holds for a FOURTH stage, and the count is 4

**Recorded bindings: four** — up from three, three, three across stages 1, 2 and 3, and the cost
went up with it.

1. **How the request participates in the choice.** D2 names "the bounded request projection" as an
   input and does not say how it enters. The weak reading (the request selects WHICH choice function
   runs; the value comes from the stream alone) type-checks and is **unfalsifiable** — under it a
   generator driven by nothing but a call counter satisfies D2, which is a hair's breadth from the
   seed-ignoring generator. The strong reading (the projection perturbs the stream) is taken and
   tested. **Cost stated in-source:** request projection strings are now part of the generator's
   observable contract, and editing one is a trajectory change.
2. **What `max_resource_size` bounds** — finding 4 above.
3. **End-of-input is terminal.** Site 20. Not derivable from D2 at all; derived from the world model
   and delivered by strict replay.
4. **Where the generator's choice surface stops.** Correction 2 — the provider class's fault and
   latency are A14's, and the decision was to remove the dead field rather than leave it.

**Cost against stage 3: roughly 1.5×.** The binding count predicted 1.33× and the direction is
right. What the count did not predict is that **two of the four bindings were discovered by running
the thing, not by reading the specification** — bindings 3 and 4 both arrived as red gates. Stages
1–3's bindings were all identifiable from the artifacts before writing code.

**Proposed refinement to S6, and it is small:** the second term should distinguish **decided**
bindings from **discovered** ones. A decided binding costs a judgement; a discovered binding costs a
judgement *plus the round trip that surfaced it*, and it cannot be counted in advance — which is
exactly S5's property, arriving inside a composition. **No sixth model; S6's second term inherits
S5's uncertainty when the composition is over something that RUNS rather than something that
validates.**

**Round trips: 3 compiler, all loud; 2 gate; 2 silent.**

- **Compiler (3).** A `let ... ;` binding inside a `&&` chain does not parse (the error points at
  the closing brace, not the `let`). `==` on an ADT constructor — replaced with a `match` before
  testing whether it works. One placeholder signature left behind during a refactor.
- **Gate (2).** The A5 attribution cascade, and the strict-replay refusal that produced site 20.
- **Silent (2).** Sites 20 and 21. Neither was found by a check written for it; site 20 was found by
  a check written for something else (strict replay), site 21 by mutating the implementation.

**Judgement ratio, split** (cluster 5's rule):

- **Machinery — the PRNG, the bounds, the adapters: ~45%.** Higher than any previous stage. D2
  specifies the five inputs and the five bounds, but it specifies **no distribution, no choice
  surface and no arithmetic**, and the Lehmer/absorbing-state hazard is not in any artifact. The
  determined part is only the shape of the state and the requirement that it be threaded.
- **Content — the seeds and the fixture: ~85%.** Lower than stage 3's ~90%, and the reason is
  pleasing: **the fixture was SEARCHED FOR rather than authored.** Sweeping 260 seeds and filtering
  on S7's own two obligations turned "which fixture carries every shape with pairwise-distinct
  quantities" from a design decision into a query — of 260 seeds, exactly two qualify. The
  undetermined part is the shape LIST and the choice of quantities, not the fixture.

**And that is worth carrying:** S7's obligations were previously satisfied by an author choosing
values; here they were satisfied by a search over a generator's own output. **A15's corpora should
be selected the same way** — state the obligations as a filter, sweep, and pin the survivors, rather
than authoring corpora and hoping they cover.

---

## What is unblocked, and what stage 5 should know

**Unblocked.** Stage 5 (regression replay, and D8's generator canary) has everything it needs, and
the canary now has a generator to pin.

Five things stage 5 should know:

1. **Regression replay is still exactly what cluster 9 described** — `strict_replay_findings` with
   `ProjectionDiffers`/`OutcomeDiffers` demoted to recorded differences. Nothing in stage 4 touched
   `compare_at`. It does not need the generator.
2. **The canary must pin CHOICES, not literals.** The handoff warned that a canary pinning
   `generator_id`, `generator_version` and `seed` "passes and certifies nothing". Site 21 sharpens
   that: a canary pinning the generated program's DIGEST against a version is only meaningful if the
   digest cannot be reached except through a choice. `seeded_generator_dst`'s axis A is the model,
   and its anti-count control and its whole-state mutant are both load-bearing.
3. **A `generator_version` bump moves the whole stream**, because the version is mixed into
   `seed_state`. D2 permits the difference; this implementation asserts it, and the `versioned` row
   is where stage 5's canary should attach.
4. **The pinned seeds are 9, 13 and 94, and the reason each was chosen is asserted, not described.**
   9/13 are the equal-census anti-count pair; 94 is one of exactly two seeds under 260 satisfying
   S7. A change to the generator, to a request projection string, or to the driver's control flow
   moves all of them and the failure is loud. **Re-sweep and re-pin; do not relax the check.**
5. **`stub_step.ail:161` is still an A5 anchor and `session.ail`'s four moved to 948/1053/2290/2400.**
   `driver_only` is now **v3**. A stage-5 edit that adds another `StepProvider` variant pays the
   re-issue again; one that does not, does not.
