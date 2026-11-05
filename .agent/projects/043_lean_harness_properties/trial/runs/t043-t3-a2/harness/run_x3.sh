#!/usr/bin/env bash
# X-3: after a torn last line, the adopting host's next append. Run from the tree root.
#   bash ../out/harness/run_x3.sh [scratch]
# Exit 1 when the torn journal folds (accept) but the journal with one post-adopt append is
# refused by parse_journal_text/fold_journal — i.e. the crash the adopt path anticipates turns
# a recoverable journal into an unreadable one.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(pwd)"
scratch="${1:-../out/work/x3}"
d="${T3_DIR:-scratchpad/t3x3}"
mkdir -p "$scratch" "$d"
for f in "$here"/*.ail; do sed "s#scratchpad/t3/#$d/#" "$f" > "$d/$(basename "$f")"; done
ailang run --relax-modules --caps IO --entry main --args-json '{"maxlen":0,"seqs":[[0,0]]}' "$d/p31_twin.ail" 2>/dev/null | grep '^W	' > "$scratch/wire.tsv"
bun "$here/x3_torn.ts" "$tree" "$scratch/wire.tsv" "$scratch/j" > "$scratch/host.tsv"
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$scratch/host.tsv\"" "$d/p31_fold.ail" 2>/dev/null > "$scratch/fold.tsv"
cut -f1-4 "$scratch/fold.tsv" | cut -c1-200
torn="$(awk -F'\t' '$2=="torn"{print $3}' "$scratch/fold.tsv")"
after="$(awk -F'\t' '$2=="torn+1"{print $3}' "$scratch/fold.tsv")"
echo "torn: $torn; torn then one adopted append: $after"
[[ "$torn" == "accept" && "$after" != "accept" ]] && exit 1
exit 0
