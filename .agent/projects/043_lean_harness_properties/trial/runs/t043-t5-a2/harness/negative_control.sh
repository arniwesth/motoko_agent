#!/usr/bin/env bash
# negative_control.sh — the repros must exit 0 when the defect is absent. The tree may not be
# edited, so this builds a CONTROL tree under out/runs/control_tree holding copies of the two
# modules expose.sh reads, with ONE change to the core: path_up's cycle arm `then []` restored
# to `then acc`, which is the body the eval twin's SOURCE pin hashes
# (reader.ail:1225, sha256:db222e4c…; checked below). Then:
#   r1 and r2 against the control must exit 0, and against the tree must exit 1;
#   r3 is not touched by this fix (the empty-id arm is the twin's too), so it stays 1 on both;
#   a second control also changes `if id == "" then acc` to look the id up first, for r3.
# For r2 the fold is the control core's (gen/core_journal_exposed, via a rewritten import).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; out="$(cd "$here/.." && pwd)"; tree="$(cd "$out/../tree" && pwd)"
ct="$out/runs/control_tree"; ct2="$out/runs/control_tree2"
for d in "$ct" "$ct2"; do mkdir -p "$d/src/core" "$d/src/eval/journal"; cp "$tree/src/eval/journal/reader.ail" "$d/src/eval/journal/"; done
sed 's/^  else if contains_string(seen, id) then \[\]$/  else if contains_string(seen, id) then acc/' \
  "$tree/src/core/journal.ail" > "$ct/src/core/journal.ail"
[[ $(diff "$tree/src/core/journal.ail" "$ct/src/core/journal.ail" | grep -c '^>') -eq 1 ]] || { echo "control patch did not apply"; exit 2; }
python3 -I - "$ct/src/core/journal.ail" <<'PY' || exit 2
import sys, hashlib
b = open(sys.argv[1], 'rb').read(); i = b.find(b'pure func path_up('); j = b.find(b'\n}\n', i) + 3
h = hashlib.sha256(b[i:j]).hexdigest()
print("control path_up sha256", h, "== twin pin" if h.startswith("db222e4c") else "!= twin pin")
sys.exit(0 if h.startswith("db222e4c") else 1)
PY
# control 2: the empty-id arm as well (look the id up before treating "" as the root marker)
python3 -I - "$ct/src/core/journal.ail" "$ct2/src/core/journal.ail" <<'PY' || exit 2
import sys
s = open(sys.argv[1]).read()
old = '''  if id == "" then acc
  else if contains_string(seen, id) then acc
  else match find_entry(es, id) {
    None => acc,'''
new = '''  if contains_string(seen, id) then acc
  else match find_entry(es, id) {
    None => acc,'''
assert s.count(old) == 1
open(sys.argv[2], 'w').write(s.replace(old, new))
PY
# the fold-level harness against the control core
sed 's#^import src/core/journal (#import gen/core_journal_exposed (#; s#^module harness/fold_cycle$#module harness/fold_cycle_control#' \
  "$here/fold_cycle.ail" > "$here/fold_cycle_control.ail"
cd "$tree"
run() { local label="$1" want="$2"; shift 2; "$@" > /dev/null 2>&1; local rc=$?
  printf '%-48s rc=%d want=%d %s\n' "$label" "$rc" "$want" "$([[ $rc -eq $want ]] && echo ok || echo MISMATCH)"; [[ $rc -eq $want ]]; }
fail=0
run "r1 on tree"                    1 bash "$out/repro/r1_cycle_empty_path.sh" || fail=1
run "r1 on control (then acc)"      0 env TREE="$ct" bash "$out/repro/r1_cycle_empty_path.sh" || fail=1
run "r2 on tree"                    1 bash "$out/repro/r2_fold_header_refusal.sh" || fail=1
run "r2 on control (then acc)"      0 env TREE="$ct" FOLD_SRC=harness/fold_cycle_control.ail bash "$out/repro/r2_fold_header_refusal.sh" || fail=1
run "r3 on tree"                    1 bash "$out/repro/r3_empty_start_id.sh" || fail=1
run "r3 on control (then acc)"      1 env TREE="$ct" bash "$out/repro/r3_empty_start_id.sh" || fail=1
run "r3 on control 2 (\"\" looked up)" 0 env TREE="$ct2" bash "$out/repro/r3_empty_start_id.sh" || fail=1
"$here/expose.sh" "$tree" "$out"   # leave gen/ built from the real tree
exit $fail
