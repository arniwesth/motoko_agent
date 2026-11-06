#!/usr/bin/env bash
# Negative controls for the differential test: each mutant changes ONE behaviour of the
# model (TruncateModel.lean); run_mutants.sh requires each to mismatch the real code.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../../TruncateModel.lean"
out="${1:?scratch dir}"
mkdir -p "$out"
# M1: compare BYTE length instead of rune count (the fix for P6.1, applied to the model)
sed 's/  let n : Int := runeCount s          -- let n = Str.length(s);/  let n : Int := s.length/' "$src" > "$out/M1.lean"
# M2: lenient decoder: a lead byte announces its length even if the tail is bad
sed 's/  if decodeOk b0 rest then seqLen b0 else 1/  if seqLen b0 = 0 then 1 else seqLen b0/' "$src" > "$out/M2.lean"
# M3: Str.length counts code units of a 2-byte sequence as 2 (i.e. 2-byte seqs count twice)
sed 's/  | f + 1, b :: rest => 1 + runeCountAux f ((b :: rest).drop (width b rest))/  | f + 1, b :: rest => (if width b rest = 2 then 2 else 1) + runeCountAux f ((b :: rest).drop (width b rest))/' "$src" > "$out/M3.lean"
# M4: slice end is exclusive-minus-one (off by one: takes hi-1 bytes)
sed 's/    some ((b.drop lo.toNat).take (hi - lo).toNat)/    some ((b.drop lo.toNat).take (hi - lo - 1).toNat)/' "$src" > "$out/M4.lean"
# M5: the caller's guard is >= instead of >
sed 's/  if outBytes > maxStdoutBytes then/  if outBytes >= maxStdoutBytes then/' "$src" > "$out/M5.lean"
for m in M1 M2 M3 M4 M5; do
  if cmp -s "$src" "$out/$m.lean"; then echo "mutant $m did not apply" >&2; exit 3; fi
done
