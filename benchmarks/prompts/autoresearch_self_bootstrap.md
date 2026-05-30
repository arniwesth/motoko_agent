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
- Use main repo root (`/workspaces/motoko_agent`) only for preflight and worktree setup.
- Execute benchmark steps in worktree root (`/workspaces/motoko_agent_autoresearch_wt`).
- Tool constraints in worktree:
  - `ReadFile`, `WriteFile`, `EditFile`, `Search` only work with paths relative to
    the main repo root (`/workspaces/motoko_agent`). They cannot reach the worktree.
  - Use `BashExec` with `cat`, `tee`, `sed` for reading/writing worktree files.
  - `ar_init`, `ar_run`, `ar_log`, `ar_notes` operate on the worktree via the `cwd`
    argument on `ar_init` (persisted for the session; `ar_run`/`ar_log` inherit it).
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
1. Preflight guards in main repo (must pass):
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent
   test -d packages/motoko-ext-autoresearch
   test -x "$(command -v ailang)"
   test -x "$(command -v duckdb)"
   git rev-parse --is-inside-work-tree >/dev/null
   git diff --quiet -- packages/motoko-ext-autoresearch/
   test -z "$(git ls-files --others --exclude-standard -- packages/motoko-ext-autoresearch/)"
   ```

2. Create an isolated worktree for this run:
   - Reason: branch creation/switching happens in dedicated checkout, not main working tree.
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent
   WT="/workspaces/motoko_agent_autoresearch_wt"
   test ! -e "$WT" || { echo "worktree path already exists: $WT"; exit 1; }
   base="autoresearch/self-bootstrap-$(date -u +%Y%m%d)"
   target="$base"
   i=2
   while git show-ref --verify --quiet "refs/heads/$target"; do
     target="${base}-${i}"
     i=$((i + 1))
   done
   git worktree add -b "$target" "$WT" HEAD
   git -C "$WT" rev-parse --abbrev-ref HEAD | grep -q '^autoresearch/'
   ```

3. In worktree, create candidate workspace:
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent_autoresearch_wt
   mkdir -p experiments
   rm -rf experiments/ar_candidate
   cp -R packages/motoko-ext-autoresearch experiments/ar_candidate
   ```

4. Copy the pre-baked benchmark harness into the candidate workspace:
   - Reason: the harness is a checked-in fixture, not authored at runtime. This
     keeps the benchmark deterministic across runs and avoids spending steps
     debugging scaffolding.
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent_autoresearch_wt
   rm -rf experiments/ar_candidate/bench
   cp -R /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_self_bootstrap/bench \
         experiments/ar_candidate/bench
   chmod +x experiments/ar_candidate/bench/shim/duckdb
   chmod +x experiments/ar_candidate/bench/benchmark.sh
   chmod +x experiments/ar_candidate/bench/checks.sh
   ```

   The harness consists of (do not edit these — they are off-limits and hashed):
   - `exercise_derive_state.ail`: imports the candidate's own `state`/`db` modules
     and calls the real `derive_state` 100 times. It runs the candidate code, so
     the spawn metric reflects actual candidate behavior — optimizing
     `derive_state` genuinely moves it. Baseline: derive_state in the Ready state
     spawns duckdb 3×/call (`current_segment` + `current_status` each re-fetch the
     same sessions row, plus `has_pending_run`), so 100 calls + 2 setup spawns
     = **302**.
   - `shim/duckdb`: counting shim that appends one line per invocation to
     `$SPAWN_LOG`, then `exec "$DUCKDB_REAL" "$@"`.
   - `benchmark.sh`: compiles & runs the exercise under the shim (scratch DB and
     spawn log live OUTSIDE the worktree so they never dirty candidate paths) and
     prints exactly:
     - `METRIC duckdb_spawns_per_100_calls=<int>` (baseline 302; a successful
       single-row-fetch optimization drops this toward ~202)
     - `METRIC overhead_ms=<int>` (noisy; real bash wall-time)
     - `METRIC ext_lines=<int>` (candidate `*.ail` LOC, tie-breaker only)
   - `checks.sh`: structural greps (FSM/scope/DB invariants) PLUS the candidate's
     own immutable test suite (`state_test`, `scope_test`, `metrics_test`). Exits
     non-zero on any failure — this is what prevents "winning" the spawn metric by
     breaking `derive_state`.

5. Freeze benchmark/check artifacts (immutability):
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent_autoresearch_wt
   chmod +x experiments/ar_candidate/bench/shim/duckdb
   chmod +x experiments/ar_candidate/bench/benchmark.sh
   chmod +x experiments/ar_candidate/bench/checks.sh
   sha256sum \
     experiments/ar_candidate/bench/exercise_derive_state.ail \
     experiments/ar_candidate/bench/shim/duckdb \
     experiments/ar_candidate/bench/benchmark.sh \
     experiments/ar_candidate/bench/checks.sh \
     > experiments/ar_candidate/bench/immutable.sha256
   ```

6. Create baseline commit for candidate fixtures before `ar_init`:
   - Reason: `ar_init` snapshots `init_dirty`; any path already dirty at init is excluded from per-iteration changes.
   - If candidate files are not committed before `ar_init`, later edits to those paths can be silently excluded from keep/discard git actions.
   - Commit only candidate fixture path so unrelated staged files are never captured.
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent_autoresearch_wt
   git add -- experiments/ar_candidate
   git commit -m "autoresearch bootstrap: candidate fixture baseline" -- experiments/ar_candidate
   ```

7. Initialize autoresearch with exact tool argument shape:
   ```json
   ar_init({
     "objective": "Reduce per-tool-call overhead in derive_state hot path without behavior change",
     "cwd": "/workspaces/motoko_agent_autoresearch_wt",
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
     "checks_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent_autoresearch_wt\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nbash experiments/ar_candidate/bench/checks.sh",
     "benchmark_script": "#!/usr/bin/env bash\nset -euo pipefail\ncd /workspaces/motoko_agent_autoresearch_wt\nsha256sum -c experiments/ar_candidate/bench/immutable.sha256\nexport DUCKDB_REAL=\"$(command -v duckdb)\"\nbash experiments/ar_candidate/bench/benchmark.sh"
   })
   ```
   - The `cwd` field tells the extension to run all git and script operations
     (worktree guard, branch creation, baseline snapshot, `ar_run` benchmark,
     `ar_log` commit/revert) from the worktree, not the main checkout. It is
     persisted for the session, so `ar_run`/`ar_log` inherit it automatically.
     The session DB still lives under the main checkout's `.motoko/autoresearch`
     so it survives worktree cleanup.

8. Capture baseline immediately after init (before edits):
   - Call:
     ```json
     ar_run()
     ```
   - Note: this consumes one run slot in segment (`max_iterations` counts baseline run).
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
   - Primary lever: `derive_state` (in candidate `state.ail`) calls
     `DB.current_segment` and `DB.current_status`, which each independently run
     `current_session_row` — two duckdb spawns for the same row. Fetching the
     session row once and reading both fields collapses the Ready path from 3
     spawns/call to 2 (≈302 → ≈202). Edit `db.ail`/`state.ail` together; keep
     every `current_*` accessor's external behavior identical so `checks.sh`
     (which runs the candidate test suite) still passes.
   - AILANG gotcha: `let (a, b) = ...` is NOT valid (tuple destructuring in `let`
     is a parse error). To return two values, use a record
     (`{ segment: int, status: string }`) and read its fields, or return a tuple
     and destructure it inside a `match` arm — not via `let`.
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
   cd /workspaces/motoko_agent_autoresearch_wt
   sha256sum -c experiments/ar_candidate/bench/immutable.sha256
   git diff -- packages/motoko-ext-autoresearch/
   test -z "$(git ls-files --others --exclude-standard -- packages/motoko-ext-autoresearch/)"
   ```
   - `git diff -- packages/motoko-ext-autoresearch/` must be empty.
   - Summarize best metrics vs baseline with absolute and percent deltas.
   - List kept commits and why each was safe.
   - Confirm benchmark/check definitions stayed unchanged (hash match).
   - Report exact file set used for `ext_lines`.

11. Optional cleanup after reporting:
   ```bash
   set -euo pipefail
   git -C /workspaces/motoko_agent worktree remove /workspaces/motoko_agent_autoresearch_wt
   ```

Troubleshooting (quick fixes):
- `ar_init` fails with `session already exists; use ar_init(new_segment=true)`:
  - Re-run `ar_init` with `"new_segment": true`, or remove `.motoko/autoresearch` in the worktree if starting fresh.
- `ar_init` fails with `worktree-first enforced`:
  - The extension is checking the directory given by the `cwd` argument, not the
    process CWD. Ensure `ar_init` includes `"cwd": "/workspaces/motoko_agent_autoresearch_wt"`
    (the linked worktree from step 2). Do not omit it — without `cwd` the guard
    checks the main checkout and always rejects.
- AILANG docs version gap:
  - The `ailang-docs` MCP server covers up to v0.19.1; the installed compiler is
    v0.22.0. The docs server's `prompt_get` tool returns the latest AILANG teacher
    prompt (v0.19.1), still useful for syntax and stdlib patterns — use it, but
    prefer reading existing `.ail` files in the repo for v0.22.0-specific features.
    The candidate code itself is the best reference for current idioms.
- Worktree creation fails because path exists:
  - Remove or move `/workspaces/motoko_agent_autoresearch_wt`, or run cleanup step 11 first.
- Baseline fixture commit fails with `nothing to commit`:
  - Confirm step 3 recreated `experiments/ar_candidate/`; if rerunning in-place, remove and recreate candidate workspace first.
- `ar_log` fails with `run_number mismatch`:
  - Use exact `run_number` from most recent `ar_run`; do not guess or increment manually.
- `ar_log` fails with `cannot keep: run failed checks or exited nonzero`:
  - Inspect `checks.sh` and benchmark stderr/stdout tails from `ar_run` metadata, fix candidate, then run new iteration.
- `ar_log` fails with `scope deviation requires justification for keep`:
  - For this benchmark, treat as hard failure and discard; do not keep runs with scope/off-limits deviations.
- Hash check fails (`sha256sum -c ... FAILED`):
  - Benchmark/check artifacts drifted. Restore canonical files in `experiments/ar_candidate/bench/`, regenerate `immutable.sha256`, and restart segment.
- `duckdb` count metric is unexpectedly zero/flat:
  - Verify `DUCKDB_REAL` is exported and executable, and the shim is executable.
    `benchmark.sh` runs the exercise via `ailang run` from the candidate package
    root with the shim first on PATH; if the metric is 0, the exercise failed to
    compile/run — run `cd experiments/ar_candidate && AILANG_RELAX_MODULES=1 ailang run --caps IO,Process,FS,Clock,Env bench/exercise_derive_state.ail`
    directly to see the error. A *flat* (non-moving) metric means your edit didn't
    change `derive_state`'s spawn count — confirm you reduced `current_session_row`
    calls on the Ready path, not just renamed things.
- benchmark or checks fail to compile the candidate (`ailang run`/`ailang test`):
  - The candidate must remain a valid AILANG package. Run
    `cd experiments/ar_candidate && AILANG_RELAX_MODULES=1 ailang check --relax-modules state.ail db.ail`
    and fix type/parse errors before re-running `ar_run`.
- Candidate edits are not being committed/reverted across iterations:
  - Ensure step 6 baseline commit ran before `ar_init`; if not, restart from fresh segment after baseline commit.
- Live extension appears modified:
  - Stop and inspect `git diff -- packages/motoko-ext-autoresearch/`; any non-empty diff is hard failure of this run.

Start now and execute the full loop autonomously.
