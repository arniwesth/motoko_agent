#!/usr/bin/env bash
# Differential test for ../JournalTwinModel.lean (T3), in the style of
# .agent/projects/043_lean_harness_properties/evidence/diff/run_diff.sh.
#
# Every action sequence of length 0..4 over the model's nine child actions (7,381 runs):
#   Lean    enumerate.lean.tail   the model: host, twin, host-across-processes, folded; validity; spec
#   AILANG  gen_events.ail        the child's wire events (real digests); the REAL twin
#                                 (`journal_lines_of_records`) folded by the REAL `fold_journal`
#   bun     host.ts               the REAL `SessionJournal.record` over the same events, in one
#                                 process and (--across) with a fresh adopted instance per resume
#   AILANG  fold_host.ail         the REAL `fold_journal` over the host's journals
#   awk     compare.awk           model vs real (must be 0 mismatches), then P3.1/P3.2 on the
#                                 real code over the sequences a run can emit
#
#   run_diff.sh [work dir]       needs lean 4.28.0 (or ~/.elan's), bun and ailang v0.54.14
#
# The two .ail files are copied into a temporary directory INSIDE the tree for the run (package
# imports resolve only there) and removed on exit. Exit 0 iff the model matches the real code.
#
#   T3_FIX=twin|host|both run_diff.sh [work dir]   negative control (see below): must exit 1
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
repo="$(cd "$out/../tree" && pwd)"
work="${1:-$here/work}"
mkdir -p "$work"
work="$(cd "$work" && pwd)"   # absolute: the AILANG halves run from the tree root
command -v lean >/dev/null || export PATH="$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin:$PATH"

cat "$out/JournalTwinModel.lean" "$here/enumerate.lean.tail" > "$work/Enum.lean"
lean "$work/Enum.lean" > "$work/lean.raw"
grep -E '^[0-9,]*\|' "$work/lean.raw" > "$work/lean.out"
echo "lean: $(wc -l < "$work/lean.out") sequences, $(awk -F'|' '$8=="true"' "$work/lean.out" | wc -l) a run can emit"
grep '^#' "$work/lean.raw" || true

tmp="$(mktemp -d "$repo/t3tmp_XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
cp "$here/gen_events.ail" "$tmp/gen_events.ail"
cp "$here/fold_host.ail" "$work/fold_host.ail"
# NEGATIVE CONTROL: T3_FIX=twin|host|both runs the REAL side against patched temporary copies
# (never the tree), exactly as ../repro/case.sh does. The model is NOT patched, so the model
# comparison must then report mismatches, on exactly the sequences the defects touch.
fix="${T3_FIX:-}"
if [[ "$fix" == twin || "$fix" == both ]]; then
  mod="${tmp#"$repo"/}/journal_fixed"
  sed '/"history_replaced", kvs);$/{n;s/      { next | digest: i.digest_after }$/      { next | digest: i.digest_after, replaced_since_seed: true }/}' \
    "$repo/src/core/journal.ail" > "$tmp/journal_fixed.ail"
  [[ "$(diff "$repo/src/core/journal.ail" "$tmp/journal_fixed.ail" | grep -c '^>')" == 1 ]] || { echo "twin patch: not exactly one line"; exit 2; }
  sed -i "s#^import src/core/journal (#import $mod (#" "$tmp/gen_events.ail" "$work/fold_host.ail"
  echo "NEGATIVE CONTROL: twin patched"
fi
if [[ "$fix" == host || "$fix" == both ]]; then
  sed 's#^    if (this.historyMessages === 0) this.historyMessages = 1;$#&\n    this.updatePending(message);#' \
    "$repo/src/tui/src/session-journal.ts" > "$work/session-journal.t3fix.ts"
  [[ "$(diff "$repo/src/tui/src/session-journal.ts" "$work/session-journal.t3fix.ts" | grep -c '^>')" == 1 ]] || { echo "host patch: not exactly one line"; exit 2; }
  export T3_HOST_MODULE="$work/session-journal.t3fix.ts"
  echo "NEGATIVE CONTROL: host patched"
fi
( cd "$repo" && ailang run --relax-modules --caps IO --entry main "$tmp/gen_events.ail" ) > "$work/gen.raw" 2> "$work/gen.err"
echo "ailang twin: $(grep -c '^T|' "$work/gen.raw") sequences"

rm -rf "$work/hostdirs"
bun "$here/host.ts" "$repo" "$work/hostdirs" < "$work/gen.raw" > "$work/host.txt"
bun "$here/host.ts" "$repo" "$work/hostdirs" --across < "$work/gen.raw" >> "$work/host.txt"
echo "bun host: $(wc -l < "$work/host.txt") journals"

sed "s#HOST_JOURNALS_PATH#$work/host.txt#" "$work/fold_host.ail" > "$tmp/fold_host.ail"
( cd "$repo" && ailang run --relax-modules --caps IO,FS --entry main "$tmp/fold_host.ail" ) > "$work/hfold.raw" 2> "$work/hfold.err"
grep -h '^[TH]|' "$work/gen.raw" "$work/hfold.raw" > "$work/real.out"
echo "real: $(wc -l < "$work/real.out") lines; sha256 $(sha256sum "$work/real.out" | cut -c1-16)"

awk -F'|' -f "$here/compare.awk" "$work/lean.out" "$work/real.out"
