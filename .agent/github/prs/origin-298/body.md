---
repo: arniwesth/motoko_agent
pr: 298
branch: arniwesth/041-hygiene-notes
ticket: null
title: "fix(worktree): quiet new.sh, and note gh pr edit's limit (041 hygiene)"
---

## Summary

Two small corrections found while running 041. `tools/worktree/new.sh` printed `could not write config file .git/config` twice on every run in the devcontainer although the worktree was fine, and it no longer does. `tools/pr/README.md` now says that `gh pr edit` fails with the bot token and gives the `gh api -X PATCH` form that works.

**What changes for anyone who relied on tracking.** `new.sh` now creates branches with `--no-track`, so a new branch has no upstream. On a writable checkout, `git status` loses its ahead/behind count, and a bare `git pull` or `git rebase` loses its default. All three used to read `origin/main`. A bare `git push` is no worse: it was already refused, because the recorded upstream was `origin/main`, not the branch's own name. I measured this in a throwaway repository with git 2.43. `make pr` still runs `git push -u`, so on a writable checkout it records the correct upstream, `origin/<branch>`.

**No conditional for a writable checkout.** The only thing lost is an upstream pointing at `origin/main`, and a conditional would make the same command build differently on the host and in the container.

**The docs did not say what the task assumed.** Neither `AGENTS.md` nor `tools/pr/README.md` said explicit refspecs are the norm. Only three start prompts under `.agent/projects/` (005, 034, 041) said so. `tools/pr/pr.ts:379` does the opposite, with `git push -u`. So this PR states the rule in `tools/worktree/README.md`, and the code comment points there. `pr.ts` is unchanged.

`git branch -D <name>` still prints the message once; that is git's own deletion path and out of scope for this fix.

## Changes

- fix(worktree): stop new.sh writing branch config (041 hygiene)
- docs(pr): note that gh pr edit needs read:org (041 hygiene)

- `tools/worktree/new.sh`: `--no-track` on the `worktree add`, with a comment saying why.
- `tools/worktree/test.sh`: two new checks. The shared checkout's config stays byte-identical across `new.sh`, and the branch has no upstream.
- `tools/worktree/README.md`: a "Pushing" section.
- `tools/pr/README.md`: a "Correcting a published PR" subsection.

4 files changed.

## Governing docs

None: this is tool hygiene. The worktree rule is in `AGENTS.md`, and the push form was previously stated only in `.agent/projects/041_process_execution_timeouts/PROMPT-motoko-plan-001-start.md`.

## Predicted outcome

`tools/worktree/new.sh` runs silently on the read-only mount, and `tools/worktree/test.sh` fails if the config write returns. No `src/` behaviour changes.

## Test evidence

- The three probes from the shared checkout, with cleanup confirmed: `git branch zzz origin/main` printed the error twice; `git worktree add --detach` was silent; `git worktree add --no-track -b` was silent and on the right branch. A plain `-b` control printed the error twice. `touch .git/config` gave `Read-only file system`, and `mount` shows it as a `virtiofs (ro)` bind mount.
- `tools/worktree/test.sh`: exit 0, 38 passed, 0 failed. Against the old `new.sh` line: exit 1, and both new checks fail.
- `make check_core`: exit 0, 60 passed, 0 failed. It says nothing about this change and was run as a sanity signal only.
- `new.sh` itself was not run against the real shared checkout, only in the test's throwaway repository; its `worktree add` form was probed there directly.
- CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
