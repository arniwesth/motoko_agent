#!/usr/bin/env bash
# SPIKE ONLY, part 6 — known-bad control for the journal suites: the v0.2 prototype with ONE wrong
# row in D2's table (StepBudgetExhausted -> "error"). If the live suites evaluate a suspended run,
# they must go red. Never merges.
cd /workspaces/motoko_agent-spike-mut || exit 9
O=tmp/spike/out6/known-bad; mkdir -p $O
git diff --quiet -- src || { echo "ABORT src not clean" > $O/DONE; exit 8; }
python3 tmp/spike/proto2_apply.py > $O/apply.log 2>&1
python3 - <<'PY' >> $O/apply.log 2>&1
p='src/core/dst_invariants.ail'; s=open(p).read()
a='if code == "StepBudgetExhausted" then "max_steps"'; assert s.count(a)==1
open(p,'w').write(s.replace(a,'if code == "StepBudgetExhausted" then "error"')); print("known-bad row applied")
PY
for f in witness_live_test candidate_checks_live_test; do
  timeout 1800 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand --ai-stub --entry main src/eval/journal/$f.ail < /dev/null > $O/$f.log 2>&1; echo "$f rc=$?" >> $O/rc
done
git checkout -- src/core/dst_invariants.ail
git diff --quiet -- src && echo "restored OK" >> $O/rc || echo "RESTORE FAILED" >> $O/rc
echo "FINISHED $(date -Is)" > $O/DONE
