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

### RC4: `ar_init` worktree guard checks `ctx.workdir`, not the experiment CWD

**Critical blocker the original plan missed.** Even if the agent had gotten
past step 4, `ar_init` would have rejected the call.

`handle_init` (autoresearch.ail:672) calls `require_linked_worktree(ctx.workdir)`.
`ctx.workdir` is set at agent startup to the process CWD — always
`/workspaces/motoko_agent` (the main checkout) when launched via `make
run_autoresearch_self`. The worktree guard compares `git rev-parse --git-dir`
vs `--git-common-dir` from that path. In the main checkout they're equal
(both `.git`), so the check rejects with:

    "ar_init worktree-first enforced: run from a linked git worktree,
     not the main checkout"

The agent can `cd` via `BashExec` to the worktree, but that doesn't change
`ctx.workdir` — it's fixed for the session. So:

- `require_linked_worktree(ctx.workdir)` → always fails
- The `shell()` helper `cd`s to `ctx.workdir` before running git commands
- No amount of prompt editing can fix this; it's a code bug

**The worktree guard was designed for a scenario where Motoko itself is launched
from inside a worktree.** The self-bootstrap flow is different: Motoko runs
from the main checkout and the agent creates/uses a worktree via BashExec.
The guard needs to check the worktree path (derivable from `session_dir` or
a new `cwd` argument), not `ctx.workdir`.

### RC5: Exercise script measures the wrong thing

The plan's proposed `exercise_100_calls.sh` runs a single `duckdb` SQL query
100 times. But `derive_state` (the actual hot path) spawns **2-4 duckdb
processes per call**: `current_segment` → `SELECT * FROM sessions ...`,
`current_status` → same query, `has_pending_run` → `SELECT COUNT(*) ...`,
and optionally `read_pending_run`. A shell script that runs one query per
iteration doesn't exercise the same code path or produce the same spawn
count.

The implementation plan's Appendix A (line 642) calls for
`ailang run ... exercise_100_calls.ail` which *would* exercise the real
`derive_state` — but that requires a valid AILANG file, which loops back
to RC1.

---

## Fixes

### Fix 1: Pre-bake the benchmark harness (addresses RC1, RC5)

**What:** Ship the four benchmark files as checked-in fixtures under
`benchmarks/fixtures/autoresearch_self_bootstrap/bench/`, and change the
prompt's step 4 from "create these files" to "copy these files."

#### `bench/exercise_100_calls.sh` (shell, replaces `.ail`)

The AILANG exercise was the right idea (call `derive_state` 100 times
via the real candidate code), but authoring it at runtime is fragile.
Replace with a **shell script that simulates the derive_state query pattern**
accurately — running the same 3 SQL queries per iteration that the real
`derive_state` dispatches:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Simulate the derive_state hot path 100 times.
# derive_state makes 2-3 duckdb spawns per call:
#   1. current_segment: SELECT * FROM sessions ORDER BY id DESC LIMIT 1
#   2. current_status:  (same query, re-executed — separate DB.current_status call)
#   3. has_pending_run: SELECT COUNT(*) AS n FROM pending_runs WHERE segment = ...
#
# We replicate this exact pattern so the shim counts match real behavior.

SD="${SESSION_DIR:-.motoko/autoresearch}"
DB="$SD/autoresearch.db"
mkdir -p "$SD"

# Ensure minimal schema exists (matches db.ail ensure_schema)
duckdb "$DB" "
CREATE SEQUENCE IF NOT EXISTS seq_sessions START 1;
CREATE TABLE IF NOT EXISTS sessions (
  id INTEGER DEFAULT nextval('seq_sessions') PRIMARY KEY,
  segment INTEGER, status TEXT DEFAULT 'active'
);
CREATE TABLE IF NOT EXISTS pending_runs (
  session_id INTEGER, segment INTEGER, run_number INTEGER
);
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

This spawns 300 duckdb processes for 100 iterations — matching the real
`derive_state` behavior (3 spawns per call: `current_segment` calls
`current_session_row`, `current_status` calls `current_session_row` again
separately, then `has_pending_run`).

**Note:** The `current_session_row` function is called twice (once by
`current_segment`, once by `current_status`) because they are separate
exported functions that each independently call `run_sql`. This is the
exact inefficiency the benchmark is designed to detect and that the
optimization loop should fix.

#### `bench/shim/duckdb` (unchanged from prompt)

The counting shim. Already well-specified; ship it as a fixture.

#### `bench/benchmark.sh` (updated to reference shell exercise)

Update the exercise invocation line to call `exercise_100_calls.sh` instead
of `ailang run ... exercise_100_calls.ail`. The rest of the script
(DUCKDB_REAL validation, PATH rewrite, ext_lines counting, wall-time
measurement) stays as designed.

#### `bench/checks.sh`

Ship as fixture. The agent-generated version from the failed run was
reasonable — use it as the starting point, but verify all grep patterns
match the actual candidate source. Confirmed matches:

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

### Fix 2: Fix the worktree guard in `ar_init` (addresses RC4)

**This is a code change to the autoresearch extension.** The worktree guard
must check the *experiment's* working directory, not `ctx.workdir`.

**Option A (minimal — argument-based):** Add a `cwd` field to the `ar_init`
tool arguments. When provided, `require_linked_worktree` uses that instead
of `ctx.workdir`. The prompt passes `"cwd": "/workspaces/motoko_agent_autoresearch_wt"`.

```
# In handle_init, change:
require_linked_worktree(ctx.workdir)
# To:
let init_cwd = Tools.parse_cwd(call.arguments, ctx.workdir);
require_linked_worktree(init_cwd)
```

Also update `resolve_session_dir` to respect this `cwd` when resolving
relative `session_dir` paths, so that the session DB lands inside the
worktree.

**Option B (session_dir-based):** Derive the worktree check from
`session_dir` — if it's an absolute path, check whether it lives inside a
linked worktree. This is more implicit but doesn't require a new argument.

**Recommendation: Option A.** It's explicit, doesn't change existing
behavior for callers that don't pass `cwd`, and the prompt already knows
the worktree path.

**Tool schema change:** Add `cwd` (optional string) to `ar_init`'s
parameter schema in `tools.ail`.

**Prompt change (step 7):** Add `"cwd": "/workspaces/motoko_agent_autoresearch_wt"`
to the `ar_init` call.

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
  argument (see step 7).
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
| Step 8 (benchmark.sh ref) | Update to reference shell exercise |
| Troubleshooting | AILANG docs version gap note |

The prompt's 11-step structure and all `ar_*` tool call shapes remain
unchanged except for the added `cwd` field on `ar_init`.

## New Fixture Files to Create

```
benchmarks/fixtures/autoresearch_self_bootstrap/
  bench/
    exercise_100_calls.sh    # shell-based hot-path exercise (300 duckdb spawns)
    shim/duckdb              # counting shim
    benchmark.sh             # metric emitter
    checks.sh                # FSM/scope/invariant validator
```

These must be committed and hashed before any benchmark run. The prompt's
step 5 (SHA256 freeze) applies to these fixtures.

## Code Changes Required

### In `packages/motoko-ext-autoresearch/`

1. **`tools.ail`**: Add `parse_cwd(args, fallback) -> string` function.
   Add `cwd` to `ar_init` tool schema (optional string parameter).

2. **`autoresearch.ail` `handle_init`** (line 672): Change
   `require_linked_worktree(ctx.workdir)` to use the parsed `cwd` value.
   Also propagate `cwd` to `resolve_session_dir` so relative session_dir
   paths resolve against the worktree, not the main checkout.

3. **`autoresearch.ail` `tool_hook`** (line 949-961): For non-`ar_init`
   tools, `resolve_session_dir` already supports absolute `session_dir`
   arguments, so an absolute `session_dir` passed to `ar_run`/`ar_log`
   will work. But `shell()` calls in `handle_run` and `handle_log` use
   `ctx.workdir` as their CWD — verify these also need the `cwd` override
   for benchmark/checks script execution.

4. **`autoresearch.ail` `handle_run`** and **`handle_log`**: Verify that
   `run_command_for_sample` and `checks_script` execution use the correct
   CWD. If they use `ctx.workdir`, they'll run benchmark/checks from the
   wrong directory. May need to propagate `cwd` to these handlers too, or
   persist it in the session DB at `ar_init` time.

### Ripple effects to check

- `db.ail`: No changes needed — all functions take `session_dir` as an
  absolute path argument.
- `state.ail`: No changes needed — `derive_state` takes `session_dir`.
- `git_ops.ail`: Uses `shell(argv, cwd)` — verify the `cwd` passed to
  git operations (commit, revert) is the worktree path, not `ctx.workdir`.
  Currently `handle_log` passes `ctx.workdir` to `Git.selective_commit`
  and `Git.selective_revert` — these need the worktree CWD.

## Implementation Order

1. **Fix 2 first** (code change — RC4). This is the only fix that requires
   code changes to the extension. Without it, `ar_init` always rejects.
   - Add `parse_cwd` to `tools.ail`
   - Update `handle_init`, `handle_run`, `handle_log` to use worktree CWD
   - Add `cwd` to `ar_init` tool schema
   - Persist `cwd` in session row (or derive from `session_dir`) so
     `ar_run`/`ar_log` can use it without re-supplying
   - Run `ailang check --package packages/motoko-ext-autoresearch`
   - Test manually: create a worktree, call `ar_init` with `cwd` pointing
     to it, verify it passes the worktree guard

2. **Fix 1** (create fixture files — RC1, RC5).
   - Write all four bench files
   - Test `exercise_100_calls.sh` produces 300 lines in `$SPAWN_LOG`
   - Test `benchmark.sh` emits exactly three `METRIC` lines
   - Test `checks.sh` passes against `packages/motoko-ext-autoresearch/`
   - Commit fixtures

3. **Fixes 3 & 4** (prompt updates — RC2, RC3).
   - Update `benchmarks/prompts/autoresearch_self_bootstrap.md`
   - Update `Makefile` target if needed

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
