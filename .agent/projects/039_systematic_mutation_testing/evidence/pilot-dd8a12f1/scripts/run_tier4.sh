#!/usr/bin/env bash
# 039 random-mutant pilot: tier 4, a full `make dst` on the tier-3 survivors.
#
#   run_tier4.sh <reached id>...   the ids tier 3 ran, in draw order
#
# Waits for tier 3's closing line, reads each id's six tier-3 results with score_target.py, and
# takes as survivors the ids with every target GREEN (a CEILING-ONLY corpus_pr was re-run by
# run_tier3.sh and the re-run is what is read). Logs the survivors, then sweeps the unmutated tree
# (C-base, asked for by the operator so a red can be checked against base) and the first five
# survivors in draw order. Survivors past five are logged as not swept.
set -u
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
until grep -q "run_tier3.sh $* done" "$LOG"; do sleep 20; done
surv=()
for id in "$@"; do
  all=1
  for t in check_core strict_replay discovery stream_parity ledger_parity corpus_pr; do
    st=$(python3 "$E/scripts/score_target.py" "$t" "$id" | awk -F'\t' 'NR==2 {print $3}')
    [ "$st" = "GREEN" ] || all=0
  done
  [ $all = 1 ] && surv+=("$id")
done
swept=("${surv[@]:0:5}"); rest=("${surv[@]:5}")
echo "$(date -u +%FT%TZ) TIER 3 survivors (all six targets GREEN), in draw order: ${surv[*]:-none}. TIER 4 sweeps C-base then: ${swept[*]:-none}; not swept (past five): ${rest[*]:-none}" >> "$LOG"
"$E/scripts/run_gate.sh" dst C-base "${swept[@]}" > /dev/null
echo "$(date -u +%FT%TZ) run_tier4.sh done" >> "$LOG"
