# common.sh — sourced by the repro scripts. Run them FROM THE TREE ROOT:
#   bash ../out/repro/repro_<name>.sh
# Every ailang run uses the real, unmodified src/core/journal.ail.
set -uo pipefail
REPRO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$(cd "$REPRO/.." && pwd)"
TREE="$(pwd)"
[[ -f "$TREE/src/core/journal.ail" ]] || { echo "run from the tree root"; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ail() { ailang run --relax-modules --package-dir "$TREE" "$@" 2>>"$WORK/ail.err"; }

# path_up_cases <case lines...> : runs the REAL path_up/find_entry/contains_string bodies
# (copied verbatim from src/core/journal.ail at run time by ../diff/build_harness.sh) on the
# given cases, format `<entries>|<start>|<variant>` (../diff/gen_cases.py), and prints
# `<case>|<result seqs>|<length>`.
path_up_cases() {
  printf '%s\n' "$@" > "$WORK/cases.txt"
  "$OUT/diff/build_harness.sh" "$TREE" "$WORK/cases.txt" "$WORK/harness_path_up.ail" 2>"$WORK/bodies.txt"
  sed 's/^/  real body: /' "$WORK/bodies.txt" >&2
  ail --caps IO,FS --entry main "$WORK/harness_path_up.ail" | grep -F '|'
}

# write_base > file : a valid journal from the real writer twin (write_journal.ail).
write_base() { ail --caps IO --entry main "$REPRO/write_journal.ail"; }

# fold_file <path> : the resume path's fold of that file (fold_file.ail).
fold_file() { ail --caps IO,FS --entry main --args-json "\"$1\"" "$REPRO/fold_file.ail"; }
