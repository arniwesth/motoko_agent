#!/usr/bin/env bash
# 039 random-mutant pilot, follow-up F1, READ BY HAND: run one DST program under one probe and KEEP
# its whole output.
#
#   run_program.sh <id> <program.ail>
#
# Why: `ledger_parity` and `world_framed_wire` both run scripts/dst/ledger_parity_dst.ail into a
# mktemp file, print only its `  ✗` rows on failure, and delete the file on exit. A runtime error
# (`Error: execution failed: RT001: ...`) is therefore never shown and never kept, so the F1 sweep
# cannot tell whether a probe fired inside that program. This runs the same program with the same
# command line as both scripts (run_ledger_parity_wire.sh:52, run_world_framed_wire.sh:281) and
# keeps every non-wire line.
#
# Apply, integrity check and restore are run_gate.sh's, unchanged: the four files must be at
# base.sha256 and the scratch clean at dd8a12f1 before the edit and after the restore.
# Output goes to runs/program/<program basename>/<id>/: out.txt, mutant.diff, apply.log, rc.
set -u
S=${PILOT_SCRATCH:-/workspaces/motoko_agent-039-pilot-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail"
id=$1; prog=$2
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ] && [ "$(git rev-parse HEAD)" = "dd8a12f1ec2f0f302b6619df9a02c1c4ea9b7716" ]; }

intact || { note "program $prog $id ABORT: the scratch is not at base before apply"; exit 8; }
d="$E/runs/program/$(basename "$prog" .ail)/$id"; rm -rf "$d"; mkdir -p "$d"
python3 "$E/scripts/fixed_edits.py" apply "$id" "$S" > "$d/apply.log" 2>&1 \
  || { note "program $prog $id APPLY FAILED: $(cat "$d/apply.log")"; git checkout -- $FILES; exit 8; }
git diff -U0 -- $FILES > "$d/mutant.diff"
[ "$(git status --short | wc -l)" = "1" ] || { note "program $prog $id ABORT: the edit touched $(git status --short | wc -l) files, expected 1"; git checkout -- $FILES; exit 8; }
w0=$(date +%s)
timeout 1800 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main "$prog" < /dev/null > "$d/raw.txt" 2>&1
rc=$?
w1=$(date +%s)
wire=$(grep -c '^{' "$d/raw.txt"); grep -v '^{' "$d/raw.txt" > "$d/out.txt"; rm -f "$d/raw.txt"
echo "rc=$rc wall_secs=$((w1 - w0)) wire_lines=$wire" > "$d/rc"
git checkout -- $FILES
if intact; then note "program $prog $id restored OK; $(head -1 "$d/apply.log"); $(cat "$d/rc"); INTEGRITY: the four files at base.sha256, scratch clean at dd8a12f1"
else note "program $prog $id RESTORE FAILED"; exit 7; fi
