---
repo: arniwesth/motoko_agent
pr: 282
branch: arniwesth/034-w3-report
ticket: null
title: "feat(dst): the run report counts world-only rows from the effect log, and duplicate effect keys (034 Phase 3)"
---

## Summary

This is Phase 3 of 034 ADR-001, "the report" (`034/PLAN-001` workstream W3, tasks `034/PLAN-001/W3.1` to `034/PLAN-001/W3.3`). Phase 1 (#280) added two world-only fault rows, `tool_effect_applied_then_failed` and `tool_effect_applied_then_deadline`, each the applied twin of an existing class. Phase 3 makes the DST run report count them correctly: each world-only row is counted from the world's effect log, never from the wire, so one tool call is one row and never two. It also adds a duplicate-effect-key metric, labelled as describing the generator.

**Stacked on #281**, which is stacked on #280. The base is `arniwesth/034-w2-properties`, so this diff is W3 only. Merge #280, then #281; GitHub then retargets this PR.

No source outside the DST report and its scenario scripts changes: the harness, the wire and the evaluator are untouched. `make dst` fails no target, the same as W2's baseline.

## Changes

- feat(dst): the run report counts world-only rows from the effect log, and duplicate effect keys (034 W3.1)
- test(034): Phase 3 mutation run at 7b822058 — r1-r3 all kills, zero-duplicate survival holds (034 W3.2)
- test(034): Phase 3 gate at 0cb8c3f3 — run_report, corpus_pr and dst green, FAILED names equal W2's, ADR and plan status (034 W3.3)

What each part does:

- **W3.1** (`src/core/dst_run_report.ail`, `scripts/dst/run_report_dst.ail`, `scripts/dst/corpus_pr_dst.ail`, `Makefile`, `tools/verify_classify/contracts.register`). `tool_class_counts` counts each tool-boundary row from the recorded interactions and the effect log: a world-only row is the twin id's interactions the log holds, and its twin is the ones it does not hold. `observe_classes` and `observe_branches` fold the counts into the two counters, which stay separate. `generator_effect_keys` counts the effect log's duplicate keys (an entry whose key an earlier entry carries). It is labelled as describing the generator, and no live or journal figure is claimed, because neither has an effect log. Its label has one home, `generator_effect_keys_label`, with a substantive contract. `documented_coverage()` now counts its five tool rows with the same counter instead of a hand list. `conditional == 2`, `the_surviving_gaps`, `all_reach_ids() == 5` and the `run_report` awk are unchanged, as the plan says (review finding 6). `corpus_pr_dst` holds the counter against W1.5's class observer on every bank member, names seed 102 (a world-only failed row with no unapplied `ToolFailed`), and prints `REPORTCOUNT` and `REPORTKEYS`. `make corpus_pr` checks that each twin id's wire count equals the twin's count plus its world-only row's (5 = 2 + 3, 5 = 3 + 2, 4 = 4), and now counts `fault_class` occurrences, not lines. The bank's effect logs hold 18 entries and 0 duplicate keys.
- **W3.2** (`evidence/mutation-w3-7b822058/`). The plan's three mutants of `dst_run_report.ail`, with predictions hashed before any run. r1, r2 and r3 are all killed, each red on the tests it named in advance. Controls C-baseline, C-restored and K0 pass (172 tests and rows each). The zero-duplicate survival case holds inline, in `run_report_dst` and on the bank.
- **W3.3** (`evidence/baseline-w3-after-0cb8c3f3/`). The gate. See *Test evidence*. ADR-001 and PLAN-001 status lines name this PR.

52 files changed against #281's head, 5 of them outside `.agent/` (+640, −18). The rest is evidence.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md` (and `PLAN-001.dagr.json`; task addresses `034/PLAN-001/W3.1` to `034/PLAN-001/W3.3`)
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w3-7b822058/README.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w3-after-0cb8c3f3/README.md`

## Predicted outcome

- The run report no longer counts an applied fault and its twin together. On the bank: `ToolFailed` 2 + `tool_effect_applied_then_failed` 3 = the wire's 5; `ToolDeadlineExceeded` 3 + `tool_effect_applied_then_deadline` 2 = 5; `ToolCorrelationMismatch` 4 = 4. Checked by `make corpus_pr`, and it holds.
- A change that counts a world-only row from the typed outcome, counts it under its twin as well, or counts distinct keys instead of duplicates turns a gate red. Checked by W3.2's r1 to r3: each is red on the test it named.
- The duplicate-effect-key metric reads 0 on the bank (`REPORTKEYS effects=18 duplicates=0`) and 1 on a fixture with one repeated key. Checked, and it holds.
- No DST target changes status. Checked, and it holds.
- The wire does not change: `corpus_pr`'s JSON-lines hash is W2's. Checked, and it holds.
- `eval_matrix` does not change. W3 touches no file in `manifest-A` (`protected.py check` is byte-identical to W2's). Not re-run: W3.3's gate does not include it.
- No model-in-the-loop run is a gate (ADR ruling 5), so this PR claims no change in model behaviour.

### Baselines, before and after

- Before: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w2-after-0e09e09d/`, W2.4's baseline. W2's commits after `0e09e09d` change only `.agent/`.
- After: `.agent/projects/034_ambiguous_tool_outcomes/evidence/baseline-w3-after-0cb8c3f3/`, at `0cb8c3f3`. That is this branch before the W3.3 commit, which adds only that directory and the two status lines.

| what changed | cause |
|---|---|
| DST failed targets: none on either side. **The FAILED names are equal** (`diff` of the two `dst-failed.txt`: no output) | |
| `corpus_pr`'s masked wire: 1621 JSON lines, `sha256_json_lines` unchanged. `sha256_all_lines` moves, 1907 → 1920 lines | W3.1's 13 new non-JSON lines (its counter section). Deleted, the output hashes to W2's all-lines hash exactly |
| the sweep log: the `run_report` W3.1 section (4 checks and the survival row) and the report's two new lines | W3.1 |
| the sweep log: the `corpus_pr` W3.1 section (4 checks, 5 `REPORTCOUNT`, `REPORTKEYS`, the duplicate-key row) and the Makefile's world-only wire witness | W3.1 |
| the sweep log: `dst_run_report.ail` 8/8 → 14/14, `test_coverage` 717 → 723 tests (704 → 710 passed) | W3.1's 6 inline tests |
| the sweep log: revision, a temp file name, `WHOLE TARGET` 73,000 → 17,000 ms, the slowest-file line; `make dst` wall 1336 → 1074 s | load. Within every ceiling |

## Test evidence

W3.3, all at `0cb8c3f3`, uid 1001, AILANG v0.52.5, one `make` at a time, all under `env -u AILANG_FS_SANDBOX`:

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core run_report corpus_pr new_contract_policy verify_classify_check` | 2, from `verify_classify_check` only (below) | | `src/core/ type-check: 60 passed, 0 failed` … `run_report_dst PASS` … `REPORTKEYS effects=18 duplicates=0` … `✓ WI-A15 commit 1: the blocking PR corpus` (`WHOLE TARGET: 79000 ms against a declared ceiling of 180000 ms`) … `new_contract_policy: 93 in-scope new pure func declarations, all justified` … `Ran 18 tests … OK` |
| `ailang test src/core/dst_run_report.ail` | 0 | 1.7 s | `14 tests: 14 passed, 0 failed, 0 skipped` |
| `make verify_classify_check`, rerun alone twice | 2, then 0 | | `verify_classify: 70 contracts, register agrees (65 substantive, 2 tautology, 0 spec-equals-body, 3 unclassified)` |
| `REV=0cb8c3f3 WT=<this worktree> run_dst.sh` → `make dst` | 0 | 1074 s | `1074s wall, -j8, load 7.64 8.79 8.27` … `all targets passed` |
| `diff dst-failed.txt` against W2's | 0 | | no output. Both empty |

**`verify_classify_check` is flaky, and not because of W3.** In the chain it stopped on `ailang verify` reporting `ERROR` (`cannot encode ensures clause … std/string.concat`) for `det_applied_twin_message` and `det_excerpt_at`. These are the DETERMINE probes of two W2.2 functions in `dst_invariants.ail`, which W3 does not touch. Run 12 times on the same generated probe file, `ailang verify` gave `SKIPPED` 9 times and `ERROR` 3 times, with the same bytes and the same binary. The record is in `verify-classify-flake.txt`. It is not fixed here.

W3.2's mutation run (`evidence/mutation-w3-7b822058/`, at `7b822058`):

| id | rule | verdict |
|---|---|---|
| r1 | a world-only row is counted from the effect log | KILL |
| r2 | a twin and its world-only row are not counted together | KILL |
| r3 | duplicate effect keys are counted | KILL |
| K0, C-baseline, C-restored | controls | PASS |

Not run, or not done:

- `make eval_matrix` was not run: it is not in W3.3's gate, and W3 touches no protected file.
- `cd src/tui && bun run test` was not run: W3 does not touch `src/tui`.
- The gate chain's wall time was not recorded.
- The `verify_classify_check` flake was not filed upstream.
- No model-in-the-loop run was made.
- CI was not awaited.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
