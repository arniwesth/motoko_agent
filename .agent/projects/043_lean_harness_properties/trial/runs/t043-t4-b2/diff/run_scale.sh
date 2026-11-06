#!/usr/bin/env bash
# run_scale.sh <tree root> [scratch] — step (2) on long inputs. The REAL chain_digest_over and
# chain_digests_over (scale_chain.ail) against the model (../lean/Scale.lean.tail) on n copies
# of `user "hi"` from the empty base, n = 1000, 4000, 16000: the final digest, and the digest
# list's length. Also records wall time per real run (start-up dominated; see SUMMARY.md).
# Exit 0: all six lines agree. 1: a mismatch. 2: a toolchain is missing.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lean_dir="$(cd "$here/../lean" && pwd)"
tree="$(cd "${1:?usage: run_scale.sh <tree root> [scratch]}" && pwd)"
scratch="${2:-$here/../runs/scale}"; mkdir -p "$scratch"
command -v lean >/dev/null || { echo "NOT RUN -- no lean"; exit 2; }
command -v ailang >/dev/null || { echo "NOT RUN -- no ailang"; exit 2; }
: > "$scratch/scale_ail.out"
for n in 1000 4000 16000; do
  for f in over digests; do
    s=$(date +%s%N)
    "$here/ail_run.sh" "$tree" "$here/scale_chain.ail" "${f}_$n" 2>/dev/null | grep -E '^(over|digests) ' >> "$scratch/scale_ail.out"
    echo "real ${f}_$n: $(( ($(date +%s%N) - s) / 1000000 )) ms"
  done
done
sed -n '1,/^#eval show IO Unit from do/p' "$lean_dir/Enumerate.lean.tail" | sed '$d' > "$scratch/enum_noeval.tail"
cat "$lean_dir/ChainModel.lean" "$lean_dir/FrameModel.lean" "$lean_dir/Sha256.lean" "$scratch/enum_noeval.tail" "$lean_dir/Scale.lean.tail" > "$scratch/Scale.lean"
lean "$scratch/Scale.lean" 2>&1 | grep -E '^(over|digests) ' > "$scratch/scale_lean.out"
cat "$scratch/scale_ail.out"
if diff -u "$scratch/scale_ail.out" "$scratch/scale_lean.out"; then
  echo "scale: $(wc -l < "$scratch/scale_ail.out") lines, 0 mismatches"
else
  echo "scale: MISMATCH"; exit 1
fi
