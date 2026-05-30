Run Appendix A "Self-Research Bootstrap (optimizer != optimized)" from `.agent/plans/Motoko-auto-research/implementation-plan.md`.

Goal:
- Have the running autoresearch extension optimize a separate candidate copy of itself, not the live extension.

Hard requirements:
1. Do not modify `packages/motoko-ext-autoresearch/` in this run.
2. Keep benchmark and checks immutable during optimization (off-limits to candidate edits).
3. Use `scope_paths` + `off_limits` so `optimizer != optimized`.
4. Use deterministic primary metric and noisy secondary metric exactly as intended.
5. Capture and preserve a measured baseline before candidate mutations.

Execution contract:
- Execute steps in order.
- Use repo root (`/workspaces/motoko_agent`) as cwd.
- Treat benchmark/check artifacts as immutable once hashed.
- Do not call `ar_run` again until pending run is logged with `ar_log`.

Execution plan:
1. Preflight guards (must pass):
   ```bash
   set -euo pipefail
   test -d packages/motoko-ext-autoresearch
   test -x "$(command -v ailang)"
   test -x "$(command -v duckdb)"
   git rev-parse --is-inside-work-tree >/dev/null
   ```

2. Create candidate workspace:
   ```bash
   set -euo pipefail
   mkdir -p experiments
   rm -rf experiments/ar_candidate
   cp -R packages/motoko-ext-autoresearch experiments/ar_candidate
   mkdir -p experiments/ar_candidate/bench/shim
   ```

3. Create benchmark harness in `experiments/ar_candidate/bench/`:
   - `exercise_100_calls.ail`: deterministic hot-path trigger for exactly 100 extension-relevant calls.
   - `shim/duckdb`: counting shim that appends one line per invocation to `$SPAWN_LOG`, then `exec "$DUCKDB_REAL" "$@"`.
   - `benchmark.sh`: prints exactly:
     - `METRIC duckdb_spawns_per_100_calls=<int>`
     - `METRIC overhead_ms=<int>`
     - `METRIC ext_lines=<int>`
   - `checks.sh`: validates FSM behavior, scope gating, and logging invariants for candidate code; exits non-zero on failure.

   Required `benchmark.sh` behavior:
   - `set -euo pipefail`
   - verify `DUCKDB_REAL` is set and executable before PATH rewrite
   - reset `$SPAWN_LOG` each sample (`: > "$SPAWN_LOG"`)
   - run benchmark workload from isolated PATH with shim first
   - wall-time uses bash (`date +%s%N`), not virtual AILANG clock
   - `ext_lines` counts only candidate source (`*.ail`) excluding `bench/`, tests, and `registry_generated.ail`

4. Freeze benchmark/check artifacts (immutability):
   ```bash
   set -euo pipefail
   chmod +x experiments/ar_candidate/bench/shim/duckdb
   chmod +x experiments/ar_candidate/bench/benchmark.sh
   chmod +x experiments/ar_candidate/bench/checks.sh
   sha256sum \
     experiments/ar_candidate/bench/exercise_100_calls.ail \
     experiments/ar_candidate/bench/shim/duckdb \
     experiments/ar_candidate/bench/benchmark.sh \
     experiments/ar_candidate/bench/checks.sh \
     > experiments/ar_candidate/bench/immutable.sha256
   ```

5. Initialize autoresearch with exact tool argument shape:
   ```json
   ar_init({
     "objective": "Reduce per-tool-call overhead in derive_state hot path without behavior change",
     "metrics": [
       { "name": "duckdb_spawns_per_100_calls", "direction": "minimize", "noisy": false },
       { "name": "overhead_ms", "direction": "minimize", "noisy": true },
       { "name": "ext_lines", "direction": "minimize", "noisy": false }
     ],
     "scope_paths": [
       "experiments/ar_candidate/"
     ],
     "off_limits": [
       "packages/motoko-ext-autoresearch/",
       "experiments/ar_candidate/**/tests/**",
       "experiments/ar_candidate/**/*_test.ail",
       "experiments/ar_candidate/**/*.test.ail",
       "experiments/ar_candidate/bench/",
       "experiments/ar_candidate/**/registry_generated.ail",
       "packages/**/registry_generated.ail"
     ],
     "constraints": [
       "candidate must pass full candidate checks unchanged",
       "derive_state remains DB-authoritative",
       "no tool/schema contract changes",
       "AwaitingLog hard-block behavior preserved"
     ],
     "checks_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nbash experiments/ar_candidate/bench/checks.sh",
     "benchmark_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nexport DUCKDB_REAL=\"$(command -v duckdb)\"\nexport SPAWN_LOG=\"/workspaces/motoko_agent/experiments/ar_candidate/bench/spawn.log\"\nbash experiments/ar_candidate/bench/benchmark.sh",
     "patience": 4,
     "max_iterations": 25
   })
   ```

6. Capture baseline immediately after init (before edits):
   - Call:
     ```json
     ar_run({ "samples": 7 })
     ```
   - Record run metadata as baseline from returned aggregate metrics.
   - Immediately log it (usually `keep` if checks pass) with all required fields:
     ```json
     ar_log({
       "run_number": <baseline_run_number>,
       "decision": "keep",
       "changes_summary": "Baseline capture before candidate mutations",
       "reasoning": "Establishes authoritative baseline metrics for this segment",
       "learnings": "Baseline only",
       "justification": "No candidate edits; metrics snapshot"
     })
     ```

7. Iterate optimization loop:
   - edit candidate files only under `experiments/ar_candidate/` (respect off-limits)
   - call:
     ```json
     ar_run({ "samples": 7 })
     ```
   - inspect returned `metrics`, `within_run_mad`, `checks_passed`, and `run_number`
   - call `ar_log` with required fields every iteration:
     ```json
     ar_log({
       "run_number": <run_number_from_ar_run>,
       "decision": "keep|discard",
       "changes_summary": "<what changed>",
       "reasoning": "<why keep/discard based on metrics + checks>",
       "learnings": "<optional>",
       "justification": "<optional scope/off-limits note if relevant>"
     })
     ```
   - stop when one condition is met:
     - no primary-metric improvement for 4 consecutive kept runs (patience exhausted), or
     - `max_iterations` reached, or
     - immutable checks/constraints fail and cannot be repaired.

8. Final verification and report:
   ```bash
   set -euo pipefail
   sha256sum -c experiments/ar_candidate/bench/immutable.sha256
   git diff -- packages/motoko-ext-autoresearch/
   ```
   - `git diff -- packages/motoko-ext-autoresearch/` must be empty.
   - Summarize best metrics vs baseline with absolute and percent deltas.
   - List kept commits and why each was safe.
   - Confirm benchmark/check definitions stayed unchanged (hash match).
   - Report exact file set used for `ext_lines`.

Start now and execute the full loop autonomously.
