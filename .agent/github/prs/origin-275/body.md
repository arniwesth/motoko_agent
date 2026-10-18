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

A review by codex `gpt-6.1-sol` at xhigh effort (`tmp/review-275-sol.md` in the shared checkout)
found five ways the new "end your turn and park" guidance could strand or mislead an orchestrator.
The third commit fixes them. The main fix bounds the two waits that never woke by themselves.
A second review (`tmp/review-275-sol-r2.md`) found four more problems in that fix. The fourth code
commit fixes them.

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

- fix(herdr): bound the waits that never woke, forward the process wall, parse Go durations
  - `wake-waiter.ts`, idle with no answer: a claude or codex delegate that settled with no answer
    file never woke the park, because its row never goes away. Now `idleNoAnswerMs` of continuous
    quiet wakes it as `lost`, and the core's wake sends the model to `DelegateCheck`. The default
    is 60 min, set with `MOTOKO_WAKE_IDLE_NO_ANSWER_MS`.
    - `working` resets the clock and returns to the settled-state wait. `blocked` resets it and
      never times out.
    - The bound is long because `DelegateCheck` closes an idle pane, and with it any background
      job still running there.
  - `wake-waiter.ts`, never registered: a row that was never seen was retried for ever as "not
    registered yet". Now, after `registerTimeoutMs`, the waiter re-reads the answer and reports
    `settled` or `lost`. The default is 2 min, set with `MOTOKO_WAKE_REGISTER_TIMEOUT_MS`.
  - `buildChildEnv` forwards `MOTOKO_PROCESS_TIMEOUT`, trimmed. Before this the extension never
    saw it.
  - `process_wall_ms` follows Go's duration grammar: `10.0s`, `0.5s`, `1s500ms`, `1m30s`, `us`,
    `ns`. Anything it still cannot parse is taken as a short 10 s wall.
  - `code_hint("timeout")` no longer promises a park. Only start, prompt and get failures reach
    it, and a failed Delegate opens no wait.
  - The DelegateCheck description ("call it as often as you like") and the motoko launch result
    now say to end the turn as well.
  - The 034 prompt says what the two new `lost` wakes mean.
- fix(herdr): a pending check re-opens its wait, and the parser cannot overflow
  - R2-1: a `lost` wake removed the wait while the delegate was still live. The check it asked
    for could find the delegate working again or `unknown`, and ending the turn then finished the
    run.
    - DelegateCheck's open results (still working, blocked, motoko not yet written) now carry the
      delegate's `wait` again. The core re-registers it, which changes nothing while it is open.
      This also re-opens a wait that a resumed run dropped.
    - The waiter counts only `idle` and `done` as quiet. `unknown` resets the clock, and a row
      with no `agent_status` is `host_error`.
    - 034's brief gains item 7: a delegate does not end its turn while its own background job
      runs. A check closes an idle pane with no answer file, and that kills the job.
  - R2-2: `1.` followed by 64 zeros and `s` is a value AILANG accepts, and it crashed
    registration with `RT001` because `pow10` wrapped to 0. Fractions now keep at most 9
    digits, each term is computed inside 64 bits, and sums saturate.
  - R2-3: `+`, `µs` and `μs` are parsed. A positive wall under 1 ms counts as 1 ms. Zero and
    negative values get the short 10 s wall. `check_wait_default` never returns 0.
  - R2-4: the timeout hint no longer says that nothing was delegated, because a prompt that
    timed out may still have been delivered (`DESIGN-prompt-retry.md`).
  - 034: the `timeout after …ms` bullet no longer says the delegate is still working.

13 files changed.

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
- After the review fixes, these passed again with the counts that changed: `types.ail` 308,
  `herdr.ail` 8, `progress_contract_guard.ail` 25, `verify_strict_context_limit` and the twelve
  targets above.
  - `bun test` passed 91: `wake-waiter`, `runtime-process.wake`, `herdr-child-env`,
    `proxy-child-env`, `session-identity`, `harness-dst`. Five of the new tests are the waiter's
    bounds and one is the forwarding.
  - `tsc --noEmit` and `git diff --check` passed.
- After the second review's fixes, these passed:
  - `types.ail`: 324 tests, including 28 duration cases.
  - `bun test` on the same six files: 93 tests.
  - `verify_herdr_delegate_wait`, with three new assertions that an open check carries its wait.
  - `verify_wait_descriptor_fixtures`, with a new `check_pending_reopens` row.
  - The other eleven herdr targets, `tsc --noEmit` and `git diff --check`.
  - `verify_herdr_gate`, run with `MOTOKO_PROCESS_TIMEOUT` set to the 64-zero value: exit 0, no
    `RT001`.
- Not run: the full `make check_core` and `make dst`. The W0 delegate's heavy runs were using the
  machine, and the plan runs heavy targets one at a time.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
