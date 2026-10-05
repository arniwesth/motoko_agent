#!/usr/bin/env bash
# 037 R3 evidence, after the second review: the one mutant that round found
# surviving every committed check, against the inline test that now names its
# case.
#
#   bash mutate_r3_second_review.sh <out dir>          the run
#   DRY=1 bash mutate_r3_second_review.sh <out dir>    apply, type-check and
#                                                      restore; run no check
#
# The kill rule is mutate_r3.sh's: the check expected to fail is named here,
# before the run; the mutant is KILLED only when the command exits non-zero and
# that check is on a failure line of its output; a mutant that does not
# type-check, the runner's own limit, and a non-zero exit without the named
# check are each recorded as what they are.
#
# The unmutated source runs first and must be green on the two make targets.
# The row is appended to <out dir>/../mutants.tsv.
set -u
OUT=${1:?out dir}
DRY=${DRY:-0}
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
[ -z "$(git status --short --untracked-files=no)" ] || { echo "tracked changes present; refusing"; exit 1; }
TSV="$OUT/../mutants.tsv"

quiet_env() {
  env -u ANTHROPIC_API_KEY -u AWS_BEARER_TOKEN_BEDROCK -u CLAUDE_CODE_MESSAGING_TOKEN -u EXA_API_KEY \
      -u GH_TOKEN -u GOOGLE_API_KEY -u LINEAR_API_KEY -u MOTOKO_BOT_GH_TOKEN -u OBSIDIAN_MCP_TOKEN \
      -u OPENAI_API_KEY -u OPENROUTER_API_KEY "$@"
}

ID=c6
RULE="D7: an unsandboxed start with a relative workdir other than \`.\` returns D7's error on a Skill call"
WORDS="the launch check asks whether the workdir is absolute, not whether it is other than \`.\`"
FILE=packages/motoko-ext-skills/register.ail
OLD='if config_sandbox_set(cfg) then false else workdir != "."'
NEW='if config_sandbox_set(cfg) then false else startsWith(workdir, "/")'
CMD="ailang test --no-color $FILE"
NAMED="test_d7_unsandboxed_launch_with_another_workdir_does_not_load"

if [ "$DRY" != 1 ]; then
  git rev-parse HEAD > "$OUT/HEAD.txt"
  for target in verify_skills_tests verify_skills_refusal; do
    quiet_env make "$target" > "$OUT/baseline_$target.log" 2>&1 < /dev/null; rc=$?
    echo "exit=$rc" >> "$OUT/baseline_$target.log"
    printf 'baseline %-24s exit=%s  %s\n' "$target" "$rc" "$(grep -E '[0-9]+ tests:|^verify_skills_refusal:' "$OUT/baseline_$target.log" | sed 's/^ *//' | cut -c1-110 | paste -sd'|')"
    [ "$rc" -eq 0 ] || { echo "the unmutated source is not green on make $target"; exit 1; }
  done
fi

python3 - "$FILE" "$OLD" "$NEW" <<'PY' || { echo "$ID: the edit did not apply exactly once"; git checkout -q -- "$FILE"; exit 1; }
import sys
from pathlib import Path
path, old, new = sys.argv[1:4]
text = Path(path).read_text()
if text.count(old) != 1:
    sys.exit(1)
Path(path).write_text(text.replace(old, new))
PY
git diff -- "$FILE" > "$OUT/$ID.diff"

rc="-"; observed=""
if ! AILANG_RELAX_MODULES=1 ailang check "$FILE" > "$OUT/$ID.check.log" 2>&1 < /dev/null; then
  result="compile error"; observed=$(grep -m1 -i 'error' "$OUT/$ID.check.log" | cut -c1-200)
elif [ "$DRY" = 1 ]; then
  result="dry: applies and type-checks"
else
  quiet_env timeout -k 10 600 bash -c "$CMD" > "$OUT/$ID.log" 2>&1 < /dev/null; rc=$?
  echo "exit=$rc" >> "$OUT/$ID.log"
  failures=$(grep -E '^FAIL |^ *✗ ' "$OUT/$ID.log" | grep -vE '✗ (Failed:|Some tests failed)')
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then result="runner timeout"
  elif [ "$rc" -eq 0 ]; then result="SURVIVED"
  elif printf '%s\n' "$failures" | grep -qF -- "$NAMED"; then result="killed"
  else result="other check failed; the named check did not: [$NAMED]"; fi
  observed="$(grep -E '^[0-9]+ tests:' "$OUT/$ID.log" | tr '\n' ' '); failure lines: $(printf '%s\n' "$failures" | sed 's/^ *//' | cut -c1-170 | paste -sd'|' | sed 's/|/ | /g')"
fi

git checkout -q -- "$FILE"
git diff --quiet -- "$FILE" || { echo "$ID: $FILE was not restored"; exit 1; }
printf '%-4s %-22s exit=%-3s %s\n' "$ID" "$(basename "$FILE")" "$rc" "$result"
[ "$DRY" = 1 ] || printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ID" "$RULE" "$FILE" "$WORDS" "$CMD" "$NAMED" "$rc" "$result" "$observed" >> "$TSV"

# The table is tracked and has just gained its row; nothing else may differ.
echo "tracked changes after the run, the table aside: '$(git status --short --untracked-files=no | grep -v 'evidence/r3/mutants.tsv$')'"
