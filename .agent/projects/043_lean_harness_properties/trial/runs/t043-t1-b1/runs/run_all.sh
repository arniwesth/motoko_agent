#!/usr/bin/env bash
# runs/run_all.sh — the recorded final run: kernel check + axiom report, step (2) differential,
# its negative control, and the end-to-end differential. Logs land next to this script.
#   PATH must carry lean 4.28.0, bun and ailang v0.54.14.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"
s="${1:-$(mktemp -d)}"; mkdir -p "$s"
{ lean --version; lean "$out/HerdrGateModel.lean" 2>&1 | grep -E "axioms|error"; echo "lean exit ${PIPESTATUS[0]}"; } > "$out/axioms.txt"
cat "$out/axioms.txt"
( "$out/diff/run_diff.sh" "$s/diff"; echo "exit $?" ) 2>&1 | tee "$here/run_diff.log"
( "$out/diff/run_diff.sh" --control "$s/control"; echo "exit $?" ) 2>&1 | tee "$here/run_diff_control.log"
( "$out/diff/run_e2e.sh" "$s/e2e"; echo "exit $?" ) 2>&1 | tee "$here/run_e2e.log"
cp "$s/diff/p11.txt" "$here/p11_real_vs_real.txt"
sha256sum "$s/diff/ts.out" "$s/diff/ail.out" "$s/diff/lean.model.out" "$s/e2e/e2e.ts.out" "$s/e2e/e2e.lean.out" \
  | sed "s#$s/##" > "$here/outputs.sha256"
gzip -c "$s/diff/lean.model.out" > "$here/lean.model.out.gz"
gzip -c "$s/diff/ts.out" > "$here/ts.out.gz"
gzip -c "$s/diff/ail.out" > "$here/ail.out.gz"
cp "$s/e2e/e2e.ts.out" "$here/e2e.real.out"
