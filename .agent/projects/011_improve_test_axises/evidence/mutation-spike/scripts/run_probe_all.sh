#!/usr/bin/env bash
# SPIKE ONLY — part 2: the invariant set over the bank, under each mutant. Never merges.
# usage: run_probe_all.sh <id> [<id>...]
set -u
root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
O=tmp/spike/out2; LOG=$O/sequence.log; mkdir -p "$O"
note() { echo "$(date -Is) $*" | tee -a "$LOG"; }
sha() { cat src/core/session.ail src/core/tool_phase.ail src/core/recovery.ail | sha256sum | cut -c1-16; }
BASE=$(cat tmp/spike/base.sha)
snap() { awk '/^cpu /{t=0; for(i=2;i<=9;i++) t+=$i; print $5+$6, t}' /proc/stat; }
idle_cores() { local i0 t0 i1 t1; read -r i0 t0 < <(snap); sleep 5; read -r i1 t1 < <(snap)
  awk -v a="$i0" -v b="$t0" -v c="$i1" -v d="$t1" -v n="$(nproc)" 'BEGIN{printf "%.2f", n*(c-a)/(d-b)}'; }
quiet() { local idle; for i in $(seq 1 150); do idle=$(idle_cores)
    if awk -v x="$idle" 'BEGIN{exit !(x >= 5.0)}'; then note "gate: idle_cores=$idle ok"; return 0; fi; sleep 1; done
  note "gate: idle_cores=$idle still < 5.0 after 15 min — ABORT"; return 1; }
probe() { # probe <label>
  local d="$O/$1"; rm -rf "$d"; mkdir -p "$d"; git diff -U0 -- src > "$d/mutant.diff" 2>&1
  local t0; t0=$(date +%s)
  timeout 600 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace --ai-stub \
    --entry families_probe scripts/dst/spike_families_on_bank.ail < /dev/null > "$d/probe.out" 2>&1
  echo "rc=$? secs=$(( $(date +%s) - t0 )) rows=$(grep -a -c '^FAMROW ' "$d/probe.out") end=$(grep -a -c '^FAMPROBE end' "$d/probe.out")" > "$d/rc"
}
for id in "$@"; do
  git diff --quiet -- src || { note "$id ABORT: src not clean before apply"; exit 8; }
  [ "$(sha)" = "$BASE" ] || { note "$id ABORT: sha drift before apply"; exit 8; }
  quiet || exit 75
  if [ "$id" != "baseline" ]; then
    python3 tmp/spike/mutants.py apply "$id" >> "$LOG" 2>&1 || { note "$id APPLY FAILED"; git checkout -- src; continue; }
  fi
  probe "$id"
  git checkout -- src
  if git diff --quiet -- src && [ "$(sha)" = "$BASE" ]; then note "$id restored OK; $(cat $O/$id/rc)"; else note "$id RESTORE FAILED"; exit 7; fi
done
note "sequence done; final sha $(sha) $( [ "$(sha)" = "$BASE" ] && echo 'FINAL INTEGRITY: PASS' || echo 'FINAL INTEGRITY: FAIL')"
