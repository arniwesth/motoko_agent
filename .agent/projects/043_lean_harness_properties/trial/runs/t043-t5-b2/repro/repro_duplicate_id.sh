#!/usr/bin/env bash
# X-1 (observation): ids are looked up by FIRST match in file order (`find_entry`), while the
# leaf is the LAST line's id (`journal_leaf`). Nothing refuses a repeated id, so a journal
# whose last line repeats an earlier id folds a path that does not end at its last line.
# Exit 1 when the fold ACCEPTS such a journal (defect present), 0 when it refuses it.
#
#  (a) The real `path_up` on [a(no parent) seq 0, a(no parent) seq 1] from a: [seq 0]
#      (Lean: obs_duplicate_id_first_wins).
#  (b) The real resume fold: the valid journal with ONLY the last line's id (the
#      `run_finished`, "0006") changed to "0004", the id of the assistant `history_appended`.
#      The fold accepts, climbs from the earlier "0004", drops the `state_delta` and the
#      `run_finished`, and reports a different last boundary.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
path_up_cases 'a>;a>|a|0' | sed 's/^/path_up: /'

write_base > "$WORK/base.jsonl"
python3 - "$WORK/base.jsonl" "$WORK/dup.jsonl" <<'PY'
import json, sys
src, dst = sys.argv[1:]
lines = open(src).read().splitlines()
l = json.loads(lines[-1]); assert l["type"] == "run_finished"
l["id"] = json.loads(lines[4])["id"]
lines[-1] = json.dumps(l, separators=(",", ":"))
open(dst, "w").write("\n".join(lines) + "\n")
PY
b=$(fold_file "$WORK/base.jsonl"); d=$(fold_file "$WORK/dup.jsonl")
echo "fold, valid journal:                  $b"
echo "fold, last line's id repeats line 4:  $d"
[[ "$b" == accept* ]] || { echo "control did not fold; inconclusive"; exit 2; }
[[ "$d" == accept* ]] && { echo "  -> accepted: the folded path ends at line 4, not at the journal's last line"; exit 1; }
exit 0
