# Phase 3 mutation run at `7b822058`: the result

Run on 2026-10-23 for `../../PLAN-001-effect-disclosure.md` W3.2, under standing rule 3 and
`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`. Commit handed in:
`7b822058` (W3.1, the head of `arniwesth/034-w3-report`). AILANG v0.52.5, uid 1001. Started
2026-10-23T16:54:29Z, ended 2026-10-23T16:56:53Z (`meta.txt`). No source was changed by this
task: the run's only new files are in this directory.

## The result

- **Every row of the plan's table is a kill.** r1, r2 and r3, each red on every test it named
  before the run: the inline test W3.1 wrote for the rule, and the bank or scenario row that
  holds the same rule. No row was added, and none survived. No mutant failed to compile, timed out
  or stopped before a suite's summary.
- **Both controls are green**: the unmutated source before the first mutant (`C-baseline`) and
  after the last (`C-restored`), 172 tests and rows each, with all 8 survival rows green. `K0`, a
  comment-only edit, leaves every suite green, so a recompile alone is not a kill.
- **The survival case holds**: a log with no repeated effect key reports 0 duplicates, in
  `test_no_repeated_effect_key_reports_zero` (three logs: the mixed member's, seed 102's shape,
  and the empty log), in `run_report_dst`'s survival row (0 of 2), and on the bank
  (`REPORTKEYS effects=18 duplicates=0`). All three are green in both controls and in K0, and
  r3 turns all three red (below).
- After the run `src/core/dst_run_report.ail`, the one file it mutates, is byte-identical to
  `7b822058`: its sha256 was compared after every mutant and at the end (`meta.txt`'s
  `restore` and `final_sha256` lines, all `3be1a863…ecb05`), and `git status` shows nothing
  outside this directory.

| id | rule | expected red (named before the run) | verdict |
|---|---|---|---|
| r1 | a world-only row is counted from the effect log | `dst_run_report:test_a_world_only_row_is_counted_from_the_effect_log`; `cp`: seed-102's world-only row | KILL |
| r2 | a twin and its world-only row are not counted together | `dst_run_report:test_a_twin_and_its_world_only_row_are_not_counted_together`; `cp`: seed-102's "and not under its twin" row | KILL |
| r3 | duplicate effect keys are counted | `dst_run_report:test_a_repeated_effect_key_is_one_duplicate`; `rr`: the one-repeated-key row | KILL |
| K0 | control: comment-only edit | nothing red | PASS |

`mutants.tsv` has each row's exact edit and site, every other test that went red (`also_red`,
never counted), and which survival rows the mutant turned red (`survival_red`).

## How it was run

    python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w3-7b822058/mutate.py --apply-check
    python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-w3-7b822058/mutate.py

from the worktree root at `7b822058`. `mutate.py` holds the spec and is the runner, on W1.7's
pattern (`../mutation-w1-f160eebb/mutate.py`), with the same columns, verdict rules and controls.
It refuses to start as root, off `7b822058`, or with anything dirty outside this directory. Its
first act is to print the sha256 of itself, which holds the predictions (`MUTANTS`, `SURVIVAL`,
`K0`), before any suite runs: `5f43f695…c536`, the first line of `run.stdout.log` and
`meta.txt`'s `spec_sha256`. For each mutant, one at a time, it copies the file, applies the edit
(each `old` string must occur exactly once; `<EOF>` appends), runs all four suites, copies the
file back and compares its sha256 with the original. It clears `.ailang/dst-artifacts` and
`.ailang/dst-corpus` before every script suite. `AILANG_FS_SANDBOX` is unset for each run.

| suite | command | what it holds |
|---|---|---|
| two inline | `ailang test --json src/core/<file>.ail` for dst_run_report and dst_corpus (which imports it) | W3.1's five rows; the corpus rules |
| `rr` | `make run_report`'s `run_report_dst` | the W3.1 scenario: rows a-e, the survival row included |
| `cp` | `make corpus_pr`'s `corpus_pr_dst`, plus two rows the script computes from its output | the bank: the counter held against W1.5's observer on every member, seed 102 named |

The two computed `cp` rows are the target's own W3.1 checks, as W1.7 computed the target's
before-dispatch wire count: **`wire:`** each twin id's `fault_class` occurrences on the wire equal
its twin's `REPORTCOUNT` plus its world-only row's (5 = 2 + 3, 5 = 3 + 2, 4 = 4 at baseline,
and each of the four counts above 0), and **`bank:`** `REPORTKEYS` reports more than 0 effects and
0 duplicates. Each `cp.log` ends with the two `[mutate.py]` lines the rows were computed from.

**What counts** is W1.7's rule. An inline test is `suite:function`, red when its status is
neither `pass` nor `skip`. A script row is `suite:<fragment of its pass line>`, red when fewer
pass lines carry the fragment than in `C-baseline`; digits compare as `#` except after `v` or
`/`. A mutant is a `KILL` when every test in its expected set is red, in a run where every suite
compiled and printed its summary line. Other red tests are listed and never count. `NOT-RUN`,
`PARTIAL` and `SURVIVED` did not occur. `apply-check.txt` is `--apply-check`: every mutant
applied, `ailang check`ed and restored, all compiling.

**Survival rows** (`SURVIVAL` in the script): the zero-duplicate rows inline, in `rr` and on the
bank; and the rows that hold the counts where the rules are intact,
`test_the_counts_fold_into_both_counters`, `rr`'s "each world-only row is reached from the effect
log, once", and `cp`'s two "on every member" rows and the `wire:` row.

## The mutants

| id | site at `7b822058` | edit |
|---|---|---|
| r1 | `dst_run_report.ail:367`, `class_times`'s `WorldOnly` arm | `count_partition(xs, applied, twin, true)` → `count_class(xs, r.class_id)`: the row read from the typed outcome, whose `fault_class_id` is never the world-only id, so it counts 0 |
| r2 | `dst_run_report.ail:370`, `class_times`'s twin arm | `count_partition(xs, applied, r.class_id, false)` → `count_class(xs, r.class_id)`: the twin counts every interaction under its id, the applied ones included |
| r3 | `dst_run_report.ail:499-500`, `duplicates_after` | the `1 +` moves from the repeat arm to the first-seen arm: distinct keys are counted |
| K0 | end of `dst_run_report.ail` | one comment line |

Every edit is line-neutral (`mutant.diff` in each `runs/<id>/`); no anchor cites this file.

## What the also_red columns show

- **The bank sees r1 and r2 in three places**: seed 102's named row, both "on every member" rows
  (the report disagrees with W1.5's observer, and the twin-plus-world-only split no longer sums
  to the twin id's interactions), and the `wire:` row. Under r1 the report counts
  `tool_effect_applied_then_failed=0 tool_effect_applied_then_deadline=0` against 5 and 5 on the
  wire; under r2 `ToolFailed=5 ToolDeadlineExceeded=5`, so 5 + 3 and 5 + 2 against 5 and 5. So
  `make corpus_pr` fails under either mutant on its own.
- **r1 also turns r2's inline test red**: that test asserts the world-only row's branch count is
  1 on seed 102's shape, which r1 makes 0. The reverse does not happen. r2 leaves r1's test green,
  so the two rules are separated by their own tests.
- **r3 turns every zero-duplicate survival row red**: with distinct keys counted, a log with no
  repeat reports its length, 2 in the scenario and 18 on the bank (`REPORTKEYS effects=18
  duplicates=18`). This is the reason W3.1's PART 2c gives: "on a log with no repeat it equals
  the length, not 0". It leaves every count row green, and r1 and r2 leave every key row green.

## Files

| file | what |
|---|---|
| `mutants.tsv` | one row per control and mutant; `commit` is `7b822058` |
| `mutate.py` | the spec and the runner |
| `apply-check.txt` | `--apply-check` output |
| `run.stdout.log` | the run's own progress lines, the spec hash first |
| `meta.txt` | full commit, uid, AILANG version, start and end, the spec hash, the mutated file's sha256 before, under each mutant, after each restore and at the end |
| `runs/<id>/` | `mutant.diff`, and each suite's log with the driver's JSON wire lines dropped |
