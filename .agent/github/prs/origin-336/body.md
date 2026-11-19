---
repo: arniwesth/motoko_agent
pr: 336
branch: chore/gitignore-ailang-link
ticket: null
title: "chore(gitignore): ignore a worktree's ailang link, not only the directory"
---

## Summary

`.gitignore` had `/ailang/`, and a trailing slash matches only a directory. A worktree that links
in the shared checkout's AILANG tree (`ln -s …/ailang ailang`) therefore showed an untracked
`ailang` entry, and the new-task skill warned not to `git add -A` over it. `/ailang` matches the
link as well as the directory, and the skill now says how to link it.

## Changes

- chore(gitignore): ignore a worktree's ailang link, not only the directory

2 files changed.

- `.gitignore`: `/ailang/` becomes `/ailang`. The comment above it gives the reason, so nobody
  restores the slash.
- `.claude/skills/new-task/SKILL.md`, step 4: the caveat is replaced by the `ln -s` line.

**Overlap:** #56 (a merge-main branch, last updated 2026-06-22) adds the `/ailang/` line this
changes. If it is ever revived, that is a one-line conflict; keep `/ailang`. #21, #35 and #37
touch other lines of `.gitignore`.

## Governing docs

`AGENTS.md`, "What a worktree does not give you", and the `new-task` skill, which this edits.

## Predicted outcome

A worktree with an `ailang` link shows a clean `git status`. The shared checkout's `ailang/`
directory stays ignored.

## Test evidence

In a worktree cut from `origin/main` (`dd8a12f1`):

| | `/ailang/` (main) | `/ailang` (this PR) |
|---|---|---|
| `ailang` link: `git status --short` | `?? ailang` | clean |
| `ailang` link: `git check-ignore -v ailang` | exit 1, not ignored | `.gitignore:18:/ailang` |
| `ailang/` directory with a file in it | ignored | ignored, `!! ailang/` |

`git ls-files -ci --exclude-standard`, tracked files that match an ignore rule: identical before
and after.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
