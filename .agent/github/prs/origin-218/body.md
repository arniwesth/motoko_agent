---
repo: arniwesth/motoko_agent
pr: 218
branch: chore/worktree-rule
ticket: null
title: "feat(tools): the worktree rule — one task, one worktree, one branch"
---

## Summary

States the rule that parallel work happens in separate git worktrees, in the one file every agent
here loads, and adds the tools to follow it. The operator asked for this on 2026-10-04. That day
the shared checkout held 8 modified tracked files from several sessions and nineteen agent
processes had been started in it, while `AGENTS.md` was empty.

**Merging this needs one operator action.** `AGENTS.md` and `.claude/**` are in the R7 audit's
frozen set, so the R7 baseline has to be re-recorded afterwards (019 ADR-001 C2).

## Changes

- feat(tools): the worktree rule — one task, one worktree, one branch, with tools to follow it

8 files changed.

| File | What it is |
|---|---|
| `AGENTS.md` | The rule, in 36 lines. Claude Code, Codex and Motoko each load it at session start. |
| `.claude/skills/new-task/SKILL.md` | How to follow it, step by step, including what to do when delegating. |
| `tools/worktree/new.sh` | Creates `../motoko_agent-<name>` on a new branch from `origin/main`. Refuses a directory or branch that exists. |
| `tools/worktree/status.sh` | Lists every worktree with its uncommitted files, reports a shared checkout that is off `main` or modified, and lists the open pull requests that change the paths you name. |
| `tools/githooks/pre-commit` | Refuses a commit on `main`, and a commit from the shared checkout on any branch. |
| `tools/worktree/install-hooks.sh` | Turns the hook on, per user. |
| `tools/worktree/test.sh` | 36 checks in a throwaway repository. |
| `tools/worktree/README.md` | Use, install, test, limits. |

Three things a reviewer should know:

- **The hook is not turned on by this change.** Someone has to run `install-hooks.sh`.
- **The installer never writes the repository's config.** The R7 audit names `core.hooksPath`
  among the settings through which agent-writable configuration runs as the operator on the host.
  The installer adds a conditional include to the user's global git config instead, scoped to this
  repository. It should not be run on the host, where the tracked hook would run as the operator.
- **`AGENTS.md` now reaches Motoko's own system prompt** for any Motoko session started in this
  repository, through `src/core/agents_md.ail`. No test reads the real file; the two code-graph
  tests that mention `AGENTS.md` use fixtures.

Adapted from the `new-feature` skill in `michaelshimeles/skills`.

## Governing docs

- `.agent/projects/019_agent_confined/ADR-001-confined-agent-container.md` C2 — the obligation to
  re-record the R7 baseline after an approved change to `AGENTS.md` or `.claude/**`
- `.devcontainer/agent_sandbox/checks/r7_git_audit.py` — why the hook is not installed through the
  repository's config
- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md` — the pull request pipeline
  the rule points at

No project under `.agent/projects/` owns this change. The rule itself is the operator's.

## Predicted outcome

Landing this changes what a new session is told, not what the tree does.

- A Claude Code session started in the repository shows `AGENTS.md` as loaded, since there is no
  `CLAUDE.md`. Check: the session's first lines.
- `tools/worktree/status.sh --check` in the shared checkout fails today (8 modified tracked
  files). It should pass once the work now sitting there has moved to worktrees, and stay passing.
  Check: run it; watch the count.
- Where the hook is installed, no commit is made from the shared checkout. Check: its reflog
  shows no `commit:` entries after the install date.

It does not by itself move anyone's uncommitted work, and it does not give a delegate a worktree.

## Test evidence

- `tools/worktree/test.sh`: 36 passed, 0 failed. It covers `new.sh` (creates beside the shared
  checkout, from `origin/main`, refuses reuse), `status.sh --check` (passes clean, fails when
  modified or off `main`, ignores untracked files), the installer (hooks in effect in the shared
  checkout and in a worktree, repository config byte-identical, an unrelated repository
  unaffected, idempotent, uninstall), and the hook (refuses on `main`, refuses in the shared
  checkout, allows the override except on `main`, allows a task branch in its own worktree).
- Control: with the hook not installed, the same commit on `main` goes through.
- Mutation 1: with the hook replaced by `exit 0`, the four refusal checks fail.
- Mutation 2: with the installer changed to write the repository's config, "the repository's own
  config is byte-identical" and "holds no hooksPath" fail.
- `tools/worktree/status.sh Makefile` on this repository listed the same seven open pull requests
  as an independent lookup made earlier the same day.
- After all runs, this repository's config has no `core.hooksPath` and the global config has no
  `includeIf`.
- `main` already requires a pull request on GitHub (rules read 2026-10-04: `pull_request`,
  `non_fast_forward`, `deletion`). The hook adds a local refusal; it does not replace that.

Not done:

- [ ] The hook is not installed anywhere
- [ ] The R7 audit was not run: its baseline is on the host
- [ ] `shellcheck` is not installed here; the scripts were only syntax-checked with `bash -n`
- [ ] Nothing gives a delegate a worktree by default. `Delegate` still starts in the
      orchestrator's directory unless passed a `cwd`, and the delegate mailbox and `.dagr/` stay
      in the orchestrator's checkout
- [ ] The vendored `herdr` skill still says not to create a worktree unless asked; the new skill
      says this repository's rule is that request, and the `herdr` skill is not edited
- [ ] `herdr worktree create` was not tried
- [ ] The include condition was measured on git 2.43 only

🤖 Generated with [Claude Code](https://claude.com/claude-code)
