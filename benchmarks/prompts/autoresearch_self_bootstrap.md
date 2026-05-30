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
- `scope_paths` / `off_limits` matching is prefix-or-exact only in current implementation (no `**` glob semantics).
- For this benchmark, any scope or off-limits deviation is a hard failure: discard the run; do not keep via `justification`.
- Use profile defaults from `.motoko/config/default/autoresearch.json`:
  - `default_session_dir=.motoko/autoresearch`
  - `default_patience=3`
  - `default_max_iterations=20`
  - `default_samples=1`
  - `default_timeout_ms=60000`

Execution plan:
1. Preflight guards (must pass):
   ```bash
   set -euo pipefail
   test -d packages/motoko-ext-autoresearch
   test -x "$(command -v ailang)"
   test -x "$(command -v duckdb)"
   git rev-parse --is-inside-work-tree >/dev/null
   git diff --quiet -- packages/motoko-ext-autoresearch/
   test -z "$(git ls-files --others --exclude-standard -- packages/motoko-ext-autoresearch/)"
   ```

2. Ensure run branch before creating candidate fixtures:
   - Reason: the baseline fixture commit must land on an `autoresearch/*` branch before `ar_init`.
   - `ar_init` reuses current `autoresearch/*` branch; if you commit first on another branch, you pollute that branch.
   ```bash
   set -euo pipefail
   current="$(git rev-parse --abbrev-ref HEAD)"
   if [[ "$current" != autoresearch/* ]]; then
     base="autoresearch/self-bootstrap-$(date -u +%Y%m%d)"
     target="$base"
     i=2
     while git show-ref --verify --quiet "refs/heads/$target"; do
       target="${base}-${i}"
       i=$((i + 1))
     done
     git switch -c "$target"
   fi
   ```

3. Create candidate workspace:
   ```bash
   set -euo pipefail
   mkdir -p experiments
   rm -rf experiments/ar_candidate
   cp -R packages/motoko-ext-autoresearch experiments/ar_candidate
   mkdir -p experiments/ar_candidate/bench/shim
   ```

4. Create benchmark harness in `experiments/ar_candidate/bench/`:
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

5. Freeze benchmark/check artifacts (immutability):
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

6. Create a baseline commit for candidate fixtures before `ar_init`:
   - Reason: `ar_init` snapshots `init_dirty`; any path already dirty at init is excluded from per-iteration changes.
   - If candidate files are not committed before `ar_init`, later edits to those paths can be silently excluded from keep/discard git actions.
   - Commit only the candidate fixture path so unrelated staged files are never captured.
   ```bash
   set -euo pipefail
   git add -- experiments/ar_candidate
   git commit -m "autoresearch bootstrap: candidate fixture baseline" -- experiments/ar_candidate
   ```

7. Initialize autoresearch with exact tool argument shape:
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
       "experiments/ar_candidate/state_test.ail",
       "experiments/ar_candidate/metrics_test.ail",
       "experiments/ar_candidate/scope_test.ail",
       "experiments/ar_candidate/_smoke.ail",
       "experiments/ar_candidate/bench/",
       "src/core/ext/registry_generated.ail",
       ".packages/motoko_core/src/core/ext/registry_generated.ail"
     ],
     "constraints": [
       "candidate must pass full candidate checks unchanged",
       "derive_state remains DB-authoritative",
       "no tool/schema contract changes",
       "AwaitingLog hard-block behavior preserved"
     ],
     "checks_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nbash experiments/ar_candidate/bench/checks.sh",
     "benchmark_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nexport DUCKDB_REAL=\"$(command -v duckdb)\"\nexport SPAWN_LOG=\"/workspaces/motoko_agent/experiments/ar_candidate/bench/spawn.log\"\nbash experiments/ar_candidate/bench/benchmark.sh"
   })
   ```

8. Capture baseline immediately after init (before edits):
   - Call:
     ```json
     ar_run()
     ```
   - Note: this consumes one run slot in the segment (`max_iterations` counts this baseline run).
   - Run uses profile defaults (`samples=1`, `timeout_ms=60000`) unless overridden.
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

9. Iterate optimization loop:
   - edit candidate files only under `experiments/ar_candidate/` (respect off-limits)
   - call:
     ```json
     ar_run()
     ```
   - Run uses profile defaults (`samples=1`, `timeout_ms=60000`) unless overridden.
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
     - no primary-metric improvement for 3 consecutive kept runs (patience exhausted), or
     - `max_iterations` reached, or
     - immutable checks/constraints fail and cannot be repaired.

10. Final verification and report:
   ```bash
   set -euo pipefail
   sha256sum -c experiments/ar_candidate/bench/immutable.sha256
   git diff -- packages/motoko-ext-autoresearch/
   test -z "$(git ls-files --others --exclude-standard -- packages/motoko-ext-autoresearch/)"
   ```
   - `git diff -- packages/motoko-ext-autoresearch/` must be empty.
   - Summarize best metrics vs baseline with absolute and percent deltas.
   - List kept commits and why each was safe.
   - Confirm benchmark/check definitions stayed unchanged (hash match).
   - Report exact file set used for `ext_lines`.

Troubleshooting (quick fixes):
- `ar_init` fails with `session already exists; use ar_init(new_segment=true)`:
  - Re-run `ar_init` with `"new_segment": true`, or remove the session dir `.motoko/autoresearch_self_bootstrap` if starting fresh.
- Baseline fixture commit fails with `nothing to commit`:
  - Confirm step 3 actually recreated `experiments/ar_candidate/`; if rerunning in-place, remove and recreate candidate workspace first.
- `ar_log` fails with `run_number mismatch`:
  - Use the exact `run_number` returned by the most recent `ar_run`; do not guess or increment manually.
- `ar_log` fails with `cannot keep: run failed checks or exited nonzero`:
  - Inspect `checks.sh` and benchmark stderr/stdout tails from `ar_run` metadata, fix candidate, then run a new iteration.
- `ar_log` fails with `scope deviation requires justification for keep`:
  - For this benchmark, treat as hard failure and discard; do not keep runs with scope or off-limits deviations.
- Hash check fails (`sha256sum -c ... FAILED`):
  - Benchmark/check artifacts drifted. Restore canonical files in `experiments/ar_candidate/bench/`, regenerate `immutable.sha256`, and restart the segment.
- `duckdb` count metric is unexpectedly zero/flat:
  - Verify `DUCKDB_REAL` is exported, shim is executable, shim is first on PATH inside benchmark script, and `$SPAWN_LOG` is reset per sample.
- Candidate edits are not being committed/reverted across iterations:
  - Ensure step 6 baseline commit ran before `ar_init`; if not, restart from a fresh segment after baseline commit.
- Live extension appears modified:
  - Stop and inspect `git diff -- packages/motoko-ext-autoresearch/`; any non-empty diff is a hard failure of this benchmark run.

Start now and execute the full loop autonomously.
