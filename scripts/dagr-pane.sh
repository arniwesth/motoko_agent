#!/usr/bin/env bash
#
# Open the herdr-dagr pane on THIS repo's live delegation run.
#
# WHY THIS EXISTS. `dagr view` resolves its run file as $DAGR_RUN, then
# `.dagr/run.json`, then `run.json` under the pane cwd. The Motoko producer
# writes `.dagr/run-<pane>-<session_ms>.json` — keyed by producer pane AND
# session, because one writer per file is what stops two Motokos in one checkout
# from clobbering each other (DESIGN-dagr-as-delegation-view.md §5). Those two
# rules never intersect, so the stock `herdr plugin action invoke open-dagr`
# cannot find a Motoko run and renders whatever stale `.dagr/run.json` happens
# to be lying about instead. Measured 2026-09-01: a session spent twenty minutes
# and ~90 scratch panes discovering that, while its own run file sat unread on
# disk the whole time.
#
# So this resolves the run file explicitly and passes it down as $DAGR_RUN. It
# is NOT a workaround for a missing feature in the producer — a shared
# `.dagr/run.json`, symlink or otherwise, would reintroduce exactly the
# multi-writer shape §5 refuses, and a reader who opened the pane would silently
# get some other session's graph.
#
# Usage:
#   scripts/dagr-pane.sh                        # newest run file
#   scripts/dagr-pane.sh --pane w1:p1           # the run of the Motoko in that pane
#   scripts/dagr-pane.sh --file .dagr/run-x.json
#   scripts/dagr-pane.sh --direction down       # right (default) | down | left | up
#   scripts/dagr-pane.sh --print                # print the herdr command, open nothing
#
# Exit codes: 0 opened (or printed), 2 nothing to open / plugin missing.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
DAGR_DIR="$ROOT_DIR/.dagr"
# Pin must match Makefile DAGR_VERSION (single source of truth). Derive it so
# the next bump cannot update one and teach the wrong ref in the other.
DAGR_VERSION="$(sed -nE 's/^DAGR_VERSION \?= ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$ROOT_DIR/Makefile" | head -n1)"
DAGR_VERSION="${DAGR_VERSION:-0.3.1}"
PLUGIN_PIN="herdr plugin install aemrebarut/herdr-dagr --ref v${DAGR_VERSION} --yes"

pane=""
file=""
direction="right"
print_only=0

die() { printf '%s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --pane)      pane="${2:-}"; shift 2 ;;
    --file)      file="${2:-}"; shift 2 ;;
    --direction)
      direction="${2:-right}"
      case "$direction" in
        right|down|left|up) ;;
        *) die "dagr-pane: --direction takes right, down, left or up (got \`$direction\`)." ;;
      esac
      shift 2 ;;
    --print)     print_only=1; shift ;;
    -h|--help)   sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           die "dagr-pane: unknown argument \`$1\`. Try --help." ;;
  esac
done

command -v "$HERDR_BIN" >/dev/null 2>&1 || die "dagr-pane: no herdr binary (\`$HERDR_BIN\`). This opens a pane in a running herdr session; there is nothing to open outside one."

# THE PLUGIN MUST BE PINNED. An unpinned `herdr plugin install` builds from
# main and needs Cargo, which this container does not have; the pin is the
# difference between "installs" and "fails on a machine without a toolchain".
if ! ls "$HOME"/.config/herdr/plugins/github/herdr-dagr-*/bin/dagr >/dev/null 2>&1; then
  die "dagr-pane: the herdr-dagr plugin is not installed. Install it pinned:
  $PLUGIN_PIN"
fi

# RESOLVING THE RUN FILE, and it says which one it picked rather than picking
# quietly. With two Motokos in one checkout there are two run files and only one
# of them is the one you meant; a silent newest-wins would show the wrong graph
# and look right doing it.
if [ -n "$file" ]; then
  [ -f "$file" ] || die "dagr-pane: no such run file: $file"
  run_file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
else
  if [ -n "$pane" ]; then
    # The producer slugs `:` to `-` in the filename (dagr.slug).
    glob="$DAGR_DIR/run-${pane//:/-}-*.json"
  else
    glob="$DAGR_DIR/run-*.json"
  fi
  # shellcheck disable=SC2086
  mapfile -t candidates < <(ls -t $glob 2>/dev/null)
  if [ "${#candidates[@]}" -eq 0 ]; then
    hint="No Motoko run file in $DAGR_DIR yet."
    [ -n "$pane" ] && hint="No Motoko run file for pane $pane in $DAGR_DIR."
    die "dagr-pane: $hint The producer writes one on the first Delegate call, so
delegate something first, then run this again. \`.dagr/run.json\` is not one of
these — it is whatever hand-authored file was last left in the directory."
  fi
  run_file="${candidates[0]}"
  if [ "${#candidates[@]}" -gt 1 ]; then
    printf 'dagr-pane: %d run files in .dagr/ — opening the newest.\n' "${#candidates[@]}" >&2
    for c in "${candidates[@]}"; do
      marker="  "; [ "$c" = "$run_file" ] && marker="→ "
      printf '%s%s\n' "$marker" "${c#"$ROOT_DIR"/}" >&2
    done
    printf 'Pass --pane <id> or --file <path> to pick a different one.\n' >&2
  fi
fi

# THE STALE PROBE, NAMED RATHER THAN DELETED. `.dagr/run.json` is what the stock
# `open-dagr` action renders, and in this checkout it has been the hand-authored
# 2026-08-26 install probe — a confident graph of work that is not this session's.
# Removing another tool's file is not this script's call; saying so is.
if [ -f "$DAGR_DIR/run.json" ]; then
  printf 'dagr-pane: note — .dagr/run.json exists. `herdr plugin action invoke open-dagr`\n' >&2
  printf '  renders THAT file, not this one. Remove it if it is a leftover probe.\n' >&2
fi

# herdr splits only know right and down, so left/up open as right/down and then
# swap across — the same two-step the stock `open-dagr.sh` uses.
case "$direction" in
  right) dir="right"; swap="" ;;
  down)  dir="down";  swap="" ;;
  left)  dir="right"; swap="left" ;;
  up)    dir="down";  swap="up" ;;
esac

set -- plugin pane open \
  --plugin herdr-dagr \
  --entrypoint dagr \
  --placement split \
  --direction "$dir" \
  --focus \
  --cwd "$ROOT_DIR" \
  --env "DAGR_RUN=$run_file"

if [ "$print_only" -eq 1 ]; then
  printf '%s' "$HERDR_BIN"
  for a in "$@"; do printf ' %q' "$a"; done
  printf '\n'
  exit 0
fi

# ONE DAGR PANE, NOT A PILE OF THEM. $DAGR_RUN is fixed when the pane spawns, so
# pointing the view at a different run file means REPLACING the pane, and the
# 2026-09-01 session left ~90 behind by opening without ever closing.
#
# BY EXPLICIT PANE ID, from a note this script wrote itself. `plugin pane close
# dagr` does not find a pane opened with `plugin pane open` (verified here:
# `plugin_pane_not_found` against a live, dagr-labelled pane), and closing by
# LABEL is the rule herdr.ail's sweep refuses for good measured reason — a pane
# is only ours to close if we can prove we opened it. So the id goes in
# `.dagr/.pane`, and a recorded id is the only thing this ever closes.
#
# AND THE EXTENSION'S MARKER FOR THIS RUN COUNTS TOO, since MOT-137. Under
# HERDR_DAGR_PANE=1 `motoko-ext-herdr` opens a view itself on the first
# delegation and records the pane in `.dagr/.pane-<pane>-<session>` — so this
# script is no longer the only thing that opens one, and closing only its own
# note would leave the operator with two views of the same run and a fresh one
# on top. The proof standard is unchanged and is why these can be closed at all:
# the id comes from a marker THIS REPO'S TOOLING WROTE WHEN IT OPENED THE PANE,
# never from a label search.
#
# TAKEOVER, NOT REMOVAL. The marker is re-pointed at the new pane after the
# open (below), never left deleted: the extension treats a missing sentinel as
# "no view yet" and opens a second one on the next Delegate. Measured
# 2026-09-03 — extension opened w1:pD, the script replaced it with w1:pE and
# removed the sentinel, the next Delegate opened w1:pG: two live views of one
# run. Other sessions' `.pane-*` markers are not touched at all: closing them
# would take another session's view with it, and deleting them would make THAT
# session reopen on its next call.
close_marked() {
  local marker prev
  for marker in "$@"; do
    [ -f "$marker" ] || continue
    prev="$(cat "$marker" 2>/dev/null)"
    # Only if it is still a dagr pane. Pane ids are reused, and closing a
    # recycled id would take out whatever moved in.
    if [ -n "$prev" ] && "$HERDR_BIN" pane get "$prev" 2>/dev/null | grep -q '"label":"dagr"'; then
      "$HERDR_BIN" pane close "$prev" >/dev/null 2>&1 || true
    fi
    rm -f "$marker"
  done
}

LAST_PANE="$DAGR_DIR/.pane"
# The extension's marker for THIS run only: `run-<slug>-<session>.json` shares
# its `<slug>-<session>` stem with `.pane-<slug>-<session>` (dagr.pane_marker
# vs dagr.run_file_name). Other sessions' `.pane-*` markers are left strictly
# alone — closing them would take another session's live view with it, and
# deleting them would make THAT session reopen on its next Delegate.
ext_marker=""
case "$(basename "$run_file")" in
  run-*.json)
    stem="$(basename "$run_file" .json)"
    stem="${stem#run-}"
    [ -n "$stem" ] && ext_marker="$DAGR_DIR/.pane-$stem"
    ;;
esac
if [ -n "$ext_marker" ]; then
  # Remember whether the extension actually opened for this run: if its
  # sentinel was never there, creating one would claim it did.
  if [ -f "$ext_marker" ]; then
    ext_had_marker=1
  else
    ext_had_marker=0
  fi
  close_marked "$LAST_PANE" "$ext_marker"
else
  ext_had_marker=0
  close_marked "$LAST_PANE"
fi

out="$("$HERDR_BIN" "$@")" || die "dagr-pane: herdr refused to open the pane:
$out"

pane_id="$(printf '%s' "$out" | sed -nE 's/.*"pane_id":"([^"]+)".*/\1/p' | head -1)"
if [ -n "$pane_id" ]; then
  printf '%s' "$pane_id" > "$LAST_PANE"
  # Take over the extension's sentinel: it treats a missing marker as "no view
  # yet" and opens a second view on the next Delegate. Re-pointing it at the
  # replacement pane keeps at-most-once true across both openers — but only
  # when the extension actually opened one (see above).
  if [ "$ext_had_marker" = 1 ] && [ -n "$ext_marker" ]; then
    printf '%s' "$pane_id" > "$ext_marker"
    # Keep the replacement pane reaped like the one it replaced: the extension
    # tagged its view `mot-owner=<own>:<session>`, and an untagged replacement
    # would leak at exit. Best-effort — a failed tag leaves a working view.
    stem2="$(basename "$ext_marker")"
    stem2="${stem2#.pane-}"
    sess="${stem2##*-}"
    slug_part="${stem2%-*}"
    own_pane_takeover="${slug_part/-/:}"
    if [ -n "$sess" ] && [ -n "$own_pane_takeover" ]; then
      "$HERDR_BIN" pane report-metadata "$pane_id" --source motoko-delegate \
        --token "mot-owner=${own_pane_takeover}:${sess}" >/dev/null 2>&1 || true
    fi
  fi
  [ -n "$swap" ] && "$HERDR_BIN" pane swap --pane "$pane_id" --direction "$swap" >/dev/null 2>&1
fi

printf 'dagr pane %s watching %s\n' "${pane_id:-(opened)}" "${run_file#"$ROOT_DIR"/}"
