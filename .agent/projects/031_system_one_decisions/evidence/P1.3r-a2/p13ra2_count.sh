#!/usr/bin/env bash
# 031 PLAN-001 P1.3r-a2: the test-count check. `ailang test` (P1.1's workspace,
# evidence/P1.1/p11_core_check.sh) on runtime.ail and the module the neutral_registration
# test moved to; every test must pass AND the counts must be exactly the split of HEAD's
# 36 (e921241 BASELINE-TEST.log): runtime.ail 35, ext_neutral_registration.ail 1.
# A dropped moved test shows as a lower count (or a failed module); exit 1. Run from a repo root.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence
L=$(mktemp "${TMPDIR:-/tmp}/p13ra2count.XXXXXX"); trap 'rm -f "$L"' EXIT
bash $E/P1.1/p11_core_check.sh test src/core/ext/runtime.ail src/core/test/ext_neutral_registration.ail > "$L" 2>&1; rc=$?
cat "$L"
[ $rc -eq 0 ] || { echo "p13ra2_count: a module failed (exit $rc)"; exit 1; }
# grep on the file, never `cmd | grep -q` under pipefail (exit 141, the known trap)
grep -qE '^p11: test src/core/ext/runtime\.ail ok -- 35 tests: 35 passed, 0 failed' "$L" \
  || { echo "p13ra2_count: runtime.ail is not 35/35"; exit 1; }
grep -qE '^p11: test src/core/test/ext_neutral_registration\.ail ok -- 1 tests: 1 passed, 0 failed' "$L" \
  || { echo "p13ra2_count: ext_neutral_registration.ail is not 1/1"; exit 1; }
echo "p13ra2_count: ok -- 35 + 1 = 36, as at HEAD"
