#!/usr/bin/env bash
# 039 random-mutant pilot: tier 3, the targeted set, for each id in turn.
#
#   run_tier3.sh <id>...     an id run_gate.sh accepts (C-base for the unmutated tree, or mNN)
#
# For each id, in order: check_core, strict_replay, discovery, stream_parity, ledger_parity, then
# corpus_pr LAST, so nothing this pilot starts runs beside it (it gates on its own wall clock). Each
# target is one run_gate.sh call: apply, run, restore, hash-check. If corpus_pr is red on its
# ceiling alone it is re-run once, as the brief says, and both runs are kept.
set -u
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for id in "$@"; do
  for t in check_core strict_replay discovery stream_parity ledger_parity corpus_pr; do
    "$E/scripts/run_gate.sh" "$t" "$id" > /dev/null || exit $?
  done
  st=$(python3 "$E/scripts/score_target.py" corpus_pr "$id" | awk -F'\t' 'NR==2 {print $3}')
  if [ "$st" = "CEILING-ONLY" ]; then
    mv "$E/runs/corpus_pr/$id" "$E/runs/corpus_pr/$id-first"
    echo "$(date -u +%FT%TZ) corpus_pr $id was red on its ceiling alone; kept as $id-first and re-run once" >> "$E/sequence.log"
    "$E/scripts/run_gate.sh" corpus_pr "$id" > /dev/null || exit $?
  fi
done
echo "$(date -u +%FT%TZ) run_tier3.sh $* done" >> "$E/sequence.log"
