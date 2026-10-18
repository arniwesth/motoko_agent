# Phase 0 mutation run at `019f1c6c`: the result

Run on 2026-10-18 for `../../PLAN-001-effect-disclosure.md` W0.6, under standing rule 3 and
`.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`. Commit handed in:
`019f1c6c` (W0.5, the head of `arniwesth/034-w0-effect-disclosure`). AILANG v0.52.5, uid 1001
(not root, so W0.5 rows e and f were evaluated in every run). Started 09:16:36 UTC, ended
09:18:30 UTC. No source was changed by this task.

## The result

- **Every row of the plan's table is a kill.** m01-m35, and three rows added (m13b, m30b, m34b):
  38 mutants, each red on every test it named before the run. No mutant failed to compile, timed
  out or stopped before its suite's summary.
- **Both controls are green**: the unmutated source before the first mutant (`C-baseline`) and
  after the last (`C-restored`), 44 tests each, W0.5's survival rows b, c, g, h and i to n among
  them. `K0`, a comment-only edit, leaves every suite green, so a recompile alone is not a kill.
- **Two survivors, each with its sentence**, as the plan fixes them: the no-wildcard property and
  Search's `rg` launch failure.
- After the run the four files it mutates are byte-identical to `019f1c6c` (sha256 checked after
  every mutant and at the end) and `git status` shows nothing in them.

## How it was run

    python3 .agent/projects/034_ambiguous_tool_outcomes/evidence/mutation-019f1c6c/mutate.py

from the worktree root. `mutate.py` holds the spec and is the runner; there is no shared runner,
so it implements the meta-decision's rules 2, 3 and 6 itself. It refuses to start as root, off
`019f1c6c`, or with the mutated files dirty. For each mutant, one at a time, it copies the file,
applies the edit (each `old` string must occur exactly once), runs the three suites, copies the
file back and compares its sha256 with the original. `AILANG_FS_SANDBOX` is unset for each run.

| suite | command | what it holds |
|---|---|---|
| `tool_fault` | `ailang test --json src/core/tool_fault.ail` | W0.2's 14 mapping rows, one per arm of each mapping |
| `adapter` | `ailang test --json src/core/tool_dispatch_adapter.ail` | W0.3's 14 renderer tests |
| `w05` | `ailang run … --entry fault_disclosure_witness scripts/dst/world_state_probe.ail` | W0.5 rows a-p, as `make world_state` runs them |

**What counts.** A mutant is a `KILL` when every test in its `expect_red` is red, in a run where
all three suites compiled and printed their summary (`w05`: all 16 rows and the closing
PASS/FAIL line, and no `NOT EVALUATED`). Other tests going red are listed in `also_red` and never
count. A compile error, a missing summary or a timeout would be `NOT-RUN`; some but not all
expected tests red would be `PARTIAL`. None occurred. `apply-check.txt` is the spec's self-test,
`mutate.py --apply-check`: every mutant applied, `ailang check`ed and restored, all compiling.

## Files

| file | what |
|---|---|
| `mutants.tsv` | one row per mutant, control and survivor; the `commit` column names `019f1c6c` |
| `mutate.py` | the spec and the runner |
| `apply-check.txt` | `--apply-check` output |
| `run.stdout.log` | the run's own progress lines |
| `meta.txt` | full commit, uid, AILANG version, start and end |
| `runs/<id>/` | `mutant.diff`, and each suite's log (`tool_fault.log`, `adapter.log`, `w05.log`) |

## Choices a reader should know

- **m13 and m30 are mutated in the renderer, and each has a construction-site twin.** W0.3's
  byte-equal `Ok` tests and its `RunTestsResult` test build the result item themselves, so a
  change at `tool_runtime`'s construction site cannot reach them. The plan names those tests, so
  m13 makes `fault_field` render a fault on the `Ok` arm (fault `None`; W0.3's own word for it) and
  m30 drops `fault_field` from the `RunTestsResult` arm. The added m13b (`to_bash_result`
  constructs `Some`) and m30b (`run_process_result`'s `Err` arm constructs `None`) are the
  construction-site readings; W0.5 rows c and p kill them.
- **m34 drops both of `signal`'s extra fields; m34b drops `signal_name` alone.** Rows a and p read
  the signal number, so only W0.3's per-kind test sees `signal_name`; m34b shows it does.
- **m11 and m23-m29 keep the kind `refused` and change only the disclosure**, as
  `{ kind: refused_fault().kind, effects: EffectsUnknown }`, so the row that goes red is red on
  `effects`, the rule under test.
- **m22 maps `AbnormalExit` to `FaultSpawnFailed`**, m16-m21 each to a sibling kind, so every
  kind mutant still compiles and changes only the arm it names.

## The survivors

| id | rule | why it has no mutant |
|---|---|---|
| `s-nowildcard` | a new upstream `ProcessError` arm is a compile error in both mappings | No mutant is possible: the property is that no wildcard exists, and that is checked by reading the code. The script reads it: `process_error_fault_kind` and `process_error_effects` each have the seven arms and no `_ =>`. |
| `s-rg` | Search's `rg` failure is `none` (`tool_runtime.ail:600`, the plan's `:596`) | It is `Err` only when `rg` itself cannot be launched, which no portable fixture arranges, so no run tells the two versions apart. |

## Line references that moved

The plan is grounded at `e69aaad7`. W0.2 added an import line (+1), a three-line comment above
Search's `Err` arm (+3), and a `fault: None` line to each of `to_bash_result` and
`to_test_result` (+2). At `019f1c6c`, in `src/core/tool_runtime.ail`: `:248`→`:249`, `:404`→`:405`,
`:529`→`:530`, `:590`→`:591`, `:596`→`:600`, `:701`→`:705`, `:703`→`:707`, `:870`→`:874`,
`:872`→`:876`, `:877`→`:881`, `:880`→`:884`, `:899`→`:903`, `:987`→`:993`. Each was found by its
code, and the `edit` column of `mutants.tsv` gives both.
