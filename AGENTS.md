# Working in this repository

Claude Code, Codex and Motoko each load this file when a session starts here. It holds only what
a session needs before it knows what it will touch. Keep it short and point to the detail.

## One task, one worktree, one branch

- Do task work in its own git worktree, on its own branch. Start with
  `tools/worktree/new.sh <name> <branch>`, which creates `../motoko_agent-<name>` from
  `origin/main`. The `new-task` skill walks through it.
- The shared checkout, the directory that owns `.git`, stays on `main`. Do not edit, switch
  branches or commit there.
- Never commit to `main`. Changes reach it through a pull request.
- Check for overlap before you start. `tools/worktree/status.sh <paths you expect to change>`
  lists every worktree, what is uncommitted in each, and the open pull requests that change
  those paths. On overlap, stop and ask.
- Leave other sessions' worktrees, branches and uncommitted files alone.
- Keep your worktree until its pull request is merged or closed.

## What a worktree does not give you

A worktree has tracked files only. `ailang/`, `.env`, `.dagr/` and `.motoko/` are gitignored and
live in the shared checkout. Two things follow:

- There is no `.env`, so `tools/pr` needs `MOTOKO_BOT_GH_TOKEN` in the environment.
- A delegate whose `cwd` is a worktree still has its task file in the orchestrator's
  `.motoko/herdr-delegates/`, and the run file stays in the orchestrator's `.dagr/`.

## Pointers

- Pull requests are opened through `tools/pr`, as the bot: `tools/pr/README.md`.
- Checks to run before a pull request: `CONTRIBUTING.md`, "Local Motoko changes".
- Design records: `.agent/projects/`.
- The worktree tools, their test and their limits: `tools/worktree/README.md`. A commit hook that
  refuses commits on `main` and from the shared checkout is in `tools/githooks/`. It is active
  only for a user who has run `tools/worktree/install-hooks.sh`, and is not for the host.
