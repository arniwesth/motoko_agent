# Baseline after Phase 0, at `c8ca2521`, compared with `3ae506cc`

Measured on 2026-10-18 for `../../PLAN-001-effect-disclosure.md` W0.7, at the head of
`arniwesth/034-w0-effect-disclosure` after W0.6. The "before" is `../baseline-3ae506cc/` (W0.1).
`git merge-base HEAD origin/main` printed `3ae506cc` when this ran, so that baseline is still
the right "before".

## How it was run

As W0.1 ran, with W0.1's own script, from `../baseline-3ae506cc/`:

    REV=c8ca2521 WT=/workspaces/motoko_agent-034-w0 OUT=<scratch dir> ./run_baseline.sh

W0's worktree at `c8ca2521`: no tracked change, nothing untracked, on the warm compile cache
the branch's earlier tasks left. `make dst` at `-j8`, then `make eval_matrix --logs`, one after
the other, both under `env -u AILANG_FS_SANDBOX`, AILANG v0.52.5, 8 cores, uid 1001. No other
heavy run was going. `memory.current` was 4.4 to 4.8 GiB at the start and at the end. One
sample during `make dst` read 11.1 GiB.

| run | result | wall |
|---|---|---|
| `make dst` | exit 0; all targets pass; `dst-failed.txt` is empty | 852 s |
| `corpus_pr`, alone, inside that sweep | passes; 22,000 ms against a ceiling of 180,000 | |
| `make eval_matrix` | exit 2; 619 rows; the same 2 of 28 suites exit 1 | 309 s |

## The comparison

Run from `../baseline-3ae506cc/`, as its README says:

| check | result |
|---|---|
| `./compare_matrix.py . <after>` | `VERDICT: IDENTICAL`, exit 0. 28 and 28 suites, 619 and 619 rows, 0 on one side only, 0 suite exits differ, 0 observations differ, 0 join statuses differ |
| `diff dst-failed.txt <after>/dst-failed.txt` | no output, exit 0. Both empty |
| `diff` of `corpus_pr.wire.sha256` past its first line | no output, exit 0. The masked corpus output is byte-identical |
| `cmp suites.json`, `cmp join.tsv` | identical |
| `diff matrix.stdout.log` | 2 lines: the commit and logs path, and `Makefile:3527` → `:3529` in make's error line (W0.5 added two lines to `world_state`'s recipe) |

So every `eval_matrix` row is unchanged. This confirms the plan's inference that journals replay
recorded tool content verbatim (`src/eval/journal/world.ail:88-90`, `journal_tool` copies
`t.content`).

### The sweep log, line by line

`dst-log.diff` diffs the two full sweep logs (`dst.stdout.log`, not committed) after removing
colour codes, masking times, `/tmp` paths and timestamps, and sorting, because `-j8`
interleaves targets. It has 61 lines. Every line falls into one of these groups:

| difference | target | cause | expected? |
|---|---|---|---|
| a `fault_disclosure_witness` header, rows a to p `✓`, `fault_disclosure_witness PASS` and its summary line | `world_state` | W0.5's 16 rows | yes, *Expected differences* |
| `src/core: 72 .ail files discovered, 49 carry tests, 596 tests, 591 passed` → `73 …, 51 …, 624 tests, 619 passed`, still 5 skipped; new `✓ src/core/tool_fault.ail: 14/14` and `✓ src/core/tool_dispatch_adapter.ail: 14/14` | `test_coverage` | W0.2's 14 tests in the new `tool_fault.ail` and W0.3's 14 in `tool_dispatch_adapter.ail`: 596 + 28 = 624 | yes, *Expected differences* |
| `34 pin(s) across 568 tracked .ail file(s)` → `569`, twice | `profile_definition`, `driver_only` (`tools/profile_definition/check_fixtures.py`) | W0.2 added one tracked `.ail` file, `src/core/tool_fault.ail`. The check passes in both runs. Only the count of files it scanned changed | explained. Not a row: the check's verdict is the same |
| `source revision 3ae506cc…` → `c8ca2521…` | the sweep's revision lines | a different commit | noise |
| the wall time and load line, `corpus_pr`'s "WHOLE TARGET" cost (70,000 → 22,000 ms), `test_coverage`'s "slowest against the per-file cap" line | `make dst`, `corpus_pr`, `test_coverage` | a cold compile cache at the base and a warm one here. W0.1's warm rerun measured 18,000 ms | noise, all within the ceilings |
| the `inline_<n>` scratch file name in a compiler diagnostic | `compose_live_exec` | a time-based temp name | noise |

No DST target changed status, and no `eval_matrix` row changed. **The comparison has no
unexplained row.**

## The other gate targets

Run one at a time after the baseline, in the same worktree, as uid 1001. `env -u
AILANG_FS_SANDBOX` was not used for these three: the session's permission layer refused the
wrapper. They ran with the session's environment unchanged.

| command | exit | result |
|---|---|---|
| `make compose_live_exec` | 0 | `compose_live_exec PASS` |
| `make verify_native_path_guard` | 0 | every `OK:` line; its matcher (`scripts/verify_native_path_guard.ail:36`) still finds `"error":true` and "escapes workspace" |
| `cd src/tui && bun run test` | 1 | red, and red the same way at the base. See below |

### `bun run test`

`src/tui` is not changed by Phase 0 (`git diff 3ae506cc HEAD -- src/tui` is empty). The worktree had
no `node_modules`, so `bun install --frozen-lockfile` was run first, at the head and in a
temporary detached worktree at `3ae506cc` (since removed). `tui-test.txt` has the details.

| run | test suites | tests |
|---|---|---|
| base, two full runs | 5 failed, 44 passed | 460 passed, 0 failed |
| head, full run 1 | 6 failed, 43 passed | 2 failed, 458 passed |
| head, full runs 2 and 3 | 5 failed, 44 passed | 460 passed, 0 failed |

The 5 suites red in every run are the same at the base and at the head. They fail to load, which is
environmental and not a test assertion. `compose-output-validator`, `compose_guard_semiformal`,
`env-server` and `scratchpad/loopback` stop on `depd`'s `callSite.getFileName is not a function`
under bun's jest. `test/path-guard` stops on a jest worker that exits with code 0.

Head run 1 also failed 2 tests in `src/runtime-process.wake.test.ts`. One of them reads `append of
park failed: ENOENT … /tmp/wake-protocol-*/.motoko/sessions/sess-p4/journal.jsonl`. That suite
passed 27 of 27 in three runs alone at the head, in three alone at the base, and in head full runs
2 and 3. The cause is a timing flake in that suite under the full run's load, not this tree. It is
recorded here and was not fixed.

## Files

| file | what |
|---|---|
| `dst-failed.txt`, `dst-summary.txt`, `corpus_pr.wire.sha256` | as in `../baseline-3ae506cc/` |
| `MATRIX.tsv`, `suites.json`, `join.tsv`, `matrix.stdout.log` | as in `../baseline-3ae506cc/` |
| `meta.txt` | timings, revision, toolchain, load and `memory.current` |
| `dst-log.diff` | the normalised, sorted diff of the two full sweep logs described above |
| `tui-test.txt` | the failing suites and the counts from every `bun run test` run, and the flake's error |

The full sweep and matrix logs are not committed, as at the base. The script and the compare
script are `../baseline-3ae506cc/run_baseline.sh` and `compare_matrix.py`, unchanged.
