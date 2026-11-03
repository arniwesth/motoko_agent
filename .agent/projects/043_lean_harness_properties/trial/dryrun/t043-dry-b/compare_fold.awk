# compare_fold.awk — the model's fold against the real one, and the real host against the
# real fold. Input: lean.out and ail.out joined line by line with `paste -d'|'`:
#
#   $1 indices  $2 model hostPending  $3 model accept|refuse  $4 model open ids  $5 count
#   $6 indices  $7 real verdict       $8 real dangling        $9 count
#
# The model's host field is compared with the real host elsewhere (run_diff.sh's diff), so
# here $2 stands for the real `updatePending`'s output too.
#
# 1. Model fold vs real fold. The model is `pair_step`'s fold only, so its refusal must be
#    the real fold's `pairing` refusal, and its acceptance must be the real fold's
#    acceptance with `dangling` equal to the model's open ids, or a refusal by a check the
#    real fold runs after pairing (`transcript`, `head-prefix`), which is counted, not failed.
# 2. Real host vs real fold. Where the real fold accepts, `exit.pending_tool_calls` and
#    `SessionState.dangling` must be equal within (H1) and (H2): no message 8 or 10.
#    Disagreements outside them are listed: they are the cases the hypotheses exclude.
#
# Exit 1 on any mismatch in 1 or any disagreement within (H1)/(H2) in 2.
BEGIN { FS = "|" }
$1 != $6 { print "ORDER MISMATCH at line " NR ": " $1 " vs " $6; order = 1; exit 1 }
{
  real = ($7 == "accept" || $7 == "pairing") ? $7 : "other:" $7
  pairs[$3 " / " real]++
  if ($3 == "accept" && $7 == "accept" && ($4 != $8 || $5 != $9)) { bad++; if (bad <= 10) print "  DANGLING MISMATCH " $0 }
  if ($3 == "accept" && $7 == "pairing") { bad++; if (bad <= 10) print "  VERDICT MISMATCH " $0 }
  if ($3 == "refuse" && $7 != "pairing") { bad++; if (bad <= 10) print "  VERDICT MISMATCH " $0 }
  if ($7 == "accept") {
    hyp_ok = ($1 !~ /(^|,)(8|10)(,|$)/)
    host_n = ($2 == "") ? 0 : split($2, tmp, ",")
    same = ($2 == $8 && host_n == $9)
    if (hyp_ok) { in_n++; if (!same) { twin_bad++; if (twin_bad <= 10) print "  TWIN DISAGREES within H1/H2: " $0 } }
    else if (!same) { out_bad++; if (out_bad <= 5) print "  twin disagrees outside H1/H2: " $1 " host=[" $2 "] dangling=[" $8 "] (" $9 ")" }
  }
}
END {
  if (order) exit 1
  for (k in pairs) printf "  model / real fold: %-24s %6d\n", k, pairs[k]
  printf "fold: %d histories, %d mismatches between the model and the real fold\n", NR, bad + 0
  printf "twin: %d histories the real fold accepts within H1/H2, %d where host and fold disagree; %d disagree outside H1/H2\n", in_n + 0, twin_bad + 0, out_bad + 0
  exit (bad > 0 || twin_bad > 0)
}
