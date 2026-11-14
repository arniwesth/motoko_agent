#!/usr/bin/env bash
# gen_exports.sh — make the REAL `path_up`/`find_entry` (src/core/journal.ail) and their twins
# `ev_path_up`/`ev_find_entry` (src/eval/journal/reader.ail) callable from a harness.
#
# Both pairs are module-private (`pure func`, no `export`). AILANG v0.54.14 accepts a private
# name in an import list but the name is then undefined at the call site (checked: "undefined
# variable: path_up"), so a harness cannot reach them through the original modules. This script
# copies each module BYTE FOR BYTE from the tree into out/gen/, and changes exactly three lines:
#
#   module src/core/journal          -> module gen/journal_t5
#   pure func find_entry(            -> export pure func find_entry(
#   pure func path_up(               -> export pure func path_up(
#
# (and the same three for reader.ail: module, ev_find_entry, ev_path_up). The bodies are not
# touched; the script refuses (exit 2) if the diff against the tree is anything else, so a harness
# can never run against a stale or edited copy. Re-run on every harness invocation; it is cheap.
#
# Layout it relies on (all inside out/):
#   ailang.toml / ailang.lock  a manifest whose only dependency is ../tree/packages/motoko-ext-abi
#                              (journal.ail imports pkg/sunholo/motoko_ext_abi/types)
#   src -> ../tree/src         a symlink, so `import src/core/...` resolves to the tree's own files
#                              when ailang runs with out/ as its working directory
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$here/../tree" && pwd)"
mkdir -p "$here/gen"
[[ -L "$here/src" ]] || ln -sfn ../tree/src "$here/src"

gen() { # <tree file> <gen file> <old module> <new module> <fn1> <fn2>
  local src="$tree/$1" dst="$here/$2"
  sed -e "s#^module $3\$#module $4#" \
      -e "s#^pure func $5(#export pure func $5(#" \
      -e "s#^pure func $6(#export pure func $6(#" "$src" > "$dst.tmp"
  # Exactly three changed lines, and they are the three above.
  local d changed
  d="$(diff "$src" "$dst.tmp" || true)"
  changed="$(grep -c '^>' <<< "$d" || true)"
  if [[ "$changed" != "3" ]] \
     || ! grep -q "^> module $4\$" <<< "$d" \
     || ! grep -q "^> export pure func $5(" <<< "$d" \
     || ! grep -q "^> export pure func $6(" <<< "$d"; then
    echo "gen_exports: unexpected diff for $1 ($changed lines changed)" >&2
    echo "$d" >&2
    rm -f "$dst.tmp"; exit 2
  fi
  mv "$dst.tmp" "$dst"
}

gen src/core/journal.ail         gen/journal_t5.ail src/core/journal         gen/journal_t5 find_entry    path_up
gen src/eval/journal/reader.ail  gen/reader_t5.ail  src/eval/journal/reader  gen/reader_t5  ev_find_entry ev_path_up
