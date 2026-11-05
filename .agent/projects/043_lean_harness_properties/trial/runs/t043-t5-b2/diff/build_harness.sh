#!/usr/bin/env bash
# build_harness.sh <tree root> <case file> <out .ail>
# Assembles the AILANG half: harness_head.ail + the REAL bodies of contains_string,
# find_entry and path_up, copied verbatim from <tree>/src/core/journal.ail + the driver.
# Prints "<symbol> L<start>-<end> sha256:<hash of the copied text>" for each body on stderr.
# Negative control only: MUTANT='<symbol>:<sed expression>' applies the sed expression to that
# one copied body (never to src/), and the hash printed is then the MUTATED text's.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$1"; cases="$2"; out="$3"
src="$tree/src/core/journal.ail"
{
  cat "$here/harness_head.ail"
  for sym in contains_string find_entry path_up; do
    s=$(grep -n "^pure func $sym(" "$src" | head -1 | cut -d: -f1)
    [[ -n "$s" ]] || { echo "build_harness: $sym not found in $src" >&2; exit 3; }
    e=$(awk -v s="$s" 'NR > s && /^}/ { print NR; exit }' "$src")
    body="$(sed -n "${s},${e}p" "$src")"
    if [[ -n "${MUTANT:-}" && "${MUTANT%%:*}" == "$sym" ]]; then
      body="$(printf '%s\n' "$body" | sed "${MUTANT#*:}")"; echo "MUTANT applied to $sym: ${MUTANT#*:}" >&2
    fi
    echo "$sym L$s-$e sha256:$(printf '%s\n' "$body" | sha256sum | cut -c1-64)" >&2
    printf -- '-- VERBATIM from src/core/journal.ail L%s-%s\n%s\n\n' "$s" "$e" "$body"
  done
  sed "s#CASES_PATH#$cases#" "$here/harness_driver.ail"
} > "$out"
