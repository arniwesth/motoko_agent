#!/usr/bin/env bash
# Differential test for ../TruncateModel.lean (T6: store.ail:20-30 and its caller :32-49).
#
# Same 30,375 cases on both sides (14-atom enumeration of 0..3 atoms x every cap -1..len+1,
# plus 3,000 LCG-random byte strings), two routes into the real code:
#
#   caller  the REAL, UNMODIFIED `store_stdout_and_elide` (caller/harness.ail) against the
#           model's `storeElide` (enumerate.lean.tail). Reaches `truncate_utf8_by_bytes`
#           on every case whose byte length exceeds the cap.
#   direct  `truncate_utf8_by_bytes` itself, in a scratch copy of the package whose only
#           change is `export` on store.ail:20 (direct/make_exposed.sh checks that), against
#           the model's `truncate` (enumerate_direct.lean.tail). Covers the cases that fit.
#
# Then: the kernel check and axiom report of the model alone (axioms.txt), refusing
# `sorryAx` and `Lean.ofReduceBool`; a bounded check of P6.1-P6.3 on the real outputs
# (check_props.py); and, with --mutants, the negative controls (mutants/run_mutants.sh).
#
#   run_diff.sh [--mutants] [scratch dir]
#
# Needs `lean` 4.28.0 (core only; looked up under ~/.elan if not on PATH), `ailang` v0.54.14
# and python3. Exit 0 only when every half ran and no case mismatched; 1 on a mismatch;
# 2 when a toolchain is missing or a half could not run.
set -euo pipefail

mutants=0
if [[ "${1:-}" == "--mutants" ]]; then mutants=1; shift; fi
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
scratch="${1:-$(mktemp -d)}"
mkdir -p "$scratch"
export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"
command -v lean >/dev/null || { echo "NOT RUN -- no lean"; exit 2; }
command -v ailang >/dev/null || { echo "NOT RUN -- no ailang"; exit 2; }
echo "lean: $(lean --version)"
echo "ailang: $(ailang --version | head -1)"

# 0. The model alone: kernel check and axiom report.
lean "$out/TruncateModel.lean" > "$scratch/model.raw" 2>&1 || { cat "$scratch/model.raw"; echo "model: Lean ERROR"; exit 1; }
grep -E "depends on axioms|does not depend on any axioms" "$scratch/model.raw" > "$scratch/axioms.txt"
if grep -vE "depends on axioms|does not depend on any axioms" "$scratch/model.raw" | grep -q .; then
  echo "model: unexpected Lean output:"; cat "$scratch/model.raw"; exit 1
fi
if grep -qE "sorryAx|ofReduceBool|ofReduceNat" "$scratch/axioms.txt"; then
  echo "model: a theorem uses sorry or native_decide"; grep -E "sorryAx|ofReduce" "$scratch/axioms.txt"; exit 1
fi
cp "$scratch/axioms.txt" "$out/axioms.txt"
echo "model: checks; $(wc -l < "$scratch/axioms.txt") theorems, axioms in axioms.txt"

status=0

# 1. Caller route: the real, unmodified store_stdout_and_elide.
( cd "$here/caller" && { [[ -f ailang.lock ]] || ailang lock > /dev/null; } \
  && ailang run --caps IO,FS --entry main harness.ail ) > "$scratch/caller.raw" 2> "$scratch/caller.err" \
  || { echo "caller: ailang run failed"; head "$scratch/caller.err"; exit 2; }
grep -E '^[ER]\|' "$scratch/caller.raw" > "$scratch/caller.out"
cat "$out/TruncateModel.lean" "$here/enumerate.lean.tail" > "$scratch/EnumCaller.lean"
lean "$scratch/EnumCaller.lean" 2>&1 | grep -E '^[ER]\|' > "$scratch/lean_caller.out"
if diff "$scratch/lean_caller.out" "$scratch/caller.out" > "$scratch/diff_caller.txt"; then
  echo "caller: $(wc -l < "$scratch/caller.out") cases, 0 mismatches (sha256 $(sha256sum "$scratch/caller.out" | cut -c1-16))"
else
  echo "caller: MISMATCH, $(grep -c '^<' "$scratch/diff_caller.txt") cases"; head -10 "$scratch/diff_caller.txt"; status=1
fi

# 2. Direct route: the function itself, in an exposed copy (one word changed, checked).
h="$("$here/direct/make_exposed.sh" "$scratch")" || { echo "direct: could not build the exposed copy"; exit 2; }
( cd "$h" && ailang run --caps IO --entry main harness.ail ) > "$scratch/direct.raw" 2> "$scratch/direct.err" \
  || { echo "direct: ailang run failed"; head "$scratch/direct.err"; exit 2; }
grep -E '^[ER]\|' "$scratch/direct.raw" > "$scratch/direct.out"
cat "$out/TruncateModel.lean" "$here/enumerate_direct.lean.tail" > "$scratch/EnumDirect.lean"
lean "$scratch/EnumDirect.lean" 2>&1 | grep -E '^[ER]\|' > "$scratch/lean_direct.out"
if diff "$scratch/lean_direct.out" "$scratch/direct.out" > "$scratch/diff_direct.txt"; then
  echo "direct: $(wc -l < "$scratch/direct.out") cases, 0 mismatches (sha256 $(sha256sum "$scratch/direct.out" | cut -c1-16))"
else
  echo "direct: MISMATCH, $(grep -c '^<' "$scratch/diff_direct.txt") cases"; head -10 "$scratch/diff_direct.txt"; status=1
fi

# 3. The properties, on the real outputs alone.
python3 -I "$here/check_props.py" "$scratch/direct.out" "$scratch/caller.out"

# 4. Negative controls.
if [[ "$mutants" -eq 1 ]]; then
  cp "$scratch/caller.out" "$scratch/ail.out"
  "$here/mutants/run_mutants.sh" "$scratch" || { echo "mutants: a mutant was NOT caught"; status=1; }
fi
echo "scratch: $scratch"
exit $status
