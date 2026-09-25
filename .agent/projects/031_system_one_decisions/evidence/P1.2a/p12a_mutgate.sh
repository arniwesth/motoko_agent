#!/usr/bin/env bash
# 031 PLAN-001 P1.2a: run mutgate.sh (013) over evidence/P1.2a/p12a_mutgate_spec.tsv in a
# THROWAWAY clone, never in a checkout anyone is using. Run from a repo root.
#
#   p12a_mutgate.sh --clone-from <repo>   a fresh `git clone --shared` of <repo> (intake)
#   p12a_mutgate.sh --overlay             a fresh clone of this checkout's HEAD with P1.2a's
#                                         working-tree paths copied over it (the delegate's
#                                         pre-commit run: the same bytes the commit carries)
#
# The throwaway lives under /workspaces, not /tmp: derive.py (the gate rows) refuses a repo
# under /tmp, where AILANG auto-relaxes MOD010. Every row's test_cmd builds its own workspace
# (p12a_ws.sh / p12a_core_check.sh), so the clone's tracked ailang.lock -- which pins path
# dependencies to the primary checkout -- is never what resolves a mutated file. mutgate's
# logs stay in the throwaway; the verdict table is copied to evidence/P1.2a/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.2a
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p12a_mutgate_spec.tsv" ] || { echo "p12a_mutgate: run from the repo root" >&2; exit 2; }
PATHS="packages/motoko-ext-compaction-structural packages/motoko-ext-decision-framework
packages/motoko-ext-empty-stop-guard packages/motoko-ext-microrag packages/motoko-ext-omnigraph
packages/motoko-ext-progress-contract-guard scripts/dst/compaction_policy_dst.ail
scripts/dst/compaction_seeded_dst.ail scripts/smoke_v2_compaction_full_loop.ail
scripts/dst/phase_c2_wiring_scenarios.ail src/core/test/integration_tests.ail $E"
T=$(mktemp -d /workspaces/mutgate-031-p12a.XXXXXX)
case "${1:-}" in
  --clone-from)
    git clone --shared --quiet "$2" "$T/repo" || { echo "p12a_mutgate: clone failed" >&2; exit 2; } ;;
  --overlay)
    git clone --shared --quiet "$(pwd)" "$T/repo" || { echo "p12a_mutgate: clone failed" >&2; exit 2; }
    for p in $PATHS; do
      if [ -d "$p" ]; then mkdir -p "$T/repo/$p"; cp -a "$p/." "$T/repo/$p/"
      else mkdir -p "$T/repo/$(dirname "$p")"; cp -a "$p" "$T/repo/$p"; fi
    done
    rm -f "$T/repo/$E/mutgate-result.tsv" ;;
  *) echo "usage: $0 --clone-from <repo> | --overlay" >&2; rm -rf "$T"; exit 2 ;;
esac
bash "$M" --spec "$E/p12a_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p12a_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
