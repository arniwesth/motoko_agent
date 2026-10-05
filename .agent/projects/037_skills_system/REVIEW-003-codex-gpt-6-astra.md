# REVIEW-003: Codex (GPT-6-Astra) review of the implementation (PR #213)

Date: 2026-10-05
Reviewer: Codex CLI 0.160.0, launched with `-m gpt-6-astra -s danger-full-access -a never`; the terminal status line confirmed GPT-6-Astra, reasoning effort high. It worked for 8 minutes.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `rev-astra`, pane `w7:p7`, worktree `/workspaces/motoko_agent-review-astra`.
Change reviewed: PR #213, `feat/skills-extension` at `4c9f9c25`, against the merge base `cf54dff9`.
Report SHA-256: `30164c45b81b3ebecbe98b92146bbfcc80831212b8cb1644bf57ccd4cd8510c2`.
Verdict: **merge after fixes.**
Status: **Open. Nothing here is addressed yet.** A proposed disposition is at the end.

## Scope

An independent review of the implementation, not of the ADR. The reviewer worked in its own
detached worktree of the PR's head and was free to run and change anything in it. It was asked to
judge the change against ADR-001, starting with the core change in
`src/core/ext/registry_normalize.ail` and then the handler, to report findings by severity with a
concrete failing input, to say for each whether it ran it or only read it, and to break the five
rules it considered most important and see whether a test noticed. It was told what was already
known and accepted: the three gates red on `test_dummy`, the layout issue, the reload and
size-limit findings of D8, and that CI and the local suites were green. It was told not to run
the heavy DST gates, and not to commit, push or write to GitHub. The brief is the same for both
reviewers; neither saw the other's report.

The response below is the reviewer's `.review/REPORT.md`, unchanged apart from its headings being
moved down two levels.

## Reviewer response

### Verdict

**Merge after fixes.** Reviewed PR #213 at `4c9f9c25d0375d48642351de552469a4dac66cba` against `cf54dff9`. I would hold it for a discovery guard that refuses non-regular `SKILL.md` entries without opening them, a bounded integration regression test for that case, and a membership check that catches the surviving DST omission mutant below. The host's refusal implementation appears to follow D2, including malformed values, unchanged accepted registrations, and precedence over multiplicity checks. I reproduced the unchanged package's 91 passing tests and the refusal gate's 41 passing checks; those passes do not cover the startup hang or enforce the herdr omission's identity.

### Findings

#### 1. Should fix — a FIFO named `SKILL.md` hangs startup before any refusal

**Location:** `packages/motoko-ext-skills/register.ail:95`, especially the unconditional `readFileResult` at line 96.

Discovery checks that the skill directory lists the exact filename, then opens that entry without checking that it is a regular file. `readFileResult` provides an error result for failed reads, but opening a FIFO with no writer blocks. Consequently a static, listable skill directory can prevent runtime startup indefinitely, without the host's JSONL error or exit 2. No filesystem race, inaccessible directory, or unreadable call-time file is needed; this is outside the limitations accepted in D1 and D10.

**Concrete state:** enable `skills` in a profile and create `.motoko/skills/pipe/SKILL.md` with `mkfifo`, leaving it without a writer. The parent directories are ordinary readable directories. The sandbox is set to that workdir.

**Confirmed by running:** `.review/fs_probe.ail` printed `isFile=false isDir=false` and `before read`, then blocked inside `readFileResult` until a 15-second timeout killed it. Through the real registration/startup path, `scripts/verify_skills_startup.ail` likewise produced no refusal and was killed by `timeout 20s` with exit 124. A matching fixture with an ordinary valid `SKILL.md` started with exit 0 and one `Skill` schema. I repeated both startup cases after restoring all mutants; the result was unchanged. See `.review/logs/fifo-fs.log`, `.review/logs/fifo-final.log`, `.review/logs/regular-final.log`, and the exact commands in `.review/fifo-results.json`. `python3 .review/reproduce_fifo.py` reruns the two retained startup fixtures.

**Required fix:** check `isFile(skill_md_path(entry))` before opening an existing `SKILL.md`, and turn a non-regular entry into a structured refusal, retaining support for sandbox-approved relative symlinks to regular files. Add a timeout-bounded FIFO fixture that requires the refusal rather than merely requiring a nonzero process status. This fixes the static case; it need not promise race-free filesystem access.

#### 2. Should fix — the re-pinned herdr omission test accepts the wrong extension

**Location:** `src/core/dst_driver_plus_herdr.ail:488`; the new omission is at line 331. The related graded-script check is `scripts/dst/herdr_graded_dst.ail:742`.

The new count of 19 proves only the length of the omitted list. The other module test checks disjointness from installed extensions. Neither establishes A8's requirement that `skills` is named in that list. Replacing its ID with an unknown ID preserves both properties. The graded script's `partition_ok` similarly checks counts and nonempty reasons, not membership; this latter observation is from reading, not running that gate.

**Concrete mutant and confirmation:** changed only `extension_id: "skills"` to `extension_id: "skills_typo"` in this module. `ailang test --no-color src/core/dst_driver_plus_herdr.ail` exited 0, with all three tests passing, exactly as on the unchanged source. See `.review/logs/M5-omission-membership.log`. This is a demonstrated regression-test gap, **not a claim that the committed omission is currently wrong**, and not a claim that I ran the prohibited heavy gates.

**Required fix:** add a lightweight check of the required omitted IDs in all four profiles, including `skills` and the repaired `ailang_tools` entry. For herdr, comparing the installed/omitted sets against the manifest's extension set would also make its claimed partition test substantive. A count-preserving wrong-ID mutation must fail.

### Your five mutants

I selected host refusal semantics, root refusal discovery, extension fail-safe behavior, call-time validation, and the new DST omission requirement. Mutants were applied individually; each file was restored immediately afterwards with `git checkout -- <file>`. The runner also checked that the restored text equalled the pre-mutation text. All failures below were executed test assertions, not compilation failures.

Commands below run from the repository root unless a package-directory prefix is shown. Exact replacements, commands, and exit statuses are retained in `.review/mutants.json`; the runner is `.review/run_mutants.py`.

| Mutant | Source change | Command | Result |
| --- | --- | --- | --- |
| M1 — D2: malformed refusal must refuse | `src/core/ext/registry_normalize.ail:388`: replace `Some(_) => Some(malformed_registration_refusal())` with `Some(_) => None`. | `ailang test --no-color src/core/ext/registry_normalize.ail` | **Killed**, exit 1; 27/29 pass. `test_refusal_non_string_value_refuses_as_malformed` and `test_refusal_reader_reads_one_top_level_key` fail. |
| M2 — R1: a listed but inaccessible root is not absent | `packages/motoko-ext-skills/register.ail:125`: change the `root_is_listed()` branch from `RootIsNeither` to `RootAbsent`. | `make verify_skills_refusal` | **Killed**, make exit 2; 38 checks pass, 3 fail. Outside-target, absolute-target, and dangling root symlinks incorrectly start with exit 0 and no refusal event. |
| M3 — D2: every call returns a recorded refusal | `packages/motoko-ext-skills/register.ail:310`: replace the refusal condition with `false`, bypassing that branch. | `cd packages/motoko-ext-skills && ailang test --no-color register.ail` | **Killed**, exit 1; 16/18 pass. `test_d2_with_a_refusal_every_call_returns_it` and the refusal-precedence case in `test_d7_unsandboxed_launch_with_another_workdir_does_not_load` fail. |
| M4 — D10/D8: validate the freshly read text before delivery | `packages/motoko-ext-skills/register.ail:320`: replace `load_skill(skill, content, call_id, declared_limit)` with `Ok(skill_result_envelope(call_id, skill, content))`. This bypasses both per-file validation and the context-size check. | `cd packages/motoko-ext-skills && ailang test --no-color register.ail` | **Killed**, exit 1; 16/18 pass. `test_a9_a_broken_edit_is_a_tool_error_naming_the_rule` and `test_d8_a_skill_that_does_not_fit_is_a_tool_error` fail. |
| M5 — A8: name `skills` in the omitted list | `src/core/dst_driver_plus_herdr.ail:331`: replace the omission's `skills` ID with `skills_typo`, preserving its reason and the list length. | `ailang test --no-color src/core/dst_driver_plus_herdr.ail` | **Survived**, exit 0; 3/3 pass. Finding 2. |

Unchanged-source baselines: `skills.ail` 62/62, `a6b_test.ail` 11/11, `register.ail` 18/18, `registry_normalize.ail` 29/29, the herdr module 3/3, and `make verify_skills_refusal` 41/41. Logs are under `.review/logs/baseline-*`. Final `git diff --exit-code` was clean; review artifacts are confined to `.review/`.

### What you did not look at

- I did not run `make dst`, any `driver_*` target, or another heavy gate. I inspected the changed DST profile and inventory pins and their relevant check implementations; I did not independently rerun the complete inventory/CI suites.
- I read the ADR decisions and acceptance criteria, implementation plan, prototype-results note, and the specified production diff. I did not audit the 283-file evidence archive or independently rescore the prototype's model sessions.
- I did not launch the TUI, call live providers, or conduct an end-to-end journal resume. The refusal gate exercises the runtime startup path and the journal's compatibility function, not a complete resumed session.
- I did not test filesystem races, non-Linux/case-insensitive filesystems, or every special-file type. The FIFO failure is executed evidence; broader special-file behavior is not claimed.
- The known `test_dummy` gate failures, subdirectory-workdir issue, compaction/reload limitations, OpenAI scope exclusion, and absence from the default profile are not reported as new findings.

## Verification by the delegating agent

Both findings were re-run by the delegating session at `4c9f9c25`, with its own commands.

- **Finding 1, the FIFO.** Reproduced. Two fixture workdirs with the suite's own `probe` profile,
  started the way `scripts/verify_skills_refusal.sh` starts one. With an ordinary valid `SKILL.md`:
  exit 0 in one second, `entries=1 loaded=skills`, one `Skill` schema. With `SKILL.md` made by
  `mkfifo`: no output and no error event, killed by a 30-second timeout (exit 124). The code path
  is `read_entry`, `packages/motoko-ext-skills/register.ail:92`: `readFileResult` is called on a
  listed `SKILL.md` with no `isFile` check. The other reviewer found the same thing independently.
- **Finding 2, the herdr omission.** Reproduced. With `extension_id: "skills"` changed to
  `"skills_typo"` in `src/core/dst_driver_plus_herdr.ail`, `ailang test` passes 3 of 3, as on the
  unchanged source. A qualification the reviewer did not make: in none of the four profile
  modules does an inline test name the id. For `driver_plus_no_ops` and `driver_plus_compose` the
  gates' own checkers do compare the two lists with the resolved install set
  (`tools/profile_definition/check_no_op_profile.py:424`, `check_compose_profile.py:150`). That was
  read, not run with the mutant, and both of those gates are red today on `test_dummy`, so a new
  failure there would show only as a different failing line.
- **Mutants M1 to M4** were not re-run.

## Proposed disposition — 2026-10-05, not ruled

| # | Finding | Proposed |
|---|---|---|
| 1 | A FIFO named `SKILL.md` hangs startup | Fix before merge: an `isFile` guard in `read_entry` that reports V3, and a fixture with a timeout that requires the refusal |
| 2 | The herdr omission test accepts the wrong extension | Fix before merge: an inline test in each of the four profile modules that names the omitted ids it requires |
