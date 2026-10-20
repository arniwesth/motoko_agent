#!/usr/bin/env bash
# Acceptance of 034 ADR-001 §2's P1-P3 by mutant (034 PLAN-001 W2.3): both gates per id, one edit
# at a time, in this worktree.
#
#   run_row.sh <id>...      an id of apply_mutant.py, or C-<name> for the unmutated tree
#
# For each id: check that the one file this acceptance ever edits is at its baseline hash and that
# no tracked file is modified; apply the one edit; keep its diff; run `make corpus_judge` and
# `make applied_twin` side by side on the same tree; restore with `git checkout --`; check the hash
# and `git status` again. The kept trace or output a red recipe leaves in $TMPDIR is counted and
# deleted. It scores nothing: `score.py` reads the rows, and exit status is not a verdict.
set -u
cd "$(git rev-parse --show-toplevel)"
E=.agent/projects/034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274
LOG="$E/sequence.log"
F=src/core/tool_phase.ail
TIMEOUT=${ACCEPT_TIMEOUT:-900}

note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
# The baseline is the committed blob, written once to base.sha256 on a clean tree.
if [ ! -f "$E/base.sha256" ]; then
  [ -z "$(git status --short --untracked-files=no)" ] || { note "ABORT: tracked tree not clean before the baseline hash"; exit 8; }
  sha256sum $F > "$E/base.sha256"
  note "baseline hash of the one file ever edited written to base.sha256: $(cut -c1-16 "$E/base.sha256") ($F, HEAD $(git rev-parse --short HEAD))"
fi
intact() { sha256sum -c --quiet "$E/base.sha256" >/dev/null 2>&1 && [ -z "$(git status --short --untracked-files=no)" ]; }

kept_path() { sed -n "s/^  $2  *\(\/[^ ]*\) (kept.*/\1/p" "$1" | head -1; }

for id in "$@"; do
  intact || { note "$id ABORT: $F not at baseline, or a tracked file is modified, before apply"; exit 8; }
  d="$E/runs/$id"; rm -rf "$d"; mkdir -p "$d"
  if [ "${id#C-}" = "$id" ]; then
    python3 "$E/scripts/apply_mutant.py" apply "$id" . > "$d/apply.log" 2>&1 \
      || { note "$id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $F; continue; }
    git diff -U0 -- $F > "$d/mutant.diff"
    [ "$(git status --short --untracked-files=no | wc -l)" = "1" ] || { note "$id ABORT: the edit touched more than one file"; git checkout -- $F; exit 8; }
  else
    echo "no edit" > "$d/apply.log"
  fi
  w0=$(date +%s)
  ( s=$(date +%s); timeout "$TIMEOUT" make corpus_judge > "$d/judge.out" 2>&1 < /dev/null; echo "rc=$? wall_secs=$(( $(date +%s) - s ))" > "$d/judge.rc" ) &
  ( s=$(date +%s); timeout "$TIMEOUT" make applied_twin > "$d/twin.out" 2>&1 < /dev/null; echo "rc=$? wall_secs=$(( $(date +%s) - s ))" > "$d/twin.rc" ) &
  wait
  w1=$(date +%s)
  kj=$(kept_path "$d/judge.out" trace); wire="-"
  if [ -n "$kj" ] && [ -f "$kj" ]; then wire=$(grep -c '^{' "$kj"); rm -f "$kj"; fi
  kt=$(kept_path "$d/twin.out" output)
  if [ -n "$kt" ] && [ -f "$kt" ]; then rm -f "$kt"; fi
  echo "judge $(cat "$d/judge.rc") judgerows=$(grep -c '^JUDGEROW ' "$d/judge.out") controlrows=$(grep -c '^CONTROLROW ' "$d/judge.out") judge_red=$(grep -c '^JUDGE .* RED ' "$d/judge.out") control_red=$(grep -c '^CONTROL .* RED ' "$d/judge.out") wire_lines_in_kept_trace=$wire; twin $(cat "$d/twin.rc") $(grep -E '^COUNT ' "$d/twin.out" | tail -1); wall_secs=$((w1 - w0)) load=$(cut -d' ' -f1-3 /proc/loadavg)" > "$d/rc"
  git checkout -- $F
  if intact; then note "$id restored OK (git checkout -- $F); $(head -1 "$d/apply.log"); $(cat "$d/rc")"
  else note "$id RESTORE FAILED"; exit 7; fi
done
note "run_row.sh $* done; $(intact && echo "INTEGRITY: $F at baseline, no tracked file modified" || echo 'INTEGRITY: FAIL')"
