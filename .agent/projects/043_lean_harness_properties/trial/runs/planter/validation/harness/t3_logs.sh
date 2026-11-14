#!/usr/bin/env bash
# Assemble T3's validation logs (s08, s09 = S2; s10 = E) from runs/t3-* and runs/t3r-*.
set -uo pipefail
P=/home/motoko/trial-043/planter; W=$P/work; R=$W/runs; H=$W/harness
res() { grep -v '^E' "$1" | sort; }
for s in s08 s09 s10; do mkdir -p $P/validation/$s; done
for s in s08 s09; do
  w=W${s#s}
  { echo "# $s (S2): T3. Pipeline: t3_gen.ail (wire events via to_schema_v1 + the AILANG twin folded by fold_journal),"
    echo "# t3_host.ts (the real SessionJournal writes each journal from those events), t3_fold.ail (fold_journal on the host's"
    echo "# journals). P3.1 holds on a case iff both folds refuse with the same refusal id, or both accept with equal history"
    echo "# and dangling. P3.2 (rule 3) is checked on accepted appended-only cases with no dangling call."
    echo
    echo "## 1. Exhaustive search over Appendix C's T3 alphabet, ONLY $s applied (trees/only-$s)"
    echo "## 16,105 histories (0..4 appended messages over the eleven messages, enumerate_fold.ail's prologue and epilogue)"
    $H/t3_compare.sh only-$s | sed 's/^/   /'
    echo "   Appendix-C cases whose outcome differs from B0 (twin or host): $(diff <(res $R/t3-B0.gen | grep -v "	W0") <(res $R/t3-only-$s.gen | grep -v "	W0") | grep -c '^[<>]') twin, $(diff <(sort $R/t3-B0.host | grep -v "	W0") <(sort $R/t3-only-$s.host | grep -v "	W0") | grep -c '^[<>]') host"
    echo "   RESULT: no P3.1 or P3.2 violation among the 16,105 Appendix C histories (the only violation listed is the named witness $w)."
    echo
    echo "## 2. Richer record alphabet (t3_rich.ail): every sequence of 1..5 records, the first seed counted, over seven"
    echo "## record-producing actions (append plain / call / result / user, hybrid replacement, checkpoint, resume = 2 records)."
    echo "## 'ne' marks sequences no run emits (a resume of a journal the fold refuses; a hybrid replacement not after its plain assistant)."
    for n in B0 only-$s; do
      echo "   -- $n"
      $H/t3r_compare.sh $n | grep -v "ne:" | sed 's/^/   /'
      for k in 1 2 3 4 5; do
        v=$($H/t3r_compare.sh $n | grep -c "VIOLATED R$k:"); c=$(grep -c "^W	R$k:" $R/t3r-$n.gen)
        echo "      emittable sequences of $k record(s): $c, P3.1 violations: $v"
      done
    done
    echo "   Per-case outcomes that differ from B0 (emittable sequences only), by size:"
    for k in 1 2 3 4 5; do
      d1=$(diff <(grep "^W	R$k:" $R/t3r-B0.gen | sort) <(grep "^W	R$k:" $R/t3r-only-$s.gen | sort) | grep -c '^>')
      d2=$(diff <(grep "^H	R$k:" $R/t3r-B0.host | sort) <(grep "^H	R$k:" $R/t3r-only-$s.host | sort) | grep -c '^>')
      echo "      $k record(s): twin $d1, host $d2"
    done
    echo
    echo "## 3. The witness $w (also a case of the richer alphabet), on B0, only-$s, T and T-$s"
    for n in B0 only-$s T minus-$s; do
      printf "   %-10s twin: %-90s host: %s\n" $n "$(grep -P "^W\t$w\t" $R/t3-$n.gen | cut -f3)" "$(grep -P "^H\t$w\t" $R/t3-$n.host | cut -f3)"
    done
    echo "   (fields: verdict | dangling ids | how many | sha256 of the folded history | rule-3 check)"
    echo "   Its wire events, in order:"
    grep -P "^E\t$w\t" $R/t3-B0.gen | cut -f3 | sed 's/^/     /'
  } > $P/validation/$s/validation.log
done
{ echo "# s10 (E): T3. The properties give the same results with and without the seed over Appendix C's T3 alphabet."
  echo "## Appendix C alphabet (16,105 histories + the 2 named scenarios), B0 vs only-s10:"
  $H/t3_compare.sh B0 | sed 's/^/   B0: /'; $H/t3_compare.sh only-s10 | sed 's/^/   only-s10: /'
  echo "   wire events identical: $(cmp -s <(grep '^E' $R/t3-B0.gen) <(grep '^E' $R/t3-only-s10.gen) && echo yes || echo no)"
  echo "   twin outcomes identical: $(cmp -s <(res $R/t3-B0.gen) <(res $R/t3-only-s10.gen) && echo yes || echo no)"
  echo "   host journals byte-identical: $(cmp -s $R/t3-B0.jl $R/t3-only-s10.jl && echo yes || echo no)"
  echo "   host fold outcomes identical: $(cmp -s <(sort $R/t3-B0.host) <(sort $R/t3-only-s10.host) && echo yes || echo no)"
  echo "## Richer record alphabet (1,677 sequences), B0 vs only-s10:"
  echo "   host journals byte-identical: $(cmp -s $R/t3r-B0.jl $R/t3r-only-s10.jl && echo yes || echo no)"
  echo "   host fold outcomes identical: $(cmp -s <(sort $R/t3r-B0.host) <(sort $R/t3r-only-s10.host) && echo yes || echo no)"
  echo "   twin outcomes identical: $(cmp -s <(res $R/t3r-B0.gen) <(res $R/t3r-only-s10.gen) && echo yes || echo no)"
} > $P/validation/s10/validation.log
