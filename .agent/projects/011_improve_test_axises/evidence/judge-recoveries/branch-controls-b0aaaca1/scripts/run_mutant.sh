#!/usr/bin/env bash
# One mutant, applied to a clean tree, the gate run once, the source restored.
#   run_mutant.sh B2|B3 <output file>
# The edits are acceptance's blind rows B2 and B3, text from
# ../../acceptance-ce9cb247/blind/blind-mutants.tsv. The gate runs under a
# timeout: B3 does not end on a control whose script has no closing error.
set -euo pipefail
id=$1; out=$2
test -z "$(git status --short -- src/core)" || { echo "src/core is not clean"; exit 3; }
python3 -I - "$id" <<'PY'
import sys
which = sys.argv[1]
if which == "B2":
    p, anchor = "src/core/tool_phase.ail", None
    old = "dispatch_tool_entries_with_builtin(ports, executed.next_state, rt,"
    new = "dispatch_tool_entries_with_builtin(ports, world, rt,"
elif which == "B3":
    p, anchor = "src/core/session.ail", "func c2_dp7_rejected_state("
    old, new = "step_idx: step_idx + 1,", "step_idx: step_idx,"
else:
    sys.exit("unknown mutant " + which)
s = open(p).read()
a = s.index(anchor) if anchor else 0
i = s.index(old, a)
assert anchor is None and s.count(old) == 1 or anchor is not None and i - a < 2500
open(p, "w").write(s[:i] + new + s[i + len(old):])
PY
git diff -U0 -- src/core | grep -E '^[-+] ' > "$out.edit" || true
rc=0; start=$(date +%s)
timeout 600 make corpus_judge > "$out" 2>&1 || rc=$?
echo "rc=$rc seconds=$(( $(date +%s) - start ))" > "$out.rc"
git checkout -- src/core
test -z "$(git status --short -- src/core)" || { echo "restore failed"; exit 4; }
cat "$out.rc"
