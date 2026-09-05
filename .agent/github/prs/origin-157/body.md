---
repo: arniwesth/motoko_agent
pr: 157
branch: arniwesth/mot-97-github-ops
ticket: MOT-97
title: "MOT-97: GitHub PR ops pipeline (WI-0 → WI-4)"
---

## Summary

Implements ADR-001 (016_github_ops) WI-0 through WI-4: `gh` in the container, a bot
credential kept separate from the operator's, a PR creation driver that writes the PR number
back, a comment sync with a git-versioned state record, and the backfill that opens the new
`.agent/github/` tree while freezing `.agent/prs/`.

The point is not automation for its own sake -- it is that GitHub review becomes an intake
channel with provenance, so a reviewer's claim can be ranked, tested and dispositioned once
rather than re-litigated. Automation stays at degree 1 throughout: grounding is mechanized,
judgment is not.

## Changes

- WI-1a: install the GitHub CLI in the container
- WI-1b: pass the bot credential through under a non-GH_TOKEN name
- WI-2: PR template, creation driver with number write-back, and the mirror
- WI-1b follow-up: resolve the bot credential explicitly, and flag a PAT that cannot write
- Extract tools/pr/lib.ts ahead of WI-3
- WI-3: pr-sync and the state writer, with the cache gitignore
- ADR-001: corrections C1-C8 from implementing WI-0..WI-3
- WI-4: freeze .agent/prs/, backfill open PRs, first responded record

16 files changed.

## Governing docs

- `.agent/projects/016_github_ops/ADR-001-github-pr-ops-pipeline.md`

## Predicted outcome

Settles part of ADR-001's prediction (015 §3.5):

- **(a) every new `origin` PR is driver-created with a populated template.** This PR is the
  first real test -- it was authored by `make pr` against a staged body and its number was
  written back to `.agent/github/prs/origin-<n>/body.md`. Checkable by whether that file
  exists with the number in frontmatter.
- **(b) at least one upstream comment reaches `responded` or `dismissed`-with-reason through
  the pipeline within two weeks of WI-3.** Recorded here as at risk: upstream currently has
  **zero open PRs**, so satisfying (b) depends on activity nobody in this PR controls. If it
  fails for that reason, that is the honest cause, not premature mechanization.
- **(c) no dispositioned comment is re-litigated.** The first `responded` record
  (`origin-97`, comment 5257958760) is the test case. `make pr_sync` must never return it to
  `pending`; it is flagged `stale` on edit instead.

If sync stops being run, the state tree goes quietly out of date rather than failing loudly.
That is the main thing to watch.

## Test evidence

No test harness exists for `tools/` (reported, not invented -- see the handoff's stop-and-report
#3). Verified manually against live data:

- `gh --version` → 2.97.0; `install_gh` idempotent on re-run; `bun install && bun run build`
  (the postCreateCommand) still exits 0.
- **Identity split**, same container: `make pr_whoami` → `arniwesth`;
  `make pr_whoami PR_FLAGS=--as-bot` → `motoko-agent`. With a valid bot token exported as
  `GH_TOKEN`, plain `gh api user` acts as the bot while the driver still reports `arniwesth`
  -- D1 holds against a hostile ambient environment.
- **Driver**, on a throwaway branch: created PR #156 with all five sections populated, wrote
  `pr: 156` back to `body.md`, and on re-run **adopted** it rather than opening a second.
  Deleting the local record and re-running reconstructed it from GitHub. PR and branch deleted.
- **Sync invariants**: idempotent (byte-identical re-run); judgment fields and unknown fields
  survive a run; an edited comment gets `stale: true` without rewinding `status`; deleting the
  cache loses nothing; malformed input is refused without clobbering.
- **YAML**: `state.yaml` round-trips through `js-yaml` with the right types -- `pr` and
  `comment_id` as numbers, `stale` as boolean, and `reason: "superseded by #154"` intact
  (unquoted it parses as `"superseded by"` -- see ADR correction C8).
- **Backfill**: 21 PRs cached, 4 inbound comments queued, 7 of ours excluded, 0 upstream PRs.
