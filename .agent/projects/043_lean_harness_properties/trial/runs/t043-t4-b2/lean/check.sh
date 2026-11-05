#!/usr/bin/env bash
# check.sh — kernel-check ChainModel.lean alone, then ChainModel.lean + FrameModel.lean, and
# write the axiom report (every theorem's `#print axioms`) to ../axioms.txt. Needs `lean`
# 4.28.0 on PATH. Exit 0 only if both files check with no error and no theorem depends on
# sorryAx or Lean.ofReduceBool (native_decide).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../axioms.txt"
mkdir -p "$here/../runs"
combined="$here/../runs/ChainAndFrame.lean"
cat "$here/ChainModel.lean" "$here/FrameModel.lean" > "$combined"
{
  echo "# Axiom report. $(lean --version). $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# lean ChainModel.lean"
  lean "$here/ChainModel.lean" 2>&1; s1=$?
  echo "# exit status: $s1"
  echo "# lean ChainModel.lean + FrameModel.lean (FrameModel's theorems; ChainModel's repeat)"
  lean "$combined" 2>&1 | grep -v "^'T4\."; s2=${PIPESTATUS[0]}
  echo "# exit status: $s2"
} > "$out"
cat "$out"
if [[ $s1 -ne 0 || $s2 -ne 0 ]] || grep -qE "error|sorryAx|ofReduceBool" "$out"; then
  echo "check: FAIL"; exit 1
fi
echo "check: $(grep -c 'axioms' "$out") theorems, no error, no sorryAx, no Lean.ofReduceBool"
