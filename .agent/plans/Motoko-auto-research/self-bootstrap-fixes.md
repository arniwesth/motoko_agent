# Fix Plan: Self-Bootstrap Benchmark Failures (2026-05-30)

## Problem Statement

The first live run of the Appendix A "Self-Research Bootstrap" benchmark
(`benchmarks/prompts/autoresearch_self_bootstrap.md`) failed to reach `ar_init`.
The agent spent its entire 23-step budget stuck in **step 4** (creating the
benchmark harness) and was killed mid-reasoning. The autoresearch extension
loaded correctly and its hooks were active, but the `ar_*` tools were never
called.

## Root Causes

### RC1: Benchmark harness authored at runtime by the agent

The prompt instructs the agent to *create* four benchmark files from prose
descriptions (step 4). One of these — `exercise_100_calls.ail` — must be valid
AILANG source. The agent:

1. Used `_env_args()` (doesn't exist in AILANG stdlib).
2. Used `letrec` syntax (not valid AILANG — recursion uses named `func`).
3. Spent 12 steps searching docs, rewriting, re-checking — never got it to
   compile.

**Why this is the wrong design:** The benchmark's job is to measure the
*candidate extension*, not to test whether the agent can author AILANG from
scratch. Having the agent generate benchmark files at runtime introduces a
failure mode orthogonal to what the test is validating, wastes steps on
scaffolding, and makes runs non-reproducible (different agents may generate
different harnesses).

### RC2: AILANG docs MCP server version gap

The `ailang-docs` MCP server only has docs up to v0.19.1. The installed
compiler is v0.22.0. When the agent searched for `env_args`, recursion syntax,
or stdlib modules, it got empty results or version-mismatch errors. This left
it guessing at language features.

### RC3: ReadFile rejects worktree absolute paths

Motoko's `ReadFile` tool validates paths against `ctx.workdir`
(`/workspaces/motoko_agent`). The worktree lives at
`/workspaces/motoko_agent_autoresearch_wt`, so `ReadFile` with absolute
worktree paths returns `"absolute paths are not allowed"`. The agent fell back
to `BashExec cat`, which works but wastes a step and is less ergonomic.

This is an inherent tension in the worktree-first design: the agent's tool
sandbox is rooted at the main checkout, but the experiment runs in a separate
worktree. `BashExec` can reach both, but `ReadFile`/`WriteFile`/`EditFile`
cannot.

---

## Fixes

### Fix 1: Pre-bake the benchmark harness (addresses RC1)

**What:** Ship the four benchmark files as checked-in fixtures under
`benchmarks/fixtures/autoresearch_self_bootstrap/`, and change the prompt's
step 4 from "create these files" to "copy these files."

**Files to create:**

#### `bench/exercise_100_calls.sh` (replace `.ail` with shell)

The original design called for an AILANG file that imports the candidate's
`state` module and calls `derive_state` 100 times. This is fragile because:
- The candidate's `ailang.toml` module resolution may differ from the host.
- AILANG `ailang run` requires correct effect declarations and module paths.
- The agent doesn't reliably know AILANG syntax.

**Replace with a shell script** that achieves the same measurement: spawn
`duckdb` against the session DB 100 times with the same SQL query that
`derive_state` uses. This exercises the exact hot path (process spawn + DB
query) without requiring AILANG compilation.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Exercise the duckdb hot path 100 times (same query as derive_state).
# Requires: DUCKDB_REAL or duckdb on PATH, SESSION_DIR set.
SD="${SESSION_DIR:-.motoko/autoresearch}"
DB="$SD/autoresearch.db"
mkdir -p "$SD"
# Ensure minimal schema exists
duckdb "$DB" "CREATE TABLE IF NOT EXISTS sessions (id INTEGER, segment INTEGER, status TEXT);" 2>/dev/null
duckdb "$DB" "CREATE TABLE IF NOT EXISTS pending_runs (session_id INTEGER, segment INTEGER, run_number INTEGER);" 2>/dev/null
for i in $(seq 1 100); do
  duckdb "$DB" "SELECT COALESCE(MAX(segment),0) FROM sessions;" >/dev/null 2>&1
done
```

This is simpler, reproducible, and measures the same thing: how many times
`duckdb` is spawned per 100 derive_state-equivalent calls.

#### `bench/shim/duckdb` (unchanged from prompt)

The counting shim. Already well-specified; ship it as a fixture.

#### `bench/benchmark.sh` (unchanged from prompt, references shell exercise)

Update the exercise invocation line to call `exercise_100_calls.sh` instead of
`ailang run ... exercise_100_calls.ail`.

#### `bench/checks.sh` (unchanged from prompt)

Ship as fixture. The agent-generated version from the failed run was actually
reasonable — use it as the starting point, but verify all grep patterns match
the actual candidate source.

**Prompt change (step 4):**

```
4. Copy pre-baked benchmark harness into candidate workspace:
   ```bash
   set -euo pipefail
   cd /workspaces/motoko_agent_autoresearch_wt
   cp -R /workspaces/motoko_agent/benchmarks/fixtures/autoresearch_self_bootstrap/bench \
         experiments/ar_candidate/bench
   chmod +x experiments/ar_candidate/bench/shim/duckdb
   chmod +x experiments/ar_candidate/bench/benchmark.sh
   chmod +x experiments/ar_candidate/bench/checks.sh
   chmod +x experiments/ar_candidate/bench/exercise_100_calls.sh
   ```
```

This eliminates the entire AILANG authoring failure mode and makes the benchmark
deterministic across runs.

### Fix 2: Add worktree workdir hint to prompt (addresses RC3)

The prompt already says "Execute benchmark steps in worktree root." But the
agent doesn't know that `ReadFile`/`WriteFile`/`EditFile` are workdir-scoped.
Add a note:

```
Tool constraints in worktree:
- ReadFile, WriteFile, EditFile, Search only work with paths relative to the
  main repo root (/workspaces/motoko_agent). They cannot reach the worktree.
- Use BashExec with `cat`, `tee`, `sed` for reading/writing worktree files.
- ar_init, ar_run, ar_log, ar_notes work in the worktree because they use
  BashExec internally (via the extension's Process effect).
```

This prevents the agent from wasting a step discovering the restriction.

### Fix 3: Note AILANG docs version gap in prompt (addresses RC2)

Add to the troubleshooting section:

```
- ailang-docs MCP server covers up to v0.19.1; installed compiler is v0.22.0.
  For syntax questions, read existing .ail files in the repo rather than
  querying the docs server. The candidate code itself is the best reference.
```

This is a low-cost hint that prevents the docs-search rabbit hole.

---

## Revised Prompt Diff Summary

| Section | Change |
|---------|--------|
| Step 4 | "Create benchmark harness" → "Copy pre-baked benchmark harness" |
| New section before step 1 | "Tool constraints in worktree" note |
| Troubleshooting | AILANG docs version gap note |
| Step 8 (benchmark.sh ref) | Update to reference shell exercise |

Total prompt change: ~15 lines replaced/added. The prompt's 11-step structure
and all `ar_*` tool call shapes remain unchanged.

## New Fixture Files to Create

```
benchmarks/fixtures/autoresearch_self_bootstrap/
  bench/
    exercise_100_calls.sh    # shell-based hot-path exercise (replaces .ail)
    shim/duckdb              # counting shim
    benchmark.sh             # metric emitter
    checks.sh                # FSM/scope/invariant validator
```

These must be committed and hashed before any benchmark run. The prompt's
step 5 (SHA256 freeze) applies to these fixtures.

## Implementation Order

1. Create `benchmarks/fixtures/autoresearch_self_bootstrap/bench/` with all
   four files. Test each independently:
   - `exercise_100_calls.sh` runs without error when `duckdb` is on PATH
   - `benchmark.sh` emits exactly three `METRIC` lines
   - `checks.sh` passes against the current `packages/motoko-ext-autoresearch/`
   - `shim/duckdb` logs to `$SPAWN_LOG` and execs the real binary
2. Update `benchmarks/prompts/autoresearch_self_bootstrap.md` with the three
   prompt changes above.
3. Run the benchmark again (`make run_autoresearch_self`) and verify the agent
   reaches `ar_init` within the first 10 steps.

## Out of Scope

- **Fixing the `ReadFile` workdir restriction for worktrees.** This would
  require changes to `tool_runtime.ail` in the core runtime, which is vendored
  and not owned by this project. The `BashExec` workaround is sufficient.
- **Updating the ailang-docs MCP server.** That's an upstream dependency
  (`sunholo-data/ailang`). The prompt hint is the right short-term fix.
- **Changing the `ar_*` tool implementations.** The extension loaded and
  dispatched correctly; the tools themselves are not the problem.
