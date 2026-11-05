#!/usr/bin/env bash
# One reproduction on the real, unmodified code.  repro.sh <entry> <property>
# Exit 1: defect present. 0: absent. 2: the repro could not run as designed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"
[[ -f ailang.lock ]] || ailang lock > /dev/null || exit 2
out="$(timeout 100 ailang run --caps IO,FS --entry "$1" repro.ail 2> /dev/null)" || { echo "ailang run failed"; exit 2; }
printf '%s\n' "$out" | python3 -I "$here/verdict.py" "$2"
