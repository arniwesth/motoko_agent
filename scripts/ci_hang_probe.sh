#!/usr/bin/env bash
# ci_hang_probe.sh LIMIT_SECONDS CMD [ARGS...]
#
# Run CMD. If it finishes inside LIMIT_SECONDS, exit with its status and print
# one timing line. If it is still alive at the limit, print what its process
# tree is doing, then SIGQUIT it -- the Go runtime in ailang answers SIGQUIT by
# printing every goroutine's stack -- and exit 124. A CI hang then fails in
# minutes WITH a signature, instead of eating the job's budget and reporting as
# "cancelled" with no log at all (run 36010382877 kept none).
#
# What is printed answers the open questions directly rather than by inference:
#   blocked or spinning?   CPU TIME sampled twice, 5 s apart, per process
#   blocked on what?       kernel wait channel per thread; goroutine stacks
#   stdin?                 what fd 0 is, here and in every process of the tree
#   network?               the tree's sockets and their TCP states
#   lock / child / shm?    open fds, and the full descendant tree
#   memory?                RSS, free -m, PSI
#
# CMD keeps this script's stdin. A bare `&` in a non-interactive shell would
# quietly hand it /dev/null instead -- the very variable under test -- hence
# the explicit 0<&0.
set -u

limit=$1
shift

echo "ci_hang_probe: limit ${limit}s, stdin -> $(readlink /proc/$$/fd/0 2>/dev/null || echo '?'): $*"

GOTRACEBACK=all "$@" 0<&0 &
pid=$!
start=$SECONDS

alive() {
  local s
  s=$(ps -o stat= -p "$1" 2>/dev/null) && [[ $s != Z* ]]
}

while alive "$pid" && ((SECONDS - start < limit)); do
  sleep 1
done

if ! alive "$pid"; then
  wait "$pid"
  rc=$?
  echo "ci_hang_probe: rc=$rc after $((SECONDS - start))s: $*"
  exit "$rc"
fi

descendants() {
  local c
  echo "$1"
  for c in $(ps -o pid= --ppid "$1" 2>/dev/null); do
    descendants "$c"
  done
}

pids=$(descendants "$pid" | xargs)
csv=${pids// /,}
fmt=pid,ppid,stat,wchan:32,etime,time,pcpu,rss,args

echo "::error title=ci_hang_probe::still running after ${limit}s: $*"
echo "===== ci_hang_probe: process tree ($pids)"
ps -o "$fmt" -p "$csv"
sleep 5
echo "===== 5 s later -- TIME moved: spinning; TIME flat: blocked"
ps -o "$fmt" -p "$csv"

for p in $pids; do
  [ -d "/proc/$p" ] || continue
  echo "===== pid $p: $(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-200)"
  echo "--- fds"
  ls -l "/proc/$p/fd" 2>&1 | sed 1d
  echo "--- threads: tid state wchan"
  for t in /proc/"$p"/task/*; do
    echo "$(basename "$t") $(cut -d' ' -f3 "$t/stat" 2>/dev/null) $(cat "$t/wchan" 2>/dev/null)"
  done
  echo "--- kernel stack (main thread)"
  sudo -n cat "/proc/$p/stack" 2>&1
done

echo "===== sockets owned by the tree"
sudo -n ss -tanup 2>/dev/null | awk -v p="$pids" '
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

echo "===== SIGQUIT to every ailang in the tree (goroutine dump follows on stderr)"
for p in $pids; do
  [ "$(cat "/proc/$p/comm" 2>/dev/null)" = ailang ] && kill -QUIT "$p" 2>/dev/null
done
sleep 10
for p in $pids; do
  kill -KILL "$p" 2>/dev/null
done
wait "$pid" 2>/dev/null
echo "ci_hang_probe: KILLED after $((SECONDS - start))s: $*"
exit 124
