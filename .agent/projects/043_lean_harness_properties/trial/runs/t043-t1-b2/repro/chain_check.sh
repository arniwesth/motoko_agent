#!/usr/bin/env bash
# chain_check.sh — the herdr gate END TO END on the REAL code (target T1, exploratory X-1, X-2).
#
#   chain_check.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID>      (each a value or UNSET)
#
# P1.1 compares the two functions with "unset" mapped to "". The running system does not map
# it that way, so this follows the variables along the real path instead:
#
#   1. the pane environment is exactly the three variables (plus HERDR_ORCHESTRATOR=off, which
#      only stops the extension reading dagr files) over PATH and HOME;
#   2. in it, the REAL host code (chain_ts.ts) computes the TS gate, `readHerdrEnvironment(
#      process.env)`, and the child environment, `buildChildEnv(...)`;
#   3. the REAL AILANG `register_with_config` (register_ail.ail), the one caller of
#      `herdr_env_ready`, runs in exactly that child environment and reports its tools.
#
# Exit 1: the TS gate and the runtime's gate disagree (one open, one shut). Exit 0: they agree.
# Exit 2: a tool failed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../tree" && pwd)"
[[ $# -eq 3 ]] || { echo "usage: chain_check.sh <HERDR_ENV> <HERDR_BIN_PATH> <HERDR_PANE_ID> (or UNSET)"; exit 2; }
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

pane=(env -i "PATH=$PATH" "HOME=$HOME" HERDR_ORCHESTRATOR=off)
names=(HERDR_ENV HERDR_BIN_PATH HERDR_PANE_ID)
args=("$@")
for i in 0 1 2; do
  [[ "${args[$i]}" != "UNSET" ]] && pane+=("${names[$i]}=${args[$i]}")
done

host=$("${pane[@]}" bun "$here/chain_ts.ts" "$tree" "$work") || { echo "bun failed"; exit 2; }
ts=$(printf '%s' "$host" | python3 -I -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["ts"]))')
herdr_child=$(printf '%s' "$host" | python3 -I -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["child"]))')
mapfile -d '' child < <(printf '%s' "$host" | python3 -I -c '
import json, sys
for k, v in json.load(sys.stdin)["env"].items():
    sys.stdout.write(k + "=" + v + "\0")')

reg=$(cd "$here" && env -i "${child[@]}" ailang run --relax-modules --caps Clock,Env,FS,IO,Process \
      --entry main register_ail.ail 2>/dev/null) || { echo "ailang failed"; exit 2; }
tools=$(printf '%s\n' "$reg" | sed -n 's/^tools=//p')
rbin=$(printf '%s\n' "$reg" | sed -n 's/^bin=//p')
printf '%s\n' "$reg" | grep -q '^tools=' || { echo "ailang printed: $reg"; exit 2; }

printf 'pane env: HERDR_ENV=%q HERDR_BIN_PATH=%q HERDR_PANE_ID=%q\n' "$1" "$2" "$3"
echo "host   readHerdrEnvironment(process.env) -> $ts"
echo "host   buildChildEnv forwards HERDR_*    -> $herdr_child"
echo "child  register_with_config tools        -> [${tools}]  (cfg.bin = '${rbin}')"
ts_open=false; [[ "$ts" != "null" ]] && ts_open=true
ail_open=false; [[ -n "$tools" ]] && ail_open=true
if [[ "$ts_open" != "$ail_open" ]]; then
  echo "GATES DISAGREE END TO END: TS open=$ts_open, runtime open=$ail_open"; exit 1
fi
echo "gates agree end to end (open=$ts_open)"; exit 0
