#!/usr/bin/env bash
# 031 PLAN-001 P1.5r-a3: run mutgate.sh (013) over evidence/P1.5r-a3/p15ra3_mutgate_spec.tsv in a
# THROWAWAY clone, never in a checkout anyone is using. Run from a repo root.
#
#   p15ra3_mutgate.sh --clone-from <repo>   a fresh `git clone --shared` of <repo> (intake)
#   p15ra3_mutgate.sh --overlay             a fresh clone of this checkout's HEAD with P1.5r-a3's
#                                           working-tree paths copied over it (the delegate's
#                                           pre-commit run: the same bytes the commit carries)
#
# The throwaway lives under /workspaces, not /tmp (derive.py, which profile_definition and
# driver_only reach, refuses /tmp). Every row's test_cmd is p15ra3_test.sh, which regenerates the
# clone's lock once. The verdict table is copied to evidence/P1.5r-a3/mutgate-result.tsv and each
# row's mutated red reason to MUTGATE-red-reasons.txt.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.5r-a3
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p15ra3_mutgate_spec.tsv" ] || { echo "p15ra3_mutgate: run from the repo root" >&2; exit 2; }
PATHS="tools/profile_definition/check_fixtures.py scripts/dst/run_declared_vs_performed.sh scripts/dst/declared_vs_performed.ail $E"
T=$(mktemp -d /workspaces/mutgate-031-p15ra3.XXXXXX)
case "${1:-}" in
  --clone-from)
    git clone --shared --quiet "$2" "$T/repo" || { echo "p15ra3_mutgate: clone failed" >&2; exit 2; } ;;
  --overlay)
    git clone --shared --quiet "$(pwd)" "$T/repo" || { echo "p15ra3_mutgate: clone failed" >&2; exit 2; }
    for p in $PATHS; do rm -rf "$T/repo/$p"; mkdir -p "$T/repo/$(dirname "$p")"; cp -a "$p" "$T/repo/$p"; done
    rm -f "$T/repo/$E/mutgate-result.tsv" "$T/repo/$E/MUTGATE-red-reasons.txt" ;;
  *) echo "usage: $0 --clone-from <repo> | --overlay" >&2; rm -rf "$T"; exit 2 ;;
esac
echo "start $(date -u +%Y-%m-%dT%H:%M:%SZ) HEAD $(git -C "$T/repo" rev-parse --short HEAD) mode ${1}"
bash "$M" --spec "$E/p15ra3_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
{
  echo "# P1.5r-a3 mutgate: each row's MUTATED run (p15ra3_test.sh prints every failing row and the last line)"
  for f in "$T"/out/*.mutated.log; do
    echo "== $(basename "$f" .mutated.log)"
    grep -E '✗|FAIL|p15ra3:|passed' "$f" | cut -c1-400
  done
} > "$E/MUTGATE-red-reasons.txt"
echo "p15ra3_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv, red reasons in $E/MUTGATE-red-reasons.txt"
rm -rf "$T"
exit $rc
