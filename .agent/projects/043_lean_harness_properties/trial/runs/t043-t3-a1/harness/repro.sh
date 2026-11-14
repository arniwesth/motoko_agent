#!/usr/bin/env bash
# repro.sh <witness> — one report's repro, from the tree root:
#
#   bash ../out/harness/repro.sh <witness>
#
# Runs the T3 pipeline (run_t3.sh) on ONE case and exits with the selected property's
# verdict on it: 1 when the defect is present, 0 when it is absent. ~15 s unloaded.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
w="${1:-}"
case "$w" in
  # P3.1/P3.2: checkpoint, crash, --resume (same profile), the resumed run appends.
  twin-replaced-since-seed) export T3_OPS=7-9-0 T3_PROP=P3.1 ;;
  # P3.1: plain assistant, hybrid batch head (replaces_previous, calls [a]), crash, --resume, append.
  host-replace-pending)     export T3_OPS=0-6-9-0 T3_PROP=P3.1 ;;
  # X-3 (same root cause): the same journal before the crash; exit.pending_tool_calls vs dangling.
  host-replace-exit-pending) export T3_OPS=0-6 T3_PROP=X-3 ;;
  # P3.1: assistant with calls [a, ""], result for a, crash, --resume, append.
  host-empty-call-id)       export T3_OPS=12-3-9-0 T3_PROP=P3.1 ;;
  # P3.1: checkpoint with first_kept = -1.
  first-kept-negative)      export T3_OPS=14 T3_PROP=P3.1 ;;
  # P3.1: two system messages; checkpoint, two appends, checkpoint with first_kept = 4.
  first-kept-undercount)    export T3_OPS=7-0-0-15 T3_NSYS=2 T3_PROP=P3.1 ;;
  # P3.2: checkpoint, then the follow-up turn (run_summary, user append, next run's seed).
  followup-after-checkpoint) export T3_OPS=7-8 T3_PROP=P3.2 ;;
  # X-2: chain_digests_over ignores its base.
  chain-digests-base)
    "$here/ail_run.sh" "$here/check_chain_digests.ail" 2>/dev/null | tee /dev/stderr | grep -qx OK
    exit $? ;;
  *) echo "usage: repro.sh <witness>; witnesses:"; sed -n 's/^  \([a-z0-9-]*\))  *.*/  \1/p' "$0"; exit 2 ;;
esac
"$here/run_t3.sh"
