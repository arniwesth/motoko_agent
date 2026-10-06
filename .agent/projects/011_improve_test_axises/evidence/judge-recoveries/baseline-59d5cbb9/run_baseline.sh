#!/usr/bin/env bash
# Baseline for PLAN-judge-recoveries-on-real-runs (011): which `make dst` targets and which
# `make eval_matrix` suites are red on a CLEAN checkout of origin/main, no source edit.
# Sequential on purpose: corpus_pr gates on wall time and the matrix has a memory guard.
set -u
OUT=/workspaces/motoko_agent/tmp/plan-011-baseline-2026-10-06
WT=/workspaces/motoko_agent-011-baseline
REV=59d5cbb9
cd /workspaces/motoko_agent || exit 97
{
  echo "start $(date -u +%FT%TZ) rev=$REV ailang=$(ailang --version 2>&1 | head -1) nproc=$(nproc)"
  if [ ! -d "$WT" ]; then git worktree add --detach "$WT" "$REV" || exit 98; fi
  cd "$WT" || exit 98
  echo "worktree HEAD $(git rev-parse HEAD) status-lines=$(git status --short | wc -l)"
  uptime
} > "$OUT/meta.txt" 2>&1
cd "$WT" || exit 98

t0=$(date +%s)
timeout 6000 make dst > "$OUT/dst.stdout.log" 2>&1; rc_dst=$?
t1=$(date +%s)
cp -f .ailang/dst-last.log "$OUT/dst-last.log" 2>/dev/null
echo "dst rc=$rc_dst seconds=$((t1 - t0)) end $(date -u +%FT%TZ)" >> "$OUT/meta.txt"
git status --short > "$OUT/status-after-dst.txt" 2>&1

mkdir -p "$OUT/matrix-logs"
timeout 4200 make eval_matrix EVAL_MATRIX_ARGS="--logs $OUT/matrix-logs" > "$OUT/matrix.stdout.log" 2>&1; rc_mx=$?
t2=$(date +%s)
cp -f src/eval/journal/testdata/MATRIX.tsv "$OUT/MATRIX.tsv" 2>/dev/null
echo "eval_matrix rc=$rc_mx seconds=$((t2 - t1)) end $(date -u +%FT%TZ)" >> "$OUT/meta.txt"
git status --short > "$OUT/status-after-matrix.txt" 2>&1
uptime >> "$OUT/meta.txt"
echo DONE >> "$OUT/meta.txt"
