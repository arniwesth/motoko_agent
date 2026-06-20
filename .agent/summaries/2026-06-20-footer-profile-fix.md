# Session Summary: TUI Footer Profile Fix

Date: 2026-06-20

## Context

The session started by reading `README.md`, then investigated why `make run` showed a Motoko footer like:

```text
profile: default | model: openrouter/deepseek/deepseek-v4-flash | ... | ext: compaction_ai, context_mode, exa_search, eval, mcp, ailang_docs
```

even though the runtime appeared to be loading `.motoko/config/observability/`.

## Findings

- `AgentUI` had a `profile` constructor option, but `src/tui/src/index.ts` did not pass the active profile into it.
- Because of that, the footer started from `AgentUI`'s class default: `default`.
- The runtime already emits the effective profile in `session_start.config_profile`, but the TUI event type did not include `config_profile`/`config_dir`, and `ui.ts` did not use it.
- Profile switching could also leave the footer stale because the restart path updated the runtime profile variable without calling `ui.setProfile()`.
- `make run` was actually defaulting to `observability` because the current devcontainer environment exports `MOTOKO_CONFIG=observability`.
- That env var comes from `.devcontainer/docker-compose.observability.yml`, which sets:

```yaml
environment:
  MOTOKO_CONFIG: observability
```

- The Makefile intentionally derives `PROFILE` from `MOTOKO_CONFIG`:

```make
PROFILE ?= $(if $(MOTOKO_CONFIG),$(MOTOKO_CONFIG),default)
```

## Changes Made

- Updated `src/tui/src/index.ts` to pass `profile` into `new AgentUI(...)`.
- Updated `src/tui/src/index.ts` restart paths to call `ui.setProfile(profile)` when the selected profile changes.
- Updated `src/tui/src/runtime-process.ts` so the typed `session_start` event includes optional `config_profile` and `config_dir`.
- Updated `src/tui/src/ui.ts` to set the footer profile from `event.config_profile` when present.
- Wrote a PR description to `.agent/prs/mot-7-fix-wrong-profile-name-in-footer.md`.

## Verification

- `bun run build` passed in `src/tui`.
- Focused tests passed with Node:

```bash
node --experimental-vm-modules node_modules/.bin/jest --testPathPattern='src/(runtime-process.stream-protocol|ui.wait-state)\\.test\\.ts'
```

- Running the same focused tests through the Bun/Jest launcher failed before executing tests with:

```text
TypeError: Attempted to assign to readonly property.
```

This appeared to be a Bun/Jest harness issue rather than a failure in the changed code.

## Current Worktree Notes

At the time of the session, the worktree also contained unrelated untracked directories:

```text
ailang/
oh-my-pi/
```

Earlier local config/lockfile modifications were present before the final branch state checked during the PR-description step; care was taken not to revert unrelated user changes.

## Operational Notes

To force the default profile from the observability devcontainer:

```bash
make run PROFILE=default
```

or:

```bash
MOTOKO_CONFIG=default make run
```

To let the Makefile fall back to `default` in the current shell:

```bash
unset MOTOKO_CONFIG
make run
```
