#!/usr/bin/env bash
# attribute.sh <compare.ts output, run with a large T3_EXAMPLES> — attribute every P3.1 and
# P3.2 violation listed to a reported root cause by the ops of its case:
#
#   KN or KL anywhere                     first_kept            (A1-T3-4, A1-T3-5)
#   H1 anywhere                           empty call id         (A1-T3-3)
#   R1 anywhere (P3.1 only: a host cause) host replace pending  (A1-T3-2)
#   CP (or KL) then, first after it, FU   follow-up after checkpoint (A1-T3-6)
#   CP (or KL) then, first after it, RS/PS twin replaced_since_seed (A1-T3-1)
#
# Anything else is printed as UNATTRIBUTED: a violation no report explains. This is
# bookkeeping by shape, not a proof of cause; the residual run with both writer fixes
# applied (SUMMARY.md) is the stronger check.
awk '
  function after_cp(ops,   n, xs, i, seen) {
    n = split(ops, xs, ","); seen = 0
    for (i = 1; i <= n; i++) {
      if (xs[i] ~ /^CP/) seen = 1
      else if (seen && xs[i] ~ /^FU/) return "FU"
      else if (seen && xs[i] ~ /^(RS|PS)/) return "RS"
    }
    return ""
  }
  /^P3\.[12] / { split($0, c, " "); p = c[1]; on = 1; next }
  /^[A-Za-z]/ { on = 0 }
  on && NF >= 2 {
    ops = $2; k = after_cp(ops)
    if (ops ~ /KN|KL/) a = "first_kept (A1-T3-4/5)"
    else if (ops ~ /H1/) a = "empty call id (A1-T3-3)"
    else if (ops ~ /R1/ && p == "P3.1") a = "host replace pending (A1-T3-2)"
    else if (k == "FU") a = "follow-up after checkpoint (A1-T3-6)"
    else if (k == "RS") a = "twin replaced_since_seed (A1-T3-1)"
    else a = "UNATTRIBUTED"
    n[p " " a]++
    if (a == "UNATTRIBUTED") print "  UNATTRIBUTED " p ": " $0
  }
  END { for (k in n) printf "  %-50s %d\n", k, n[k] }' "$1" | sort
