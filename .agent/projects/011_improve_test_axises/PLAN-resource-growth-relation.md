# Plan: replace the pinned depth canary with ADR-002's measured slope

Status: **written, not started.** Date: 2026-08-17. Grounded against `059dbd9`, AILANG v0.33.0.
Commissioned by `HANDOFF-write-resource-growth-relation-plan.md`; decided by
`ADR-002-resource-growth-as-a-metamorphic-relation.md` as corrected.

**Subject, one sentence.** Replace the shipped pinned-ceiling canary
(`scripts/dst/run_depth_canary.sh` tier 1) with a measured **slope** of recursion depth against
accumulated records, trajectory length held fixed.

**Everything numeric below was measured by this session against HEAD**, not inherited. The
handoff's calibration ask is answered first because its answer re-routes the plan.

---

## 1. The calibration ask, answered

> *"Report the canary-fallout count before scheduling the rest — how many pinned artifacts a
> changed draw range actually moves."*

### Method

Full `make dst` twice, same machine, same tree, 8 cores. Baseline at HEAD. Then exactly one
edit — `dst_generator.ail:600`'s chunk draw `0, 3` → `0, 16` — and the sweep again, then
`git checkout`. Each newly-red target was then re-run alone and its failing check read.

**The baseline is not clean, and one half of it is this branch's doing.** Seven targets are
already red at HEAD, from two unrelated causes, and both are subtracted from every count below.
`depth_canary` is **green** at baseline.

*Five are `agentcli`, and not this axis.* `declared_vs_performed`, `driver_plus_compose`,
`driver_plus_no_ops`, `ext_ambient_inventory_selftest` and `ext_hook_scope_selftest` all fail
because `sunholo/motoko_ext_agentcli` is in `ailang.toml` and in no profile's install or omission
list ("15 expected, got 16"; `ailang.lock` is uncommitted at HEAD, regenerated 2026-08-16). That
is `.agent/projects/017_extension_handling/`'s subject.

*Two are line drift from the #160 fix, and they are worth reporting on their own.* `anchors` and
`attribution_table` are one recipe (`Makefile:2378`, `:2383`) and one failure: **five pinned
`src/core/session.ail` line anchors — `:1111`, `:1370`, `:1476`, `:2942`, `:3052` — no longer
name a routed core clock site.** The fix for #160 edited `session.ail`; these anchors were
measured before it. The target's own message says the repair is not a re-baseline: it is a D4
judgement about which site is "the" attributed one, and correcting the table **re-issues three
profile versions** (`driver_only_version`, `no_ops_version`, `compose_profile_version`) across
eleven files. **This is a live defect on the branch carrying the #160 fix, found by this plan's
baseline measurement and not otherwise reported anywhere.** It is not this plan's work item — it
belongs to whoever lands #160 — but it must not be discovered by CI after the fact.

### The fallout

Four targets go red that were green. They resolve to **five artifact groups**: 6 pinned digests,
3 pinned record counts, an 11-member fixed-seed bank to re-select, and 8 assertions that are D2
semantics rather than pins at all.

| # | artifact | what moves | class | repair |
|---|---|---|---|---|
| 1 | `dst_generator.ail:1232-1241` — `pinned_canary_v1`/`v2` | the **choice digest only**, at 3 seeds × 2 versions | D8 pin | re-sweep + re-pin by hand, **with a `generator_version` bump** |
| 2 | `dst_generator.ail:1428` — `test_the_interaction_budget_forces_termination_and_only_then` | `generator_failed(unspent.state)` flips true | semantics | raise `test_bounds().max_chunks_per_interaction` (one line) |
| 3 | `seeded_generator_dst.ail` — 6 scenarios (`rich`, `pairA`, `pairB`, `repeat`, `versioned`, +1) | "zero generator failures against the declared bounds" | D2 semantics | raise the profile's declared bound to ≥ the draw's `hi` |
| 4 | `corpus_pr_dst.ail` — the 11-member fixed-seed bank | fault-class coverage: `declared ⊆ observed` goes red | selection | 260-seed re-sweep, re-select witnesses, re-write each member's `why` |
| 5 | `run_depth_canary.sh:103` — tier 1's three record pins | 79→80, 126→138, 96→120 | pin | moot; WI-3 replaces this gate |

Group 3 and group 2 are **not pins at all** and it matters that they are not: `bounded_draw`
clamps *downward* and records a `BoundFailure`, `GeneratorBoundFailure` maps to `HarnessHygiene`
(`dst_invariants.ail:369`), and that family requires zero. A draw whose `hi` exceeds a profile's
declared `max_chunks_per_interaction` therefore reports **every run as a generator failure** —
20 `generator-bound-exceeded` findings in one target. Widening the draw without raising the
declared bound in the same commit is not a re-pin, it is a suite-wide D2 violation.

### The verdict: a `generator_version` bump is required, and it is not cosmetic

Measured, not inferred. The canary reports exactly six findings and they are all one rule:

```
6 × generator-choices-remapped-without-a-version-bump
0 × generator-seed-remapped-without-a-version-bump
0 × generator-trajectory-reshaped-without-a-version-bump
```

That is the predicted signature and the mechanism is checkable by reading: `draw_between`
(`dst_generator.ail:416`) consumes exactly one `draw` whatever its range, and `d_chunks.value`
feeds only `chunk_count` (`:669`) and no later draw. So the RNG stream, `initial_state` and
`draws` are all **invariant** to the range change and only the drawn value moves. The canary's
own recorded remedy for that rule (`dst_generator.ail:977`) admits two outcomes and no third:
fix the generator, or **bump `generator_version`, re-sweep and re-pin by hand.**

**The bump is the expensive half, and the cost is second-order.**
`seed_state(id, version, seed) = in_range(salt_hash("${id}/${version}") + seed)`
(`dst_generator.ail:373`) mixes the version into the Lehmer state *by design* — D8 requires a
version that changed nothing observable to be impossible. So bumping it **re-rolls every seed's
program**: the corpus bank's 11 pinned seeds stop meaning what their prose says, both canary
tables move a second time for a different reason, the artifact path
`.ailang/dst-corpus/motoko_driver_only/1/` becomes `/2/`, and `generator_version() -> "1"` —
replicated in `export_trace.ail:103`, `corpus_pr_dst.ail:299` and `seeded_generator_dst.ail:254`,
and *asserted* at `seeded_generator_dst.ail:1123` — moves in four places at once.

> ### STOP AND REPORT #1 — fired.
> The handoff's first trigger is "larger than a handful of artifacts, **or** needs a
> generator-version bump." The count is a handful; the bump is required. Widening
> `dst_generator.ail:600`'s literal is therefore **a D8 compatibility event, not a
> test-infrastructure change**, and whether to spend it is the operator's call.
>
> **The plan is re-routed rather than blocked.** Two routes to the same lever avoid the bump
> entirely (WI-1, routes B and C), and one of them is cheaper than the fallout it avoids. The
> operator's decision is *which lever*, not *whether to proceed*.

---

## 2. Four findings that change ADR-002

Expected, per the handoff: the ADR's prose survived one review and one execution pass and was
still wrong three times. These are the next three, plus one that is a finding against the
*shipped gate* rather than against the ADR. Each is measured; the raw data is in Appendix A.

### Correction 9 — the healthy slope is identically zero only at a lever too narrow to be worth building

This is the load-bearing one, and it invalidates the ADR's central robustness argument.

ADR-002 states, twice and emphatically, that no tolerance is needed because "the healthy slope is
*identically* 0.00 at every point on every seed" and the separation is therefore "qualitative,
flat versus linear". **That is a property of the 1.25× lever, not of the fixed driver.** Measured
at HEAD with the lever widened — the exact change WI-1 exists to make:

| seed | records | depth, HEAD (fixed) | healthy slope |
|---|---|---|---|
| 7  | 63 → 104 (1.65×) | 58 → 64 | **0.146** frames/record |
| 11 | 106 → 181 (1.71×) | 87 → 89 | **0.027** |
| 23 | 88 → 160 (1.82×) | 75 → 83 | **0.111** |

The floor is flat through `max_chunks` 0–3 — 58/87/75 at every point, reproducing the shipped
pins exactly — and then rises. **The flatness ends precisely where the current draw range ends.**

The mechanism is identifiable and it is structural rather than a defect:
`stream_chunk_events` (`session.ail:1336`) is hand-written non-tail recursion over *one step's*
chunk list, so it costs one frame per chunk in the step that sets the peak. With no TCO, **every
records-per-step lever in this codebase costs frames proportional to records-per-step**, because
every per-step list in it is built by hand-written recursion. The healthy driver's peak depth is
Θ(records *per step*); the fault's is Θ(*total* records) = Θ(steps × records per step). The
discriminator is the step count, and it is a ratio, not a floor.

**Consequence for the relation.** "Slope must be zero" is not implementable at any lever wide
enough to be worth building. The threshold must be a number, and Appendix A says which numbers
are available. WI-3 owns it.

### Correction 10 — the slope, built exactly as specified, would not catch a regression of #160 itself

Measured, and it surprised this session. Restore the hand-written frame-per-record fold in
`runtime_status_counts` and leave the fix's name guard in place, then run the shipped gate:

```
tier 0  ✗  recursion_depth_probe hit the ceiling at 200
tier 1  ✓  seed 7   ✓  seed 11   ✓  seed 23
```

**Tier 1 is green on a total regression of the fault it was built for.** The reason is the
second half of the #160 fix: `encode(runtime_status_json(...))` now sits inside the
`runtime_builtin` lambda under `call.name == "MotokoRuntimeStatus"` (`session.ail:2523`), and the
generator draws its tool name from `{"T", "BashExec", "Read"}` (`dst_generator.ail:598`). **No
generated world ever requests `MotokoRuntimeStatus`, so the guarded traversal is unreachable on
the `driver_only` path.**

This is not a defect in tier 1 — it guards the *class* (any **unguarded** O(|trace|) traversal on
the driver path), which is what ADR-002 claims for it, and it was shown to fire against the
pre-fix driver where the call was eager. But the ADR's implicit reading — that the full relation
subsumes the unit probe — is false, and WI-4's "what replaces what" is therefore not an open
question: **tier 0 cannot be retired.** It is the only thing in the tree that guards the specific
function, and it does so because it calls the real export rather than a copy.

It also means any future measurement of the fault-present column must un-do **both** halves of
the fix. Un-doing only the fold measures nothing.

### Correction 11 — a vacuous seed is the modal case, not an anecdote

ADR-002 records seed 3 as one seed with zero tool batches. Swept, seeds 1–40, driver phase,
counting `native_tool_calls` off the wire:

| tool batches | 0 | 1 | 2 | ≥3 |
|---|---|---|---|---|
| seeds | **15** | 6 | 6 | 13 |

**37.5% of seeds never execute the tool-dispatch arm at all**, and 52.5% reach it at most once.
A single-seed gate is vacuously green better than one time in three. The shipped canary's three
seeds (7/11/23, at 4/8/6 batches) are in the top third — a selection, and the ADR is right to
call it a mitigation. WI-2 owns the fix, and the base rate makes the choice for it.

### Correction 12 — the ratio is not rescued by a wider lever

Worth recording because the obvious hope is that widening the range revives the simpler
statistic. It does not. At the full widened range the growth *ratio* is 1.52–1.62× faulty
against 1.02–1.11× healthy — still no tolerance sits far from both populations. The slope stays
the honest statistic for the reason Correction 7 gave, and now for a second reason: the slope has
a derivable expected value (≈ 1/steps healthy, ≈ 1 faulty) and the ratio has none.

---

## 3. Re-grounding: what HEAD actually says

Per `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`, every anchor this
plan builds on was re-observed. Six had drifted or vanished — all cosmetic, none load-bearing,
listed so the next reader does not re-derive them:

| cited as | at HEAD | note |
|---|---|---|
| `dst_generator.ail:598` (chunk draw) | **`:600`** | |
| `export_trace.ail:237` (`record_lines`) | **`:232`/`:235`** | |
| `session.ail:507` (the fold call) | **`:544`** | |
| `session.ail:2470` (the crash site) | **`:2523`**, now lazy and guarded | |
| `session.ail:437` `runtime_status_counts_rec` | **gone** | replaced by `List.foldl` at `:525-527` |
| `export_trace.ail:42` "refuses every profile" | comment; the refusal is **`:293-294`** | |

Verified present and behaving as described: the `CG_EXPORT_PHASE=driver` seam
(`export_trace.ail:334-335`, writes nothing, off by default); `make depth_canary` in
`DST_TARGETS` (`Makefile:416`) and green; `recursion_depth_probe.ail` importing the real
`session.runtime_status_counts`; `bounded_draw`'s downward clamp (`:429-437`);
`canary_row_from`'s digest over `wide.text ++ tight.text` including `failures_text` (`:1090`).

---

## 4. The work items

### WI-1 — make the records-per-step lever real

**The problem, restated with the measurement attached.** `max_chunks_per_interaction` is a
ceiling on a draw hardcoded to `0, 3`, so it cannot scale record volume; the usable range is
1.25×. Everything else depends on this, because without a lever there is no slope.

Three routes. They are not equivalent and the choice is §5's decision gate.

**Route A — widen the literal in core.** `dst_generator.ail:600`, `0, 3` → `0, N`.
*Measured cost:* §1's five artifact groups plus a `generator_version` bump that re-rolls every
seed. *Measured benefit:* records ×1.65–1.82. **Not recommended.** It buys the narrowest of the
three ranges at the highest price, and the price is paid in exactly the artifact — the corpus
bank — whose value is that nobody has had to re-derive it.

**Route B — make the draw range declared, defaulted to today's value.** Add `chunk_draw_hi` to
`GeneratorBounds`; the call site becomes `bounded_draw(…, 0, g.bounds.chunk_draw_hi, …)`; every
existing profile declares `3`. **The values do not move, so no digest moves, so no version bump
is owed** — and that is falsifiable in one sweep before any other work is done (see acceptance).
It also makes the bound mean what its name has always implied.

*What it costs instead*, and this is the honest half: `GeneratorBounds` is serialized. The
`bounds` header line (`dst_persistence.ail:513`) is positional with five fields and is read back
by index (`:1110-1116`); `ext_world.ail:463/472` carries a JSON codec; `dst_program.ail:608`
validates it. A sixth field is a **program-schema change** →
`program_schema_version` `execution-program/2` → `/3`, an entry in `decodable_schema_versions`
(`dst_program.ail:119`), and a fourth fixture beside
`scripts/dst/fixtures/execution-program-v{0,1,2}.artifact`.

*The trap, and it is silent:* `int_at` returns **0** for a missing field
(`dst_persistence.ail:777-779`). A v2 artifact read by a v3 reader would decode
`chunk_draw_hi: 0` — "this program never draws chunks" — which is a legal-looking program that
is not the one that was recorded. The version-aware default must be **3**, written explicitly,
with a decode test that reads a v2 fixture and asserts 3. Do not let `int_at`'s default answer
this.

*Why this trade is the right one:* the format version axis is machinery that already exists and
already carries two live versions; the generator version axis is machinery whose whole purpose is
to make a bump expensive. Route B spends the cheap one.

**Route C — move the lever out of the generator entirely, into hook count.**
`fold_pre_step_chain_rec` (`ext/runtime.ail:300-323`) conses one `CompactionStageRecord` per hook
per step unconditionally, including `StagePassed` — which is why production saw 567 of them from
9 extensions over 63 steps. Hook count is therefore a records-per-step lever that the generator
never sees, with **no generator change, no core change, no digest, no bump**. It comes in two
forms and they cost very different things.

*C1 — use the profile that already exists.* `src/core/dst_driver_plus_no_ops.ail` is a **declared
profile** installing four no-op extensions against `driver_only`'s empty install list, so the pair
gives two scale points at 0 and 4 stage records per step — a real slope from two artifacts nobody
has to invent. What it needs is the one thing the exporter refuses: `supported_profile()` is
`driver_only_id()` and every other profile is refused by name (`export_trace.ail:293`). **That is
the handoff's third stop-and-report and C1 fires it** — see §5.3.

*C1's honest weakness, and it is a specification objection rather than a cost:* two profiles
differ in **more** than records-per-step. ADR-002's relation says "the same generator differing
**only** in records-produced-per-step"; `driver_plus_no_ops` also runs four hooks' worth of
dispatch, which is ≤4 extra frames by the same non-tail fold. The confounder is small, bounded
and predictable — but it must be modelled and stated, not ignored, and two points is a thin basis
for a regression.

*C2 — replicate the exporter's own hook N times.* `export_trace.ail:155`'s `approval_rt` installs
exactly one; N of them give N points rather than two. **Caveat that must be checked before
anything is measured:** that hook carries `on_tool_policy: pending_policy`, so N copies of it are
not obviously policy-neutral. The replicas must be pass-through on every hook that can decide
anything, and the trajectory-constancy assertion (WI-1 acceptance 4) is what proves it.

*What C2 costs:* the run stops being `driver_only`. `export_trace.ail:38-43` says adding a
profile "is a wiring decision to be argued, not a silent fork", and this forks the rig rather
than the profile — the same objection one level down. It also has the same frame arithmetic as
the chunk lever (the fold is non-tail, so N hooks cost N frames), so it does not escape
Correction 9; it merely trades one confounder for an identical one.

**Recommendation: Route B, with C1 as the fallback if the schema change is refused.**
Route B is the only one that leaves the generator's identity, the corpus bank and the canary
untouched while making the bound honest, and it is the only one that keeps the relation's
"differing **only** in records-per-step" clause literally true. C1 is cheaper to build and weaker
to defend; C2 is cheaper still and weaker still. Route A is not recommended at any price this
plan can see.

**Acceptance for WI-1 — and the first step is falsification, not construction:**
1. Apply route B's default-preserving change **alone** and run `make dst`. **Zero new red
   targets against the seven-red baseline.** If anything reddens, the "values do not move" claim
   is wrong and route B is not what it claims — stop and report, do not re-pin.
2. `make depth_canary` green, unchanged, at every step.
3. A v2 fixture decodes to `chunk_draw_hi == 3` under the v3 reader, asserted in
   `program_persistence_dst`.
4. With the measurement profile alone declaring a wider range: record volume ≥ 1.6× on seeds
   7/11/23, with **decision, provider-call and tool-batch counts constant across the sweep** —
   verified, not assumed, exactly as the spike verified it. The trajectory must not move.

### WI-2 — settle the seed question

Correction 11 decides this: at a 37.5% vacuity base rate, **both** halves are needed, and the
plan does not treat them as alternatives.

1. **A precondition, asserted per run.** A seed whose driver phase executed fewer than **3**
   tool batches must fail the gate as `INCONCLUSIVE`, distinct from red. Not "warn": a relation
   that reports green on a trajectory that never ran the code is the vacuity this project has
   twice refused elsewhere (`generator-canary-is-vacuous`, `dst_seeded`'s axis K).
2. **A seed set, not a seed.** Three at minimum, chosen by sweep for tool-batch coverage rather
   than by hand, and recorded with the sweep that chose them — the discipline
   `pinned_canary_v1`'s header already applies to seed selection.

**The counter is already on the wire and needs no new code.** `native_tool_calls` appears in the
driver run's stdout stream; the sweep in Correction 11 counted it with `grep -c`. If the gate is
to read it inside the process instead, extend the `phase=driver` line to report decisions and
tool batches — a `List.foldl` over `trace.records`, which is frame-free and so cannot perturb the
measurement. Prefer the in-process count: the wire stream is the emission-witness channel and
`export_trace.ail:13-20` is explicit that it is not the returned trace.

**Acceptance:** the gate is shown to report INCONCLUSIVE on seed 3 and green on 7/11/23, and the
seed set's selection sweep is committed as the reason the seeds are those seeds.

### WI-3 — replace the pins with the slope

**The statistic.** Peak driver-phase depth regressed on accumulated records, trajectory length
held fixed, ≥4 scale points per seed, bisection tolerance **1** (tolerance 32 is what made the
spike's appendix report 98 for a true 86; it costs five subprocess runs to fix).

**The threshold, from measurement rather than from taste.** At the widened lever:

| | seed 7 | seed 11 | seed 23 |
|---|---|---|---|
| slope, fault present | 1.00 | 0.93 | 0.93 |
| slope, HEAD | 0.146 | 0.027 | 0.111 |

Any threshold in **(0.15, 0.93)** decides every seed measured. **Take 0.40** — 2.7× above the
worst healthy observation and 2.3× below the best faulty one, which is the "far from both
populations" property ADR-002 wanted from the ratio and could not get.

**State the normalized form beside it, because the raw threshold is lever-dependent.** The
healthy slope is ≈ c/steps and the faulty slope is ≈ 1; measured, `slope × decisions` is 0.7–2.3
healthy against 14–24 faulty. A gate written on the normalized quantity survives a change to the
lever's width, where a raw threshold does not. Write both, gate on the normalized one, and
record the raw numbers beside it so a red row is legible without recomputing.

**Do not add a per-step allowance.** Correction 7 killed it and Correction 9 does not revive it:
what moved is the *floor's dependence on chunks per step*, which the slope already sees. An
allowance would hide exactly the thing being measured.

**Acceptance:** shown to fire — the relation goes red against a driver with **both** halves of
the #160 fix un-done (Correction 10: un-doing one half proves nothing), and green at HEAD, on
every seed in WI-2's set. This is the house caveat and it is not optional.

### WI-4 — decide what replaces what, and retire nothing that is load-bearing

Correction 10 forces most of this:

- **Tier 0 stays, unconditionally.** It is the only guard on `runtime_status_counts` itself, and
  the slope relation is blind to that function's regression while the name guard holds.
- **Tier 1 is what the slope replaces.** Its weakness is exactly the one the slope is immune to:
  its floor is ~2.4 frames per decision plus ~23, so any legitimate change to `c2_loop`'s
  per-step cost reddens it, while the slope varies records with steps held fixed and does not
  care about the floor at all.
- **Keep tier 1 as a cheap pre-filter during the transition, then delete it in the same commit
  that lands the slope green.** Not before: the guardrail is that #160 stays covered at every
  commit. A tier that survives "for safety" past the thing that supersedes it becomes a pin
  nobody re-measures, which is the failure mode its own header warns about.
- **Cost budget, and ADR-002's figure is optimistic.** The `export_trace` driver-phase process
  costs **1.6 s warm** and **13 s cold**, measured — not the 0.46 s the ADR quotes for
  `driver_only_dst`, which is a different process. Bisection to tolerance 1 over [20, 900] is
  ~12 runs, so 4 scale points × 3 seeds ≈ 144 runs ≈ **4 minutes**, and any core edit invalidates
  the compile cache so CI pays the cold run at least once. That is still a `DST_TARGETS` target
  rather than a nightly, and it roughly halves if each scale point seeds its bisection from the
  previous one's answer — depth is monotone in records, so the previous answer is a valid `lo`.

### WI-5 — write the corrections back

Corrections 9–12 into ADR-002's *Corrections* section, in its established shape: what was
asserted, what measurement contradicted it, and why the wrong version is the one a reader will
re-derive. Correction 9 also obliges an edit to the ADR's **body** — the *Decision*'s "slope of
zero frames per accumulated record" is now false at any usable lever and must read as a
threshold. `run_depth_canary.sh`'s header and
`.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`'s *Gated* section both describe
tier 1 as awaiting "a records-per-step lever the generator does not have"; both need the route
that was actually taken.

### Sequencing, and what blocks what

WI-1 blocks WI-3 outright — without a lever there is no slope — and nothing else is blocked by
anything. Run it in this order and each step is falsifiable before the next one costs anything:

| step | what | blocked by | how you know it is done |
|---|---|---|---|
| 1 | WI-1 acceptance 1 alone: the default-preserving change, swept | — | zero new red against the seven-red baseline |
| 2 | WI-2's precondition + tool-batch counter | — | INCONCLUSIVE on seed 3, green on 7/11/23 |
| 3 | WI-1 remainder: the measurement profile declares a wider range | 1 | ≥1.6× records, trajectory constant |
| 4 | WI-3: the slope, its threshold, shown to fire | 1, 2, 3 | red with both halves of #160 un-done; green at HEAD |
| 5 | WI-4: tier 1 deleted in the same commit that lands step 4 | 4 | `make depth_canary` still guards #160 at every commit in between |
| 6 | WI-5: corrections back into ADR-002 and the two headers that describe tier 1 | 4 | — |

Steps 1 and 2 are independent and small; step 4 is where the real work is. **If the operator
picks route A instead**, insert the corpus re-sweep and the version bump *before* step 1 and
treat the whole of §1's fallout table as its own work item — that is a different plan's worth of
effort and this one does not schedule it.

**Steps 1 and 3 are commissioned**, as route B's cluster A, by
`HANDOFF-declare-the-chunk-draw-range.md` — the only handoff written, per
`../../meta-decisions/sequence-implementation-handoffs-by-source-surface.md`'s rule that a handoff
is written only for the cluster whose anchors are current. WI-2 and WI-3 share a source surface
that cluster A edits, so their handoff is written against the tree cluster A leaves, not now.

---

## 5. Decision gates that belong to the operator, not to this plan

1. **Which WI-1 route.** A costs a D8 generator-version bump and a 260-seed corpus re-sweep;
   B costs a program-schema version bump; C1 costs a decision to let the exporter run an
   already-declared second profile; C2 costs an argued fork of the exporter's rig. This plan
   recommends B and will not spend A's budget without an explicit instruction.
2. **Whether the baseline is repaired first.** Seven red targets make "no new red" a judgement
   rather than a check. The `attribution_table` half is the #160 branch's own line drift and
   should be repaired by that branch regardless of this plan; the `agentcli` half can wait. What
   the plan will not do is silently normalize seven reds.
3. **Whether a second profile is wanted — STOP AND REPORT #3, conditionally fired.** Everything
   measured, here and in the spike, is `driver_only`. The exporter refuses every other profile by
   name (`export_trace.ail:293`) and its header says widening that is an argued decision. Route B
   does not need it. **Route C1 does** — it is precisely a request to accept
   `driver_plus_no_ops`, which already exists as a declared profile and is refused only by the
   exporter. So this gate opens only if the operator sends WI-1 down route C, and the plan does
   not fork the exporter to find out.

## 6. Guardrails, carried forward from the handoff and re-verified here

- **`make depth_canary` is green at HEAD and must stay green.** Verified at the start of this
  session and again after every experiment; the tree was restored each time. Nothing in WI-1–WI-3
  may retire it before WI-3's gate is green and shown to fire.
- **No pin is bumped to make something pass.** Every pin this plan touches moves because the
  thing it certifies deliberately changed, with the reason recorded — and route B exists
  precisely so that most of them do not have to move at all.
- **A green relation proves the instrument fires on the trajectories run.** It does not say no
  `O(|state|)` traversal exists. That is §3.3's oracle-strength question, it is untouched here,
  and Correction 10 is a concrete instance of the gap: a real traversal, present in the tree, that
  the relation cannot see because no generated trajectory calls it.
- **Expect defects in this plan.** ADR-002's prose survived a review pass and was wrong three
  ways; this plan's numbers survived one execution pass by one session. Budget a correction round.

---

## Appendix A — raw measurements

All 2026-08-17, AILANG v0.33.0, tree at `059dbd9` plus the stated temporary edits, each reverted.
Driver phase only (`CG_EXPORT_PHASE=driver`), bisection tolerance 1, `--max-recursion-depth`
first on the argv, an abort scored only on `rc != 0` **and** an `RT_REC_003` marker.

**Calibration.** At `max_chunks = 0` the healthy depths are **58/87/75** on seeds 7/11/23 —
identical to the floors `run_depth_canary.sh` pins — and the fault-present depths are
**73/135/108**, identical to the spike's independently-derived, differently-implemented
fault-present column. Two unrelated restorations landing on the same three numbers is what you
expect if both re-created the same traversal and nothing else.

**Depth vs records, chunk draw widened to `0, 16`, export bound swept.** Left of each pair is
records, right is minimum viable ceiling.

| bound | s7 HEAD | s11 HEAD | s23 HEAD | s7 faulty | s11 faulty | s23 faulty |
|---|---|---|---|---|---|---|
| 0  | 63 / 58  | 106 / 87 | 88 / 75  | 63 / 73  | 106 / 135 | 88 / 108  |
| 1  | 68 / 58  | 115 / 87 | 96 / 75  | — | — | — |
| 2  | 72 / 58  | 123 / 87 | 104 / 75 | — | — | — |
| 3  | 76 / 58  | 131 / 87 | 112 / 75 | 76 / 86  | 131 / 157 | 112 / 129 |
| 4  | 80 / 58  | 138 / 88 | 120 / 76 | 80 / 90  | 138 / 163 | 120 / 136 |
| 8  | 95 / 61  | 159 / 89 | 145 / 78 | 95 / 105 | 159 / 183 | 145 / 160 |
| 16 | 104 / 64 | 181 / 89 | 160 / 83 | 104 / 114| 181 / 205 | 160 / 175 |

Records are identical in both conditions at every point — the depth moved and the trace did not,
so the comparison is like-for-like.

**Derived:** healthy slope 0.146 / 0.027 / 0.111; faulty slope 1.00 / 0.93 / 0.93. Healthy ratio
1.10 / 1.02 / 1.11; faulty ratio 1.56 / 1.52 / 1.62. Record range 1.65× / 1.71× / 1.82×.

**Tool-batch coverage, seeds 1–40**, counted from `"type":"native_tool_calls"` on the wire:
zero batches at seeds 3, 5, 6, 8, 17, 19, 20, 21, 22, 25, 26, 29, 35, 37, 40 (**15 of 40**); one
batch at 1, 2, 13, 16, 28, 33; two at 12, 24, 30, 31, 32, 36; ≥3 at 4, 7, 9, 10, 11, 14, 15, 18, 23, 27, 34, 38, 39 (**13 of 40**).

**Fallout, per target.** New red under the widened draw, against the seven-red baseline:
`corpus_pr` (`declared ⊆ observed` fails — the fixed bank loses class witnesses),
`seeded_generator` (20 × `generator-bound-exceeded`, 6 × `generator-choices-remapped-…`),
`depth_canary` (record-count pins only; the depth ceilings held), `test_coverage`
(`dst_generator.ail` 19/21 inline tests — the canary test and the interaction-budget test).

**Reproduction.** Each experiment is one temporary edit plus a sweep, reverted by
`git checkout`. The scripts were throwaway and are not committed, in keeping with the spike's
disposal discipline; the three edits are: `dst_generator.ail:600` `0, 3` → `0, 16`;
`export_trace.ail:107`'s `max_chunks_per_interaction` literal, swept; and, for the fault-present
column, `runtime_status_counts` restored to hand-written recursion **and**
`session.ail:2523`'s `encode(runtime_status_json(…))` hoisted back out of the `runtime_builtin`
lambda. Un-doing only the first of those measures nothing — see Correction 10.
