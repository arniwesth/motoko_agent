#!/usr/bin/env bash
# negative_controls.sh — every repro in reports.tsv against the real tree and against scratch
# copies of it with one defect fixed (and all fixed). The tree itself is never modified.
#
#   bash <out>/negative_controls.sh          (from the tree root; ~6-8 minutes)
#
# Each repro must exit 1 on the unmodified copy and 0 on the copy with its own defect fixed.
# The table also shows what each repro does on the other copies, which is how the classes
# are seen to be independent. Exit 0 when every expectation holds, 1 otherwise.
#
# The fixes (one line each, applied with sed to the copies):
#   envfix   types.ail      herdr_env >= "1"         ->  herdr_env == "1"
#   binfix   herdr-agent-state.ts  bin === undefined ->  !bin
#   regfix   register.ail   getEnvOr("HERDR_BIN_PATH", "herdr")  ->  getEnvOr("HERDR_BIN_PATH", "")
#   panefix  runtime-process.ts    forward HERDR_PANE_ID whenever it is non-empty
#   allfix   all four
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(pwd)"
[[ -f "$root/src/tui/src/herdr-agent-state.ts" ]] || { echo "run from the tree root" >&2; exit 2; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

ENVFIX='s/{ herdr_env >= "1" \&\& bin_path != "" \&\& pane_id != "" }/{ herdr_env == "1" \&\& bin_path != "" \&\& pane_id != "" }/'
BINFIX='s/if (!paneId || bin === undefined) return null;/if (!paneId || !bin) return null;/'
REGFIX='s/let bin_path  = getEnvOr("HERDR_BIN_PATH", "herdr");/let bin_path  = getEnvOr("HERDR_BIN_PATH", "");/'
PANEFIX='s/if (key.startsWith("HERDR_") \&\& value \&\& value.trim() !== "") {/if (key.startsWith("HERDR_") \&\& value \&\& (key === "HERDR_PANE_ID" || value.trim() !== "")) {/'

apply() { # <copy> <fix>
  local c="$1"
  case "$2" in
    envfix)  sed -i "$ENVFIX"  "$c/packages/motoko-ext-herdr/types.ail" ;;
    binfix)  sed -i "$BINFIX"  "$c/src/tui/src/herdr-agent-state.ts" ;;
    regfix)  sed -i "$REGFIX"  "$c/packages/motoko-ext-herdr/register.ail" ;;
    panefix) sed -i "$PANEFIX" "$c/src/tui/src/runtime-process.ts" ;;
  esac
}
for m in orig envfix binfix regfix panefix allfix; do
  bash "$here/mkcopy.sh" "$root" "$work/$m"
  case "$m" in
    orig) ;;
    allfix) for f in envfix binfix regfix panefix; do apply "$work/$m" "$f"; done ;;
    *) apply "$work/$m" "$m" ;;
  esac
  if [[ "$m" != orig ]] && diff -rq "$work/orig" "$work/$m" > /dev/null; then
    echo "fix $m did not apply (the source line changed?)"; exit 2
  fi
done

declare -A REPRO=(
  [A2-T1-1]="bash $here/p11/run_p11.sh --class ENV_GT_1"
  [A2-T1-2]="bash $here/p11/run_p11.sh --class BIN_EMPTY"
  [A2-T1-3]="bun $here/callsite/run_callsite.ts . --prop X-1 --class BIN_UNSET --grid small"
  [A2-T1-4]="bun $here/callsite/run_callsite.ts . --prop X-2 --class PANE_DROP --grid small"
)
declare -A OWNFIX=([A2-T1-1]=envfix [A2-T1-2]=binfix [A2-T1-3]=regfix [A2-T1-4]=panefix)

bad=0
printf "%-8s %-7s %-7s %-7s %-7s %-7s %-7s\n" report orig envfix binfix regfix panefix allfix
for r in A2-T1-1 A2-T1-2 A2-T1-3 A2-T1-4; do
  row="$(printf "%-8s" "$r")"
  for m in orig envfix binfix regfix panefix allfix; do
    ( cd "$work/$m" && timeout 120 ${REPRO[$r]} > "$work/$r.$m.log" 2>&1 )
    code=$?
    row+="$(printf " %-7s" "$code")"
    if [[ "$m" == orig && "$code" != 1 ]]; then bad=1; fi
    if [[ "$m" == "${OWNFIX[$r]}" || "$m" == allfix ]] && [[ "$code" != 0 ]]; then bad=1; fi
  done
  echo "$row"
done
echo "expectation: 1 under orig, 0 under the report's own fix and under allfix"
exit "$bad"
