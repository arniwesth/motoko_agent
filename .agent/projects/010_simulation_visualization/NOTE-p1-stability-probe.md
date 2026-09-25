# NOTE — P1 layout stability probe: measurements and the calibrated threshold

Date: 2026-08-08
Status: **Decision record.** Sets the P1 acceptance threshold that
`PLAN-map-and-overlay-p1-p3.md` task 1.4 defers to a probe, and resolves the
D2 sub-choice decision point (circle packing vs squarified treemap).
Tool: `tools/code-graph/layout/stability_probe.py` (re-runnable; `--check`
enforces every number below).
Baseline: all-profile extraction at HEAD `b23a44e`, 225 modules, 297 layout
rows, `LAYOUT_VERSION=1`, `SEP=0.06`, `PAD=0.04`.

## Headline

1. **The D2 sub-choice does not flip. Circle packing stands.** The plan's flip
   condition is "*every* candidate threshold is vacuous or unmeetable". Not
   every: single-module insertion — the common refresh — is bounded tightly and
   reproducibly (mean 0.0045, max 0.0057 in unit-root coordinates). Two of four
   mutation classes carry real thresholds.
2. **Deletion and re-areaing are not boundable at a useful level**, and this
   NOTE says so rather than inventing a number that sounds like a guarantee.
   They carry deliberately loose *regression ceilings* — they catch "the map
   fell apart", not "the map is stable".
3. **Two candidate stabilizations were tried and rejected on measurement**
   (§4). The pinned sha256 sibling order and the min-enclosing-circle frame both
   survive contact with evidence; no plan amendment is proposed.
4. **Most insertion ripple is a rigid translation of the whole map** (93–98% of
   it), not a reshuffle — recorded as a decomposition because it changes what
   the number *means* for the viewer (§3).
5. **Q4 (area = `modules.n_funcs`) shows no degeneracy** and is not switched to
   LOC (§5).

## 1. The metric, as implemented

For a snapshot pair (A, B), over nodes present in both and **outside the
expected-motion zone**: `d_i = ‖pos_B(i) − pos_A(i)‖` in unit-root coordinates
(the whole map is a circle of radius 1, so 0.01 is 1% of the map radius). Max,
mean and p95 are reported, plus the same for radius change.

**Expected-motion zone**, as the plan pinned it operationally: the subtree
rooted at the **immediate parent** of each added / removed / re-areaed node
(that container must repack — sibling motion there is legitimate) **plus the
ancestor-chain nodes themselves** (their radii legitimately grow and shrink).
Everything outside is ripple.

The probe also asserts the zone *did* move (`zone_actually_moved`) — a probe
whose expected-motion zone sat still would be measuring nothing, and its
"outside" numbers would be meaningless.

## 2. Measurements (2026-08-08)

Outside-zone displacement, unit-root coordinates:

| Fixture | n measured | mean | p95 | max | max Δradius |
|---|---:|---:|---:|---:|---:|
| add 1 module to the deepest dir (`packages/motoko-ext-compose/authoring`) | 251 | **0.004520** | 0.005307 | **0.005654** | 0.000719 |
| add 10 modules to the largest L1 package (`src/core`) | 188 | **0.018201** | 0.025077 | **0.026329** | 0.005930 |
| delete a mid-size dir (`packages/motoko-ext-compaction-ai`, 4 modules) | 251 | 0.058941 | 0.274649 | 0.378933 | 0.000522 |
| grow one module's `n_funcs` 5× | 188 | 0.110379 | 0.154359 | 0.161747 | 0.039824 |
| historical pair: `c611a78` (2026-07-08, 166 modules) → HEAD (225 modules) | 69 | 0.383297 | 0.552942 | 0.565929 | 0.026182 |

The historical pair is a **real** extraction pair, not a synthetic one: both
sides were extracted with `extract.sh --profile=all --structural-only` in
throwaway git worktrees, and both layouts were built by the committed builder.
It is a diagnostic, not an acceptance case — one month of drift added 59
modules and changed 93 nodes, so 195 of 264 nodes fall inside the
expected-motion zone and only 69 are measurable. Which commit you diff against
determines the answer, so it carries no threshold.

## 3. What the numbers mean: rigid shift vs residual

The probe decomposes outside-zone motion into the mean displacement **vector**
(a rigid translation of everything measured — every relative position is
preserved) and the **residual** after removing it (genuine reshuffling).

| Fixture | total mean | rigid shift | residual mean | residual max |
|---|---:|---:|---:|---:|
| add 1 module, deep | 0.004520 | 0.004455 | 0.000984 | 0.004210 |
| add 10 modules | 0.018201 | 0.017059 | 0.007257 | 0.018731 |
| delete mid-size dir | 0.058941 | 0.008503 | 0.063318 | 0.370509 |
| grow one module 5× | 0.110379 | 0.102577 | 0.046218 | 0.114015 |
| historical pair | 0.383297 | 0.343108 | 0.156433 | 0.465941 |

Insertion and re-areaing are 93–98% rigid: the map keeps its shape and slides.
**Deletion is the opposite** — an almost entirely non-rigid reflow (rigid
0.0085 out of a 0.0589 mean), because removing a circle lets the front chain
re-thread and downstream siblings land in different places.

This is recorded because it changes what the threshold protects. The pinned
metric is the total, and the total is what the table above is graded on — but a
reader deciding "is this map still recognisable?" should know that after adding
ten modules almost nothing moved *relative to anything else*.

**A correctness point that bounds the blast radius of all of this:** layout
stability is about *human spatial memory*, not about data correctness. The
`snapshot` key means two runs compared in an overlay are always rendered over
**one** layout — never two — and `cgq.py`'s banner refuses to let a stale layout
pass silently (Q7, task 1.5). No view joins coordinates across snapshots.

## 4. Two candidate stabilizations, tried and rejected

Both were measured against all five fixtures before being discarded; neither is
proposed as a plan amendment.

**(a) Sibling order by descending radius** (sha256 as tie-break) instead of the
pinned ascending-sha256 order. Front-chain packing is normally well-behaved
under descending-radius insertion, so this looked promising.

| Fixture | sha256 (pinned), max | descending-radius, max |
|---|---:|---:|
| add 1 module, deep | 0.005654 | 0.005651 |
| add 10 modules | 0.026329 | **0.001047** |
| delete mid-size dir | 0.378933 | 0.567716 |
| grow one module 5× | 0.161747 | 0.083241 |
| historical pair | 0.565929 | **1.389492** |

It buys a large win on batch insertion and loses badly on deletion and on the
real historical pair (1.39 exceeds the map's radius — a different picture, not a
shifted one). Rejected: not a clear win, and it would cost a pinned-spec
amendment for a trade rather than an improvement.

**(b) Area-weighted centroid as each container's frame origin**, instead of the
smallest-enclosing-circle centre. Motivated by §3: the enclosing circle's centre
is determined by a 2–3 circle basis and therefore *jumps discontinuously* when
the basis changes, which looked like the source of the rigid component. Result
(max, outside zone): 0.007339 / 0.017039 / 0.405656 / 0.131586 / 0.691738 —
marginally better in two classes, worse in three. **The hypothesis was wrong**:
the rigid shift comes from the front chain reflowing globally, not from the
choice of centre, and a centroid reflows with it. Rejected.

## 5. Q4 degeneracy eyeball — area stays `modules.n_funcs`

| quantity | value |
|---|---:|
| module radius min / median / max | 0.005800 / 0.017401 / 0.065625 |
| radius max ÷ min | 11.31 |
| `n_funcs` min / median / max | 0 / 9 / 128 |
| modules with `n_funcs = 0` (floored to area 1) | 6 |

An 11× radius spread over 225 modules is a healthy, readable range — the largest
module does not swallow the picture and the smallest stays visible. **No
degeneracy; Q4 is not switched to `source_files.n_lines`.** The alternative
stays recorded: it is a one-line change plus a probe re-run, decided here and
never silently.

## 6. The calibrated thresholds (the P1 acceptance criterion)

Encoded in `stability_probe.py:THRESHOLDS` and enforced by
`stability_probe.py --check`, so the criterion is a detector rather than a
sentence in a document.

| Fixture | kind | mean limit | max limit | measured mean | headroom |
|---|---|---:|---:|---:|---:|
| add 1 module, deep | **threshold** | 0.010 | 0.015 | 0.004520 | 2.2× |
| add 10 modules, one package | **threshold** | 0.040 | 0.060 | 0.018201 | 2.2× |
| delete mid-size dir | *ceiling* | 0.150 | 0.600 | 0.058941 | 2.5× |
| grow one module 5× | *ceiling* | 0.200 | 0.300 | 0.110379 | 1.8× |
| historical pair | none | — | — | 0.383297 | — |

**Threshold** = a stability claim: insertion ripple is bounded and a breach means
the layout engine regressed. **Ceiling** = a regression guard only; it asserts
nothing about stability, and saying otherwise would be the kind of number that
sounds like a guarantee and isn't.

Headroom is deliberately ~2×: tight enough that a real regression in the packing
or the level mapping trips it, loose enough that adding a package to the repo
does not.

## 7. Recorded consequences

- **P1 sign-off**: validator green (5 rules, 15 hermetic tests) + these numbers
  + `--check` passing. Met.
- **Open for P2 (not a P1 blocker)**: the viewer should anchor its camera on
  **node identity**, not coordinates, when the snapshot changes under it — §3's
  rigid component says a re-extraction typically slides the map rather than
  rearranging it, so "keep `src/core/session` centred" survives a refresh that
  "keep (0.31, −0.12) centred" does not.
- **Open for P5**: the deletion class's non-rigid reflow is the one case where
  spatial memory genuinely breaks. If it ever becomes painful, the recorded
  option is a stable-layout variant (anchored/ordered packing), argued as a D2
  amendment with these numbers as the baseline — not a silent swap.
