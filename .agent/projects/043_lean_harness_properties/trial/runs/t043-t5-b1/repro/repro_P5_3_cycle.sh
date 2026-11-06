#!/usr/bin/env bash
# B1-T5-1. P5.3 on the real `path_up` (export-only shim): on a parent cycle, path_up returns
# [] although find_entry finds the start entry, so the result does not end at the start id.
# Exit 1 when the defect is present, 0 when absent, 2 when the harness itself is broken.
source "$(dirname "$0")/_common.sh"
out=$(run_harness shim path_up_direct.ail); echo "$out"
echo "$out" | grep -qx 'control_chain|found seq 2|path_up=\[0,1,2\]' || { echo "HARNESS BROKEN"; exit 2; }
if echo "$out" | grep -qx 'self_loop|found seq 0|path_up=\[\]' || \
   echo "$out" | grep -qx 'cycle_through_root|found seq 2|path_up=\[\]'; then
  echo "DEFECT PRESENT: path_up drops the whole path at the first repeated id"; exit 1
fi
echo "absent"; exit 0
