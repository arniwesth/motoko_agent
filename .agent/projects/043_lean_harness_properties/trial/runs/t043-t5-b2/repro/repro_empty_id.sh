#!/usr/bin/env bash
# P5.3 with the empty id: an entry may have id "" (journal_entry_of_json accepts it), and
# `path_up` tests `id == ""` first, as the root sentinel, so a start id "" that names an entry
# yields []. Exit 1 when the defect is present, 0 when absent.
#
#  (a) The real `path_up` on [""(parent "")] from "" (Lean: bug_P5_3_empty_id).
#  (b) The real resume fold: the valid journal with ONLY the last line's id changed to "",
#      against the same change to an unused id "0099" as the control. journal_leaf returns "",
#      the path is [], and the fold reports `header`, though the header is in the file and the
#      leaf entry's parent chain reaches it.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
defect=0
while IFS= read -r line; do
  echo "path_up: $line"
  n="${line##*|}"
  [[ "$n" == "0" ]] && { echo "  -> DEFECT: start id \"\" names an entry, result is []"; defect=1; }
done < <(path_up_cases '>||0')

write_base > "$WORK/base.jsonl"
for newid in "" "0099"; do
python3 - "$WORK/base.jsonl" "$WORK/j_$newid.jsonl" "$newid" <<'PY'
import json, sys
src, dst, newid = sys.argv[1:]
lines = open(src).read().splitlines()
l = json.loads(lines[-1]); l["id"] = newid
lines[-1] = json.dumps(l, separators=(",", ":"))
open(dst, "w").write("\n".join(lines) + "\n")
PY
done
c=$(fold_file "$WORK/j_0099.jsonl"); e=$(fold_file "$WORK/j_.jsonl")
echo "fold, last id \"0099\" (control): $c"
echo "fold, last id \"\":               $e"
[[ "$c" == accept* ]] || { echo "control did not fold; inconclusive"; exit 2; }
[[ "$e" == "refuse|header|"* ]] && { echo "  -> DEFECT: the leaf named \"\" is never looked up; the fold reports no header"; defect=1; }
exit $defect
