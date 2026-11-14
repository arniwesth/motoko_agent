#!/usr/bin/env bash
# check_fix.sh — Kiro's step 8 on the real code: build a throw-away copy of the tree in which
# ONLY src/core/journal.ail differs, by the one-line fix the Lean model proves (`pathUpFix`):
#
#   else if contains_string(seen, id) then []   ->   else if contains_string(seen, id) then acc
#
# (every other file is a symlink to the real tree, which is not modified), and run
# repro_cycle.sh there. Expect exit 0 from it. Also prints the fixed body's sha256: it equals
# the pin src/eval/journal/reader.ail:1225 records for journal.ail's `path_up`.
# Run from the tree root. Exit 0 when the fix closes the cycle defect, 1 otherwise.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; T="$(pwd)"
[[ -f "$T/src/core/journal.ail" ]] || { echo "run from the tree root"; exit 2; }
P="$(mktemp -d)"; trap 'rm -rf "$P"' EXIT
mkdir -p "$P/src/core"
for f in "$T"/* "$T"/.[!.]*; do [[ -e "$f" ]] || continue; b=$(basename "$f"); [[ $b == src ]] || ln -s "$f" "$P/$b"; done
for f in "$T"/src/*; do b=$(basename "$f"); [[ $b == core ]] || ln -s "$f" "$P/src/$b"; done
for f in "$T"/src/core/*; do b=$(basename "$f"); [[ $b == journal.ail ]] || ln -s "$f" "$P/src/core/$b"; done
sed 's/^  else if contains_string(seen, id) then \[\]$/  else if contains_string(seen, id) then acc/' \
  "$T/src/core/journal.ail" > "$P/src/core/journal.ail"
echo "patch:"; diff "$T/src/core/journal.ail" "$P/src/core/journal.ail" | sed 's/^/  /'
s=$(grep -n '^pure func path_up(' "$P/src/core/journal.ail" | cut -d: -f1)
e=$(awk -v s="$s" 'NR > s && /^}/ { print NR; exit }' "$P/src/core/journal.ail")
echo "fixed path_up sha256: $(sed -n "${s},${e}p" "$P/src/core/journal.ail" | sha256sum | cut -c1-64)"
echo "reader.ail pin:       $(grep -o 'sha256:[0-9a-f]* symbol=path_up' "$T/src/eval/journal/reader.ail" | cut -d: -f2 | cut -d' ' -f1)"
cd "$P" && bash "$here/repro_cycle.sh"; rc=$?
echo "repro_cycle.sh on the fixed copy: exit $rc"
exit $(( rc == 0 ? 0 : 1 ))
