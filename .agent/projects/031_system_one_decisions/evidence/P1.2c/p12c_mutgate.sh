#!/usr/bin/env bash
# 031 PLAN-001 P1.2c: run mutgate.sh (013) over evidence/P1.2c/p12c_mutgate_spec.tsv in a
# THROWAWAY clone, never in a checkout anyone is using. Run from a repo root.
#
#   p12c_mutgate.sh --clone-from <repo>   a fresh `git clone --shared` of <repo> (intake)
#   p12c_mutgate.sh --overlay             a fresh clone of this checkout's HEAD with P1.2c's
#                                         working-tree paths copied over it (the delegate's
#                                         pre-commit run: the same bytes the commit carries)
#
# The throwaway lives under /workspaces, not /tmp: derive.py (the gate rows) refuses a repo
# under /tmp, where AILANG auto-relaxes MOD010. Every row's test_cmd builds its own workspace
# (p12c_ws.sh / p12c_core_check.sh), so the clone's tracked ailang.lock -- which pins path
# dependencies to the primary checkout -- is never what resolves a mutated file. mutgate's
# logs stay in the throwaway; the verdict table is copied to evidence/P1.2c/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.2c
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p12c_mutgate_spec.tsv" ] || { echo "p12c_mutgate: run from the repo root" >&2; exit 2; }
PATHS="packages/motoko-ext-a2a packages/motoko-ext-agentcli packages/motoko-ext-ailang-docs
packages/motoko-ext-mcp packages/motoko-ext-compaction-ai scripts/dst/conformance_selftest.ail
scripts/dst/long_qwen_compaction_dst.ail $E"
T=$(mktemp -d /workspaces/mutgate-031-p12c.XXXXXX)
case "${1:-}" in
  --clone-from)
    git clone --shared --quiet "$2" "$T/repo" || { echo "p12c_mutgate: clone failed" >&2; exit 2; } ;;
  --overlay)
    git clone --shared --quiet "$(pwd)" "$T/repo" || { echo "p12c_mutgate: clone failed" >&2; exit 2; }
    for p in $PATHS; do
      if [ -d "$p" ]; then mkdir -p "$T/repo/$p"; cp -a "$p/." "$T/repo/$p/"
      else mkdir -p "$T/repo/$(dirname "$p")"; cp -a "$p" "$T/repo/$p"; fi
    done
    rm -f "$T/repo/$E/mutgate-result.tsv" ;;
  *) echo "usage: $0 --clone-from <repo> | --overlay" >&2; rm -rf "$T"; exit 2 ;;
esac
bash "$M" --spec "$E/p12c_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p12c_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
