#!/usr/bin/env bash
# 031 PLAN-001 P0.6: exit checks 1 and 2 -- `ailang check` every example module
# against THIS checkout's ABI 8.0 and conformance kit, then the scripted run:
# each decision consumer's votes, the disclosure and second-registration checks,
# and the DescribeTools catalog registered configured and empty -- all in
# examples/scripted_backend.ail `main`, which exits 1 on any mismatch. Run from
# a repo root.
# Exits 0 only when every module checks, every scripted vote matches, and the
# catalog reads configured=1 empty=0.
set -euo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P0.6
T=$(bash "$E/p06_workspace.sh")
trap 'rm -rf "$T"' EXIT
cd "$T"
export AILANG_RELAX_MODULES=1
for m in completion_guard repeat_failure_policy config_catalog scripted_backend; do
  f="deps/motoko_ext_conformance/examples/$m.ail"
  ailang check "$f" >/dev/null 2>&1 \
    || { ailang check "$f" 2>&1 | tail -6; echo "p06: ailang check $m FAILED"; exit 1; }
  echo "p06: ailang check examples/$m ok"
done
cp deps/motoko_ext_conformance/examples/scripted_backend.ail run.ail
sed -i 's|^module sunholo/motoko_ext_conformance/examples/scripted_backend$|module run|' run.ail
ailang run --caps IO --entry main run.ail < /dev/null
echo "p06: scripted run PASS"
