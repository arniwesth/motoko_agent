#!/usr/bin/env bash
# X-3 / P3.1: message text that is not valid UTF-8. The child hashes the raw bytes
# (phase_vocab.canonical_message_frame) but its wire encoding (std/json encode) replaces them
# with U+FFFD, so the REAL host journals text whose chain it cannot match; the REAL twin folds
# the in-memory message and accepts.
#   bash ../out/repro/unicode.sh [case]      (from the tree root; default case bad_utf8)
# Cases (unicode_probe.ail): ascii html emoji lsep nul_ctrl bad_utf8 cesu_surrogate bom.
# Exit 1 when the host's and the twin's journals fold differently (defect present), else 0.
source "$(dirname "$0")/_env.sh"
case="${1:-bad_utf8}"
cp "$here/unicode_probe.ail" "$mod/repro/"
ail --caps IO --entry main repro/unicode_probe.ail | grep -aE "^[WT]	${case}	" > "$work/gen.out"
twin="$(grep -aE '^T	' "$work/gen.out" | cut -f3)"
host="$(host_verdict "$work/gen.out" | cut -f3)"
echo "case $case"
echo "  wire bytes of the appended message's content: $(grep -aE '^W	' "$work/gen.out" | sed -n 3p | grep -ao '"content":"[^"]*"' | od -An -tx1 | tr -s ' ' | head -2 | tr '\n' ' ')"
echo "  host journal folds to: $host"
echo "  twin journal folds to: $twin   (history contents as base64)"
h="${host%%;*}"; t="${twin%%;*}"
[[ "$host" == R\;* ]] && h="$host"; [[ "$twin" == R\;* ]] && t="$twin"
if [[ "$h" != "$t" ]]; then echo "P3.1 VIOLATED"; exit 1; fi
echo "P3.1 holds (both ${h})"; exit 0
