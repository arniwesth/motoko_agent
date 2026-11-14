#!/usr/bin/env bash
# repro.sh — run one T4 repro harness against the tree you are standing in.
#
#   bash ../out/repro.sh <harness> [caps]        (from a tree root; caps default IO)
#
# Builds a throwaway package root under ../out/.run.XXXXXX whose src/, packages/, ailang.toml
# and ailang.lock are symlinks to THE CURRENT DIRECTORY's, copies out/pkg/t4/<harness>.ail into
# it, and runs it with `ailang run --relax-modules`. So the code under test is always the tree
# the command is run from, never a fixed path.
#
# Exit status: 1 if the harness printed its DEFECT marker, 0 if it printed its ABSENT marker,
# 2 for anything else (harness did not compile/run) — a broken harness never reads as a finding.
set -u
TREE="$(pwd -P)"
OUT="$(cd "$(dirname "$0")" && pwd -P)"
name="${1:?usage: repro.sh <harness> [caps]}"
caps="${2:-IO}"
[ -f "$TREE/src/core/journal.ail" ] || { echo "repro.sh: run from the tree root" >&2; exit 2; }
W="$(mktemp -d "$OUT/.run.XXXXXX")"
trap 'rm -rf "$W"' EXIT
ln -s "$TREE/src" "$W/src"
ln -s "$TREE/packages" "$W/packages"
ln -s "$TREE/ailang.toml" "$W/ailang.toml"
ln -s "$TREE/ailang.lock" "$W/ailang.lock"
mkdir "$W/t4" && cp "$OUT/pkg/t4/$name.ail" "$W/t4/"
log="$W/run.log"
ailang run --relax-modules --caps "$caps" --chdir "$W" --entry main "t4/$name.ail" > "$log" 2>&1
grep -v "^Warning: dependency\|^Run 'ailang lock\|MOD010\|relax-modules flag" "$log"
if grep -q "VIOLATED\|COLLISION\|X-1: chain_digests_over is more" "$log"; then exit 1; fi
if grep -q "holds on this witness\|X-9: no collision\|X-1: within 2x" "$log"; then exit 0; fi
echo "repro.sh: harness produced neither marker" >&2
exit 2
