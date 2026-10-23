# Phase 2 baseline at `0e09e09d`, compared with W1's `24d347d2`

Measured on 2026-10-20 for `../../PLAN-001-effect-disclosure.md` W2.4. `0e09e09d` is the head of
`arniwesth/034-w2-properties` after W2.3. W2 is stacked on W1 (`4d1e8e48`, #280, not yet
merged), so `git merge-base HEAD origin/main` is still `a94204aa`. The "before" is W1.8's
baseline, `../baseline-w1-after-24d347d2/`. W1's commits after `24d347d2`, up to `4d1e8e48`,
change only `.agent/`, so that baseline is W2's base.

**Result: the gate is green.** Every gate-1 target passes. `make dst` fails no target, the same
as the base. `make eval_matrix` is identical to the base, row for row: 0 rows changed, so there
is no row to explain. Every line of the sweep log that differs is W2's own output.

## How it was run

In W2's worktree at `0e09e09d`, with no tracked and no untracked change. The compile cache was
warm. One `make` at a time, all under `env -u AILANG_FS_SANDBOX`, AILANG v0.52.5, 8 cores,
uid 1001. No other heavy run was going on; a long-lived interactive Motoko session was idle on the
host. `meta.txt` holds the timings, load and `memory.current`.

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core invariants corpus_judge verify_classify_check new_contract_policy` | 0 | 228 s | `src/core/ type-check: 60 passed, 0 failed`; `invariants_dst PASS` (`invariant-set/3`, `all 44 Violation constructors sampled by name`); `✓ corpus_judge: 18 members, …`; `Ran 18 tests … OK`; `verify_classify: 69 contracts, register agrees (64 substantive, 2 tautology, 0 spec-equals-body, 3 unclassified)`; `new_contract_policy: 78 in-scope new pure func declarations, all justified; 59 more out of scope, …` |
| `make applied_twin` (the P2 pair runner) | 0 | 72 s | `applied_twin PASS`; `P2 held on 13 of 13 twin pair(s) over 18 program(s) (8 flipped to applied, 5 to not applied); 6 of 6 controls red on their own rule` |
| `REV=0e09e09d WT=<this worktree> ../baseline-3ae506cc/run_baseline.sh` → `make dst` | 0 | 1336 s | `1336s wall, -j8, load 5.58 7.72 8.24` … `all targets passed` |
| the same script → `make eval_matrix --logs` | 2, as at the base | 371 s | `make: *** [Makefile:3593: eval_matrix] Error 1`. The base's 2 suites exit 1: `tools/eval_protected/selftest.py` and `scripts/eval/test_candidate.py` |

`gate1.txt` holds gate 1's result lines; the whole log carries no `✗`. `check_core`'s sub-target
`verify_native_path_guard` passed on this run. `make dst` took 334 s longer than at the base;
`memory.current` reached 10.1 GiB during it, against 4.7 to 5.3 GiB at the base. No ceiling was
crossed (`corpus_pr`: `WHOLE TARGET: 73000 ms against a declared ceiling of 180000 ms`).

Against W1's gate, `verify_classify` grew from 62 contracts (59 substantive, 1 unclassified) to
69 (64, 3), and `new_contract_policy` from 43 in-scope declarations to 78. Both are W2.1's and
W2.2's new functions and their `contracts.register` rows, and both checks pass.

## `make dst`

| check | result |
|---|---|
| `diff ../baseline-w1-after-24d347d2/dst-failed.txt dst-failed.txt` | no output, exit 0. Both empty: **no failed target on either side** |
| `corpus_pr.wire.sha256` | identical past its first line (the revision). W2 does not change the wire: 1907 lines, 1621 JSON lines, the same two hashes |
| `dst-summary.txt` | identical but for the revision and the wall/load line |

### The sweep log, line by line

`dst-log.diff` is the complete diff of the base's full sweep log (`.ailang/dst-last.log` at
`24d347d2`) and this run's, each normalised by `../baseline-w1-after-24d347d2/norm_sweep.sh` and
sorted, with group counts from `../baseline-w1-after-24d347d2/classify.py`. It is 171 lines: 105
changed lines, 2 of them blank. Every one falls into a group below.

| difference | target | cause | expected? |
|---|---|---|---|
| 43 added `✓ seed-N …` lines (the `corpus-bank` group): 17 seeds' "the base program run twice is clean against itself" and 13 pairs × 2 rows, 8 "(not → applied)" and 5 "(applied → not)"; in `other`, the constructed member's clean row, the `applied_twin` header, `COUNT`, `PASS` and summary lines, and 7 control lines (6 controls and the discovery-contract note) | `applied_twin` | W2.2: the P2 pair runner, in `DST_TARGETS` | yes |
| `invariant-set/2` → `/3` (2 lines); `all 42 Violation constructors` → `all 44`; `dst_invariants.ail: 16/16 passed` → `23/23`; the P1/P3 conversation, 10 `mutant:` rows and 9 `absent:`/`survives:` rows | `invariants`, `corpus_judge` | W2.1: P1 `EffectDisclosureUnsound` and P3 `ToolCallRedispatched` as rules | yes |
| `test_coverage`: 710 tests, 697 passed → 717, 704 (13 skipped, unchanged) | `test_coverage` | W2.1's 7 new inline tests in `dst_invariants.ail` | yes |
| `34 pin(s) across 571 tracked .ail file(s)` → `573` | `profile_definition`, `driver_only` | W2.2's `scripts/dst/applied_twin_dst.ail` and W2.3's `evidence/acceptance-w2-8c996274/p1p3_reach.ail`. The check passes | explained |
| `source revision`, the `inline_<n>` temp name, `WHOLE TARGET` (20,000 → 73,000 ms), the `slowest against the per-file cap` line | the sweep, `compose_live_exec`, `corpus_pr`, `test_coverage` | a different commit, a time-based name, load | noise, within ceilings |

No line of W1's sweep was removed except those replaced above, and no corpus bank row
(`CORPUSROW`, `JUDGE`, `JUDGEROW`) changed. No DST target changed status.

## `make eval_matrix`

| check | result |
|---|---|
| `compare_matrix.py ../baseline-w1-after-24d347d2 <this run>` (`compare-vs-w1-24d347d2.txt`) | **`VERDICT: IDENTICAL`**. 28 and 28 suites, 619 and 619 rows, 0 on one side only, 0 suite exits differ, 0 observations differ, 0 join statuses differ |
| `MATRIX.tsv` | identical to the base's but for the `commit` column (`24d347d2…` → `0e09e09d…`) |
| `suites.json`, `join.tsv` | byte-identical to the base's |
| `matrix.stdout.log` | identical but for the revision, the logs path and the Makefile line of `eval_matrix` (3540 → 3593, W2.2's Makefile edits) |

This is what W2's file set predicts. W2 changes `Makefile`, `scripts/dst/applied_twin_dst.ail`,
`scripts/dst/invariants_dst.ail`, `src/core/dst_invariants.ail` and
`tools/verify_classify/contracts.register`. None is a protected file of `manifest-A`. `protected-check.txt` runs `tools/eval_protected/protected.py check`
against `manifest-A` at this tree: 12 findings, first `dst_fault_catalogue.ail <imports:1>`, the
same bytes as the `24d347d2` section of `../baseline-w1-after-24d347d2/protected-check.txt`. W1's 5
changed rows therefore stay as W1 left them (pass → fail under Option A), and the evaluator pull
request after W1 merges still owns them.

## Not done

- The worktree's `.ailang/` compile cache predates this task (earlier W2 tasks created it) and is
  gitignored. It was left in place.
- `make eval_matrix` writes `src/eval/journal/testdata/MATRIX.tsv` into the tree, untracked, as at
  the base. It is copied here and removed from the tree.

## Files

| file | what |
|---|---|
| `dst-failed.txt`, `dst-summary.txt`, `corpus_pr.wire.sha256` | as in `../baseline-w1-after-24d347d2/` |
| `MATRIX.tsv`, `suites.json`, `join.tsv`, `matrix.stdout.log` | this run's `make eval_matrix` |
| `compare-vs-w1-24d347d2.txt` | `compare_matrix.py`'s output against W1's baseline |
| `dst-log.diff` | the complete normalised sweep-log diff against W1's, with group counts |
| `protected-check.txt` | `protected.py check` against `manifest-A` at `0e09e09d` |
| `gate1.txt` | gate 1's result lines, with their line numbers in the full log |
| `meta.txt` | timings, revision, toolchain, load, `memory.current`, uid, merge base |

The full sweep, gate and matrix logs are not committed, as at the base. The baseline and compare
scripts are `../baseline-3ae506cc/run_baseline.sh` and `compare_matrix.py`, the normaliser and
grouping are `../baseline-w1-after-24d347d2/norm_sweep.sh` and `classify.py`, all unchanged.
