#!/usr/bin/env bash
# make_control.sh <variant> -- build a shadow package root at out/control-<variant> whose
# src/core/journal.ail is a PATCHED COPY of the tree's, everything else symlinked to the tree.
# Used only as a negative control: the harnesses and repros, pointed at this root, must go
# clean when the defect is removed. The tree itself is never modified.
#
#   base    chain_digests_over folds from `base` instead of `chain_empty_base()`
#   linear  `base`, plus the prefix list built with List.mapAccumL instead of `acc.out ++ [d]`
set -euo pipefail
variant="${1:?usage: make_control.sh base|linear}"
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="$(cd "$out/../tree" && pwd)"
c="$out/control-$variant"
rm -rf "$c"; mkdir -p "$c/src/core"
for f in ailang.toml ailang.lock packages; do ln -s "$tree/$f" "$c/$f"; done
for d in "$tree"/src/*; do b=$(basename "$d"); [ "$b" = core ] || ln -s "$d" "$c/src/$b"; done
for f in "$tree"/src/core/*; do b=$(basename "$f"); [ "$b" = journal.ail ] || ln -s "$f" "$c/src/core/$b"; done
j="$c/src/core/journal.ail"
cp "$tree/src/core/journal.ail" "$j"
old='  List.foldl(chain_prefix_step, { last: chain_empty_base(), out: [] }, ms).out'
grep -qF "$old" "$j" || { echo "make_control: anchor not found" >&2; exit 2; }
case "$variant" in
  base)   new='  List.foldl(chain_prefix_step, { last: base, out: [] }, ms).out' ;;
  linear) new='  match List.mapAccumL(\s m. { let d = chain_digest_after(s, m); (d, d) }, base, ms) { (ds, _) => ds }' ;;
  *) echo "unknown variant $variant" >&2; exit 2 ;;
esac
python3 - "$j" "$old" "$new" <<'PY'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
assert s.count(old) == 1
s = s.replace(old, new)
if "mapAccumL" in new:
    s = s.replace("import std/list as List (length, map, foldl)", "import std/list as List (length, map, foldl, mapAccumL)")
open(p, "w").write(s)
PY
# the harness programs, beside the patched root
for f in "$here"/*.ail "$here"/t4_rand.ts; do ln -sf "$f" "$c/$(basename "$f")"; done
diff "$tree/src/core/journal.ail" "$j" || true
echo "control root: $c"
