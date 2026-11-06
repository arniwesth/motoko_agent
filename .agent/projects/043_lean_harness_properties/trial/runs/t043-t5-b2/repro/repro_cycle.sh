#!/usr/bin/env bash
# P5.3 on a parent cycle: `path_up` returns [] instead of stopping at the first repeated id.
# Exit 1 when the defect is present, 0 when absent.
#
#  (a) The real `path_up` on two entry lists whose start id names an entry:
#        [a(parent a)]            from a   -- D4 rule 1 path: [a]
#        [h(parent m), m(parent h)] from m -- D4 rule 1 path: [h, m]
#      (Lean: bug_P5_3_cycle, bug_P5_3_header_cycle.)
#  (b) Its effect on the real resume fold: a valid journal (real writer twin), and the same
#      journal with ONLY the header's parent_id changed to the leaf's id. Climbing from the
#      leaf reaches the header and then the leaf again; stopped there, the path is the whole
#      journal, header first. The real fold refuses it with `header`.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
defect=0
while IFS= read -r line; do
  echo "path_up: $line"
  n="${line##*|}"
  [[ "$n" == "0" ]] && { echo "  -> DEFECT: start id names an entry, result is []"; defect=1; }
done < <(path_up_cases 'a>a|a|0' 'h>m;m>h|m|0')

write_base > "$WORK/base.jsonl"
leaf=$(tail -1 "$WORK/base.jsonl" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["id"])')
python3 - "$WORK/base.jsonl" "$WORK/cycle.jsonl" "$leaf" <<'PY'
import json, sys
src, dst, leaf = sys.argv[1:]
lines = open(src).read().splitlines()
h = json.loads(lines[0]); assert h["type"] == "header" and h["parent_id"] == ""
h["parent_id"] = leaf
lines[0] = json.dumps(h, separators=(",", ":"))
open(dst, "w").write("\n".join(lines) + "\n")
PY
b=$(fold_file "$WORK/base.jsonl"); c=$(fold_file "$WORK/cycle.jsonl")
echo "fold, valid journal:                       $b"
echo "fold, header.parent_id = leaf ($leaf):       $c"
[[ "$b" == accept* ]] || { echo "control did not fold; inconclusive"; exit 2; }
[[ "$c" == "refuse|header|"* ]] && { echo "  -> DEFECT: the cycle's path is discarded, the fold finds no header"; defect=1; }
exit $defect
