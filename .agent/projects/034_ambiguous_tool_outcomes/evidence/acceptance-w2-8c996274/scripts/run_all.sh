#!/usr/bin/env bash
# 034 W2.3: the whole sequence, in order. The rows first (both gates each), then the unit fixtures
# and the reach probe on the restored tree.
set -u
cd "$(git rev-parse --show-toplevel)"
E=.agent/projects/034_ambiguous_tool_outcomes/evidence/acceptance-w2-8c996274
LOG="$E/sequence.log"
note() { echo "$(date -u +%FT%TZ) $*" | tee -a "$LOG"; }
$E/scripts/run_row.sh C-gate K0 p1a p1b p2 p3 C-restored || { note "run_all: run_row.sh stopped rc=$?"; exit 1; }
d="$E/runs/C-invariants"; mkdir -p "$d"; s=$(date +%s)
timeout 900 make invariants > "$d/invariants.out" 2>&1 < /dev/null; rc=$?
note "C-invariants (make invariants): rc=$rc wall_secs=$(( $(date +%s) - s )) $(grep -E 'invariants_dst (PASS|FAIL)' "$d/invariants.out" | tail -1)"
d="$E/runs/R-reach"; mkdir -p "$d"; s=$(date +%s)
timeout 900 ailang run --relax-modules --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
  --ai-stub --entry main $E/p1p3_reach.ail < /dev/null 2>&1 | grep -v '^{' > "$d/reach.out"; rc=${PIPESTATUS[0]}
note "R-reach (p1p3_reach.ail): rc=$rc wall_secs=$(( $(date +%s) - s )) $(grep -c '^REACH ' "$d/reach.out") member rows, $(grep -c '^REACHCONTROL ' "$d/reach.out") control rows"
note "run_all done; tracked tree: $(git status --short --untracked-files=no | wc -l) modified file(s); $(sha256sum -c --quiet $E/base.sha256 && echo 'tool_phase.ail at baseline')"
