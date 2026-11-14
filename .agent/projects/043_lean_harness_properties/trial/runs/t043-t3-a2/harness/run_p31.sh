#!/usr/bin/env bash
# P3.1 differential: twin vs host, both folded by the real fold. Run from the tree root.
#   bash ../out/harness/run_p31.sh <maxlen> [scratch]
#   bash ../out/harness/run_p31.sh '[[6,9,0]]' [scratch]     (exactly these action sequences)
# T3_DIR=scratchpad/<dir> is where the .ail copies go (inside the package, so imports resolve).
# T3_HOST_MODULE / T3_JOURNAL_AIL: patched copies of the two writers, for fix validation only.
# T3_GEN=p31_crafted.ail runs the crafted X-2 cases instead of the enumeration.
# T3_MODES=one,crash,restart selects the host lifecycles; T3_STRICT_PENDING=1 also fails on X-1
# (the host's pendingToolCalls, which `exit.pending_tool_calls` is written from, != fold dangling).
# Exit 1 on any P3.1 disagreement.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(pwd)"
maxlen="${1:-2}"
scratch="${2:-$(mktemp -d)}"
d="${T3_DIR:-scratchpad/t3}"
mkdir -p "$scratch" "$d"
for f in "$here"/*.ail; do sed "s#scratchpad/t3/#$d/#" "$f" > "$d/$(basename "$f")"; done
# T3_JOURNAL_AIL=<file>: fold and twin from a patched copy of journal.ail (fix validation only).
if [[ -n "${T3_JOURNAL_AIL:-}" ]]; then
  cp "$T3_JOURNAL_AIL" "$d/journal.ail"
  for f in "$d"/*.ail; do [[ "$f" == "$d/journal.ail" ]] || sed -i "s#src/core/journal (#$d/journal (#" "$f"; done
fi
if [[ "$maxlen" == \[* ]]; then args="{\"maxlen\":0,\"seqs\":$maxlen}"; else args="{\"maxlen\":$maxlen,\"seqs\":[]}"; fi
gen="${T3_GEN:-p31_twin.ail}"
ailang run --relax-modules --caps IO --entry main --args-json "$args" "$d/$gen" 2>/dev/null > "$scratch/twin.raw"
grep '^W	' "$scratch/twin.raw" > "$scratch/wire.tsv"
grep '^V	' "$scratch/twin.raw" | cut -f2- > "$scratch/twin.tsv"
bun "$here/p31_host.ts" "$tree" "$scratch/wire.tsv" "$scratch/j" > "$scratch/host.tsv"
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$scratch/host.tsv\"" "$d/p31_fold.ail" 2>/dev/null > "$scratch/hostfold.tsv"
echo "cases: $(wc -l < "$scratch/twin.tsv") action sequences, $(wc -l < "$scratch/hostfold.tsv") host journals; scratch $scratch"
awk -v strict_pending="${T3_STRICT_PENDING:-0}" -f "$here/p31_compare.awk" "$scratch/twin.tsv" "$scratch/hostfold.tsv"
