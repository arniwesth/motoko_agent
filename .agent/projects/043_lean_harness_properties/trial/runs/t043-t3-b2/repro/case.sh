#!/usr/bin/env bash
# case.sh — reproduce one T3 counterexample on the REAL code.
#
#   (from the tree root)  ../out/repro/case.sh <actions> <check> [expected]
#
# <actions> is a comma-separated action sequence of the model's `Child.step` (0 A plain
# assistant, 1 A assistant with call c1, 2 A result for c1, 3 A user, 4 hybrid replacement
# with call c1, 5 checkpoint, 6 resume same profile, 7 resume with profile switch, 8 follow-up
# turn). The child's wire events are built by ../diff/gen_events.ail with the REAL chain
# functions; then:
#   twin    the REAL `journal_lines_of_records`, folded by the REAL `fold_journal`
#   host    the REAL `SessionJournal.record` (bun), one process; folded by the REAL fold
#   across  the same, with a NEW `SessionJournal` (adopt) for every `session_resumed`
#
# <check>:
#   p31          exit 1 if host and twin do not fold alike (refusal id, or history+dangling)
#   p31-across   the same with the across-process host
#   p32          exit 1 if the twin's fold is not exactly [expected] (`accept|<history>|<dangling>#n`)
# Exit 0 when the property holds on this input, 2 when a toolchain step failed.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
repo="$(cd "$out/../tree" && pwd)"
acts="$1"; check="$2"; expected="${3:-}"
work="$(mktemp -d "$here/work.XXXX")"
tmp="$(mktemp -d "$repo/t3tmp_XXXXXX")"
trap 'rm -rf "$work" "$tmp"' EXIT

# `x1` is the hand-built X-1 event list (gen_events.ail `main_x1`); anything else is an
# action sequence of the enumeration's `main`.
entry=main
if [[ "$acts" == x1 ]]; then entry=main_x1; cp "$out/diff/gen_events.ail" "$tmp/gen_events.ail"
else sed "s/let all = .*;/let all = [[${acts}]];/" "$out/diff/gen_events.ail" > "$tmp/gen_events.ail"; fi
cp "$out/diff/fold_host.ail" "$work/fold_host.ail"
# T3_FIX=twin|host|both: the same run against a PATCHED COPY (never the tree), to show the
# check exits 0 once the defect is gone. twin: `HistoryReplaced` sets `replaced_since_seed`
# (journal.ail twin_event). host: `replaceLastHistoryMessage` calls `updatePending`.
fix="${T3_FIX:-}"
if [[ "$fix" == twin || "$fix" == both ]]; then
  mod="${tmp#"$repo"/}/journal_fixed"
  sed '/"history_replaced", kvs);$/{n;s/      { next | digest: i.digest_after }$/      { next | digest: i.digest_after, replaced_since_seed: true }/}' \
    "$repo/src/core/journal.ail" > "$tmp/journal_fixed.ail"
  [[ "$(diff "$repo/src/core/journal.ail" "$tmp/journal_fixed.ail" | grep -c '^>')" == 1 ]] || { echo "twin patch: not exactly one line"; exit 2; }
  cmp -s "$repo/src/core/journal.ail" "$tmp/journal_fixed.ail" && { echo "twin patch did not apply"; exit 2; }
  sed -i "s#^import src/core/journal (#import $mod (#" "$tmp/gen_events.ail" "$work/fold_host.ail"
fi
if [[ "$fix" == host || "$fix" == both ]]; then
  sed 's#^    if (this.historyMessages === 0) this.historyMessages = 1;$#&\n    this.updatePending(message);#' \
    "$repo/src/tui/src/session-journal.ts" > "$work/session-journal.t3fix.ts"
  [[ "$(diff "$repo/src/tui/src/session-journal.ts" "$work/session-journal.t3fix.ts" | grep -c '^>')" == 1 ]] || { echo "host patch: not exactly one line"; exit 2; }
  export T3_HOST_MODULE="$work/session-journal.t3fix.ts"
fi
( cd "$repo" && ailang run --relax-modules --caps IO --entry "$entry" "$tmp/gen_events.ail" ) > "$work/gen.raw" 2> "$work/gen.err" || { cat "$work/gen.err"; exit 2; }
bun "$out/diff/host.ts" "$repo" "$work/hd" < "$work/gen.raw" > "$work/host.txt" || exit 2
bun "$out/diff/host.ts" "$repo" "$work/hd" --across < "$work/gen.raw" >> "$work/host.txt" || exit 2
sed "s#HOST_JOURNALS_PATH#$work/host.txt#" "$work/fold_host.ail" > "$tmp/fold_host.ail"
( cd "$repo" && ailang run --relax-modules --caps IO,FS --entry main "$tmp/fold_host.ail" ) > "$work/hfold.raw" 2> "$work/hfold.err" || { cat "$work/hfold.err"; exit 2; }

twin="$(grep -F "T|${acts}|" "$work/gen.raw" | head -1 | cut -d'|' -f3-)"
host="$(grep -F "H|${acts}|" "$work/hfold.raw" | head -1 | cut -d'|' -f3-)"
across="$(grep -F "H|A:${acts}|" "$work/hfold.raw" | head -1 | cut -d'|' -f3-)"
[[ -n "$twin" && -n "$host" && -n "$across" ]] || { echo "a half printed nothing"; exit 2; }
echo "actions: $acts"
echo "  twin   (journal_lines_of_records -> fold_journal): $twin"
echo "  host   (SessionJournal, one process -> fold_journal): $host"
echo "  across (SessionJournal, adopted per resume -> fold_journal): $across"
echo "  host's journal: $(grep -E "^${acts}	" "$work/host.txt" | head -1 | cut -f2 | grep -o '"type":"[a-z_]*"' | cut -d'"' -f4 | tr '\n' ' ')"

case "$check" in
  p31)        [[ "$host" == "$twin" ]] && { echo "P3.1 holds"; exit 0; }; echo "P3.1 VIOLATED: host and twin fold differently"; exit 1 ;;
  p31-across) [[ "$across" == "$twin" ]] && { echo "P3.1 holds"; exit 0; }; echo "P3.1 VIOLATED: adopted host and twin fold differently"; exit 1 ;;
  p32)        echo "  expected (rule 3, then rule 4): $expected"
              [[ "$twin" == "$expected" ]] && { echo "P3.2 holds"; exit 0; }; echo "P3.2 VIOLATED: the twin's journal does not fold to rule 3's history"; exit 1 ;;
  *) echo "unknown check $check"; exit 2 ;;
esac
