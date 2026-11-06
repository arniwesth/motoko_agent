#!/usr/bin/env bash
# P3.2: the twin's journal of single-run traces, folded, against the executable statement of
# rule 3 (+ rule 4) in p32.ail. Run from the tree root.
#   bash ../out/harness/run_p32.sh <maxlen> <starts as JSON, e.g. [0,1,3]>
# T3_ACCEPT_ONLY=true judges only the first clause (the fold accepts). T3_DIR as in run_p31.sh.
# Exit 1 when any run FAILs.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
d="${T3_DIR:-scratchpad/t3p}"   # inside the package, so `scratchpad/...` imports resolve
mkdir -p "$d"
for f in "$here"/*.ail; do sed "s#scratchpad/t3/#$d/#" "$f" > "$d/$(basename "$f")"; done
out="$(ailang run --relax-modules --caps IO --entry main --args-json "{\"maxlen\":${1:-1},\"starts\":${2:-[0,1,2,3]},\"accept_only\":${T3_ACCEPT_ONLY:-false}}" "$d/p32.ail" 2>/dev/null)"
printf '%s\n' "$out" | grep -v '	FAIL	' || true
printf '%s\n' "$out" | grep '	FAIL	' | cut -c1-240 | head -"${T3_SHOW:-5}" || true
grep -q '^p3.2: .* 0 FAIL$' <<< "$out" && exit 0
exit 1
