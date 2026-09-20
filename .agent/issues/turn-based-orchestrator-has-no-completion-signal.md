# Turn-based orchestrator has no timer, file-watch, or completion callback

## Status

open — filed 2026-09-19 from the PLAN-004 v2 P2.3 delegation run (graph
`.dagr/run-w3-p1-1789663745618.json`, X9 tail: 1.12 leg pid-class 1300924).

## Description

The orchestrator is turn-based: it acts only when a wake event arrives (delegate
settle, operator message, progress-guard ping). It has no timer, no file watcher,
and no completion callback. A detached leg that finishes between turns produces
nothing the orchestrator can hear.

Observed twice in one day on the same sweep:

- 12:25:16Z — the X9 1.7 leg (`x9-17.rc=0`) finished; the launching delegate had
  exited at 12:22Z with it "in flight". Nothing read the `.rc` until an operator
  typed at 12:38Z (13 min gap). Recorded in
  `DIRECTIVE-p23-17-green-chain-reentry.md` as the launcher/poller hazard.
- 13:14:15Z — the 1.11 legs finished (`x9-111.rc=0`); the launching turn had
  ended at 13:14:04Z, eleven seconds earlier. Same gap, same operator-as-scheduler
  rescue. Recorded in `DIRECTIVE-p23-notify-on-completion.md`.

## Mitigation in place (not a fix)

The notify directive (every detached leg ends with `herdr pane send-text w3:p1`
+ `send-keys enter` after writing its `.rc`, on every exit path) restores the
wake-up *if the leg finishes*: the poke lands in the composer as queued input
for the next turn. Verified mechanism (`send-text`, not agent prompt — `w3:p1`
has no named agent, `agent_prompt` returns `agent_not_ready`).

What it does not cover:

- a leg that never finishes (hang, lock stall, driver death with no `.rc` write)
  still produces silence — indistinguishable from "still running";
- ~~an unread poke is queued input, not an interrupt: if nothing else wakes the
  orchestrator, the poke sits until an operator types anyway;~~
  **Corrected 2026-09-19 (supervising session, observed): this holds only while the
  orchestrator is WORKING.** The poke's behaviour depends on the agent's state:
  - **idle** — `send-keys enter` *submits*, and submitting starts a turn. The poke IS
    the wake event; no operator is needed. Observed four times today on `w3:p1`, which
    went `idle → working` on each directive submitted this way (12:38Z, 13:25Z and two
    earlier). This is the state a leg finishes in, since the launching turn has ended,
    so it is the case the mitigation actually has to cover — and it covers it.
  - **working** — the text lands in the composer as queued input and is picked up on the
    next turn. dagr's `queued_input` liveness field exists for this. Not a lost poke.
  - **blocked** — `herdr agent prompt` rejects with `agent_blocked` before sending; the
    `send-text`/`send-keys` path was not tested against a blocked pane.

  As originally written this bullet understates the mitigation and would justify building
  a watcher that is not needed for the finished-leg case. The genuine gaps are the other
  two bullets;
- a self-polling `sleep`+check loop is the same failure shape as the drivers
  that died today (Hangup, pane churn) — one unwatched thing traded for another.

## A notify is only as good as the `rc` it carries (added 2026-09-19, supervising session)

A wake-up reporting the wrong status is **worse** than no wake-up: it settles the row
falsely instead of leaving it visibly open. Two instances of that defect, both found today
in the notify path itself:

- `x9-112.sh` — the first script the notify rule was applied to — computes `rc` from an
  `echo`, not from the work: `echo 0 > $T/x9-112.rc` then `rc=$?` captures the echo's exit
  status. Both pytest codes go to the log as `nolive=`/`live=` and neither reaches the
  `.rc`, so a failing 1.12 would poke `rc=0`. It is running with this bug now; its real
  result must be read from the log, not its `.rc`.
- The first corrected template introduced a second variant: `trap finish EXIT INT TERM HUP`.
  On SIGTERM bash runs the handler and then **resumes**, the script completes normally, and
  the EXIT trap fires again overwriting the result — measured trace `FINISH rc=97` then
  `FINISH rc=0`, i.e. a killed leg announcing success. A signal trap must exit; keep it
  separate from the EXIT trap.

Both are fixed in
[`LEG-TEMPLATE.sh`](../projects/013_core_architecture_for_dst/LEG-TEMPLATE.sh), which
derives `rc` from the work, uses a fail-closed `RC=97` sentinel so any death before
completion reports "did not run to completion", and notifies exactly once. Verified against
real signals: pass→0, leg-A-fail→1, leg-B-fail→2, SIGTERM→98, SIGHUP→98, each with exactly
one notify. **SIGKILL is uncatchable** — no `.rc`, no notify — so the poller must treat "no
`.rc` past the expected duration and the pid is gone" as failure rather than still-running.
The expected-duration field already required in the launch receipt is what makes that
decidable.

## Structural fix requested

A harness-level completion signal for detached work: a real timer, a file-watch
on `<leg>.rc`, or a completion callback that wakes the owning session. The
leg contract already exists (pid + log + `.rc` + expected duration recorded
before launch); what is missing is anything that reads the `.rc` without a
human typing first.

## Repro

1. Launch any leg >30 s detached with `.rc` + notify lines per the directive.
2. End the turn with the leg in flight.
3. Kill the session's wake source (or simply wait with no operator input).
4. Leg finishes, `.rc` sits unread; `send-text` poke queues with no turn to
   land in.

## Related

- `empty-stop-floor-event-never-reaches-the-session-journal.md` (same run,
  same shape: a terminal event with no artifact any observer can distinguish).
- `DIRECTIVE-p23-notify-on-completion.md` (the mitigation this issue asks to
  make structural).
- `DIRECTIVE-p23-17-green-chain-reentry.md` (first occurrence, 12:25Z gap).
