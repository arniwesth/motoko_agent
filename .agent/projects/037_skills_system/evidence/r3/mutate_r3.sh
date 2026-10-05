#!/usr/bin/env bash
# 037 R3 evidence: one mutant per rule LEG-R3 fixed, to show that the committed
# check for that rule fails when the rule is broken.
#
#   bash mutate_r3.sh <out dir>          the run
#   DRY=1 bash mutate_r3.sh <out dir>    apply, type-check and restore each
#                                        mutant; run no check, write no table
#
# How a kill counts (LEG-R3, "Mutation check"):
#   - Every mutant names, here in this file and so before the run, the
#     committed check or checks expected to fail.
#   - It is KILLED only when the command exits non-zero and every named check
#     is on a failure line of its output (`FAIL ...` from the suite, `✗ ...`
#     from `ailang test` and from `make verify_skills_tests`).
#   - A mutant that does not type-check is `compile error`, the runner's own
#     limit is `runner timeout`, and a non-zero exit without the named check is
#     `other check failed`. None of those is a kill.
#   - Whatever else failed beside the named check is written down.
#
# The unmutated source runs first and must be green. Each mutant is one exact
# replacement in one tracked file, restored with `git checkout` straight after
# its run; the tree must be clean before and is checked clean after. Logs go
# under <out dir>, the table to <out dir>/../mutants.tsv.
set -u
OUT=${1:?out dir}
DRY=${DRY:-0}
ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
[ -z "$(git status --short --untracked-files=no)" ] || { echo "tracked changes present; refusing"; exit 1; }
TSV="$OUT/../mutants.tsv"
RUNNER_LIMIT=1500   # seconds, for one command

quiet_env() {  # the credential variables removed, as evidence/p6/run_gates.sh does
  env -u ANTHROPIC_API_KEY -u AWS_BEARER_TOKEN_BEDROCK -u CLAUDE_CODE_MESSAGING_TOKEN -u EXA_API_KEY \
      -u GH_TOKEN -u GOOGLE_API_KEY -u LINEAR_API_KEY -u MOTOKO_BOT_GH_TOKEN -u OBSIDIAN_MCP_TOKEN \
      -u OPENAI_API_KEY -u OPENROUTER_API_KEY "$@"
}

SUITE="make verify_skills_refusal"
TARGET="make verify_skills_tests"
unit() { printf 'ailang test --no-color %s' "$1"; }
PKG=packages/motoko-ext-skills
PROFILES="dst_driver_only dst_driver_plus_no_ops dst_driver_plus_compose dst_driver_plus_herdr"

# ---- the unmutated source first ----------------------------------------------

green() {  # id, command
  quiet_env bash -c "$2" > "$OUT/baseline_$1.log" 2>&1 < /dev/null; local rc=$?
  echo "exit=$rc" >> "$OUT/baseline_$1.log"
  printf 'baseline %-28s exit=%s  %s\n' "$1" "$rc" "$(grep -E '^[0-9]+ tests:|^verify_skills_refusal:' "$OUT/baseline_$1.log" | tr '\n' ' ')"
  [ "$rc" -eq 0 ] || { echo "the unmutated source is not green on: $2"; exit 1; }
}

if [ "$DRY" != 1 ]; then
  git rev-parse HEAD > "$OUT/HEAD.txt"
  printf 'id\trule\tfile\tchange\tcommand\tcheck expected to fail\texit\tresult\tobserved\n' > "$TSV"
  green verify_skills_tests "$TARGET"
  green verify_skills_refusal "$SUITE"
  green registry_normalize "$(unit src/core/ext/registry_normalize.ail)"
  for m in $PROFILES; do green "$m" "$(unit "src/core/$m.ail")"; done
fi

# ---- one mutant ----------------------------------------------------------------

# id, rule, what the change is in words, file, old text, new text, command,
# then each check expected to fail (a fixed string, looked for on failure lines).
mutant() {
  local id=$1 rule=$2 words=$3 file=$4 old=$5 new=$6 cmd=$7; shift 7
  python3 - "$file" "$old" "$new" <<'PY' || { echo "$id: the edit did not apply exactly once"; git checkout -q -- "$file"; exit 1; }
import sys
from pathlib import Path
path, old, new = sys.argv[1:4]
text = Path(path).read_text()
if text.count(old) != 1:
    sys.exit(1)
Path(path).write_text(text.replace(old, new))
PY
  if git diff --quiet -- "$file"; then echo "$id: the edit changed nothing"; exit 1; fi
  git diff -- "$file" > "$OUT/$id.diff"

  local rc="-" result observed="" compiled=yes
  AILANG_RELAX_MODULES=1 ailang check "$file" > "$OUT/$id.check.log" 2>&1 < /dev/null || compiled=no
  if [ "$compiled" = no ]; then
    result="compile error"; observed=$(grep -m1 -i 'error' "$OUT/$id.check.log" | cut -c1-200)
  elif [ "$DRY" = 1 ]; then
    result="dry: applies and type-checks"
  else
    quiet_env timeout -k 10 "$RUNNER_LIMIT" bash -c "$cmd" > "$OUT/$id.log" 2>&1 < /dev/null; rc=$?
    echo "exit=$rc" >> "$OUT/$id.log"
    local failures named=0 missing="" c
    failures=$(grep -E '^FAIL |^ *✗ ' "$OUT/$id.log" | grep -vE '✗ (Failed:|Some tests failed)')
    for c in "$@"; do
      if printf '%s\n' "$failures" | grep -qF -- "$c"; then named=$((named + 1)); else missing="$missing [$c]"; fi
    done
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then result="runner timeout"
    elif [ "$rc" -eq 0 ]; then result="SURVIVED"
    elif [ "$named" -eq $# ]; then result="killed"
    else result="other check failed; the named check did not:$missing"; fi
    observed="$(grep -E '^[0-9]+ tests:|^verify_skills_refusal:' "$OUT/$id.log" | tr '\n' ' '); failure lines: $(printf '%s\n' "$failures" | sed 's/^ *//' | cut -c1-170 | paste -sd'|' | sed 's/|/ | /g')"
  fi

  git checkout -q -- "$file"
  git diff --quiet -- "$file" || { echo "$id: $file was not restored"; exit 1; }
  printf '%-4s %-22s exit=%-3s %s\n' "$id" "$(basename "$file")" "$rc" "$result"
  [ "$DRY" = 1 ] || printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rule" "$file" "$words" "$cmd" "$(printf '%s; ' "$@" | sed 's/; $//')" "$rc" "$result" "$observed" >> "$TSV"
}

# ---- F-A: a SKILL.md that is not a regular file refuses; it does not hang ------

# REQUIRED. Without the guard the read of the pipe blocks. The suite stops that
# start at START_TIMEOUT and fails the case, so the named check fails on the
# suite's own timeout, in the suite's words; the runner's limit is not reached.
mutant a1 "F-A: SKILL.md is read only when it is a regular file" \
  "the isFile guard removed" \
  $PKG/register.ail \
  '    else if not isFile(skill_md_path(entry)) then DirUnreadableSkillMd(entry, "it is not a regular file, or is a symlink that does not lead to one inside the working directory")
' '' \
  "$SUITE" \
  "refused  V3 SKILL.md is a named pipe"

# std/fs has no lstat, so a mutant cannot tell a symlink from what it leads to:
# this one names the fixture's entry.
mutant a2 "F-A: a SKILL.md that is a relative symlink to a regular file inside the workdir still loads" \
  "the guard also refuses the entry whose SKILL.md is a symlink (named: std/fs cannot tell)" \
  $PKG/register.ail \
  'else if not isFile(skill_md_path(entry)) then' \
  'else if not isFile(skill_md_path(entry)) || entry == "mdlink" then' \
  "$SUITE" \
  "started  a SKILL.md that is a relative symlink to a regular file inside the workdir"

# ---- F-C: the sandbox flag and the real handler path -------------------------

# REQUIRED.
mutant c1 "F-C / D7: registration records whether the sandbox variable was set" \
  "sandbox_set forced to true" \
  $PKG/register.ail \
  'let sandbox_set = getEnvOr(sandbox_variable(), "") != "";' \
  'let sandbox_set = true;' \
  "$SUITE" \
  "D7: unsandboxed, the registration's config record says the sandbox was not set" \
  "D7: unsandboxed with an absolute workdir that is not the process's directory, a Skill call returns D7's error and loads nothing"

# REQUIRED.
mutant c2 "F-C / D7: registration reads the sandbox variable by its name" \
  "the sandbox variable's name misspelt" \
  $PKG/register.ail \
  'pure func sandbox_variable() -> string { "AILANG_FS_SANDBOX" }' \
  'pure func sandbox_variable() -> string { "AILANG_FS_SANDBOXX" }' \
  "$SUITE" \
  "D7: under the sandbox, the registration's config record says the sandbox was set" \
  "A9: sandboxed, a valid skill loads: the directory line, then the file as it is on disk"

mutant c3 "F-C / D7: an unsandboxed start with a workdir elsewhere returns D7's error on a Skill call" \
  "the handler's launch check always says no" \
  $PKG/register.ail \
  'if config_sandbox_set(cfg) then false else workdir != "."' \
  'false' \
  "$SUITE" \
  "D7: unsandboxed with an absolute workdir that is not the process's directory, a Skill call returns D7's error and loads nothing"

mutant c4 "F-C / A9: a valid skill loads and its result begins with the directory line" \
  "the result is the file with no directory line" \
  $PKG/skills.ail \
  'concat([skill_dir(dir_name), "\n", text])' \
  'text' \
  "$SUITE" \
  "A9: sandboxed, a valid skill loads: the directory line, then the file as it is on disk"

mutant c5 "F-C / A9: a name not in the index returns the error that lists the names" \
  "the unknown-name error lists no names" \
  $PKG/register.ail \
  "_ => concat([\"Unknown skill '\", wanted, \"'. Valid names: \", join(\", \", names), \".\"])" \
  "_ => concat([\"Unknown skill '\", wanted, \"'.\"])" \
  "$SUITE" \
  "A9: sandboxed, a name not in the index is an error that lists the nine names"

# ---- F-E: the symlink control checks the index ---------------------------------

# Named for the same reason as a2.
mutant e1 "F-E: a skill directory reached through a relative symlink inside the workdir is indexed" \
  "discovery skips the symlinked entry (named: std/fs cannot tell)" \
  $PKG/register.ail \
  'n :: rest => read_entry(n) :: read_entries(rest)' \
  'n :: rest => if n == "inlink" then read_entries(rest) else read_entry(n) :: read_entries(rest)' \
  "$SUITE" \
  "the symlinked skill is in the index and the enum"

# ---- F-D: each profile names the extensions it omits ---------------------------

# REQUIRED: `skills` renamed in each of the four profile modules.
i=1
for m in $PROFILES; do
  mutant "d$i" "F-D: $m names skills in its omitted list" \
    "skills renamed to skills_typo in the omitted list" \
    "src/core/$m.ail" \
    'extension_id: "skills"' 'extension_id: "skills_typo"' \
    "$(unit "src/core/$m.ail")" \
    "test_skills_and_ailang_tools_are_omitted_by_name"
  i=$((i + 1))
done
for m in $PROFILES; do
  mutant "d$i" "F-D: $m names ailang_tools in its omitted list" \
    "ailang_tools renamed to ailang_tools_typo in the omitted list" \
    "src/core/$m.ail" \
    'extension_id: "ailang_tools"' 'extension_id: "ailang_tools_typo"' \
    "$(unit "src/core/$m.ail")" \
    "test_skills_and_ailang_tools_are_omitted_by_name"
  i=$((i + 1))
done

# ---- F-B: the make target reads a failing test ---------------------------------

# Not one of the four fixes the brief asks mutants for. It shows that the new
# target goes red on a broken rule of the package (REVIEW-003's mutant 3, V5).
mutant b1 "F-B: make verify_skills_tests fails when a package test fails" \
  "V5 no longer compares name with the directory name" \
  $PKG/skills.ail \
  'broken: s != dir_name,' 'broken: false,' \
  "$TARGET" \
  "packages/motoko-ext-skills/skills.ail"

echo "tracked changes after the run: '$(git status --short --untracked-files=no)'"
[ -z "$(git status --short --untracked-files=no)" ]
