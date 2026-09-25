#!/usr/bin/env bash
# 031 P1.1 (attempt 2): sweep an explicit list of modules (one chunk of a tree)
# so a large tree can run as parallel chunks. Run from a repo root:
#   p11_sweep_list.sh <label> <listfile> [relax]   -> TYPE-SWEEP-<label>.log
# Chunk logs are concatenated into TYPE-SWEEP-<tree>.log by the caller and
# turned into the TSV by p11_sweep_tsv.py.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.1
label="$1"; list="$2"; relax="${3:-}"
mapfile -t files < "$list"
P11_RELAX="$relax" bash "$E/p11_core_check.sh" check "${files[@]}" > "$E/TYPE-SWEEP-$label.log" 2>&1
echo "chunk $label: $(grep -c '^p11: check' "$E/TYPE-SWEEP-$label.log")/${#files[@]} checked, $(grep -c FAILED "$E/TYPE-SWEEP-$label.log") failed"
