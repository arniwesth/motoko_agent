#!/usr/bin/env bash
# check_on_fixed_copy.sh [tree root, default: the current directory] — the repro scripts'
# other direction. Copies the tree's src/ into ../runs/fixed_tree, applies the one-token fix
# to journal.ail:293 (`{ last: chain_empty_base(), out: [] }` -> `{ last: base, out: [] }`),
# and requires p4_1.sh and p4_2.sh to exit 0 there (and 1 on the tree itself). The tree is
# not modified; the copy is removed on exit.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "${1:-.}" && pwd)"
fixed="$here/../runs/fixed_tree"
rm -rf "$fixed"; mkdir -p "$fixed"
trap 'rm -rf "$fixed"' EXIT
cp -r "$tree/src" "$fixed/src"
for f in ailang.toml ailang.lock packages; do ln -s "$tree/$f" "$fixed/$f"; done
sed -i '293s/{ last: chain_empty_base(), out: \[\] }/{ last: base, out: [] }/' "$fixed/src/core/journal.ail"
echo "--- the fix:"; diff "$tree/src/core/journal.ail" "$fixed/src/core/journal.ail"
status=0
for p in p4_1 p4_2; do
  bash "$here/$p.sh" "$tree" > /dev/null; on_tree=$?
  bash "$here/$p.sh" "$fixed" > /dev/null; on_fixed=$?
  echo "$p.sh: exit $on_tree on the tree, exit $on_fixed on the fixed copy"
  [[ $on_tree -eq 1 && $on_fixed -eq 0 ]] || status=1
done
exit $status
