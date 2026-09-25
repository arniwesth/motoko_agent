#!/usr/bin/env bash
# mutgate for 031 line R's production contracts (027 ADR-001 §4).
#
# A gate that passes is not evidence until it can be made to fail. Two
# mutations, each aimed at one half of what this leg added:
#
#   M1  weaken a CONTRACT to `ensures { true }`  -> verify_classify_check red
#       (the register pins contract text AND computed class; `true` is a
#       tautology and hashes differently, so pin and tree disagree)
#   M2  delete an EXCUSE's `-- contracts:` line  -> new_contract_policy names
#       that declaration, and its finding count rises by one
#   M3  add a THIRD skipped property                -> profile_coverage red
#   M4  move a contract to a different function     -> profile_coverage red
#       (same skip COUNT, different skip IDENTITY -- the case a pinned count
#        of 2 would wave through, which is why Makefile:773 pins names)
#
# M2 IS COUNT-BASED ON PURPOSE. `new_contract_policy` is LEGITIMATELY RED at
# baseline: the 83 test-only declarations are held pending 027's ruling
# (QUESTION-2026-09-24-test-scaffolding-in-scope.md). So "the gate went red"
# proves nothing here -- it was already red. What the mutation has to show is
# that the excuse is LOAD-BEARING: 83 -> 84, with the mutated name appearing
# where it did not appear before.
#
# NO `| grep -q`: under `set -o pipefail` a short-circuiting grep kills the
# writer with SIGPIPE and the baseline scores red at exit 141 -- the trap named
# in the brief. Output goes to a file and the file is grepped.
set -euo pipefail

TREE="${1:?usage: mutgate.sh <fresh-clone-path>}"
cd "$TREE"

# The base is a SHA, not the NAME `origin/main_dst`. In a clone whose origin is a
# local path, `origin/main_dst` mirrors the PRIMARY checkout's LOCAL `main_dst`
# branch (600663a2, months behind) instead of its remote-tracking ref, and the
# gate then reports `527 of 575` -- which this script scores as a hard failure
# rather than a pass, because count() pins `of 109`. Override with BASE= for a
# branch cut somewhere else.
BASE="${BASE:-31c5308e3ccf65041b3d5571c5f32346cea0cc73}"
git cat-file -e "$BASE^{commit}" 2>/dev/null || {
  echo "mutgate: base $BASE is not a commit in $TREE -- fetch it first"; exit 2; }
OUT="$(mktemp -d)"
trap 'git -C "$TREE" checkout -- src/core tools/verify_classify/contracts.register Makefile 2>/dev/null || true; rm -rf "$OUT"' EXIT

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ✓ $1"; }
bad() { fail=$((fail+1)); echo "  ✗ $1"; }

run() {  # run <name> <cmd...>  -> writes $OUT/<name>, echoes exit code
  local n=$1; shift
  set +e; "$@" > "$OUT/$n" 2>&1; local r=$?; set -e
  echo "$r"
}
count() { sed -n 's/^new_contract_policy: \([0-9]*\) of 109.*/\1/p' "$1" | head -1; }
names() { grep -c "  ✗ .* $1:" "$2" || true; }

echo "mutgate: baseline"
b_classify=$(run base_classify make verify_classify_check)
[ "$b_classify" -eq 0 ] && ok "verify_classify_check green (exit 0)" \
                        || bad "verify_classify_check wanted green, got $b_classify"

b_policy=$(run base_policy make new_contract_policy BASE="$BASE")
b_n=$(count "$OUT/base_policy")
[ "$b_n" = 83 ] && ok "new_contract_policy: 83 of 109 unjustified (the held scaffolding; exit $b_policy)" \
                || bad "new_contract_policy: wanted 83 unjustified, got '${b_n:-none}'"
[ "$(names compare_bytes "$OUT/base_policy")" -eq 0 ] \
  && ok "compare_bytes is NOT among them (its excuse is accepted)" \
  || bad "compare_bytes already flagged at baseline -- M2 would prove nothing"

echo "mutgate: M1 -- weaken capability_purity_basis's contract to \`ensures { true }\`"
python3 - <<'PY'
from pathlib import Path
p = Path("src/core/dst_profile_coverage.ail"); t = p.read_text()
old = """  ensures { (result == ViewsPlusBoundary)
              == (k == DecisionSolverJudgeKind || k == DecisionToolPolicyKind) }"""
assert t.count(old) == 1, "mutation target not found -- contract text moved"
p.write_text(t.replace(old, "  ensures { true }"))
PY
m1=$(run m1 make verify_classify_check)
[ "$m1" -ne 0 ] && ok "verify_classify_check RED (exit $m1)" \
                || bad "verify_classify_check stayed green under a tautology"
[ "$(grep -c capability_purity_basis "$OUT/m1")" -gt 0 ] \
  && ok "and it names capability_purity_basis" \
  || bad "red, but does not name the mutated contract"
git checkout -- src/core/dst_profile_coverage.ail

echo "mutgate: M2 -- delete compare_bytes's \`-- contracts:\` excuse line"
python3 - <<'PY'
from pathlib import Path
p = Path("src/core/ext/registry_normalize.ail"); t = p.read_text()
old = "-- contracts: SKIPPED — uses an unencodable builtin: std/string.charAt. Tried as\n"
assert t.count(old) == 1, "mutation target not found -- excuse text moved"
p.write_text(t.replace(old, ""))
PY
m2=$(run m2 make new_contract_policy BASE="$BASE")
m2_n=$(count "$OUT/m2")
[ "$m2_n" = 84 ] && ok "new_contract_policy: 84 of 109 -- one more than baseline (exit $m2)" \
                 || bad "wanted 84 unjustified, got '${m2_n:-none}'"
[ "$(names compare_bytes "$OUT/m2")" -gt 0 ] \
  && ok "and compare_bytes is now among them" \
  || bad "count rose but compare_bytes is not named"
git checkout -- src/core/ext/registry_normalize.ail

# --- Makefile:773's identity-pinned skip set -------------------------------
# `ailang test` exits 1 on ANY skip, so profile_coverage cannot just chain on
# it; the recipe pins WHICH properties are allowed to be quiet. These two
# mutations are what make that pin worth more than a count.

echo "mutgate: baseline profile_coverage"
b_pc=$(run base_pc make profile_coverage)
[ "$b_pc" -eq 0 ] && ok "profile_coverage green (exit 0)" \
                  || bad "profile_coverage wanted green, got $b_pc"
[ "$(grep -c 'pinned by name' "$OUT/base_pc")" -gt 0 ] \
  && ok "and it reports the pinned skip set" \
  || bad "green, but the pin did not report"

echo "mutgate: M3 -- add a THIRD skipped property (a contract on capability_kind_id)"
python3 - <<'PY'
from pathlib import Path
p = Path("src/core/dst_profile_coverage.ail"); t = p.read_text()
old = "export pure func capability_kind_id(k: CapabilityKind) -> string {"
assert t.count(old) == 1, "mutation target not found -- capability_kind_id moved"
p.write_text(t.replace(old, 'export pure func capability_kind_id(k: CapabilityKind) -> string\n'
                            '  ensures { result != "" }\n{'))
PY
m3=$(run m3 make profile_coverage)
[ "$m3" -ne 0 ] && ok "profile_coverage RED on a third skip (exit $m3)" \
                || bad "profile_coverage stayed green with an unpinned third skip"
[ "$(grep -c 'capability_kind_id_property_1' "$OUT/m3")" -gt 0 ] \
  && ok "and it names the new skip in got:" \
  || bad "red, but does not name the new skip"
git checkout -- src/core/dst_profile_coverage.ail

echo "mutgate: M4 -- SAME count, DIFFERENT identity (move purity_name's contract)"
python3 - <<'PY'
from pathlib import Path
p = Path("src/core/dst_profile_coverage.ail"); t = p.read_text()
# take the contract off purity_name ...
old = """pure func purity_name(b: PurityBasis) -> string
  ensures { result != ""
              && ((b == ViewsPlusBoundary) == (result == "views-plus-boundary")) }
{"""
assert t.count(old) == 1, "mutation target not found -- purity_name's contract moved"
t = t.replace(old, "pure func purity_name(b: PurityBasis) -> string {")
# ... and put one on a different ADT-parameter function, so the COUNT is still 2
old2 = "export pure func capability_kind_id(k: CapabilityKind) -> string {"
assert t.count(old2) == 1, "mutation target not found -- capability_kind_id moved"
t = t.replace(old2, 'export pure func capability_kind_id(k: CapabilityKind) -> string\n'
                    '  ensures { result != "" }\n{')
p.write_text(t)
PY
m4=$(run m4 make profile_coverage)
# The skip COUNT comes from `ailang test` directly: on the identity-mismatch
# path the recipe prints want/got, not the run's summary line, so parsing make's
# own output here would find nothing (and did, the first time this was written).
_=$(run m4_raw ailang test src/core/dst_profile_coverage.ail)
m4_skipped=$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/m4_raw" \
             | sed -n 's/^[0-9][0-9]* tests:.*, \([0-9][0-9]*\) skipped.*/\1/p' | tail -1)
[ "${m4_skipped:-}" = 2 ] && ok "the skip COUNT is still 2 (a count-based pin would pass)" \
                          || bad "wanted 2 skips so the count is unchanged, got '${m4_skipped:-none}'"
[ "$m4" -ne 0 ] && ok "profile_coverage RED anyway -- the pin is on IDENTITY (exit $m4)" \
                || bad "profile_coverage stayed green though purity_name stopped running"
[ "$(grep -c 'purity_name_property_1' "$OUT/m4")" -gt 0 ] \
  && ok "and it names the property that went quiet" \
  || bad "red, but does not name the property that went quiet"
git checkout -- src/core/dst_profile_coverage.ail

echo "mutgate: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
