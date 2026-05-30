Run Appendix A "Self-Research Bootstrap (optimizer != optimized)" from `.agent/plans/Motoko-auto-research/implementation-plan.md`.

Goal:
- Have the running autoresearch extension optimize a separate candidate copy of itself, not the live extension.

Hard requirements:
1. Do not modify `packages/motoko-ext-autoresearch/` in this run.
2. Keep benchmark and checks immutable during optimization (off-limits to candidate edits).
3. Use `scope_paths` + `off_limits` so `optimizer != optimized`.
4. Use deterministic primary metric and noisy secondary metric exactly as intended.
5. Capture and preserve a measured baseline before any candidate mutations.

Execution plan:
1. Create candidate workspace:
   - `experiments/ar_candidate/`
   - Copy extension sources from `packages/motoko-ext-autoresearch/` into `experiments/ar_candidate/`.
   - Create `experiments/ar_candidate/bench/`.

2. Create benchmark harness files in `experiments/ar_candidate/bench/`:
   - `exercise_100_calls.ail`: repeatedly trigger extension hot-path behavior in a deterministic way.
   - PATH shim script to count `duckdb` spawns into `$SPAWN_LOG`.
   - Any helper files needed by benchmark/check scripts.
   - Benchmark must run in an isolated subprocess environment that:
     - resets/truncates `$SPAWN_LOG` per sample
     - sets PATH so only the shimmed `duckdb` is counted
     - avoids counting unrelated processes from outside the run.

3. Create immutable checks script for candidate behavior:
   - Validate FSM behavior, scope gating, and logging invariants relevant to autoresearch.
   - Fail on any contract break.
   - Record SHA256 hashes for benchmark/check artifacts before optimization starts.
   - Re-verify the same hashes after every iteration and at finalization; abort on drift.

4. Capture baseline before `ar_init`:
   - Run the benchmark + checks against pristine `experiments/ar_candidate/` with no candidate edits.
   - Use the same sample count intended for optimization comparisons (`samples: 7`).
   - Persist baseline metrics as:
     - `BASELINE duckdb_spawns_per_100_calls=<int>`
     - `BASELINE overhead_ms=<int>`
     - `BASELINE ext_lines=<int>`

5. Initialize autoresearch with `ar_init`:
   - objective: reduce per-tool-call overhead in derive_state path without behavior change.
   - metrics:
     - `duckdb_spawns_per_100_calls` minimize (primary, deterministic)
     - `overhead_ms` minimize (secondary, noisy)
     - `ext_lines` minimize (informational)
   - scope_paths:
     - `experiments/ar_candidate/`
   - off_limits:
     - `packages/motoko-ext-autoresearch/`
     - `experiments/ar_candidate/**/tests/**`
     - `experiments/ar_candidate/**/*_test.ail`
     - `experiments/ar_candidate/**/*.test.ail`
     - `experiments/ar_candidate/bench/`
     - `experiments/ar_candidate/**/registry_generated.ail`
     - `packages/**/registry_generated.ail`
   - constraints:
     - candidate must pass full candidate checks unchanged
     - derive_state remains DB-authoritative
     - no tool/schema contract changes
     - AwaitingLog hard-block behavior preserved
   - checks_script: use the immutable checks harness
   - benchmark_script:
     - emits:
       - `METRIC duckdb_spawns_per_100_calls=<int>`
       - `METRIC overhead_ms=<int>`
       - `METRIC ext_lines=<int>`
   - patience: 4
   - max_iterations: 25

6. Iterate:
   - call `ar_run` with sampling appropriate for noisy metric (e.g. `samples: 7`)
   - inspect results
   - call `ar_log(keep|discard)` with rigorous reasoning
   - continue until one stop condition is met:
     - no primary-metric improvement for 4 consecutive iterations (patience exhausted), or
     - max_iterations reached, or
     - candidate fails immutable checks/constraints and cannot be repaired within the loop.

7. At the end:
   - summarize best metrics vs baseline (include absolute and percent deltas)
   - list kept commits and why they were safe
   - confirm live extension code was untouched by verifying:
     - `git diff -- packages/motoko-ext-autoresearch/` is empty
   - confirm benchmark/check definitions were unchanged during optimization via final SHA256 match.
   - report exact file set used for `ext_lines` (candidate source only; exclude `bench/`, tests, and generated files).

Start now and execute the full loop autonomously.
