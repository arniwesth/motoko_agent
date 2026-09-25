#!/usr/bin/env bash
# 031 PLAN-001 P1.4r (P1.3r's runner, re-pointed): run mutgate.sh (013) over evidence/P1.4r/p14r_mutgate_spec.tsv
# in a THROWAWAY WORKSPACE, never in a checkout anyone is using. Run from a repo root.
#
#   p14r_mutgate.sh                   a copy of the cwd's working tree (the
#                                     delegate's pre-commit run)
#   p11_mutgate.sh --clone-from <r>   a fresh `git clone --shared` of <r> (intake)
#
# The copy holds only what the rows need: src/core/**/*.ail, the ABI package,
# the conformance kit and its examples, the registry generator and this evidence directory (with literal_defaults.py).
# Each row's test_cmd is p14r_check.sh, which builds ITS OWN workspace from
# the copy's src/core and writes its own ailang.lock there -- so the clone-side
# mutation is what is tested and the primary's lock never enters (P0.4's trap).
# mutgate's own logs stay in the throwaway; the verdict table is copied out to
# evidence/P1.4r/mutgate-result.tsv.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.4r
M=.agent/projects/013_core_architecture_for_dst/mutgate.sh
[ -f "$M" ] && [ -f "$E/p14r_mutgate_spec.tsv" ] || { echo "p14r_mutgate: run from the repo root" >&2; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/p14rmut.XXXXXX")
if [ "${1:-}" = --clone-from ]; then
  git clone --shared --quiet "$2" "$T/repo" || { echo "p14r_mutgate: clone failed" >&2; exit 2; }
else
  mkdir -p "$T/repo/packages/motoko-ext-abi" "$T/repo/packages/motoko_ext_conformance/fixtures" \
           "$T/repo/packages/motoko_ext_conformance/examples" \
           "$T/repo/tools/ext_registry_gen" "$T/repo/$E"
  ( cd src && find core -name '*.ail' -print0 | while IFS= read -r -d '' f; do
      mkdir -p "$T/repo/src/$(dirname "$f")"; cp "$f" "$T/repo/src/$f"; done )
  cp packages/motoko-ext-abi/types.ail packages/motoko-ext-abi/ailang.toml "$T/repo/packages/motoko-ext-abi/"
  cp packages/motoko_ext_conformance/ailang.toml packages/motoko_ext_conformance/invariants.ail \
     packages/motoko_ext_conformance/harness.ail "$T/repo/packages/motoko_ext_conformance/"
  cp packages/motoko_ext_conformance/fixtures/reject_fixtures.ail "$T/repo/packages/motoko_ext_conformance/fixtures/"
  cp packages/motoko_ext_conformance/examples/*.ail "$T/repo/packages/motoko_ext_conformance/examples/"
  cp tools/ext_registry_gen/generate.py "$T/repo/tools/ext_registry_gen/"
  cp "$E"/p14r_check.sh "$E"/p14r_mutgate_spec.tsv "$E"/cursor_e2e.ail "$E"/literal_defaults.py "$T/repo/$E/"
fi
bash "$M" --spec "$E/p14r_mutgate_spec.tsv" --repo "$T/repo" --out "$T/out"; rc=$?
cp "$T/out/mutgate.tsv" "$E/mutgate-result.tsv"
echo "p14r_mutgate: exit $rc; verdicts in $E/mutgate-result.tsv"
rm -rf "$T"
exit $rc
