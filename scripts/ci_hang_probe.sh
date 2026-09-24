#!/usr/bin/env bash
# ci_hang_probe.sh LIMIT_SECONDS CMD [ARGS...]
#
# Run CMD. If it finishes inside LIMIT_SECONDS, exit with its status. If it is
# still alive at the limit, record what its process tree is doing, then
# SIGQUIT it -- the Go runtime in ailang answers SIGQUIT by printing every
# goroutine's stack -- and exit 124. A CI hang then fails in minutes WITH a
# signature, instead of eating the job's budget and reporting as "cancelled"
# with no log at all (runs 36010382877, 36014490004 and 36014504002 kept none).
#
# NOTHING GOES TO THE RUNNER'S PIPE WHILE CMD RUNS. The first version of this
# probe wrote its diagnostics to stdout, and in run 36014490004 it printed
# nothing: if the runner stops draining the step's stdout, CMD blocks on
# write(1) once the 64 KB pipe buffer fills, and so does the probe's first
# echo. So CMD's output and every diagnostic go to files under
# $CI_HANG_PROBE_DIR (default $RUNNER_TEMP/ci_hang_probe), which the workflow uploads as
# an artifact under always(), and stdout gets a bounded copy only afterwards:
# every line, cut to 2000 characters.
#
# What is recorded answers the open questions directly rather than by inference:
#   memory over time?      free -m, PSI, and the tree's RSS every 2 s from start
#   blocked or spinning?   CPU TIME sampled twice, 5 s apart, per process
#   blocked on what?       kernel wait channel per thread; goroutine stacks
#   stdin / stdout?        what fds 0-2 are, here and in every process of the tree
#   network?               the tree's sockets and their TCP states
#   lock / child / shm?    open fds, and the full descendant tree
#
# CMD keeps this script's stdin. A bare `&` in a non-interactive shell would
# quietly hand it /dev/null instead -- the variable under test in hypothesis 1
# -- hence the explicit 0<&0. Nothing here reads /proc/<pid>/cmdline or runs
# `ps -o args`: both take the target's mmap lock, which a process under memory
# pressure can hold for as long as the pressure lasts.
set -u

limit=$1
shift

dir=${CI_HANG_PROBE_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ci_hang_probe}
mkdir -p "$dir"
name=$(printf '%s' "${*: -1}" | tr -c 'A-Za-z0-9_.-' '_')
out="$dir/$name.out"
log="$dir/$name.probe"
mem="$dir/$name.mem"
: > "$out"
: > "$log"

note() { echo "$(date -u +%H:%M:%SZ) $*" >> "$log"; }

note "limit ${limit}s, stdin -> $(readlink /proc/$$/fd/0 2>/dev/null || echo '?'): $*"

GOTRACEBACK=all "$@" 0<&0 > "$out" 2>&1 &
pid=$!
start=$SECONDS

descendants() {
  local c
  echo "$1"
  for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do
    descendants "$c"
  done
}

(
  echo "t_s used_mb avail_mb swap_used_mb psi_mem_some_avg10 psi_mem_full_avg10 tree_rss_mb"
  while [ -d "/proc/$pid" ]; do
    rss=0
    for p in $(descendants "$pid"); do
      r=$(awk '/^VmRSS/ {print $2}' "/proc/$p/status" 2>/dev/null)
      rss=$((rss + ${r:-0}))
    done
    m=$(free -m | awk '/^Mem:/ {u = $3; a = $7} /^Swap:/ {s = $3} END {print u, a, s}')
    psi=$(awk '{split($2, a, "="); printf "%s ", a[2]}' /proc/pressure/memory 2>/dev/null)
    echo "$((SECONDS - start)) $m ${psi:-? ? }$((rss / 1024))"
    sleep 2
  done
) > "$mem" 2>&1 &
sampler=$!

alive() {
  local s
  s=$(ps -o stat= -p "$1" 2>/dev/null) && [[ $s != Z* ]]
}

while alive "$pid" && ((SECONDS - start < limit)); do
  sleep 1
done

if alive "$pid"; then
  pids=$(descendants "$pid" | xargs)
  csv=${pids// /,}
  fmt=pid,ppid,stat,wchan:32,etime,time,pcpu,rss,comm
  {
    echo "===== STILL RUNNING after ${limit}s: $*"
    echo "===== process tree ($pids)"
    ps -o "$fmt" -p "$csv"
    sleep 5
    echo "===== 5 s later -- TIME moved: spinning; TIME flat: blocked"
    ps -o "$fmt" -p "$csv"
    for p in $pids; do
      [ -d "/proc/$p" ] || continue
      echo "===== pid $p ($(cat "/proc/$p/comm" 2>/dev/null))"
      echo "--- fds"
      ls -l "/proc/$p/fd" 2>&1 | sed 1d
      echo "--- threads: tid state wchan"
      for t in /proc/"$p"/task/*; do
        echo "$(basename "$t") $(cut -d' ' -f3 "$t/stat" 2>/dev/null) $(cat "$t/wchan" 2>/dev/null)"
      done
      echo "--- kernel stack (main thread)"
      timeout 5 sudo -n cat "/proc/$p/stack" 2>&1
    done
    echo "===== sockets owned by the tree"
    timeout 5 sudo -n ss -tanup 2>/dev/null | awk -v p="$pids" '
      BEGIN { n = split(p, a, " "); for (i = 1; i <= n; i++) want["pid=" a[i] ","] = 1 }
      NR == 1 { print; next }
      { for (k in want) if (index($0, k)) { print; break } }'
    echo "===== memory"
    free -m
    cat /proc/pressure/memory /proc/pressure/cpu 2>/dev/null
    if command -v strace > /dev/null; then
      echo "===== strace -f, 5 s"
      timeout 5 sudo -n strace -f -tt -p "$pid" 2>&1 | tail -60
    fi
    echo "===== SIGQUIT to every ailang in the tree (goroutine dump lands in $out)"
  } >> "$log" 2>&1
  for p in $pids; do
    [ "$(cat "/proc/$p/comm" 2>/dev/null)" = ailang ] && kill -QUIT "$p" 2>/dev/null
  done
  sleep 10
  for p in $pids; do
    kill -KILL "$p" 2>/dev/null
  done
  wait "$pid" 2>/dev/null
  rc=124
  note "KILLED after $((SECONDS - start))s: $*"
else
  wait "$pid"
  rc=$?
  note "rc=$rc after $((SECONDS - start))s: $*"
fi
kill "$sampler" 2>/dev/null
wait "$sampler" 2>/dev/null

# Only now, and bounded: the runner sees every line of CMD's output, none
# longer than 2000 characters, then the probe's record and the memory curve.
cut -c1-2000 "$out"
echo "===== ci_hang_probe: $out is $(wc -c < "$out") bytes, $(wc -l < "$out") lines, longest $(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$out") chars"
cat "$log"
echo "===== memory, every 2 s ($mem)"
cat "$mem"
[ "$rc" = 124 ] && echo "::error title=ci_hang_probe::still running after ${limit}s: $*"
exit "$rc"
