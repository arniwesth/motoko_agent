#!/usr/bin/env bash
# The differential of run_diff.sh over RUNNABLE sequences (runnable.py's run grammar): every
# runnable sequence of length 4 (5,213) and a seeded sample of 3,000 of lengths 5 and 6.
#   run_diff_runnable.sh <scratch dir>
# Exit 0 iff the model matches both real writers on every sequence. Also reports P3.1 and the
# twin's refusals on the real code, restricted to runnable sequences.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; repo="$(cd "$out/../tree" && pwd)"
scratch="${1:?scratch dir}"; mkdir -p "$scratch"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"
python3 - "$here" > "$scratch/keys.json" <<'PY'
import json, random, sys, itertools
sys.path.insert(0, sys.argv[1]); from runnable import runnable
four = [list(s) for s in itertools.product(range(13), repeat=4) if runnable(s)]
rng = random.Random(43); sample = []
while len(sample) < 3000:
    n = rng.choice([5, 6]); s = [rng.randrange(13) for _ in range(n)]
    if runnable(s) and s not in sample: sample.append(s)
print(json.dumps(four + sample))
PY
python3 -c "import json,sys; [print(','.join(map(str,s))) for s in json.load(open(sys.argv[1]))]" "$scratch/keys.json" > "$scratch/keys.txt"
echo "keys: $(wc -l < "$scratch/keys.txt")"
cd "$out"
ailang run --relax-modules --caps IO --entry many --args-json - diff/gen.ail < "$scratch/keys.json" > "$scratch/gen.raw" 2> "$scratch/gen.err"
grep -E '^[WT]	' "$scratch/gen.raw" > "$scratch/gen.out"
grep -E '^T	' "$scratch/gen.out" | cut -f2,3 | sort > "$scratch/twin.real"
bun "$here/host.ts" "$repo" "$scratch/gen.out" "$scratch/hostroot" > "$scratch/host.out"
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$scratch/host.out\"" diff/foldhost.ail > "$scratch/fold.raw" 2> "$scratch/fold.err"
grep -E '^F	' "$scratch/fold.raw" | cut -f2,3 | sort > "$scratch/host.real"
cat "$out/T3Model.lean" "$here/enumerate_list.lean.tail" > "$scratch/Enumerate.lean"
( cd "$scratch" && lean Enumerate.lean ) > "$scratch/lean.raw"
grep -E '^M	' "$scratch/lean.raw" > "$scratch/lean.out"
cut -f2,3 "$scratch/lean.out" | sort > "$scratch/twin.model"; cut -f2,4 "$scratch/lean.out" | sort > "$scratch/host.model"
fail=0
for side in twin host; do
  if diff "$scratch/$side.model" "$scratch/$side.real" > "$scratch/$side.diff"; then
    echo "$side: model = real on $(wc -l < "$scratch/$side.real") sequences, 0 mismatches"
  else echo "$side: MISMATCH, $(grep -c '^<' "$scratch/$side.diff") differ"; head "$scratch/$side.diff"; fail=1; fi
done
join -t $'\t' "$scratch/host.real" "$scratch/twin.real" > "$scratch/joined.tsv"
awk -F'\t' '$2 != $3 { bad++ } END { printf "P3.1 (real host vs real twin, runnable): %d of %d differ\n", bad + 0, NR }' "$scratch/joined.tsv"
awk -F'\t' '$2 ~ /^R;/ { n[$2]++ } END { for (k in n) printf "  real twin refuses with %s: %d runnable sequences\n", k, n[k] }' "$scratch/twin.real"
exit $fail
