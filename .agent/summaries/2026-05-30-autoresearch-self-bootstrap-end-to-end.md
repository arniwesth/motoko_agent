# Autoresearch Self-Bootstrap Benchmark: End-to-End

Implemented `.agent/plans/Motoko-auto-research/self-bootstrap-fixes.md`, then drove
the autoresearch extension to a working end-to-end "self-research bootstrap" run
(the live extension optimizing a separate copy of itself). The machinery worked but
four latent bugs surfaced across live runs; each was root-caused, fixed, and
verified. Final clean run: **302 → 102 duckdb spawns (−66%)**, behavior-preserved,
live extension provably untouched. All work on branch `autoresearch-research`.

## Fix 2: per-session `cwd` override (the plan's critical blocker)

### Problem
The extension used `ctx.workdir` (the agent process cwd = main checkout) for all git
and script operations. The self-bootstrap flow runs the experiment in a **linked git
worktree**, so `ar_init`'s worktree guard always rejected, and `ar_run`/`ar_log`
would have operated on the wrong repo.

### Fix
Added an optional `cwd` to `ar_init`, persisted in a new `sessions.cwd` column, and
resolved per session via `effective_cwd()`. The 11 git/script call sites in
`handle_init`/`handle_run`/`handle_log` use it; `resolve_session_dir` intentionally
keeps `ctx.workdir` so the session DB stays in the main checkout (survives worktree
cleanup). Files: `db.ail` (`cwd` column + migration + `current_cwd`), `tools.ail`
(`parse_cwd` + schema), `autoresearch.ail` (`effective_cwd`, handler rewrites).

## Harness redesign: shell simulation → real-code `.ail` exercise

### Problem
The original plan shipped `exercise_100_calls.sh`, a shell script that *simulated*
`derive_state`'s query pattern with hardcoded `duckdb` calls. That decouples the
metric from the candidate code — editing `derive_state` could not move the spawn
count, defeating the benchmark's purpose.

### Fix
Replaced it with `exercise_derive_state.ail`, which imports the candidate's own
`state`/`db` modules and calls the real `derive_state` 100× under a counting
`duckdb` shim. Prototyped first: baseline 302, and a single-row-fetch optimization
genuinely moved it to 202 — proving coupling. `checks.sh` was strengthened to run
the candidate's own (off-limits) test suite so the optimizer can't win by breaking
behavior. Fixtures: `benchmarks/fixtures/autoresearch_self_bootstrap/bench/`.

## Four bugs found during live runs

Each blocked or degraded a run and was reproduced before fixing.

1. **`/tmp` not writable in the sandboxed exec** → empty metrics. The benchmark's
   `mktemp -d` scratch couldn't be written under `ar_run`'s sandbox. Fixed by
   honoring `AR_BENCH_SCRATCH` (a workdir-relative, sandbox-writable path set by the
   `benchmark_script` wrapper), with `mktemp` fallback for standalone use.
   (`061b6c1`)

2. **Arg parser truncated on escaped quotes.** `raw_str_field`/`extract_between`
   extracted a JSON string value up to the first literal `"`, so a `benchmark_script`
   containing `DUCKDB_REAL=\"$(...)\"` was silently cut to `DUCKDB_REAL=\` → empty
   metrics. Worked around in the prompt (quote-free scripts), then fixed properly:
   `scan_json_string_value` walks the value honoring `\"`/`\\` and stops at the first
   *unescaped* quote. (`bd32aa9`)

3. **Relative benchmark-script path.** Default config has `agent.workdir: "."`, so
   `ctx.workdir` is relative. `ar_init` *wrote* the script via `writeFile` (based at
   the runtime cwd = main checkout) but `ar_run` *executed* it from the worktree —
   `bash ./.motoko/.../autoresearch.sh` not found there → exit 127. The agent had to
   symlink `.motoko` into the worktree to recover (~10 wasted steps). Fixed with
   `abs_cwd`/`absolutize` helpers that make the benchmark/checks script paths
   absolute for both write and exec. (`9fb33e2`)

4. **`checks.sh` keyed off `ailang test`'s exit code.** Right after the benchmark's
   `ailang run`, `ailang test` could exit non-zero for a non-test reason (a cache /
   "content changed" warning) even though all tests pass — so the pristine baseline
   reported `checks_passed=false` and blocked the loop. Fixed to decide pass/fail
   from the test summary (`0 failed`), with one retry and failure output surfaced.
   Verified: pristine → OK, broken candidate → CHECK FAILED. (`20bebbc`)

## Verification

A full user-initiated `make run` completed end-to-end autonomously
(`session_2026-05-30T15-20-12-382Z.md`):

- Metric trajectory (every run kept, checks passed): 302 → 202 → 102, then 4 runs
  stable at 102 → patience-stop. 102 is the theoretical floor (1 spawn/call + 2
  setup).
- The agent discovered three levels: collapse `current_segment`+`current_status`
  into one row fetch (302→202), fold `has_pending` via a correlated subquery
  (202→102), then dead-code removal to trim `ext_lines`.
- Hard requirements checked against the repo (not just the agent's report): live
  `packages/motoko-ext-autoresearch/` diff empty, `sha256sum -c` passed, candidate
  work isolated to its `autoresearch/self-bootstrap-*` branch, worktree cleaned up.

## Docs

- Rewrote `packages/motoko-ext-autoresearch/README.md` from the generic scaffold to
  document the tools, FSM (`Setup → Ready → AwaitingLog → Done`), config,
  persistence, module map, and the **git-worktree/branch model** (each run = a new
  branch + throwaway worktree; the worktree is removed but the branch persists,
  which is why many `self-bootstrap-*` branches accumulate with no worktrees).
- `.agent/learnings/2026-05-30-ailang-syntax-gotchas.md` + `ailang-syntax-gotchas`
  memory: `--` comments, `++` is list-only, no `let` tuple-destructure,
  `MOD010`/`--relax-modules`, the pre-existing `_smoke.ail` failure.

## Next direction

The current test validates the machinery but is an easy research challenge (answer
handed to the agent, tiny closed search space, deterministic metric, self-
referential). Decided next target: **optimize a local ARC-AGI-3 agent for the real
2026 prize** (optimizer ≠ player, offline submission) — see
`.agent/plans/Motoko-auto-research/next-session-ambitious-test-handoff.md` and the
`arc-agi-3-autoresearch` memory. The handoff also captures the operational playbook
(use `deepseek-v4-pro` not the weak default; clean up worktrees/branches between
runs; never hold the session DB open in a DuckDB browser during a run; monitor via
the JSONL log, not DB queries).
