#!/usr/bin/env bash
# verify_runtime_cancel_process_tree: the runtime-level reproduction of
# sunholo-data/ailang#2034, for SIGTERM and for SIGINT (ADR-002 D6, R10).
#
#   bash scripts/verify_runtime_cancel_process_tree.sh
#
# A plain `std/process.exec` with no Motoko code runs a command and an ordinary
# descendant, each of which writes a marker 2 s after it starts, under a 1 s
# `--process-timeout`. Once the command has started, the signal goes to the
# `ailang` pid alone. A runtime that stops the process tree leaves no marker.
#
# NOT WIRED INTO check_core UNTIL W9 (PLAN-001). It fails today, by design: W3
# records the defect and satisfies no ADR criterion. `RuntimeProcess` sends
# SIGTERM alone, so SIGINT has its evidence only here; the SIGTERM path through
# the host is src/tui/src/runtime-process.cancel.test.ts. SIGKILL is out of scope
# here. R10 keeps it a disclosed limit, and `make verify_native_process_tree`
# pins it where that target has it.
#
# Exit status:
#   0  the behaviour holds: no marker after either signal, and #2034 has changed
#   1  the defect reproduced: a marker was written after a signal (today)
#   2  the probe could not evaluate: the control failed, the command never
#      started, or the runtime did not die of the signal
set -uo pipefail

AILANG_BIN="${AILANG_BIN:-ailang}"
LIMIT=1s
SECONDS_TO_MARKER=2
# How long after the signal to keep looking, in tenths of a second. Well past the
# marker, so a loaded machine cannot read a late marker as an absent one. It stops
# early once both markers exist.
WINDOW_TENTHS=60
START_TENTHS=300

root=$(mktemp -d "${TMPDIR:-/tmp}/verify-runtime-cancel.XXXXXX") || exit 2
trap 'rm -rf "$root"' EXIT

# `ailang run` matches the module name against a relative path, so it runs from here.
cat >"$root/repro.ail" <<EOF
module repro

import std/process (exec)

export func main() -> () ! {Process} {
  let _ = exec("sh", ["-c", "printf up > \"\$PROBE_DIR/up\"; (sleep $SECONDS_TO_MARKER; printf late > \"\$PROBE_DIR/descendant\") & sleep $SECONDS_TO_MARKER; printf late > \"\$PROBE_DIR/command\""]);
  ()
}
EOF

start_runtime() { # dir: sets $pid
  (cd "$root" && PROBE_DIR="$1" exec env -u AILANG_FS_SANDBOX "$AILANG_BIN" run --caps Process --process-timeout "$LIMIT" --entry main repro.ail) >"$1/log" 2>&1 &
  pid=$!
}

wait_for_start() { # dir: returns 0 once the command has started
  local i=0
  while [ ! -e "$1/up" ] && [ "$i" -lt "$START_TENTHS" ] && kill -0 "$pid" 2>/dev/null; do
    sleep 0.1
    i=$((i + 1))
  done
  [ -e "$1/up" ]
}

yes_no() { if [ -e "$1" ]; then echo yes; else echo no; fi; }

could_not_evaluate=0
reproduced=0

# The control: the same command with no signal. The deadline reaches the tree, so
# what the signal rows see comes from the signal and not from the command.
dir=$(mktemp -d "$root/control.XXXXXX")
start_runtime "$dir"
started=no
wait_for_start "$dir" && started=yes
wait "$pid"
status=$?
sleep $((SECONDS_TO_MARKER + 1))
command_marker=$(yes_no "$dir/command")
descendant_marker=$(yes_no "$dir/descendant")
echo "control (no signal): runtime_status=$status command_started=$started command_marker=$command_marker descendant_marker=$descendant_marker"
if [ "$started$status$command_marker$descendant_marker" = yes0nono ]; then
  echo "OK: control: the deadline stopped the command and its descendant when no signal was sent"
else
  echo "FAIL: control: expected a started command, status 0 and no marker"
  could_not_evaluate=1
fi

for signal in TERM INT; do
  dir=$(mktemp -d "$root/$signal.XXXXXX")
  start_runtime "$dir"
  if ! wait_for_start "$dir"; then
    echo "SIG$signal: the command never started; log:"
    cat "$dir/log"
    kill -KILL "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    could_not_evaluate=1
    continue
  fi
  at_signal=no
  { [ -e "$dir/command" ] || [ -e "$dir/descendant" ]; } && at_signal=yes
  kill "-$signal" "$pid"
  wait "$pid"
  status=$?
  i=0
  while { [ ! -e "$dir/command" ] || [ ! -e "$dir/descendant" ]; } && [ "$i" -lt "$WINDOW_TENTHS" ]; do
    sleep 0.1
    i=$((i + 1))
  done
  command_marker=$(yes_no "$dir/command")
  descendant_marker=$(yes_no "$dir/descendant")
  echo "SIG$signal: runtime_status=$status command_started=yes marker_at_signal=$at_signal command_marker=$command_marker descendant_marker=$descendant_marker looked_for_ms~$((i * 100))"
  case "$signal:$status" in
    TERM:143 | INT:130) echo "OK: SIG$signal: the runtime died of the signal" ;;
    *) echo "FAIL: SIG$signal: the runtime died of the signal — status $status"; could_not_evaluate=1 ;;
  esac
  if [ "$at_signal" = no ]; then
    echo "OK: SIG$signal: the signal was sent before any marker existed"
  else
    echo "FAIL: SIG$signal: a marker already existed when the signal was sent"
    could_not_evaluate=1
  fi
  for row in "command:$command_marker" "descendant:$descendant_marker"; do
    if [ "${row#*:}" = no ]; then
      echo "OK: SIG$signal: the ${row%%:*} wrote no marker after the signal"
    else
      echo "FAIL: SIG$signal: the ${row%%:*} wrote a marker after the signal, past the limit (#2034)"
      reproduced=1
    fi
  done
done

if [ "$could_not_evaluate" -ne 0 ]; then
  echo "NOT EVALUATED: the probe's own preconditions failed"
  exit 2
fi
if [ "$reproduced" -ne 0 ]; then
  echo "REPRODUCED: sunholo-data/ailang#2034 on $("$AILANG_BIN" --version 2>/dev/null | head -1)"
  exit 1
fi
echo "NOT REPRODUCED: no marker after SIGTERM or SIGINT; #2034's behaviour has changed"
exit 0
