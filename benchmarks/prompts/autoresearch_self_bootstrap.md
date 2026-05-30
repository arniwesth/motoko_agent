Run Appendix A "Self-Research Bootstrap (optimizer != optimized)" from `.agent/plans/Motoko-auto-research/implementation-plan.md`.

Goal:
- Have the running autoresearch extension optimize a separate candidate copy of itself, not the live extension.

Hard requirements:
1. Do not modify `packages/motoko-ext-autoresearch/` in this run.
2. Keep benchmark and checks immutable during optimization (off-limits to candidate edits).
3. Use `scope_paths` + `off_limits` so `optimizer != optimized`.
4. Use deterministic primary metric and noisy secondary metric exactly as intended.

Execution plan:
1. Create candidate workspace:
   - `experiments/ar_candidate/`
   - Copy extension sources from `packages/motoko-ext-autoresearch/` into `experiments/ar_candidate/`.
   - Create `experiments/ar_candidate/bench/`.

2. Create benchmark harness files in `experiments/ar_candidate/bench/`:
   - `exercise_100_calls.ail`: repeatedly trigger extension hot-path behavior in a deterministic way.
   - PATH shim script to count `duckdb` spawns into `$SPAWN_LOG`.
   - Any helper files needed by benchmark/check scripts.

3. Create immutable checks script for candidate behavior:
   - Validate FSM behavior, scope gating, and logging invariants relevant to autoresearch.
   - Fail on any contract break.

4. Initialize autoresearch with `ar_init`:
   - objective: reduce per-tool-call overhead in derive_state path without behavior change.
   - metrics:
     - `duckdb_spawns_per_100_calls` minimize (primary, deterministic)
     - `overhead_ms` minimize (secondary, noisy)
     - `ext_lines` minimize (informational)
   - scope_paths:
     - `experiments/ar_candidate/`
   - off_limits:
     - `packages/motoko-ext-autoresearch/`
     - `experiments/ar_candidate/**/*_test.ail`
     - `experiments/ar_candidate/bench/`
     - `src/core/ext/registry_generated.ail`
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

5. Iterate:
   - call `ar_run` with sampling appropriate for noisy metric (e.g. `samples: 7`)
   - inspect results
   - call `ar_log(keep|discard)` with rigorous reasoning
   - continue until convergence criteria from the loop are met.

6. At the end:
   - summarize best metrics vs baseline
   - list kept commits and why they were safe
   - confirm live extension code was untouched
   - confirm benchmark/check definitions were unchanged during optimization.

Start now and execute the full loop autonomously.
