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
check src/core/ext/runtime.ail 199 'now()' "the ambient clock read attributed to test_dummy"
check src/core/tool_phase.ail 317 'is_scratchpad_tool_name' "the mixed guard"
check src/core/tool_phase.ail 318 'exec_scratchpad_cell_ws' "the call attributed to scratchpad"
# WI-D16 RE-BASELINED the five session.ail anchors 881/1126/1232/2677/2787 ->
# 911/1160/1266/2711/2821, WI-D17 RE-BASELINED THEM AGAIN to
# 931/1185/1291/2736/2846, and WI-D18 A THIRD TIME to 965/1224/1330/2775/2885 —
# its three new ExtPorts.path_stat/dir_list/dir_make bridges added 34 lines
# inside `ext_ports_of` plus one on the import line. Each is the MECHANICAL drift this header describes
# and not the D4 judgement the failure message warns about: D16's widening of
# ExtPorts.proc_exec and its new ExtPorts.file_read seam added 30 and then 4
# lines inside `ext_ports_of`, and D17's ExtPorts.file_write/file_remove seams
# added 20 more plus 5 in the record literal — all above all five anchors. Each
# anchored expression was compared to `git show HEAD:` before and after and is
# character-identical, so no site changed identity, routing or attribution —
# only its offset. The table identity hash and driver_only_attribution_ref move
# with it.
#
# THREE ITEMS IN A ROW MAKES IT A LAW RATHER THAN A PATTERN: every seam added to
# ExtPorts lands inside `ext_ports_of`, which sits above all five anchors, so
# every Route B surface item re-baselines this list and re-issues both profiles.
# That is not a defect in the anchors — a line-number anchor is what makes the
# drift visible at all — but an item that plans for Route B should price it, and
# from WI-D17 onward the handoffs do.
#
# WI-D20 RE-BASELINED THE THREE tool_phase.ail ANCHORS, 313/314/373 ->
# 317/318/413, AND IT IS THE FIRST RE-BASELINE THAT IS NOT A ROUTE B SURFACE
# ITEM — so it is the exception the law above did not predict rather than another
# instance of it. WI-D19 showed a routing item can touch a driver file and NOT
# cascade, by making every edit line-count-neutral. This item could not: the
# `on_tool_handle` successor fix needs `src/core/ext_world`'s codec inside
# `tool_phase.ail`, and an IMPORT can only go above the anchors. Holding them
# would have meant compressing an unrelated import block to buy back four lines,
# which is the cosmetic edit `ext/runtime.ail:24` already had to make once; twice
# is a habit, and the anchors are an instrument while the dropped successor is a
# defect. Re-baselined deliberately, with the reason here.
#
# TWO OF THE THREE ARE PURE OFFSET DRIFT and were compared to `git show HEAD:`
# character by character: `is_scratchpad_tool_name` (313->317) and
# `exec_scratchpad_cell_ws` (314->318) are byte-identical, so no site changed
# identity, routing or attribution.
#
# THE THIRD CHANGED, AND IT IS RECORDED AS A CHANGE RATHER THAN AS DRIFT.
# `tool_phase.ail:373` read `ports.clock_now(world)`; :413 reads
# `ports.clock_now(handle_world)`. It is the same site, the same effect and the
# same routing — what moved is WHICH world it starts from, because a delegating
# `on_tool_handle` may now have advanced it. The anchor still checks `clock_now`
# and the attribution row's note says so.
#
# AND THE RE-BASELINE HAS NINE CONSUMER SITES, NOT SIX. WI-D20 updated six,
# believed it was done, and `make dst` found the other three — the "discovered
# site" fixtures in `scripts/dst/driver_only_dst.ail:75`,
# `driver_plus_no_ops_dst.ail:110` and `profile_definition_dst.ail:111`, which
# each carry their own literal copy of the attributed Process site so that the
# unaccounted-site rule has something to reject. They are invisible to a grep of
# `src/core/` and to a grep of the attribution table, which is how they were
# missed. The full set a moved anchor touches:
#
#   1. this file                                   (the check itself)
#   2. src/core/dst_attribution_table.ail          (the row + 3 test literals)
#   3. scripts/dst/attribution_table_dst.ail       (2 literals)
#   4. src/core/dst_driver_only.ail                (version + content hash)
#   5. src/core/dst_driver_plus_no_ops.ail         (version + content hash)
#   6-9. the three *_dst.ail discovered-site fixtures above
#
# The grep that finds all of them is
#   grep -rn 'tool_phase.ail", line: [0-9]' --include=*.ail .
# and it is written here because the cost of missing one is a full sweep.
#
# WI-D21 RE-BASELINED THE FIVE session.ail ANCHORS A FOURTH TIME,
# 965/1224/1330/2775/2885 -> 1061/1320/1426/2871/2981, ALL +96 — AND IT IS THE
# CHEAPEST EDIT THAT CAN CAUSE THIS. WI-D18's law was "every Route B SURFACE item
# re-baselines". WI-D20 found the first exception: a non-surface item does too if
# it needs a driver-side codec. THIS ITEM ADDED NO SEAM, NO IMPORT AND NO CODE AT
# ALL — it wrote a comment block inside `ext_ports_of`'s `proc_exec` closure,
# which sits above all five anchors, and that moved every one of them.
#
# So the law's real form is not about surfaces or codecs: ANY EDIT TO
# `ext_ports_of`, INCLUDING PROSE, RE-BASELINES THIS LIST AND RE-ISSUES BOTH
# PROFILES. An item whose whole deliverable is documentation must price the
# cascade exactly as a routing item does, and this one is the proof.
#
# All five were compared to `git show HEAD:` character by character and are
# byte-identical, so no site changed identity, routing or attribution — only its
# offset. The three `*_dst.ail` discovered-site fixtures are NOT touched by this
# one: they carry `tool_phase.ail:318`, which did not move. The nine-file set
# below is the cost of a tool_phase move; a session.ail-only move touches six.
#
# WI-D23 RE-BASELINED THE FIVE session.ail ANCHORS A FIFTH TIME,
# 1061/1320/1426/2871/2981 -> 1096/1355/1461/2906/3016, ALL +35 — the law above
# firing exactly as priced. The item put the typed exit code through the bridge:
# `tool_outcome_exit_code` (a new projection beside `tool_outcome_text`), the
# S15 re-tensing of the seam comment's expired scope clause, and the `proc_exec`
# closure's second output field all land at or above `ext_ports_of`, which sits
# above all five anchors. All five were compared to `git show HEAD:` character
# by character and are byte-identical — pure offset drift, no site changed
# identity, routing or attribution. The three `*_dst.ail` discovered-site
# fixtures carry `tool_phase.ail:318`, which did not move, so this is the
# six-file session.ail-only form, not the nine-file tool_phase form.
#
# WI-D24 RE-BASELINED SIX ANCHORS, NOT FIVE, AND THAT MAKES THE SIX-VERSUS-NINE
# RULE ABOVE WRONG AS STATED. The five session.ail anchors moved +15
# (1096/1355/1461/2906/3016 -> 1111/1370/1476/2921/3031) for the usual reason —
# the item edited `ext_ports_of`. But `src/core/ext/runtime.ail:190` ALSO moved,
# to 199, because the item added an import and its rationale to that file's
# header, and the fold is where the extension's identity is stamped.
#
# THE THREE DISCOVERED-SITE FIXTURES CARRY THE `ext/runtime.ail` ANCHOR TOO.
# WI-D21 recorded the nine-file form as "the price of a `tool_phase` move"; the
# real rule is that it is the price of moving ANY anchor those fixtures carry,
# and they carry two — `tool_phase.ail:318` AND `ext/runtime.ail:190`. So this
# item paid nine files with `tool_phase.ail` untouched, which the recorded law
# said could not happen. The grep that finds them all is the one below, widened:
#   grep -rn '\(session\|tool_phase\|ext/runtime\).ail", line: [0-9]' --include=*.ail .
#
# The anchored expressions were compared to `git show HEAD:` character by
# character — all six byte-identical, pure offset drift.
#
# WI-C5 RETIRED the session.ail:878 anchor. `ext_unrouted_clock` no longer
# exists: widening ExtPorts.clock_now to thread the world token let
# ext_ports_of route that seam, so the site is not un-routed, it is GONE. Its
# replacement is :881 below, and it is checked as ROUTED rather than as ambient.
check src/core/test/stub_step.ail 203 'now()' "the one remaining ambient clock (declared UNROUTED core)"
for l in 1111 1370 1476 2921 3031; do
  check src/core/session.ail "$l" 'clock_now' "a routed core clock site"
done
check src/core/tool_phase.ail 413 'clock_now' "the FIFTH routed core clock site (D4's table says four)"

if [ "$fail" -ne 0 ]; then
  echo
  echo "An anchor moved. Do NOT re-baseline it without deciding which site is 'the'"
  echo "attributed one — that is a D4 judgement with other consumers, and correcting"
  echo "the table re-issues every referring profile (bump driver_only_version and"
  echo "re-record driver_only_attribution_ref)."
  exit 1
fi
