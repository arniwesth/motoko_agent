#!/usr/bin/env bash
# direct.sh <cases file> — run the REAL, private `truncate_utf8_by_bytes` on every case.
#
# The function is not exported, and AILANG refuses to import or --entry a private
# function. So this builds, in a temp dir under out/ (where ailang.toml resolves the
# packages), a file that is packages/motoko-ext-compose/store.ail VERBATIM with:
#   (1) extra import lines inserted after the file's last `import` line, and
#   (2) direct_driver.ail.part appended.
# It then checks that deleting exactly those additions gives back store.ail byte for byte,
# so the function under test is the tree's text, not a copy that could drift.
# Prints `<index>|<base64 of result bytes>|<Str.length(input)>|<byte length(input)>` per case.
# Run from the tree root.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(pwd)"
src="$tree/packages/motoko-ext-compose/store.ail"
[[ -f "$src" ]] || { echo "direct.sh: run from the tree root ($src missing)" >&2; exit 2; }
cases="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
gen="$(mktemp -d "$here/../.gen.XXXXXX")"
trap 'rm -rf "$gen"' EXIT
extra=$'import std/io (println)\nimport std/fs (readFile)\nimport std/bytes as T6B\nimport std/string as T6S\nimport std/option (Option, Some, None)'
last_import="$(grep -n '^import ' "$src" | tail -1 | cut -d: -f1)"
{
  head -n "$last_import" "$src"
  printf '%s\n' "$extra"
  tail -n +"$((last_import + 1))" "$src"
  cat "$here/direct_driver.ail.part"
} > "$gen/store_direct.ail"
# Check: removing the inserted lines and the appended driver gives back store.ail exactly.
n_extra="$(printf '%s\n' "$extra" | wc -l)"
n_src="$(wc -l < "$src")"
{ head -n "$last_import" "$gen/store_direct.ail"; tail -n +"$((last_import + n_extra + 1))" "$gen/store_direct.ail" | head -n "$((n_src - last_import))"; } > "$gen/roundtrip.ail"
cmp -s "$gen/roundtrip.ail" "$src" || { echo "direct.sh: generated file does not contain store.ail verbatim" >&2; exit 2; }
# Negative controls only: T6_MUTANT=<name> rewrites exactly one line of the generated copy
# (never the tree). Unset, the function under test is the tree's text.
case "${T6_MUTANT:-}" in
  "") ;;
  fix_len)    from='  let n = Str.length(s);';                to='  let n = length(b);' ;;
  cut_from_1) from='    match slice(b, 0, max_bytes) {';      to='    match slice(b, 1, max_bytes) {' ;;
  over_by_1)  from='    match slice(b, 0, max_bytes) {';      to='    match slice(b, 0, max_bytes + 1) {' ;;
  *) echo "direct.sh: unknown T6_MUTANT=$T6_MUTANT" >&2; exit 2 ;;
esac
if [[ -n "${T6_MUTANT:-}" ]]; then
  [[ "$(grep -cxF -- "$from" "$gen/store_direct.ail")" == 1 ]] || { echo "direct.sh: mutant $T6_MUTANT: anchor not found once" >&2; exit 2; }
  awk -v f="$from" -v t="$to" '$0 == f { print t; next } { print }' "$gen/store_direct.ail" > "$gen/m.ail" && mv "$gen/m.ail" "$gen/store_direct.ail"
  echo "direct.sh: MUTANT $T6_MUTANT applied to the generated copy" >&2
fi
ailang run --relax-modules --caps IO,FS --entry t6_main --args-json "\"$cases\"" "$gen/store_direct.ail" 2> "$gen/err" || { cat "$gen/err" >&2; exit 2; }
