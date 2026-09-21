# OPERATOR DIRECTIVE 2026-09-19 14:4xZ — M15 live: contamination refuted, and it is a FIRST MEASUREMENT, not a regression

Authority: operator. Scope: P2.3, PLAN-004 v2, G1.

## 1. Contamination is refuted

`x9-112b` ran 1.12 live **alone, under the heavy lock, nothing else in flight**:

```
9 failed, 121 passed in 942.54s (0:15:42)
live=1
x9-112b finished rc=1 2026-09-19T14:34:52Z
```

Same nine `test_m15_*`, same `changed_during_run` class as the contended run. The concurrency
hypothesis — mine, in the previous directive — is wrong. Do not spend more time on it.

(Two things this run also proved: the rebuilt template reported **`rc=1`** where `x9-112.sh`'s
hardcode would have said `0` — first live proof of the fix on a failing leg. And the script is a
zombie in `ps`, not a hang: it exited at 14:34:52 and nothing reaps a `setsid` child.)

## 2. It is not a regression — those tests have never run in this round

```
test_candidate.py:56   LIVE = os.environ.get("EVAL_CANDIDATE_LIVE", "1") != "0"
test_candidate.py:57   live = pytest.mark.skipif(not LIVE, reason="EVAL_CANDIDATE_LIVE=0")
```

The M15 family is `@live`-marked. Every prior 1.12 measurement ran `EVAL_CANDIDATE_LIVE=0`, so those
tests were **skipped, not passing**. The arithmetic is exact, same 130 tests both times:

| run | failed | passed | skipped |
|---|---|---|---|
| X6 nolive (`t112-clone-nolive.log`) | 4 | 113 | **13** |
| X9 live (`x9-112b.log`) | 9 | 121 | 0 |

`EVAL_CANDIDATE_LIVE=1` appears in exactly two files in `$T`, `x9-112.sh` and `x9-112b.sh`, both
written today. `a17`'s own receipt states it: *"live-mode + A-side runs **PENDING** (wall-time)"*,
and the X6 artifact is literally named `…-nolive.log`.

So: **no bisect.** Nothing at X7/X8/X9 caused this. Row 1.12's spec is *"pytest BOTH modes"*, one
mode was deferred for wall-time every round, and the deferral was carried forward as though the row
were merely incomplete rather than unmeasured. The X9 fixes are unaffected — nolive went 4 failed →
**0 failed** across X7–X9, which is the fixes working.

## 3. What to do

1. **Characterise the nine, do not fix them yet.** All nine are `changed_during_run`. Establish what
   the assembled tree is observing as changed during a live K1–K7 run: which path, which digest, and
   whether the change is the run's own artifacts landing inside the tree being digested. One
   read-only investigation, light, detached if it exceeds the tool budget.
2. **Confirm the family is one cause, not nine.** If a single `changed_during_run` source explains
   all nine, this is one finding; if not, say so. `test_m15_clean_candidate_reproduced` failing is
   the strongest hint that the divergence is environmental rather than per-case — a clean candidate
   should reproduce.
3. **Then stop and report.** Whether this is fixed inside round 4, deferred to a named follow-up
   part, or escalated, is an operator ruling. Do not open an X10 for it without one. A nine-test
   family in the near-miss row set is not a one-item batch.

Rows 1.13 and 1.15 may proceed in parallel — they are independent of M15 and their scripts are
rebuilt from the template. One heavy at a time still applies.

## 4. Bookkeeping, carry into the next attempt

- **`progress` reads 12/18** and is wrong: 1.12 is red, 1.13 has not run. Closed on real evidence:
  1.7, 1.8, 1.10, 1.11, 1.18. Restate from the ledger.
- **`generated_at` is 14:09:25Z** against writes at 14:18+. Refresh it on every write; a stale value
  renders a staleness banner.
- **Append, do not rewrite.** `a26`'s `cause` has now been edited twice after it settled, most
  recently to carry a `SUPERSEDED` note about a directive issued eight minutes later. The
  corrections are honest; the location is not. **New work opens a new attempt; a correction to a
  settled attempt belongs in a `note` event.** Anyone reconstructing the timeline from the graph
  currently gets events dated before they happened.

## 5. Still outstanding

- Restate the carry-over: `scan.ail` differs X7 `20700842…` → X8 `0dfdee2c…`; six blobs equal, one
  differs by a line inside `test_m12_one_hit_per_component`; attach the diff.
- 1.16 teardown — operator-owned, do not execute.
- P2.3R review of X9 once the rows are in.
- Follow-up, not X9: `:437` routes on an exact error string produced by `jr_end` ~100 lines away.
