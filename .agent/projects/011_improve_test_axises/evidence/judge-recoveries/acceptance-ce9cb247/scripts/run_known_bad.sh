#!/usr/bin/env bash
# Acceptance of ADR-003's rules (011 WI-4), precondition 1: the two known-bad controls, so that
# the matrix's IDENTICAL is not the answer to everything.
#
#   run_known_bad.sh <full-logs-dir> KB-D2 KB-D3
#
# Each is one edit to src/core/dst_invariants.ail in the scratch worktree (apply_mutant.py), then
# `witness_live_test.ail` and `candidate_checks_live_test.ail` run as the spike's control6.sh ran
# them, which is also how `candidate.py matrix` runs a `*_live_test.ail` suite, then restore.
# The full logs hold wires and go to <full-logs-dir>; the evidence keeps their non-wire lines.
set -u
S=${ACCEPT_SCRATCH:-/workspaces/motoko_agent-011-accept-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FULL=${1:?usage: run_known_bad.sh <full-logs-dir> <id>...}; shift
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail src/core/dst_invariants.ail"
CAPS=IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ]; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }

for id in "$@"; do
  intact || { note "$id ABORT: scratch worktree is not at baseline before apply"; exit 8; }
  d="$E/known-bad/$id"; rm -rf "$d"; mkdir -p "$d" "$FULL/$id"
  python3 "$E/scripts/apply_mutant.py" apply "$id" "$S" > "$d/apply.log" 2>&1 \
    || { note "$id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $FILES; exit 8; }
  git diff -U0 -- $FILES > "$d/mutant.diff" 2>&1
  : > "$d/rc"
  for f in witness_live_test candidate_checks_live_test; do
    w0=$(date +%s); u0=$(up)
    timeout 1800 ailang run --caps $CAPS --ai-stub --entry main src/eval/journal/$f.ail < /dev/null > "$FULL/$id/$f.log" 2>&1
    rc=$?
    echo "$f rc=$rc wall_secs=$(( $(date +%s) - w0 )) uptime_secs=$(( $(up) - u0 ))" >> "$d/rc"
    grep -v '^{' "$FULL/$id/$f.log" > "$d/$f.log"
  done
  git checkout -- $FILES
  if intact; then note "$id restored OK; $(head -1 "$d/apply.log"); $(tr '\n' ';' < "$d/rc")"
  else note "$id RESTORE FAILED"; exit 7; fi
done
note "run_known_bad.sh $* done; $(intact && echo 'INTEGRITY: the five files at baseline, scratch worktree clean' || echo 'INTEGRITY: FAIL')"
