#!/usr/bin/env bash
# SPIKE ONLY, part 6 — the journal control: `make eval_matrix` on the unmutated tree, then with
# the v0.2 prototype (proto2_apply.py) applied to the working tree. Never merges.
cd /workspaces/motoko_agent-spike-mut || exit 9
O=tmp/spike/out6
log(){ echo "$(date -Is) $*" >> $O/sequence.log; }
mem(){ echo "cgroup_current=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"; }
run(){ # $1 = label
  local d=$O/$1; mkdir -p "$d"; local t0=$(date +%s)
  log "$1 start head=$(git rev-parse --short HEAD) invariants=$(sha256sum src/core/dst_invariants.ail | cut -c1-16) $(mem)"
  make --no-print-directory eval_matrix EVAL_MATRIX_ARGS="--logs $PWD/$d/logs --out $PWD/$d/MATRIX.tsv" > "$d/run.log" 2>&1
  echo $? > "$d/rc"
  log "$1 done rc=$(cat "$d/rc") secs=$(( $(date +%s) - t0 )) $(mem)"
}
git diff --quiet -- src || { log "ABORT: src not clean before baseline"; echo ABORTED > $O/DONE; exit 8; }
run baseline
python3 tmp/spike/proto2_apply.py >> $O/sequence.log 2>&1
if [ "$(sha256sum src/core/dst_invariants.ail | cut -c1-16)" != "$(cat tmp/spike/proto2.sha)" ]; then
  log "ABORT: prototype hash differs from the one part 5 ran"; git checkout -- src/core/dst_invariants.ail; echo ABORTED > $O/DONE; exit 7
fi
run proto
git checkout -- src/core/dst_invariants.ail
if git diff --quiet -- src; then log "restored OK; src clean"; else log "RESTORE FAILED"; fi
echo "FINISHED $(date -Is)" > $O/DONE
