#!/usr/bin/env bash
# control_fixed.sh — the negative control for the four repro commands in ../reports.tsv:
# each must exit 1 on the real tree AND exit 0 once its defect is fixed.
#
# Builds, under a scratch directory, the layout the repro scripts expect
# (<scratch>/tree, <scratch>/out/repro), where <scratch>/tree holds COPIES of the four files
# involved with one candidate fix each. The real tree is only read.
#
#   types.ail:1433            herdr_env >= "1"         ->  herdr_env == "1"           (B2-T1-1)
#   herdr-agent-state.ts:164  bin === undefined        ->  !bin                       (B2-T1-2)
#   register.ail:49           getEnvOr(…, "herdr")     ->  getEnvOr(…, "")            (B2-T1-3)
#   runtime-process.ts:631    value && value.trim()…   ->  value !== undefined        (B2-T1-4)
#
# The last is one of two possible repairs for X-2 (the other: both gates treat a blank value as
# unset); which one is the intent is a person's decision, and this control only shows that the
# repro command can tell fixed from unfixed.
#
#   control_fixed.sh [scratch dir]      exit 0 iff every repro exits 1 on the real tree and 0
#                                       on the fixed copy
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
real_tree="$(cd "$here/../../tree" && pwd)"
s="${1:-$(mktemp -d)}"
rm -rf "$s/tree" "$s/out"
mkdir -p "$s/tree/src/tui" "$s/tree/packages" "$s/out"
cp -r "$real_tree/src/tui/src" "$s/tree/src/tui/"
cp -r "$real_tree/packages/motoko-ext-herdr" "$real_tree/packages/motoko-ext-abi" "$s/tree/packages/"
cp -r "$here" "$s/out/repro"

patch_one() {  # patch_one <file> <python old> <python new>
  python3 -I - "$1" "$2" "$3" <<'EOF'
import sys
p, old, new = sys.argv[1:]
s = open(p, encoding="utf-8").read()
assert s.count(old) == 1, f"{p}: expected exactly one {old!r}"
open(p, "w", encoding="utf-8").write(s.replace(old, new))
EOF
}
patch_one "$s/tree/packages/motoko-ext-herdr/types.ail" \
  '{ herdr_env >= "1" && bin_path != "" && pane_id != "" }' \
  '{ herdr_env == "1" && bin_path != "" && pane_id != "" }' || exit 2
patch_one "$s/tree/src/tui/src/herdr-agent-state.ts" \
  'if (!paneId || bin === undefined) return null;' 'if (!paneId || !bin) return null;' || exit 2
patch_one "$s/tree/packages/motoko-ext-herdr/register.ail" \
  'getEnvOr("HERDR_BIN_PATH", "herdr")' 'getEnvOr("HERDR_BIN_PATH", "")' || exit 2
patch_one "$s/tree/src/tui/src/runtime-process.ts" \
  'if (key.startsWith("HERDR_") && value && value.trim() !== "") {' \
  'if (key.startsWith("HERDR_") && value !== undefined) {' || exit 2

cmds=(
  "bash ../out/repro/p11_check.sh 2 /usr/local/bin/herdr w1:p7"
  "bash ../out/repro/p11_check.sh 1 '' w1:p7"
  "bash ../out/repro/chain_check.sh 1 UNSET w1:p7"
  "bash ../out/repro/chain_check.sh 1 /usr/local/bin/herdr ' '"
)
fail=0
for c in "${cmds[@]}"; do
  ( cd "$real_tree" && eval "$c" ) > /dev/null 2>&1; real=$?
  ( cd "$s/tree" && eval "$c" ) > /dev/null 2>&1; fixed=$?
  verdict=ok; [[ "$real" -eq 1 && "$fixed" -eq 0 ]] || { verdict=FAIL; fail=1; }
  echo "real tree exit $real, fixed copy exit $fixed  [$verdict]  $c"
done
exit "$fail"
