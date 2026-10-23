#!/usr/bin/env bash
# 034 PLAN-001 W1.1: predict which test_candidate.py rows of `make eval_matrix` move when W1
# edits ADR-004's protected symbols in src/core/ports.ail.
#
#   predict_matrix.sh <commit> <out-dir>
#
# Clones the repository at <commit> twice into <out-dir>. The second clone gets one commit that
# widens the four types W1.2 and W1.3 widen (ScriptedTool, ToolFailed's record, WorldState,
# ExecutionProgram) by one field each. The check is lexical, so the widening need not compile.
# Runs scripts/eval/test_candidate.py in both with EVAL_CANDIDATE_LIVE=0 and EVAL_MATRIX_OBS
# set, and prints every test whose observed (verdict, first finding, position) differs, with
# the MATRIX.expected.tsv rows it feeds. Live rows are skipped by EVAL_CANDIDATE_LIVE=0; the
# record says which live rows are inferred instead. About 5 minutes on 8 cores.
set -euo pipefail
commit=$1; out=$2
here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
mkdir -p "$out"; out=$(cd "$out" && pwd)
rm -rf "$out/base" "$out/w1"
git clone -q --no-hardlinks "$repo" "$out/base"
git -C "$out/base" checkout -q "$commit"
git clone -q "$out/base" "$out/w1"
git -C "$out/w1" checkout -q "$commit"
python3 - "$out/w1" <<'EOF'
import sys
root = sys.argv[1]
def edit(path, old, new):
    p = f"{root}/{path}"; s = open(p).read()
    assert s.count(old) == 1, (path, old)
    open(p, "w").write(s.replace(old, new))
edit("src/core/ports.ail", "  content: string,\n  exit_code: int\n}\n\n-- D1's typed tool request",
     "  content: string,\n  exit_code: int,\n  w1_applied: bool\n}\n\n-- D1's typed tool request")
edit("src/core/ports.ail", "| ToolFailed({ tool_call_id: string, code: string, message: string })",
     "| ToolFailed({ tool_call_id: string, code: string, message: string, w1_stage: string })")
edit("src/core/ports.ail", "export type WorldState = {\n  script: [ScriptedStep],",
     "export type WorldState = {\n  w1_effect_log: [int],\n  script: [ScriptedStep],")
edit("src/core/dst_program.ail", "  interactions: [Interaction]\n}",
     "  interactions: [Interaction],\n  w1_applied_faults: [int]\n}")
EOF
git -C "$out/w1" -c user.name=sim -c user.email=sim@invalid commit -qam "sim: W1-shaped type widening"
for t in base w1; do
  rm -f "$out/obs_$t.tsv"
  (cd "$out/$t" && EVAL_CANDIDATE_LIVE=0 EVAL_MATRIX_OBS="$out/obs_$t.tsv" \
     python3 -m pytest -q -p no:cacheprovider scripts/eval/test_candidate.py > "$out/pytest_$t.log" 2>&1) || true
  tail -1 "$out/pytest_$t.log"
done
python3 - "$out" "$out/base/src/eval/journal/testdata/MATRIX.expected.tsv" <<'EOF'
import sys
out, expected = sys.argv[1], sys.argv[2]
def load(p):
    d = {}
    for line in open(p):
        a = line.rstrip("\n").split("\t"); d[a[0]] = tuple(a[1:3])
    return d
b, w = load(f"{out}/obs_base.tsv"), load(f"{out}/obs_w1.tsv")
rows = {}
for i, line in enumerate(open(expected), 1):
    a = line.rstrip("\n").split("\t")
    if len(a) > 3: rows.setdefault(a[1], []).append(f"{i}:{a[0]} expects {a[2]} {a[3]}")
for k in sorted(set(b) | set(w)):
    if b.get(k) != w.get(k):
        print(f"{k}\n    base {b.get(k)}\n    w1   {w.get(k)}\n    rows {rows.get(k)}")
EOF
