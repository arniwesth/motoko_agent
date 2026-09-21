#!/usr/bin/env bash
# 031 PLAN-001 P1.7r: the three self-tests and the fixture compiles against COMMITTED HEAD
# (plan §0 item 13: never the working tree -- P1.3r's and P1.5r's follow-ups edit src/core
# in this checkout), with P1.7r's own working-tree paths overlaid: the bytes the commit carries.
# Run from the primary repo root; writes the logs beside this script.
#
#   p17r_headws.sh            build the workspace, run hook / ambient / call / check, remove it
#
# THE WORKSPACE: `git clone --shared` of this checkout (its HEAD commit checked out, nothing of
# the working tree), under /workspaces (derive.py refuses /tmp, where AILANG relaxes MOD010),
# P1.7r's paths copied over it, and the lock regenerated there by p17r_selftest.sh so nothing
# resolves to the primary (the ailang.lock trap).
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.7r
[ -f "$E/p17r_selftest.sh" ] || { echo "p17r_headws: run from the repo root" >&2; exit 2; }
# P1.7r's paths: the 17 fixtures and their pins, both classifiers (the orchestrator's two scope
# additions: tools/ext_call_inventory/ and tools/ext_ambient_inventory/ derive code + fixtures), this dir
PATHS="tools/ext_call_inventory tools/ext_ambient_inventory $E"
R=$(pwd)
W=$(mktemp -d /workspaces/p17r-head.XXXXXX); trap 'rm -rf "$W"' EXIT
git clone --shared --quiet "$(pwd)" "$W" || { echo "p17r_headws: clone failed" >&2; exit 2; }
for p in $PATHS; do rm -rf "$W/$p"; mkdir -p "$W/$(dirname "$p")"; cp -a "$p" "$W/$p"; done
find "$W/tools" \( -name __pycache__ -o -name .ailang \) -prune -exec rm -rf {} + 2>/dev/null
echo "p17r_headws: workspace $W at $(git -C "$W" rev-parse --short HEAD) + P1.7r overlay"
rc=0
for m in hook ambient call check; do
  ( cd "$W" && P17R_RAW="$R/$E/AFTER-head-$m.raw.log" bash "$E/p17r_selftest.sh" $m ) > "$E/AFTER-head-$m.log" 2>&1; r=$?
  echo "p17r_headws: $m exit $r -- $(tail -1 "$E/AFTER-head-$m.log")"
  [ $m = check ] || [ $r -eq 0 ] || rc=1
done
exit $rc
