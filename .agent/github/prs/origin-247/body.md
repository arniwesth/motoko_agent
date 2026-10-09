---
repo: arniwesth/motoko_agent
pr: 247
branch: chore/issue-237-follow-up-notes
ticket: null
title: "chore(github): records for the #237 follow-up — its closing reply, and issues #244, #245, #246"
---

## Summary

Records only. After #239 and #241 merged, #237 was answered and closed and three findings that
lived only in those PR bodies were filed as issues. This lands the files those were published
from. No code, no docs outside `.agent/github/`.

## Changes

- chore(github): records for the #237 follow-up — its closing reply, and issues #244, #245, #246

4 files changed.

| file | what |
|---|---|
| `.agent/github/issues/origin-237/response-6066331177.md` | the reply posted on #237 before closing it |
| `.agent/github/issues/origin-244/body.md` | flat layout: the host does not read the profile, so the run uses the host's default model |
| `.agent/github/issues/origin-245/body.md` | the TUI's context counter is dead since `6350b7ad` |
| `.agent/github/issues/origin-246/body.md` | the committed `ailang.lock` goes stale and nothing notices |

## Governing docs

- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md`: the file on disk is the
  source of truth and GitHub is transport. The three issue records were written by
  `tools/pr/issues.ts`.
- The pipeline has no command for a comment on an issue. The #237 reply was posted with `gh` as
  the bot and its record follows the form of a PR response record
  (`.agent/github/prs/origin-<n>/response-<id>.md`), with `issue:` and the comment's id in the
  frontmatter. That is a convention made up here for one file; say if it should be different.

## Predicted outcome

Nothing changes in behaviour. After this lands the four records are on `main`, and each matches
what is on GitHub.

## Test evidence

Nothing to run for the records themselves. What stands behind the three issues, each on `main` at
`21a8a96a`:

| issue | what was run |
|---|---|
| #244 | a headless launch per layout with the provider keys removed: the per-profile one asks for `OPENROUTER_API_KEY`, the flat one for `ANTHROPIC_API_KEY (model claude-sonnet-4-6 …)` |
| #245 | a search of every `.ail` file for the event name (none), and the commit that removed its emitter |
| #246 | `ailang check` in a fresh worktree, which prints the two-line warning; and the history of the lock and the package |

#245's issue body was edited once after filing, to stop it claiming more about the commits in
between than was checked; the record here is the edited text.
