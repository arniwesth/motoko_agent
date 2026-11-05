# Sourced by the repro scripts. Run them from the TREE ROOT, e.g.
#   bash ../out/repro/repro_P5_3_cycle.sh
# Builds an AILANG package root under ../out/repro/work (nothing is written in the tree),
# copies one harness module into it, and runs it with ailang v0.54.14.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="$(pwd)"
[[ -f "$tree/src/core/journal.ail" ]] || { echo "run from the tree root" >&2; exit 2; }
# REPRO_MUTANT=fix runs the same harness on a shim with the fix planted (make_root.sh), to
# show that the script exits 0 when the defect is absent.
run_harness() {  # run_harness <real|shim> <module.ail> -> prints the harness's lines
  local mode="$1" mod="$2" mut="${REPRO_MUTANT:-}"
  [[ -n "$mut" ]] && mode=shim
  local root="$here/work/${mode}${mut:+_$mut}_$(basename "$2" .ail)"
  bash "$here/../diff/make_root.sh" "$tree" "$root" "$mode" $mut || exit 2
  cp "$here/$mod" "$root/"
  ( cd "$root" && ailang run --relax-modules --caps IO --entry main "$mod" ) 2> "$root/stderr.txt"
}
