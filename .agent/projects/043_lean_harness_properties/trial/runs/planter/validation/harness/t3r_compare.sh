#!/usr/bin/env bash
# t3_compare.sh <name> — P3.1 (host fold vs twin fold) and P3.2 (twin fold vs rule 3) per case.
W=/home/motoko/trial-043/planter/work; n="$1"
awk -F'\t' -v n="$n" '
  FNR==NR { if ($1=="W") tw[$2]=$3; next }
  $1=="H" { host[$2]=$3 }
  END {
    for (c in tw) {
      split(tw[c], t, "|"); split(host[c], h, "|"); total++
      p31 = (t[1]==h[1]) && (t[1]!="accept" || (t[2]==h[2] && t[3]==h[3] && t[4]==h[4]))
      if (!p31) { v31++; if (c ~ /^W/ || c ~ /^R[0-9]:/ || v31 <= 5) print "  P3.1 VIOLATED " c "  twin=" t[1] "|" t[2] "|" t[3] "  host=" h[1] "|" h[2] "|" h[3] (t[4]!=h[4] && t[1]=="accept" && h[1]=="accept" ? "  (histories differ)" : "") }
      if (t[5]=="differs") { v32++; print "  P3.2 VIOLATED (history differs from rule 3) " c }
      if (t[1]=="accept") acc++
    }
    printf "%s: %d cases; twin accepts %d; P3.1 violated in %d; P3.2 rule-3 history differs in %d\n", n, total, acc, v31+0, v32+0
  }' $W/runs/t3r-$n.gen $W/runs/t3r-$n.host
