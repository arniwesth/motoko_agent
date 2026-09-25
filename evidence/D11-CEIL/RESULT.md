# D11-CEIL — result

Head measured: **`cdf0f65f`**, which is code-identical to PR 186's head
`42dc0c18`: `git diff 42dc0c18..cdf0f65f -- src/ scripts/ Makefile packages/
ailang.toml` is empty, the three commits between them touching only `.agent/`.

Method and traps: `METHOD.md`. Harness: `scripts/`, `per_seed_bench.ail`.

## 1. The PR target, cold

Every row is a fresh clone plus `make CI=1 sync_packages`, then the target.
`foreign` is the peak number of AILANG processes running OUTSIDE the sample's
own clone, by `/proc/<pid>/cwd`. Rows with `foreign > 0` are recorded but are
**not** used to derive anything: the target's pass condition is wall clock.

| sample | ms | rc | foreign | used |
|---|---|---|---|---|
| pr-7  | 86000 | 2 | 0 | yes |
| pr-6  | 86000 | 2 | 0 | yes |
| prb-5 | 86000 | 2 | 0 | yes |
| pr-5  | 87000 | 2 | 0 | yes |
| prb-4 | 88000 | 2 | 0 | yes |
| pr-3  | 90000 | 2 | 0 | yes |
| prb-3 | 90000 | 2 | 0 | yes |
| pr-2  | 91000 | 2 | 0 | yes |
| pr-1  | 111000 | 2 | 0 | yes |
| prb-2 | 90000 | 2 | 1 | no — contended |
| prb-1 | 94000 | 2 | 1 | no — contended |
| pr-4  | 95000 | 2 | 1 | no — contended |
| (first batch) | 97000 | 2 | ? | no — detector was cwd-blind |

**n = 9 clean. Median 88 000 ms. Slow end 111 000 ms.** `rc=2` throughout: every
one of these fails the old 80 000 ceiling, cold. CI measured **106 000 ms** on
this code at `42dc0c18` — inside the local range, BELOW the local slow end.

## 2. Where the time goes (same clone, run twice)

| | cold | warm | difference |
|---|---|---|---|
| this item | 89 562 ms | 30 073 ms | **59 489 ms is compilation** |
| WI-D4 (from the file) | 47 000–50 000 ms | 24 000 ms | ~25 000 ms was compilation |

The corpus work went 24 → 30 s. The compilation went ~25 → ~60 s. Of the ~40 s
the ceiling must absorb, ~35 s is AILANG compiling a module graph that roughly
doubled between WI-D4 and ABI 8.0. The bank is unchanged at fifteen seeds plus
one constructed member; at 416 ms/seed those fifteen are 6.2 s of the 30.

## 3. The per-seed constant

`per_seed_bench.ail`, two counts in one warm clone, after a priming run:

| n | wall | note |
|---|---|---|
| 1 | 55 282 ms | priming run — compiles the bench's own graph, not a datum |
| 25 | 17 768 ms | `BENCH seeds=25` |
| 100 | 41 558 ms | `BENCH seeds=100 loaded_bytes=372269` |

* **slope** = (41558 − 17768) / 75 = **317 ms/seed** marginal
* **fixed** = 17768 − 25×317 = **9 838 ms** process start + module load
* **file's own method**, t(100)/100, "one process start included" = **415.6 → 416 ms/seed**

**416 is taken**, not 317. Two reasons, both recorded in the file: it is the
method the 381 was measured by, and a constant re-measured by a different method
is not a comparison; and of the two honest numbers it is the one that buys
FEWER seeds per budget. Taking 317 would have restored the margin below by
picking the more flattering number.

## 4. The knock-on

`seeds_affordable_in(5000) = 5000 / 416 = 12`, against `pr_job().minimum_seeds =
12`. The brief's condition — affordable **≥** minimum — **holds**, so neither the
budget nor the minimum was moved.

It holds with **zero margin**, where at 381 it held by one seed. `ailang test
src/core/dst_corpus.ail`: 12 passed, 0 failed, including
`test_the_minimums_fit_their_measured_budgets`.

**The budget was deliberately NOT raised.** It is declared as 2.5% of `make dst`
(200 s). The only `make dst` figure this item has is a **cold, serial
(`DST_JOBS=1`) 2 670 s** run — a different quantity, and substituting it into
that rule would scale the budget off whichever number happened to be at hand.
Re-deriving the budget needs `make dst` timed the way the 200 s was. Recorded in
the file so the next person measures that first.

Scheduled job: `600000 / 416 = 1442` affordable against a minimum of 240 (~17%,
was ~15% at 381); the rotating suite's stricter row, `affordable ≥ minimum × 4`
(960), also holds.

## 5. The scheduled ceiling

`make corpus_rotating` cold, fresh clone, no contention: **68 461, 68 837,
74 505 ms**, all green. Against the declared 120 000 that is 62% at the slow end
— not near it.

`scheduled_target_ceiling_ms()` was **left at 120000**, for two reasons. Nothing
reads it: it appears in no Makefile target, no script and no workflow, so unlike
`pr_target_ceiling_ms()` — which the `corpus_pr` recipe greps out of this file —
it has no gate behind it and cannot fire however slow the target gets. And by
the file's own ratio it is already the right number: 74500 × 1.58 = 117 710,
which rounds to the 120 000 already written. The value is right; the wiring is
missing. Recorded rather than repaired — wiring it up or deleting it is a choice
for its owner, not a measurement.

## 6. The constants

    pr_target_ceiling_ms()   80000 -> 180000     111000 x 1.58 = 175380, rounded as 79000 -> 80000
    measured_ms_per_seed()     381 ->    416     41558 ms / 100 seeds
    scheduled_target_ceiling_ms()  120000 (unchanged, and unread)
    pr_job() budget_ms / minimum_seeds  5000 / 12 (unchanged)

## 7. mutgate

From a fresh clone, pre-synced (`mutgate.sh --clone-from` does a plain
`git clone` and would walk straight into the lock trap this item is about).
Spec: `mutgate_spec.tsv`. Record: `mutgate-result.tsv`.

    fix           baseline  mutated  restored  bytes  verdict
    d11_ceiling   GREEN     RED      GREEN     same   PASS
    d11_per_seed  GREEN     RED      GREEN     same   PASS

    mutgate: 2/2 discriminate, 0 failed.

Both rows needed a correction, and both corrections are findings rather than
bookkeeping:

**Row 1 — the cache is not where it looks.** The first attempt cleared `.ailang`
in the tree to force the cold run the ceiling only bites on. It scored VACUOUS:
the AILANG compile cache is GLOBAL (`~/.ailang/cache`) and keyed so a clone at a
new PATH misses it, so the tree's `.ailang` — 112K of corpus store — is not the
cache at all, and the mutated run was a warm 31 s that passes any plausible
ceiling. Fixed by pointing `AILANG_CACHE_DIR` at an empty temp dir per run, the
mechanism the Makefile already uses for its lanes. The global cache was NOT
cleared: it is shared with the other agents in this container.

**Row 2 — reverting `measured_ms_per_seed()` cannot go red, by construction.**
The brief asked for a revert to 381. The constant moved UP, so reverting it buys
MORE seeds per budget (13 against 12) and the check it feeds passes *more*
comfortably than on real code. A mutation that makes a test pass harder tests
nothing. The mutation that breaks what the check NAMES is 416 → 417:
5000/417 = 11 < 12. That one millisecond is enough is the finding — it is a
direct demonstration that the margin is now exactly zero.

## 8. The near-miss that explains CI's history

Row 1 was also tried as the literal revert the brief asked for, 180000 → 80000.
It scored VACUOUS **twice**, and the second log says why: a cold run in the
mutgate clone came in at **79 000 ms against the reverted 80 000 and passed by
one second**.

The old ceiling sits INSIDE the noise band of current cold runs (79–111 s
observed across every clone here). That is not a detail about mutgate — it is
the explanation for the CI history in the brief: one pass at exactly 80 000
against 80 000, then a failure at 106 000. The gate was not measuring the
corpus; it was measuring which second the run happened to land in.

So row 1 mutates to 50 000 — WI-D4's own measured slow end, below every cold
sample ever observed here — and discriminates deterministically. What it proves
is what matters: `pr_target_ceiling_ms()` is read by the recipe and fails the
target when it is too low.

## 9. Exit checks

**1. `make corpus_pr` green, cold, in a fresh clone — with margin.**

| run | ms | ceiling | rc |
|---|---|---|---|
| fix-pr-1 | 95 000 | 180 000 | 0 |
| fix-pr-2 | 91 000 | 180 000 | 0 |
| fix-pr-3 | 88 000 | 180 000 | 0 |
| final (exact committed bytes) | **89 000** | 180 000 | **0** |

All cold, all fresh clones, all with zero competing AILANG processes.

**2. `make corpus_rotating` green** — 77 739 ms, rc=0, cold, fresh clone, with
the new constants. (Unpatched cold baseline: 68 461 / 68 837 / 74 505 ms.)

**3. `make dst DST_JOBS=1`, run alone — 0 NEW reds.**

    baseline (unmodified cdf0f65f)  rc=2  2670 s  FAILED (12)
    with the new constants          rc=2  2408 s  FAILED (10)

    NEW reds (in fixed, not in baseline):  none
    no longer failing:                     corpus_pr, test_coverage

`corpus_pr` inside `make dst`: `✓ measured CI cost, WHOLE TARGET: 87000 ms
against a declared ceiling of 180000 ms`.

`test_coverage` also stopped failing, and this change gets NO credit for it:
the diff touches only `dst_corpus.ail`, and `test_coverage` runs its own
per-worker lanes (`TEST_COVERAGE_JOBS`) and was environmentally flaky. It is
reported because it moved, not because it was fixed.

The 10 remaining reds are all pre-existing at unmodified HEAD and are not this
item's: `driver_only`, `driver_plus_compose`, `driver_plus_no_ops`,
`ext_ambient_inventory{,_selftest}`, `ext_call_inventory{,_selftest}`,
`ext_hook_scope{,_selftest}`, `profile_definition`.

The `make dst` run above was launched against a copy of `dst_corpus.ail` taken
before two further COMMENT-only edits (restoring the WI-D4 / WI-A15 provenance
chains). Verified: stripping comment lines from the tested copy and from the
committed file leaves them byte-identical, and exit check 1's `final` row was
re-run against the committed bytes.

**4. mutgate** — 2/2 discriminate, rc=0. Section 7.

## 10. Reported, not repaired — out of this item's scope

* `scheduled_target_ceiling_ms()` is read by nothing (section 5).
* `Makefile:618` describes the ceiling as "(80 s)" in a comment. It is now
  180 s. The Makefile is outside this item's declared scope, so the stale
  parenthetical is reported rather than edited.
* `make dst` reported that `driver_plus_herdr` and `herdr_graded` are listed in
  `DST_KNOWN_RED` but PASSED, in both the baseline and the fixed run — an
  expected-failure list outliving its failures. Pre-existing, not this item's.
* The 12 baseline reds are all labelled "NEW — this one is yours" by the `make
  dst` summary even on unmodified HEAD, because none are in `DST_KNOWN_RED`.
  Anyone using that label alone to decide whether they broke something will be
  misled; the set difference against a baseline run is what settles it.
