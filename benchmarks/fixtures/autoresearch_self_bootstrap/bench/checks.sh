#!/usr/bin/env bash
set -euo pipefail
# Validates FSM behavior, scope gating, and logging invariants of the candidate
# extension source. Exits non-zero on any violation. These checks guard the
# behavior the optimizer must NOT change while it reduces overhead.

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_DIR="$(cd "$BENCH_DIR/.." && pwd)"

fail() { echo "CHECK FAILED: $1" >&2; exit 1; }

# derive_state remains exported and DB-authoritative.
grep -qE 'export func derive_state' "$CANDIDATE_DIR/state.ail" \
  || fail "derive_state must remain exported in state.ail"
grep -qE 'DB\.' "$CANDIDATE_DIR/state.ail" \
  || fail "derive_state must consult the DB (DB. calls) in state.ail"

# AwaitingLog hard-block invariant preserved.
grep -qE 'AwaitingLog.*must be logged before another ar_run' "$CANDIDATE_DIR/state.ail" \
  || fail "AwaitingLog hard-block message must be preserved in state.ail"

# Scope gating stays prefix/exact only (no glob semantics).
grep -qE 'export pure func path_matches_spec' "$CANDIDATE_DIR/scope.ail" \
  || fail "path_matches_spec must remain exported in scope.ail"
if grep -qE '\*\*' "$CANDIDATE_DIR/scope.ail"; then
  fail "scope.ail must not introduce ** glob semantics"
fi

# Benchmark hot path still spawns duckdb via exec in db.ail.
grep -qE 'exec.*duckdb' "$CANDIDATE_DIR/db.ail" \
  || fail "db.ail must spawn duckdb via exec"

echo "checks: OK"
