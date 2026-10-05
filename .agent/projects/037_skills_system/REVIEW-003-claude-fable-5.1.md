# REVIEW-003: Claude (Fable 5.1) review of the implementation (PR #213)

Date: 2026-10-05
Reviewer: Claude Code, launched with `--dangerously-skip-permissions --model claude-fable-5-1`; the banner confirmed Fable 5.1. It worked for 26 minutes.
Delegation: [herdr skill](../../../.claude/skills/herdr/SKILL.md), agent `rev-fable`, pane `w7:p8`, worktree `/workspaces/motoko_agent-review-fable`. It stopped once on a permission dialog, for removing a temporary directory inside its own scratch space; the delegating session read the target and approved it.
Change reviewed: PR #213, `feat/skills-extension` at `4c9f9c25`, against the merge base `cf54dff9`.
Report SHA-256: `8586b0a7c9a9999aead546bbbb6dd261fba9193a93c8ba730e8695e428fb16ea`.
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

### Review: PR #213, the skills extension (implementation)

Reviewed at `4c9f9c25` against merge base `cf54dff9`, AILANG v0.47.2, in the detached worktree
`/workspaces/motoko_agent-review-fable`. Nothing was committed or pushed. The worktree is back
to its starting state (only `.review/` is untracked).

#### 1. Verdict

**Merge after fixes.** The code does what ADR-001 says in every place I could check, and the
core change is correct: it refuses exactly the four cases D2 lists, in the stated order. It
changes behaviour for one other extension, `ailang_tools`, and only if the operator's own config
file carries the reserved key (F4). The extension fails safe on a host that
ignores the key; I confirmed that through the real registry, not only the stub tests. I would
hold the merge for three small things: F1, a `SKILL.md` that is a FIFO hangs startup forever
with no message; F2, nothing in CI and no `make` target runs the package's 91 tests, and
`verify_skills_refusal` is outside CI, so "CI is green" covers only the core change and a
type-check; F3, the D7 sandbox flag is read by no committed check, and a mutant of it survived
all 91 tests and all 41 checks. The rest are notes.

#### 2. Findings

##### F1. Should fix: a `SKILL.md` that is a FIFO blocks startup indefinitely

- **Where:** `packages/motoko-ext-skills/register.ail:95-99` (`read_entry`).
- **What:** when the directory's listing holds `SKILL.md`, the code calls `readFileResult` on it
  without asking `isFile` first. A named pipe opens and blocks until something writes to it.
  The runtime prints nothing and never exits: no refusal, no error event. When a writer
  appears, whatever it writes is validated as the file.
- **Input:** `mkdir -p .motoko/skills/pipe && mkfifo .motoko/skills/pipe/SKILL.md`, beside a
  valid skill, sandbox set to the workdir.
- **Confirmed by running.** Booted through `load_config_from_cli` and
  `init_runtime_with_config`: killed by `timeout` at 25 s with no output. A second run was left
  blocked, a writer fed the pipe at 50 s, and the process then exited 2 at 50 s with
  `V4: .motoko/skills/pipe/SKILL.md: no frontmatter block`.
- **Contrast:** a FIFO directly under the root is handled (`V2`, ran it), and the call-time read
  is safe because `ambient_file` checks `isFile` first (`src/core/ports.ail:1393`).
- **Fix:** an `isFile(skill_md_path(entry))` guard, reporting V3 otherwise, and a fixture in
  `verify_skills_refusal.sh`. This is not one of the ADR's stated limits (those are `listDir`
  failures and `.motoko` itself being a symlink out).

##### F2. Should fix: CI runs none of the skills tests

- **Where:** `Makefile:2658-2662`, `.github/workflows/verify-extensions.yml`,
  `tools/test_coverage/derive.py:834` (`--root` defaults to `src/core`).
- **What:** no CI step and no `make` target runs `ailang test` on
  `packages/motoko-ext-skills/` (`grep` for `motoko-ext-skills`, `motoko_ext_skills` and
  `verify_skills` over `.github`, `Makefile` and `tools/test_coverage` finds only the
  `verify_skills_refusal` target). `test_coverage` walks `src/core` only.
  `verify_skills_refusal` is deliberately outside `check_core` (the Makefile comment says so).
  So in CI this PR is covered by the 29 inline tests of `registry_normalize.ail` and by the
  type-check that comes from `registry_generated.ail` importing the package. Every rule in
  `skills.ail` and all of discovery can regress with CI green.
- **Shown by:** mutants 3 and 5 below are killed only by commands CI does not run.
- **Confirmed by reading and grep**, not by running CI.
- **Why this is not covered by D11's accepted consequence:** D11 accepts that
  `verify_extensions` does not boot `skills` because it is outside the default profile. It does
  not say the package's own tests have no runner. The two commands cost about 15 s and 75 s
  here (the Makefile comment says 45 s; I measured 1m15s).

##### F3. Should fix: the D7 sandbox flag, and the real handler path, are checked by nothing committed

- **Where:** `packages/motoko-ext-skills/register.ail:345` (`sandbox_set`), `:293-295`
  (`launched_elsewhere`).
- **What:** the handler's D7 guard depends on `sandbox_set`, which registration reads from the
  environment. Outside `register.ail` itself, the only readers of that value are the P4 probe
  and mutation script in the evidence folder, which no gate runs. The inline tests build
  `config` by hand, and `verify_skills_startup.ail` never prints or reads the flag.
- **Shown by:** mutant 4 (`let sandbox_set = true;`) passes all 91 package tests and all 41
  checks of `make verify_skills_refusal`. That direction switches the D7 guard off. The other
  direction is worse and equally unseen: a misspelt variable name makes the flag always false,
  and then every session whose `--workdir` is not `.` (layout 1, the layout D7 is stated for)
  gets "nothing was loaded" on every `Skill` call. I did not run that second mutant; the
  argument is that nothing committed reads the flag from a real registration.
- **Wider point:** no committed check dispatches a `Skill` call through the real host and the
  live port. A9 and A10 rest on the P1 and P5 evidence scripts. I wrote a 60-line probe that
  does it (`dispatch_tool_handle` with `ext_ports_of(live_ports(rt), …)`), and it behaved
  correctly: a valid skill loads with the directory line, an unknown name lists the names, an
  unsandboxed launch with an absolute workdir returns the D7 error. Adding that call and the
  `config` line to `verify_skills_startup.ail`, plus one unsandboxed case, would close this.

##### F4. Note: the reserved key can reach the host from `ailang_tools`, through the operator's file

- **Where:** `src/core/ext/registry_normalize.ail:405`, with
  `packages/motoko-ext-ailang-tools/register.ail:258-263`.
- **What:** this is the one answer "yes" to "does it change anything for an extension other than
  skills". `ailang_tools` returns the decoded `<profile>/ailang_tools.json` as its `config`,
  whole. Every other extension builds `config` from fixed keys. So a top-level
  `registration_refusal` in that file now refuses startup, where before this change the runtime
  started.
- **Ran it.** Profile order `["ailang_tools"]`, sandbox set. With
  `{"some_feature": true}` the registry starts. With
  `{"some_feature": true, "registration_refusal": false}` it exits 2 with
  `[registration-refused] extension 'ailang_tools#0' refuses its own registration … the value
  of 'registration_refusal' is not a string`.
- Nobody writes that key by accident, so this is a note. Two things are still off: the message
  says the extension refused "its own registration" when the operator's file did, and the ABI
  comment's "an extension uses the key for nothing else" is a promise `ailang_tools` cannot
  keep, because it does not choose its keys. D2's "the key is unused in the tree today" is true
  of the source and silent about this path.

##### F5. Note: the D7 guard sees "unset", not "set to something other than the workdir"

- **Where:** `register.ail:293-295`, `:345`.
- **Ran it:** sandbox root set to the parent of the workdir, the parent holding its own
  `.motoko/skills/parent-skill`, the workdir holding `good`. The index was the parent's,
  `Skill("good")` was "Unknown skill", `Skill("parent-skill")` loaded, and the directory line
  it returned is a path that does not exist under the workdir. No error.
- The code matches D7's text, which records only whether the variable was set, so this is a
  gap in the decision, not a deviation. Every in-tree session launcher sets the sandbox to the
  workdir (`runtime-process.ts:475`, `env-server.ts:543`, `:1455`), so I know of no real launch
  that hits it.

##### F6. Note: invalid UTF-8 and control characters are accepted

- **Ran it.** A `SKILL.md` with Latin-1 bytes in the description and body starts, and both the
  index and the loaded text carry U+FFFD where the bytes were. A description holding NUL or ESC
  (`"one\0two\x1b[31m"`) passes V6 and goes into the tool description as is. Neither is
  against the ADR. The first means a mis-encoded skill loads silently altered.

##### F7. Note: one control in `verify_skills_refusal.sh` would pass on a wrong implementation

- **Where:** `scripts/verify_skills_refusal.sh:240` (`c3-relative-symlink-inside`).
- `starts` checks the exit code, the absence of an error event and that there is one schema.
  It does not check that `inlink` is in the index, so an implementation that silently skipped a
  symlinked skill directory would pass. **Read, not run.**

##### F8. Note: the envelope copy is pinned to a literal, not to the core function

- **Where:** `packages/motoko-ext-skills/skills.ail:314` (`envelope_message`), a copy of
  `result_to_model_json` (`src/core/tool_contract.ail:60`).
- The test compares against strings printed once by the core function. If the core encoding
  changes, the copy and V7 drift with all tests green. `registry_multiplicity_dst.ail` already
  imports both sides and could hold a live row. Low risk today: V7 leaves 5,536 chars under the
  65,536 cut. **Read, not run.**

##### F9. Note: the pins, and the known-red gates

- I ran the two light inventory tools. `ext_ambient_inventory` passes and derives for `skills`
  what the four omitted-list reasons say: AMBIENT, 5 ambient sources, 1 ExtPorts field call,
  3-module closure. `register.ail:331` in those reasons is the right line.
- `ext_hook_scope` and its self-test are red, as stated. I diffed expected against derived in
  the self-test's four failing rows: the only differing key in each is `test_dummy`. Every
  `skills` pin agrees (in the HOOK-PORT-MEDIATED list, 2 atoms, `config-caps`, `pass`).
- That is not worse than stated, with one caveat: those four comparisons are whole-map
  comparisons, so while `test_dummy` keeps them red a wrong `skills` pin would not change the
  exit status. It was right today because I read it, not because a gate said so.
- No stale profile-version literal: the only versioned `extension_profile` strings that changed
  are the two `driver_plus_herdr/4` in `herdr_graded_dst.ail`, matching version `4`.
- The omitted-list count tests (`== 19`, `== 19`, `== 16`) check a list's own length. Whether
  `skills` is a member is checked by the partition gates I was told not to run; I relied on the
  P6 evidence README for that and did not re-run it.

##### Checked and found correct

- **The core change** (`src/core/ext/registry_normalize.ail:384-413`). Absent key, non-object
  config and empty string accept; non-empty string refuses with that string; any other type
  refuses as malformed; the check precedes the empty-list test and the walk. Apart from
  `ailang_tools` (F4), the other 18 registrations pass `config` through a named builder or
  `jo([])`. I read five builders (`mcp`, `a2a`, `compose`, `herdr`, `test_dummy`) and each writes
  fixed keys; for the rest I read only the call site, so "fixed keys" is an inference there. No source file outside this change contains the string `registration_refusal`.
- **Failing safe (D2).** With the host check disabled in source and a broken tree, the real
  registry started, the catalogue was the "failed validation" text with no `enum`, and both
  `Skill` calls returned the refusal string. Ran it.
- **Filesystem cases run through the real registry under the sandbox:** FIFO as a root entry
  (V2); a symlink loop `loop -> .` (V1); an alias symlink to another skill (V5); `SKILL.md` as a
  relative symlink inside the workdir (loads); the root as a relative symlink inside the
  workdir (loads); `.git` and `__pycache__` directories under the root (V1 each, as D1 says);
  directory names with a space and with a newline (V5, and the event stays one JSON line); an
  empty `SKILL.md` (V4); an unlistable root (exit 1 with the AILANG error, the stated limit).
- **Pure rules:** `length` and `substring` count characters, so non-ASCII text before the
  closing delimiter cuts correctly; 1,024 CJK characters pass V6 and 1,025 fail; an alias bomb
  is a V4 decode error in under a second; U+2028 and U+0085 in a description collapse to
  spaces, so a description cannot add an index line.

#### 3. The five mutants

Each was applied alone and the file restored with `git checkout`.

| # | Rule | Change | Command | Result |
|---|---|---|---|---|
| 1 | D2, host fails closed on a malformed refusal | `registry_normalize.ail:388`: `Some(_) => Some(malformed_registration_refusal())` to `Some(_) => None` | `ailang test --no-color src/core/ext/registry_normalize.ail` | **Killed.** 2 of 29 fail: `test_refusal_non_string_value_refuses_as_malformed`, `test_refusal_reader_reads_one_top_level_key`. |
| 2 | D2, the extension returns the refusal on every call | `register.ail:310`: removed the `config_refusal` arm of `precheck` | `cd packages/motoko-ext-skills && ailang test --no-color register.ail` | **Killed.** 2 of 18 fail: `test_d2_with_a_refusal_every_call_returns_it`, `test_d7_unsandboxed_launch_with_another_workdir_does_not_load`. |
| 3 | V5, `name` equals the directory name | `skills.ail:238`: `broken: s != dir_name` to `broken: false` | `cd packages/motoko-ext-skills && ailang test --no-color skills.ail` | **Killed.** 5 of 62 fail, first `test_v5_name_differs_from_directory`. |
| 4 | D7, registration records whether the sandbox was set | `register.ail:345`: `let sandbox_set = true;` | all three package test files, then `make verify_skills_refusal` | **Survived.** 18, 62 and 11 pass; 41 passed, 0 failed. See F3. |
| 5 | R1, a root that is a symlink out is not "no root" | `register.ail:125`: removed `else if root_is_listed() then RootIsNeither` | `make verify_skills_refusal` | **Killed.** 38 passed, 3 failed: the symlink-out, absolute-target and dangling R1 cases each exit 0. |

Two more, run because they were cheap, both killed by `ailang test register.ail`: the catalogue
listing skills beside a refusal (`register.ail:220`, `test_catalogue_with_a_refusal_lists_no_skill`),
and the handler returning `ctx.world` instead of the port's world (`register.ail:334`,
`test_a6_the_ports_world_is_returned` and one more). The second also shows the effectful
inline tests do execute.

Baselines before any mutant: 29, 62, 18 and 11 tests pass; `make verify_skills_refusal` gives
41 passed, 0 failed in 1m15s.

#### 4. What I did not look at

- `make dst`, the `driver_*` targets, `declared_vs_performed`, `registry_multiplicity` and
  `herdr_graded`: not run, as instructed. The new rows in `registry_multiplicity_dst.ail` and
  the `absorb Env 18` / `absorb FS 15` counts were read only.
- A live model session, the TUI, A5's measurements and A10. `ReadFile` on a bundled file under
  the directory line (A9's last clause) was not run, including for a root or skill reached
  through a symlink.
- `a6b_test.ail` beyond running it, and the compactor interaction in general.
- `PLAN-001`, `NOTE-p1-prototype-results.md` and the evidence folder, except the P4 mutant
  table and the P6 README. The measured figures quoted in the omitted-list reasons (261 of 270,
  53 of 54, and so on) were not checked against the note.
- `ailang.lock`, the package lock, and the `.motoko/config/skills/` profile contents.
- Call-time behaviour for an unreadable file (the stated D10 limit) and very large files.
- macOS or any case-insensitive filesystem, where V1's exact-case rule actually matters.

## Verification by the delegating agent

The three findings the reviewer would hold the merge for were checked by the delegating session
at `4c9f9c25`. The notes were not re-run, except where said.

- **F1, the FIFO.** Reproduced, with a separate fixture and command: a valid file starts in one
  second with one `Skill` schema; a FIFO gives no output and is killed by a 30-second timeout.
  The other reviewer found the same thing independently. The reviewer's observation that the
  process continues and reports V4 once a writer appears was not re-run.
- **F2, CI runs none of the package's tests.** Confirmed by search. Nothing under `.github`
  names the package. The `Makefile` has one target for it, `verify_skills_refusal` (`:2661`), and
  the comment above it says it is not a prerequisite of `check_core`. `test_coverage` walks
  `src/core` by default (`tools/test_coverage/derive.py:834`). Two other packages do have a test
  file run from a `make` target (`Makefile:2494`, `:2718`); this one has none.
- **F3, the sandbox flag.** Reproduced. With `register.ail:345` changed to
  `let sandbox_set = true;`, the three package test files pass (18, 62 and 11) and
  `make verify_skills_refusal` gives 41 passed, 0 failed. One thing the reviewer did not say: P4's
  own mutation table lists three sandbox-flag mutants (`d09`, `d10`, `d12`) as killed. They were
  killed by the P4 discovery probe, an evidence script that no gate runs. So the table says
  killed, and every committed check lets the same break through.
- **F4, the reserved key through `ailang_tools`.** Confirmed by reading:
  `packages/motoko-ext-ailang-tools/register.ail:257` returns the decoded
  `<profile>/ailang_tools.json` whole as its `config`, and `normalize_registration`
  (`src/core/ext/registry_normalize.ail:404`) reads the key from any extension's `config`. The
  reviewer ran it; the delegating session did not.
- **F5 to F9** were not checked.

## Proposed disposition — 2026-10-05, not ruled

| # | Finding | Proposed |
|---|---|---|
| F1 | A FIFO named `SKILL.md` hangs startup | Fix before merge, as in the Codex record |
| F2 | CI runs none of the package's tests | Fix before merge: a `make` target that runs the three test files, and it and `verify_skills_refusal` in CI |
| F3 | The sandbox flag and the real handler path are checked by nothing committed | Fix before merge: the startup probe prints the `config` record and dispatches one `Skill` call through the real host; one sandboxed and one unsandboxed case in the suite |
| F4 | The reserved key can reach the host from the operator's `ailang_tools.json` | Operator's call. Smallest: correct the ABI comment and the refusal message's wording, and record the path in Amendment 5 |
| F5 | The D7 guard sees "unset", not "set to something else" | Record as a stated limit of D7. No code change |
| F6 | Invalid UTF-8 and control characters are accepted | Operator's call: refuse control characters in a description under V6, or record it. Not a merge blocker |
| F7 | The symlink control does not check the index | Fix with the others: it is one assertion |
| F8 | The envelope copy is pinned to a literal | Follow-up: a live row in `registry_multiplicity_dst.ail` |
| F9 | While `test_dummy` keeps four comparisons red, a wrong `skills` pin would not change the exit status | No action here; it is one more reason to file the `test_dummy` issue |
