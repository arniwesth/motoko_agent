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

### RC4: Every `ctx.workdir` usage in the extension assumes Motoko runs from the worktree

**Critical blocker the original plan missed.** Even if the agent had gotten
past step 4, `ar_init` would have rejected the call — and even if that were
bypassed, `handle_run`, `handle_log`, and all git operations would execute
in the wrong directory.

There are **13 references** to `ctx.workdir` across the extension. `ctx.workdir`
is set at agent startup to the process CWD — always `/workspaces/motoko_agent`
(the main checkout) when launched via `make run_autoresearch_self`. It cannot be
changed during the session.

**Specific failures (all use `ctx.workdir` as CWD for `shell()` calls):**

| Call site | What it does with `ctx.workdir` | What breaks |
|-----------|-------------------------------|-------------|
| `handle_init:672` `require_linked_worktree` | Checks if CWD is a linked worktree | **Always rejects** — main checkout's `--git-dir` == `--git-common-dir` |
| `handle_init:684,686` `write_executable_script` | `chmod +x` in CWD | Harmless (absolute path), but runs chmod from wrong dir |
| `handle_init:702` `Git.ensure_autoresearch_branch` | `git checkout -b autoresearch/...` | **Would switch the main repo's branch** — destructive |
| `handle_init:703` `Git.head_sha` | Gets baseline commit | Gets main repo's HEAD, not worktree's |
| `handle_init:704` `Git.capture_init_dirty_json` | Snapshots dirty files | Snapshots main repo's dirty files, not worktree's |
| `handle_run:752` `run_samples` → `run_command_for_sample` | Runs benchmark script from CWD | **Benchmark script runs from main checkout** — relative paths in script break |
| `handle_run:763` `run_checks_if_present` | Runs checks script from CWD | Same problem |
| `handle_log:860` `Git.dirty_paths` | Lists changed files | Lists main repo changes, not worktree's |
| `handle_log:862` `exclude_session_paths` | Strips session_dir prefix using workdir | Relative path math breaks if workdir != worktree |
| `handle_log:869` `commit_or_revert` → `Git.selective_commit/revert` | Commits/reverts in CWD | **Commits/reverts in main repo** — destructive, wrong repo |

The worktree guard was designed for a scenario where Motoko itself is launched
from inside a worktree. The self-bootstrap flow is different: Motoko runs from
the main checkout and the agent creates/uses a worktree via BashExec. The
extension needs a per-session CWD override for all git and script operations.

### RC5: Exercise script must seed a session row to hit the real hot path

The derive_state hot path has different spawn counts depending on DB state:

| DB state | duckdb spawns per call | ArState returned |
|----------|----------------------|------------------|
| No session rows | **1** (current_segment returns 0) | Setup |
| Active session, no pending | **3** (current_segment + current_status + has_pending_run) | Ready |
| Active session, with pending | **4** (+ read_pending_run) | AwaitingLog |
| Non-active session | **2** (current_segment + current_status) | Done |

The proposed exercise in the previous plan revision ran against an **empty
database**, so `current_segment` returns 0, `derive_state` returns `Setup`
after just **1 spawn**, and the loop would report 100 spawns instead of 300.
The exercise must seed an active session row to hit the 3-spawn `Ready` path.

Additionally, `current_session_row` is called **twice** per `derive_state` in
the `Ready` path (once by `current_segment`, once by `current_status`) — they
are separate exported functions that each independently call `run_sql`. This
redundancy is the exact inefficiency the benchmark should detect and that the
optimization loop should fix.

---

## Fixes

### Fix 1: Pre-bake the benchmark harness (addresses RC1, RC5)

**What:** Ship the four benchmark files as checked-in fixtures under
`benchmarks/fixtures/autoresearch_self_bootstrap/bench/`, and change the
prompt's step 4 from "create these files" to "copy these files."

#### `bench/exercise_100_calls.sh` (shell, replaces `.ail`)

The AILANG exercise was the right idea (call `derive_state` 100 times via the
real candidate code), but authoring it at runtime is fragile. Replace with a
**shell script that simulates the derive_state query pattern** accurately:

```bash
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
  done_reason TEXT, baseline_commit TEXT, branch TEXT, ts BIGINT
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
```

This spawns 300 duckdb processes for 100 iterations (plus 1 for schema seed) —
matching the real `derive_state` behavior in the `Ready` state. The seed row
ensures `current_segment` returns > 0 so we don't short-circuit to `Setup`.

#### `bench/shim/duckdb` (unchanged from prompt)

The counting shim. Already well-specified; ship it as a fixture.

#### `bench/benchmark.sh` (updated to reference shell exercise)

Update the exercise invocation line to call `exercise_100_calls.sh` instead
of `ailang run ... exercise_100_calls.ail`. The rest of the script
(DUCKDB_REAL validation, PATH rewrite, wall-time measurement) stays as
designed.

For `ext_lines`, use the prompt's more precise counting (excluding `bench/`,
`*_test.ail`, `_smoke.ail`, `registry_generated.ail`) rather than the
implementation plan's simpler `cat *.ail | wc -l` which overcounts by
including test files.

#### `bench/checks.sh`

Ship as fixture. The agent-generated version from the failed run was
reasonable — use it as the starting point. All grep patterns verified
against the current source:

| Pattern | Source file | Matches? |
|---------|-----------|----------|
| `export func derive_state` | state.ail:23 | Yes |
| `DB\.` | state.ail | Yes (4 matches) |
| `AwaitingLog.*must be logged before another ar_run` | state.ail:63 | Yes |
| `export pure func path_matches_spec` | scope.ail:23 | Yes |
| `\*\*` (must not match) | scope.ail | Correct (0 matches) |
| `exec.*duckdb` | db.ail:39 | Yes |

**Prompt change (step 4):**

Replace the entire "Create benchmark harness" block with:

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

This eliminates the entire AILANG authoring failure mode and makes the
benchmark deterministic across runs.

### Fix 2: Add per-session CWD to the extension (addresses RC4)

**This is a code change to `packages/motoko-ext-autoresearch/`.** All 13
`ctx.workdir` references need to resolve to the worktree CWD when operating
on a remote session.

**Design:** Add an optional `cwd` field to `ar_init`. When provided, it
overrides `ctx.workdir` for all operations in that session. Persist it in
the `sessions` table so `ar_run`/`ar_log` inherit it without re-supplying.

#### 2a. Schema change (`db.ail`)

Add `cwd TEXT` column to the `sessions` table. Add `insert_session` parameter.
Add `current_cwd(session_dir) -> Result[string, string]` function.

#### 2b. Tool schema change (`tools.ail`)

Add `parse_cwd(args, fallback) -> string` function.
Add `cwd` (optional string) to `ar_init` parameter schema.

#### 2c. Session CWD resolver (`autoresearch.ail`)

Add a helper that resolves the effective CWD for a session:

```
func effective_cwd(ctx: ExtCtx, session_dir: string) -> string ! {Process} {
  match DB.current_cwd(session_dir) {
    Ok(c) => if c != "" then c else ctx.workdir,
    Err(_) => ctx.workdir
  }
}
```

#### 2d. `handle_init` changes

```
# Change:
require_linked_worktree(ctx.workdir)
# To:
let init_cwd = Tools.parse_cwd(call.arguments, ctx.workdir);
require_linked_worktree(init_cwd)
```

Replace all `ctx.workdir` in `handle_init` with `init_cwd`:
- `write_executable_script(init_cwd, ...)` (lines 684, 686)
- `Git.ensure_autoresearch_branch(init_cwd, ...)` (line 702)
- `Git.head_sha(init_cwd)` (line 703)
- `Git.capture_init_dirty_json(init_cwd)` (line 704)

Pass `init_cwd` to `DB.insert_session` as the new `cwd` column.

#### 2e. `handle_run` changes

```
# Change:
run_samples(ctx.workdir, script, ...)
run_checks_if_present(ctx.workdir, session_dir, ...)
# To:
let cwd = effective_cwd(ctx, session_dir);
run_samples(cwd, script, ...)
run_checks_if_present(cwd, session_dir, ...)
```

#### 2f. `handle_log` changes

```
# Change all ctx.workdir references:
Git.dirty_paths(ctx.workdir)
exclude_session_paths(..., ctx.workdir, session_dir)
commit_or_revert(decision, ctx.workdir, ...)
# To:
let cwd = effective_cwd(ctx, session_dir);
Git.dirty_paths(cwd)
exclude_session_paths(..., cwd, session_dir)
commit_or_revert(decision, cwd, ...)
```

#### 2g. `resolve_session_dir` changes

Currently resolves relative paths against `ctx.workdir`. When `cwd` is
provided in the `ar_init` call, relative `session_dir` should resolve
against that CWD instead. For `ar_run`/`ar_log`, the session_dir is
typically passed as an absolute path or uses the default, so this change
is mainly for consistency.

#### 2h. `tool_hook` change (line 951)

`derive_state` is called with `session_dir` (not `ctx.workdir`) and only
does DB queries, so it doesn't need `cwd`. No change needed here.

### Fix 3: Add worktree workdir hint to prompt (addresses RC3)

The prompt already says "Execute benchmark steps in worktree root." But the
agent doesn't know that `ReadFile`/`WriteFile`/`EditFile` are workdir-scoped.
Add a note to the execution contract:

```
Tool constraints in worktree:
- ReadFile, WriteFile, EditFile, Search only work with paths relative to the
  main repo root (/workspaces/motoko_agent). They cannot reach the worktree.
- Use BashExec with `cat`, `tee`, `sed` for reading/writing worktree files.
- ar_init, ar_run, ar_log, ar_notes work in the worktree via the `cwd`
  argument on ar_init (persisted for the session).
```

### Fix 4: Note AILANG docs version gap in prompt (addresses RC2)

Add to the troubleshooting section:

```
- ailang-docs MCP server covers up to v0.19.1; installed compiler is v0.22.0.
  For syntax questions, read existing .ail files in the repo rather than
  querying the docs server. The candidate code itself is the best reference.
```

---

## Revised Prompt Diff Summary

| Section | Change |
|---------|--------|
| Execution contract | Add "Tool constraints in worktree" note |
| Step 4 | "Create benchmark harness" → "Copy pre-baked benchmark harness" |
| Step 7 (`ar_init`) | Add `"cwd"` field to tool arguments |
| Troubleshooting | AILANG docs version gap note |

The prompt's 11-step structure and all `ar_*` tool call shapes remain
unchanged except for the added `cwd` field on `ar_init`.

## New Fixture Files to Create

```
benchmarks/fixtures/autoresearch_self_bootstrap/
  bench/
    exercise_100_calls.sh    # shell-based hot-path exercise (301 duckdb spawns)
    shim/duckdb              # counting shim
    benchmark.sh             # metric emitter
    checks.sh                # FSM/scope/invariant validator
```

These must be committed and hashed before any benchmark run. The prompt's
step 5 (SHA256 freeze) applies to these fixtures.

## Code Changes Required

### In `packages/motoko-ext-autoresearch/`

| File | Change | Why |
|------|--------|-----|
| `db.ail` | Add `cwd TEXT` column to sessions schema; add `current_cwd()` query | Persist per-session CWD |
| `tools.ail` | Add `parse_cwd(args, fallback)` function; add `cwd` to `ar_init` schema | Accept CWD argument |
| `autoresearch.ail` `handle_init` | Replace 6x `ctx.workdir` with `init_cwd` from parsed args | All git/script ops use worktree |
| `autoresearch.ail` `handle_run` | Replace 2x `ctx.workdir` with `effective_cwd(ctx, session_dir)` | Benchmark runs in worktree |
| `autoresearch.ail` `handle_log` | Replace 3x `ctx.workdir` with `effective_cwd(ctx, session_dir)` | Git ops target worktree |
| `autoresearch.ail` `resolve_session_dir` | Accept optional `cwd` override for relative path resolution | Session dir in worktree |

### Files NOT changed

- `state.ail`: `derive_state` takes `session_dir`, only does DB queries — no CWD needed.
- `git_ops.ail`: Already takes `cwd` as an argument to all functions — no changes needed (callers pass the corrected CWD).
- `scope.ail`, `metrics.ail`, `notes.ail`, `compaction.ail`, `prompts.ail`: No `ctx.workdir` references.

### Verification

After changes:
```bash
ailang check --package packages/motoko-ext-autoresearch
# Existing tests
ailang test packages/motoko-ext-autoresearch/state_test.ail
ailang test packages/motoko-ext-autoresearch/scope_test.ail
ailang test packages/motoko-ext-autoresearch/metrics_test.ail
```

## Implementation Order

1. **Fix 2 first** (code change — RC4). Without it, `ar_init` always rejects.
   - Add `cwd` column to DB schema
   - Add `parse_cwd` and `current_cwd` functions
   - Add `effective_cwd` helper
   - Update `handle_init` (6 sites), `handle_run` (2 sites), `handle_log` (3 sites)
   - Update `ar_init` tool schema
   - Run `ailang check --package packages/motoko-ext-autoresearch`
   - Manual test: create a worktree, call `ar_init` with `cwd` pointing
     to it, verify the worktree guard passes and session is stored correctly

2. **Fix 1** (create fixture files — RC1, RC5).
   - Write all four bench files
   - Test `exercise_100_calls.sh` produces 301 lines in `$SPAWN_LOG`
     (1 seed + 300 loop)
   - Test `benchmark.sh` emits exactly three `METRIC` lines
   - Test `checks.sh` passes against `packages/motoko-ext-autoresearch/`
   - Commit fixtures

3. **Fixes 3 & 4** (prompt updates — RC2, RC3).
   - Update `benchmarks/prompts/autoresearch_self_bootstrap.md`

4. **Smoke test**: Run `make run_autoresearch_self` and verify the agent
   reaches `ar_init` within the first 8 steps and the init succeeds.

## Out of Scope

- **Fixing the `ReadFile` workdir restriction for worktrees.** This would
  require changes to `tool_runtime.ail` in the core runtime, which is
  vendored and not owned by this project. The `BashExec` workaround is
  sufficient.
- **Updating the ailang-docs MCP server.** That's an upstream dependency
  (`sunholo-data/ailang`). The prompt hint is the right short-term fix.
- **Performance of derive_state (3 spawns per call).** This is the thing
  the benchmark is designed to *measure and optimize* — don't fix it here.
  The optimization loop should discover the caching fix autonomously.
