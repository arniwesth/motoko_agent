#!/usr/bin/env bash
# expose.sh — make the REAL path_up / find_entry (core) and ev_path_up / ev_find_entry (eval
# twin) callable from a harness. AILANG refuses to import a non-exported function, even under
# --relax-modules ("undefined variable: path_up"), so this writes, at every run, a copy of each
# module taken byte-for-byte from the tree, with exactly two kinds of change:
#   * the `module` line renamed (gen/…), and
#   * `export ` prefixed to the named function declarations.
# The diff guard below fails (exit 3) if anything else differs, so the function BODIES under
# test are the tree's own bytes, re-read every run: editing the tree is seen by the next run.
#
#   expose.sh <tree root> <out root>
set -euo pipefail
tree="$(cd "$1" && pwd)"; out="$(cd "$2" && pwd)"
mkdir -p "$out/gen"

gen() {  # gen <src rel> <old module> <new module> <file> <func>...
  local rel="$1" src="$tree/$1" old="$2" new="$3" dst="$out/gen/$4"; shift 4
  local tmpf="$dst.tmp.$$"   # written aside and renamed, so concurrent runs never read a half file
  local sedargs=(-e "s#^module $old\$#module $new#")
  for f in "$@"; do sedargs+=(-e "s#^pure func $f(#export pure func $f(#"); done
  sed "${sedargs[@]}" "$src" > "$tmpf"
  # Guard: the only changed lines are the module line and one line per exposed function.
  local want=$(( 1 + $# )) got
  got=$(diff "$src" "$tmpf" | grep -c '^>' || true)
  if [[ "$got" -ne "$want" ]]; then
    echo "expose.sh: $rel: expected $want changed lines, got $got" >&2; diff "$src" "$tmpf" >&2 || true; rm -f "$tmpf"; exit 3
  fi
  if diff "$src" "$tmpf" | grep '^>' | grep -vqE "^> (module $new|export pure func ($(IFS='|'; echo "$*"))\()"; then
    echo "expose.sh: $rel: unexpected change" >&2; rm -f "$tmpf"; exit 3
  fi
  mv -f "$tmpf" "$dst"
}

gen src/core/journal.ail src/core/journal gen/core_journal_exposed core_journal_exposed.ail \
  path_up find_entry contains_string
gen src/eval/journal/reader.ail src/eval/journal/reader gen/eval_reader_exposed eval_reader_exposed.ail \
  ev_path_up ev_find_entry ev_contains_string
