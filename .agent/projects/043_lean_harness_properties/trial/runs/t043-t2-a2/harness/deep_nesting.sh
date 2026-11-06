#!/usr/bin/env bash
# deep_nesting.sh — herdr JSON agent_not_found whose message is an array nested <depth> deep,
# through both REAL twins, without going through a shell variable (repro.sh's line limit).
#   bash ../out/harness/deep_nesting.sh 10000 100000 1000000      (from the tree root)
# Prints both halves' line per depth; exit 1 if any depth splits P2.1, 3 on a harness error.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../../tree" && pwd)"
tmp="$here/../runs/deep"; mkdir -p "$tmp"
rc=0
for d in "$@"; do
  python3 -I -c "
import base64,sys
d=int(sys.argv[1])
s='{\"error\":{\"code\":\"agent_not_found\",\"message\":'+'['*d+']'*d+'}}'
print('0\t1\t'+base64.b64encode(s.encode()).decode())" "$d" > "$tmp/c.tsv"
  t="$(bun "$here/ts_eval.ts" < "$tmp/c.tsv")" || exit 3
  a="$( cd "$tree" && ailang run --relax-modules --caps IO --entry main "$here/ail_eval.ail" < "$tmp/c.tsv" 2>/dev/null | grep -E '^[0-9]+	')" || exit 3
  tg="$(cut -f3 <<<"$t")"; ag="$(cut -f4 <<<"$a")"
  echo "depth $d: ts gone=$tg  ail shape=$(cut -f2 <<<"$a") gone=$ag  -> $([[ "$tg" == "$ag" ]] && echo agree || echo SPLIT)"
  [[ "$tg" == "$ag" ]] || rc=1
done
rm -rf "$tmp"
exit $rc
