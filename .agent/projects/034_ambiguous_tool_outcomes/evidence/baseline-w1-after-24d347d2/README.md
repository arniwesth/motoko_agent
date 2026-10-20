# Phase 1 baseline at `24d347d2`, compared with W0's `2ac0ff88`

Measured on 2026-10-20 for `../../PLAN-001-effect-disclosure.md` W1.8. `24d347d2` is the head of
`arniwesth/034-w1-world-and-catalogue` after W1.7 and the `pinned_canary_v3` contract fix.
`git merge-base HEAD origin/main` is `a94204aa`. The "before" is W0.7's final baseline,
`../baseline-after-2ac0ff88/`, and `../baseline-3ae506cc/` (W0.1) is compared as well.

**Result: the gate is green, and every changed row is on W1.1's list.** `make dst` fails no
target, the same as the base. `make eval_matrix` changes 5 rows, all 5 predicted. The other 11
predicted rows did not visibly change. That is because of one change W1.1 §5 anticipated but did
not measure: W1.5 added an import to `dst_fault_catalogue.ail`. Its cause is under *The finding*
below.

The first attempt, at `9405d738`, stopped at gate 1 on `new_contract_policy`. `24d347d2` fixed
that. This run starts again from gate 1.

## How it was run

In W1's worktree at `24d347d2`, with no tracked change. The only untracked path was the first
attempt's directory, `../baseline-w1-after-9405d738/`, which is not committed. The compile cache
was warm. One `make` at a time, all under `env -u AILANG_FS_SANDBOX`, AILANG v0.52.5, 8 cores,
uid 1001 (`id -u` → `1001`). No other heavy run was going on. The load average read 1.5 to 10.5,
and `memory.current` 4.7 to 5.3 GiB. `meta.txt` holds the timings.

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core test_coverage seeded_generator fault_catalogue corpus_pr run_report world_state invariants anchors attribution_table` | 0 | 397 s | `src/core/ type-check: 60 passed, 0 failed`; `test_coverage: … 697 of 710 passed, 13 skipped against a record`; `seeded generator: all axes green`; `fault_catalogue_dst PASS`; `corpus_pr`: `the guard read 62 tool-role message(s) across 18 member trace(s)`, `WHOLE TARGET: 74000 ms against a declared ceiling of 180000 ms`; `run_report_dst PASS`; `world_state_probe PASS`, `exit_code_witness PASS`, `fault_disclosure_witness PASS`; `invariants_dst PASS`; anchors all `✓`; `attribution_table_dst PASS` |
| `make new_contract_policy verify_classify_check` | 0 | 49 s | `new_contract_policy: 43 in-scope new pure func declarations, all justified; 59 more out of scope, reachable only from a tests block`; `Ran 18 tests … OK`; `verify_classify: 62 contracts, register agrees (59 substantive, 2 tautology, 0 spec-equals-body, 1 unclassified)` |
| `REV=24d347d2 WT=<this worktree> ../baseline-3ae506cc/run_baseline.sh` → `make dst` | 0 | 1002 s | `1002s wall, -j8, load 8.05 10.54 7.50` … `all targets passed` |
| the same script → `make eval_matrix --logs` | 2, as at the base | 371 s | `make: *** [Makefile:3540: eval_matrix] Error 1`. The base's 2 suites exit 1: `tools/eval_protected/selftest.py` and `scripts/eval/test_candidate.py` |

Every `ailang` call prints `Warning: dependency sunholo/motoko_ext_herdr content changed`. #278
changed `packages/motoko-ext-herdr/` on `main` (`2ac0ff88..a94204aa`). W1 does not touch it
(`git diff a94204aa HEAD -- packages` is empty). The warning changes no exit status.

## `make dst`

| check | result |
|---|---|
| `diff ../baseline-after-2ac0ff88/dst-failed.txt dst-failed.txt` | no output, exit 0. Both empty: **no failed target on either side** |
| `corpus_pr.wire.sha256` past its first line | differs, as expected: 1847 → 1907 lines, 1591 → 1621 JSON lines. W1.6 re-derived the bank (17 seeds and the constructed member, against 15 and 1), and W1.4 puts `fault` on the typed wire |

### The sweep log, line by line

`dst-log.diff` compares the base's full sweep log with this one. Both are normalised by W0.7's
`norm_sweep.sh` (copied here) and sorted. `classify.py` (also here) sorts the diff's lines into
groups. The full diff is 3819 lines and is not committed. The committed file holds the group counts
and the 296 lines outside the bulk groups. Every line falls into one of these groups:

| difference | target(s) | cause | expected? |
|---|---|---|---|
| trace JSON lines (867 → 1256) and bank lines: `CORPUSROW`, `JUDGE`, `JUDGEROW`, `seed-N`, identity, trajectory, why, classes, branches (263 → 303) | `corpus_pr`, `corpus_judge`, `corpus_rotating`, `run_report`, the profile suites | W1.6: `generator_version` "2", and the bank re-derived as 17 seeds plus the constructed member; W1.2's `/5` programs; W1.3's world truth; W1.4's `fault` on typed messages | yes |
| `Warning: dependency sunholo/motoko_ext_herdr content changed` / `Run 'ailang lock'` (0 → 246) | every target | #278 on `main`, before the merge base | not W1's |
| `packages/motoko-ext-herdr/herdr.ail:N` effect-site lines, `herdr -- … 50 → 51 ExtPorts field call(s)`, `non-member port calls (92) → (93)` | the herdr profile census | #278's `herdr.ail` | not W1's |
| profiles `driver_only` 37 → 38, `driver_plus_no_ops` 26 → 27, `driver_plus_compose` 18 → 19, `driver_plus_herdr` 7 → 8; the attribution reference `sha256:38d8a67e…` → `sha256:8c5302b3…` | profile suites, `attribution_table`, `herdr_graded` | W1.4's one bump per profile and its re-baselined attribution table | yes |
| `tool_phase.ail:388/389/484` → `:403/404/499`, and the clock-site rows `:484/485/492` → `:499/500/507` | `anchors`, the clock census | W1.4 added 15 lines to `tool_phase.ail` above the guard | yes |
| `schemas: … execution-program/4 … fault-catalogue/2` → `/5 … /3`; `execution_program_dst (execution-program/5)`; v5 specimen rows; `v1-v4 … empty world-truth list`; the rejection rows for `applied_faults` | `execution_program`, `program_persistence`, `strict_replay` | W1.2 | yes |
| `world_truth` and `v5_fixture` rows in `strict_replay` | `strict_replay` | W1.3 | yes |
| catalogue 11 → 13 classes; `fault classes reached 9 of 11` → `11 of 13`; v08-v11 rows; the two world-only rows; the standing-rule-6 guard rows | `fault_catalogue`, `corpus_pr`, `run_report`, `strict_replay` | W1.5 | yes |
| seeded suite: `pairA` 132 → 9, `rich` 110 → 632, `versioned` at "3", the canary at version 2, `depth_canary` seeds 7/11/23 → 6/10/22, `MEASURED: seed 77` → `86`, CENSUS rows | `seeded_generator`, `depth_canary`, `latency_pair` | W1.6's re-sweep, as its commit lists | yes |
| `wire witness, dispatch stage: 1 before-dispatch ToolFailed(s) rendered with effects none, of 5` | `corpus_pr` | W1.6's new wire count | yes |
| `test_coverage`: 657 tests, 644 passed → 710, 697; per-file counts for `tool_fault`, `tool_phase`, `ports`, `session`, `ext_world`, `dst_*` | `test_coverage` | W1.2 to W1.6's inline tests, and `pinned_canary_v3`'s contract property | yes |
| `34 pin(s) across 569 tracked .ail file(s)` → `571`; `admission.ail:993` → `:1001` | `profile_definition`, `driver_only` | W0b.1's `evidence/wrapper_probe.ail` (on `main`) and W1.7's `evidence/mutation-w1-f160eebb/bank_replay.ail`; W1.2's edit to `admission.ail`. The check passes | explained |
| `source revision`, wall, load, the `inline_<n>` temp name, `WHOLE TARGET` (20,000 → 74,000 ms), `sandwich_discriminates` positions | the sweep, `corpus_pr`, `compose_live_exec`, `latency_pair` | a different commit, time-based names, load; the bank is larger | noise, within ceilings |

No DST target changed status.

## `make eval_matrix`

| check | result |
|---|---|
| `compare_matrix.py ../baseline-after-2ac0ff88 <this run>` (`compare-vs-2ac0ff88-run1.txt`) | `VERDICT: DIFFERS`. 619 and 619 rows, 0 on one side only, **5 observations differ**, 5 join statuses differ (`equal` → `failed`). 1 suite exit differs: `scripts/eval/test_mem_guard.py`, 1 → 0. That is the base's run-1 load flake, recorded in its README |
| the same against the base's run 2 (`matrix-rerun/`; `compare-vs-2ac0ff88-run2.txt`) | the same 5 rows, **0 suite exits differ** |
| the same against W0.1, `../baseline-3ae506cc` (`compare-vs-3ae506cc.txt`) | the same 5 rows, 0 suite exits differ |

### Every changed row, with its cause

| `MATRIX.expected.tsv` | case | observed at the base | observed here | join | on W1.1's list? |
|---|---|---|---|---|---|
| `:477` | `M13.ProtectedRegionTouched.span_hash` | `changed:tool_outcome_record` | `changed:<imports:1>` | equal → failed | yes (pass → fail) |
| `:478` | `M13.ProtectedRegionTouched.missing` | `missing:scripted_step_faults` | `changed:<imports:1>` | equal → failed | yes (pass → fail) |
| `:479` | `M13.ProtectedRegionTouched.duplicate` | `duplicate:provider_api_model` | `changed:<imports:1>` | equal → failed | yes (pass → fail) |
| `:481` | `M13.ProtectedRegionTouched.moved` | `moved:provider_api_model` | `changed:<imports:1>` | equal → failed | yes (pass → fail) |
| `:610` | `M15.ProtectedRegionTouched.fixture_comment_only` | `changed:has_key` | `changed:<imports:1>` | equal → failed | yes (pass → fail) |

Each finding is prefixed `ProtectedRegionTouched:`. The cause is a basis change under Option A
(`../../RECORD-W1.1-regrounding-a94204aa.md` §6). `test_candidate.py` checks every candidate
against `manifest-A`, pinned at `65003110`. A row records only the first finding, and the first
finding is now in a protected span W1 changed. The rows are not re-pinned. Moving A and
regenerating `manifest-A` belongs to the evaluator pull request after W1 merges, as §6 point 2
says.

**No row outside W1.1's list changed.** The four rows that would move only if W1.2 had missed its
`execution-program/4` asserts (`:189`, `:191`, `:193`, `:426`) did not move. The journal rows did
not move.

### The finding: the label is `<imports:1>`, not `WorldState`, so 11 predicted rows look unchanged

W1.1 §5 predicted every candidate's first finding would become `changed:WorldState`. It is
`changed:<imports:1>`, from `src/core/dst_fault_catalogue.ail`. `protected-check.txt` runs
`tools/eval_protected/protected.py check` against `manifest-A` at three trees:

| tree | first finding | findings |
|---|---|---|
| `a94204aa` (merge base) | `session.ail <imports:1>` | 2: `session.ail` and `stub_step.ail` imports, stale against A as W0's README says |
| `dd493a1a` (after W1.3) | `ports.ail WorldState` | 11. This is §5's prediction, and at that commit it held |
| `24d347d2` (HEAD) | **`dst_fault_catalogue.ail <imports:1>: L43-45: +import std/string (1 names, L45)`** | 12 |

**Cause.** W1.5 (`59c16984`) added `import std/string (contains)` to `dst_fault_catalogue.ail` for
`ids_occurring_in` (`:796`), the lexical helper behind standing rule 6's guard. The checker reports
files in manifest order, and `dst_fault_catalogue` comes first. Its `<imports:1>` region is
therefore now every candidate's first finding. §5's last paragraph anticipated this case ("If W1.5
changes … the imports of `dst_fault_catalogue.ail` …, the label becomes that span's instead of
`WorldState`"). Its claim that "the set of rows stays the same" does not hold. The new label,
`changed:<imports:1>`, is the same string that the stale `session.ail` imports already gave 11
predicted rows at the base. The matrix records the label without the file, so those rows look
unchanged even though their first finding now comes from another file:

- `:480` `M13.ProtectedRegionTouched.import_statement` expects `changed:<imports:1>` and still
  joins `equal`. It now passes on a different file's imports.
- The 10 rows that already fail (`:483`, `:492`, `:542`, `:556`, `:557`, `:560`, `:563`, `:565`,
  `:566`, `:567`) observed `changed:<imports:1>` at the base, from `session.ail`. They still do,
  now from `dst_fault_catalogue.ail`.

So the visible changed set is 5 of the 16 predicted rows. No row outside the list changed, and no
target went red unexpectedly. The plan's wording is "exactly W1.1's predicted list", and the task's
is "only". The 5 changed rows meet "only". "Exactly" fails for 11 rows, because their observed
string happens to be the same, and the cause is measured above. It is recorded here and not fixed:
the import is W1.5's, and keeping it is a source decision. Two other things follow from it. The
evaluator pull request after W1 merges must also cover `dst_fault_catalogue.ail`'s imports when it
regenerates `manifest-A`. And W1.1 §6 point 2's list of spans W1 touches should name that file,
which §6 says W1 does not touch.

### W1.4's journal rows

W1.1 §5 expected W1.4's journal fixture to add rows. It added none. W1.4 left
`MATRIX.expected.tsv` untouched under Option A ("the new checks have no rows yet", `324589e0`). Its
tests run inside suites whose exit codes did not change: `source_checks.ail`,
`source_checks_live_test.ail` and `candidate_checks_live_test.ail` exit 0, as at the base. 0 rows
are present on one side only.

## Not done

- `../baseline-w1-after-9405d738/` was not removed. The session's permission layer refused
  `shutil.rmtree` and `mv` on it. It is untracked and not committed.
- The worktree's `.ailang/` compile cache and scratch were not removed, for the same reason. It is
  gitignored.
- `make eval_matrix` writes `src/eval/journal/testdata/MATRIX.tsv` into the tree, untracked, as at
  the base. It is copied here and not committed in place.

## Files

| file | what |
|---|---|
| `dst-failed.txt`, `dst-summary.txt`, `corpus_pr.wire.sha256` | as in `../baseline-3ae506cc/` |
| `MATRIX.tsv`, `suites.json`, `join.tsv`, `matrix.stdout.log` | this run's `make eval_matrix`, as in `../baseline-3ae506cc/` |
| `compare-vs-2ac0ff88-run1.txt`, `compare-vs-2ac0ff88-run2.txt`, `compare-vs-3ae506cc.txt` | `compare_matrix.py`'s output against each base run |
| `protected-check.txt` | `protected.py check` against `manifest-A` at `a94204aa`, `dd493a1a` and `24d347d2` |
| `dst-log.diff` | group counts and the 296 lines outside the bulk groups of the normalised sweep-log diff |
| `norm_sweep.sh`, `classify.py` | the normaliser (W0.7's) and the grouping used for `dst-log.diff` |
| `meta.txt` | timings, revision, toolchain, load, `memory.current`, uid, merge base |

The full sweep and matrix logs are not committed, as at the base. The baseline and compare scripts
are `../baseline-3ae506cc/run_baseline.sh` and `compare_matrix.py`, unchanged.
