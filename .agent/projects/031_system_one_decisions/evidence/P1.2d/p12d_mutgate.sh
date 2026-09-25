#!/usr/bin/env bash
# 031 PLAN-001 P1.2d: run mutgate.sh (013) over evidence/P1.2d/p12d_mutgate_spec.tsv in a
# THROWAWAY clone, never in a checkout anyone is using. Run from a repo root.
#
#   p12d_mutgate.sh --clone-from <repo>   a fresh `git clone --shared` of <repo> (intake)
#   p12d_mutgate.sh --overlay             a fresh clone of this checkout's HEAD with P1.2d's
#                                         working-tree paths copied over it (the delegate's
#                                         pre-commit run: the same bytes the commit carries)
#
# The throwaway lives under /workspaces, not /tmp: derive.py (the gate rows) refuses a repo
# under /tmp, where AILANG auto-relaxes MOD010. Every row's test_cmd builds its own workspace
# (p12d_ws.sh / p12d_core_check.sh), so the clone's tracked ailang.lock -- which pins path
# dependencies to the primary checkout -- is never what resolves a mutated file. mutgate's
# logs stay in the throwaway; the verdict table is copied to evidence/P1.2d/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.2d
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p12d_mutgate_spec.tsv" ] || { echo "p12d_mutgate: run from the repo root" >&2; exit 2; }
PATHS="packages/motoko-ext-compose packages/motoko-ext-herdr scripts/dst/compose_live_exec.ail
scripts/dst/declared_vs_performed.ail scripts/dst/herdr_graded_dst.ail scripts/verify_delegate_kind_required.ail
scripts/verify_exit_intent.ail scripts/verify_herdr_delegate_wait.ail scripts/verify_herdr_orchestrator.ail
scripts/verify_mot131_early_answer.ail scripts/verify_mot133_owner_tag.ail scripts/verify_mot136_dagr_producer.ail
scripts/verify_mot137_dagr_pane.ail $E"
T=$(mktemp -d /workspaces/mutgate-031-p12d.XXXXXX)
case "${1:-}" in
  --clone-from)
    git clone --shared --quiet "$2" "$T/repo" || { echo "p12d_mutgate: clone failed" >&2; exit 2; } ;;
  --overlay)
    git clone --shared --quiet "$(pwd)" "$T/repo" || { echo "p12d_mutgate: clone failed" >&2; exit 2; }
    for p in $PATHS; do
      if [ -d "$p" ]; then mkdir -p "$T/repo/$p"; cp -a "$p/." "$T/repo/$p/"
      else mkdir -p "$T/repo/$(dirname "$p")"; cp -a "$p" "$T/repo/$p"; fi
    done
    rm -f "$T/repo/$E/mutgate-result.tsv" ;;
  *) echo "usage: $0 --clone-from <repo> | --overlay" >&2; rm -rf "$T"; exit 2 ;;
esac
bash "$M" --spec "$E/p12d_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p12d_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
