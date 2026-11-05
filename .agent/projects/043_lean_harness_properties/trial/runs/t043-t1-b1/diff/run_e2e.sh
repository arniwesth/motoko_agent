#!/usr/bin/env bash
# diff/run_e2e.sh — step (2) for section 4 of ../HerdrGateModel.lean (X-1): the model's
# `readHerdrEnvironment`, `forwarded` and `registerGate` against the REAL readHerdrEnvironment,
# buildChildEnv and register_with_config, over the 512 TUI environments of enumerate_e2e.ts.
# Every ambient HERDR_* is removed before each case. Exit 0 iff 0 mismatches.
#
#   run_e2e.sh [scratch dir]      needs lean 4.28.0, bun and ailang v0.54.14 on PATH (~1 min)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
repo="$(cd "${REPO:-$out/../tree}" && pwd)"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch/wd"
for t in lean bun ailang; do command -v "$t" >/dev/null || { echo "NOT RUN -- no $t"; exit 2; }; done

bun "$here/enumerate_e2e.ts" "$repo" "$scratch/wd" > "$scratch/e2e.ts.out"
cat "$out/HerdrGateModel.lean" "$here/enumerate_e2e.lean.tail" > "$scratch/E2E.lean"
lean "$scratch/E2E.lean" | grep -E '^[0-9]+,[0-9]+,[0-9]+\|' > "$scratch/e2e.lean.out"
echo "real: $(wc -l < "$scratch/e2e.ts.out") environments; model: $(wc -l < "$scratch/e2e.lean.out")"
if ! diff "$scratch/e2e.ts.out" "$scratch/e2e.lean.out" > "$scratch/e2e.diff"; then
  echo "e2e differential: MISMATCH ($(grep -c '^<' "$scratch/e2e.diff") lines)"; head -20 "$scratch/e2e.diff"; exit 1
fi
echo "e2e differential: 0 mismatches"
awk -F'|' '{ ts = ($2 != "null"); g = ($4 == "true"); if (ts != g) { n++; if (n <= 12) print "  X-1 disagrees: " $0 } }
  END { printf "X-1 on the real path: %d of %d environments disagree\n", n + 0, NR }' "$scratch/e2e.ts.out"
