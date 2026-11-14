#!/usr/bin/env bash
# fix_diff.sh — differential test of the step-8 fixes: the Lean fix models against the same
# fixes applied to a SCRATCH COPY of packages/motoko-ext-compose (the tree is not modified).
#
#   fixA:  `let n = Str.length(s)` -> `let n = length(b)`              vs T6Model.lean truncateFix
#   fixAB: fixA plus `rune_cut` (back off from a continuation byte)    vs T6FixUtf8.lean truncateFix2
#
# Exit 0 if both pairs match on every case.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="${T6_TREE:-/home/motoko/trial-043/s/t043-t6-b1/tree}"
w="$(mktemp -d)"
for v in fixA fixAB; do
  mkdir -p "$w/$v/packages/motoko-ext-compose"
  cp "$tree/packages/motoko-ext-compose/store.ail" "$w/$v/packages/motoko-ext-compose/store.ail"
  sed -i 's/  let n = Str.length(s);/  let n = length(b);/' "$w/$v/packages/motoko-ext-compose/store.ail"
done
python3 - "$w/fixAB/packages/motoko-ext-compose/store.ail" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("import std/bytes (fromString, length, slice, toString)",
              "import std/bytes (fromString, length, slice, toString, byteAt)", 1)
s = s.replace("func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {",
"""func rune_cut(b: bytes, k: int) -> int {
  if k <= 0 then 0
  else match byteAt(b, k) {
    Some(c) => if c >= 128 && c < 192 then rune_cut(b, k - 1) else k,
    None => k
  }
}

func truncate_utf8_by_bytes(s: string, max_bytes: int) -> string {""", 1)
s = s.replace("match slice(b, 0, max_bytes) {", "match slice(b, 0, rune_cut(b, max_bytes)) {", 1)
open(p, "w").write(s)
PY
for v in fixA fixAB; do echo "== $v"; diff "$tree/packages/motoko-ext-compose/store.ail" "$w/$v/packages/motoko-ext-compose/store.ail"; done
# fixA model: T6Model.lean as is, function truncateFix.
# fixAB model: T6Model.lean's definitions (for runeCount) + T6FixUtf8.lean's fix definitions.
awk '/^\/-! ## Lemmas -\//{exit} {print}' "$here/../T6Model.lean" > "$w/fixAB.lean"
echo "end T6" >> "$w/fixAB.lean"
{ echo "namespace T6"
  awk '/^def runeCutN/{p=1} /^\/-! ## Lemmas about UTF-8 decoding -\//{p=0} p{print}' "$here/../T6FixUtf8.lean"
  echo "end T6"; } >> "$w/fixAB.lean"
fail=0
echo "== fixA vs T6.truncateFix"
T6_TREE="$w/fixA" T6_LEAN_FN=T6.truncateFix "$here/run_diff.sh" "$w/runA" | grep -E '^(differential|real function|ail|lean)' || fail=1
echo "== fixAB vs T6.truncateFix2"
T6_TREE="$w/fixAB" T6_MODEL="$w/fixAB.lean" T6_LEAN_FN=T6.truncateFix2 "$here/run_diff.sh" "$w/runAB" | grep -E '^(differential|real function|ail|lean)' || fail=1
for r in runA runAB; do grep -q '' "$w/$r/diff.txt" 2>/dev/null && [[ -s "$w/$r/diff.txt" ]] && fail=1; done
[[ -s "$w/runA/ail.out" && -s "$w/runAB/ail.out" ]] || fail=1
echo "fix_diff: $([[ $fail -eq 0 ]] && echo 'both fixes match their models' || echo FAILED)"
exit $fail
