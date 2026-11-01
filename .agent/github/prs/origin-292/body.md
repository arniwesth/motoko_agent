---
repo: arniwesth/motoko_agent
pr: 292
branch: arniwesth/041-w1-r6-admission
ticket: null
title: "test: the R6 admission test (041 W1)"
---

## Summary

Task `041/PLAN-001/W1`, the test ruling R6 depends on (ADR-002 A14d, first half). A generated fixture, `fxw_r6_post_change_limits`, holds a clamped call, an invalid `timeout_secs: 0` and a non-numeric `"soon"`. It admits on today's code and replays from `world_state_of(program)` with `report_ok` and zero `strict_replay_findings`. Recorded tool content is served unchanged, and a control with altered content is seen. **R6's admission test passes, so R6 holds at this stage.** The fixture is synthetic: W5 tightens the test to `process_limits == Legacy` and W13 repeats it with a real session.

"Admits as `Legacy`" here means "admits under today's code", which is Legacy throughout. No `process_limits` field or `Legacy` value is added, because that is W5's work.

## Changes

- test(journal): admit a post-change journal under R6 (041 W1)
- test(journal): assert admission serves R6 results as completions (041 W1)
- docs(041): record W1's mutation evidence (041 W1)
- docs(041): add W1's mutation script and re-run the table (041 W1)

12 files changed. No change to `src/core/**`, `MATRIX.expected.tsv`, `tools/eval_protected/` or `scripts/eval/`.

## Governing docs

- `.agent/projects/041_process_execution_timeouts/ADR-002-per-call-process-timeouts.md` (R6, D7, A14d)
- `.agent/projects/041_process_execution_timeouts/PLAN-001-implement-adr-002.md` (W1, R11)
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`

## Predicted outcome

Landing this adds four checks to `admission_live_test.ail` and raises three fixture-count pins by one (`world.ail`, `stopping.ail`, `admission.ail`). It should move no matrix row, and none moved against `origin/main`. W2-W4 can start once this is accepted.

**Basis change, not re-pinned (R11).** `make eval_matrix` reads its rows from `MATRIX.expected.tsv`, so it runs the new checks but does not report them as unlisted and gives them no rows. A failing r6 check still exits the suite non-zero, which turns the file's 15 listed rows red. These rows are for the operator's regeneration:

```
R6.post_change.admits	src/eval/journal/admission_live_test.ail:r6_post_change_admits	pass	-	call:3
R6.post_change.replays_strict	src/eval/journal/admission_live_test.ail:r6_post_change_replays_strict	pass	-	call:3
R6.post_change.content_served	src/eval/journal/admission_live_test.ail:r6_post_change_content_served	pass	-	call:3
R6.post_change.altered_content_seen	src/eval/journal/admission_live_test.ail:r6_post_change_altered_content_seen	pass	-	call:3
```

The case ids and the position are proposed by this pull request.

**Re-grounding.** `src`, `packages`, `scripts`, `tools` and the `Makefile` are byte-identical between `e3293ede` and base `44a71589`, as the brief reports. Line references that moved:

- D7's `execution-program/5` pin moved from `admission_live_test.ail:127` to `:148`, because the new imports and check sit above it. The pin stays `5`.
- `journal_tool` is still at `world.ail:88`.

## Test evidence

Run at `f8eba573` (source identical to `7d01fcfb`) unless stated. Base is `origin/main` `44a71589`, run in a temporary detached worktree that has since been removed.

| Gate | Exit | Result |
|---|---|---|
| `env -u AILANG_FS_SANDBOX make check_core` | 0 | `src/core/ type-check: 60 passed, 0 failed` |
| `make test` | 0 | `All core runtime module tests passed!` |
| `cd src/tui && bun run test` | **1, same at base** | 4 suites fail to load, 469 of 469 tests pass; details below |
| admission check (header command, at `28693e76`) | 0 | `admission_live_test: all checks passed` |
| `ailang test` on `world.ail`, `stopping.ail`, `admission.ail` | 0 | the three raised pins; also run inside the matrix |
| `gen_fixtures.py` regenerated | 0 | no tree change: the fixtures come from the generator |
| `make eval_matrix` | **2, same at base** | no difference from base; details below |

```
PASS r6_post_change_admits
PASS r6_post_change_replays_strict
PASS r6_post_change_content_served
PASS r6_post_change_altered_content_seen
```

**TUI failures.** `compose-output-validator`, `compose_guard_semiformal`, `env-server` and `scratchpad/loopback` fail on both sides with `TypeError: callSite.getFileName is not a function` from `depd`, loaded through `express`, under bun 1.4.4. These four suites did not run on either side. This pull request does not touch `src/tui`.

**Matrix comparison, head against base.**

```
eval_matrix: 619 rows: credited=418, equal=124, failed=33, inapplicable=11, missing=33   (both)
eval_matrix: suites 28, non-zero exit: scripts/eval/test_candidate.py=1, tools/eval_protected/selftest.py=1   (both)
```

Rows (`case_id` to `observed_position`), join statuses, suite exit codes and `test_candidate.py` FAILED names are all identical. 66 rows are red on both sides, in the two suites that R11 leaves red. `test_candidate.py` is refused with `ProtectedRegionTouched(changed:<imports:1>) src/core/dst_fault_catalogue.ail`, and `selftest.py` stops at `parser cross-check FAILED`. Those 66 rows cannot show a change from this pull request, because they are red with or without it. The run took about 4-5 minutes, not the 14 last measured.

**Mutants.** Each diff was applied alone and the tree was clean afterwards. Table: `evidence/W1/mutants.tsv`; runner: `mutate.sh`.

| Mutant | Commit | Expected test | Red | Verdict |
|---|---|---|---|---|
| t1, drop limit fields from content | `28693e76` | `r6_post_change_content_served` | that test only | killed |
| t2, refuse `timeout_secs` of `0` | `28693e76` | `r6_post_change_admits` | that test, plus `content_served` and `altered_content_seen` | killed |

With the check as it stood at `f3ace72e`, t1 was already killed. t2 survived its named test (`admits` passed, with `content_served` and `altered_content_seen` red), which is why `7d01fcfb` strengthened the check.

**Not run:** `make dst`, G-core and G-dst, because there is no `src/core` change and they are not W1's gate set. CI was not waited for.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
