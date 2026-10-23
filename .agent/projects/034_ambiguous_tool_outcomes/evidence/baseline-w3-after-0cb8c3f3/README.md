# Phase 3 gate at `0cb8c3f3`, compared with W2's `0e09e09d`

Measured on 2026-10-23 for `../../PLAN-001-effect-disclosure.md` W3.3. `0cb8c3f3` is the head of
`arniwesth/034-w3-report` after W3.2. W3 is stacked on W2 (`da85c1c5`, #281, not yet merged),
which is stacked on W1 (#280), so `git merge-base HEAD origin/main` is still `a94204aa`. The
"before" is W2.4's baseline, `../baseline-w2-after-0e09e09d/`. W2's commits after `0e09e09d`, up
to `da85c1c5`, change only `.agent/`, so that baseline is W3's base.

**Result: the gate is green.** The W3.3 acceptance (`PLAN-001.dagr.json`): `make run_report
corpus_pr` and `ailang test src/core/dst_run_report.ail` pass, and `make dst`'s FAILED names equal
the base's: none on either side. The wire does not move. Every line of the sweep log that differs
is W3.1's own output or noise.

One check outside the acceptance went red once and is not a W3 change: `make
verify_classify_check` failed in the gate chain on an `ailang verify` nondeterminism over two of
W2.2's probes, and passed when rerun. See *verify_classify_check* below.

## How it was run

In W3's worktree at `0cb8c3f3`, with no tracked and no untracked change. The compile cache was
warm. One `make` at a time, all under `env -u AILANG_FS_SANDBOX`, AILANG v0.52.5, 8 cores,
uid 1001. No other heavy run was going on. `meta.txt` holds the `make dst` timings, load and
`memory.current` (its line "unset for both runs" is the script's inherited wording: only `make
dst` ran).

| command | exit | wall | last lines |
|---|---|---|---|
| `make check_core run_report corpus_pr new_contract_policy verify_classify_check` | 2, from `verify_classify_check` only | not recorded | `src/core/ type-check: 60 passed, 0 failed`; `run_report_dst PASS` (`5 ReachStatus variants == 5 ids; all 13 ReportRejection constructors`); `REPORTKEYS effects=18 duplicates=0`; `✓ WI-A15 commit 1: the blocking PR corpus` (`WHOLE TARGET: 79000 ms against a declared ceiling of 180000 ms`); `new_contract_policy: 93 in-scope new pure func declarations, all justified; 72 more out of scope`; `Ran 18 tests … OK`; then `ailang verify reported ERROR for det_applied_twin_message, det_excerpt_at` … `make: *** [Makefile:3414: verify_classify_check] Error 1` |
| `ailang test src/core/dst_run_report.ail` | 0 | 1.7 s | `14 tests: 14 passed, 0 failed, 0 skipped` |
| `make verify_classify_check`, rerun alone, twice | 2, then 0 | | run 1: the same ERROR; run 2: `verify_classify: 70 contracts, register agrees (65 substantive, 2 tautology, 0 spec-equals-body, 3 unclassified)` |
| `REV=0cb8c3f3 WT=<this worktree> run_dst.sh` → `make dst` | 0 | 1074 s | `1074s wall, -j8, load 7.64 8.79 8.27` … `all targets passed` |

`make` stops at the first failing target, and `verify_classify_check` is the last in the chain, so
every other gate-1 target ran to its end and passed. `gate1.txt` holds the result lines with their
line numbers in the full log. Its 15 `✗` lines are 14 `VIOLATION` verdicts in the verifier dump
(the probes' expected verdicts, which `classify.py` reads) and `ailang test`'s `✗ Failed: 0`.

Against W2's gate, `verify_classify` grew from 69 contracts (64 substantive) to 70 (65), and
`new_contract_policy` from 78 in-scope declarations to 93. Both are W3.1's new functions and
`generator_effect_keys_label`'s `contracts.register` row.

`run_dst.sh` is the `make dst` half of `../baseline-3ae506cc/run_baseline.sh`, verbatim. W3.3's
gate has no `make eval_matrix`, so the matrix half was left out.

## `make dst`

| check | result |
|---|---|
| `diff ../baseline-w2-after-0e09e09d/dst-failed.txt dst-failed.txt` | no output, exit 0. Both empty: **the FAILED names are equal, the empty set on each side**. No failed target on either side |
| `corpus_pr.wire.sha256` | `json_lines` 1621 and `sha256_json_lines` `5d83cdce…` **unchanged**: W3 does not change the wire. `lines` 1907 → 1920 and `sha256_all_lines` `cbc0138c…` → `4c64d739…` move, by design: below |
| `dst-summary.txt` | identical but for the revision, the wall/load line, and W3.1's new section (its header and 5 check rows) |

`compare-vs-w2-0e09e09d.txt` holds all three diffs.

**Why the all-lines hash moves and the JSON-lines hash does not.** W3.1 made `corpus_pr_dst`
print a new section after the bank: a blank line, the header `-- 034 W3.1: the run report's
counter, on the bank's own runs and effect logs --`, 4 check rows, 5 `REPORTCOUNT` lines,
`REPORTKEYS effects=18 duplicates=0` and the duplicate-key row. That is 13 lines, none of them
JSON, at lines 1755-1767 of `/tmp/corpus_pr.out`. Delete them from the masked output and it hashes
to W2's all-lines hash exactly (`cbc0138c…`, 1907 lines). So the 13 lines are the whole
difference, and the 1621 JSON lines, which are the wire, are byte-identical.

### The sweep log, line by line

`dst-log.diff` is the complete diff of the base's full sweep log (`.ailang/dst-last.log` at
`0e09e09d`, still in W2's worktree from W2.4's run, its mtime that run's end) and this run's, each
normalised by `../baseline-w1-after-24d347d2/norm_sweep.sh` and sorted, with group counts from
`../baseline-w1-after-24d347d2/classify.py`. It is 67 lines: 41 changed lines, 8 removed and 33
added. Every one falls into a group below.

| difference | target | cause | expected? |
|---|---|---|---|
| the `-- 034 W3.1: world-only rows, counted from the effect log --` section: 4 check rows and the survival row; the report's two new lines (`world-only rows are counted from the effect log …`, `effect keys: duplicate effect keys: 1 of 3 …`), each twice | `run_report` | W3.1: the run report's counter and duplicate-key metric, and the scenario rows | yes |
| the `-- 034 W3.1: the run report's counter …` section: its 4 check rows (2 of them `seed-102`, grouped `corpus-bank`), 5 `REPORTCOUNT`, `REPORTKEYS effects=18 duplicates=0`, the duplicate-key row; `✓ wire witness, world-only rows (034 W3.1): ToolFailed×5 on the wire = 2 not applied + 3 …` | `corpus_pr` | W3.1: `corpus_pr_dst`'s counter on the bank, and the Makefile's wire check | yes |
| `dst_run_report.ail: 8/8 passed` → `14/14`; `test_coverage` 717 tests, 704 passed → 723, 710 (13 skipped, unchanged) | `run_report`, `test_coverage` | W3.1's 6 new inline tests | yes |
| 2 blank lines | `run_report`, `corpus_pr` | the two new sections' separators | yes |
| `source revision` (2 lines), the `inline_<n>` temp name, `WHOLE TARGET` (73,000 → 17,000 ms), the `slowest against the per-file cap` line | the sweep, `compose_live_exec`, `corpus_pr`, `test_coverage` | a different commit, a time-based name, load | noise, within ceilings |

No line of W2's sweep was removed except those replaced above, and no corpus bank row
(`CORPUSROW`, `JUDGE`, `JUDGEROW`) changed. The pin census (`34 pin(s) across 573 tracked .ail
file(s)`) is unchanged: W3 adds no `.ail` file. No DST target changed status.

## `make eval_matrix`: not run

W3.3's gate does not include it. `protected-check.txt` runs `tools/eval_protected/protected.py
check` against `manifest-A` at this tree: the same 12 findings, byte for byte, as
`../baseline-w2-after-0e09e09d/protected-check.txt`. W3 changes `Makefile`,
`scripts/dst/corpus_pr_dst.ail`, `scripts/dst/run_report_dst.ail`, `src/core/dst_run_report.ail`
and `tools/verify_classify/contracts.register`; none is a protected file of `manifest-A`.

## `verify_classify_check`

`verify-classify-flake.txt` holds the record. In the gate chain `classify.py --check` stopped
because `ailang verify` reported `ERROR` (`encoding error: cannot encode ensures clause: …
unsupported application: std/string.concat`) for `det_applied_twin_message` and `det_excerpt_at`,
the DETERMINE probes of two W2.2 functions in `src/core/dst_invariants.ail`. On a pass the same
two probes are `SKIPPED` (unencodable builtin), and both contracts are pinned `unclassified`.

- `dst_invariants.ail` is unchanged since W2.2 (`8c996274`), and so is its generated probe file.
- Rerun alone twice: exit 2 with the same ERROR, then exit 0 (`70 contracts, register agrees`).
- `ailang verify` on the same generated probe file, 12 times in a row: 9 `SKIPPED`, 3 `ERROR`.
  Same input bytes, same binary (v0.52.5, `7200786`).

So the verdict on these two probes is nondeterministic in `ailang verify`, and the failure
predates W3. W2.4's single gate run happened to pass. Not fixed here: it is outside W3's surface
and is an AILANG-side defect (an ERROR versus SKIPPED race in the verifier's encodability check).

## Not done

- The gate chain's wall time was not recorded.
- `make eval_matrix` was not run (not part of W3.3's gate; see above).
- The `verify_classify_check` nondeterminism is recorded, not fixed, and not filed upstream.
- The worktree's `.ailang/` compile cache and `tools/verify_classify/generated/` are gitignored
  and were left in place.

## Files

| file | what |
|---|---|
| `dst-failed.txt`, `dst-summary.txt`, `corpus_pr.wire.sha256` | as in `../baseline-w2-after-0e09e09d/` |
| `compare-vs-w2-0e09e09d.txt` | the FAILED-name, wire-hash and summary diffs against W2's baseline |
| `dst-log.diff` | the complete normalised sweep-log diff against W2's, with group counts |
| `protected-check.txt` | `protected.py check` against `manifest-A` at `0cb8c3f3` |
| `gate1.txt` | gate 1's result lines, with their line numbers in the full log |
| `verify-classify-flake.txt` | `verify_classify_check`'s failure, its reruns and the 12-run measurement |
| `run_dst.sh` | the `make dst` runner |
| `meta.txt` | timings, revision, toolchain, load, `memory.current`, uid, merge base |

The full sweep and gate logs are not committed, as at the base. The normaliser and grouping are
`../baseline-w1-after-24d347d2/norm_sweep.sh` and `classify.py`, unchanged.
