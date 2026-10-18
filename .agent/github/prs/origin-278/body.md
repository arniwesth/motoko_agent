---
repo: arniwesth/motoko_agent
pr: 278
branch: fix/herdr-wall-cut-own-attempt
ticket: null
title: "fix(herdr): a wall-cut DelegateCheck recovers only its own attempt (#275 follow-up)"
---

## Summary

#275 was merged at `1ef3cf14`, one commit before the fix for its fourth review's finding. This PR
lands that fix.

The defect is on `main` now. When the shell's time limit cuts off a `DelegateCheck`'s herdr call,
the check reads the delegate's pane and kind from the run file and reopens its wait. After a linked
retry, a check on the original handle took the retry's attempt. The wait it built had the
original's answer path and the retry's pane and kind. That revives a finished delegation as
pending, and its wake can be delayed or report it lost because of unrelated work.

## Changes

- fix(herdr): a wall-cut check recovers only its own attempt from the run file

`open_attempt` in `packages/motoko-ext-herdr/dagr.ail` now takes the task's latest attempt only
when the task's `owner` is the checked handle. `open_task_model`, `open_retry_model` and
`attach_to_task` all keep `owner` on the handle the latest attempt belongs to. Any other handle gets
nothing, and the wall-cut check stays the error it was before #275's round 3, with no wait.

2 files changed: `packages/motoko-ext-herdr/dagr.ail` and
`scripts/verify_herdr_delegate_wait.ail`.

## Governing docs

- `.agent/projects/013_core_architecture_for_dst/ADR-002-park-and-wake.md`: the wait this
  reopens. Unchanged.
- PR #275's record, `.agent/github/prs/origin-275/body.md`: round 3 added the run-file lookup this
  corrects.

## Predicted outcome

- A wall-cut check on a delegation's current handle reopens its wait with its own pane, kind,
  answer path and run key, as in #275.
- A wall-cut check on a handle a linked retry has replaced is an error and opens no wait. It no
  longer opens a wait on the retry's pane.
- Nothing else changes. Checked by `verify_herdr_delegate_wait` c16 and c17 and the
  `open_attempt_pane`/`open_attempt_kind` rows.

## Test evidence

- `ailang check` on `types.ail`, `herdr.ail`, `register.ail` and `dagr.ail`: ok.
- `ailang test`: `types.ail` 327, `dagr.ail` 84, `herdr.ail` 8 and `progress_contract_guard.ail`
  25, all passed.
- `make`, each exit 0: `verify_extensions`, `verify_repetition_guard`, `verify_herdr_gate`,
  `verify_herdr_check_answer`, `verify_herdr_delegate_wait`, `verify_wait_descriptor_fixtures`,
  `verify_herdr_owner_tag`, `verify_herdr_dagr_pane`, `verify_herdr_orchestrator`,
  `verify_delegate_kind`, `verify_dagr_producer`, `verify_exit_intent`,
  `verify_strict_context_limit`.
- `git diff --check origin/main...HEAD`: clean.
- Codex Sol reviewed `b43ed6e1..851e27be` and approved, with no findings:
  - Its round-4 probe now returns empty for the original handle and `w1:p9`/`motoko` for the
    retry's. On `b43ed6e1` both returned the retry's.
  - c16 fails on `b43ed6e1` and passes with the fix. c17 is the positive control and passes on
    both. Three of the 11 `dagr.ail` rows fail on `b43ed6e1`.
  - It ran `verify_mot136_dagr_producer.ail`, 44 assertions, and passed each of its 29 run-file
    snapshots' live owners to the new lookup. All 171 checks matched the recorded pane and actor,
    across plain delegations, linked retries and first and later attachments.
  - It found no producer-written run file without `owner`: the producer has written it since its
    first commit, `d75b62f4`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
