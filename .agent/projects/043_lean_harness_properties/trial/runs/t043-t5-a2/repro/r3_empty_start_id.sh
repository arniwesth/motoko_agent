#!/usr/bin/env bash
# A2-T5-3 (P5.3): an entry whose id is "" is named by the start "", but path_up's first test
# (`if id == "" then acc`) returns [] before looking it up. Shared by the eval twin.
# Exit 1 while path_up(es, "", [], []) is [] for es = [{id:"", parent_id:""}].
source "$(dirname "$0")/_common.sh"
direct r3 '<|' 'x<,<x|'
cat "$tmp/r3.out"
TWIN_GATE=0 bun "$out/harness/check.ts" "$tmp/r3.cases" "$tmp/r3.out"
