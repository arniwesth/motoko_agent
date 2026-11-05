#!/usr/bin/env bash
# repro.sh <report id>   — run from the tree root.
#
# Writes the report's witness as a one-case (or few-case) cases file, runs it through the real
# code (run_direct.sh: the real truncate_utf8_by_bytes behind a one-word export shim;
# run_caller.sh: the real exported store_stdout_and_elide; twins.ts: the real TS twins), and
# lets check.ts decide. Exit 1: the defect is present. Exit 0: absent. Exit 2/3: harness error.
set -uo pipefail
id="${1:?usage: repro.sh <report id>}"
here="$(cd "$(dirname "$0")" && pwd)"
h="$here/../harness"
tree="$(pwd)"
[[ -f "$tree/packages/motoko-ext-compose/store.ail" ]] || { echo "repro.sh: run from the tree root" >&2; exit 2; }
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
c="$work/cases"

direct() { bash "$h/direct/run_direct.sh" "$c" "$work" > "$work/direct.out" || exit 2; }
caller() { bash "$h/caller/run_caller.sh" "$c" "$work" > "$work/caller.out" || exit 2; }
check() { bun "$h/check.ts" "$tree" "$c" "$@"; }

case "$id" in
  A1-T6-1)        # P6.1 on the real truncate_utf8_by_bytes: "éé" (c3 a9 c3 a9), max_bytes 2
    echo "195,169,195,169|2" > "$c"; direct
    check --direct "$work/direct.out" --fail-on ail:P6.1 ;;
  A1-T6-1-caller) # the same defect through the real exported store_stdout_and_elide, at
                  # compose's default cap: 1400 x U+6F22 (4200 bytes), max_stdout_bytes 4000
    bun "$h/gen.ts" cjk 1400 | grep '|4000$' > "$c"; direct; caller
    check --direct "$work/direct.out" --caller "$work/caller.out" --fail-on ailcaller:P6.1 ;;
  A1-T6-2)        # P6.3 (K2) on the real truncate_utf8_by_bytes: "éa" (c3 a9 61), max_bytes 1
    echo "195,169,97|1" > "$c"; direct
    check --direct "$work/direct.out" --fail-on ail:P6.3 ;;
  A1-T6-3)        # X-4 on compose-claimcheck.ts truncateUtf8ByBytes, directly and through the
                  # exported runClaimCheck: "é" (c3 a9), maxBytes 1
    echo "195,169|1" > "$c"
    check --twins --runclaimcheck --fail-on tsclaim:X-4,tsrun:X-4 ;;
  A1-T6-4)        # X-4 on env-server.ts truncateUtf8ByBytes: "é" (c3 a9), maxBytes 1
    echo "195,169|1" > "$c"
    check --twins --fail-on tsenv:X-4 ;;
  A1-T6-5)        # X-2 on compose-claimcheck.ts: omittedBytes, through runClaimCheck: "é", 1
    echo "195,169|1" > "$c"
    check --twins --runclaimcheck --fail-on tsclaim:X-2,tsrun:X-2 ;;
  *) echo "repro.sh: unknown report id $id" >&2; exit 2 ;;
esac
