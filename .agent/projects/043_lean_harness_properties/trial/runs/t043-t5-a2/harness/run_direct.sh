#!/usr/bin/env bash
# run_direct.sh <name> <gen.ts args…> — generate cases, run the REAL functions over them
# (path_direct.ail, under a timeout that is the P5.1 check), and judge them with check.ts.
# Run from out/. Results land in runs/<name>.{cases,out,err,check}.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; cd "$out"
name="$1"; shift
mkdir -p runs
"$here/expose.sh" "$out/../tree" "$out" || exit 3
bun "$here/gen.ts" "$@" > "runs/$name.cases"
s=$(date +%s%N)
timeout "${TMO:-1800}" ailang run --relax-modules --caps IO --entry main harness/path_direct.ail \
  < "runs/$name.cases" > "runs/$name.out" 2> "runs/$name.err"
rc=$?
echo "$name: $(wc -l < "runs/$name.cases") cases, ailang rc=$rc, $(( ($(date +%s%N)-s)/1000000 )) ms" | tee "runs/$name.check"
bun "$here/check.ts" "runs/$name.cases" "runs/$name.out" | tee -a "runs/$name.check"
exit "${PIPESTATUS[0]}"
