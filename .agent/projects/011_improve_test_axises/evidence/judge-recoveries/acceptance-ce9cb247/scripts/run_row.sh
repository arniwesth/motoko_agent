#!/usr/bin/env bash
# Acceptance of ADR-003's rules (011 WI-4): one gate run per id, one edit at a time.
#
#   run_row.sh <id>...        an id of apply_mutant.py, or C-gate for the unmutated tree
#
# For each id: check that every file this acceptance ever edits is at its baseline hash and that
# the scratch worktree is clean; apply the one edit; keep its diff; run `make corpus_judge`; restore
# with `git checkout`; check the hashes and `git status` again. The run's output is make's own:
# every non-wire line, and on red the path of the kept trace, which is deleted here once read.
#
# It scores nothing. `score.py` reads the rows; exit status is recorded and is not a verdict.
set -u
S=${ACCEPT_SCRATCH:-/workspaces/motoko_agent-011-accept-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail src/core/dst_invariants.ail"
TIMEOUT=${ACCEPT_TIMEOUT:-900}
cd "$S" || exit 9

note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
hashes() { sha256sum $FILES; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }

# The baseline hashes are taken once, on a clean tree at the commit handed in, before any edit.
if [ ! -f "$E/base.sha256" ]; then
  [ -z "$(git status --short)" ] || { note "ABORT: scratch worktree not clean before the baseline hashes"; exit 8; }
  [ "$(git rev-parse HEAD)" = "ce9cb247ce4c240679bc46453a146c99bfcb8971" ] || { note "ABORT: scratch HEAD is not ce9cb247"; exit 8; }
  hashes > "$E/base.sha256"
  note "baseline hashes of the five files ever edited written to base.sha256 ($(sha256sum < "$E/base.sha256" | cut -c1-16))"
fi
intact() { [ "$(hashes)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ]; }

for id in "$@"; do
  intact || { note "$id ABORT: a file is not at baseline, or the scratch worktree is not clean, before apply"; exit 8; }
  d="$E/runs/$id"; rm -rf "$d"; mkdir -p "$d"
  if [ "$id" != "C-gate" ] && [ "${id#C-gate-}" = "$id" ]; then
    # An id B<n> is a row of the blind reviewer's file, applied from that file as it stands.
    if [ "${id#B}" != "$id" ]; then
      python3 "$E/scripts/apply_mutant.py" apply-blind "$E/blind/blind-mutants.tsv" "$id" "$S" > "$d/apply.log" 2>&1
    else
      python3 "$E/scripts/apply_mutant.py" apply "$id" "$S" > "$d/apply.log" 2>&1
    fi \
      || { note "$id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $FILES; continue; }
    git diff -U0 -- $FILES > "$d/mutant.diff" 2>&1
    [ "$(git status --short | wc -l)" = "1" ] || { note "$id ABORT: the edit touched $(git status --short | wc -l) files, expected 1"; git checkout -- $FILES; exit 8; }
  else
    echo "no edit" > "$d/apply.log"
  fi
  w0=$(date +%s); u0=$(up)
  timeout "$TIMEOUT" make corpus_judge > "$d/gate.out" 2>&1 < /dev/null
  rc=$?
  w1=$(date +%s); u1=$(up)
  # On red the recipe keeps its output file and prints the path. gate.out already holds every
  # non-wire line of it; count the wire lines, then delete it.
  kept=$(sed -n 's/^  trace  *\(\/[^ ]*\) (kept.*/\1/p' "$d/gate.out" | head -1)
  wire="-"
  if [ -n "$kept" ] && [ -f "$kept" ]; then wire=$(grep -c '^{' "$kept"); rm -f "$kept"; fi
  echo "rc=$rc wall_secs=$((w1 - w0)) uptime_secs=$((u1 - u0)) judge_rows=$(grep -c '^JUDGE ' "$d/gate.out") judgerows=$(grep -c '^JUDGEROW ' "$d/gate.out") red=$(grep -c '^JUDGE .* RED ' "$d/gate.out") wire_lines_in_kept_trace=$wire load=$(cut -d' ' -f1-3 /proc/loadavg)" > "$d/rc"
  git checkout -- $FILES
  if intact; then note "$id restored OK; $(cat "$d/apply.log" | head -1); $(cat "$d/rc")"
  else note "$id RESTORE FAILED"; exit 7; fi
done
note "run_row.sh $* done; $(intact && echo 'INTEGRITY: the five files at baseline, scratch worktree clean' || echo 'INTEGRITY: FAIL')"
