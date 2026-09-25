# OPERATOR DIRECTIVE 2026-09-19 12:38Z — 1.7 came back GREEN; the poller chain dropped, re-enter

Authority: operator. Scope: P2.3, PLAN-004 v2, G1. Continues
[`DIRECTIVE-p23-x9-ruling-and-detached-runs.md`](DIRECTIVE-p23-x9-ruling-and-detached-runs.md).

## 1. 1.7 is GREEN at X9 — the result you recorded as "in flight" finished

`P2.3·a22` (settled 12:22Z) recorded the 1.7 leg as in flight. It finished **12:25:16Z**, and as of
12:38Z nothing has read it.

```
$T/x9-17.log   (sha256 a551c7ea…)
  X9-1.7 leg at e397d957c38ffe59598bdfcd9c0bb4456a0c2e0a started 2026-09-19T12:20:45Z
  1 passed in 270.23s (0:04:30)
  X9-1.7 leg finished rc=0 2026-09-19T12:25:16Z
$T/x9-17.rc    0
```

The pass is the real thing, not a weakened assertion. `test_p23_r6_d1_classes_through_shell` still
demands, for **both** cases, `returncode == 1` and exactly one `AVERDICT` row:

- unreadable dir → `MalformedEntry` at position `path` (`test_candidate.py:1352`, `:1353`)
- bad end form (`selector.txt` end `"e20"`, bare id) → `BadSelector` at position `path` (`:1367`, `:1368`)

**The distinct-label half, open since the round-3 RETURN, is satisfied.** 1.7 is the first round-4 row
to close on evidence that survives the mechanical checks the reviewer has been applying.

Its submission also carries the mutgate record — `$T/x9mutgate/mutgate.tsv` (sha256 `15931dd6…`):

```
fix  test                            baseline  mutated  restored  bytes  verdict
X9   scripts/eval/journal_replay.ail  GREEN     RED      GREEN     same   PASS
```

`GREEN → RED → GREEN` with the file digest unchanged. The test discriminates; the green means
something the previous three rounds' greens did not.

## 2. Re-enter the chain, and record the drop

Open the next attempt (`P2.3·a23`, `cause: followup, ref: P2.3·a22`) and have it:

1. read `$T/x9-17.rc` and `$T/x9-17.log`, confirm the digests above, and **settle 1.7 GREEN** in the
   row ledger with `progress` advanced;
2. record in its receipt that the chain dropped between 12:25:16Z (leg finished) and this attempt —
   no answer file, no poller. Do not paper over it: this is the known hazard of the launcher/poller
   pattern and the gap belongs on the record.

**Process correction for every future poller:** a poller must read the leg's `.rc` **before**
reporting it in flight. `a22` reported "in flight" for a run with ~3 minutes left and then nothing
checked back. Either poll to completion or hand off to a successor explicitly named in the receipt.

## 3. Remaining work — all detached, one heavy at a time

Six rows plus teardown and review:

| row | note |
|---|---|
| 1.8 | re-run — a20 flagged it STALE-CARRY (D3c) |
| 1.10 | X8/X9 leg not re-run |
| 1.11 | MUT-4 / MUT-5 legs not re-run |
| 1.12 | ×2 (both modes) |
| 1.13 | not re-run |
| 1.15 | not re-run, runs last |
| 1.18 | checkpoints, partial |
| 1.16 | teardown — **operator-owned, do not execute** |

Same conditions as the standing directive: `setsid`, pid + log + `.rc` + expected duration in the
receipt before the launching attempt settles, launcher exits in minutes, short poller reads results,
one heavy run at a time, absolute `EVAL_LOCK_PATH`, 12 GiB rule, never move the clone mid-run.

## 4. Restate the carry-over before the review — still outstanding

The claim on record is blob-equality across all seven evaluator files. That is **false** since X8:
`scan.ail` `20700842…` → `0dfdee2c…`. The change is one line inside
`test_m12_one_hit_per_component`, so no production path is affected and rows 1.3/1.4/1.5/1.6/1.9
remain carryable — but the argument must read *"six blobs equal; `scan.ail` differs by one line in a
test function, diff attached"*. `P2.3R·a5` recomputed blob ids and would stop at DIFFERS.

## 5. For the review notes — not a blocker

X9 routes on an exact error-string comparison:

```ail
Err(e) => if e == "selector.txt: end is not EndAt(_) or CutoffBefore(_)"
          then Err(jr_source_refusal(e)) else Err(jr_unreadable_refusal(e)),
```

The string is produced by `jr_end` about 100 lines away (`:335`) and nothing pins the two together.
Rewording that message silently reverts the routing. The structural fix is a typed error from
`jr_end` rather than a string; that is larger than a one-item batch and should be a named follow-up,
not folded into X9.

## 6. Graph

P2.3 currently reads `done` at `progress {done: 3, total: 18}`. It needed no manual correction this
time — `progress` made the discrepancy self-evident, which is what it is for. Keep emitting it on
every settle.
