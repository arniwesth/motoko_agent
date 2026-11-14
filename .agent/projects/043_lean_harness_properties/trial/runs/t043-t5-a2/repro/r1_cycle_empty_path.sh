#!/usr/bin/env bash
# A2-T5-1 (P5.3): on a parent cycle, path_up returns [] although the start id names an entry,
# so the result's last entry is not the start (ADR-003 D4 rule 1 says to stop at the first
# repeated id and keep the path). Witnesses: a self-parent, a 2-cycle, and a 3-cycle in the
# host's id shape. Exit 1 while path_up returns [] (or disagrees with ev_path_up) on any of them.
source "$(dirname "$0")/_common.sh"
direct r1 'a<a|a' 'a<b,b<a|a' '000000<000002,000001<000000,000002<000001|000002'
cat "$tmp/r1.out"
bun "$out/harness/check.ts" "$tmp/r1.cases" "$tmp/r1.out"
