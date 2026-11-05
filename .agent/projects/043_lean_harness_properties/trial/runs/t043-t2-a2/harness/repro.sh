#!/usr/bin/env bash
# repro.sh — one witness through both REAL twins; exit 1 when the named property fails on it.
#
#   bash ../out/harness/repro.sh P2.1 ../out/witness/A2-T2-1.json     (from the tree root)
#
#   P2.1  herdrMeansAgentGone == means_agent_gone   (exit 1 when they differ)
#   P2.2  herdrFailureCode    == failure_code       (exit 1 when they differ)
#
# Witness file: {"exit": <int>, "stderr": <string>}, no spawn error. Exit 0 when the twins agree,
# 1 when they disagree, 3 on a harness error. Prints both sides.
# T2_TS_MODULE / T2_AIL_ENTRY point at patched copies instead of the tree (fixcheck/ only).
set -uo pipefail
prop="$1"; witness="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
here="$(cd "$(dirname "$0")" && pwd)"
out="$(cd "$here/.." && pwd)"
tree="$(cd "$out/../tree" && pwd)"
entry="${T2_AIL_ENTRY:-$here/ail_eval.ail}"
# The lock pins the package by content hash: regenerate it next to the nearest ailang.toml.
proj="$(dirname "$entry")"; while [[ ! -f "$proj/ailang.toml" && "$proj" != "/" ]]; do proj="$(dirname "$proj")"; done
( cd "$proj" && ailang lock >/dev/null 2>&1 ) || { echo "ailang lock failed in $proj"; exit 3; }
case_line="$(bun "$here/gen.ts" one "$witness")" || { echo "gen failed"; exit 3; }
ts="$(printf '%s\n' "$case_line" | bun "$here/ts_eval.ts")" || { echo "ts_eval failed"; exit 3; }
ail="$(cd "$tree" && printf '%s\n' "$case_line" | ailang run --relax-modules --caps IO --entry main "$entry" 2>/dev/null | grep -E '^[0-9]+	')" || { echo "ailang failed"; exit 3; }
d() { printf '%s' "$1" | base64 -d; }
tcode="$(d "$(cut -f2 <<<"$ts")")"; tgone="$(cut -f3 <<<"$ts")"
ashape="$(cut -f2 <<<"$ail")"; acode="$(d "$(cut -f3 <<<"$ail")")"; agone="$(cut -f4 <<<"$ail")"
echo "witness: $(cat "$witness")"
echo "TS : herdrFailureCode=\"$tcode\" herdrMeansAgentGone=$tgone"
echo "AIL: failure_shape=$ashape failure_code=\"$acode\" means_agent_gone=$agone"
case "$prop" in
  P2.1) [[ "$tgone" == "$agone" ]] && { echo "P2.1 holds"; exit 0; } || { echo "P2.1 FAILS"; exit 1; } ;;
  P2.2) [[ "$tcode" == "$acode" ]] && { echo "P2.2 holds"; exit 0; } || { echo "P2.2 FAILS"; exit 1; } ;;
  *) echo "unknown property $prop"; exit 3 ;;
esac
