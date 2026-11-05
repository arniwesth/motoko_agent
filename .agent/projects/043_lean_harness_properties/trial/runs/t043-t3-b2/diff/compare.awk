# compare.awk — the model against the real code, then P3.1 and P3.2 on the real code.
#
#   awk -F'|' -f compare.awk lean.out real.out
#
# lean.out (from enumerate.lean.tail), 13 fields:
#   $1 actions | $2-$4 host verdict, history, dangling | $5-$7 twin ... | $8 valid | $9 spec history | $10 spec dangling
#   | $11-$13 host across processes (adopt() before each session_resumed): verdict, history, dangling
# real.out also carries `H|A:<actions>|...` lines: the real host run with --across.
# real.out: `T|<actions>|<verdict>|<history>|<dangling>` (real twin, real fold) and
#           `H|<actions>|...` (real host, real fold).
#
# 1. MODEL: the model's host triple must equal the H line, its twin triple the T line.
# 2. P3.1 on the REAL code, over the sequences the model marks valid (a run can emit them):
#    H and T fold alike — same refusal id, or both accept with equal history and dangling.
# 3. P3.2 on the REAL code, over the valid sequences: T accepts, with history and dangling
#    equal to the model's spec (rule 3, then rule 4's strip).
#
# Exit 1 on any model mismatch. Property violations are counted and listed, not failed:
# they are findings, reproduced separately under ../repro/.
NR == FNR { key = $1; mh[key] = $2 "|" $3 "|" $4; mt[key] = $5 "|" $6 "|" $7; valid[key] = $8; spec[key] = "accept|" $9 "|" $10; ma[key] = $11 "|" $12 "|" $13; n++; next }
$1 == "H" && $2 ~ /^A:/ { k = substr($2, 3); rha[k] = $3 "|" $4 "|" $5; next }
$1 == "T" { rt[$2] = $3 "|" $4 "|" $5; next }
$1 == "H" { rh[$2] = $3 "|" $4 "|" $5; next }
END {
  for (k in mh) {
    if (!(k in rt) || !(k in rh)) { missing++; if (missing <= 5) print "  MISSING real line for [" k "]"; continue }
    if (mh[k] != rh[k]) { bad++; if (bad <= 10) print "  HOST MISMATCH [" k "]\n    model: " mh[k] "\n    real:  " rh[k] }
    if (mt[k] != rt[k]) { bad++; if (bad <= 10) print "  TWIN MISMATCH [" k "]\n    model: " mt[k] "\n    real:  " rt[k] }
    if (!(k in rha)) { missing++; if (missing <= 5) print "  MISSING across-process host line for [" k "]"; continue }
    if (ma[k] != rha[k]) { bad++; if (bad <= 10) print "  HOST-ACROSS MISMATCH [" k "]\n    model: " ma[k] "\n    real:  " rha[k] }
    if (valid[k] == "true") {
      nv++
      split(rh[k], a, "|"); split(rt[k], b, "|")
      if (rh[k] != rt[k]) { p31++; if (p31 <= 8) print "  P3.1 [" k "] host=" rh[k] "  twin=" rt[k] }
      if (rt[k] != spec[k]) { p32++; if (p32 <= 8) print "  P3.2 [" k "] twin=" rt[k] "  spec=" spec[k] }
      if (rh[k] != spec[k]) { hs++ }
      if (rha[k] != rt[k]) { p31a++; if (p31a <= 8) print "  P3.1-across [" k "] host=" rha[k] "  twin=" rt[k] }
    }
  }
  printf "model: %d sequences, %d mismatches with the real code, %d missing\n", n, bad + 0, missing + 0
  printf "P3.1 (real host vs real twin, folded by the real fold): %d of %d valid sequences disagree\n", p31 + 0, nv + 0
  printf "P3.1 across processes (adopted host vs real twin): %d of %d valid sequences disagree\n", p31a + 0, nv + 0
  printf "P3.2 (real twin vs rule 3+4 spec): %d of %d valid sequences violate; host vs spec: %d\n", p32 + 0, nv + 0, hs + 0
  exit (bad > 0 || missing > 0)
}
