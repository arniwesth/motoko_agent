#!/usr/bin/env bash
# 034 W2.3: type-check each mutant BEFORE predictions.tsv is hashed. It runs no gate and reads no
# rule: `ailang check` on the one edited file, then `git checkout --`. A mutant that does not
# compile is repaired here, before the hash, and never after it.
set -u
cd "$(git rev-parse --show-toplevel)"
E=.agent/projects/034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274
F=src/core/tool_phase.ail
base=$(git rev-parse HEAD:$F)
for id in "${@:-p1a p1b p2 p3 K0}"; do
  for one in $id; do
    [ -z "$(git status --short --untracked-files=no)" ] || { echo "$one ABORT: tracked tree not clean"; exit 8; }
    python3 $E/scripts/apply_mutant.py apply "$one" . || { git checkout -- $F; continue; }
    s=$(date +%s)
    ailang check $F > $E/runs/typecheck-$one.log 2>&1; rc=$?
    echo "$one typecheck rc=$rc secs=$(( $(date +%s) - s )) $(tail -1 $E/runs/typecheck-$one.log)"
    git checkout -- $F
    [ "$(git hash-object $F)" = "$base" ] || { echo "$one RESTORE FAILED"; exit 7; }
  done
done
echo "typecheck done; tracked tree: $(git status --short --untracked-files=no | wc -l) changed file(s)"
