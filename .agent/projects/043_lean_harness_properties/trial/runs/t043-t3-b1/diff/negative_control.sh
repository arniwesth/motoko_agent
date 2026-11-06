#!/usr/bin/env bash
# Negative control for run_diff.sh (RESEARCH §4: "plant one mutant ... and require mismatches").
# The mutants are on the MODEL side, so the tree is not touched: the model's twin becomes
# `twinLinesFix` (sets replaced_since_seed on HistoryReplaced) and its host `hostLinesFix`
# (replaceLastHistoryMessage runs updatePending). Each is compared with the REAL outputs of a
# finished run_diff.sh scratch dir. The test is sensitive iff each mutant mismatches.
#   negative_control.sh <scratch dir of a finished run_diff.sh run>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; s="${1:?scratch}"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"
cat "$out/T3Model.lean" "$here/enumerate_mutant.lean.tail" > "$s/Mutant.lean"
lean "$s/Mutant.lean" | grep -E '^M	' > "$s/mutant.out"
cut -f2,3 "$s/mutant.out" | sort > "$s/twin.mutant"; cut -f2,4 "$s/mutant.out" | sort > "$s/host.mutant"
rc=0
for side in twin host; do
  n=$(diff "$s/$side.mutant" "$s/$side.real" | grep -c '^<' || true)
  echo "mutant $side vs real $side: $n of $(wc -l < "$s/$side.real") sequences mismatch"
  [[ "$n" -gt 0 ]] || rc=1
done
# The fixed model's own P3.1 (bounded, model only): which sequences still fold differently.
join -t $'\t' "$s/host.mutant" "$s/twin.mutant" | awk -F'\t' '$2 != $3 { n++; printf "  fixed model, P3.1 still differs: %s host=%s twin=%s\n", $1, $2, $3 }
  END { printf "fixed model: %d of %d sequences still differ\n", n + 0, NR }' | tail -40
exit $rc
