#!/usr/bin/env bash
#
# PLAN-001 P2 Part 3 (ADR-001 D2 part 3): the world ordinal, checked PER FRAMED
# RUN on the stdout wire.
#
# =============================================================================
# Why frames, and why here
# =============================================================================
#
# `session.witness` puts one `world_request` line on the wire for every helped
# leaf request, carrying the ordinal `world_ordinal.advance` gave it. A DST
# script runs many traced invocations in one process, and all eight subjects of
# `ledger_parity_dst.ail` share `session_0` and restart at ordinal 1 — so the
# wire alone cannot say where one run ends, and a run that dropped its LAST
# request looks exactly like a shorter run (cF1). The script therefore prints
#
#   WORLD_RUN_BEGIN <label> <ordinal0>   before the OUTER entry call
#   WORLD_RUN_END   <label> <final>      after it, from run.world.ordinal
#
# and refuses END (printing WORLD_RUN_REFUSED) when run.world.pending is
# non-empty. Frames are NOT `RunSummary` or `done`: the exit publish is one of
# the requests under test.
#
# Per frame this gate demands: exactly one END per BEGIN; every world_request
# inside a frame; ordinals exactly ordinal0+1, ordinal0+2, … (STRICT +1 —
# exempt requests do not advance); last == final; and at least one request
# (every traced run witnesses its finalize clock). Across the run: the expected
# frame count. Equal ordinals in DIFFERENT frames are valid.
#
# What a red LOCALIZES, and no more: an inconsistent sequence in a named frame.
# A repeated or backward ordinal is a stale-world re-request (a whole-record
# drop); a gap is a leaf advanced but not witnessed on that path, or an
# unhelped leaf; a final mismatch is a drop after the last witness. Fixtures,
# not this gate, distinguish a drop from a codec reset or a double emission.
#
# =============================================================================
# Failing closed
# =============================================================================
#
# Every check below is green over an empty wire, so the frame count, the
# script's own WORLD_RUN_FRAMES line and a non-zero request total are asserted
# as vacuity rows. `--selftest` runs each red class over a synthetic wire before
# the make target trusts a green: a checker that cannot go red certifies nothing.
#
# Usage:
#   run_world_framed_wire.sh                 run ledger_parity_dst.ail and check it
#   run_world_framed_wire.sh --wire FILE [N] check a captured wire, expecting N frames
#   run_world_framed_wire.sh --selftest      every red class, plus the green shapes

set -euo pipefail

cd "$(dirname "$0")/../.."

# The nine subjects of ledger_parity_dst.ail, the same pin as its LEDGER_SUBJECTS
# (PLAN-002 W4 added `parked`, whose frame carries the `wake_read` witness).
EXPECT_FRAMES=9

# check_wire FILE EXPECTED — prints rows, returns 0 on green.
check_wire() {
  local file="$1" expected="$2" summary fail=0
  local frames ends requests fails sessions printed

  summary="$(awk '
    function bad(msg) { print "  ✗ " msg; fails++ }
    BEGIN { open = ""; frames = 0; ends = 0; total = 0; fails = 0 }

    /^WORLD_RUN_BEGIN( |$)/ {
      if ($0 !~ /^WORLD_RUN_BEGIN [A-Za-z0-9_.:-]+ -?[0-9]+$/) {
        bad("line " NR ": truncated or malformed BEGIN marker: \x27" $0 "\x27"); next
      }
      if (open != "") bad("frame " open ": BEGIN " $2 " arrived before its END (missing END or duplicated BEGIN)")
      if ($2 in seen) bad("frame " $2 ": label framed twice (duplicated BEGIN)")
      seen[$2] = 1; open = $2; ord0 = $3 + 0; last = ord0; n = 0; sid = "?"; at_open = fails; frames++
      next
    }

    /^WORLD_RUN_END( |$)/ {
      if ($0 !~ /^WORLD_RUN_END [A-Za-z0-9_.:-]+ -?[0-9]+$/) {
        bad("line " NR ": truncated or malformed END marker: \x27" $0 "\x27"); next
      }
      if (open == "") { bad("line " NR ": END " $2 " with no open frame (duplicated END or missing BEGIN)"); next }
      if ($2 != open) { bad("frame " open ": closed by END " $2 " (marker label mismatch)"); open = ""; next }
      final = $3 + 0; ends++
      if (n == 0) bad("frame " open ": no world_request inside it — every traced run witnesses its finalize clock, so an empty frame is vacuous")
      if (last != final) bad("frame " open ": last witnessed ordinal " last " != final " final " (a drop after the last witness)")
      if (fails == at_open) print "  ✓ frame " open ": ordinal0=" ord0 " requests=" n " strict +1 to final=" final " (session " sid ")"
      open = ""
      next
    }

    # A refusal closes its frame WITHOUT an END: it is red here and again in the
    # END-per-BEGIN count, but the next BEGIN is not also reported as a missing END.
    /^WORLD_RUN_REFUSED / {
      bad("frame " $2 ": the script REFUSED END (" $3 ") — the run returned with witnesses pending")
      if ($2 == open) open = ""
      next
    }

    /^WORLD_RUN_FRAMES / { printed = $2; next }

    /"type":"world_request"/ {
      if (match($0, /"ordinal":-?[0-9]+/) == 0) { bad("line " NR ": world_request with no readable ordinal"); next }
      o = substr($0, RSTART + 10, RLENGTH - 10) + 0
      total++
      if (match($0, /"session_id":"[^"]*"/)) { s = substr($0, RSTART + 14, RLENGTH - 15); sessions[s] = 1 } else s = "?"
      if (open == "") { bad("line " NR ": world_request ordinal " o " outside any frame"); next }
      n++; sid = s
      if (o == last + 1) last = o
      else if (o == last) { bad("frame " open ": ordinal " o " repeated (stale-world re-request)"); last = o }
      else if (o < last) { bad("frame " open ": ordinal " o " after " last " is backward (stale-world re-request)"); last = o }
      else { bad("frame " open ": ordinal " o " after " last " is a gap of " (o - last - 1) " (advanced but not witnessed on this path, or an unhelped leaf)"); last = o }
      next
    }

    END {
      if (open != "") bad("frame " open ": no END marker (the script exited inside the frame, or END was truncated away)")
      ns = 0; for (k in sessions) ns++
      print "FRAMED frames=" frames " ends=" ends " requests=" total " fails=" fails " sessions=" ns " printed=" (printed == "" ? "none" : printed)
    }
  ' "$file")"

  grep -v '^FRAMED ' <<<"$summary" || true
  local line
  line="$(grep '^FRAMED ' <<<"$summary")"
  frames="$(sed 's/.* frames=\([0-9]*\).*/\1/' <<<"$line")"
  ends="$(sed 's/.* ends=\([0-9]*\).*/\1/' <<<"$line")"
  requests="$(sed 's/.* requests=\([0-9]*\).*/\1/' <<<"$line")"
  fails="$(sed 's/.* fails=\([0-9]*\).*/\1/' <<<"$line")"
  sessions="$(sed 's/.* sessions=\([0-9]*\).*/\1/' <<<"$line")"
  printed="$(sed 's/.* printed=\([a-z0-9]*\).*/\1/' <<<"$line")"

  [ "$fails" -eq 0 ] || fail=1

  if [ "$frames" -eq "$expected" ]; then
    echo "  ✓ expected frame count: ${frames} BEGIN marker(s)"
  else
    echo "  ✗ expected ${expected} frame(s), saw ${frames} BEGIN marker(s)"; fail=1
  fi
  if [ "$ends" -eq "$frames" ]; then
    echo "  ✓ exactly one END per BEGIN (${ends})"
  else
    echo "  ✗ ${frames} BEGIN but ${ends} matching END marker(s)"; fail=1
  fi
  if [ "$printed" = "$expected" ]; then
    echo "  ✓ the script reached its WORLD_RUN_FRAMES ${printed} line"
  else
    echo "  ✗ WORLD_RUN_FRAMES is ${printed}, expected ${expected} — the script did not finish framing its runs"; fail=1
  fi
  if [ "$requests" -gt 0 ]; then
    echo "  ✓ ${requests} world_request line(s) checked across ${sessions} session_id(s) (equal ordinals in different frames are valid)"
  else
    echo "  ✗ no world_request lines at all — every row above is vacuous"; fail=1
  fi

  return "$fail"
}

# --- selftest: synthetic wires, one per red class ----------------------------
req() { printf '{"schema_version":"1","session_id":"%s","type":"world_request","ordinal":%s,"class":"env_read"}\n' "${2:-session_0}" "$1"; }

selftest() {
  local dir st_fail=0
  dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$dir'" RETURN

  # expect NAME green|red SUBSTRING EXPECTED_FRAMES — the wire is on stdin
  expect() {
    local name="$1" want="$2" needle="$3" n="$4" out rc
    cat > "${dir}/${name}.wire"
    set +e
    out="$(check_wire "${dir}/${name}.wire" "$n" 2>&1)"
    rc=$?
    set -e
    if [ "$want" = green ] && [ "$rc" -eq 0 ]; then
      echo "  ✓ selftest ${name}: green"
    elif [ "$want" = red ] && [ "$rc" -ne 0 ] && grep -qF -- "$needle" <<<"$out"; then
      echo "  ✓ selftest ${name}: red — $(grep -F -- "$needle" <<<"$out" | head -1 | sed 's/^ *✗ //')"
    else
      echo "  ✗ selftest ${name}: wanted ${want} (${needle:-no row}), got exit ${rc}:"
      sed 's/^/      /' <<<"$out"
      st_fail=1
    fi
  }

  # Acceptance case 4: two honest runs sharing session_id — equal ordinals, different frames.
  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 2; req 3; echo "WORLD_RUN_END a 3"
    echo "WORLD_RUN_BEGIN b 0"; req 1; req 2; req 3; echo "WORLD_RUN_END b 3"
    echo "WORLD_RUN_FRAMES 2"; } | expect shared_session_two_runs green "" 2

  # A world handed in with a non-zero ordinal: strict +1 from ordinal0, not from 1.
  { echo "WORLD_RUN_BEGIN seeded 5"; req 6; req 7; echo "WORLD_RUN_END seeded 7"
    echo "WORLD_RUN_FRAMES 1"; } | expect nonzero_ordinal0 green "" 1

  # Acceptance case 1's shape: the approval site continues from the stale world.
  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 2; req 2; req 3; echo "WORLD_RUN_END a 3"
    echo "WORLD_RUN_FRAMES 1"; } | expect repeated_ordinal red "repeated" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 2; req 3; req 2; req 3; echo "WORLD_RUN_END a 3"
    echo "WORLD_RUN_FRAMES 1"; } | expect backward_ordinal red "backward" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 3; echo "WORLD_RUN_END a 3"
    echo "WORLD_RUN_FRAMES 1"; } | expect gap red "gap of 1" 1

  { echo "WORLD_RUN_BEGIN a 3"; req 5; req 6; echo "WORLD_RUN_END a 6"
    echo "WORLD_RUN_FRAMES 1"; } | expect gap_at_ordinal0 red "gap of 1" 1

  # Acceptance case 3's shape: the last request advanced and was never witnessed.
  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 2; echo "WORLD_RUN_END a 3"
    echo "WORLD_RUN_FRAMES 1"; } | expect final_mismatch red "!= final 3" 1

  { req 1; echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_FRAMES 1"; } | expect request_outside_frame red "outside any frame" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"; req 2
    echo "WORLD_RUN_FRAMES 1"; } | expect request_after_frame red "outside any frame" 1

  # Acceptance case 2's shape: the script exits before printing END.
  { echo "WORLD_RUN_BEGIN a 0"; req 1; req 2; } | expect missing_end_at_eof red "no END marker" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_BEGIN b 0"; req 1; echo "WORLD_RUN_END b 1"
    echo "WORLD_RUN_FRAMES 2"; } | expect missing_end_midstream red "arrived before its END" 2

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_FRAMES 2"; } | expect duplicated_begin red "framed twice" 2

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_FRAMES 1"; } | expect duplicated_end red "no open frame" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a"
    echo "WORLD_RUN_FRAMES 1"; } | expect truncated_end red "malformed END" 1

  { echo "WORLD_RUN_BEGIN a"; req 1; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_FRAMES 1"; } | expect truncated_begin red "malformed BEGIN" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END b 1"
    echo "WORLD_RUN_FRAMES 1"; } | expect label_mismatch red "marker label mismatch" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_REFUSED a pending=1"
    echo "WORLD_RUN_FRAMES 1"; } | expect refused_end red "REFUSED END" 1

  { echo "WORLD_RUN_BEGIN a 0"; echo "WORLD_RUN_END a 0"
    echo "WORLD_RUN_FRAMES 1"; } | expect empty_frame red "vacuous" 1

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"
    echo "WORLD_RUN_FRAMES 1"; } | expect frame_count red "expected 2 frame(s)" 2

  { echo "WORLD_RUN_BEGIN a 0"; req 1; echo "WORLD_RUN_END a 1"; } \
    | expect frames_line_missing red "did not finish framing" 1

  : < /dev/null | expect empty_wire red "no world_request lines" 0

  return "$st_fail"
}

# --- modes -------------------------------------------------------------------
case "${1:-}" in
  --selftest)
    echo "=== world_framed_wire selftest (every red class on a synthetic wire) ==="
    if selftest; then echo "world_framed_wire selftest PASS"; exit 0; fi
    echo "world_framed_wire selftest FAIL"; exit 1
    ;;
  --wire)
    [ -n "${2:-}" ] || { echo "usage: $0 --wire FILE [EXPECTED_FRAMES]"; exit 2; }
    echo "=== world_framed_wire over ${2} ==="
    if check_wire "$2" "${3:-$EXPECT_FRAMES}"; then echo "world_framed_wire gate PASS"; exit 0; fi
    echo "world_framed_wire gate FAIL"; exit 1
    ;;
  "") ;;
  *) echo "usage: $0 [--selftest | --wire FILE [EXPECTED_FRAMES]]"; exit 2 ;;
esac

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

echo "=== world_framed_wire (PLAN-001 P2 Part 3: per-run frames on the stdout wire) ==="

set +e
ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand \
  --entry main scripts/dst/ledger_parity_dst.ail < /dev/null > "$out" 2>&1
rc=$?
set -e

fail=0

# CARRIED, not returned on, as in run_ledger_parity_wire.sh: a run that failed
# (including a REFUSED END) is exactly the run whose frames are worth printing.
if [ "$rc" -ne 0 ]; then
  echo "  ✗ ledger_parity_dst.ail failed (exit ${rc}); its rows:"
  grep -v '^{' "$out" | grep -E '^  ✗' | sed 's/^/    /' | head -40 || true
  fail=1
fi

check_wire "$out" "$EXPECT_FRAMES" || fail=1

if [ "$fail" -ne 0 ]; then
  echo "world_framed_wire gate FAIL"
  exit 1
fi

echo "world_framed_wire gate PASS"
