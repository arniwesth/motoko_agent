#!/usr/bin/env bash
# T2: witness checks for s05, s06, s07 on B0, only-s, T, T-s; and for the S2 seeds (s05, s06) the
# exhaustive search over Appendix C's strings and exit codes with only that seed applied.
set -uo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; H=$W/harness
for s in s05 s06 s07; do
  out=$P/validation/$s; mkdir -p $out
  { echo "# $s: P2.1 witness check. Each line: tree | case | TS herdrMeansAgentGone (code) | AILANG means_agent_gone (code) | P2.1"
    for t in base trees/only-$s trees/T trees/minus-$s; do
      tree=$W/$t; [ "$t" = base ] && name=B0 || name=$(basename $t)
      paste -d'|' <(bun $H/t2_witness.ts $tree) <($H/run_ail.sh $tree $H/t2_witness.ail IO) | awk -F'|' -v n=$name '{
        split($1,a," -> "); split($2,b," -> "); split(a[2],x," "); split(b[2],y," ");
        printf "%-10s | %-50s | TS %-28s | AIL %-28s | %s\n", n, a[1], a[2], b[2], (x[1]==y[1])?"holds":"VIOLATED" }'
    done
    echo; echo "# witness stderr byte lengths"
    python3 -I -c 'import sys
for n,s in [("s05",'"'"'{"error":{"code":"agent_not_found","message":"x"}}'"'"'),("s06",'"'"'{"error":{"code":"pane_not_found","message":"x"}}'"'"'),("s07",'"'"'{ "error": {"code": "agent_not_found", "message": "x"}}'"'"')]: print(n, len(s.encode()), "bytes:", s)'
  } > $out/witness.log
done
for s in s05 s06; do
  out=$P/validation/$s
  { echo "# $s: exhaustive P2.1 search, ONLY $s applied (trees/only-$s), Appendix C: every string <= 8 bytes over {a, 1, space, \", é, €} x exit {-1,0,1,2,3}"
    echo "# TS side (herdrMeansAgentGone):"; bun $H/t2_vocab.ts $W/trees/only-$s | tee /tmp/claude-1001/t2ts.$s
    echo "# AILANG side (means_agent_gone):"; $H/run_ail.sh $W/trees/only-$s $H/t2_vocab.ail IO | tee /tmp/claude-1001/t2ail.$s
    if cmp -s /tmp/claude-1001/t2ts.$s /tmp/claude-1001/t2ail.$s; then echo "RESULT: identical gone-sets on both sides for all $(head -1 /tmp/claude-1001/t2ts.$s | cut -d= -f2) strings x 5 exit codes: NO P2.1 violation within the bound"; else echo "RESULT: MISMATCH"; fi
  } > $out/exhaustive.log
done
grep -h "RESULT" $P/validation/s0[56]/exhaustive.log; for s in s05 s06 s07; do grep "$s-witness" $P/validation/$s/witness.log; done
