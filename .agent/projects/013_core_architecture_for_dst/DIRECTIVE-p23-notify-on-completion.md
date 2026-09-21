# OPERATOR DIRECTIVE 2026-09-19 13:2xZ — every detached leg must wake the orchestrator when it finishes

Authority: operator. Scope: P2.3 and every later detached run in this graph.

## The problem, stated exactly

You are turn-based. You have no timer, no file watcher and no completion callback. When you write
*"Polling `x9-111.rc` — next report when the legs land"* and end your turn, nothing will ever make
you look. `x9-111` finished at 13:14:15Z; your turn ended at 13:14:04Z, eleven seconds earlier, and
the result sat unread until an operator typed.

The same thing happened at 12:25:16Z with the 1.7 leg. Neither was a dropped chain — **there was
never anything to continue it.** The operator has been acting as your scheduler on every detached
run in this round.

Detached execution is correct and stays (a 30 s tool budget cannot hold a 40–300 s leg). What is
missing is the wake-up.

## The rule — from the next launch onward

Every wrapper that launches a detached leg must notify this pane on completion. Two lines after the
`.rc` write:

```bash
rc=$?; echo $rc > "$T/x9-<row>.rc"
herdr pane send-text w3:p1 "LEG DONE: x9-<row> rc=$rc at $(date -u +%FT%TZ) — read $T/x9-<row>.log and continue"
herdr pane send-keys w3:p1 enter
```

Verified reachable from exactly the context these run in: `setsid bash -c` with
`PATH=/workspaces/ailang-pins:$PATH` resolves `/usr/local/bin/herdr` and reaches the socket API.
Use `herdr pane send-text` + `send-keys`, **not** `herdr agent prompt` — the latter requires a named
agent and `w3:p1` has none (it returns `agent_not_ready`).

Notes:

- A notification arriving while you are mid-turn lands in the composer as **queued input**, not an
  interrupt; you pick it up on your next turn. That is fine and is what dagr's `queued_input`
  liveness field is for. An unread poke is not a second failure.
- Notify on **every** exit path, including failure. `rc` non-zero is exactly when someone needs to
  know. Put the notify after the `.rc` write so the record exists before the poke.
- One notify per leg. Do not add retries; a missed poke is recoverable by reading the `.rc`, a
  notify loop is not.
- Keep the `flock` discipline unchanged: the notify happens after the lock is released.

## Apply it now

1.11 landed green (`x9-111.rc` = 0; `mut5red=1`, restored `1 passed in 60.34s`, `mut5green=0`). The
heavy slot is free and nothing is in flight.

Continue with the remaining rows — **1.12 ×2, 1.13, 1.15** — one heavy at a time, each launched with
the notify lines above, then **1.16 teardown is operator-owned; do not execute it.**

Still outstanding from the standing directive, unchanged:

- **Restate the carry-over** before the review: `scan.ail` differs X7 `20700842…` → X8 `0dfdee2c…`,
  so "all seven evaluator blobs equal" is false. Six equal; one differs by a single line inside
  `test_m12_one_hit_per_component`; no production path affected; attach the diff. A reviewer
  recomputing blob ids stops at DIFFERS otherwise.
- **P2.3R review of X9** once the rows are in.
- **Follow-up, not for X9:** the `:437` routing compares an exact error string produced by `jr_end`
  ~100 lines away, with nothing pinning them together. Rewording that message silently reverts the
  routing. A typed error from `jr_end` is the structural fix; name it as a follow-up part.

## Keep emitting `progress`

`{done, total}` on every settle. It is working — P2.3 read `done` at `3/18` and again at `7/18` and
both were self-evidently wrong from the data alone, with no manual correction needed. That is the
first time in this run that the projection error did not require a human to read a row table.
