---
repo: arniwesth/motoko_agent
pr: 275
branch: fix/herdr-check-wall-and-park
ticket: null
title: "fix(herdr): park instead of polling DelegateCheck, and size its wait under the process wall"
---

## Summary

The first 034 PLAN-001 orchestrator session (`session_1792309035163`) never parked. It called
`DelegateCheck` every ~35 s, resending ~107k tokens of context each time, for as long as the delegate
ran. Three things caused it:

- The start prompt told it to poll and never to end its turn early. Parking happens only when the
  model ends its turn with a wait open.
- The herdr tool texts said "Poll with DelegateCheck" and "Check again".
- Every check timed out. The 45 s `herdr agent wait` ran under AILANG's 30 s `--process-timeout`,
  which kills it, and the error was reported as `herdr_cli_rejected`.

This PR fixes all three, and adds `gemini-4-argon`'s context limit so its sessions compact.

## Changes

- fix(herdr): size DelegateCheck's wait under the process wall, and tell the model to park
  - `wait_elapsed` reads the process wall's `timeout after <n>ms` as a poll interval, as it already
    reads herdr's own `timeout`.
  - The default `check_wait_ms` is sized from `MOTOKO_PROCESS_TIMEOUT`: 20 s under the default 30 s
    wall, up to 45 s under a raised one. `HERDR_CHECK_WAIT_MS` still overrides it. The 2026-09-08
    comment that said nothing on this path stops a longer wait is corrected.
  - The Delegate description, the Delegate result, both "not written yet" check results and the
    timeout hint now say to end the turn and park. The phrases `progress_contract_guard` matches
    on are unchanged.
  - 034's start prompt:
    - *VERIFYING A DELEGATE* step 1 says to wait by ending the turn, and not to check before the
      wake. A check that finds a claude delegate idle with no answer file closes its pane. That
      killed the first W0.1 attempt's background `make dst`.
    - The end-of-turn rule allows ending the turn to wait on a delegate.
    - The operator note no longer describes waiting as "~70 steps".
- chore(models): add `google/gemini-4-argon`'s context limit, 1048576. This is OpenRouter's
  `context_length` from `api/v1/models`, read 2026-10-18; max completion is 65536. The lookup strips
  `openrouter/`, so the bare id serves both spellings.

5 files changed.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/PROMPT-motoko-plan-001-start.md`
- `.agent/projects/013_core_architecture_for_dst/ADR-002-park-and-wake.md`: D2 is the park this
  points the model at. Unchanged.

## Predicted outcome

- An orchestrator that delegates and has nothing else to do ends its turn, and the journal shows a
  `park` entry. On the `wake` it makes one `DelegateCheck` call, instead of one call per ~35 s.
  - This was checked live on the same session after the operator gave it the new step 1 by hand:
    the W0.2 delegation parked (`session_1792309035163-….r1.1.p0`) with no check in between.
  - The tool texts in this PR take effect only after merge and a Motoko restart.
- A `DelegateCheck` cut off by the process wall reports the delegate as still working, not as
  `herdr_cli_rejected`.
- A `gemini-4-argon` session no longer warns that its context limit is unknown, and its compactors
  can trigger.

## Test evidence

- `ailang test packages/motoko-ext-herdr/types.ail`: 300 passed, 0 failed. This includes the new
  `wait_elapsed`, `process_wall_elapsed`, `process_wall_ms` and `check_wait_default` cases and the
  updated `code_hint` case.
- `ailang test packages/motoko-ext-herdr/herdr.ail`: 8 passed. `register.ail` has no tests.
- `ailang check` on `types.ail`, `herdr.ail` and `register.ail`: ok.
- `make` passed, each exit 0: `verify_extensions`, `verify_repetition_guard`, `verify_herdr_gate`,
  `verify_herdr_check_answer`, `verify_herdr_delegate_wait`, `verify_wait_descriptor_fixtures`,
  `verify_herdr_owner_tag`, `verify_herdr_dagr_pane`, `verify_herdr_orchestrator`,
  `verify_delegate_kind`, `verify_dagr_producer`, `verify_exit_intent`, `verify_strict_context_limit`.
- Not run: the full `make check_core` and `make dst`. The W0 delegate's heavy runs were using the
  machine, and the plan runs heavy targets one at a time.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
