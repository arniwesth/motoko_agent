#!/usr/bin/env bash
# 041 W1: run mutants t1 and t2 one at a time against admission_live_test. Run from the worktree root on a clean tree.
set -u
EV=.agent/projects/041_process_execution_timeouts/evidence/W1
OUT=${1:?log directory}
[ -z "$(git status --porcelain -- src)" ] || { echo "src is dirty"; exit 2; }
echo "commit $(git rev-parse HEAD)"
for m in t1 t2; do
  git apply "$EV/$m.diff" || { echo "$m: does not apply"; exit 2; }
  ailang check src/eval/journal/world.ail >"$OUT/$m.check" 2>&1; echo "$m: check exit=$?"
  ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand --ai-stub --entry main \
    src/eval/journal/admission_live_test.ail </dev/null >"$OUT/$m.log" 2>&1
  echo "$m: run exit=$?"
  grep -E '^(PASS|FAIL) ' "$OUT/$m.log" | grep -E 'r6_|^FAIL' || true
  grep -E '^r6_(replay|control)|^r6_post_change_admits:' "$OUT/$m.log" | cut -c1-260
  tail -1 "$OUT/$m.log" | cut -c1-200
  git apply -R "$EV/$m.diff" || { echo "$m: did not restore"; exit 2; }
done
[ -z "$(git status --porcelain -- src)" ] && echo "tree clean" || { echo "tree dirty"; exit 2; }
