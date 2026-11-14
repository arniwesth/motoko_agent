#!/usr/bin/env bash
# mutants.sh — negative and positive controls for every repro in reports.tsv.
#
# Copies the code under test (packages/motoko-ext-herdr, packages/motoko-ext-abi, src/tui/src) and
# the harnesses into a work directory laid out like tree/ and out/, applies ONE edit at a time to the
# copy, and runs the repros against it. The real tree is never written.
#
# Each row says what a repro must do on that copy: a "fix" mutant must turn its own repro from 1 to
# 0 and leave the others at 1; a "break" mutant must be caught by a slice that is clean on the real
# code. Exit 0 when every expectation holds, 1 otherwise.
#
#   mutants.sh [work dir]          run from anywhere; default work dir: mktemp -d
set -uo pipefail

out="$(cd "$(dirname "$0")" && pwd)"
tree="$(cd "$out/../tree" && pwd)"
W="${1:-$(mktemp -d)}"
rm -rf "$W"; mkdir -p "$W/tree/packages" "$W/tree/src/tui" "$W/out"

fresh() {
  rm -rf "$W/tree/packages/motoko-ext-herdr" "$W/tree/packages/motoko-ext-abi" "$W/tree/src/tui/src"
  cp -r "$tree/packages/motoko-ext-herdr" "$tree/packages/motoko-ext-abi" "$W/tree/packages/"
  cp -r "$tree/src/tui/src" "$W/tree/src/tui/"
}
cp "$out"/{gate_diff.ts,gate_ail.ail,register_diff.ts,register_ail.ail,ailang.toml,ailang.lock} "$W/out/"

TYPES="$W/tree/packages/motoko-ext-herdr/types.ail"
REG="$W/tree/packages/motoko-ext-herdr/register.ail"
TS="$W/tree/src/tui/src/herdr-agent-state.ts"

# A gate that accepts an empty pane id also accepts the blank one buildChildEnv drops, so X-2's
# witness agrees under break-ail-pane: x2 = 0 is expected there.
RP="$W/tree/src/tui/src/runtime-process.ts"

# Each repro, as reports.tsv runs it, but against the copy.
r_env()  { (cd "$W/tree" && bun "$W/out/gate_diff.ts" --scratch "$W/s" --case '["2","/usr/local/bin/herdr","w1:p7"]' >/dev/null 2>&1); echo $?; }
r_bin()  { (cd "$W/tree" && bun "$W/out/gate_diff.ts" --scratch "$W/s" --case '["1","","w1:p7"]' >/dev/null 2>&1); echo $?; }
r_x1()   { (cd "$W/tree" && bun "$W/out/register_diff.ts" --scratch "$W/s" --mode x1 --case '["1",null,"w1:p7"]' >/dev/null 2>&1); echo $?; }
r_x2()   { (cd "$W/tree" && bun "$W/out/register_diff.ts" --scratch "$W/s" --mode x2 --case '["1","/usr/local/bin/herdr"," "]' >/dev/null 2>&1); echo $?; }
r_all()  { (cd "$W/tree" && bun "$W/out/gate_diff.ts" --scratch "$W/s" --gen all >/dev/null 2>&1); echo $?; }
r_pane() { (cd "$W/tree" && bun "$W/out/gate_diff.ts" --scratch "$W/s" --gen pane >/dev/null 2>&1); echo $?; }

# sed one literal edit into a file; fail loudly if the anchor is not there (the mutant would be a no-op).
edit() {
  local file="$1" from="$2" to="$3"
  grep -qF -- "$from" "$file" || { echo "  ANCHOR NOT FOUND in $(basename "$file"): $from"; return 1; }
  FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/' "$file"
}

fail=0
check() { # name expected-env expected-bin expected-x1 expected-x2 expected-all expected-pane
  local name="$1"; shift
  local got="$(r_env) $(r_bin) $(r_x1) $(r_x2) $(r_all) $(r_pane)"
  local want="$*"
  local verdict=ok; [[ "$got" == "$want" ]] || { verdict=UNEXPECTED; fail=1; }
  printf '%-22s env bin x1 x2 all pane = %s   (expected %s)  %s\n' "$name" "$got" "$want" "$verdict"
}

fresh;                                                                         check "unmutated"            1 1 1 1 1 0
fresh; edit "$TYPES" 'herdr_env >= "1"' 'herdr_env == "1"';                    check "fix-ail-env"          0 1 1 1 1 0
fresh; edit "$TS" 'bin === undefined' '!bin';                                  check "fix-ts-bin"           1 0 1 1 1 0
fresh; edit "$TYPES" 'herdr_env >= "1"' 'herdr_env == "1"'
       edit "$TS" 'bin === undefined' '!bin';                                  check "fix-ail-env+ts-bin"   0 0 1 1 0 0
fresh; edit "$REG" 'getEnvOr("HERDR_BIN_PATH", "herdr")' 'getEnvOr("HERDR_BIN_PATH", "")'
                                                                               check "fix-register-bin"     1 1 0 1 1 0
# Two ways to make X-2's witness agree. Trimming in the TS twin alone moves only one copy, so the
# pane slice then catches a P1.1 mismatch (AILANG accepts " "): pane = 1 is expected.
fresh; edit "$TS" 'if (!paneId || bin' 'if (!paneId || paneId.trim() === "" || bin'
                                                                               check "fix-ts-pane-blank"    1 1 1 0 1 1
fresh; edit "$RP" 'key.startsWith("HERDR_") && value && value.trim() !== ""' 'key.startsWith("HERDR_") && value !== undefined'
                                                                               check "fix-forward-verbatim" 1 1 1 0 1 0
fresh; edit "$TS" 'if (!paneId ||' 'if (paneId === undefined ||';              check "break-ts-pane"        1 1 1 1 1 1
fresh; edit "$TYPES" 'pane_id != ""' 'true';                                   check "break-ail-pane"       1 1 1 0 1 1
exit "$fail"
