#!/usr/bin/env bash
# Differential test for ../T3Model.lean (target T3: the journal writer twin and the round trip).
#
# Four halves over every step sequence of length 0..3 of the child simulator (2,380 sequences):
#   gen.ail       REAL journal_lines_of_records + REAL fold_journal      -> T lines (+ W wire events)
#   host.ts       REAL SessionJournal over the same wire events          -> H lines (journals)
#   foldhost.ail  REAL fold_journal over the host's journals             -> F lines
#   Lean          the model's twin, host and fold (T3Model.lean + enumerate.lean.tail) -> M lines
# and compares: model twin vs real twin, model host vs real host (both through the fold).
# It also reports P3.1 on the REAL code (host verdict vs twin verdict) without failing on it.
#
#   run_diff.sh [scratch dir]     needs lean 4.28.0, bun and ailang v0.54.14 on PATH
# Run from anywhere; `out/` must hold the symlinks src, packages, ailang.lock (to the tree).
# Exit 0 iff the model matches both real writers on every sequence.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
repo="$(cd "$out/../tree" && pwd)"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"

cd "$out"
ailang run --relax-modules --caps IO --entry main diff/gen.ail > "$scratch/gen.raw" 2> "$scratch/gen.err"
grep -E '^[WT]	' "$scratch/gen.raw" > "$scratch/gen.out"
grep -E '^T	' "$scratch/gen.out" | cut -f2,3 | sort > "$scratch/twin.real"
echo "gen: $(wc -l < "$scratch/twin.real") sequences"

bun "$here/host.ts" "$repo" "$scratch/gen.out" "$scratch/hostroot" > "$scratch/host.out"
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$scratch/host.out\"" diff/foldhost.ail \
  > "$scratch/fold.raw" 2> "$scratch/fold.err"
grep -E '^F	' "$scratch/fold.raw" | cut -f2,3 | sort > "$scratch/host.real"
echo "host: $(wc -l < "$scratch/host.real") journals folded"

cat "$out/T3Model.lean" "$here/enumerate.lean.tail" > "$scratch/Enumerate.lean"
lean "$scratch/Enumerate.lean" > "$scratch/lean.raw"
grep -E '^M	' "$scratch/lean.raw" > "$scratch/lean.out"
cut -f2,3 "$scratch/lean.out" | sort > "$scratch/twin.model"
cut -f2,4 "$scratch/lean.out" | sort > "$scratch/host.model"

fail=0
for side in twin host; do
  if diff "$scratch/$side.model" "$scratch/$side.real" > "$scratch/$side.diff"; then
    echo "$side: model = real on $(wc -l < "$scratch/$side.real") sequences, 0 mismatches"
  else
    echo "$side: MISMATCH, $(grep -c '^<' "$scratch/$side.diff") sequences differ"; head -10 "$scratch/$side.diff"; fail=1
  fi
done

# P3.1 on the real code: the host's journal and the twin's journal fold alike.
join -t $'\t' "$scratch/host.real" "$scratch/twin.real" | awk -F'\t' '
  $2 != $3 { bad++; if (bad <= 15) print "  P3.1 differs: " $1 "  host=" $2 "  twin=" $3 }
  END { printf "P3.1 (real host vs real twin): %d of %d sequences fold differently\n", bad + 0, NR }'
# P3.2-acceptance on the real twin: sequences the twin journal refuses.
awk -F'\t' '$2 ~ /^R;/ { n[$2]++ } END { for (k in n) printf "  twin refuses with %s: %d sequences\n", k, n[k] }' "$scratch/twin.real"
exit $fail
