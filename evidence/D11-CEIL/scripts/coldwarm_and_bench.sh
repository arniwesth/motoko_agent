#!/usr/bin/env bash
# Phase B: one clone, cold/warm split for corpus_pr, and the per-seed bench at
# two counts. The bench is copied in because it is not committed yet.
set -uo pipefail
ROOT=/tmp/claude-1001/-workspaces-motoko-agent/bd8176ff-ae08-43f2-b32d-d7d1bfa1141e/scratchpad/d11
CLONE=$ROOT/clone-B
PRIMARY=/workspaces/motoko_agent
rm -rf "$CLONE"
git clone -q --no-hardlinks "$PRIMARY" "$CLONE" || exit 1
git -C "$CLONE" checkout -q cdf0f65f || exit 1
mkdir -p "$CLONE/evidence/D11-CEIL"
cp "$PRIMARY/evidence/D11-CEIL/per_seed_bench.ail" "$CLONE/evidence/D11-CEIL/" || exit 1
( cd "$CLONE" && make CI=1 sync_packages ) > "$ROOT/b-sync.log" 2>&1 || { echo "SYNC_FAIL"; tail -5 "$ROOT/b-sync.log"; exit 1; }
grep -q "$CLONE" "$CLONE/ailang.lock" || { echo "LOCK_NOT_REPOINTED"; exit 1; }

t(){ local s=$(date +%s%N); "$@" >/dev/null 2>&1; local r=$?; local e=$(date +%s%N); echo $(( (e-s)/1000000 )):$r; }

echo "foreign_at_start=$(pgrep -x ailang | wc -l)"
cd "$CLONE"
echo "corpus_pr COLD  = $(t make corpus_pr)"
echo "corpus_pr WARM  = $(t make corpus_pr)"

bench(){ MOTOKO_BENCH_SEEDS=$1 ailang run --caps IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace \
   --ai-stub --entry main evidence/D11-CEIL/per_seed_bench.ail < /dev/null; }

# prime: compiles the bench module itself so the two timed runs measure seeds
echo "bench PRIME n=1 = $(t bench 1)"
bench 1 > "$ROOT/b-bench-prime.out" 2>&1; echo "prime output: $(grep -a BENCH "$ROOT/b-bench-prime.out" | head -1)"
echo "bench n=25      = $(t bench 25)"
echo "bench n=100     = $(t bench 100)"
bench 100 > "$ROOT/b-bench-100.out" 2>&1; echo "n=100 output: $(grep -a BENCH "$ROOT/b-bench-100.out" | head -1)"
echo "foreign_at_end=$(pgrep -x ailang | wc -l)"
