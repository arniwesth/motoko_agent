#!/usr/bin/env bash
# 037 P6 evidence: three mutants, one per kind of pin P6 moved, to show each
# pin is read by its gate (ADR-001 A7: a pin that moves is checked, not just
# re-pinned). Each is one change to a tracked file, restored with
# `git checkout` after the run; the tree must be clean before and is clean
# after. Logs under <out dir>, a row per mutant in <out dir>/../mutants.tsv.
#
#   bash mutate_p6.sh <out dir>
set -u
OUT=${1:?out dir}
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
mkdir -p "$OUT"
[ -z "$(git status --short --untracked-files=no)" ] || { echo "tracked changes present; refusing"; exit 1; }
TSV="$OUT/../mutants.tsv"
printf 'id\tfile\tchange\tcommand\texpected\texit\tobserved\tkilled\n' > "$TSV"

run() {  # id file sed-expr command expected grep-for-observed
  local id=$1 file=$2 expr=$3 gate=$4 expected=$5 pat=$6
  sed -i "$expr" "$file"
  if git diff --quiet -- "$file"; then echo "$id: the edit changed nothing"; exit 1; fi
  bash -c "$gate" > "$OUT/$id.log" 2>&1 < /dev/null; local rc=$?
  echo "exit=$rc" >> "$OUT/$id.log"
  git checkout -q -- "$file"
  local seen; seen=$(grep -c -E "$pat" "$OUT/$id.log")
  local killed=no; [ "$rc" -ne 0 ] && [ "$seen" -gt 0 ] && killed=yes
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s matching line(s)\t%s\n' "$id" "$file" "$expr" "$gate" "$expected" "$rc" "$seen" "$killed" >> "$TSV"
  printf '%-4s %-48s exit=%s matching=%s killed=%s\n' "$id" "$gate" "$rc" "$seen" "$killed"
}

# m1: the absorption pins put back to the values they had before P6.
run m1 scripts/dst/run_declared_vs_performed.sh 's/^absorb Env 18$/absorb Env 16/; s/^absorb FS 15$/absorb FS 13/' \
    "make declared_vs_performed" "red on the Env and FS absorption rows and on no other row" "✗ absorption of '(Env|FS)' moved"
# m2: the hook-scope fixture's atom count for skills, one too many.
run m2 tools/ext_ambient_inventory/fixtures/hook_scope/expected.json 's/^      "skills": 2,$/      "skills": 3,/' \
    "make ext_hook_scope_selftest" "the atom-count row names skills: 3 expected, 2 derived" "'skills': 3.*derived.*'skills': 2"
# m3: driver_plus_no_ops's omitted count, one short. Run twice: the module's
# inline tests directly, and through `make test_coverage`. NOT through
# `make driver_plus_no_ops`: its recipe runs the module's tests last, and at
# this commit the guard before them stops on test_dummy, so that target never
# reaches them (the first version of this script found that out by matching
# the guard's own FAIL line).
M3='s/List.length(d.omitted_extensions) == 16/List.length(d.omitted_extensions) == 15/'
run m3a src/core/dst_driver_plus_no_ops.ail "$M3" \
    "ailang test src/core/dst_driver_plus_no_ops.ail" "the inline partition test fails" "test_installed_and_omitted_are_disjoint.*(FAIL|fail|✗)|✗.*test_installed_and_omitted_are_disjoint|[1-9][0-9]* failed"
run m3b src/core/dst_driver_plus_no_ops.ail "$M3" \
    "make test_coverage" "test_coverage is red and names the module" "dst_driver_plus_no_ops"
git status --short --untracked-files=no
