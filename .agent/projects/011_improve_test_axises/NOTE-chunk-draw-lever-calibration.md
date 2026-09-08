# Note: the records-per-step lever, calibrated — for WI-3

Date: 2026-08-17. Measured against the tree `PLAN-resource-growth-relation.md`'s WI-1 route B
leaves (three commits on `arniwesth/mot-99-fix-max-recursion-depth-10000-exceeded`, on top of
`059dbd9`). AILANG v0.33.0.

**What this note is for.** WI-1's cluster A was commissioned to build a lever, not a relation, and
`HANDOFF-declare-the-chunk-draw-range.md`'s last guardrail says so: *"If commit 3 tempts you into
measuring a slope because the data is right there — write the numbers into a note for WI-3 and
stop."* So there is **no depth measurement and no slope below.** What is below is the lever's
calibration, the evidence that it holds the trajectory fixed, and three things about it that WI-3
would otherwise have to rediscover.

---

## 1. How to drive it

```bash
CG_EXPORT_PHASE=driver CG_EXPORT_SEED=7 CG_EXPORT_PROFILE=driver_only \
CG_EXPORT_CHUNK_DRAW_HI=16 CG_OUT_DIR="$(mktemp -d)" \
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
    --entry main scripts/dst/export_trace.ail < /dev/null
```

The phase line now reports the lever it ran at:

```
export_trace: phase=driver — 104 records, run_complete=true, chunk_draw_hi=16
```

**Unset, or unparseable, means 3** — today's value — so `make depth_canary`'s three pinned record
counts are untouched and the default export path is byte-identical. A **widened run refuses to
write a trace document at all**: overlay trace v1's header records the rig, the profile and the
generator version and has no field for a bounds override, so writing one would be the silent fork
of the rig that `export_trace.ail`'s own header refuses by name. It is a measurement seam, the same
shape as `CG_EXPORT_PHASE=driver` beside it.

## 2. The calibration table

Records off the phase line; steps, provider calls and tool batches counted from the driver's stdout
wire stream, the way Correction 11's sweep counted them.

| seed | lever | records | steps | provider calls | tool batches |
|---|---|---|---|---|---|
| 7  | 0  | 63  | 6 | 6 | 4 |
| 7  | **3 (default)** | **79**  | 6 | 6 | 4 |
| 7  | 4  | 68  | 6 | 6 | 4 |
| 7  | 8  | 96  | 6 | 6 | 4 |
| 7  | 16 | 104 | 6 | 6 | 4 |
| 11 | 0  | 106 | 9 | 9 | 8 |
| 11 | **3 (default)** | **126** | 9 | 9 | 8 |
| 11 | 4  | 118 | 9 | 9 | 8 |
| 11 | 8  | 140 | 9 | 9 | 8 |
| 11 | 16 | 181 | 9 | 9 | 8 |
| 23 | 0  | 88  | 8 | 8 | 6 |
| 23 | **3 (default)** | **96**  | 8 | 8 | 6 |
| 23 | 4  | 107 | 8 | 8 | 6 |
| 23 | 8  | 123 | 8 | 8 | 6 |
| 23 | 16 | 160 | 8 | 8 | 6 |

**Range achieved, against the c=0 floor:** 104/63 = **1.65×**, 181/106 = **1.71×**, 160/88 =
**1.82×**. Those are the plan's three figures to three significant figures, and the endpoint record
counts — 63/106/88 and 104/181/160 — reproduce its Appendix A rows exactly. Two independently
implemented levers landing on the same six numbers is the calibration.

## 3. The trajectory does not move, and this is the strong form of that claim

The plan's relation rests on trajectory length being held fixed while records vary. The counters
above are constant down every seed's column. Stronger, and cheap to re-run: the **whole wire-record
type histogram** at the default lever and at 16 differs in **exactly one type**, on all three
seeds.

```
seed 7:   16 "type":"thinking_delta"   ->   41    (every other type identical)
seed 11:  20 "type":"thinking_delta"   ->   75
seed 23:   8 "type":"thinking_delta"   ->   72
```

`thinking_delta` is the chunk record. Nothing else on the wire changes count. That is
"differing **only** in records-produced-per-step" as an observation rather than as a clause.

## 4. Three things WI-3 should not have to rediscover

**a. Records are NOT monotone in the lever, and seed 7 at hi=4 is the counterexample: 68 records
against 79 at hi=3.** `draw_between(g, s, 0, hi)` calls `draw(g, s, hi + 1)`, so changing `hi`
changes the *modulus* and re-rolls every chunk count — it does not widen a distribution, it
replaces one. The trend over the range is up; individual steps are not.

Consequence for WI-3, and it is the reason this is the first item: plan §WI-4 proposes seeding each
scale point's bisection from the previous point's answer, on the ground that "depth is monotone in
records, so the previous answer is a valid `lo`". That premise is about depth versus records and is
untouched — but a harness that seeds by **lever** rather than by measured record count will pass an
invalid `lo` at any point where records fall. **Sort the scale points by measured records, not by
knob value**, or measure records first and bisect second.

**b. This lever is not the plan's appendix lever, and the middle of the two tables disagrees for a
good reason.** Appendix A swept `max_chunks_per_interaction` with the draw pinned wide at `0, 16`,
so its interior rows measure a *clamp* — many draws collapsing onto the limit. This one moves the
draw range and raises the declared limit with it, so nothing clamps and no `BoundFailure` is
recorded. The two agree at both endpoints, where clamp and range coincide (hi=0: 63/106/88; hi=16:
104/181/160), and differ in between (bound 4: 80/138/120 there, hi=4: 68/118/107 here). Neither is
wrong. **Quote one table or the other, not rows from both.**

**c. `max_chunks_per_interaction` rises with the lever inside `export_trace`, and it must.** A
range wider than the declared limit would do both of the things that ruin the measurement at once:
cap records at the limit, and report every run as a `generator-bound-exceeded` failure —
`HarnessHygiene` requires zero. The expression is `if chunk_draw_hi > 4 then chunk_draw_hi else 4`,
so the default is unchanged at 4. This is local to the exporter's own bounds; the **generator's**
two quantities stay separate for the opposite reason, see `GeneratorBounds`'s comment and
`canary_bounds_tight`.

## 5. What is still true and untouched

- **`make depth_canary` is green** at all three commits, all four rows, pins unmoved at 79/126/96.
  It is still the only gate on motoko_agent#160 and WI-3 is what supersedes it.
- **Tier 0 cannot be retired** (Correction 10). Nothing here changes that: no generated world
  requests `MotokoRuntimeStatus`, and the chunk lever does not make one.
- **No slope, no threshold, no new gate** was built. WI-3 owns all three, and its acceptance is
  still that the relation goes red with **both** halves of the #160 fix un-done.

## 6. Still open, and not this cluster's

`anchors` and `attribution_table` are red at HEAD and remain red: five pinned `src/core/session.ail`
line anchors no longer name a routed core clock site, from the #160 fix's own line drift. The
target's message says the repair is a D4 judgement that re-issues three profile versions across
eleven files. It belongs to whoever lands #160, and putting it inside a commit about generator
bounds is exactly what it should not be.
