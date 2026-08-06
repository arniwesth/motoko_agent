#!/usr/bin/env bash
# A5's attribution anchors, checked in isolation and without compiling anything.
#
# WHY THIS IS A SEPARATE, FAST TARGET (WI-B4, closing WI-B2a's ask).
#
# The anchors are LINE NUMBERS recorded in `src/core/dst_attribution_table.ail`,
# and any edit that adds or removes a line above one of them moves it. The only
# thing that noticed was `make attribution_table`, which sits deep inside
# `make dst` — and for the whole of Milestone B `make dst` exited 2 before
# reaching it. Nine of the ten anchors were stale at HEAD and nothing said so;
# absent read identically to unchanged, one level above where WI-B1 and WI-B3
# found the same shape.
#
# WI-B2a's repair tool carried a line-count assertion for exactly this reason —
# it refused a `session.ail` rewrite that would have gone 2962 -> 2961 and
# silently moved two anchors — but it lived in a scratchpad script that died
# with its session. This is that guard's durable home, and it is stronger than a
# line COUNT: a count only catches edits that change the total, while this reads
# the anchored lines themselves, so a one-line insertion balanced by a one-line
# deletion above an anchor is caught too.
#
# Run it after any mechanical edit to session.ail, tool_phase.ail, stub_step.ail
# or ext/runtime.ail. It compiles nothing and takes milliseconds, which is the
# point: a guard you can afford to run every round is a guard that runs.
#
# `make attribution_table` sources the same list, so there is exactly one copy.
set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
check() {
  if sed -n "$2p" "$1" | grep -q -- "$3"; then
    echo "  ✓ $1:$2 still $4"
  else
    echo "  ✗ $1:$2 no longer $4 — the attribution table describes a site that moved"
    echo "      expected to find: $3"
    echo "      actual line:      $(sed -n "$2p" "$1")"
    fail=1
  fi
}

echo "attribution anchors:"
check src/core/ext/runtime.ail 190 'now()' "the ambient clock read attributed to test_dummy"
check src/core/tool_phase.ail 313 'is_scratchpad_tool_name' "the mixed guard"
check src/core/tool_phase.ail 314 'exec_scratchpad_cell_ws' "the call attributed to scratchpad"
# WI-C5 RETIRED the session.ail:878 anchor. `ext_unrouted_clock` no longer
# exists: widening ExtPorts.clock_now to thread the world token let
# ext_ports_of route that seam, so the site is not un-routed, it is GONE. Its
# replacement is :881 below, and it is checked as ROUTED rather than as ambient.
check src/core/test/stub_step.ail 203 'now()' "the one remaining ambient clock (declared UNROUTED core)"
for l in 881 1126 1232 2677 2787; do
  check src/core/session.ail "$l" 'clock_now' "a routed core clock site"
done
check src/core/tool_phase.ail 373 'clock_now' "the FIFTH routed core clock site (D4's table says four)"

if [ "$fail" -ne 0 ]; then
  echo
  echo "An anchor moved. Do NOT re-baseline it without deciding which site is 'the'"
  echo "attributed one — that is a D4 judgement with other consumers, and correcting"
  echo "the table re-issues every referring profile (bump driver_only_version and"
  echo "re-record driver_only_attribution_ref)."
  exit 1
fi
