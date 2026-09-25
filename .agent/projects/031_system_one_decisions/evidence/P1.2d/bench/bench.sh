#!/usr/bin/env bash
# P1.2d measurement (ADR-001 D2 "Cost"): hook latency before (7.4) and after (8.0) for
# compose's ResponseInterceptor and herdr's PromptShaper, plus retained config bytes.
# Run from the repo root:  bench.sh [rounds]   (default 3; each round runs 7.4 then 8.0,
# interleaved so drift hits both alike). Writes RAW.txt and SUMMARY.txt beside itself.
#
# BEFORE: a lock-free workspace from `git archive 181051d0` (7.4 ABI; compose, herdr and
# ai-compat as of that commit -- byte-identical to their state before P1.2d).
# AFTER: the ABI and ai-compat from `git show HEAD`, compose and herdr from the cwd's
# working files (P1.2d's own paths). Never a clone against the root lock.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); R=$(pwd); rounds=${1:-3}
W=$(mktemp -d "${TMPDIR:-/tmp}/p12dbench.XXXXXX"); trap 'rm -rf "$W"' EXIT
mk() { # $1 dir; packages already under $1/packages
  cat > "$1/ailang.toml" <<TOML
[package]
name = "local/p12dbench"
version = "0.1.0"
edition = "1"
ailang = ">=0.33.0"

[dependencies]
"sunholo/motoko_ext_abi" = { path = "packages/motoko-ext-abi" }
"sunholo/motoko_ext_ai_compat" = { path = "packages/motoko-ext-ai-compat" }
"sunholo/motoko_ext_compose" = { path = "packages/motoko-ext-compose" }
"sunholo/motoko_ext_herdr" = { path = "packages/motoko-ext-herdr" }

[effects]
max = ["IO", "Env", "AI", "Net", "FS", "Process", "SharedMem", "Clock", "Stream", "Rand", "Trace"]
TOML
  find "$1/packages" -name ailang.lock -delete
  ( cd "$1" && ailang lock > lock.log 2>&1 ) || { cat "$1/lock.log"; exit 1; }
}
mkdir -p "$W/v74" "$W/v80/packages"
git archive 181051d0 packages/motoko-ext-abi packages/motoko-ext-ai-compat packages/motoko-ext-compose packages/motoko-ext-herdr | tar -x -C "$W/v74"
git archive HEAD packages/motoko-ext-abi packages/motoko-ext-ai-compat | tar -x -C "$W/v80"
cp -r packages/motoko-ext-compose packages/motoko-ext-herdr "$W/v80/packages/"
cp "$D/bench_74.ail" "$W/v74/"; cp "$D/bench_80.ail" "$W/v80/"
mk "$W/v74"; mk "$W/v80"
: > "$D/RAW.txt"
for i in $(seq 1 "$rounds"); do
  for v in 74 80; do
    ( cd "$W/v$v" && AILANG_RELAX_MODULES=1 ailang run --caps IO,Process,FS,Clock,Env,AI,Rand --entry main bench_$v.ail ) > "$W/out.txt" 2>&1 \
      || { tail -20 "$W/out.txt"; echo "bench: v$v run FAILED"; exit 1; }
    grep -E '^(SAMPLE|CONFIG) ' "$W/out.txt" | sed "s/^/v$v round$i /" >> "$D/RAW.txt"
  done
done
python3 "$D/summarize.py" "$D/RAW.txt" | tee "$D/SUMMARY.txt"
