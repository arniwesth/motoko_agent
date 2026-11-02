---
repo: arniwesth/motoko_agent
pr: 294
branch: arniwesth/041-w3-cancel-witness
ticket: null
title: "test: the cancellation witness, expected to fail (041 W3)"
---

## Summary

This is `041/PLAN-001/W3`. It records sunholo-data/ailang#2034 as a witness and fixes nothing: cancelling a run kills the runtime, but a native `BashExec` command and its ordinary descendant keep running and write their markers after the limit has passed.

**No ADR criterion is satisfied by this PR.** A22 says a recorded failure alone does not satisfy it, and W9 owns A22.

- `src/tui/src/runtime-process.cancel.test.ts` is ADR-002 D6's experiment: a real `RuntimeProcess`, the real `interruptRuntime`, and a native `BashExec` dispatched from a model step by the real supervisor. Only the provider is local, a loopback SSE endpoint. The two `it.failing` rows carry the witness; an ordinary row says the experiment really ran, because `it.failing` accepts any failure.
- `scripts/verify_runtime_cancel_process_tree.sh` is the runtime-level reproduction for SIGTERM and SIGINT, with a no-signal control. It uses plain `std/process.exec` and no Motoko code. It exits 1 today and is not wired into `check_core` until W9.

## Changes

- test(tui): witness the post-cancel survivor, expected to fail (041 W3)
- docs(041): record W3's mutation evidence (041 W3)

6 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`: D6, R10
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`: W3, A22
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

No production behaviour changes, and no matrix row moves: this PR touches no `src/core`, `MATRIX.expected.tsv`, `tools/eval_protected/` or `scripts/eval/`.

The TUI suite gains one passing file while #2034 stands. When the behaviour changes, the two witness rows turn red and W9 removes `.failing`. The twin then moves from exit 1 to exit 0, and W9 wires it into `check_core`.

**The witness only speaks when someone runs it.** No CI job runs the TUI's Jest suite (`Makefile:3309`) and the twin is not wired yet, so a fixed upstream will not turn CI red by itself. The file needs `ailang` on PATH.

## Test evidence

Run as a non-root user (`id -u` prints 1001), with markers in `mkdtemp` directories.

| Gate | Exit | Result |
|---|---|---|
| `cd src/tui && bun run test`, base `44a71589` | 1 | `Test Suites: 4 failed, 44 passed, 48 total`; `Tests: 469 passed, 469 total` |
| `cd src/tui && bun run test`, head | 1 | `Test Suites: 4 failed, 45 passed, 49 total`; `Tests: 472 passed, 472 total` |
| `env -u AILANG_FS_SANDBOX make check_core` | 0 | `src/core/ type-check: 60 passed, 0 failed` |
| `env -u AILANG_FS_SANDBOX make test` | 0 | `All core runtime module tests passed!` |

The TUI gate exits 1 on both sides, for a reason that predates this PR. The same four suites do not run on either side (`compose-output-validator`, `compose_guard_semiformal`, `env-server`, `src/scratchpad/loopback`: `callSite.getFileName is not a function` under bun 1.4.4). The difference is the new file: one more suite, three more tests.

**The marker.** `it.failing`, from `@jest/globals`. Jest and jest-circus are 29.7.0, and `src/tui/package.json:9` runs Jest under bun. `jest-circus/build/index.js:216` defines it and `run.js:320-335` inverts the result. It was also confirmed by running: the rows pass today and go red under c1.

**Mutants** (`.agent/projects/041_process_execution_timeouts/evidence/W3/`, run at `1669bf4d`). Nine of nine behaved as predicted. `c1` ends the expected failure: with both marker writes removed, both witness rows go red with "Failing test passed even though it was supposed to fail", and the ordinary row stays green. The rest:

- `c1.command` and `c1.descendant` end only their own row.
- `f1` stops the tree from the test (no change to `runtime-process.ts`) and ends both rows.
- `h1` (no signal), `h2` (no experiment) and `h3` (no runtime) turn the ordinary row red as well.
- `t1` takes the twin to exit 0, and `t2` to exit 2.

**The twin, at head:**

```
control (no signal): runtime_status=0 command_started=yes command_marker=no descendant_marker=no
SIGTERM: runtime_status=143 command_started=yes marker_at_signal=no command_marker=yes descendant_marker=yes looked_for_ms~1900
SIGINT: runtime_status=130 command_started=yes marker_at_signal=no command_marker=yes descendant_marker=yes looked_for_ms~1800
REPRODUCED: sunholo-data/ailang#2034 on AILANG v0.54.14
```

**Re-grounding.** No anchor moved: `rp.kill()` is at `src/tui/src/runtime-process.ts:212` and `kill()` at `:1149`, as D6 states.

**Findings.**

- Under this runner, a witness row that stops failing prints a red row with an empty body. The sentence appears only in `--json`'s `failureDetails`. The test's header comment says so.
- The witness uses a 3 s limit and a 4 s marker, where D6's experiment used 1 s and 2 s, so a loaded machine cannot let the deadline fire before the signal. The ordinary row checks that the signal landed inside the limit. The twin keeps 1 s and 2 s.

**Not run.** G-core, G-dst and G-heavy are not this item's set, since it changes no `src/core`. No keypress in a full TUI session was exercised: like D6's experiment, this calls the helper. SIGKILL is not covered here (R10 keeps it disclosed). CI was not awaited, and this PR was not merged.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
