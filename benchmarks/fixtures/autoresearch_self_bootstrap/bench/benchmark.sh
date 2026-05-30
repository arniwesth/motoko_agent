#!/usr/bin/env bash
set -euo pipefail
# Metric emitter for the self-bootstrap benchmark. Prints exactly three lines:
#   METRIC duckdb_spawns_per_100_calls=<int>
#   METRIC overhead_ms=<int>
#   METRIC ext_lines=<int>
#
# Invoked (indirectly) by ar_run via the benchmark_script wrapper, which sets
# DUCKDB_REAL and SPAWN_LOG and cd's into the worktree root.

# Resolve directories relative to this script so it works regardless of CWD.
BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_DIR="$(cd "$BENCH_DIR/.." && pwd)"

# DUCKDB_REAL must be set and executable BEFORE we shadow duckdb on PATH,
# otherwise the shim would recurse into itself.
: "${DUCKDB_REAL:?DUCKDB_REAL must be set to the real duckdb binary}"
test -x "$DUCKDB_REAL" || { echo "DUCKDB_REAL not executable: $DUCKDB_REAL" >&2; exit 1; }

: "${SPAWN_LOG:=$BENCH_DIR/spawn.log}"
export SPAWN_LOG

# Reset the spawn log for this sample.
: > "$SPAWN_LOG"

# Put the counting shim first on PATH so every `duckdb` call is counted.
export PATH="$BENCH_DIR/shim:$PATH"

# Disposable session dir for the exercise (kept inside bench/).
export SESSION_DIR="$BENCH_DIR/bench_session"
rm -rf "$SESSION_DIR"

# --- Metrics 1 + 2: duckdb spawn count and wall-time overhead for 100 calls ---
# Wall-time uses bash's real clock (date +%s%N), not the virtual AILANG clock.
start_ns="$(date +%s%N)"
bash "$BENCH_DIR/exercise_100_calls.sh"
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
