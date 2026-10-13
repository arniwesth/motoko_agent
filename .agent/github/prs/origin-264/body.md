---
repo: arniwesth/motoko_agent
pr: 264
branch: chore/repetition-guard-pin-metadata-poll
ticket: null
title: "test(repetition_guard): pin the poll that moves only in its metadata (check 21)"
---

## Summary

Adds check 21 to `scripts/verify_repetition_guard.ail`. It is a test only: the guard's code does
not change.

Since #260 the guard compares an extension result without its `tool_call_id`. Until then the id
alone kept every extension poll out of the identical-result rule. A poll is now safe only if its
result changes between calls. herdr's still-waiting `DelegateCheck` result changes in
`metadata.elapsed_ms`, and for a motoko delegate its stdout is close to fixed. Check 20, added by
#260, covers a moving stdout only. Check 21 feeds twelve polls that differ in nothing but the id
and `metadata.elapsed_ms`, and requires that the next one is not denied.

The check was proposed in the review of #260:
https://github.com/arniwesth/motoko_agent/pull/260#issuecomment-6151046681

## Changes

- test(repetition_guard): pin the poll that moves only in its metadata (check 21)

1 file changed.

## Governing docs

None. No `.agent/projects/` document governs the repetition guard's checks. The reason for this
one is the replay in the review comment linked above: over 179 recorded sessions the new result
key denied nothing in the 144 sessions since 2026-09-15, and 64 calls in two sessions from 12 and
13 September, all `DelegateCheck` polls whose error result then carried empty metadata.

## Predicted outcome

- **No session behaves differently.** Nothing a session loads is changed.
- **`make verify_repetition_guard` prints 21 `OK` lines instead of 20.** The target is part of
  `make check_core`, which CI runs in "check_core + verify_extensions +
  smoke_no_delegated_storm". No other target, tool or workflow reads the script.
- **A later change that makes the result key drop or normalise `metadata` turns this check red**
  instead of denying live `DelegateCheck` polling. Checked here with one such change, below.
- **CI.** Its result was not waited for when this was written.

## Test evidence

Run in a worktree cut from `origin/main` at `25e76272`, the merge of #260, on AILANG v0.52.5.

- `make verify_repetition_guard`: 21 `OK`, no `FAIL`. The new line is
  `OK: a poll whose only moving part is metadata.elapsed_ms is not a loop`.
- The check can fail. With `drop_call_id` in `repetition_guard.ail` changed to drop `metadata` as
  well as `tool_call_id` (not committed), the same target prints
  `FAIL: a poll whose only moving part is metadata.elapsed_ms is not a loop` and exits 1. That was
  the only `FAIL` line.
- `make check_core`: exit 0 in 2 min 47 s, ending `src/core/ type-check: 59 passed, 0 failed`.
- Not run: `make dst`. The change is one script that only `verify_repetition_guard` reads.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
