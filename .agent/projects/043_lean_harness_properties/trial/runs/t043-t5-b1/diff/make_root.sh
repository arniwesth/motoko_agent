#!/usr/bin/env bash
# make_root.sh — build an AILANG package root OUTSIDE the tree, so that harness modules can
# import `src/core/journal` without writing anything into the tree.
#
#   make_root.sh <tree> <root> real          src/ is a symlink to <tree>/src: the real,
#                                            unmodified journal.ail (used by the repros)
#   make_root.sh <tree> <root> shim          src/core/journal.ail is a COPY in which only
#                                            `contains_string`, `find_entry` and `path_up`
#                                            gain the `export` keyword (the differential test:
#                                            AILANG refuses to import a non-exported name)
#   make_root.sh <tree> <root> shim <mutant> as `shim`, plus one planted mutant (negative
#                                            control): fix | find_last | no_seen
#
# The shim is checked: apart from the mutant, `diff` against the tree's journal.ail must show
# exactly three changed lines, each the original line with `export ` prepended. Anything else
# exits 3.
set -euo pipefail
tree="$(cd "$1" && pwd)"; root="$2"; mode="$3"; mutant="${4:-}"
rm -rf "$root"; mkdir -p "$root"
cp "$tree/ailang.toml" "$tree/ailang.lock" "$root/"
ln -s "$tree/packages" "$root/packages"
if [[ "$mode" == real ]]; then
  ln -s "$tree/src" "$root/src"
  exit 0
fi
mkdir -p "$root/src/core"
for f in "$tree"/src/*; do [[ "$(basename "$f")" == core ]] || ln -s "$f" "$root/src/$(basename "$f")"; done
for f in "$tree"/src/core/*; do [[ "$(basename "$f")" == journal.ail ]] || ln -s "$f" "$root/src/core/$(basename "$f")"; done
j="$root/src/core/journal.ail"
sed -e 's/^pure func contains_string(/export pure func contains_string(/' \
    -e 's/^pure func find_entry(/export pure func find_entry(/' \
    -e 's/^pure func path_up(/export pure func path_up(/' "$tree/src/core/journal.ail" > "$j"
# The export-only check, before any mutant.
changed=$(diff "$tree/src/core/journal.ail" "$j" | grep -c '^>' || true)
bad=$(diff "$tree/src/core/journal.ail" "$j" | grep '^>' | grep -vcE '^> export pure func (contains_string|find_entry|path_up)\(' || true)
if [[ "$changed" -ne 3 || "$bad" -ne 0 ]]; then echo "make_root: shim is not export-only ($changed lines, $bad bad)" >&2; exit 3; fi
case "$mutant" in
  "") ;;
  fix)       # the repeated-id branch returns the accumulated path (D4 rule 1, the eval twin)
    sed -i 's/else if contains_string(seen, id) then \[\]/else if contains_string(seen, id) then acc/' "$j" ;;
  find_last) # find_entry keeps searching and returns the LAST entry with the id
    sed -i 's/e :: rest => if e.id == id then Some(e) else find_entry(rest, id)/e :: rest => match find_entry(rest, id) { None => if e.id == id then Some(e) else None, Some(x) => Some(x) }/' "$j" ;;
  no_seen)   # the seen list is never extended (a cycle would not terminate; bounded by depth)
    sed -i 's/Some(e) => path_up(es, e.parent_id, id :: seen, e :: acc)/Some(e) => if List.length(acc) > 12 then acc else path_up(es, e.parent_id, seen, e :: acc)/' "$j" ;;
  *) echo "make_root: unknown mutant $mutant" >&2; exit 3 ;;
esac
if [[ -n "$mutant" ]] && cmp -s "$j" <(sed -e 's/^pure func contains_string(/export pure func contains_string(/' -e 's/^pure func find_entry(/export pure func find_entry(/' -e 's/^pure func path_up(/export pure func path_up(/' "$tree/src/core/journal.ail"); then
  echo "make_root: mutant $mutant did not apply" >&2; exit 3
fi
