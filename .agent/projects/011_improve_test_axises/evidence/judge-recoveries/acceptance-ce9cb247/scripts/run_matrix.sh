#!/usr/bin/env bash
# Acceptance of ADR-003's rules (011 WI-4), precondition 1 (ruling 14): `make eval_matrix` at the
# commit handed in, on the unedited scratch worktree, compared row for row with the last tree
# without the two rules, `../baseline-59d5cbb9`.
#
#   run_matrix.sh <logs-dir>      a directory outside every worktree; it receives the per-suite
#                                 logs, which hold wires and are not committed
#
# Heavy: it takes /tmp/motoko-011-heavy.lock for the matrix alone. Nothing else of this
# acceptance runs beside it; the matrix refuses its live suites above 12 GiB of memory.current.
set -u
S=${ACCEPT_SCRATCH:-/workspaces/motoko_agent-011-accept-scratch}
E="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS=${1:?usage: run_matrix.sh <logs-dir>}
LOG="$E/sequence.log"
FILES="src/core/session.ail src/core/step_machine.ail src/core/recovery.ail src/core/tool_phase.ail src/core/dst_invariants.ail"
M="$E/matrix"; mkdir -p "$M" "$LOGS"
cd "$S" || exit 9
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
intact() { [ "$(sha256sum $FILES)" = "$(cat "$E/base.sha256")" ] && [ -z "$(git status --short)" ]; }
mem() { echo "cgroup_current=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"; }
up() { cut -d' ' -f1 /proc/uptime | cut -d. -f1; }
intact || { note "MX ABORT: scratch worktree is not at baseline"; exit 8; }
[ ! -e src/eval/journal/testdata/MATRIX.tsv ] || { note "MX ABORT: a MATRIX.tsv is already in testdata"; exit 8; }

note "MX waiting for /tmp/motoko-011-heavy.lock; head=$(git rev-parse --short HEAD) invariants=$(sha256sum src/core/dst_invariants.ail | cut -c1-16) $(mem)"
flock -x /tmp/motoko-011-heavy.lock bash -c '
  echo "$(date +%s) $(cut -d" " -f1 /proc/uptime | cut -d. -f1)" > "$1/started"
  timeout 4200 make eval_matrix EVAL_MATRIX_ARGS="--logs $2" > "$1/matrix.stdout.log" 2>&1 < /dev/null
  echo $? > "$1/rc"
  echo "$(date +%s) $(cut -d" " -f1 /proc/uptime | cut -d. -f1)" > "$1/ended"
' _ "$M" "$LOGS"
read -r w0 u0 < "$M/started"; read -r w1 u1 < "$M/ended"
note "MX make eval_matrix rc=$(cat "$M/rc") wall_secs=$((w1 - w0)) uptime_secs=$((u1 - u0)) $(mem) load=$(cut -d' ' -f1-3 /proc/loadavg)"

# The generated MATRIX.tsv goes beside the logs and into the evidence, and out of the evaluator's paths.
if [ -f src/eval/journal/testdata/MATRIX.tsv ]; then
  cp -f src/eval/journal/testdata/MATRIX.tsv "$LOGS/MATRIX.tsv"
  rm -f src/eval/journal/testdata/MATRIX.tsv
fi
for f in MATRIX.tsv suites.json join.tsv; do cp -f "$LOGS/$f" "$M/$f" 2>/dev/null || note "MX: $f missing from the logs directory"; done
python3 "$E/../compare_matrix.py" "$E/../baseline-59d5cbb9" "$LOGS" > "$M/compare.txt" 2>&1
echo "compare_matrix.py exit=$?" >> "$M/compare.txt"
python3 - "$E/../baseline-59d5cbb9/suites.json" "$M/suites.json" > "$M/live-suites.txt" 2>&1 <<'PY'
import json, sys
live = ["src/eval/journal/witness_live_test.ail", "src/eval/journal/candidate_checks_live_test.ail", "src/eval/journal/admission_live_test.ail"]
base = {s["suite"]: s["exit"] for s in json.load(open(sys.argv[1]))}
here = {s["suite"]: s["exit"] for s in json.load(open(sys.argv[2]))}
print("# the three suites that evaluate real runs (ruling 14): exit at ce9cb247, and in baseline-59d5cbb9")
for s in live:
    print(f"{s} exit={here.get(s, 'absent')} baseline_exit={base.get(s, 'absent')}")
print("# every suite with a non-zero exit at ce9cb247")
for s, e in here.items():
    if e != 0:
        print(f"{s} nonzero={e} baseline={base.get(s, 'absent')}")
PY
note "MX $(grep '^VERDICT' "$M/compare.txt" || echo 'VERDICT: none printed'); $(grep '^compare_matrix.py exit' "$M/compare.txt")"
note "run_matrix.sh done; $(intact && echo 'INTEGRITY: the five files at baseline, scratch worktree clean' || echo "INTEGRITY: FAIL: $(git status --short | head -5 | tr '\n' ' ')")"
