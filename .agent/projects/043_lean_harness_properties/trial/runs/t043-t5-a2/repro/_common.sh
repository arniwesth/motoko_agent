# Sourced by the repro scripts. Run them FROM THE TREE ROOT; the tree is $TREE, else $PWD if it
# holds src/core/journal.ail, else ../tree beside out/. Exit 2 means the harness itself failed.
out="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tree="${TREE:-$PWD}"
[[ -f "$tree/src/core/journal.ail" ]] || tree="$out/../tree"
tmp="$out/runs/tmp"; mkdir -p "$tmp"
direct() {  # direct <name> <case lines…>: run the real path_up / ev_path_up / find_entry, then check.ts
  local name="$1"; shift
  "$out/harness/expose.sh" "$tree" "$out" || exit 2
  printf '%s\n' "$@" > "$tmp/$name.cases"
  ( cd "$out" && timeout 100 ailang run --relax-modules --caps IO --entry main harness/path_direct.ail ) \
    < "$tmp/$name.cases" > "$tmp/$name.out" 2> "$tmp/$name.err"
  grep -q '^END|' "$tmp/$name.out" || { echo "harness failed:"; tail -5 "$tmp/$name.err"; exit 2; }
}
