#!/usr/bin/env bash
# P3.1 on the REAL code for one child-simulator step sequence (diff/gen.ail's alphabet):
# the REAL host's journal and the REAL twin's journal, each folded by the REAL fold_journal.
#   bash ../out/repro/p31.sh 7,8,5       (from the tree root)
# Exit 1 when the two verdicts differ (defect present), 0 when they agree.
source "$(dirname "$0")/_env.sh"
steps="${1:?usage: p31.sh <comma-separated steps>}"
ail --caps IO --entry one_of --args-json "[${steps}]" diff/gen.ail > "$work/gen.out"
twin="$(grep -aE '^T	' "$work/gen.out" | cut -f3)"
host="$(host_verdict "$work/gen.out" | cut -f3)"
echo "steps $steps"
echo "  host journal folds to: $host"
echo "  twin journal folds to: $twin"
if [[ "$host" != "$twin" ]]; then echo "P3.1 VIOLATED"; exit 1; fi
echo "P3.1 holds"; exit 0
