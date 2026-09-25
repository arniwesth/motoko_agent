#!/usr/bin/env bash
# One COLD sample: fresh never-run clone -> make CI=1 sync_packages -> target.
# Records the target's own reported ms, my wall clock, and contention evidence
# (loadavg + foreign `ailang run` processes outside this clone) so a sample
# taken on a busy machine can be identified and discarded rather than averaged in.
set -uo pipefail
PRIMARY=/workspaces/motoko_agent
COMMIT="$1"; TARGET="$2"; TAG="$3"
ROOT=/tmp/claude-1001/-workspaces-motoko-agent/bd8176ff-ae08-43f2-b32d-d7d1bfa1141e/scratchpad/d11
CLONE=$ROOT/clone-$TAG
LOG=$ROOT/log-$TAG.txt
rm -rf "$CLONE"
git clone -q --no-hardlinks "$PRIMARY" "$CLONE" 2>>"$LOG" || { echo "$TAG CLONE_FAIL"; exit 1; }
git -C "$CLONE" checkout -q "$COMMIT" 2>>"$LOG" || { echo "$TAG CHECKOUT_FAIL"; exit 1; }

# apply the working-tree constants under test, if a patch was staged for this run
if [ -n "${CONSTPATCH:-}" ] && [ -f "$CONSTPATCH" ]; then
  cp "$CONSTPATCH" "$CLONE/src/core/dst_corpus.ail" || { echo "$TAG PATCH_FAIL"; exit 1; }
fi

# THE TRAP: the tracked ailang.lock holds absolute path deps into the PRIMARY
# checkout. Without this step the clone compiles the primary's packages and
# measures the wrong tree.
( cd "$CLONE" && make CI=1 sync_packages ) >>"$LOG" 2>&1 || { echo "$TAG SYNC_FAIL"; exit 1; }
grep -q "$CLONE" "$CLONE/ailang.lock" || { echo "$TAG LOCK_NOT_REPOINTED"; exit 1; }

load_before=$(cut -d' ' -f1 /proc/loadavg)
# CONTENTION WATCHER. A foreign ailang process is identified by its WORKING
# DIRECTORY, not by its command line: the clone runs `ailang run ...
# scripts/dst/corpus_pr_dst.ail` with a RELATIVE script path, so a command-line
# filter on the clone path matches nothing and counts this sample's own work as
# contention. Anything whose cwd is outside $ROOT (i.e. in the primary checkout)
# is another agent competing for the same 8 cores, and this target's pass
# condition is wall clock.
echo 0 > "$ROOT/foreign-$TAG"
( peak=0
  while :; do
    n=0
    for pid in $(pgrep -x ailang 2>/dev/null); do
      cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null) || continue
      case "$cwd" in "$ROOT"*) continue;; esac
      grep -qa "supervisor.ail" "/proc/$pid/cmdline" 2>/dev/null && continue
      n=$((n+1))
    done
    if [ "$n" -gt "$peak" ]; then peak=$n; echo "$peak" > "$ROOT/foreign-$TAG"; fi
    sleep 2
  done ) & watcher=$!

t0=$(date +%s%N)
( cd "$CLONE" && make "$TARGET" ) > "$ROOT/out-$TAG.txt" 2>&1; rc=$?
t1=$(date +%s%N)
kill $watcher 2>/dev/null; wait $watcher 2>/dev/null

wall=$(( (t1 - t0) / 1000000 ))
load_after=$(cut -d' ' -f1 /proc/loadavg)
foreign=$(cat "$ROOT/foreign-$TAG" 2>/dev/null || echo "?")
# the target prints its own measured ms; that is the number the gate uses
reported=$(grep -oE "took [0-9]+ ms|WHOLE TARGET: [0-9]+ ms" "$ROOT/out-$TAG.txt" | grep -oE "[0-9]+" | head -1)
echo "SAMPLE $TAG rc=$rc reported_ms=${reported:-none} wall_ms=$wall load_before=$load_before load_after=$load_after foreign_ailang=$foreign"
rm -rf "$CLONE"
