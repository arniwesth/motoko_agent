#!/usr/bin/env bash
# p4_1.sh [tree root, default: the current directory] — runs p4_1.ail against the REAL code.
# Exit 1 when the defect is present ("P4.1 VIOLATED"), 0 when absent ("P4.1 holds"),
# 2 when the harness did not run to a verdict.
here="$(cd "$(dirname "$0")" && pwd)"
out="$("$here/../diff/ail_run.sh" "${1:-.}" "$here/p4_1.ail" 2>/dev/null)"
echo "$out"
case "$out" in
  *"P4.1 VIOLATED"*) exit 1 ;;
  *"P4.1 holds"*) exit 0 ;;
  *) echo "no verdict: the harness did not run" >&2; exit 2 ;;
esac
