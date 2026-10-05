# 037 R3 — evidence for the fixes REVIEW-003 holds the merge for

Evidence for `LEG-R3.md`: five fixes to PR #213 after the two implementation reviews
(`REVIEW-003-codex-gpt-6-astra.md`, `REVIEW-003-claude-fable-5.1.md`). Produced on
2026-10-05 in `/workspaces/motoko_agent-skills` on `feat/skills-extension`, with AILANG
v0.47.2. R3 started at `6dcd4ae6`. Nothing was pushed.

## The result

- All five fixes are committed, one commit each, and one more commit re-locks the root
  manifest.
- `make verify_skills_tests` (new) and `make verify_skills_refusal` pass. The suite is 51
  checks; it was 41.
- `ailang test` passes on `src/core/ext/registry_normalize.ail` (29) and on the four
  profile modules (7, 8, 10 and 4, one more each than before).
- 17 mutants, 17 killed by the check named for them before the run. No survivor.
- No gate is newly red against P6's table. `driver_plus_no_ops` and `driver_plus_compose`
  are red on the same `test_dummy` line as in P6 and on no other: their logs are identical
  to P6's.
- Three things are not as the brief words them. They are under "What differs from the
  brief": the `Skill` dispatch is in a second script, a re-lock commit came after the
  mutant run, and one row of `declared_vs_performed` reads differently in this pane.

## The commits

| Commit | Fix |
|---|---|
| `b839b1de` | F-A: the `isFile` guard, the FIFO fixture, the `SKILL.md`-symlink control, the start timeout |
| `c1a4490c` | F-E: the symlink control checks the index |
| `d4fb1a5a` | F-C: the config record, the `Skill` call script, the suite's D7 and A9 checks |
| `c7649907` | F-D: the by-name omission test in the four profile modules |
| `9f547d78` | F-B: `make verify_skills_tests`, the CI step, the Makefile comment |
| `4fd22883` | re-lock: `ailang.lock` carries the package's new content hash |

The mutants ran at `9f547d78` (`mutants/HEAD.txt`). The gates and the last test runs ran at
`4fd22883` (`gates/HEAD.txt`, `tests/HEAD.txt`). The commit after `4fd22883` adds this
folder only.

## The fixes

### F-A. A `SKILL.md` that is not a regular file refuses; it does not hang — `b839b1de`

**What changed.** `read_entry` (`packages/motoko-ext-skills/register.ail:92`) now asks
`isFile` before it opens a listed `SKILL.md`. One that is not a regular file is V3,
"cannot be read", with the reason "it is not a regular file, or is a symlink that does not
lead to one inside the working directory". No rule was added.

Two things follow from where the guard sits, and a reader should know both:

- A `SKILL.md` that is a directory, and one that is a symlink leaving the workdir, now
  reach the same arm. Both are still V3 with the same path. Their reason is the one above;
  before, it was `std/fs`'s read error ("is a directory", "escapes sandbox").
- The edit keeps the file's line count, on purpose. The reasons in the four omitted lists
  cite `register.ail:331` for the handler's port read, and
  `scripts/dst/run_declared_vs_performed.sh` cites `:344`. Both lines are where they were;
  `ext_call_inventory` still prints `register.ail:331  ctx.ports.file_read`.

**The checks**, in `scripts/verify_skills_refusal.sh`:

- `refused  V3 SKILL.md is a named pipe`: fixture `v3d-skill-md-is-fifo`, `mkfifo` for
  `SKILL.md` with no writer, beside a valid skill. Expects exit 2 and exactly one error
  event naming V3 and the path. A second check requires the reason.
- `started  a SKILL.md that is a relative symlink to a regular file inside the workdir`:
  fixture `c4-skill-md-relative-symlink-inside`. No fixture held this before. It must
  start, and a second check requires the skill in the index and the enum.
- Every start runs under `timeout -k 5 $START_TIMEOUT` (180 s unless set). A run stopped
  by it fails its check with "the run did not end within 180s and was stopped: it hangs".

**Mutants.** `a1`, the guard removed (required): killed. The FIFO case failed with the
timeout message above, exit 124, and the suite ended on its own with 49 passed and 2
failed. The second failure is the reason check on the same case. What failed is the named
check, on the suite's own timeout; the mutant runner's limit (1500 s) was not reached.
`a2`, the guard also refuses the entry whose `SKILL.md` is a symlink: killed by the
control, and by its index check.

### F-B. The package's tests run from a `make` target, and CI runs them — `9f547d78`

**What changed.**

- `make verify_skills_tests` runs `ailang test` on `skills.ail`, `a6b_test.ail` and
  `register.ail`. It reads each file's count line. A file passes when it ran at least one
  test and none failed or was skipped; a file that does not compile prints no count line
  and fails.
- `.github/workflows/verify-extensions.yml`, job `core`: one new step after `check_core`
  runs `make --keep-going verify_skills_tests verify_skills_refusal`. The workflow's
  trigger is every pull request. `check_core` and what it runs are unchanged, and the
  job's name is unchanged.
- The Makefile comment on `verify_skills_refusal` says CI runs it, and no longer that it
  is outside CI.

**The check.** The target passes at `4fd22883`: 62, 11 and 18 tests
(`gates/verify_skills_tests.log`).

**Mutant.** `b1`, V5 no longer compares `name` with the directory name (REVIEW-003's
mutant 3): killed. The target exits 2 and marks `skills.ail` (57 of 62) and `register.ail`
(17 of 18). The brief does not ask for a mutant here.

**Read, not run.** The CI step has not run: nothing was pushed. The workflow file parses
(`Bun.YAML.parse`), and the `core` job's steps are the four it had and the new one. The
"count is zero" branch was not exercised by a mutant: the pattern requires the count to
start with a digit from 1 to 9.

### F-C. The sandbox flag and the real handler path are checked by something committed — `d4fb1a5a`

**What changed.**

- `scripts/verify_skills_startup.ail` prints the registration's `config` record, as the
  registry holds it: `SKILLS_CONFIG {...}`.
- `scripts/verify_skills_call.ail` (new) starts as the runtime does and then dispatches
  `Skill` once per name: `dispatch_tool_handle` over the built registry, with
  `session.ext_ports_of(live_ports(rt), …)` as the ports, under `cfg.agent.workdir`, the
  workdir `rpc.run_with_config` hands a session. These are the calls REVIEW-003 F3 names.
- The suite gained five checks:
  - `D7: under the sandbox, the registration's config record says the sandbox was set`;
  - `A9: sandboxed, a valid skill loads: the directory line, then the file as it is on
    disk` (the result must equal `.motoko/skills/workdir-stamp\n` followed by the file);
  - `A9: sandboxed, a name not in the index is an error that lists the nine names`;
  - `D7: unsandboxed, the registration's config record says the sandbox was not set`;
  - `D7: unsandboxed with an absolute workdir that is not the process's directory, a
    Skill call returns D7's error and loads nothing`.

The unsandboxed launch reads `.motoko/skills` from the directory the process starts in,
the repository root, which is D7's point. The root has no such directory today. Neither
check depends on what it would hold; a root tree that fails validation would refuse the
launch, and both checks would then fail.

**Mutants.** All through `make verify_skills_refusal`.

| Mutant | Result | What failed |
|---|---|---|
| `c1` `sandbox_set` forced to `true` (required) | killed | both unsandboxed checks; 49 passed, 2 failed |
| `c2` the sandbox variable's name misspelt (required) | killed | the sandboxed record check and the valid-load check, as named; also the unknown-name check and the unsandboxed error check; 47 passed, 4 failed |
| `c3` the handler's launch check always says no | killed | the unsandboxed error check alone |
| `c4` the result has no directory line | killed | the valid-load check alone |
| `c5` the unknown-name error lists no names | killed | the unknown-name check alone |

`c1` is the mutant that passed all 91 package tests and all 41 suite checks in the review.
`c2` also fails two checks that were not named for it, for one reason each: with the flag
read as unset, every sandboxed call returns D7's error, and the misspelt name is in the
error text the unsandboxed check compares.

### F-D. Each profile says which extensions it omits, not only how many — `c7649907`

**What changed.** Each of `src/core/dst_driver_only.ail`, `dst_driver_plus_no_ops.ail`,
`dst_driver_plus_compose.ail` and `dst_driver_plus_herdr.ail` gained one inline test,
`test_skills_and_ailang_tools_are_omitted_by_name`. `driver_only` also gained a
test-only helper, `omits`. No entry was added and no count or version moved.
`new_contract_policy` computes all five declarations as out of scope, reachable only from
a `tests` block.

**The check.** `ailang test` on each module: 7, 8, 10 and 4 tests pass (`tests/`).

**Mutants.** `d1` to `d4`, `skills` renamed to `skills_typo` in each module (required):
killed, each by the new test alone (6 of 7, 7 of 8, 9 of 10, 3 of 4). `d5` to `d8`,
`ailang_tools` renamed in each: killed the same way. The count test and the disjointness
test pass under all eight, which is the gap the review found.

### F-E. The symlink control checks the index — `c1a4490c`

**What changed.** After `c3-relative-symlink-inside` starts, a second check,
`the symlinked skill is in the index and the enum`, requires `inlink`'s index line and
requires the enum to be `good` and `inlink`.

**Mutant.** `e1`, discovery skips the symlinked entry: killed by the new check alone. The
`started` check on the same fixture passes under it, as REVIEW-003 F7 predicted.

## The mutation check (`mutate_r3.sh`, `mutants.tsv`, `mutants/`)

`mutate_r3.sh` ran once, at `9f547d78`, on a clean tree. It ran the unmutated source
first: `make verify_skills_tests`, `make verify_skills_refusal` (51 passed),
`registry_normalize.ail` and the four profile modules, all exit 0 (`mutants/baseline_*`).
Then 17 mutants, each one exact replacement in one tracked file, restored with
`git checkout` after its run. The tree was clean at the end.

How a kill counts, as the brief sets it:

- The check or checks expected to fail are written in the script beside each mutant, so
  before the run. `mutants.tsv` copies them into its sixth column.
- A mutant is `killed` only when the command exits non-zero and every named check is on a
  failure line of its output.
- Each mutant is type-checked first. One that does not compile is `compile error`, the
  runner's own limit is `runner timeout`, and a non-zero exit without the named check is
  `other check failed`. None of those happened.
- The `observed` column lists every failure line, so a check that failed beside the named
  one is on the record. That is the case for `a1`, `a2`, `c2` and `b1`.

Two mutants name a fixture's entry in the source (`a2`: `mdlink`, `e1`: `inlink`).
`std/fs` has `isFile` and `isDir` and no way to ask whether a path is a symlink, so a
mutant cannot break "symlinks" as a class. Each breaks the one entry its control builds.

Before the run, each mutant was applied, type-checked and restored once with `DRY=1`,
which runs no check and writes no table.

`mutants.tsv` has the columns id, rule, file, change, command, check expected to fail,
exit, result and observed. `mutants/<id>.diff` is the change, `.check.log` the type-check
and `.log` the run.

## The gates against P6's table (`GATES.tsv`, `gates/`)

`evidence/p6/run_gates.sh` ran each gate as `make <gate>` from the worktree root, one at
a time, with the credential variables removed, at `4fd22883`. `make dst` was not run.
`evidence/p6/compare_logs.py` compared each log with P6's at the re-pin
(`evidence/p6/gates/repin/`); its output is `gates/COMPARE_p6_repin_to_r3.txt`.

The ten gates the brief names:

| Gate | P6 exit | R3 exit | Against P6's log |
|---|---|---|---|
| `check_core` | 0 | 0 | identical |
| `profile_definition` | 0 | 0 | one line: 566 tracked `.ail` files, was 565 |
| `driver_only` | 0 | 0 | the same one line |
| `driver_plus_herdr` | 0 | 0 | identical |
| `herdr_graded` | 0 | 0 | identical |
| `driver_plus_no_ops` | 2 | 2 | identical: red on the `test_dummy` line and no other |
| `driver_plus_compose` | 2 | 2 | identical: red on the `test_dummy` line and no other |
| `ext_call_inventory` | 0 | 0 | identical |
| `ext_ambient_inventory` | 0 | 0 | identical |
| `declared_vs_performed` | 0 | 0 | the `herdr [B]` row and three counts; see below |

The 566th file is `scripts/verify_skills_call.ail`.

Fourteen more targets were run, because they read files R3 changed or are what a
`src/core` change answers to in CI. All have P6's exit code:

- Green: `verify_skills_tests` (new), `verify_skills_refusal`, `new_contract_policy`,
  `verify_core`, `verify_classify_check`, `test_coverage`,
  `ext_ambient_inventory_selftest`, `ext_call_inventory_selftest`, `registry_gen_check`,
  `registry_multiplicity`, `profile_coverage`, `conformance`.
- Red as in P6, on `test_dummy`: `ext_hook_scope` and `ext_hook_scope_selftest`. One line
  differs in each, `make`'s own error line: the Makefile is 31 lines longer, so the recipe
  is at `:3460` and `:3463`.
- `test_coverage` counts 526 tests and 521 passed, 5 skipped against a record; it counted
  522 and 517. The four more are the F-D tests.

**The `herdr [B]` row.** In this run `declared_vs_performed` reports herdr as CONFOUNDED
on FS in regime B, and 9 MEASURED and 11 CONFOUNDED of 20. P6's log has MEASURED, and 10
and 10. The exit code is 0 in both.

The cause is this pane's environment. herdr's registration calls `isDir` on the dagr
directory when it runs in a herdr pane, at depth 0, with `HERDR_ORCHESTRATOR` not `off`
(`packages/motoko-ext-herdr/register.ail:230`). This session has `HERDR_ENV`,
`HERDR_BIN_PATH` and `HERDR_PANE_ID` set and no depth, and the gate's script pins none of
those. R3 changes nothing under `packages/motoko-ext-herdr`.

That was tested, not only read: the same gate at the same commit with
`HERDR_ORCHESTRATOR=off` gives a log identical to P6's
(`gates_herdr_orchestrator_off/`). What P6's own environment held was not established.
That a gate's rows depend on the pane it is run from is not R3's to change; it is here so
that the next reader of this row does not take it for a regression.

## What differs from the brief

1. **The `Skill` dispatch is in `scripts/verify_skills_call.ail`, not in
   `verify_skills_startup.ail`.** The brief puts both the `config` line and the dispatch
   in the startup script. The port bridge is `src/core/session.ext_ports_of`, and every
   process that imports `src/core/session` recompiles it: its type info is over the
   compile cache's blob limit. Measured here, the startup script takes 1.3 s per run and
   the same script with the dispatch added took 33.8 s and 33.6 s. The suite runs it 40
   times, so the brief's wording would have taken the suite from about 75 s to about 22
   minutes, in a CI job with a 20-minute limit. The `config` line is in the startup
   script as asked. The dispatch is in its own script, which the suite launches twice.
   The suite takes 105 to 115 s. The commit message of `d4fb1a5a` says 45 runs; 40 is the
   count (6 controls, 23 refusals, 7 digest rows and 4 other starts).
2. **`4fd22883`, the re-lock, came after the mutant run.** F-A changed `register.ail`, so
   the root `ailang.lock` held the package's old content hash and every `ailang` run in
   the tree warned about it. The first mutant's log showed that. `ailang lock` changed two
   lines, `generated_at` and that hash, as `cb398cc9` did for another package. The brief
   asks for the mutant run at the last commit, and it ran one commit earlier. It was not
   repeated: a mutant of a package file changes the package's content, so the lock does
   not match under any of those mutants at either commit, and the eight `src/core`
   mutants do not read the lock. The checks that must be green were run again at
   `4fd22883` (`gates/verify_skills_tests.log`, `gates/verify_skills_refusal.log`,
   `tests/`).
3. **The `herdr [B]` row**, above.

## Out of scope, and untouched

The reserved key reaching the host through `ailang_tools`' config file; the D7 guard
seeing "unset" and not "set to something else"; invalid UTF-8 and control characters; the
envelope copy pinned to a literal; `test_dummy`; the layout issue. No fix here needed to
touch one of them. The ADR and the plan are unchanged.

## What was run, and what was only read

Run: the three package test files; the refusal suite, on its final text before the work
was split into commits, on the text of `b839b1de`, as the mutants' baseline at `9f547d78`
and as a gate at `4fd22883`; the five `src/core` test files; the mutation script, once;
the 24 gate targets, once each, and `declared_vs_performed` a second time with the switch
off. The suite was not run on the text of `c1a4490c` or `d4fb1a5a` alone.

Read, not run: the CI workflow on a runner; Codex's `reproduce_fifo.py`, whose two cases
the suite's FIFO fixture and its controls now cover; the suite as root, where the
no-read-permission case is skipped.

## Files

| File | What it is |
|---|---|
| `README.md` | this report |
| `mutants.tsv` | one row per mutant |
| `mutate_r3.sh` | the script that ran them |
| `mutants/` | `HEAD.txt`, the seven baseline logs, and a diff, a type-check log and a run log per mutant |
| `GATES.tsv` | one row per gate: P6's exit, R3's exit, a note |
| `gates/` | `HEAD.txt`, `STATUS.txt`, one log per gate, and `COMPARE_p6_repin_to_r3.txt` |
| `gates_herdr_orchestrator_off/` | `declared_vs_performed` with `HERDR_ORCHESTRATOR=off` |
| `tests/` | `ailang test` on `registry_normalize.ail` and the four profile modules at `4fd22883` |

## After the second review

The second review round found a mutant that every committed check let through. It was
not among the 17 above: in `launched_elsewhere`
(`packages/motoko-ext-skills/register.ail:294`), `workdir != "."` changed to
`startsWith(workdir, "/")`. Every committed D7 check used an absolute workdir, so an
unsandboxed launch with a relative workdir other than `.` was checked by nothing. "No
survivor" in "The result" above is true of the 17 mutants that were run and of no more.

Before the fix, at `e7d635ef`, the mutant was applied and `register.ail`'s 18 tests
passed. That run was made to check the report and its log was not kept. The suite was not
run under the mutant then; the reviewer reports that all 51 checks pass.

**The fix, `d7d9dea3`.** `test_d7_unsandboxed_launch_with_another_workdir_does_not_load`
gains one case: with the sandbox unset and the workdir `sub`, the call exits 1, returns
D7's error for `sub`, has no stdout, and leaves the world as it was given, so nothing was
read. The edit is in the file's last test. The lines other files cite in `register.ail`
(`:92`, `:331`, `:344`) are where they were. `84ea6a71` re-locks: `ailang lock` changed
`generated_at` and the package's content hash.

**The runs**, by `mutate_r3_second_review.sh`, once, at `84ea6a71`
(`second_review/HEAD.txt`), on a clean tree. This time the re-lock came before the run.

| Run | Result |
|---|---|
| `make verify_skills_tests`, unmutated | exit 0: 62, 11 and 18 tests, all passed |
| `make verify_skills_refusal`, unmutated | exit 0: 51 passed, 0 failed |
| mutant `c6`, `ailang test` on `register.ail` | exit 1: 17 of 18 passed; the one failure is the named test |

**The mutant row**, appended to `mutants.tsv` as its eighteenth:

| id | rule | change | check expected to fail | exit | result |
|---|---|---|---|---|---|
| `c6` | D7: an unsandboxed start with a relative workdir other than `.` returns D7's error | `workdir != "."` to `startsWith(workdir, "/")` | `test_d7_unsandboxed_launch_with_another_workdir_does_not_load` | 1 | killed |

The check was named in the script before the run. The mutant type-checks, and no other
test failed. The kill rule is the first run's.

The gates were not run again: the change is one case in an inline test of the package and
two lines of the lock. Nothing was pushed.

New files: `mutate_r3_second_review.sh`, and `second_review/` with `HEAD.txt`, the two
baseline logs, and the mutant's diff, type-check log and run log.
