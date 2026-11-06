#!/usr/bin/env bash
# bug_twin_forgets_checkpoint_at_resume on the REAL code, through the REAL plan_resume.
#   bash ../out/repro/checkpoint_resume.sh     (from the tree root)
# Exit 1 when the host's journal is accepted and the twin's is not (defect present).
source "$(dirname "$0")/_env.sh"
ail --caps IO --entry main repro/checkpoint_resume.ail > "$work/gen.out"
grep -aE '^[IX]	' "$work/gen.out" | cut -f2
twin="$(grep -aE '^T	' "$work/gen.out" | cut -f3)"
host="$(host_verdict "$work/gen.out" | cut -f3)"
echo "  host journal folds to: $host"
echo "  twin journal folds to: $twin"
if [[ "$host" != "$twin" ]]; then echo "P3.1 VIOLATED (and P3.2: the twin's round trip is ${twin})"; exit 1; fi
echo "P3.1 holds"; exit 0
