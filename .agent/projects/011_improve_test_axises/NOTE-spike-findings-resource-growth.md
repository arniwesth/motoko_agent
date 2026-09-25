# Findings: does the resource-growth relation hold on the real driver?

Date: 2026-08-17. Status: complete, dispositioned into this note.

_Executed `PLAN-spike-resource-growth-feasibility.md` in full. **Q1 confirms, Q3 is measured,
Q4 confirms. Q2 and Q5 both falsify**, and each falsification is a change ADR-002 needs before
`PLAN-resource-growth-relation.md` can be written._

_Revision: throwaway branch `spike/011-resource-growth-feasibility`, forked from `c320269`, cut
**before** any fix to `session.ail:2470` exactly as the plan requires — the fold was verified
present in the tree at fork. **That branch never merges.** It carries three edits and nothing
else: a bounds knob in `scripts/dst/export_trace.ail` (Q2), a `SPIKE_PHASE` phase ablation in the
same file (Q5), and the `session.ail:507` measurement instrument (Q4). All three are marked
`SPIKE ONLY … NEVER MERGES` in place._

_Toolchain: AILANG v0.33.0 `ae36986`, released, unmodified._

**The headline.** The relation works, the fault is real and visible on `driver_only`, and the fix
collapses it to *exactly* flat. But **ADR-002 measures the wrong process and states the relation on
the wrong statistic**, and either error alone is enough to make the first implementation useless:

- Bisecting the `export_trace` process — the process ADR-002 names — reports **86 for both the
  faulty and the fixed driver** at the top of the range. The exporter's own serializer masks the
  signal completely.
- The available input range is **1.25×, not 8×**, so the growth *ratio* separates 1.06–1.18 from
  1.00. Stated as a ratio with the tolerance of "2–3×" ADR-002 contemplates, the relation is green
  on the known-bad system. Stated as a **slope** it separates 0.75–0.90 frames/record from
  **exactly 0.00**.

## Instrument calibration, before any number below

The plan's appendix demands one known-depth run every time the command line changes. Done first,
and it is the reason the rest of this note is trustworthy.

A program that recurses exactly *n* deep, bisected over the range 1…200 000:

| known n | bisected | delta |
|---|---|---|
| 100 | 101 | +1 |
| 500 | 501 | +1 |
| 1074 | 1075 | +1 |
| 2000 | 2001 | +1 |

Exact at every point; the constant +1 is `main`'s own frame. **Trap 2 reproduced live**: with
`--max-recursion-depth 50` placed *after* the `.ail` path, a program needing 1000 frames exits 0.
The bisection harness therefore inserts the flag first, requires `rc != 0` **and** an `RT_REC_003`
marker to score a run as an abort, and aborts loudly on a non-zero exit without the marker. It also
asserts that `lo` fails and `hi` passes before bisecting, so it cannot silently report a range
endpoint as a depth.

**Correction to the plan's appendix.** It records `driver_only` seed 7 at depth **98**. The true
value is **86**. 98 is the appendix's own tolerance-32 bisection returning `hi`, i.e. an
overestimate by up to 32, not a different measurement. Nothing downstream of it changes; the
appendix's tolerance should be tightened to 1 (it costs 5 more subprocess runs, ~2 s) before the
number is quoted anywhere.

## Q1 — Does `driver_only` exhibit the fault? **CONFIRMS.**

Measured on the driver phase alone (Q5's ablation; see below for why that qualifier is mandatory).
Trajectory length is held fixed by construction and this was *verified*, not assumed — across the
whole chunk sweep the decision count, the provider-call count and the tool-batch count are all
constant, and only `StreamDelta` volume moves:

| seed | decisions | tool batches | records c=0 → c=3 | depth, fault present | depth, fault removed |
|---|---|---|---|---|---|
| 3  | 2  | **0** | 9 → 12    | 28 → 28  | 28 → 28 |
| 7  | 15 | 4 | 63 → 79   | **73 → 86** | 58 → 58 |
| 11 | 26 | 8 | 106 → 126 | **135 → 153** | 87 → 87 |
| 23 | 21 | 6 | 88 → 96   | **108 → 114** | 75 → 75 |

Seed 7 at four points, the full curve: records 63 → 69 → 74 → 79 gives depth **73 → 78 → 82 → 86**
with the fault present and **58 → 58 → 58 → 58** with it removed.

The plan's named falsification hypothesis — "the `RunTools` arm carrying `session.ail:2470` is
rarely reached" — is **dead as stated**: seed 7 reaches it 4 times, seed 11 eight times, seed 23
six times.

**But it is alive one level down, and this is a finding the eventual gate must handle.** Seed 3
draws a trajectory that terminates after 2 decisions with **zero tool batches**, so the faulty line
is never executed and the depth is flat at 28 in *both* conditions. On that seed the relation is
green on a known-bad system. **Tool-arm coverage is a property of the seed, not of the profile**, so
a gate that runs one seed can be silently vacuous. Either the gate asserts a minimum tool-batch
count as a precondition, or it runs a seed set — this is a decision `PLAN-resource-growth-relation.md`
must make and ADR-002 does not currently anticipate.

## Q2 — Does `max_chunks_per_interaction` move the record count? **FALSIFIES.**

Neither the way the plan predicted. The bound is **not** pinned in `driver_only_manifest` and needs
no manifest seam: `export_trace.ail` carries its own local `bounds()` literal (deliberately
replicated verbatim from `corpus_pr_dst`), so making it a parameter is a three-function edit. And
the generator **does** draw chunks. The knob works — it just has almost no range.

`dst_generator.ail:598`:

```
let d_chunks = bounded_draw(d_arg.state, "${salt}|chunks", 0, 3,
                            "max_chunks_per_interaction", g.bounds.max_chunks_per_interaction);
```

`bounded_draw` (`dst_generator.ail:429`) draws from `lo..hi` and then **clamps downward** to the
limit. The draw range is the hardcoded literal `0, 3`. So `max_chunks_per_interaction` is a
*ceiling on a draw that never exceeds 3*: raising it above 3 is a no-op by construction.

Measured, seed 7 — the traces at c=4, 8, 16 and 32 are **byte-identical**:

| max_chunks | 0 | 1 | 2 | 3 | 4 | 8 | 16 | 32 |
|---|---|---|---|---|---|---|---|---|
| records | 63 | 69 | 74 | 79 | 79 | 79 | 79 | 79 |
| StreamDelta | 0 | 6 | 11 | 16 | 16 | 16 | 16 | 16 |

**Consequence for ADR-002, and it is structural.** The relation's independent variable has a usable
range of **1.25× in record volume** (63 → 79), against the **8×** every synthetic number in ADR-002
was measured over. Widening it means changing the `0, 3` draw range in core `dst_generator.ail` —
which moves every pinned canary digest that walks the chunk draw (`canary_bounds` exists precisely
to certify that path). That is core generator work with pinned-artifact fallout, not a flag, and
**`PLAN-resource-growth-relation.md` must budget it explicitly rather than assume the knob scales.**

## Q3 — How wide is the real separation? **Measured. The ratio is narrow; the slope is total.**

Because the range is 1.25× rather than 8×, the two statistics disagree about whether this relation
is implementable:

| seed | growth *ratio*, fault present | growth *ratio*, fault removed | *slope* present (frames/record) | *slope* removed |
|---|---|---|---|---|
| 7  | 1.18× | 1.00× | 0.81 | **0.00** |
| 11 | 1.13× | 1.00× | 0.90 | **0.00** |
| 23 | 1.06× | 1.00× | 0.75 | **0.00** |

Against ADR-002's synthetic baseline of **1.3× (healthy) versus 6.5× (faulty)** over an 8× scaling:
the faulty population has collapsed from 6.5× to **1.06–1.18×**, and — note the direction — the
*healthy* population is now **tighter** than synthetic, 1.00× rather than 1.3×.

**Read as a ratio this is Q3's stated red.** ADR-002 contemplates "a factor of 2–3" as a tolerance
sitting "far from both populations"; at 1.06× versus 1.00× no such tolerance exists, and a 2× gate
is green on every faulty seed measured. The plan says that outcome "sends ADR-002 back for rework —
which is a legitimate outcome of this spike and must not be argued around."

**Read as a slope it is a clean green, and the slope is the honest statistic.** The faulty driver
costs ~0.8 interpreter frames per accumulated record; the fixed one costs **exactly zero**, at every
point, on every seed, with no per-step allowance needed. The separation is not 20× — it is
*qualitative*, flat versus linear, and it is robust because the fixed measurement is not
approximately flat but identically flat.

This is a real revision to ADR-002, not a restatement. ADR-002's *Consequences* argues the tolerance
"must be stated as 'constant factor plus per-step allowance', never as 'flat'", citing its synthetic
healthy driver's 73 → 98 drift. **On the real driver that drift does not exist**: with trajectory
length held fixed, the healthy floor does not move at all, because a step's own records are walked
inside the step and never re-walked. The per-step allowance was an artefact of the synthetic probe.
A slope-based relation with a threshold anywhere in (0, 0.75) is decidable today at 1.25× range,
where no ratio-based relation is.

## Q4 — Does the #160 fix collapse the growth factor? **CONFIRMS, completely.**

The instrument replaces `session.ail:507`'s

```
let counts = runtime_status_counts_add(st.prior_counts, runtime_status_counts(st.trace));
```

with `let counts = st.prior_counts;` — it removes the `O(|st.trace|)` traversal and changes nothing
else. It is deliberately *not* the #160 fix: it undercounts, where the real fix maintains
`prior_counts` incrementally and keeps the numbers correct. It exists to move one number.

It moves it to zero. Every seed goes from a rising curve to an identically flat one (table under
Q1), and — checked, because it would invalidate the comparison — **the trace itself is unchanged**:
record counts, decision counts and `StreamDelta` counts are identical in both conditions at every
scale point. The measurement is like-for-like.

`runtime_status_counts` (`session.ail:488`) reaches `runtime_status_counts_rec` over `trace.records`,
non-tail. **It is the only `O(|accumulated state|)` traversal on the driver path**: removing it
alone takes the slope to exactly 0.00, so the issue record's fix list is complete for the paths
`driver_only` walks. Q4's falsification branch — "a second traversal survives" — does not fire.

**The floor is attributed** (the appendix requires this before the curve is trusted), and it is
explained by trajectory length exactly as predicted:

| decisions | 2 | 15 | 21 | 26 |
|---|---|---|---|---|
| flat floor | 28 | 58 | 75 | 87 |

≈ 2.4 frames per step plus a ~23-frame constant. That is `c2_loop`'s known linearity in steps, which
is why the relation varies records and holds steps fixed. Nothing unexplained dominates the floor.

## Q5 — Is anything else on the measured path frame-deep? **FALSIFIES. The exporter masks everything.**

This is the most consequential finding, and it is the *third* instance of the confounder ADR-002's
own review already caught twice.

**Bisecting the whole `export_trace` process cannot decide the relation.** With the fault removed —
a driver that is flat at 58 — the full export process still rises with record volume:

| seed 7 | recs 63 | 69 | 74 | 79 |
|---|---|---|---|---|
| whole export, fault present | 73 | 78 | 82 | **86** |
| whole export, fault removed | 70 | 76 | 81 | **86** |
| driver phase only, fault present | 73 | 78 | 82 | **86** |
| driver phase only, fault removed | **58** | **58** | **58** | **58** |

At the top of the range the faulty and the fixed driver both report **86**. The two rows ADR-002
needs to separate are the two rows the instrument it specifies cannot tell apart.

The site is `scripts/dst/export_trace.ail:237`:

```
r :: rest => record_line(seed, idx, r) :: record_lines(seed, idx + 1, rest)
```

One frame per record, over exactly the accumulated state the relation measures. ADR-002's scope
requirement — "the measured process must run the driver and serialize its trace, with invariant
evaluation in a separate process" — **puts the masking traversal inside the measured process by
name.** The requirement is right that `dst_invariants.evaluate` must be excluded; it is wrong that
serialization may be included. The measured phase must be narrower than the export: run the driver,
touch the trace only through frame-free operations, and serialize in a separate process or not at
all. The spike ablated this with a `SPIKE_PHASE=driver` branch that reports `List.length` and skips
`document()` entirely.

**Corollary, and it is a trap worth writing down.** The obvious repair — rewrite `record_lines`
with an accumulator so it is tail-recursive — **does not work, and it was tried.** AILANG has no
TCO, so a tail call costs a frame exactly like a non-tail one; measured, accumulator recursion
building a 400-element list costs 401 frames. The rewrite left the export curve rising with an
*identical* slope. Re-measured alongside it, `join`, `List.map`, `::` and `List.length` all cost
**zero** frames over a 400-element list, consistent with the plan's settled facts. **The only
frame-free traversal in this codebase is a stdlib builtin**; any hand-written recursion over
accumulated state is `O(n)` deep however it is written, and "make it tail-recursive" is not a
remedy for anything here.

## What this note does not establish

- **Nothing above says the relation is calibrated.** It says the instrument fires on a known-bad
  driver and is silent on a fixed one, over the trajectories four seeds happened to walk. Whether
  an `O(|state|)` per-step traversal exists that these trajectories do not reach is §3.3's question
  and is untouched.
- **The 1.25× range is the whole evidence base for Q3.** Both statistics are extrapolations from a
  narrow lever, and the slope's robustness rests on the fixed driver being *identically* flat rather
  than on the range being wide.
- **`driver_only` only.** No second profile was measured; the plan puts that out of scope.
- **The #160 fix is not reviewed.** A green Q4 is evidence that the traversal is the cause, not that
  the instrument's one-line replacement is the right production change.

## Disposition

**Against ADR-002** — three corrections, in the same shape as the two its review already carries:

1. **The measured phase must be narrower than the export process** (Q5). The scope requirement
   currently names `export_trace` as the process to bisect and excludes only invariant evaluation;
   `record_lines` masks the signal from inside it, to the point that faulty and fixed report the
   same number. Third instance of the maximum-wins confounder.
2. **The relation must be stated on the slope, not the growth ratio** (Q3). At the range the
   generator actually offers, a 2–3× ratio tolerance is green on every faulty seed measured. The
   *Consequences* text about a mandatory "per-step allowance" should go with it: on the real driver,
   with steps held fixed, the healthy floor is identically flat.
3. **`max_chunks_per_interaction` is a clamp, not a scale** (Q2). ADR-002 assumes the record volume
   can be scaled 8×; the draw range is hardcoded `0, 3` and the usable range is 1.25×. The
   *Why this is the right measurement* table should be rewritten against the Q1/Q3 numbers here,
   which is what the plan's Disposal section reserves for it.

**Against `PLAN-resource-growth-relation.md`, when written** — budget the `dst_generator.ail:598`
draw-range change and its pinned-canary fallout if a wider lever is wanted; decide the seed-set
question raised by seed 3 (a seed with no tool batches makes the relation vacuously green).

**Against `.agent/issues/per-step-trace-fold-exceeds-recursion-depth.md`** — Q4 is a positive
result for the fix list: `runtime_status_counts` is the only `O(|accumulated state|)` traversal on
the driver path for the trajectories measured, and removing it takes the slope to exactly zero. No
incompleteness to file.

**Against the plan's own appendix** — seed 7's `driver_only` depth is 86, not 98; tighten the
bisection tolerance from 32 to 1 before quoting it.

**Dies with the branch:** the bounds knob, the `SPIKE_PHASE` ablation, the `session.ail:507`
instrument, the bisection harness and the calibration probes.
