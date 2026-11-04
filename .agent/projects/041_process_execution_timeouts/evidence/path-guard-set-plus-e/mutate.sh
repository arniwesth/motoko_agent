#!/usr/bin/env bash
# The path guard's `set +e`: break each rule once and see the probe's own row go red.
# Run from the worktree root on a commit whose src and scripts are clean:
#   mutate.sh <log directory>
# Writes mutants.tsv and commit there, and leaves each row's raw output beside them.
#
# Every row runs `make verify_native_path_guard` from a clean environment, because the bug depended
# on the caller's. PATH has to name ailang's directory: without it make's recipe exits 127 before
# the guard runs, and that failure looks like this one.
#
# A row names one probe row and predicts its verdict on each leg:
#   m1   no `set +e` at the 43 site         all six: unset red, SHLVL=1 green
#   m2   no `set +e` at the 44 site         all six: both green. Predicted to SURVIVE, see below
#   m2a  43 arm disabled, 44 site as fixed  ReadFile: both green. The 44 arm alone refuses
#   m2b  43 arm disabled, no `set +e` at 44 ReadFile: unset red, SHLVL=1 green
#   m3   `exit 43` becomes `exit 0`         all six: both red
#   m4   no edit                            all six: both green
#
# m2 survives because the 44 arm is unreachable here. For a path where `[ -e ]` is true,
# `realpath -m` and `realpath` give the same answer, so the 43 arm has already refused it. Only a
# race between the two calls could reach 44. m2a and m2b disable the 43 arm so the 44 site is tested
# at all: m2a shows that arm refuses, m2b shows `set +e` is what keeps its code.
#
# m2a and m2b read the ReadFile row, not "all six". With the 43 arm gone the WriteFile rows go red on
# both legs, because link/planted.txt does not exist, `[ -e ]` is false, and the 44 arm never runs.
# The first version of this script predicted all six green for m2a and was wrong for that reason.
set -u
OUT=${1:?log directory}
M=src/core/tool_runtime.ail
CLEAN_PATH=$(dirname "$(command -v ailang)"):/usr/local/bin:/usr/bin:/bin
[ -z "$(git status --porcelain -- src scripts)" ] || { echo "src or scripts dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
echo "$COMMIT" >"$OUT/commit"
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\tprobe_row\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

restore() { git checkout -q -- "$M"; }
trap restore EXIT

edit() { # old new: exactly one occurrence, or the row tests nothing
  python3 - "$M" "$1" "$2" <<'PY' || { echo "edit did not apply: $1"; exit 2; }
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if s.count(old) != 1:
    sys.exit(1)
open(p, "w").write(s.replace(old, new))
PY
}

leg() { # log label row-text -> green|red|absent
  if grep -qF "OK: [SHLVL $2] $3" "$1"; then echo green
  elif grep -qF "FAIL: [SHLVL $2] $3" "$1"; then echo red
  else echo absent; fi
}

ALL="all six checks ran and passed"
READ="ReadFile through a symlink out of the workdir is refused"

row() { # id rule edit probe-row want-unset want-one verdict-if-as-predicted
  local id=$1 rule=$2 desc=$3 needle=$4 want_u=$5 want_1=$6 good=$7 log=$OUT/$1.log u one verdict
  env -i PATH="$CLEAN_PATH" HOME="$HOME" make verify_native_path_guard >"$log" 2>&1
  local rc=$?
  u=$(leg "$log" unset "$needle"); one=$(leg "$log" 1 "$needle")
  verdict=$good
  [ "$u" = "$want_u" ] && [ "$one" = "$want_1" ] || verdict=NOT-AS-PREDICTED
  # make must agree with the legs: it passes only when both legs ran all six and passed.
  local both=no
  [ "$(leg "$log" unset "$ALL")" = green ] && [ "$(leg "$log" 1 "$ALL")" = green ] && both=yes
  if [ "$both" = yes ]; then [ "$rc" = 0 ] || verdict=NOT-AS-PREDICTED
  else [ "$rc" != 0 ] || verdict=NOT-AS-PREDICTED; fi
  printf '%s\t%s\t%s\t%s\tunset=%s,one=%s\t%s\tunset=%s,one=%s,make=%s\t%s\n' \
    "$id" "$rule" "$desc" "$needle" "$want_u" "$want_1" "$COMMIT" "$u" "$one" "$rc" "$verdict" >>"$TSV"
  restore
}

SITE43='*) set +e; exit 43 ;;'
SITE44='*) set +e; exit 44 ;;'

edit "$SITE43" '*) exit 43 ;;'
row m1 "set +e keeps the 43 verdict" "remove set +e at the 43 site" "$ALL" red green killed

edit "$SITE44" '*) exit 44 ;;'
row m2 "set +e keeps the 44 verdict" "remove set +e at the 44 site" "$ALL" green green survived

edit "$SITE43" '*) ;;'
row m2a "the 44 arm refuses by itself" "43 arm falls through; 44 site as fixed" "$READ" green green passed

edit "$SITE43" '*) ;;'
edit "$SITE44" '*) exit 44 ;;'
row m2b "set +e keeps the 44 verdict" "43 arm falls through; remove set +e at the 44 site" "$READ" red green killed

edit "$SITE43" '*) set +e; exit 0 ;;'
row m3 "the rows read the verdict" "exit 43 becomes exit 0" "$ALL" red red killed

row m4 "survival control" "no edit" "$ALL" green green passed

cat "$TSV"
