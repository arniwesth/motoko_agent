#!/usr/bin/env bash
# run_diff.sh — the T2 differential test: the REAL herdrFailureCode / herdrMeansAgentGone
# (bun, ts_eval.ts) against the REAL failure_code / means_agent_gone (ailang, ail_eval.ail),
# on cases from gen.ts, compared by compare.ts.
#
#   bash ../out/harness/run_diff.sh <gen args...>      from the tree root, e.g.
#   bash ../out/harness/run_diff.sh structured
#   bash ../out/harness/run_diff.sh tokens 4
#   bash ../out/harness/run_diff.sh random 50000 7
#
# Env: SCRATCH (default: a fresh mktemp dir), COMPARE_FLAGS (e.g. "--explain --quiet"),
#      T2_TS_MODULE / T2_AIL_ENTRY (patched copies, fixcheck/ only).
# Exit: compare.ts's (1 on any P2.1 mismatch), 3 on a harness error.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="$(cd "$out/../tree" && pwd)"
scratch="${SCRATCH:-$(mktemp -d)}"
mkdir -p "$scratch"
# T2_TS_MODULE / T2_AIL_ENTRY: patched copies instead of the tree (fixcheck/ only).
entry="${T2_AIL_ENTRY:-$here/ail_eval.ail}"
# The lock pins the package by content hash: regenerate it next to the nearest ailang.toml.
proj="$(dirname "$entry")"; while [[ ! -f "$proj/ailang.toml" && "$proj" != "/" ]]; do proj="$(dirname "$proj")"; done
( cd "$proj" && ailang lock >/dev/null 2>&1 ) || { echo "ailang lock failed in $proj"; exit 3; }
bun "$here/gen.ts" "$@" > "$scratch/cases.tsv" || { echo "gen.ts failed"; exit 3; }
bun "$here/ts_eval.ts" < "$scratch/cases.tsv" > "$scratch/ts.out" || { echo "ts_eval.ts failed"; exit 3; }
( cd "$tree" && ailang run --relax-modules --caps IO --entry main "$entry" ) \
  < "$scratch/cases.tsv" > "$scratch/ail.out" 2> "$scratch/ail.err" || { echo "ailang failed:"; tail -5 "$scratch/ail.err"; exit 3; }
echo "gen: $* -> $(wc -l < "$scratch/cases.tsv") cases, sha256 $(sha256sum "$scratch/cases.tsv" | cut -c1-16) (scratch $scratch)"
set +e
bun "$here/compare.ts" "$scratch/cases.tsv" "$scratch/ts.out" "$scratch/ail.out" ${COMPARE_FLAGS:-}
rc=$?
exit $rc
