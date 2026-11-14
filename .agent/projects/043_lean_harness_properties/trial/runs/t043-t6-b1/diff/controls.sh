#!/usr/bin/env bash
# Negative controls for run_diff.sh: the differential test must see a one-token change on
# either side. Real side: a sed mutant applied to the CUT COPY of truncate_utf8_by_bytes (the
# tree is never modified). Model side: a mutated copy of T6Model.lean's definitions (theorems
# dropped, since a mutant model need not satisfy them). Each control must report MISMATCH.
# Exit 0 if every control is caught and the unmutated run matches; 1 otherwise.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
w="$(mktemp -d)"
fail=0
run() { # label, then run_diff.sh args; prints one line, sets $last
  local label="$1"; shift
  last="$("$here/run_diff.sh" "$@" 2>&1 | grep -E '^differential' || true)"
  printf '%-58s %s\n' "$label" "$last"
}
expect_mismatch() { run "$@"; [[ "$last" == *MISMATCH* ]] || fail=1; }

echo "== unmutated"
run "real function vs model" "$w/base"; [[ "$last" == *"0 mismatches"* ]] || fail=1

echo "== real-side mutants (cut copy only)"
expect_mismatch "Str.length(s) -> length(b)   (the P6.1 fix)" --mutant 's/Str.length(s)/length(b)/' "$w/r1"
expect_mismatch "n <= max_bytes -> n < max_bytes" --mutant 's/n <= max_bytes/n < max_bytes/' "$w/r2"
expect_mismatch "slice(b,0,max_bytes) -> slice(b,0,max_bytes-1)" --mutant 's/slice(b, 0, max_bytes)/slice(b, 0, max_bytes - 1)/' "$w/r3"
expect_mismatch 'None => "" -> None => s' --mutant 's/None => ""/None => s/' "$w/r4"

echo "== model-side mutants"
defs() { awk '/^\/-! ## Lemmas -\//{exit} {print}' "$here/../T6Model.lean"; }
defs | sed 's/if c = 0xED then 0x9F else/if c = 0xED then 0xBF else/' > "$w/m1.lean"; echo "end T6" >> "$w/m1.lean"
defs | sed 's/^def toString (b : Bytes) : Bytes := b .*/def toString (b : Bytes) : Bytes := b.map (fun x => if x < 0x80 then x else 0x3F)/' > "$w/m2.lean"; echo "end T6" >> "$w/m2.lean"
defs | sed 's/^  let n := strLength s$/  let n := b.length/' > "$w/m3.lean"; echo "end T6" >> "$w/m3.lean"
defs | sed 's/^  | k + 1, c :: t => 1 + runeCountF k (t.drop ((decode1 (c :: t)).2 - 1))/  | k + 1, c :: t => 1 + runeCountF k t/' > "$w/m4.lean"; echo "end T6" >> "$w/m4.lean"
for i in 1 2 3 4; do
  if cmp -s <(defs; echo "end T6") "$w/m$i.lean"; then echo "model mutant $i did not apply"; fail=1; fi
done
T6_MODEL="$w/m1.lean" expect_mismatch "model: 0xED accept range 80-9F -> 80-BF (surrogates)" "$w/m1"
T6_MODEL="$w/m2.lean" expect_mismatch "model: toString repairs non-ASCII bytes" "$w/m2"
T6_MODEL="$w/m3.lean" expect_mismatch "model: fits test on byte length" "$w/m3"
T6_MODEL="$w/m4.lean" expect_mismatch "model: rune count = byte count" "$w/m4"
echo "controls: $([[ $fail -eq 0 ]] && echo 'all caught' || echo 'FAILED')"
exit $fail
