#!/usr/bin/env bash
# run_direct.sh <cases file> <work dir>   (from the tree root)
#
# Builds the export shim of the REAL store.ail in <work dir>/shim, a driver package in
# <work dir>/drv, and runs t6_direct.ail over <cases file>; prints its output lines on stdout.
# Refuses (exit 3) if the shim differs from the real file in anything but the one `export`.
set -euo pipefail
cases="$1"; work="$2"
tree="$(pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
real="$tree/packages/motoko-ext-compose/store.ail"
[[ -f "$real" ]] || { echo "run_direct.sh: run from the tree root ($real missing)" >&2; exit 3; }
mkdir -p "$work/shim" "$work/drv"
sed 's/^func truncate_utf8_by_bytes(/export func truncate_utf8_by_bytes(/' "$real" > "$work/shim/store.ail"
d="$(diff "$real" "$work/shim/store.ail" | grep -c '^[<>]' || true)"
# 2 lines differ (the one `export` added), or 0 if the real file already exports it.
if [[ "$d" == "0" ]]; then grep -q '^export func truncate_utf8_by_bytes(' "$real" || d=x; fi
[[ "$d" == "2" || "$d" == "0" ]] || { echo "run_direct.sh: shim differs from the real store.ail in $d lines, expected 2" >&2; exit 3; }
# Negative control only (never set by a repro): T6_MUTANT=bytegate swaps the rune-count gate
# for a byte-count gate, `let n = Str.length(s);` -> `let n = length(b);`.
if [[ "${T6_MUTANT:-}" == "bytegate" ]]; then
  sed -i 's/^  let n = Str.length(s);$/  let n = length(b);/' "$work/shim/store.ail"
  d="$(diff "$real" "$work/shim/store.ail" | grep -c '^[<>]' || true)"
  [[ "$d" == "4" ]] || { echo "run_direct.sh: bytegate mutant did not apply ($d lines differ)" >&2; exit 3; }
  echo "run_direct.sh: MUTANT bytegate applied" >&2
fi
# Negative control only: T6_MUTANT=fixed is bytegate plus a cut that backs off to a character
# boundary (never inside a continuation byte), so P6.1, P6.2 and P6.3 should all hold.
if [[ "${T6_MUTANT:-}" == "fixed" ]]; then
  sed -i -e 's/^import std\/bytes (fromString, length, slice, toString)$/import std\/bytes (fromString, length, slice, toString, byteAt)/' \
         -e 's/^  let n = Str.length(s);$/  let n = length(b);/' \
         -e 's/^    match slice(b, 0, max_bytes) {$/    match slice(b, 0, t6_cut(b, max_bytes)) {/' "$work/shim/store.ail"
  cat >> "$work/shim/store.ail" <<'AIL'

pure func t6_cut(b: bytes, k: int) -> int {
  if k <= 0 then k
  else match byteAt(b, k) {
    Some(x) => if x >= 128 && x < 192 then t6_cut(b, k - 1) else k,
    None => k
  }
}
AIL
  d="$(diff "$real" "$work/shim/store.ail" | grep -c '^[<>]' || true)"
  [[ "$d" -ge 8 ]] || { echo "run_direct.sh: fixed mutant did not apply ($d lines differ)" >&2; exit 3; }
  echo "run_direct.sh: MUTANT fixed applied" >&2
fi
cat > "$work/shim/ailang.toml" <<TOML
[package]
name = "sunholo/motoko_ext_compose"
version = "0.2.4"
edition = "1"
ailang = ">=0.21.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "$tree/packages/motoko-ext-abi", version = "8.0" }

[effects]
max = ["IO", "FS"]

[exports]
modules = ["sunholo/motoko_ext_compose/store"]
TOML
cat > "$work/drv/ailang.toml" <<TOML
[package]
name = "local/t6_direct"
version = "0.1.0"
edition = "1"
ailang = ">=0.54.14"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "$tree/packages/motoko-ext-abi" }
"sunholo/motoko_ext_compose" = { path = "$work/shim" }
TOML
cp "$here/t6_direct.ail" "$work/drv/t6_direct.ail"
( cd "$work/shim" && ailang lock >/dev/null 2>&1 )
( cd "$work/drv" && ailang lock >/dev/null 2>&1 )
ailang run --relax-modules --caps IO,FS --entry main --args-json "\"$cases\"" "$work/drv/t6_direct.ail" > "$work/direct.raw" 2> "$work/direct.err" || true
grep -E '^[0-9,]*\|-?[0-9]+\|' "$work/direct.raw" > "$work/direct.raw.lines" || { echo "run_direct.sh: no output; stderr:" >&2; cat "$work/direct.err" >&2; exit 3; }
cat "$work/direct.raw.lines"
