#!/usr/bin/env bash
# 031 PLAN-001 P1.3r-a2: run mutgate.sh (013) over evidence/P1.3r-a2/p13ra2_mutgate_spec.tsv in a
# FRESH CLONE, never in a checkout anyone is using. Run from a repo root.
#   p13ra2_mutgate.sh --overlay           `git clone --shared` of the cwd's HEAD, with this
#                                         part's paths (below) copied over from the working
#                                         tree (the delegate's pre-commit run)
#   p13ra2_mutgate.sh --clone-from <r>    a fresh `git clone --shared` of <r>, as committed (intake)
# Each test_cmd builds its own workspace (P1.1's / P1.2c's scripts) with its own lock, so the
# primary's ailang.lock never enters. The verdict table is copied to evidence/P1.3r-a2/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.3r-a2
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
PATHS="src/core/ext/runtime.ail src/core/test/ext_neutral_registration.ail $E/p13ra2_probe.sh $E/p13ra2_count.sh $E/p13ra2_mutgate_spec.tsv"
[ -f "$M" ] && [ -f "$E/p13ra2_mutgate_spec.tsv" ] || { echo "p13ra2_mutgate: run from the repo root" >&2; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/p13ra2mut.XXXXXX")
case "${1:-}" in
  --clone-from) git clone --shared --quiet "$2" "$T/repo" || { echo "clone failed" >&2; exit 2; } ;;
  --overlay) git clone --shared --quiet . "$T/repo" || { echo "clone failed" >&2; exit 2; }
             for p in $PATHS; do mkdir -p "$T/repo/$(dirname "$p")"; cp "$p" "$T/repo/$p"; done ;;
  *) echo "usage: $0 --overlay | --clone-from <repo>" >&2; exit 2 ;;
esac
echo "p13ra2_mutgate: repo $T/repo at $(git -C "$T/repo" rev-parse --short HEAD) (${1})"
bash "$M" --spec "$E/p13ra2_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p13ra2_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
