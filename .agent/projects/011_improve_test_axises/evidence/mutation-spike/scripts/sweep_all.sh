#!/usr/bin/env bash
# SPIKE ONLY — applies each mutant in turn, runs the check set, restores, verifies the restore.
# usage: run_all.sh <id> [<id>...]
set -u
root="$(git rev-parse --show-toplevel)"; cd "$root" || exit 9
LOG=tmp/spike/out/sweeps.log; mkdir -p tmp/spike/out
note() { echo "$(date -Is) $*" | tee -a "$LOG"; }
sha() { cat src/core/session.ail src/core/tool_phase.ail src/core/recovery.ail | sha256sum | cut -c1-16; }
BASE=$(cat tmp/spike/base.sha)
snap() { awk '/^cpu /{t=0; for(i=2;i<=9;i++) t+=$i; print $5+$6, t}' /proc/stat; }
idle_cores() { local i0 t0 i1 t1; read -r i0 t0 < <(snap); sleep 5; read -r i1 t1 < <(snap)
  awk -v a="$i0" -v b="$t0" -v c="$i1" -v d="$t1" -v n="$(nproc)" 'BEGIN{printf "%.2f", n*(c-a)/(d-b)}'; }
quiet() { # idle cores over a 5 s window, from /proc/stat; refuse rather than proceed under load
  local idle
  for i in $(seq 1 150); do
    idle=$(idle_cores)
    if awk -v x="$idle" 'BEGIN{exit !(x >= 5.0)}'; then note "gate: idle_cores=$idle of $(nproc) ok"; return 0; fi
    sleep 1
  done
  note "gate: idle_cores=$idle still < 5.0 after 15 min — ABORT"; return 1
}
for id in "$@"; do
  git diff --quiet -- src || { note "$id ABORT: src not clean before apply"; exit 8; }
  [ "$(sha)" = "$BASE" ] || { note "$id ABORT: sha drift before apply"; exit 8; }
  quiet || exit 75
  python3 tmp/spike/mutants.py apply "$id" >> "$LOG" 2>&1 || { note "$id APPLY FAILED"; git checkout -- src; continue; }
  note "$id applied: $(git diff --numstat -- src | tr '\t' ' ' | tr '\n' ';')"
  ./tmp/spike/sweep_one.sh "$id"
  git checkout -- src
  if git diff --quiet -- src && [ "$(sha)" = "$BASE" ]; then note "$id restored OK"; else note "$id RESTORE FAILED"; exit 7; fi
  note "$id $(grep -E '^sweep' tmp/spike/out/sweep-$id/summary.tsv | tr '\t' ' ')"
done
note "sequence done; final sha $(sha) $( [ "$(sha)" = "$BASE" ] && echo 'FINAL INTEGRITY: PASS' || echo 'FINAL INTEGRITY: FAIL')"
