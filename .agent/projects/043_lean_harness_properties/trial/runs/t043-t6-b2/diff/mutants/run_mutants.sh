#!/usr/bin/env bash
# Runs each mutant model through enumerate.lean.tail and counts mismatches against the
# real code's output (ail.out from run_diff.sh). Exit 0 only if every mutant is caught.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
scratch="${1:?scratch dir holding ail.out}"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"
"$here/make_mutants.sh" "$scratch/mutants" || exit 3
fail=0
for m in M1 M2 M3 M4 M5; do
  ( cat "$scratch/mutants/$m.lean" "$here/../enumerate.lean.tail" > "$scratch/mutants/$m.enum.lean"
    lean "$scratch/mutants/$m.enum.lean" 2>&1 | grep -E '^[ER]\|' > "$scratch/mutants/$m.out" ) &
done
wait
for m in M1 M2 M3 M4 M5; do
  n=$(diff "$scratch/mutants/$m.out" "$scratch/ail.out" | grep -c '^<')
  echo "$m: $n of $(wc -l < "$scratch/ail.out") cases mismatch"
  [[ "$n" -gt 0 ]] || fail=1
done
exit $fail
