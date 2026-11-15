---
repo: arniwesth/motoko_agent
pr: 331
branch: fix/test-coverage-cap-fixture
ticket: null
title: "fix(test_coverage): the cap fixture outruns AILANG v0.60.4"
---

## Summary

Since the AILANG v0.60.4 pin (#328) merged, `verify-extensions` has failed on main twice, and on
#330, in the job `test_coverage + smoke_parity`: "a file over the per-file cap fires unrunnable:
expected ['unrunnable'], got []". The row runs `tools/test_coverage/timeout_fixtures/slow.ail`
under a 5 s cap and expects the timeout to fire. Its naive `fib(30)` took about 25 s on v0.54.14.
v0.60.4 runs it in 5.5 s on the dev box, and inside the cap on CI's runners. This raises the
fixture to `fib(35)`.

## Changes

- fix(test_coverage): the cap fixture outruns AILANG v0.60.4

2 files changed.

`slow.ail` computes `fib(35)`, and its header and the self-test's comment in `derive.py` give the
new timing. The survivor, `quick.ail` at `fib(15)`, is unchanged.

## Governing docs

None beyond the comments themselves: LEG-CI-COVERAGE-CAP, as the fixture and `derive.py` name it.

## Predicted outcome

`test_coverage_selftest` passes on CI again, and so does the `test_coverage + smoke_parity` job, on
main and on #330 once it includes this.

## Test evidence

AILANG v0.60.4, dev box (linux arm64):

| | `fib(30)` (main) | `fib(35)` (this PR) |
|---|---|---|
| `ailang test --format json slow.ail`, uncapped | 5.5 s, twice | 78 s |
| Margin over the 5 s cap | 1.1x | 15x |

- `make test_coverage_selftest`: 0 failures. "the capped file was killed at the cap (5s), not
  waited for", and the survivor row passes.
- `make test_coverage`: 997 of 1010 passed, 13 skipped against a record. `slow.ail` is outside
  `fixtures/` and the `src/core` walk, so the full run does not run it.

Failing runs on main: `43734083934` (after #328) and `43737828844` (after #329). On #330:
`43744133914`.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
