#!/usr/bin/env bash
# PLAN-001 A1 item 6 and A3: one reminder ten minutes (dry run: three) before the cap; at the cap,
# Esc, then every process in the session's directory ended, the output hashed, the tab closed.
# Each session keeps its own clock.
#   clock.sh <names...>        prints one line per event, for sequence.log
set -uo pipefail
source "$(dirname "$0")/common.sh"
declare -A remind stop start mins
for n in "$@"; do
  start[$n]=$(sed -n 's/^start_epoch=//p' "$ROOT/collect/$n/meta")
  mins[$n]=$(sed -n 's/^minutes=//p' "$ROOT/collect/$n/meta")
done
words() { case "$1" in 10) echo Ten;; 3) echo Three;; *) echo "$1";; esac; }
pending=$#
while [ "$pending" -gt 0 ]; do
  now=$(date -u +%s)
  for n in "$@"; do
    m=${mins[$n]}; left=$(( m >= 60 ? 10 : 3 ))
    if [ -z "${remind[$n]:-}" ] && [ "$now" -ge $(( start[$n] + (m - left) * 60 )) ]; then
      herdr agent prompt "$n" "$(words $left) minutes left: write your deliverables to $ROOT/s/$n/out now." >/dev/null 2>&1
      remind[$n]=1; echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) reminder sent to $n ($left min left)"
    fi
    if [ -z "${stop[$n]:-}" ] && [ "$now" -ge $(( start[$n] + m * 60 )) ]; then
      herdr agent send-keys "$n" esc >/dev/null 2>&1; sleep 5
      # End the session completely (amendment A3): every process working in its directory,
      # Claude Code and any background job included, then hash what it left, then close its tab.
      for p in $(pgrep -u "$(id -u)"); do
        d=$(readlink "/proc/$p/cwd" 2>/dev/null) || continue
        case "$d" in "$ROOT/s/$n"|"$ROOT/s/$n"/*) kill "$p" 2>/dev/null;; esac
      done
      sleep 3
      h=$(hash_dir "$ROOT/s/$n/out"); stop[$n]=1; pending=$((pending - 1))
      t=$(sed -n 's/^tab=//p' "$ROOT/collect/$n/meta"); [ -n "$t" ] && herdr tab close "$t" >/dev/null 2>&1
      printf 'stop_utc=%s\nout_sha256=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$h" >> "$ROOT/collect/$n/meta"
      echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) stopped $n at its cap; output sha256=$h"
    fi
  done
  sleep 15
done
