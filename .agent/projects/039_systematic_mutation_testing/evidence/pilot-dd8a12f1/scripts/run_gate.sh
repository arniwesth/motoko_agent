#!/usr/bin/env bash
# 039 random-mutant pilot: one gate run per id, one edit at a time, in the scratch worktree.
#
#   run_gate.sh <target> <id>...
#
#   <target>  corpus_judge (tier 1, tier 2) or any other make target (tier 3, tier 4: dst)
#   <id>      C-<name>   no edit (the unmutated tree)
#             mNN        drawn mutant NN: its candidate id is read from draw-checked.tsv
#             other      an id of fixed_edits.py (K0, KB-*, X-*)
#
# For each id: the four files must be at base.sha256 and the scratch clean; apply the one edit;
# keep its diff; run `timeout make <target>`; restore with `git checkout`; check the hashes and
# `git status` again, and stop on any difference. Output goes to runs/<target>/<id>/: out.txt
# (every line make printed, wire lines removed), mutant.diff, apply.log, rc. It scores nothing.
set -u
S=${PILOT_SCRATCH:-/workspaces/motoko_agent-039-pilot-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail"
TARGET=$1; shift
case "$TARGET" in
  corpus_judge) TIMEOUT=${PILOT_TIMEOUT:-900} ;;
  dst) TIMEOUT=${PILOT_TIMEOUT:-3600} ;;
  *) TIMEOUT=${PILOT_TIMEOUT:-1800} ;;
esac
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ] && [ "$(git rev-parse HEAD)" = "dd8a12f1ec2f0f302b6619df9a02c1c4ea9b7716" ]; }

for id in "$@"; do
  intact || { note "$TARGET $id ABORT: the scratch is not at base before apply"; exit 8; }
  d="$E/runs/$TARGET/$id"; rm -rf "$d"; mkdir -p "$d"
  case "$id" in
    C-*) echo "no edit" > "$d/apply.log" ;;
    m[0-9][0-9])
      cid=$(awk -F'\t' -v m="$id" '$8==m {print $4}' "$E/draw-checked.tsv")
      [ -n "$cid" ] || { note "$TARGET $id ABORT: no such mutant in draw-checked.tsv"; exit 8; }
      python3 "$E/scripts/mutator.py" apply "$cid" "$S" > "$d/apply.log" 2>&1 \
        || { note "$TARGET $id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $FILES; exit 8; } ;;
    *)
      python3 "$E/scripts/fixed_edits.py" apply "$id" "$S" > "$d/apply.log" 2>&1 \
        || { note "$TARGET $id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $FILES; exit 8; } ;;
  esac
  if [ "${id#C-}" = "$id" ]; then
    git diff -U0 -- $FILES > "$d/mutant.diff"
    [ "$(git status --short | wc -l)" = "1" ] || { note "$TARGET $id ABORT: the edit touched $(git status --short | wc -l) files, expected 1"; git checkout -- $FILES; exit 8; }
  fi
  l0=$(cut -d' ' -f1-3 /proc/loadavg); w0=$(date +%s); u0=$(up)
  timeout "$TIMEOUT" make "$TARGET" > "$d/raw.txt" 2>&1 < /dev/null
  rc=$?
  w1=$(date +%s); u1=$(up)
  # A red corpus_judge keeps its output file and prints the path; count its wire lines, then delete it.
  kept=$(sed -n 's/^  trace  *\(\/[^ ]*\) (kept.*/\1/p' "$d/raw.txt" | head -1)
  wire="-"
  if [ -n "$kept" ] && [ -f "$kept" ]; then wire=$(grep -c '^{' "$kept"); rm -f "$kept"; fi
  grep -v '^{' "$d/raw.txt" > "$d/out.txt"; rm -f "$d/raw.txt"
  # A4: corpus_pr prints only its last 40 lines on red (ADR-003 Not decided item 7), which hides the
  # failing row. Its recipe writes the whole run to /tmp/corpus_pr.out; keep its non-wire lines.
  if [ "$TARGET" = "corpus_pr" ] && [ -f /tmp/corpus_pr.out ]; then grep -v '^{' /tmp/corpus_pr.out > "$d/full.txt"; fi
  echo "rc=$rc wall_secs=$((w1 - w0)) uptime_secs=$((u1 - u0)) judgerows=$(grep -c '^JUDGEROW ' "$d/out.txt") red_judge=$(grep -c '^JUDGE [^ ]* [^ ]* RED' "$d/out.txt") red_control=$(grep -c '^CONTROL [^ ]* [^ ]* RED' "$d/out.txt") wire_lines_in_kept_trace=$wire load_before=$l0 load_after=$(cut -d' ' -f1-3 /proc/loadavg)" > "$d/rc"
  git checkout -- $FILES
  if intact; then note "$TARGET $id restored OK; $(head -1 "$d/apply.log"); $(cat "$d/rc")"
  else note "$TARGET $id RESTORE FAILED"; exit 7; fi
done
note "run_gate.sh $TARGET $* done; $(intact && echo 'INTEGRITY: the four files at base.sha256, scratch clean at dd8a12f1' || echo 'INTEGRITY: FAIL')"
