#!/usr/bin/env bash
# Reproduces one counterexample on the REAL, unmodified code: the TS twin through bun, the
# AILANG twin through ailang, on the same (exit code, stderr) from cases/<id>.json.
#
#   bash ../out/repro/check.sh <report id>      (from the tree root, or REPO=<tree root>)
#
# P2.1 cases compare means_agent_gone; P2.2 cases compare failure_code.
# Exit 1: the twins differ (the defect is present). Exit 0: they agree. Exit 2: could not run.
set -uo pipefail
id="${1:?usage: check.sh <report id>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="${REPO:-$(cd "$here/../../tree" && pwd)}"
case_file="$here/cases/$id.json"
[[ -f "$case_file" ]] || { echo "no case $id"; exit 2; }
prop="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["property"])' "$case_file")"
mod="$(echo "$id" | tr 'A-Z-' 'a-z_')"

ts="$(bun "$here/ts_eval.ts" "$repo" "$case_file")" || { echo "bun failed"; exit 2; }
[[ -f "$here/ail/ailang.lock" ]] || ( cd "$here/ail" && ailang lock >/dev/null 2>&1 )
ail="$(cd "$repo" && ailang run --relax-modules --caps IO --entry main "$here/ail/$mod.ail" 2>/dev/null | tail -1)" \
  || { echo "ailang failed"; exit 2; }
[[ "$ail" == *"|"* ]] || { echo "ailang printed no result: $ail"; exit 2; }

echo "$id ($prop) input: $(python3 -I -c 'import json,sys; c=json.load(open(sys.argv[1])); print("exit", c["exit"], "stderr", json.dumps(c["stderr"]))' "$case_file")"
echo "  TS     herdrFailureCode|herdrMeansAgentGone: $ts"
echo "  AILANG failure_code|means_agent_gone:        $ail"
if [[ "$prop" == "P2.1" ]]; then a="${ts##*|}"; b="${ail##*|}"; else a="${ts%|*}"; b="${ail%|*}"; fi
if [[ "$a" != "$b" ]]; then echo "  DIFFER on $prop: defect present"; exit 1; fi
echo "  agree on $prop"; exit 0
