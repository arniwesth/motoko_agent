#!/usr/bin/env bash
# mutgate — submission precondition: every test a fix adds or repairs must be shown
# to DISCRIMINATE. Not "the test passes": passing is what a vacuous test does too.
#
# THE RULE. For each (test, mutation) pair the fix claims:
#     baseline GREEN  →  mutated RED  →  restored GREEN, bytes identical
# A test that cannot go red under the mutation of the behaviour it names is vacuous.
# A test that cannot go green on unmutated code is red-by-construction. One
# two-sided check catches both, which is why it is stated as a pair and not as
# "run the mutation".
#
# WHY. PLAN-004 §0.8 already requires red-first/mutation records for PRODUCTION code
# and P1 reached 14/14 caught. Nothing applied the same discipline to the fixes'
# own tests. The P2.3 round-4 basis review (answer-mot-dlg-1789810872424.md) then
# found 3 of 5 authorized fixes defective — mut4 vacuous, mut5 red-by-construction,
# m12 a rename with no mechanical effect — a 60% per-item defect rate, every one of
# them detectable by this gate in about two minutes instead of a 30-minute review round.
#
# SCOPE. This is a process artifact. It writes nothing into the evaluator tree, the
# sweep clone, or A. Run it in a throw-away clone; never against a checkout another
# delegate is using (see --clone-from).
#
# Usage:
#   mutgate.sh --spec <spec.tsv> --repo <checkout> [--out <dir>] [--clone-from <repo>]
#
# Spec is TSV, one row per (fix, test, mutation), '#' comments allowed:
#   fix_id <TAB> target_file <TAB> sed_expr <TAB> test_cmd
#
#   target_file  path relative to --repo; the file the mutation edits
#   sed_expr     a sed -i expression that breaks the behaviour the test names
#   test_cmd     run from the repo root; exit 0 = green, non-zero = red
#
# Exit: 0 all pairs discriminate · 1 at least one failed · 2 usage/IO.

set -uo pipefail

SPEC=""; REPO=""; OUT=""; CLONE_FROM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --spec) SPEC="$2"; shift 2;;
    --repo) REPO="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --clone-from) CLONE_FROM="$2"; shift 2;;
    *) echo "mutgate: unknown argument $1" >&2; exit 2;;
  esac
done
[ -n "$SPEC" ] && [ -f "$SPEC" ] || { echo "mutgate: --spec <file> required" >&2; exit 2; }

if [ -n "$CLONE_FROM" ]; then
  [ -n "$REPO" ] || { echo "mutgate: --repo names the clone destination" >&2; exit 2; }
  rm -rf "$REPO"
  git clone --shared --quiet "$CLONE_FROM" "$REPO" || { echo "mutgate: clone failed" >&2; exit 2; }
fi
[ -n "$REPO" ] && [ -d "$REPO" ] || { echo "mutgate: --repo <dir> required" >&2; exit 2; }
OUT="${OUT:-$REPO/.mutgate}"; mkdir -p "$OUT" || exit 2

pass=0; fail=0; row=0
printf 'fix\ttest\tbaseline\tmutated\trestored\tbytes\tverdict\n' > "$OUT/mutgate.tsv"

run() { # run test_cmd in repo, log to $1; echo exit code
  local log="$1"; shift
  ( cd "$REPO" && eval "$*" ) > "$log" 2>&1; echo $?
}

while IFS=$'\t' read -r fix target sed_expr test_cmd; do
  case "${fix:-}" in ''|\#*) continue;; esac
  row=$((row+1))
  tgt="$REPO/$target"
  if [ ! -f "$tgt" ]; then
    printf '%s\t%s\tNOFILE\t-\t-\t-\tFAIL\n' "$fix" "$target" >> "$OUT/mutgate.tsv"
    echo "FAIL $fix — target not found: $target"; fail=$((fail+1)); continue
  fi

  before=$(sha256sum "$tgt" | cut -d' ' -f1)
  cp "$tgt" "$OUT/$fix.orig"

  rc_base=$(run "$OUT/$fix.baseline.log" "$test_cmd")
  sed -i "$sed_expr" "$tgt" || true
  mutated=$(sha256sum "$tgt" | cut -d' ' -f1)
  rc_mut=$(run "$OUT/$fix.mutated.log" "$test_cmd")
  cp "$OUT/$fix.orig" "$tgt"
  after=$(sha256sum "$tgt" | cut -d' ' -f1)
  rc_rest=$(run "$OUT/$fix.restored.log" "$test_cmd")

  # four-point verdict
  v=PASS; why=""
  [ "$rc_base"  = "0" ] || { v=FAIL; why="baseline not green (rc=$rc_base): red-by-construction"; }
  [ "$rc_mut"  != "0" ] || { v=FAIL; why="${why:+$why; }mutation did not go red: VACUOUS"; }
  [ "$mutated" != "$before" ] || { v=FAIL; why="${why:+$why; }sed changed nothing: mutation is inert"; }
  [ "$after"    = "$before" ] || { v=FAIL; why="${why:+$why; }restore left different bytes"; }
  [ "$rc_rest"  = "0" ] || { v=FAIL; why="${why:+$why; }not green after restore"; }

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fix" "$target" \
    "$([ "$rc_base" = 0 ] && echo GREEN || echo red)" \
    "$([ "$rc_mut" != 0 ] && echo RED || echo green)" \
    "$([ "$rc_rest" = 0 ] && echo GREEN || echo red)" \
    "$([ "$after" = "$before" ] && echo same || echo DIFFERS)" "$v" >> "$OUT/mutgate.tsv"

  if [ "$v" = PASS ]; then echo "PASS $fix — discriminates"; pass=$((pass+1))
  else echo "FAIL $fix — $why"; fail=$((fail+1)); fi
  rm -f "$OUT/$fix.orig"
done < "$SPEC"

echo "---"
echo "mutgate: $pass/$row discriminate, $fail failed. Record: $OUT/mutgate.tsv"
[ "$fail" -eq 0 ] || { echo "SUBMISSION REFUSED — a fix whose test does not discriminate is not submittable."; exit 1; }
echo "Submission precondition MET."
