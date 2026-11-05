#!/usr/bin/env bash
# Negative control for run_diff.sh (039's practice, RESEARCH §4): plant ONE mutant at a time in a
# COPY of the real code (the tree is never written), re-run that half on the corpus, and count
# the cases where it now disagrees with the unmutated model output (../run/lean.out). A test
# that cannot tell the real code from a mutant would report 0.
#
#   run_mutants.sh        after ../run_diff.sh ../run has passed
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
diffdir="$(cd "$here/.." && pwd)"
repo="$(cd "$diffdir/../../tree" && pwd)"
work="$here/work"; rm -rf "$work"; mkdir -p "$work"
cut -d'|' -f1-4 "$diffdir/run/lean.out" > "$work/lean.ts"
cut -d'|' -f1,2,5,6 "$diffdir/run/lean.out" > "$work/lean.ail"

ts_mutant() {   # name, sed expression on wake-waiter.ts
  cp "$repo/src/tui/src/wake-waiter.ts" "$work/$1.ts"
  sed -i "$2" "$work/$1.ts"
  if cmp -s "$repo/src/tui/src/wake-waiter.ts" "$work/$1.ts"; then echo "  $1: MUTANT DID NOT APPLY"; return; fi
  WW_PATH="$work/$1.ts" bun "$diffdir/enumerate.ts" "$repo" "$diffdir/gen/corpus.json" > "$work/$1.out"
  echo "  TS mutant $1: $(diff "$work/$1.out" "$work/lean.ts" | grep -c '^<') of $(wc -l < "$work/lean.ts") cases mismatch the model"
}

ail_mutant() {  # name, sed expression on types.ail
  local pkg="$work/pkg_$1" gen="$work/gen_$1"
  mkdir -p "$pkg" "$gen"
  cp "$repo/packages/motoko-ext-herdr/types.ail" "$pkg/types.ail"
  sed -i "$2" "$pkg/types.ail"
  if cmp -s "$repo/packages/motoko-ext-herdr/types.ail" "$pkg/types.ail"; then echo "  $1: MUTANT DID NOT APPLY"; return; fi
  printf '[package]\nname = "sunholo/motoko_ext_herdr"\nversion = "0.1.0"\nedition = "1"\n\n[exports]\nmodules = ["sunholo/motoko_ext_herdr/types"]\n' > "$pkg/ailang.toml"
  printf '[package]\nname = "local/t2_mut"\nversion = "0.1.0"\nedition = "1"\n\n[dependencies]\n"sunholo/motoko_ext_herdr" = { path = "../pkg_%s" }\n' "$1" > "$gen/ailang.toml"
  cp "$diffdir/gen/enumerate_herdr.ail" "$gen/"
  ( cd "$gen" && ailang lock >/dev/null 2>&1 )
  ( cd "$repo" && ailang run --relax-modules --caps IO --entry main "$gen/enumerate_herdr.ail" 2>"$work/$1.err" ) | grep -E '^[0-9]+\|' > "$work/$1.out"
  echo "  AILANG mutant $1: $(diff "$work/$1.out" "$work/lean.ail" | grep -c '^<') of $(wc -l < "$work/lean.ail") cases mismatch the model ($(wc -l < "$work/$1.out") lines run)"
}

echo "negative control:"
ts_mutant  exact_agent_not_found 's/return herdrFailureCode(r).endsWith("_not_found");/return herdrFailureCode(r) === "agent_not_found";/'
ts_mutant  code_eq_0             's/if (r.code <= 0) return "";/if (r.code === 0) return "";/'
ts_mutant  no_trim               's/JSON.parse(r.stderr.trim())/JSON.parse(r.stderr)/'
ail_mutant json_before_nested    's/else if contains(stderr, "nested herdr") then "nested_herdr"/else if contains(stderr, "nested herdr") \&\& !contains(stderr, "{\\"error\\"") then "nested_herdr"/'
ail_mutant sniff_error_key       's/else if contains(stderr, "{\\"error\\"") then "herdr_json"/else if contains(stderr, "\\"error\\"") then "herdr_json"/'
