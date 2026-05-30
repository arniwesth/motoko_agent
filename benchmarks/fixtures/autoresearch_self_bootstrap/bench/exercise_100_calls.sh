#!/usr/bin/env bash
set -euo pipefail
# Simulate the derive_state hot path 100 times.
#
# derive_state (state.ail) makes 3 duckdb spawns per call in the Ready state:
#   1. current_segment → current_session_row → SELECT * FROM sessions ORDER BY id DESC LIMIT 1
#   2. current_status  → current_session_row → (same query, separate spawn)
#   3. has_pending_run → SELECT COUNT(*) AS n FROM pending_runs WHERE segment = ...
#
# We replicate this exact pattern so the shim counts match real behavior.
# The DB must contain an active session row for the queries to exercise the
# same code path as the real Ready state.
#
# Total duckdb invocations through the shim: 1 (schema/seed) + 100*3 = 301.
# The +1 seed call is consistent across every run, so it does not affect
# relative comparisons. The baseline duckdb_spawns_per_100_calls metric is
# therefore 301, not 300 — this is expected; do not investigate the off-by-one.

SD="${SESSION_DIR:-.motoko/autoresearch}"
DB="$SD/autoresearch.db"
mkdir -p "$SD"

# Bootstrap schema + seed an active session so derive_state hits the 3-query
# Ready path (not the 1-query Setup shortcut for empty DBs).
duckdb "$DB" "
CREATE SEQUENCE IF NOT EXISTS seq_sessions START 1;
CREATE SEQUENCE IF NOT EXISTS seq_runs START 1;
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER DEFAULT nextval('seq_sessions') PRIMARY KEY,
  segment INTEGER, objective TEXT, metrics_json TEXT,
  scope_paths_json TEXT, off_limits_json TEXT, constraints_json TEXT,
  max_iterations INTEGER, patience INTEGER DEFAULT 3,
  init_dirty_json TEXT, status TEXT DEFAULT 'active',
  done_reason TEXT, baseline_commit TEXT, branch TEXT, cwd TEXT, ts BIGINT
);
CREATE TABLE IF NOT EXISTS pending_runs (
  session_id INTEGER, segment INTEGER, run_number INTEGER,
  metrics_json TEXT, samples_json TEXT, asi_json TEXT,
  checks_passed BOOLEAN, exit_code INTEGER, duration_ms INTEGER, ts BIGINT
);
INSERT INTO sessions (segment, objective, status)
  SELECT 1, 'bench-seed', 'active'
  WHERE NOT EXISTS (SELECT 1 FROM sessions);
" 2>/dev/null

for i in $(seq 1 100); do
  # Query 1: current_segment (via current_session_row)
  duckdb "$DB" -json -c "SELECT * FROM sessions ORDER BY id DESC LIMIT 1" >/dev/null 2>&1
  # Query 2: current_status (calls current_session_row again — separate spawn)
  duckdb "$DB" -json -c "SELECT * FROM sessions ORDER BY id DESC LIMIT 1" >/dev/null 2>&1
  # Query 3: has_pending_run
  duckdb "$DB" -json -c "SELECT COUNT(*) AS n FROM pending_runs WHERE segment = 1" >/dev/null 2>&1
done
