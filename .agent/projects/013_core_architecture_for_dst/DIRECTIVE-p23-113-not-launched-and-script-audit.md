# OPERATOR DIRECTIVE 2026-09-19 14:1xZ — 1.13 never launched; rebuild the launch scripts; correct progress

Authority: operator. Scope: P2.3, PLAN-004 v2, G1.

## 1. 1.13 was not launched — `a26` reported it launched and settled

`a26` (settled 14:10Z) states *"1.13 LAUNCHED (x9-113.sh patched with notify, lock-checked)"*.
Independently checked at 14:12Z, none of that holds:

- `$T/x9-113.log` **does not exist**. Line 7 of the script writes it as its first action, so the
  script never started.
- No `$T/x9-113.rc`. No `x9-` process anywhere (`ps | grep -c x9- ` → 0). Nothing written under
  `$T` since 13:55Z.
- `x9-113.sh` is dated **12:48**, unmodified since. It is **not** patched with notify — there are no
  `send-text`/`send-keys` lines in it — so even had it run, nothing would have woken you.

Nothing is running and nothing will notify. Unlike the 12:25Z and 13:14Z gaps, which were a missing
scheduler over real completed work, this one does not resolve itself: **the run is stopped while the
graph reads as progressing.**

Re-launch 1.13. Verify the launch before settling: a pid that exists, or a log file that was
written. A claimed launch with neither is not evidence.

## 2. Script audit — 5 of 6 carry the `rc` hardcode, 1 of 6 has notify

| script | notify | `rc` hardcode | row status |
|---|---|---|---|
| `x9-110.sh` | no | **no** | 1.10 green, `1 passed in 56.85s` |
| `x9-111.sh` | no | yes | 1.11 green on substance — log has the real red/green pair |
| `x9-112.sh` | **yes** | yes | 1.12 **live RED** — `.rc`=0, log `live=1` |
| `x9-113.sh` | no | yes | **never ran** |
| `x9-115.sh` | no | yes | not launched |
| `x9-118.sh` | no | yes | 1.18 green on substance — `status_rc=0`, clean, digest recorded |

The hardcode is `echo 0 > $T/x9-NNN.rc` at the end, so `.rc` is `0` whatever happened. 1.12 is the
proof: `.rc`=0 while `live=1` with 9 failures. **1.10, 1.11 and 1.18 are genuinely green — their
logs carry real pass/fail evidence — but their `.rc` files are not evidence and must not be cited as
such.** Cite the log lines.

**Rebuild `x9-113.sh` and `x9-115.sh` from
[`LEG-TEMPLATE.sh`](LEG-TEMPLATE.sh)** rather than patching them. The template derives `rc` from the
work, notifies exactly once on every catchable exit path, and uses a fail-closed `RC=97` sentinel so
a death before completion reports "did not run to completion" instead of 0. Verified against real
signals: pass→0, leg-A-fail→1, leg-B-fail→2, SIGTERM→98, SIGHUP→98, one notify each. SIGKILL is
uncatchable, so treat "no `.rc` past the expected duration and the pid is gone" as failure.

Do not hand-patch a running script: bash reads scripts by byte offset and editing one mid-run can
corrupt execution. `x9-112.sh` was left alone for that reason.

## 3. Correct `progress`

`a26` reports `12/18`. That counts 1.12 and 1.13 as closed. 1.12's live mode is **red** (9 ×
`test_m15_*`, `changed_during_run`) and 1.13 has not run. Closed on real evidence: **1.7, 1.8, 1.10,
1.11, 1.18** plus the carried rows. Restate the count from the row ledger, not from intent.

## 4. The M15 live failures — pursue contamination first

Nine failures, all `test_m15_*`, live mode only, while all 121 other tests pass and `nolive` is
clean:

```
m15_clean_candidate_reproduced        m15_inadmissible_intent_diverges_k2
m15_digest_function_only_diverges_k7  m15_inadmissible_path_diverges_k2
m15_digest_function_only_intent_diverges_k7  m15_inadmissible_path_k0_passes
m15_digest_function_only_k0_passes    m15_protected_region_search_diverges_k2
m15_evaluator_touched_diverges_k2
```

One coherent family failing `changed_during_run` reads as the tree changing under an 18-minute live
run, not as nine independent defects. Your own `a26` note (*"heavy.lock write mid-session → leaning
(a)"*) points the same way. Settle it by re-running **1.12 live alone under the heavy lock** with
nothing else in flight. If it comes back clean it was contamination; if it reproduces, it is a real
M15 regression and a much larger finding than this round.

Candidate sources worth checking first: the `x9mutgate/probe` clone, and whether any run's own
artifacts land inside the tree being digested.

## 5. Still outstanding

- **Restate the carry-over** before the review: `scan.ail` differs X7 `20700842…` → X8 `0dfdee2c…`.
  Six blobs equal, one differs by a line inside `test_m12_one_hit_per_component`, no production path
  affected; attach the diff.
- **1.16 teardown** — operator-owned, do not execute.
- **P2.3R review of X9** once the rows are in.
- **Follow-up (not X9):** `:437` routes on an exact error string produced by `jr_end` ~100 lines
  away, with nothing pinning them together.
