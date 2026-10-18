#!/usr/bin/env bash
# Baseline for 034 PLAN-001 W0.1 (before) and W0.7 (after): which `make dst` targets and which
# `make eval_matrix` rows are red at REV, with no source edit.
# Sequential on purpose: corpus_pr gates on wall time and the matrix is under the 12 GiB
# memory.current rule (Makefile:3526). Run nothing heavy beside it (PLAN-001 standing rule 4).
#
#   REV=<sha> WT=<worktree> OUT=<dir> run_baseline.sh
#
# WT must have REV checked out with no tracked change. If WT does not exist, a detached worktree
# is added there. OUT gets the files the README lists and the full logs, which are not committed.
set -u
REV=${REV:-3ae506cc}
WT=${WT:-/workspaces/motoko_agent-034-baseline-$REV}
OUT=${OUT:-${TMPDIR:-/tmp}/plan-034-baseline-$REV}
mkdir -p "$OUT" || exit 97
touch "$OUT/.start"
{
  echo "start $(date -u +%FT%TZ) rev=$REV ailang=$(ailang --version 2>&1 | head -1) nproc=$(nproc)"
  if [ ! -d "$WT" ]; then git worktree add --detach "$WT" "$REV" || exit 98; fi
  cd "$WT" || exit 98
  want=$(git rev-parse "$REV^{commit}") || exit 98
  [ "$(git rev-parse HEAD)" = "$want" ] || { echo "HEAD $(git rev-parse HEAD) is not $want"; exit 98; }
  [ -z "$(git status --short --untracked-files=no)" ] || { echo "tracked changes in $WT"; exit 98; }
  echo "worktree $WT HEAD $(git rev-parse HEAD) status-lines=$(git status --short | wc -l)"
  echo "AILANG_FS_SANDBOX unset for both runs; compile cache .ailang/ present: $([ -d .ailang ] && echo yes || echo no)"
  echo "memory.current $(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo '?')"
  uptime
} > "$OUT/meta.txt" 2>&1 || exit $?
cd "$WT" || exit 98

t0=$(date +%s)
timeout 6000 env -u AILANG_FS_SANDBOX make dst > "$OUT/dst.stdout.log" 2>&1; rc_dst=$?
t1=$(date +%s)
cp -f .ailang/dst-last.log "$OUT/dst-last.log" 2>/dev/null
echo "dst rc=$rc_dst seconds=$((t1 - t0)) end $(date -u +%FT%TZ)" >> "$OUT/meta.txt"
git status --short > "$OUT/status-after-dst.txt" 2>&1

# The sweep's FAILED names, one per line (empty when every target passed), from the closing
# summary that scripts/dst/sweep_summary.sh prints.
awk '/^─── make dst / { s = 1 } s && /^  FAILED \(/ { f = 1; next }
     f && /^    [^ ]/ { print $1; next } f { f = 0 }' "$OUT/dst.stdout.log" > "$OUT/dst-failed.txt"
{
  echo "# make dst at $REV: closing summary, make's error lines, corpus_pr's rows"
  echo
  sed -n '/^─── make dst /,/^───────/p' "$OUT/dst.stdout.log"
  echo
  echo "## make errors"
  grep -E '^make(\[[0-9]+\])?: \*\*\*' "$OUT/dst.stdout.log"
  echo
  echo "## the corpus gate's rows and wire witness"
  grep -E '^CORPUSROW |^-- |^  (✓|✗) ' /tmp/corpus_pr.out 2>/dev/null
} > "$OUT/dst-summary.txt"
if [ -r /tmp/corpus_pr.out ] && [ /tmp/corpus_pr.out -nt "$OUT/.start" ]; then
  mask() { sed -E 's/"duration_ms":[0-9]+/"duration_ms":0/g' /tmp/corpus_pr.out; }
  {
    echo "# corpus_pr's output (/tmp/corpus_pr.out) at $REV, with every \"duration_ms\":N masked to 0"
    echo "lines $(mask | wc -l)"
    echo "json_lines $(mask | grep -c '^{')"
    echo "sha256_all_lines $(mask | sha256sum | cut -d' ' -f1)"
    echo "sha256_json_lines $(mask | grep '^{' | sha256sum | cut -d' ' -f1)"
    echo "# mask: sed -E 's/\"duration_ms\":[0-9]+/\"duration_ms\":0/g'"
  } > "$OUT/corpus_pr.wire.sha256"
else
  echo "corpus_pr.out missing or older than this run" > "$OUT/corpus_pr.wire.sha256"
fi

mkdir -p "$OUT/matrix-logs"
timeout 4200 env -u AILANG_FS_SANDBOX make eval_matrix EVAL_MATRIX_ARGS="--logs $OUT/matrix-logs" \
  > "$OUT/matrix.stdout.log" 2>&1; rc_mx=$?
t2=$(date +%s)
cp -f src/eval/journal/testdata/MATRIX.tsv "$OUT/MATRIX.tsv" 2>/dev/null
cp -f "$OUT/matrix-logs/suites.json" "$OUT/matrix-logs/join.tsv" "$OUT/" 2>/dev/null
echo "eval_matrix rc=$rc_mx seconds=$((t2 - t1)) end $(date -u +%FT%TZ)" >> "$OUT/meta.txt"
git status --short > "$OUT/status-after-matrix.txt" 2>&1
echo "memory.current $(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo '?')" >> "$OUT/meta.txt"
uptime >> "$OUT/meta.txt"
echo DONE >> "$OUT/meta.txt"
