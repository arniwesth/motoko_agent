#!/usr/bin/env bash
# 031 PLAN-001 P1.7r: run mutgate.sh (013) over evidence/P1.7r/p17r_mutgate_spec.tsv in a
# THROWAWAY clone, never in a checkout anyone is using. Run from a repo root.
#
#   p17r_mutgate.sh --clone-from <repo>   a fresh `git clone --shared` of <repo> (intake)
#   p17r_mutgate.sh --overlay             a fresh clone of this checkout's HEAD with P1.7r's
#                                         working-tree paths copied over it (the delegate's
#                                         pre-commit run: the same bytes the commit carries)
#
# The throwaway lives under /workspaces, not /tmp (derive.py refuses /tmp). Every row's
# test_cmd is p17r_selftest.sh, which regenerates the clone's lock once so no compile resolves
# the primary's packages. mutgate's logs stay in the throwaway; the verdict table is copied to
# evidence/P1.7r/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.7r
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p17r_mutgate_spec.tsv" ] || { echo "p17r_mutgate: run from the repo root" >&2; exit 2; }
# P1.7r's paths: the 17 fixtures and their pins, both classifiers (the orchestrator's two scope
# additions: tools/ext_call_inventory/ and tools/ext_ambient_inventory/ derive code + fixtures), this dir
PATHS="tools/ext_call_inventory tools/ext_ambient_inventory $E"
T=$(mktemp -d /workspaces/mutgate-031-p17r.XXXXXX)
case "${1:-}" in
  --clone-from)
    git clone --shared --quiet "$2" "$T/repo" || { echo "p17r_mutgate: clone failed" >&2; exit 2; } ;;
  --overlay)
    git clone --shared --quiet "$(pwd)" "$T/repo" || { echo "p17r_mutgate: clone failed" >&2; exit 2; }
    for p in $PATHS; do rm -rf "$T/repo/$p"; mkdir -p "$T/repo/$(dirname "$p")"; cp -a "$p" "$T/repo/$p"; done
    find "$T/repo/tools" \( -name __pycache__ -o -name .ailang \) -prune -exec rm -rf {} + 2>/dev/null
    rm -f "$T/repo/$E/mutgate-result.tsv" ;;
  *) echo "usage: $0 --clone-from <repo> | --overlay" >&2; rm -rf "$T"; exit 2 ;;
esac
bash "$M" --spec "$E/p17r_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p17r_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
