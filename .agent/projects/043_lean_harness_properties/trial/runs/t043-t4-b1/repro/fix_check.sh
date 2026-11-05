#!/usr/bin/env bash
# fix_check.sh — Kiro's step 8 on the real code: the repros must EXIT 0 once the defect is gone.
# Builds out/repro/.fixed_tree: symlinks to the tree everywhere except src/core/journal.ail,
# which is a copy with the one-token fix of chain_digests_over (journal.ail:293)
#     { last: chain_empty_base(), out: [] }   ->   { last: base, out: [] }
# then runs both repros against it. The tree itself is never written.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../tree" && pwd)"
ft="$here/.fixed_tree"
rm -rf "$ft"; mkdir -p "$ft/src/core"
for f in ailang.toml ailang.lock packages; do ln -s "$tree/$f" "$ft/$f"; done
for e in "$tree"/src/*; do [[ "$(basename "$e")" == core ]] || ln -s "$e" "$ft/src/$(basename "$e")"; done
for e in "$tree"/src/core/*; do [[ "$(basename "$e")" == journal.ail ]] || ln -s "$e" "$ft/src/core/$(basename "$e")"; done
sed 's/List.foldl(chain_prefix_step, { last: chain_empty_base(), out: \[\] }, ms).out/List.foldl(chain_prefix_step, { last: base, out: [] }, ms).out/' \
  "$tree/src/core/journal.ail" > "$ft/src/core/journal.ail"
echo "patch:"; diff "$tree/src/core/journal.ail" "$ft/src/core/journal.ail" || true
rc=0
for r in P4_1 P4_2; do
  set +e; TREE="$ft" "$here/verdict.sh" "$here/repro_$r.ail" > "$here/.fixed_$r.txt"; s=$?; set -e
  echo "repro_$r against the fixed tree: exit $s ($(tail -1 "$here/.fixed_$r.txt"))"
  [[ $s -eq 0 ]] || rc=1
done
exit $rc
