---
name: new-task
description: Start a task in its own git worktree and branch, cut from origin/main, so parallel sessions never share a working tree. Use at the beginning of every feature, fix, doc change or other task in this repository, before the first edit. Also use when delegating work that edits files.
---

# New task

One task, one worktree, one branch. The shared checkout stays on `main` and nobody edits,
switches branches or commits there. `AGENTS.md` states the rule; this is how to follow it.

Adapted from the `new-feature` skill in `michaelshimeles/skills`. The steps are its steps; the
scripts and the notes on what a worktree lacks are this repository's.

## Steps

1. **Check for overlap.** Name the paths you expect to change:

   ```bash
   tools/worktree/status.sh src/core/compaction.ail packages/motoko-ext-herdr
   ```

   It lists every worktree with its uncommitted files, says whether the shared checkout is off
   `main` or has modified files, and lists the open pull requests that change those paths. If
   another pull request or another session's uncommitted work touches what you need, stop and
   ask before starting.

2. **Create the worktree.**

   ```bash
   tools/worktree/new.sh <name> <branch>
   ```

   `<name>` is short, lowercase, with hyphens; the worktree becomes `../motoko_agent-<name>`.
   For `<branch>` use a prefix already in use here: `feat/`, `fix/`, `docs/`, `chore/`, or
   `arniwesth/NNN-<slug>` for work under a numbered project. The script fetches, cuts the branch
   from `origin/main`, and refuses a name or branch that exists. Pick another; never reuse one.

3. **Work there.** Use the worktree's path for every edit, every `git` command and every
   `tools/pr` run. Confirm with `git -C <worktree> branch --show-current`.

4. **Know what is missing.** A worktree has tracked files only. The script prints what the shared
   checkout has that yours does not:

   - `ailang/`, the nested AILANG checkout. Linking it in leaves an untracked `ailang` entry,
     because `.gitignore` ignores the directory and not a link; do not `git add -A` over it.
   - `.env`. `tools/pr` then needs `MOTOKO_BOT_GH_TOKEN` in the environment.
   - `.dagr/` and `.motoko/`, which hold run files, sessions and the delegate mailbox.

5. **Keep it until the pull request is merged or closed.** Then, from any checkout:

   ```bash
   git worktree remove ../motoko_agent-<name>
   git branch -D <branch>
   ```

   `-D` is expected: after a squash merge `-d` refuses although the work is merged.

If your harness creates a worktree for you, keep the one it made and skip step 2. Steps 1, 3, 4
and 5 still apply.

## Delegating

A delegate that edits files gets its own worktree as well. Create it first, then pass its path as
`cwd` to `Delegate`. This repository's rule is the explicit request the `herdr` skill asks for
before it will use a different working directory.

Two things do not move with the delegate:

- **Its mailbox.** The task file and the answer path are in the orchestrator's
  `.motoko/herdr-delegates/`, not the worktree's (`HERDR_DELEGATE_DIR`,
  `packages/motoko-ext-herdr/register.ail`). Tell the delegate the absolute path.
- **The run file.** It stays in the orchestrator's `.dagr/` (`MOTOKO_DAGR_DIR`, same file).

## What this does not isolate

Worktrees separate files, not everything else. Ports, a shared database, the nested `ailang/`
build and anything under the shared checkout's `.motoko/` are still shared. Before trusting a
server, confirm it is your process that answers on the port.
