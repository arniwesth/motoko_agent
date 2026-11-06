#!/usr/bin/env bash
# repro/run.sh <program.ail> [caps] — regenerate the export-only copies, run one repro program
# from out/, and turn its verdict line into the exit status: 1 DEFECT PRESENT, 0 DEFECT ABSENT,
# 2 neither (it did not compile or run). Usable from any directory, e.g. the tree root:
#   bash ../out/repro/run.sh repro/cycle.ail
set -uo pipefail
out="$(cd "$(dirname "$0")/.." && pwd)"
cd "$out" || exit 2
[[ -n "${NO_GEN:-}" ]] || ./gen_exports.sh || exit 2
log="$(timeout 110 ailang run --relax-modules --caps "${2:-IO}" --entry main "$1" 2>&1)"
echo "$log" | grep -v '^\s*$' | tail -8
if grep -q "DEFECT PRESENT" <<< "$log"; then exit 1; fi
if grep -q "DEFECT ABSENT" <<< "$log"; then exit 0; fi
exit 2
