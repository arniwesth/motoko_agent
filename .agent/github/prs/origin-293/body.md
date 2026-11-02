---
repo: arniwesth/motoko_agent
pr: 293
branch: arniwesth/041-w2-setsid-probe
ticket: null
title: "test: D5's setsid and SIGKILL probe (041 W2)"
---

## Summary

Task `041/PLAN-001/W2`. `make verify_native_process_tree` now pins what the process wall does not contain, so an upstream change is seen rather than assumed: a `setsid` descendant with its pipes held, one with its pipes closed, and a command whose runtime takes a SIGKILL. `docs/configuration.md` states both limits for operators. Nothing model-facing changes, and `src/core` is untouched.

Criteria satisfied: ADR-002 D5's probe rows, and A20 (the enforced deadline and the return latency are separate rows).

**One finding on D5.** "The command survives" a SIGKILL is true but incomplete. Measured once on this host: a command that later writes to stdout dies of SIGPIPE at that write, because its pipes died with the runtime. Its next file write never happened. The operator note says so. The row pins survival only; the SIGPIPE edge is not pinned by a row.

## Changes

- test(process): pin setsid and SIGKILL survival (041 W2)
- test(process): mutation evidence for the setsid and SIGKILL rows (041 W2)

8 files changed.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md`, D5 and A20
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md`, W2 and E2
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

**Re-grounding.** No anchor had moved: `docs/configuration.md:60-62` still describes `tools.process_timeout`, and the recipe was at `Makefile:2667`. This PR moves these references, which name lines in code it changes: `Makefile:2671` (`PLAN-001:478`, the version pin) is now `Makefile:2674`; `Makefile:2673` (`ADR-002:184`, the probe's `--process-timeout`) is now `Makefile:2676`; `verify_native_process_tree.ail:38` (`ADR-002:456`, `PLAN-001:525`) is now `:101`. W2 does not edit the ADR or the plan.

**Overlap.** #234 and #209 change other `Makefile` recipes (`verify_native_path_guard`), with no shared hunk. #266 and #287 do not touch these paths.

## Predicted outcome

- `make check_core` takes about 7 s longer, because the probe goes from about 4 s to about 11 s. No gate changes colour on a host with `setsid`.
- A host without `setsid` prints two `NOT EVALUATED` lines and passes. The SIGKILL row still runs there, because it does not use `setsid`.
- If upstream sunholo-data/ailang#2037 lands, or #2034 also covers SIGKILL, the matching row goes red by design and that item updates it.
- No matrix row moves. `MATRIX.expected.tsv`, `tools/eval_protected/` and `scripts/eval/` are untouched, and `make eval_matrix` was not run because it is not in W2's gate set.

## Test evidence

| Command | Exit | Result |
|---|---|---|
| `env -u AILANG_FS_SANDBOX make check_core` | 0 | probe rows all OK, no `NOT EVALUATED`; `src/core/ type-check: 60 passed, 0 failed` |
| `make test` | 0 | `All core runtime module tests passed!` |
| `AILANG_FS_SANDBOX=$PWD make verify_native_process_tree` | 0 | no `FAIL`, no `NOT EVALUATED`; the recipe clears the sandbox |
| `cd src/tui && bun run test`, head | 1 | no difference from base: 4 suites fail to load, 469/469 tests pass |
| `cd src/tui && bun run test`, base `44a71589`, full tree | 1 | the same 4 suites: `compose-output-validator`, `compose_guard_semiformal`, `env-server`, `scratchpad/loopback` |

The bun gate is red on base and at head from a pre-existing environment failure, so it is reported as no difference, not as a pass.

Acceptance lines from the `check_core` log, Linux, no `NOT EVALUATED` line:

```
setsid pipes held: return_ms=3012 timeout_ms=3010 group_up=true group_late=false marker_at_return=true marker_after=true
setsid pipes closed: return_ms=1009 timeout_ms=1006 group_up=true group_late=false marker_at_return=false marker_after=true
SIGKILL: runtime_status=137 command_started=yes marker_at_kill=no marker_after=yes marker_ms_after_kill~1900
```

The `elapsed < 4000` row is unchanged. `elapsed` is taken before the window, which grew from 2500 to 3500 ms; mutant `e1` shows the row would go red if the window reached it.

Mutation: `evidence/W2/` holds `mutants.tsv`, `commit`, `mutate.sh` and the base probe log. 12 mutants, 12 killed, run at `c3b23412`, including `d1` per case and the stubbed exits. `g1` is the survival check: with `setsid` off `PATH`, two `NOT EVALUATED` lines and exit 0.

Not run or not observed:

- The `NOT EVALUATED` branch was observed only on Linux with `setsid` hidden from `PATH`. macOS was reasoned, not observed.
- The upper bound of limit + `WaitDelay` has no row, because the held descendant exits at 3 s. One one-off run with an 8 s descendant returned `Timeout(6017)`.
- G-core, G-dst and G-heavy are not W2's set. CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
