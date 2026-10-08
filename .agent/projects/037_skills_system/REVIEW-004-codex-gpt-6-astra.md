# REVIEW-004: Codex (GPT-6-Astra), second round on the implementation (PR #213)

Date: 2026-10-05
Reviewer: Codex CLI 0.160.0, launched with `-m gpt-6-astra -s danger-full-access -a never`; the terminal status line confirmed GPT-6-Astra, reasoning effort high. A fresh session. It worked for about 11 minutes.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `rev2-astra`, pane `w7:pA`, worktree `/workspaces/motoko_agent-review-astra`.
Change reviewed: the fixes `6dcd4ae6..e7d635ef` on `feat/skills-extension`, after [REVIEW-003](REVIEW-003-codex-gpt-6-astra.md).
Report SHA-256: `e787fd62599c5a784dea4f55103d16ef475eedf7982d9fd9e572a012271955f5`.
Verdict: **merge.**
Status: Closed. No new finding.

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

### PR #213 — round 2 review

#### 1. Verdict

**Merge.** Reviewed `e7d635ef`, including the complete 11-file production diff from `6dcd4ae6`. Both findings that held my round-1 merge are resolved. The FIFO now receives a structured V3 refusal, approved relative symlinks still work, and the previously surviving omission mutant fails the new membership test. I found no new merge blocker. Independently run baselines pass: 91 package tests, 51 refusal-suite checks, 29 normalization tests, and 29 tests across the four profile modules. Seven mutation runs fail their intended checks. This verdict does not claim CI or the prohibited heavy gates were rerun.

#### 2. Round-1 findings

| Finding | Disposition | Independent check |
| --- | --- | --- |
| FIFO `SKILL.md` hangs startup | **Resolved** | `KEEP=1 make verify_skills_refusal` passes the named-pipe fixture: exit 2, exactly one host error event naming V3 and `.motoko/skills/pipe/SKILL.md`, with the non-regular-file reason. Both relative-symlink controls pass their index/enum assertions. The suite bounds every launch with `timeout`. New mutant N2 also establishes that an exit-2 refusal under the wrong rule does not pass this check. |
| Herdr omission test accepts `skills_typo` | **Resolved** | Reapplied the exact round-1 M5 mutation and ran `ailang test --no-color src/core/dst_driver_plus_herdr.ail`: exit 1, the new named-membership test fails, the old three tests pass. Repeated the same mutation in the other three modules; each fails its new test alone. Each new test checks both `skills` and `ailang_tools` against the actual profile's omitted list. |

Baseline evidence: `r2-logs/package-baseline.log`, `r2-logs/refusal-baseline.log`, and `r2-logs/*.baseline.log`. Profile counts are driver-only 7/7, no-ops 8/8, compose 10/10, herdr 4/4. All normalization tests pass, 29/29. No permission fixture was skipped: this review ran as a non-root user.

#### 3. New findings and review of the fixes

**No new findings.** The following are the checks behind that conclusion, not additional findings.

- **Discovery (`packages/motoko-ext-skills/register.ail:92`).** The exact-case directory listing still precedes the guard, preserving V1. Non-regular listed entries now take V3 without opening the file. Directories and sandbox-rejected symlinks keep their rule/path but acquire the new generic reason instead of `readFileResult`'s reason. Ordinary unreadable regular files still reach `readFileResult` and refuse. The baseline executes those cases and both approved relative-symlink shapes. I additionally created a Unix socket, a dangling relative symlink, an absolute symlink to a valid regular file inside the workdir, and a relative symlink to an unwritten FIFO, each at `SKILL.md`. All four starts returned exit 2 and exactly one V3 error with the non-regular-file reason. Commands, statuses, and outputs are in `r2-logs/edge-results.json` and `edge-*.log`. This guard does not make filesystem access race-free; it fixes the static case requested.
- **Call probe (`scripts/verify_skills_call.ail:56`, `:81`).** It builds the real runtime, obtains registration config from its registry, and dispatches through `dispatch_tool_handle` with `ext_ports_of(live_ports(rt), ...)`. I followed the bridge to `ambient_file`; this is a real disk read. The workdir is `cfg.agent.workdir`, as in the relevant production path. Fresh empty worlds are sufficient for these independent live reads, which preserve world state. D8 is deliberately disabled by context limit 0 and remains covered by the package tests.
- **Shell checks (`scripts/verify_skills_refusal.sh:162`, `:388`).** Timeout status cannot satisfy the required exit-2 refusal; the check also requires the host event, rule and path. The successful call is compared against the entire on-disk file plus directory line. The unknown-name error checks all nine names, and the unsandboxed call checks the actual absolute workdir in D7's error. Failed launches cannot satisfy a call check. I also exercised the `jq -e` selection on empty input and on a record with the wrong name: both return 4, so a missing call record is not silently accepted. N3 demonstrates that a probe supplying `.` instead of the actual workdir fails the new D7 assertion. `bash -n scripts/verify_skills_refusal.sh` passes.
- **Make and CI (`Makefile:2681`, `.github/workflows/verify-extensions.yml:106`).** The target runs all three package files and requires a positive test count with zero failed/skipped tests for each. N1 checks the formerly unexercised zero-test case. The workflow adds both targets to the ordinary `core` job, with no `continue-on-error`, under the existing unfiltered PR trigger; `check_core` remains unchanged. The four profile modules remain within the existing recursive `test_coverage` scope and outside its slow-file exclusions. I read the workflow and setup action; I did not execute GitHub Actions.
- **Lock (`ailang.lock:564`).** The committed change is only the skills package content hash and generation timestamp. Independently running `ailang lock` at the restored head exits 0 and reproduces the entire lock apart from `generated_at`; see `r2-logs/lock-result.json`. I restored the committed file afterwards.

#### 4. Mutants

All mutations were applied individually at this head, after green baselines. The runner recorded the expected failing check before execution and restored each file with `git checkout -- <file>` in a `finally` block, then compared it with the pre-mutation text. Full replacements, commands, statuses and failure lines are in `r2-logs/mutants.json`; individual diffs/logs and the runner (`run_r2_mutants.py`) are retained. No result below is a compilation failure, panic or timeout. No mutant survived.

| Mutant | Change | Command | Result |
| --- | --- | --- | --- |
| M5, round-1 survivor | Herdr omission `extension_id: "skills"` → `"skills_typo"` | `ailang test --no-color src/core/dst_driver_plus_herdr.ail` | **Killed**, exit 1, 3/4 pass; only `test_skills_and_ailang_tools_are_omitted_by_name_test_1` fails. |
| M5, driver-only | Same replacement in `dst_driver_only.ail` | `ailang test --no-color src/core/dst_driver_only.ail` | **Killed**, exit 1, 6/7 pass; only the new membership test fails. |
| M5, no-ops | Same replacement in `dst_driver_plus_no_ops.ail` | `ailang test --no-color src/core/dst_driver_plus_no_ops.ail` | **Killed**, exit 1, 7/8 pass; only the new membership test fails. |
| M5, compose | Same replacement in `dst_driver_plus_compose.ail` | `ailang test --no-color src/core/dst_driver_plus_compose.ail` | **Killed**, exit 1, 9/10 pass; only the new membership test fails. |
| N1, new: no executed tests | Remove all eleven `tests [((), true)]` annotations from `packages/motoko-ext-skills/a6b_test.ail`, retaining its functions | `make verify_skills_tests` | **Killed**, make exit 2; `a6b_test.ail: no count line` and `No tests found`. The other two files pass. |
| N2, new: wrong refusal rule | Replace the new non-regular-file arm's `DirUnreadableSkillMd(...)` with `DirWithoutSkillMd(entry)` | `make verify_skills_refusal` | **Killed**, make exit 2, 47 checks pass and 4 fail. The named-pipe V3 and reason assertions fail as predicted; directory and outside-symlink V3 assertions also fail. Startup still exits 2, showing the assertions distinguish an incorrect refusal. |
| N3, new: wrong probe context | In `scripts/verify_skills_call.ail`, replace `workdir: workdir` with `workdir: "."` | `make verify_skills_refusal` | **Killed**, make exit 2, 50 checks pass and 1 fails: the unsandboxed absolute-workdir D7 call assertion. |

Final `git diff --exit-code` is clean; `git status --short` shows only the untracked `.review/` artifacts.

#### 5. The delegate's three departures

1. **Separate call script — accepted.** Both scripts use the real registration path, and the second actually dispatches through production ports. Running it only twice preserves the required checks without adding the session import to every startup fixture. I confirmed the wiring and executed both paths. I did not independently reproduce the delegate's exact 1.3/33.8-second comparison.
2. **Re-lock after the mutant run — accepted.** The intervening production change is package hash bookkeeping, not executable behavior or a dependency-version change. My baselines and seven mutants run at `e7d635ef`, after that lock change. Independent lock regeneration also matches. Repeating all seventeen earlier mutants solely because of that timestamp/hash update is unnecessary.
3. **Different herdr regime-B row — accepted.** The relevant herdr code is unchanged by this diff. `orchestrator_mode` gates its registration filesystem access on environment/depth and `HERDR_ORCHESTRATOR`; the stated explanation is consistent with that code. I independently compared the archived P6 log with R3's `HERDR_ORCHESTRATOR=off` log: they are byte-identical. This acceptance rests on code inspection and comparison of recorded evidence; I did not rerun the heavy gate or independently establish P6's environment.

#### 6. What I did not look at

- I did not read the other reviewer's record. I read my own round-1 record, the fixing brief, its report, ADR-001, the specified production diff, and relevant callers/helpers.
- I did not run `make dst`, any `driver_*` target, `declared_vs_performed`, or other heavy gates. I did not independently rerun every gate or all seventeen of the fixing delegate's mutants.
- I did not run live providers, the TUI, a complete journal-resume session, non-Linux filesystems, device-node cases, or filesystem races. I did not reopen the explicitly excluded round-1 notes and known limitations; I found no worsening of them in this diff.
- CI has not been run by this review. Its wiring was inspected locally.
- Scope disclosure: my initial `AGENTS.md` filename search inadvertently traversed other `/workspaces` worktrees before I processed the brief's restriction. It returned paths only; I read no file contents there and made no changes there. All subsequent repository inspection and changes stayed in this worktree.

## Notes from the delegating agent

- The reviewer's seven mutants and its four extra file-type cases (a socket, a dangling symlink,
  an absolute symlink and a symlink to a FIFO at `SKILL.md`) were not re-run.
- Its scope disclosure is its own account: an early filename search crossed other worktrees
  under `/workspaces` before it had read the restriction, returning paths only. Nothing in those
  worktrees shows a change.

## No third round

The operator asked on 2026-10-05 that this not become a review loop. It stops here. Findings that
hold the merge went from four in round 1 to none in round 2, and both reviewers moved from "merge
after fixes" to "merge". What changed after the reviewed commit is one assertion in an inline
test, the lock hash that follows from it and evidence; the delegating session checked that with
the mutant and both suites, and no reviewer was asked to look at it. Anything further is an issue,
not a change to this PR.
