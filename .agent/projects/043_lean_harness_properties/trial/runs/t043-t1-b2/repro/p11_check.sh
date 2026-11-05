#!/usr/bin/env bash
# p11_check.sh — reproduce one P1.1 witness on the REAL code (target T1).
#
#   p11_check.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID>
#
# Each argument is a value, or the literal token UNSET. Runs the real `readHerdrEnvironment`
# (bun, gate_ts.ts) on exactly that environment, and the real `herdr_env_ready` (ailang,
# gate_ail.ail) on the same three values with UNSET passed as "" (P1.1's convention).
#
# Exit 1: the two gates disagree on this input (P1.1 violated: the defect is present).
# Exit 0: they agree. Exit 2: a tool failed, so nothing was shown either way.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../tree" && pwd)"
[[ $# -eq 3 ]] || { echo "usage: p11_check.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID> (or UNSET)"; exit 2; }

ts_env=(env -u T1_HERDR_ENV -u T1_HERDR_BIN_PATH -u T1_HERDR_PANE_ID)
ail_env=(env -u T1_HERDR_ENV -u T1_HERDR_BIN_PATH -u T1_HERDR_PANE_ID)
names=(T1_HERDR_ENV T1_HERDR_BIN_PATH T1_HERDR_PANE_ID)
args=("$@")
for i in 0 1 2; do
  if [[ "${args[$i]}" != "UNSET" ]]; then
    ts_env+=("${names[$i]}=${args[$i]}")
    ail_env+=("${names[$i]}=${args[$i]}")
  fi
done

ts=$("${ts_env[@]}" bun "$here/gate_ts.ts" "$tree") || { echo "bun failed"; exit 2; }
ail=$(cd "$here" && "${ail_env[@]}" ailang run --relax-modules --caps IO,Env --entry main gate_ail.ail 2>/dev/null | tail -1) \
  || { echo "ailang failed"; exit 2; }
[[ "$ail" == "true" || "$ail" == "false" ]] || { echo "ailang printed '$ail'"; exit 2; }

printf 'input: HERDR_ENV=%q HERDR_BIN_PATH=%q HERDR_PANE_ID=%q\n' "$1" "$2" "$3"
echo "readHerdrEnvironment -> $ts"
echo "herdr_env_ready      -> $ail"
ts_open=false; [[ "$ts" != "null" ]] && ts_open=true
if [[ "$ts_open" != "$ail" ]]; then
  echo "P1.1 VIOLATED: TS gate open=$ts_open, AILANG gate open=$ail"; exit 1
fi
echo "P1.1 holds on this input"; exit 0
