#!/usr/bin/env bash
#
# The closing summary `make dst` prints, and the reason it exists.
#
# =============================================================================
# What a reader of the raw sweep cannot see
# =============================================================================
#
# The sweep runs 41 targets, 40 of them in parallel under `--output-sync=target`
# and all of them under `--keep-going`. Three things follow, and each of them
# has cost someone a wrong reading of a green-looking run:
#
#   1. THE LAST BLOCK ON SCREEN IS NOT THE FAILING ONE. Output lands per target
#      as each finishes, so a target that failed early can sit hundreds of lines
#      above a passing one. Reading the tail reports whichever target happened
#      to finish last, which is a fact about scheduling and not about the tree.
#
#   2. `Error 2` NAMES NOTHING. Make's exit 2 means "errors were encountered",
#      whether one target failed or ten, and the aggregate line carries the
#      `dst` recipe's own line number rather than any failing target's.
#
#   3. THE STANDING-RED PAIR IS INDISTINGUISHABLE FROM A REGRESSION. On a clean
#      tree the sweep exits 2 because `test_coverage` and
#      `test_coverage_selftest` have been red since D22. A reader who has
#      internalised that stops reading exit codes -- which is exactly when a
#      real regression arrives dressed as the usual noise.
#
# So this prints the failing set, splits it into KNOWN and NEW, and says which
# it is. It is DISCLOSURE AND NOT A WAIVER: the exit code is passed through
# untouched, `make dst` still exits 2 with only the known pair red, and nothing
# here can turn a red sweep green. The split changes what a reader looks at
# first; it does not change what the gate decides.
#
# THE KNOWN LIST IS CHECKED IN BOTH DIRECTIONS. A list of expected failures that
# is only ever consulted when something fails rots silently: the day
# `prompts_test.ail` is repaired, the list still claims it is expected and the
# next reader believes it. So a known-red target that PASSES is reported too,
# with the instruction to drop it. The list may only shrink by being noticed.
#
# =============================================================================
# Why the timing caveat is here and not in a comment
# =============================================================================
#
# The sweep became parallel, so its wall time is now a function of whatever else
# holds the machine. Measured on this tree: 220 s quiet, 348 s alongside two
# live agent processes at load average 13. That is a nuisance for every target
# except one. `corpus_pr`'s PASS CONDITION IS A WALL CLOCK -- it fails itself
# against `pr_target_ceiling_ms()` -- so external load can turn it red without
# anything being wrong with the corpus. It runs alone, before the fan-out, to
# keep that measurement honest, and when it fails on the clock this says so
# rather than leaving the reader to raise the ceiling.
#
# Usage: sweep_summary.sh <log> <exit-code> <elapsed-seconds> <jobs>
#        DST_KNOWN_RED="target ..." in the environment.
set -u

log=${1:?log path}
rc=${2:?exit code}
elapsed=${3:-0}
jobs=${4:-?}
known=${DST_KNOWN_RED:-}

[ -r "$log" ] || { echo "sweep_summary: cannot read $log" >&2; exit 0; }

# Failing targets, as make itself reported them. The aggregate `dst` line is the
# recipe reporting its own propagated status and is not a target failure.
failed=$(sed -n 's/^make\[[0-9]*\]: \*\*\* \[[^]]*: \([A-Za-z0-9_-]*\)\] Error [0-9]*.*/\1/p' "$log" \
         | grep -vx 'dst' | sort -u)

new=""; old=""
for t in $failed; do
	if printf '%s\n' $known | grep -qx "$t"; then old="$old $t"; else new="$new $t"; fi
done

# The reverse direction: a known-red target that is no longer red.
#
# Restricted to targets this run ACTUALLY REQUESTED. "Not in the failed set" and
# "passed" are not the same claim -- a subset run (`make dst DST_TARGETS=...`)
# leaves most targets unrun, and reading their silence as success would tell the
# reader to delete a still-valid entry. A guard that fires on absence of
# evidence is the failure mode the entry itself exists to prevent.
fixed=""
for t in $known; do
	printf '%s\n' ${DST_REQUESTED:-$known} | grep -qx "$t" || continue
	printf '%s\n' $failed | grep -qx "$t" || fixed="$fixed $t"
done

n_failed=$(printf '%s\n' $failed | grep -c . || true)
n_new=$(printf '%s\n' $new | grep -c . || true)

echo
echo "─── make dst ──────────────────────────────────────────────────────────"
printf '  %ss wall, -j%s, load %s\n' "$elapsed" "$jobs" \
	"$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo '?')"
printf '  full log: %s\n' "$log"

if [ "$n_failed" -eq 0 ]; then
	echo "  all targets passed"
else
	echo
	printf '  FAILED (%s):\n' "$n_failed"
	for t in $new; do printf '    %-28s NEW — this one is yours\n' "$t"; done
	for t in $old; do printf '    %-28s known-red since D22\n' "$t"; done
fi

for t in $fixed; do
	echo
	printf '  NOTE: %s is listed in DST_KNOWN_RED but PASSED.\n' "$t"
	echo "        Drop it from that list in the Makefile — an expected-failure"
	echo "        list that outlives the failure teaches the next reader to"
	echo "        ignore a real one."
done

# The clock-gate caveat, only when the clock is what failed.
if printf '%s\n' $failed | grep -qx 'corpus_pr' && grep -q 'against a declared ceiling' "$log"; then
	echo
	echo "  corpus_pr failed on ELAPSED TIME, which measures this machine as much"
	echo "  as the corpus. Check the load above and re-run quiet before touching"
	echo "  the ceiling — and if it is genuinely too tight, re-measure"
	echo "  measured_ms_per_seed() and move the ceiling WITH it (the seed"
	echo "  minimums are arithmetic over that constant)."
fi

if [ "$rc" -ne 0 ]; then
	echo
	if [ "$n_new" -eq 0 ] && [ "$n_failed" -gt 0 ]; then
		printf '  exit %s — no new failures; this is the expected outcome on a clean tree.\n' "$rc"
	else
		printf '  exit %s — make'"'"'s "errors were encountered". See the NEW rows above.\n' "$rc"
	fi
fi
echo "───────────────────────────────────────────────────────────────────────"
