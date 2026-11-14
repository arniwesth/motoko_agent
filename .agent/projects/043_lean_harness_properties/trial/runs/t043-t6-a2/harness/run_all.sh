#!/usr/bin/env bash
# run_all.sh <scratch dir> <results dir> [seed units_len bytes_len random_count]...
#
# The full sweep, from the tree root. For each (seed, sizes) tuple:
#   gen_cases.ts -> direct.sh (the private function, called directly) and via_store.ail (the
#   exported caller) on the same cases -> check.ts (properties, route and twin comparisons).
# Then the negative controls: the same cases through direct.sh with each T6_MUTANT, checked
# again, so the counts show the checker sees each one-line change.
# Writes <results dir>/<seed>.check.txt, <seed>.mutant-<name>.check.txt and sha256s of the
# inputs and outputs (the case files stay in the scratch dir; they are regenerated exactly
# from the seed). Exit 1 if any registered primary property (P6.1, P6.2) failed on the
# unmutated code in any sweep.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
scratch="$1"; results="$2"; shift 2
mkdir -p "$scratch" "$results"
[[ $# -eq 0 ]] && set -- 1 5 3 5000
status=0
while [[ $# -ge 4 ]]; do
  seed="$1"; ul="$2"; bl="$3"; rc="$4"; shift 4
  p="$scratch/s$seed"
  bun "$here/gen_cases.ts" "$p" "$seed" "$ul" "$bl" "$rc" 2> "$results/$seed.gen.txt"
  t0=$(date +%s)
  "$here/direct.sh" "$p.cases" > "$p.direct" || { echo "direct.sh failed" >&2; exit 2; }
  t1=$(date +%s)
  ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$p.cases\"" "$here/via_store.ail" > "$p.store" 2> "$p.store.err" || { cat "$p.store.err" >&2; exit 2; }
  t2=$(date +%s)
  echo "direct.sh $((t1 - t0))s, via_store.ail $((t2 - t1))s" >> "$results/$seed.gen.txt"
  sha256sum "$p.cases" "$p.tags" "$p.direct" "$p.store" | sed "s|$scratch/||" > "$results/$seed.sha256"
  bun "$here/check.ts" "$p" . > "$results/$seed.check.txt"; rc_check=$?
  [[ $rc_check -ne 0 ]] && status=1
  echo "== seed $seed (units<=$ul, bytes<=$bl, random $rc): check exit $rc_check"
  grep -E '^(cases|ok|FAIL)' "$results/$seed.check.txt"
  for m in fix_len cut_from_1 over_by_1; do
    if ! T6_MUTANT=$m "$here/direct.sh" "$p.cases" > "$p.direct" 2> "$p.mutant-$m.err"; then
      # One retry, logged: a mutant run once failed transiently on a loaded machine (see SUMMARY.md).
      echo "mutant $m: direct.sh failed, retrying once; stderr was:" >&2; cat "$p.mutant-$m.err" >&2
      echo "retry: mutant $m" >> "$results/$seed.gen.txt"
      T6_MUTANT=$m "$here/direct.sh" "$p.cases" > "$p.direct" 2> "$p.mutant-$m.err" || { cat "$p.mutant-$m.err" >&2; echo "mutant $m failed twice" >&2; exit 2; }
    fi
    bun "$here/check.ts" "$p" . > "$results/$seed.mutant-$m.check.txt"
    echo "-- mutant $m (direct route only; store route is the tree's code):"
    grep -E '^(ok +|FAIL )(P6\.[123]|P6\.2[ab]|X-route: clip|cut|n<0|P6\.1-(un)?explained)[: ]' "$results/$seed.mutant-$m.check.txt" | grep -v "via store" | sed 's/^/   /'
  done
  "$here/direct.sh" "$p.cases" > "$p.direct"   # leave the unmutated output in place
done
exit $status
