# count_p42.awk <ail.out> — P4.2 read directly off the REAL code's output (enumerate_chain.ail).
# For every `C` line (base, list) with a non-empty list: does the list of digests have the
# list's length, and is its last element chain_digest_over(base, list)? Counted per base.
BEGIN { FS = "|" }
$1 == "C" { cases++ }
$1 == "C" && $3 != "" {
  n = split($5, d, ",")
  tot[$2]++
  if (d[n] != $4) bad[$2]++
  if ($6 != n || n != split($3, ix, ",")) badlen++
}
END {
  for (b = 0; b < 6; b++)
    printf "base %d: %d of %d non-empty lists have last(chain_digests_over) != chain_digest_over\n", b, bad[b] + 0, tot[b]
  printf "%d C cases; %d with a length mismatch\n", cases, badlen + 0
}
