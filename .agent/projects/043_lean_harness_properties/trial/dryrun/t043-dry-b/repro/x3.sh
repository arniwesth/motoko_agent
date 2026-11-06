#!/usr/bin/env bash
# X-3: [asst(a,""), tool(a)] -- real fold accepts with dangling=[""] (1 id); real updatePending gives [].
# Exit 1 if both hold (the two sides disagree on a history the fold accepts).
O=/home/motoko/trial-043/s/t043-dry-b/out
host=$(bun "$O/repro/host.ts" '[["assistant",["a",""],""],["tool",[],"a"]]')
echo "real host pending: [$host]"
if [[ "$host" == "" ]] && bash "$O/repro/fold1.sh" x3 '10,4|accept||1' >/dev/null; then echo absent; exit 0; fi
[[ "$host" == "" ]] && { echo "DEFECT PRESENT: fold dangling=[\"\"], host pending=[]"; exit 1; }
echo absent; exit 0
