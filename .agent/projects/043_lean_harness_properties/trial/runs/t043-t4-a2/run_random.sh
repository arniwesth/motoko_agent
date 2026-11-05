#!/usr/bin/env bash
# run_random.sh — the random_chain.ts batch recorded in SUMMARY.md. From the tree root:
#   bash ../out/run_random.sh
# Writes one file per (package, seed, size) under ../out/runs/.
set -u
OUT="$(cd "$(dirname "$0")" && pwd)"
for pkg in pkg pkg_fixed; do
  for spec in "1 60 24" "2 60 24" "3 60 24" "4 60 24" "11 12 64"; do
    set -- $spec
    f="$OUT/runs/random.$pkg.seed$1.n$2.len$3.out"
    T4_PKG="$OUT/$pkg" bun "$OUT/random_chain.ts" "$1" "$2" "$3" > "$f" 2>&1
    echo "exit=$?" >> "$f"
    head -1 "$f"; tail -1 "$f"
  done
done
