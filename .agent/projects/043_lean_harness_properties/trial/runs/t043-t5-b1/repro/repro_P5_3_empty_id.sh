#!/usr/bin/env bash
# B1-T5-3. P5.3 on the real `path_up` (export-only shim): the start id "" names an entry
# (find_entry finds it), and path_up returns [] from its `id == ""` branch.
# Exit 1 when the defect is present, 0 when absent, 2 when the harness itself is broken.
source "$(dirname "$0")/_common.sh"
out=$(run_harness shim path_up_direct.ail); echo "$out"
echo "$out" | grep -qx 'control_chain|found seq 2|path_up=\[0,1,2\]' || { echo "HARNESS BROKEN"; exit 2; }
if echo "$out" | grep -qx 'empty_id|found seq 0|path_up=\[\]'; then
  echo "DEFECT PRESENT: an entry with id \"\" is found but its path is empty"; exit 1
fi
echo "absent"; exit 0
