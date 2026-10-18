# Baseline after the #277 review follow-up, at `2ac0ff88`, compared with `3ae506cc`

Measured on 2026-10-18 for `../../PLAN-001-effect-disclosure.md` W0.7, re-run because the #277
review follow-up changed W0's surface. `2ac0ff88` is the head of
`arniwesth/034-w0-effect-disclosure` after the follow-up. It holds `a490a8b9` (contracts on
`tool_fault.ail`'s pure funcs), `d3047dd1` (the review's three fixes and W0.5 rows q, r and s) and
`2ac0ff88` (the mutation follow-up, evidence only). The "before" is still `../baseline-3ae506cc/`
(W0.1): `git merge-base HEAD origin/main` is `3ae506cc`. The first "after",
`../baseline-after-c8ca2521/`, stays as it was, and the diff against it is recorded here too.

## How it was run

As W0.1 ran, with W0.1's own script, from `../baseline-3ae506cc/`:

    REV=2ac0ff88 WT=/workspaces/motoko_agent-034-w0 OUT=<scratch dir> ./run_baseline.sh

W0's worktree at `2ac0ff88`: no tracked change, nothing untracked, warm compile cache. `make dst`
at `-j8`, then `make eval_matrix --logs`, one after the other, both under
`env -u AILANG_FS_SANDBOX`, AILANG v0.52.5, 8 cores, uid 1001. No other heavy run of this
session was going. Other sessions on the host were busy: the load average read 17.6 at the end of
`make dst`, against 8.6 at the base, and `memory.current` read 5.0 GiB at the start, 13.3 GiB
once during `make dst` and 7.0 GiB at the end.

| run | result | wall |
|---|---|---|
| `make dst` | exit 0; all targets pass; `dst-failed.txt` is empty | 1508 s |
| `corpus_pr`, alone, inside that sweep | passes; 20,000 ms against a ceiling of 180,000 | |
| `make eval_matrix`, run 1 (the script's) | exit 2; 619 rows; 3 of 28 suites exit 1: the base's 2 and `scripts/eval/test_mem_guard.py` | 321 s |
| `make eval_matrix`, run 2 (alone, right after) | exit 2; 619 rows; the base's 2 of 28 suites exit 1 | 202 s |

## The comparison

Run from `../baseline-3ae506cc/`, as its README says:

| check | result |
|---|---|
| `./compare_matrix.py . <run 1>` | `VERDICT: DIFFERS`, exit 1. 619 and 619 rows, 0 on one side only, **0 observations differ**, 0 join statuses differ. 1 suite exit differs: `scripts/eval/test_mem_guard.py`, 0 → 1 |
| `./compare_matrix.py . <run 2>` (`matrix-rerun/`) | `VERDICT: IDENTICAL`, exit 0. 28 and 28 suites, 619 and 619 rows, nothing differs |
| `cmp suites.json`, `cmp join.tsv` | run 2: both identical. Run 1: `join.tsv` identical, `suites.json` differs at that one exit |
| `cmp` of the two runs' `MATRIX.tsv` | identical |
| `diff dst-failed.txt <after>/dst-failed.txt` | no output, exit 0. Both empty |
| `diff` of `corpus_pr.wire.sha256` past its first line | no output, exit 0. The masked corpus output is byte-identical |

So every `eval_matrix` row is unchanged, as at `c8ca2521`.

### Run 1's `test_mem_guard.py`

One test of 55 failed in run 1: `test_verify_accepts_a_clean_pass_via_cli`. The guard's `--verify`
rejected a clean `true` run as `monitor_gap` (`test_mem_guard.run1.log`). A gap is a memory sample
that arrived more than twice its interval after the previous one (`scripts/eval/mem_guard.py:92`),
which is the sampler thread being scheduled late. During run 1 the one-minute load average fell
from 17.6 to 4.6. `scripts/eval/` and `src/eval/` are unchanged since `3ae506cc` (`git diff --stat
3ae506cc HEAD -- scripts/eval src/eval` is empty). The suite passed 55 of 55 in three runs alone
at the head, at a load average of about 4, and in run 2. It is recorded as a load flake in that
test, not a change made by this branch.

### The sweep log, line by line

`dst-log.diff` diffs the base's full sweep log with this one, normalised as for `c8ca2521`: colour
codes removed, glued durations (`852s`, `12.3ms`), `/tmp` paths and ISO timestamps masked, lines
sorted, because `-j8` interleaves targets. The same normaliser run on the base and `c8ca2521` logs
reproduces `../baseline-after-c8ca2521/dst-log.diff` byte for byte. Here it has 68 lines.
`dst-log-vs-c8ca2521.diff` is the same diff against the first "after" and has 42. Every line of
both falls into one of these groups:

| difference | target | cause | expected? |
|---|---|---|---|
| a `fault_disclosure_witness` header, rows a to s `✓`, `fault_disclosure_witness PASS` and its summary line. Against `c8ca2521`: rows q, r, s only | `world_state` | W0.5's 16 rows, and the follow-up's 3 | yes |
| `596 tests, 591 passed, 5 skipped` → `657 tests, 644 passed, 13 skipped` (against `c8ca2521`: from 624, 619, 5). `tool_fault.ail` 36/43 (7 skipped), `tool_dispatch_adapter.ail` 15/15, `tool_runtime.ail` 16/18 → 18/21 (3 skipped) | `test_coverage` | `a490a8b9`: 29 contract properties on `tool_fault.ail`, 7 of them over an ADT parameter with no generator. `d3047dd1`: the adapter's `t_long_unknown_tool_keeps_fault`, `tool_runtime`'s `t_search_argv_reads_only`, and `echoed_tool_name`'s 2 contract properties, 1 skipped as out of contract. 624 + 29 + 1 + 3 = 657. Every skip is against the record | yes |
| `34 pin(s) across 568 tracked .ail file(s)` → `569`, twice. Not against `c8ca2521` | `profile_definition`, `driver_only` | W0.2's `src/core/tool_fault.ail`, as at `c8ca2521`. The check passes | explained |
| `source revision 3ae506cc…` → `2ac0ff88…` | the sweep's revision lines | a different commit | noise |
| the wall time and load line, `corpus_pr`'s "WHOLE TARGET" cost (70,000 → 20,000 ms; 22,000 at `c8ca2521`), `test_coverage`'s "slowest against the per-file cap" line | `make dst`, `corpus_pr`, `test_coverage` | the base's cold compile cache, and this run's load | noise, all within the ceilings |
| the `inline_<n>` scratch file name in a compiler diagnostic | `compose_live_exec` | a time-based temp name | noise |

No DST target changed status, and no `eval_matrix` row changed. **The comparison has no
unexplained row.**

## The other gate targets

Run one at a time after the baseline, in the same worktree, as uid 1001:

| command | exit | result |
|---|---|---|
| `make check_core verify_core verify_mutations test_coverage verify_classify_check new_contract_policy` | 0 | `src/core/ type-check: 60 passed, 0 failed`; `verify_core: 46 contracts proven, 0 unstated, 1 blocked; 0 files failed`; `verify_mutations: 5 falsified, 0 unfalsified`; `test_coverage: … 644 of 657 passed, 13 skipped against a record`; `verify_classify: 47 contracts, register agrees (44 substantive, …)`; `new_contract_policy: 30 in-scope new pure func declarations, all justified` |
| `env -u AILANG_FS_SANDBOX make world_state` | 0 | `fault_disclosure_witness PASS`, rows a to s, no `NOT EVALUATED` line |
| `make compose_live_exec` | 0 | `compose_live_exec PASS` |
| `make verify_native_path_guard` | 0 | every `OK:` line |

`cd src/tui && bun run test` was not run again: `src/tui` is unchanged since `3ae506cc`, and
`../baseline-after-c8ca2521/tui-test.txt` holds its runs.

## Files

| file | what |
|---|---|
| `dst-failed.txt`, `dst-summary.txt`, `corpus_pr.wire.sha256` | as in `../baseline-3ae506cc/` |
| `MATRIX.tsv`, `suites.json`, `join.tsv`, `matrix.stdout.log` | run 1, as in `../baseline-3ae506cc/` |
| `matrix-rerun/` | run 2's `suites.json`, `join.tsv`, `matrix.stdout.log` and `meta.txt`. Its `MATRIX.tsv` is identical to run 1's |
| `test_mem_guard.run1.log` | run 1's log of the suite that failed |
| `meta.txt` | timings, revision, toolchain, load and `memory.current` |
| `dst-log.diff`, `dst-log-vs-c8ca2521.diff` | the normalised, sorted diffs of the full sweep logs described above |

The full sweep and matrix logs are not committed, as at the base. The script and the compare
script are `../baseline-3ae506cc/run_baseline.sh` and `compare_matrix.py`, unchanged.
