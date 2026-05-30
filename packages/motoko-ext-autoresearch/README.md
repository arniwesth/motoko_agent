# sunholo/motoko_ext_autoresearch

A motoko_agent extension that turns the agent into a disciplined optimization loop:
**initialize** an experiment against a benchmark, **run** it to capture metrics,
then **log** a keep/discard decision that selectively commits or reverts the
iteration's changes. State is persisted in a DuckDB session database, and a
finite-state machine enforces the protocol (you cannot run twice without logging,
or finish with an unlogged run).

## Status

Experimental (v0.1.0). The `ar_init` / `ar_run` / `ar_log` / `ar_notes` tools, the
session FSM, scope/off-limits gating, metric aggregation (median + MAD), and
selective git commit/revert are all implemented.

## Overview

Each segment of an experiment is an iterative loop:

1. **`ar_init`** — declare the objective, the metrics (one deterministic primary +
   optional noisy secondaries), the `benchmark_script`, optional `checks_script`,
   and `scope_paths` / `off_limits` that bound what may change. Snapshots the
   baseline commit and the initially-dirty files.
2. **`ar_run`** — execute the benchmark script `samples` times, parse `METRIC`/`ASI`
   lines from stdout, aggregate (median; MAD for noisy metrics), run the checks
   script, and persist a *pending* run. The agent must log it before running again.
3. **`ar_log`** — record the pending run with `keep` or `discard`. On `keep`, the
   iteration's in-scope changes are committed (rejected if they touch `off_limits`
   without justification); on `discard`, they are reverted. Tracks improvement vs.
   the best kept run, a confidence report, and a stall counter for patience.

The loop stops on patience (no primary improvement for N consecutive kept runs),
`max_iterations`, or unrecoverable check failure. The `on_solver_candidate` hook
blocks the agent from "finishing" while a run is unlogged or the segment is still
active under patience/iterations.

`benchmark_script` must print lines like `METRIC <name>=<number>` (and optionally
`ASI <key>=<value>`); anything else is ignored. Exit code drives run status
(`0` = completed, `124` = timeout, else failed). `checks_script` (if present) gates
`keep` — a non-zero exit blocks keeping the run.

## Tools

| Tool | Required | Optional |
|------|----------|----------|
| `ar_init` | `objective`, `metrics[]` (`{name, direction: minimize\|maximize, noisy?}`), `benchmark_script` | `scope_paths[]`, `off_limits[]`, `constraints[]`, `checks_script`, `max_iterations`, `patience`, `new_segment`, `session_dir`, `cwd` |
| `ar_run` | — | `session_dir`, `timeout_ms`, `samples`, `label` |
| `ar_log` | `run_number`, `decision` (`keep\|discard`), `changes_summary`, `reasoning` | `learnings`, `justification`, `flag_runs[]`, `asi` |
| `ar_notes` | — | `body` (replace), `append_idea` (append) |

`cwd` (on `ar_init`) makes all git/script operations run against a different
directory than the agent's process cwd — used by the self-bootstrap benchmark so
the experiment runs in a linked worktree while the session DB stays in the main
checkout. It is persisted, so `ar_run`/`ar_log` inherit it.

The extension also advertises the host's `WriteFile`, `EditFile`, `BashExec`,
`ReadFile`, `Search`, and `RunTests` tools (via `provided_tools`) so it can gate
them through the FSM.

## Session state machine

`derive_state` derives the current state from the session DB on every tool call,
and `legal` decides which tools are permitted:

| State | Meaning | Allowed | Rejected |
|-------|---------|---------|----------|
| `Setup` | no active session yet | `ar_init`, file edits, reads | `ar_run`, `ar_log` |
| `Ready` | active session, no pending run | `ar_run`, `ar_notes`, `ar_init`, edits, `RunTests` | `ar_log` (nothing to log) |
| `AwaitingLog(n)` | run `n` captured, not yet logged | `ar_log`, `ar_notes`, reads | `ar_run`, file edits (must log first) |
| `Done` | segment finished/abandoned | `ar_init(new_segment=true)`, `ar_notes`, reads | `ar_run`, `ar_log` |

## Configuration

Defaults come from the host profile's `autoresearch.json`
(`.motoko/config/<profile>/autoresearch.json`), surfaced through
`RuntimeConfig.autoresearch` and passed to `register_with_config`:

```json
{
  "autoresearch": {
    "default_session_dir": ".motoko/autoresearch",
    "default_patience": 3,
    "default_max_iterations": 20,
    "default_samples": 1,
    "default_timeout_ms": 60000
  }
}
```

Per-`ar_init` arguments override these per session.

## Persistence

Everything for a session lives under `session_dir` (default `.motoko/autoresearch`,
resolved against the agent's workdir):

| Path | Contents |
|------|----------|
| `autoresearch.db` | DuckDB database: `sessions`, `runs`, `pending_runs` tables |
| `autoresearch.sh` | the `benchmark_script` written at `ar_init` |
| `autoresearch.checks.sh` | the `checks_script` (if provided) |
| `autoresearch.config.json` | snapshot of the init config |
| `autoresearch.md` | the human-readable notes/ideas doc (`ar_notes`) |

## Modules

| Module | Responsibility |
|--------|----------------|
| `autoresearch.ail` | hook wiring + `ar_*` handlers, benchmark execution, metric parsing |
| `tools.ail` | tool JSON schemas and argument parsing |
| `types.ail` | `ExperimentConfig`, `MetricSpec`, `AutoresearchConfig`, `ArState`, `PendingRun` |
| `state.ail` | `derive_state` (DB → FSM) and `legal` (per-state tool gating) |
| `db.ail` | DuckDB-backed persistence and row accessors |
| `scope.ail` | `path_matches_spec` (prefix/exact, no glob), scope-deviation computation |
| `metrics.ail` | median, MAD, improvement test, confidence report, stall count |
| `git_ops.ail` | selective commit/revert, dirty-path and baseline snapshots, branch helpers |
| `notes.ail` | the notes document |
| `compaction.ail` | `on_pre_step` history compaction |
| `prompts.ail` | the static protocol system-prompt patch |
| `register.ail` | `register_with_config` entry point (the registry contract) |

## Self-research bootstrap benchmark (worktrees & branches)

This extension can optimize a **separate copy of itself** — "optimizer ≠ optimized."
The benchmark prompt (`benchmarks/prompts/autoresearch_self_bootstrap.md`) and the
checked-in fixtures (`benchmarks/fixtures/autoresearch_self_bootstrap/bench/`) drive
the *live* extension to reduce `derive_state`'s duckdb-spawn count on a candidate
copy, while the live `packages/motoko-ext-autoresearch/` stays untouched.

### How each run isolates itself: a git worktree

A **git worktree** is an extra working directory linked to the same repository.
Normally a repo has one checked-out directory on one branch; a worktree gives you
*additional* directories, each on a different branch, all sharing the same `.git`
object store (cheap — not a clone, no copied history).

```bash
git worktree add -b <branch> <dir> HEAD   # create a new branch AND a checkout of it
git worktree list                         # show all worktrees
git worktree remove <dir>                 # delete the directory (the branch stays)
```

The benchmark's **step 2** runs (roughly):

```bash
git worktree add -b "autoresearch/self-bootstrap-$(date -u +%Y%m%d)[-N]" \
  /workspaces/motoko_agent_autoresearch_wt HEAD
```

— creating, in one command, a new branch **and** a throwaway worktree at
`/workspaces/motoko_agent_autoresearch_wt`. The agent copies the package to
`experiments/ar_candidate/` inside that worktree and makes all its edits there;
every kept iteration becomes a commit on that branch. **Step 11** removes the
worktree directory — but **the branch and its commits persist.**

### Why you see many `autoresearch/self-bootstrap-*` branches but no worktrees

Each run's lifecycle leaves a branch behind:

```
create branch -N  +  worktree dir  →  optimize, commit to branch  →  remove worktree dir
                                                                      (branch survives)
```

So N runs produce N branches (`…-20260530`, `…-2`, `…-3`, …) and zero leftover
worktrees. The step-2 naming loop skips already-used names, so the numeric suffix
climbs with each run. All runs reuse the same worktree **path**, which is why a
leftover worktree from an interrupted run blocks the next one ("worktree path
already exists" — remove it, or run cleanup step 11, first).

A branch is just a ~40-byte ref sharing the repo's object store, so these are nearly
free; they only keep their commits reachable until the branch is deleted.

### Inspecting and cleaning up

```bash
git worktree list                                   # live worktrees
git branch --list 'autoresearch/self-bootstrap-*'   # the per-run branches
git log --oneline <branch>                          # a run's kept-iteration commits

# Prune the per-run branches (their worktrees are already gone):
git branch -D $(git branch --list 'autoresearch/self-bootstrap-*')
```

## Develop

```bash
ailang lock                  # resolve registry deps
ailang check --package .     # type-check every module in this package
```

The package's `_smoke.ail` runs in the publish sandbox at `ailang publish` time and blocks publish on a panic. Edit it to assert anything that's load-bearing for your extension; drop the `-- optional` sections that don't apply.

### Path-dep dev loop (recommended for iterating against a host)

While iterating on this extension against `motoko_agent` (or any host that consumes it), use a path-dep in the host's `ailang.toml` so you don't have to publish for every change:

```toml
[dependencies]
"sunholo/motoko_ext_autoresearch" = { path = "../path/to/this/package" }

[extensions]
packages = [
  "sunholo/motoko_ext_autoresearch@0.1.0",   # version still matches [package].version above
]
```

Then from the host: `ailang lock && ailang generate-extension-registry && make verify_extensions` (or the host's equivalent). Once the loop closes, switch the host back to the published version pin and publish this package.

## Wire into a host (production, after publish)

In the host's `ailang.toml`:

```toml
[dependencies]
"sunholo/motoko_ext_autoresearch" = "0.1.0"   # registry version

[extensions]
packages = [
  # ... existing entries ...
  "sunholo/motoko_ext_autoresearch@0.1.0",
]
```

Then re-lock + regenerate the dispatch:

```bash
ailang lock
ailang generate-extension-registry
```

## Publish to the AILANG registry

When the extension is stable and you want others to consume it:

```bash
ailang publish --dry-run     # tarball + smoke test, no upload
ailang publish               # the real thing (requires AILANG_REGISTRY_API_KEY)
```

### Provider-safe tool naming

Tool names advertised via `provided_tools` (and the `name` field of `on_describe_tools`) MUST match `[A-Za-z0-9_]` — Anthropic Bedrock + Vertex AI reject names containing `.`, `-`, or other characters at the tool-name validator. Use `ctx_execute` or `CtxExecute`, never `ctx.execute`. `ailang publish` enforces this gate; the `--allow-dotted-tool-names` flag provides one-cycle migration grace if you're upgrading an older package.

### Publish checklist

- [ ] Bump `[package].version` in `ailang.toml` (semver: patch for fixes, minor for new tools, major for ExtensionHooks-breaking changes)
- [ ] `ailang check --package .` passes
- [ ] `ailang publish --dry-run` succeeds (smoke runs in sandbox)
- [ ] `ailang publish` (real upload — irreversible)
- [ ] Bump the host's pin: `"sunholo/motoko_ext_autoresearch" = "<new-version>"` + matching `[extensions].packages` entry
- [ ] Host: `ailang lock && ailang generate-extension-registry` + verify extensions boot

See: https://ailang.sunholo.com/docs/guides/package-publishing

## Documentation

- [Build Your First motoko Extension](https://ailang.sunholo.com/docs/guides/build-a-motoko-extension) (tutorial)
- [Motoko Extension Development workflow](https://ailang.sunholo.com/docs/guides/motoko-extension-development) (path-dep dev loop)
- [Extension Packages reference](https://ailang.sunholo.com/docs/guides/extension-packages)
- [Publishing Your Package](https://ailang.sunholo.com/docs/guides/package-publishing)
