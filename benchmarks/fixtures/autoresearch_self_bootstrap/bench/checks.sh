#!/usr/bin/env bash
set -euo pipefail
# Behavior-preservation guard for the candidate extension. Exits non-zero on any
# violation. Combines cheap structural greps with the candidate's OWN test suite
# (off-limits, so the optimizer cannot weaken it) — this is what stops the
# optimizer from "winning" the spawn metric by breaking derive_state.

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_DIR="$(cd "$BENCH_DIR/.." && pwd)"

fail() { echo "CHECK FAILED: $1" >&2; exit 1; }

# --- Structural invariants (fast, source-level) ---

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

# Hot path still spawns duckdb via exec in db.ail.
grep -qE 'exec.*duckdb' "$CANDIDATE_DIR/db.ail" \
  || fail "db.ail must spawn duckdb via exec"

# --- Functional invariants (the candidate's own immutable test suite) ---
# Run from the candidate package root so module imports resolve. These tests are
# in off_limits, so the optimizer cannot edit them to pass trivially.
# Decide pass/fail from the test summary ("N failed"), NOT the process exit code:
# right after the benchmark's `ailang run`, `ailang test` can exit non-zero for a
# non-test reason (a "content changed, run ailang lock" cache/lock warning) even
# though every test passes. One retry absorbs transient cache/lock races. A real
# regression still shows ">0 failed" (or produces no summary) and fails here.
test_passes() {
  local t="$1" out
  out="$(AILANG_RELAX_MODULES=1 ailang test "${t}.ail" 2>&1 || true)"
  if printf '%s' "$out" | grep -qE '0 failed'; then return 0; fi
  out="$(AILANG_RELAX_MODULES=1 ailang test "${t}.ail" 2>&1 || true)"
  if printf '%s' "$out" | grep -qE '0 failed'; then return 0; fi
  echo "CHECK FAILED: candidate ${t}.ail did not pass" >&2
  printf '%s\n' "$out" | tail -15 >&2
  return 1
}
(
  cd "$CANDIDATE_DIR"
  for t in state_test scope_test metrics_test; do
    test_passes "$t" || exit 1
  done
)

echo "checks: OK"
