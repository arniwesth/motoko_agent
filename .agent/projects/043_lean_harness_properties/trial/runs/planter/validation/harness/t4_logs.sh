#!/usr/bin/env bash
P=/home/motoko/trial-043/planter; R=$P/work/runs
{ echo "# s12 (E): T4. t4_chain.ail over every split xs ++ ys of every list of 0..4 of the eleven messages"
  echo "# (16,105 lists, 95,020 property checks per base), bases chain_empty_base() and \"sha256:b\"."
  echo "# verdicts-sha256 digests every P4.1/P4.2 verdict in order; function-outputs-sha256 digests every"
  echo "# output of chain_digests_over and chain_digest_over."
  echo "== B0"; grep -v s11-witness $R/t4v2-base.out
  echo "== only-s12"; grep -v s11-witness $R/t4v2-only-s12.out
  for k in "base=chain_empty_base sequences" "base=sha256:b sequences" "base=chain_empty_base function" "base=sha256:b function"; do
    a=$(grep "$k" $R/t4v2-base.out); b=$(grep "$k" $R/t4v2-only-s12.out)
    echo "RESULT ${k}: $([ "$a" = "$b" ] && echo identical || echo DIFFERENT)"
  done; } > $P/validation/s12/validation.log
{ echo "# s11 (S1): T4. The same search with only s11 applied, for the witness size: every failing case and the smallest."
  echo "== only-s11"; cat $R/t4-only-s11.out
  echo "== T (all seeds)"; cat $R/t4-T.out
  echo "== B0, for comparison"; cat $R/t4v2-base.out
  echo "# Smallest violations: P4.1 at xs = ys = [one message] (2 messages, verdict string 1101 at k = 1) under either base;"
  echo "# P4.2 at a single message under any base other than chain_empty_base() (see witness.log)."; } > $P/validation/s11/exhaustive.log
mkdir -p $P/validation/s12; grep RESULT $P/validation/s12/validation.log
