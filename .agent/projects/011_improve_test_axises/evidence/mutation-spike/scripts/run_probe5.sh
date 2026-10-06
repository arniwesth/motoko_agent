#!/usr/bin/env bash
# SPIKE ONLY — part 4: the prototype probe under each mutant. Never merges.
# The prototype lives in src/core/dst_invariants.ail (sha in tmp/spike/proto.sha) and stays applied;
# each mutant touches one of three other files, which are restored and hash-checked after every row.
set -u
root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
O=tmp/spike/out5; LOG=$O/sequence.log; mkdir -p "$O"
MUT="src/core/session.ail src/core/tool_phase.ail src/core/recovery.ail src/core/step_machine.ail"
note() { echo "$(date -Is) $*" | tee -a "$LOG"; }
sha() { cat $MUT | sha256sum | cut -c1-16; }
proto() { sha256sum src/core/dst_invariants.ail | cut -c1-16; }
BASE=$(cat tmp/spike/base4.sha); PROTO=$(cat tmp/spike/proto2.sha)
snap() { awk '/^cpu /{t=0; for(i=2;i<=9;i++) t+=$i; print $5+$6, t}' /proc/stat; }
idle_cores() { local i0 t0 i1 t1; read -r i0 t0 < <(snap); sleep 5; read -r i1 t1 < <(snap)
  awk -v a="$i0" -v b="$t0" -v c="$i1" -v d="$t1" -v n="$(nproc)" 'BEGIN{printf "%.2f", n*(c-a)/(d-b)}'; }
quiet() { local idle; for i in $(seq 1 150); do idle=$(idle_cores)
    if awk -v x="$idle" 'BEGIN{exit !(x >= 5.0)}'; then note "gate: idle_cores=$idle ok"; return 0; fi; sleep 1; done
  note "gate: idle_cores=$idle still < 5.0 after 15 min — ABORT"; return 1; }
apply() { case "$1" in
    T*) python3 tmp/spike/mutants3.py apply "$1" ;;
    K2|M3m) python3 tmp/spike/mutants4.py apply "$1" ;;
    R*) python3 tmp/spike/mutants5.py apply "$1" ;;
    *) python3 tmp/spike/mutants.py apply "$1" ;;
  esac; }
for id in "$@"; do
  [ "$(sha)" = "$BASE" ] || { note "$id ABORT: a mutated file is not at baseline before apply"; exit 8; }
  [ "$(proto)" = "$PROTO" ] || { note "$id ABORT: the prototype file changed"; exit 8; }
  quiet || exit 75
  apply "$id" >> "$LOG" 2>&1 || { note "$id APPLY FAILED"; git checkout -- $MUT; continue; }
  d="$O/$id"; rm -rf "$d"; mkdir -p "$d"; git diff -U0 -- $MUT > "$d/mutant.diff" 2>&1
  t0=$(date +%s)
  timeout 600 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
    --entry families_probe3 scripts/dst/spike_families_on_bank.ail < /dev/null > "$d/probe.out" 2>&1
  echo "rc=$? secs=$(( $(date +%s) - t0 )) rows=$(grep -a -c '^FAMROW ' "$d/probe.out") end=$(grep -a -c '^FAMPROBE end' "$d/probe.out")" > "$d/rc"
  git checkout -- $MUT
  if [ "$(sha)" = "$BASE" ] && [ "$(proto)" = "$PROTO" ]; then note "$id restored OK; $(cat $d/rc)"; else note "$id RESTORE FAILED"; exit 7; fi
done
note "sequence done; mutated files $(sha) $( [ "$(sha)" = "$BASE" ] && echo 'FINAL INTEGRITY: PASS' || echo 'FINAL INTEGRITY: FAIL'); prototype $(proto)"
