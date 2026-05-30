#!/usr/bin/env bash
set -euo pipefail
# Metric emitter for the self-bootstrap benchmark. Prints exactly three lines:
#   METRIC duckdb_spawns_per_100_calls=<int>
#   METRIC overhead_ms=<int>
#   METRIC ext_lines=<int>
#
# Unlike a simulation, this RUNS THE CANDIDATE'S OWN CODE: it compiles and
# executes `exercise_derive_state.ail`, which imports the candidate `state`/`db`
# modules and calls the real `derive_state` 100 times. Every duckdb process the
# candidate spawns is counted by the shim, so candidate edits move the metric.

# Resolve directories relative to this script so it works regardless of CWD.
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_DIR="$(cd "$BENCH_DIR/.." && pwd)"

# DUCKDB_REAL must be set and executable BEFORE we shadow duckdb on PATH,
# otherwise the shim would recurse into itself.
: "${DUCKDB_REAL:?DUCKDB_REAL must be set to the real duckdb binary}"
test -x "$DUCKDB_REAL" || { echo "DUCKDB_REAL not executable: $DUCKDB_REAL" >&2; exit 1; }

# Ephemeral scratch for the exercise's duckdb DB + the shim's spawn log.
# It must satisfy two constraints:
#   1. Sandbox-writable. Under ar_run the benchmark executes inside the runtime's
#      sandboxed exec, which may NOT permit writes to /tmp (where `mktemp -d`
#      lands). The caller therefore passes AR_BENCH_SCRATCH pointing at a
#      workdir-relative, sandbox-writable directory (see the ar_init
#      benchmark_script wrapper).
#   2. Outside the worktree's scoped/off-limits candidate paths, so the benchmark
#      never dirties them (which would trip ar_log's scope-deviation guard).
# When run standalone (no AR_BENCH_SCRATCH), fall back to mktemp.
if [ -n "${AR_BENCH_SCRATCH:-}" ]; then
  WORK="$AR_BENCH_SCRATCH"
  rm -rf "$WORK"; mkdir -p "$WORK"
else
  WORK="$(mktemp -d)"
fi
trap 'rm -rf "$WORK"' EXIT
export SPAWN_LOG="$WORK/spawn.log"; : > "$SPAWN_LOG"
export SESSION_DIR="$WORK/session"

# Put the counting shim first on PATH so every `duckdb` call is counted.
export PATH="$BENCH_DIR/shim:$PATH"

# --- Metrics 1 + 2: real duckdb spawn count and wall-time for 100 calls ---
# Run from the candidate package root so `pkg/sunholo/motoko_ext_autoresearch/*`
# resolves to the candidate's own modules. AILANG_RELAX_MODULES=1 lets the
# fixture live at bench/ without a path-matching module name. Wall-time uses
# bash's real clock (date +%s%N), not the virtual AILANG clock.
start_ns="$(date +%s%N)"
(
  cd "$CANDIDATE_DIR"
  AILANG_RELAX_MODULES=1 ailang run --caps IO,Process,FS,Clock,Env \
    bench/exercise_derive_state.ail >/dev/null
)
end_ns="$(date +%s%N)"

spawns="$(wc -l < "$SPAWN_LOG" | tr -d ' ')"
overhead_ms=$(( (end_ns - start_ns) / 1000000 ))

# --- Metric 3: candidate source size ---
# Count only candidate source (*.ail), excluding bench/, *_test.ail, _smoke.ail,
# and registry_generated.ail.
ext_lines="$(
  find "$CANDIDATE_DIR" -name '*.ail' \
    -not -path "$CANDIDATE_DIR/bench/*" \
    -not -name '*_test.ail' \
    -not -name '_smoke.ail' \
    -not -name 'registry_generated.ail' \
    -print0 \
  | xargs -0 cat \
  | wc -l | tr -d ' '
)"

echo "METRIC duckdb_spawns_per_100_calls=${spawns}"
echo "METRIC overhead_ms=${overhead_ms}"
echo "METRIC ext_lines=${ext_lines}"
