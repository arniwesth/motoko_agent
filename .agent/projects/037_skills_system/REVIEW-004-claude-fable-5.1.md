# REVIEW-004: Claude (Fable 5.1), second round on the implementation (PR #213)

Date: 2026-10-05
Reviewer: Claude Code, launched with `--dangerously-skip-permissions --model claude-fable-5-1`. A fresh session. It worked for about 25 minutes.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `rev2-fable`, pane `w7:pB`, worktree `/workspaces/motoko_agent-review-fable`. It stopped once on a permission prompt for a shell script that Claude Code could not check for `rm`. The pane showed only the end of the command, so the delegating session did not approve it; the prompt timed out, was denied, and the reviewer went on another way.
Change reviewed: the fixes `6dcd4ae6..e7d635ef` on `feat/skills-extension`, after [REVIEW-003](REVIEW-003-claude-fable-5.1.md).
Report SHA-256: `e6b8cef4d4ee46176d345eae3023d48412f7103c0c76277a12d46ead7bfbbce4`.
Verdict: **merge.**
Status: Closed. Its one surviving mutant (N1) is addressed at `d7d9dea3`; see the disposition.

## Scope

A second round, on the fixes only, by a fresh session of the same model that wrote REVIEW-003. The
reviewer worked in its own detached worktree at `e7d635ef`. It was given its own REVIEW-003 record
and told not to read the other reviewer's, the brief the fixing delegate had (`LEG-R3.md`) and the
delegate's report (`evidence/r3/README.md`), to be treated as a claim to check. It was asked to say
for each finding that held the merge whether it is resolved, having run something itself; to
review the fixes as new code; to re-run any mutant of its own that survived and write at least two
new ones against the new checks; and to accept or reject the delegate's three departures from its
brief. The round-1 notes were named as deliberately not fixed and with the operator.

The response below is the reviewer's `.review/REPORT-2.md`, unchanged apart from its headings being
moved down two levels.

## Reviewer response

### Review, round 2: PR #213 after the fixes

Reviewed at `e7d635ef` (fixes `6dcd4ae6..e7d635ef`, 11 files outside `.agent`), AILANG v0.47.2,
in the detached worktree `/workspaces/motoko_agent-review-fable`. Nothing was committed, pushed
or written to GitHub. The worktree is back to its starting state (only `.review/` is untracked).
I did not read the other reviewer's record.

#### 1. Verdict

**Merge.** The three findings I held the merge for are resolved, and I checked each by running
it: the FIFO is refused as V3 in about a second, the package's 91 tests and the refusal suite
have a `make` target and a CI step, and the round-1 mutant that survived everything
(`sandbox_set = true`) now fails two checks of the suite. F7 is fixed as well. The fixes broke
nothing I could find: all baselines are green, the lock regenerates to the committed hash, and
the `isFile` guard changes only the reason text of two V3 cases. One of my new mutants
survived (N1): no committed check covers an unsandboxed launch whose workdir is a relative path
other than `.`. The code is right there, I ran it, and the gap is one assertion in an inline
test, so I file it as a note and not as a hold. The one condition on merging is not a code
fix: nothing after `4c9f9c25` is pushed, so the new CI step has never run on a runner.

#### 2. Round-1 findings

| # | Finding | Now | How I checked |
|---|---|---|---|
| F1 | A `SKILL.md` that is a FIFO hangs startup | **Resolved** | Baseline suite: `refused V3 SKILL.md is a named pipe` passes, exit 2. With the guard removed (mutant G1) the same case fails on the timeout, so the hang is still there without the fix and the check sees it. A `SKILL.md` that is a symlink to a FIFO inside the workdir, which the suite does not hold, also refuses as V3 in 1.1 s (ran it). |
| F2 | CI runs none of the package's tests | **Resolved, CI unrun** | `make verify_skills_tests` passes (62, 11, 18) in 17 s. It goes red on a failing test (T1) and on a file that does not compile (T2). The CI step is at `.github/workflows/verify-extensions.yml:106`, in the `core` job, on every pull request. That job took 6.5 minutes on the last run of this branch against a 20-minute limit, and the step adds about 2.5 minutes here. I read the step; it has not run. |
| F3 | The sandbox flag and the real handler path are checked by nothing committed | **Resolved** | Round-1 mutant 4 re-run: the 91 tests still pass, and the suite now gives 49 passed, 2 failed, both unsandboxed D7 checks. A mutant of the tool name in the registration (N2) passes all 91 tests and fails three of the new call checks, so the real dispatch path is now covered by something only the suite sees. |
| F7 | The symlink control does not check the index | **Resolved** | Mutant E2 (discovery drops the entry `inlink`): the `started` check still passes, the new index check fails, 50 passed and 1 failed. |
| F4, F5, F6, F8, F9 | Notes, with the operator | Unchanged | No fix touches them and none is worse. The diff does not touch `registry_normalize.ail`, `skills.ail` or `ailang_tools`. |

Baselines at `e7d635ef`, before any mutant: `make verify_skills_tests` 62, 11 and 18 pass;
`make verify_skills_refusal` 51 passed, 0 failed in 2m03s; `ailang test` on
`registry_normalize.ail` 29, and on the four profile modules 7, 8, 10 and 4;
`make new_contract_policy` exit 0 (3 in scope, 18 out of scope).

#### 3. New findings

##### N1. Note: D7's rule for a relative workdir other than `.` is checked by nothing

- **Where:** `packages/motoko-ext-skills/register.ail:294` (`launched_elsewhere`), the inline
  test at `:748`, and the suite's one unsandboxed launch at
  `scripts/verify_skills_refusal.sh:416`.
- **What:** D7 says the handler refuses when the sandbox was not set and `ctx.workdir` is not
  `.`. Every committed check of that uses an absolute workdir (`/srv/project` in the inline
  test, the fixture's absolute path in the suite). Changing `workdir != "."` to
  `startsWith(workdir, "/")` passes all 91 tests and all 51 checks.
- **Input that shows it:** from the repository root, unsandboxed, `--workdir .review/wd-rel`
  where that directory holds a valid skill `good`. At HEAD the call returns D7's error naming
  `'.review/wd-rel'`, which is right. Under the mutant it returns
  `Unknown skill 'good'. No skills are installed in this workspace`, because the index is the
  launch directory's. **Ran both**, through `scripts/verify_skills_call.ail`.
- **Why a note:** the code is correct and this is the kind of gap F7 was. A relative
  `--workdir` on an unsandboxed command line is the launch D7's guard exists for, though, so
  the assertion is worth having. One line in
  `test_d7_unsandboxed_launch_with_another_workdir_does_not_load`, a call with workdir `sub`
  expecting exit code 1, kills the mutant.

##### N2. Note: the suite's "loads nothing" under D7 cannot fail on its own

- **Where:** `scripts/verify_skills_refusal.sh:412-418`.
- **What:** the unsandboxed launch indexes the repository root, which has no `.motoko/skills`,
  so the index is empty and `good` is not in it. The check therefore shows that an unindexed
  name gets D7's error. It cannot show that an indexed name is not loaded. Mutant N3 (the
  name is looked up before the launch check, so an indexed name loads from the wrong tree)
  passes all 51 checks.
- **It is covered:** the inline test `test_d7_…` fails under N3, and CI now runs it. So the
  mutant is killed, by the inline test and not by the check whose label says so. **Ran it.**
  No action needed; the label claims slightly more than the check can see.

##### Checked and found correct

- **What else the `isFile` guard changes.** Only reason text. A `SKILL.md` that is a
  directory, a symlink leaving the workdir or a dangling symlink was V3 before and is V3 now,
  with the guard's reason in place of `std/fs`'s. A file without read permission still passes
  the guard and gets `std/fs`'s reason (the suite's `v3a` case). A skill directory that can be
  listed but not entered fails in `listDir` before the guard, which is the ADR's stated limit
  (ran it: exit 1). The line count is unchanged, and `register.ail:331` is still the port read
  that the omitted-list reasons cite.
- **The four quadrants of the guard are each held by a case:** regular file loads, symlink to
  a regular file inside the workdir loads and is in the index (`c4`), FIFO refuses, directory
  and symlink-out refuse.
- **`run_ail` and the timeout.** `-u AILANG_FS_SANDBOX` is placed before the first
  assignment, so the unsandboxed run really is unsandboxed: the record reads
  `"sandbox_set":false`. A timed-out run is a failed check with the hang message and the suite
  goes on (G1: 49 passed, 2 failed, ended on its own).
- **The call checks compare whole values.** The load check requires stdout to equal the
  directory line plus the file read from the fixture with `--rawfile`; the repository root has
  no such file, so a read from the wrong directory cannot pass. The unknown-name check
  compares the whole error with the nine names.
- **`verify_skills_call.ail` against the session.** Its context uses `cfg.agent.workdir`,
  which is what `rpc.run_with_config` uses when `--workdir` is given
  (`src/core/rpc.ail:282`, `src/core/config.ail:517`), and the same `ext_ports_of` bridge as
  `session.ail`'s four `mk_v2_ext_ctx` sites. The base URL argument is empty, which only the
  model port reads.
- **The `make` target.** It reads each file's count line and requires a non-zero count with
  no failure and no skip. A module with no tests prints no count line (ran it on another
  file), so that branch fails too. It does not pin the counts, so a deleted test is not seen;
  the brief did not ask for that.
- **The CI step.** After `check_core`, in the same job, `make --keep-going` over both
  targets. CI builds v0.47.2, the version used here (`ailang.toml`, `AILANG_REF`). The longest
  line of a passing suite run is 190 characters, against the line guard's 16,384. The four
  profile modules' new tests run in CI through `test_coverage`; none is in
  `TEST_COVERAGE_SLOW`.
- **The profile tests.** Each requires both ids by name. Renaming `skills` in
  `dst_driver_plus_herdr.ail`, and replacing it with a second `ailang_tools` in
  `dst_driver_only.ail`, each fail the new test alone.
- **The lock.** `ailang lock` at HEAD rewrites only `generated_at`; the committed content
  hash of the skills package is the one it computes.

#### 4. Mutants

Each was applied alone as one exact replacement and the file restored with `git checkout`.
"tests" is `make verify_skills_tests`; "suite" is `make verify_skills_refusal`.

| # | Rule | Change | Command | Result |
|---|---|---|---|---|
| M4 (round 1, survived) | D7: registration records whether the sandbox was set | `register.ail:345`: `let sandbox_set = true;` | tests, then suite | **Killed.** Tests pass (62, 11, 18). Suite 49 passed, 2 failed: both `D7: unsandboxed …` checks. |
| G1 | F-A: a non-regular `SKILL.md` is not opened | `register.ail:96`: the `isFile` arm removed | suite, `START_TIMEOUT=75` | **Killed.** 49 passed, 2 failed: `refused V3 SKILL.md is a named pipe` with "the run did not end within 75s and was stopped: it hangs; exit 124", and its reason check. |
| N1 (new) | D7: unsandboxed and workdir not `.` refuses | `register.ail:294`: `workdir != "."` to `startsWith(workdir, "/")` | tests, then suite | **Survived.** 62, 11, 18 pass; 51 passed, 0 failed. See finding N1. |
| N2 (new) | D4: the registration provides the tool `Skill` | `register.ail:351`: `ToolProvider(["Skills"], skills_handle)` | tests, then suite | **Killed, by the new checks only.** Tests pass. Suite 48 passed, 3 failed: both A9 call checks and the D7 call check. |
| N3 (new) | D7: an indexed name is not loaded from an unsandboxed launch elsewhere | `register.ail:311-312`: the two arms of `precheck` swapped | tests, then suite | **Killed by the inline test, not by the suite.** `register.ail` 17 of 18, `test_d7_unsandboxed_launch_with_another_workdir_does_not_load`. Suite 51 passed, 0 failed. See finding N2. |
| E2 (new) | F-E: a symlinked skill directory is indexed | `register.ail:94`: the entry `inlink` is returned as a regular file | suite | **Killed.** 50 passed, 1 failed: `the symlinked skill is in the index and the enum`. |
| D-herdr | F-D: `skills` is omitted by name | `dst_driver_plus_herdr.ail:331`: `skills` to `skills_typo` | `ailang test` on the module | **Killed.** 3 of 4, `test_skills_and_ailang_tools_are_omitted_by_name`. |
| D-only (new) | F-D: `skills` is omitted by name | `dst_driver_only.ail:1080`: `skills` to `ailang_tools` | `ailang test` on the module | **Killed.** 6 of 7, the same test. |
| T1 | F-B: the target fails when a test fails | `skills.ail:238`: `broken: false` (round-1 mutant 3) | tests | **Killed.** Exit 2; `skills.ail` 57 of 62, `register.ail` 17 of 18. |
| T2 (new) | F-B: the target fails when a file does not compile | `a6b_test.ail:26`: an import of a name that does not exist | tests | **Killed.** Exit 2; `a6b_test.ail` 0 of 11. The Makefile comment says such a file prints no count line; for this error it prints one with every test failed. Red either way. |

#### 5. The three departures

1. **The dispatch is in a second script: accepted.** I measured the cost myself:
   `verify_skills_call.ail` takes 35 s per launch and prints
   `CACHE_WRITE_FAILED module=src/core/session … ARTIFACT_TOO_LARGE`, and the startup script
   takes 1.1 to 1.7 s. Forty launches at 35 s would not fit the CI job. The `config` line is
   in the startup script as asked, and the checks the brief listed are all in the suite. The
   suite took 2m03s here, not the 105 to 115 s the report gives; that is inside "about two
   minutes".
2. **The re-lock came after the mutant run: accepted.** The lock at HEAD is right (section 3),
   the green checks were re-run by me at `e7d635ef`, and I re-ran mutants of every fix at HEAD
   with the results the delegate's table gives. Its argument also holds: a package mutant
   changes the package's content, so no mutant run could have matched the lock at either
   commit.
3. **The `herdr [B]` row: accepted, on reading only.** I did not run `declared_vs_performed`.
   The committed logs say what the report says: the run in the pane differs from P6's in that
   row and three counts, and the run with `HERDR_ORCHESTRATOR=off` at the same commit is
   identical to P6's. `orchestrator_mode` in `packages/motoko-ext-herdr/register.ail:230`
   reads the dagr directory only when that switch is not `off`, and the fixes change no file
   under that package or under `scripts/dst`. Both exit codes are 0.

#### 6. What I did not look at

- CI itself. The new step has never run on a runner; everything about it here is from reading
  the workflow and from local runs.
- `make dst`, the `driver_*` targets, `declared_vs_performed`, `check_core`, `test_coverage`,
  `verify_core`, `verify_classify_check` and the other gates in the delegate's table. I read
  `GATES.tsv` and the two `declared_vs_performed` logs and re-ran only `new_contract_policy`.
- The delegate's `mutate_r3.sh` and its per-mutant logs, beyond `mutants.tsv`. I ran my own
  mutants instead of auditing its runner.
- The suite as root, on macOS, or on a checkout whose own `.motoko/skills` exists. The
  unsandboxed launch reads the repository root's `.motoko/skills`; a root tree that fails
  validation would fail both unsandboxed checks, as the delegate's report says. I did not run
  that.
- An unsandboxed launch with workdir `.` through the real host (the inline test covers it),
  and a `SKILL.md` that is a symlink to a device file in an unsandboxed launch.
- Everything round 1 listed as not looked at, which is unchanged: a live model session, the
  TUI, A5 and A10, `ReadFile` on a bundled file, the compactor interaction.

## Verification by the delegating agent

- **N1, the relative workdir.** Reproduced at `e7d635ef`: with `workdir != "."` changed to
  `startsWith(workdir, "/")` in `launched_elsewhere`, `make verify_skills_tests` passes and
  `make verify_skills_refusal` gives 51 passed, 0 failed.
- **N2** and the reviewer's other mutants were not re-run.

## Disposition — 2026-10-05

| # | Finding | Decision |
|---|---|---|
| N1 | D7's rule for a relative workdir other than `.` is checked by nothing | **Fixed** at `d7d9dea3`: one more call in `test_d7_unsandboxed_launch_with_another_workdir_does_not_load`, with workdir `sub`. The lock follows at `84ea6a71` and the evidence at `a74bdcc2`. Checked by the delegating session at `a74bdcc2`: the mutant now fails that test and no other (17 of 18), `make verify_skills_tests` passes, and the suite gives 51 passed, 0 failed. Outside the evidence folder the three commits change six lines inside that test and two lines of `ailang.lock`. |
| N2 | The suite's "loads nothing" under D7 cannot fail on its own | No action, as the reviewer says: the inline test covers it and CI now runs it. |
| — | The new CI step has never run on a runner | Settled by pushing; the operator said to push once the follow-up had passed its check. |

## No third round

The operator asked on 2026-10-05 that this not become a review loop. It stops here. Findings that
hold the merge went from four in round 1 to none in round 2, and both reviewers moved from "merge
after fixes" to "merge". What changed after the reviewed commit is one assertion in an inline
test, the lock hash that follows from it and evidence; the delegating session checked that with
the mutant and both suites, and no reviewer was asked to look at it. Anything further is an issue,
not a change to this PR.
