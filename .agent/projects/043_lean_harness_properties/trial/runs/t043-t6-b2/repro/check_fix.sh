#!/usr/bin/env bash
# Shows the repros discriminate: runs the same repro entries against a SCRATCH copy of the
# compose package with the one-line fix (store.ail:22 `Str.length(s)` -> `length(b)`, the
# byte length, as the caller already computes at :37). The tree is never written.
# Expected: P6.1 and X-1 absent (exit 0), P6.3 still present (exit 1: K2 needs a rune-
# boundary back-off, which TruncateModel.lean's `truncateFixed` states and proves).
#   check_fix.sh [scratch dir]     exit 0 iff every expectation holds
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../tree" && pwd)"
scratch="${1:-$(mktemp -d)}"
pk="$scratch/fixpkgs"; rm -rf "$pk"; mkdir -p "$pk"
cp -r "$tree/packages/motoko-ext-compose" "$pk/motoko-ext-compose"
for d in motoko-ext-abi motoko-ext-ai-compat motoko_ext_conformance; do ln -s "$tree/packages/$d" "$pk/$d"; done
sed -i 's/^  let n = Str.length(s);$/  let n = length(b);/' "$pk/motoko-ext-compose/store.ail"
d="$(diff "$tree/packages/motoko-ext-compose/store.ail" "$pk/motoko-ext-compose/store.ail" || true)"
expected='22c22
<   let n = Str.length(s);
---
>   let n = length(b);'
[[ "$d" == "$expected" ]] || { echo "fixed copy differs unexpectedly:"; echo "$d"; exit 3; }
r="$scratch/fixrepro"; rm -rf "$r"; mkdir -p "$r"
cp "$here/repro.ail" "$here/verdict.py" "$r/"
sed -e "s#../../tree/packages/motoko-ext-compose#$pk/motoko-ext-compose#" \
    -e "s#../../tree/packages/#$tree/packages/#g" "$here/ailang.toml" > "$r/ailang.toml"
( cd "$r" && ailang lock > /dev/null ) || exit 2
ok=0
for spec in "p6_1 P6.1 0" "x1_default_cap X-1 0" "p6_3 P6.3 1" "control_ascii P6.1 0"; do
  set -- $spec
  line="$(cd "$r" && timeout 100 ailang run --caps IO,FS --entry "$1" repro.ail 2>/dev/null)"
  printf '%s\n' "$line" | python3 -I "$r/verdict.py" "$2" | sed 's/^/  /'
  got=${PIPESTATUS[1]}
  echo "$1 $2 on the fixed copy: exit $got (expected $3)"
  [[ "$got" == "$3" ]] || ok=1
done
exit $ok
