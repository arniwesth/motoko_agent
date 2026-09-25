# OPERATOR DIRECTIVE 2026-09-19 16:5xZ — every leg carries a hard time bound; rc 124 means hung

Authority: operator. Scope: P2.3 and every later detached run in this graph.

## Why

The notify closed the "leg finished" gap and is proven in the run (15:49:22Z, `x9-115.sh:44`,
one second after the leg wrote its `rc`). It does **not** cover a leg that **hangs**: no `rc`, no
poke, and silence indistinguishable from progress. That case has already cost this round twice —
`P2.3·a11`'s driver Hangup, and the 1.13 leg that never started.

`LEG-TEMPLATE.sh` now bounds the work. A hang becomes an ordinary non-zero exit that the existing
trap reports and notifies on. **No harness change, no core change, no park/wait needed.**

Template sha256 `dd55b5763a07e6295e8f69f7fedb0702dc8f903b739afc2df55e285b51594375` — verify before
reuse, as you did for `x9-113.sh`/`x9-115.sh`.

## The rule

Set `LIMIT` on every leg to **~2× the expected duration** you already record in the launch receipt.
Default is 900 s if unset.

```bash
LIMIT=${LIMIT:-900}
export LOG RCF T C NAME ROW
timeout -k 10 "$LIMIT" bash -c "$(declare -f run_legs); run_legs"
RC=$?
[ "$RC" -eq 124 ] || [ "$RC" -eq 137 ] && RC=124   # EXCEEDED LIMIT, logged
```

## The rc vocabulary — a poller must distinguish these

| rc | meaning |
|---|---|
| 0 | all legs green |
| 1, 2, … | a leg failed with that status (derived from the work, never from an `echo`) |
| **97** | did not run to completion — fail-closed sentinel, never overwritten |
| **98** | killed by signal (INT/TERM/HUP) |
| **99** | heavy lock held; the leg never started — **re-launch** |
| **124** | **EXCEEDED LIMIT — hung.** Do not re-launch blindly; report it |

`124` is deliberately distinct from `98`: a hang and a crash want different responses, and the
previous template collapsed both into "non-zero".

## Verified before issuing

Five scenarios against the real template, each notifying exactly once:

```
pass      rc=0                  failA  rc=1      failB  rc=2
hang      rc=124  "EXCEEDED LIMIT 3s"   slow_ok  rc=0 (finished inside limit)
```

Lock released in every case (`exec 9>…; flock -n 9` → free; and runs 2–5 returned real statuses
rather than 99, which they could not have if the lock leaked). No stray processes left behind.

**One trap worth knowing, because the obvious implementation is wrong.** Do not bound the work with
a background killer:

```bash
( sleep "$LIMIT"; kill -TERM "$work_pid" ) & killer=$!      # WRONG
```

That subshell inherits fd 9, so its `sleep` keeps **holding the heavy lock** after the leg exits,
and killing the subshell orphans the `sleep` rather than releasing it. Measured: four of five
scenarios then aborted `rc=99` for `LIMIT` seconds, which would have blocked every following leg.
`timeout(1)` reaps its own child, so the fd goes with it. This was the third plausible-looking
version of this template to be wrong in a way only a real test exposed — the others were
`rc=$?`-of-an-`echo` and a `trap … EXIT INT TERM HUP` that fired twice and overwrote its own result
with 0.

## Still not covered

`SIGKILL` and OOM-kill are uncatchable: no `rc`, no notify, nothing to trap. Keep the poller rule
**"no `.rc` past the expected duration and the pid is gone → failure, not still-running."** The
expected duration in the launch receipt is what makes that decidable. This is now the only
completion case without a signal.

## Apply

Rebuild any remaining leg from the template with `LIMIT` set. Do not edit a running script — bash
reads by byte offset. State the `LIMIT` and the expected duration in each launch receipt, and treat
`124` as a finding to report rather than a transient to retry.
