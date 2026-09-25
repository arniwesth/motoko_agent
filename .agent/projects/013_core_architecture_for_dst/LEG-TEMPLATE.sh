#!/usr/bin/env bash
# Template for a detached P2.3 row leg. Copy, set NAME/ROW, put the work in run_legs().
#
# FIXES THE BUG IN x9-112.sh. There, line 15 wrote `echo 0 > $T/x9-112.rc` and line 16 then
# captured `rc=$?` — the exit status of that echo, not of pytest. Both pytest codes went to the
# log as `nolive=`/`live=` and neither reached the .rc, so the .rc was unconditionally 0 and a
# FAILING leg reported success to the poller and to the notify. The log held the truth; nothing
# read the log.
#
# Two rules this template enforces:
#   1. rc is derived from the work, never from an echo. Any non-zero leg makes the whole leg non-zero.
#   2. notify fires on EVERY exit path — success, failure, `set -e`, signal, unexpected death —
#      because it is a trap, not a line at the bottom that only runs when everything went well.

set -uo pipefail   # deliberately NOT `set -e`: we want to run both legs and report both.

NAME=x9-1XX                       # <-- log/rc basename
ROW=1.XX                          # <-- row id, for the notify text
PANE=w3:p1                        # orchestrator pane

T=/workspaces/p23-sweep-r4
C=$T/clone
LOG="$T/$NAME.log"
RCF="$T/$NAME.rc"
export PATH=/workspaces/ailang-pins:$PATH
export AILANG_FS_SANDBOX=/workspaces
export TMPDIR=$T/tmp
export EVAL_LOCK_PATH=$T/tmp/heavy.lock

# FAIL-CLOSED SENTINEL. 97 means "the leg did not run to completion". RC is only
# overwritten once run_legs has actually returned, so any death before that — SIGTERM,
# SIGKILL of a child, `set -e`, a syntax error in the work — reports 97, never 0.
# Tested: with RC=0 here, `kill -TERM $$` mid-leg reported rc=0, i.e. a killed run
# announcing success. That is the same defect as the x9-112.sh bug this template replaces.
RC=97

finish() {
  local trap_rc=$?
  # a clean end reports RC; if RC says success but the shell is dying non-zero, trust the shell
  local rc=$RC
  [ "$rc" -eq 0 ] && [ "$trap_rc" -ne 0 ] && rc=$trap_rc
  echo "$rc" > "$RCF"
  echo "$NAME finished rc=$rc $(date -u +%FT%TZ)" >> "$LOG"
  herdr pane send-text "$PANE" "LEG DONE: $NAME (row $ROW) rc=$rc at $(date -u +%FT%TZ) — read $LOG and continue"
  herdr pane send-keys "$PANE" enter
}
# A SIGNAL TRAP MUST EXIT. `trap finish EXIT INT TERM HUP` looks tidier and is wrong:
# on SIGTERM bash runs the handler and then RESUMES, the script finishes normally, and the
# EXIT trap fires a second time overwriting the result. Measured: trace `FINISH rc=97`
# then `FINISH rc=0` — a killed leg announcing success. Keep these two traps separate.
on_signal() { RC=98; exit 98; }   # exit re-enters the EXIT trap, which reports once
trap on_signal INT TERM HUP
trap finish EXIT

# NOT CATCHABLE: SIGKILL. Nothing can notify on `kill -9` or an OOM kill, so the poller must
# also treat "no .rc past the expected duration and the pid is gone" as a failure, not as
# still-running. The expected duration in the launch receipt is what makes that decidable.

exec 9>"$EVAL_LOCK_PATH"
if ! flock -n 9; then
  echo "$NAME: heavy lock held; abort" >> "$LOG"
  RC=99
  exit 99                         # trap still notifies
fi

echo "$NAME at $(git -C "$C" rev-parse HEAD) started $(date -u +%FT%TZ)" > "$LOG"
cd "$C" || { RC=98; exit 98; }

run_legs() {
  # --- put the work here. Capture each leg's status into a variable, not into an echo. ---
  local a b
  EVAL_CANDIDATE_LIVE=0 python3 -B -m pytest -q scripts/eval/test_candidate.py >> "$LOG" 2>&1
  a=$?; echo "nolive=$a" >> "$LOG"

  EVAL_CANDIDATE_LIVE=1 python3 -B -m pytest -q scripts/eval/test_candidate.py >> "$LOG" 2>&1
  b=$?; echo "live=$b" >> "$LOG"

  # any non-zero leg fails the row
  [ "$a" -ne 0 ] && return "$a"
  [ "$b" -ne 0 ] && return "$b"
  return 0
}

# HARD TIME BOUND. The notify closes the "leg finished" gap, but a leg that HANGS —
# a stalled driver, a lock never released, a wait on something that never comes — writes
# no .rc and sends no poke, and silence is indistinguishable from progress. Observed
# today: a driver Hangup (P2.3·a11) and a 30s-tool-budget leg that simply never started.
# Bounding the work turns a hang into an ordinary non-zero exit, which the trap already
# reports. Set LIMIT to ~2x the expected duration recorded in the launch receipt.
#
# rc 97 = did not complete (sentinel, never overwritten)
# rc 98 = signal
# rc 99 = heavy lock held
# rc 124 = EXCEEDED LIMIT  (chosen to match timeout(1)'s convention)
LIMIT=${LIMIT:-900}

# USE timeout(1), NOT a background killer. The obvious version —
#   ( sleep "$LIMIT"; kill -TERM "$work_pid" ) & killer=$!
# — is wrong here and was measured wrong: the killer subshell inherits fd 9, so its
# `sleep` keeps HOLDING THE HEAVY LOCK after the leg exits, and killing the subshell
# orphans the sleep rather than releasing it. Every following leg then aborts rc=99
# (lock held) for LIMIT seconds. timeout(1) reaps its own child, so the fd goes with it.
#
# `timeout` needs the work in a child shell, so the values run_legs reads are exported.
export LOG RCF T C NAME ROW
timeout -k 10 "$LIMIT" bash -c "$(declare -f run_legs); run_legs"
RC=$?
if [ "$RC" -eq 124 ] || [ "$RC" -eq 137 ]; then
  RC=124
  echo "$NAME EXCEEDED LIMIT ${LIMIT}s — killed" >> "$LOG"
fi
exit "$RC"
