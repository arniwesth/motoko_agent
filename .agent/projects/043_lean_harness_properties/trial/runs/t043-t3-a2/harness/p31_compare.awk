# p31_compare.awk — P3.1's executable statement. Inputs: twin.tsv (from the V lines of
# p31_twin.ail: <ix> <verdict> <dangling> <count> <history>) and hostfold.tsv (p31_fold.ail:
# <ix> <mode> <verdict> <dangling> <count> <history> <host pending>).
# P3.1: both refused with the same refusal id, or both accepted with equal history and dangling.
# Also reported (X-1): the host's `exit.pending_tool_calls` source (`pendingToolCalls`) vs the
# fold's dangling, on journals the fold accepts.
BEGIN { FS = "\t" }
FNR == NR { tv[$1] = $2; td[$1] = $3 "|" $4; th[$1] = $5; next }
{
  ix = $1; mode = $2; n++
  if (!(ix in tv)) { print "MISSING twin for " ix; bad++; next }
  hv = $3; hd = $4 "|" $5; hh = $6; hp = $7
  split(tv[ix], a, ":"); split(hv, b, ":")
  ok = 1
  if ((tv[ix] == "accept") != (hv == "accept")) ok = 0
  else if (tv[ix] != "accept") { if (a[2] != b[2]) ok = 0 }
  else if (td[ix] != hd || th[ix] != hh) ok = 0
  if (!ok) {
    bad++; key = mode " twin=" tv[ix] " host=" hv
    cls[key]++
    if (!(key in ex)) ex[key] = ix
  }
  if (hv == "accept" && hp != $4) { pend++; pk = mode; pc[pk]++; if (!(pk in pex)) pex[pk] = ix " host_pending=[" hp "] fold_dangling=[" $4 "]" }
}
END {
  for (k in cls) printf "  P3.1 VIOLATION %-60s %6d  e.g. actions [%s]\n", k, cls[k], ex[k]
  for (k in pc) printf "  X-1 host pending != fold dangling (%s) %d  e.g. [%s]\n", k, pc[k], pex[k]
  printf "p3.1: %d host journals compared, %d disagree with the twin; %d with host pending != dangling\n", n, bad + 0, pend + 0
  exit (bad > 0 || (strict_pending == 1 && pend > 0))
}
