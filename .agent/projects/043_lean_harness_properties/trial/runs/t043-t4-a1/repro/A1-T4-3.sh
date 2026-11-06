#!/usr/bin/env bash
# A1-T4-3: runs out/harness/repro_perf.ail against the REAL src/core/journal.ail.
# Exit 1 when the defect is present (the program prints DEFECT), 0 when absent (OK),
# 2 when the program did not run to a verdict.
# T4_ROOT=<dir> runs it against another package root instead (e.g. out/control-base, the
# negative control built by out/harness/make_control.sh).
here="$(cd "$(dirname "$0")/../harness" && pwd)"
root="${T4_ROOT:-$here}"
[ -e "$root/repro_perf.ail" ] || ln -s "$here/repro_perf.ail" "$root/repro_perf.ail"
out="$(cd "$root" && timeout 115 ailang run --relax-modules --caps IO,Clock --entry main repro_perf.ail 2>&1)"
grep -v "^Warning: dependency\|^Run 'ailang lock'" <<<"$out"
if grep -q '^DEFECT' <<<"$out"; then exit 1; elif grep -q '^OK' <<<"$out"; then exit 0; else exit 2; fi
