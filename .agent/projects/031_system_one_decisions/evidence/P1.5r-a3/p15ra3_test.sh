#!/usr/bin/env bash
# 031 PLAN-001 P1.5r-a3: run one of the three R-G targets this part turned green, from a repo
# root -- the primary checkout or a mutgate throwaway (p15ra3_mutgate.sh). GREEN iff exit 0.
#
#   p15ra3_test.sh profile_definition   `make profile_definition`
#   p15ra3_test.sh driver_only          `make driver_only`
#   p15ra3_test.sh dvp                  `make declared_vs_performed`
#   P15RA3_RAW=<file>                   when set, the target's full output is copied there
#
# THE LOCK TRAP (as P1.7r's p17r_selftest.sh). A tracked ailang.lock pins path dependencies to
# the primary checkout's absolute path, so a compile anywhere else resolves the primary's
# packages -- and every one of these targets compiles AILANG. Anywhere but the primary this
# regenerates the lock ONCE (`ailang lock`; offline, every dependency is a path dependency) and
# refuses to go on if the new lock still names the primary.
#
# No `cmd | grep -q` under pipefail: output goes to a file first.
set -uo pipefail
mode="${1:-}"
[ -f ailang.toml ] && [ -f scripts/dst/run_declared_vs_performed.sh ] || { echo "p15ra3: run from a repo root" >&2; exit 2; }
PRIMARY=/workspaces/motoko_agent
if [ "$(pwd -P)" != "$PRIMARY" ] && [ ! -f .p15ra3-lock-regenerated ]; then
  rm -f ailang.lock
  ailang lock > .p15ra3-lock.log 2>&1 || { tail -5 .p15ra3-lock.log; echo "p15ra3: ailang lock FAILED here"; exit 2; }
  n=$(grep -c "$PRIMARY/" ailang.lock || true)
  [ "$n" = 0 ] || { echo "p15ra3: the regenerated lock still names the primary ($n)"; exit 2; }
  touch .p15ra3-lock-regenerated
  echo "p15ra3: lock regenerated for $(pwd -P) (lock-free of the primary)"
fi
OUT=$(mktemp "${TMPDIR:-/tmp}/p15ra3.XXXXXX"); trap 'rm -f "$OUT"' EXIT
case "$mode" in
  profile_definition) make profile_definition > "$OUT" 2>&1; rc=$? ;;
  driver_only)        make driver_only > "$OUT" 2>&1; rc=$? ;;
  dvp)                make declared_vs_performed > "$OUT" 2>&1; rc=$? ;;
  *) echo "usage: $0 profile_definition|driver_only|dvp" >&2; exit 2 ;;
esac
[ -n "${P15RA3_RAW:-}" ] && cp "$OUT" "$P15RA3_RAW"
# The red reason, for the mutated log mutgate keeps: every failing row, and the last line.
grep -E '✗|FAIL' "$OUT" | head -20 || true
tail -n 1 "$OUT"
echo "p15ra3: $mode exit $rc"
exit $rc
