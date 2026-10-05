# LEG-R3 — the fixes the implementation review asked for (PR #213)

You are a delegate of the session that ran the review. You own exactly this assignment. You do
not edit the ADR or the plan, you do not push, and you do not touch other panes, tabs or
worktrees. This is a delegated task: carry it out without asking for confirmation.

## What this is

Two independent reviewers read the implementation at `4c9f9c25` and both said "merge after
fixes". Four findings hold the merge, and one more is a single assertion. The delegating session
reproduced all four. This assignment fixes those five things and nothing else.

## Where you work

Worktree `/workspaces/motoko_agent-skills`, branch `feat/skills-extension`. Verify both with
`git rev-parse HEAD` and `git branch --show-current` before you start. `git status --short`
should be empty. Commit on that branch as you go, in small commits. Push nothing.

Do not touch `/workspaces/motoko_agent` (the shared checkout), the two reviewers' worktrees
(`/workspaces/motoko_agent-review-astra`, `-review-fable`) except to read, or any other session's
paths. Put no credential in any file or output.

## Read first, in this order

1. `REVIEW-003-codex-gpt-6-astra.md` and `REVIEW-003-claude-fable-5.1.md` in this folder: the
   findings, how each was shown, and the delegating session's verification.
2. `ADR-001-skills-system.md`: D1 (R1 and V1 to V8), D2, D7, D13, and acceptance A3, A7, A8, A9.
3. `packages/motoko-ext-skills/register.ail`, `scripts/verify_skills_refusal.sh`,
   `scripts/verify_skills_startup.ail`, and the four `src/core/dst_driver_*.ail` profile modules.

Check every `file:line` below against your own HEAD before you rely on it.

## The fixes

**F-A. A `SKILL.md` that is not a regular file refuses; it does not hang.**
`read_entry` (`register.ail:92`) calls `readFileResult` on a listed `SKILL.md` without asking
whether it is a regular file. A named pipe blocks there until something writes to it.

- Guard the read with `isFile`, and report a non-regular `SKILL.md` as **V3**, "cannot be read",
  with a reason that says it is not a regular file. V3's text in the ADR already covers this; do
  not add a rule.
- A `SKILL.md` that is a relative symlink to a regular file inside the workdir must still load.
  If no fixture holds that, add one.
- Add a fixture to `scripts/verify_skills_refusal.sh`: `mkfifo` for `SKILL.md`, expecting exit 2
  and one error event naming V3 and the path. Put a timeout on the suite's start call so that a
  hang is a failed check with a clear message, not a stuck suite.
- Codex's reproduction is `/workspaces/motoko_agent-review-astra/.review/reproduce_fifo.py`.

**F-B. The package's tests run from a `make` target, and CI runs them.**
Nothing in CI and no `make` target runs `ailang test` on `packages/motoko-ext-skills/`, and
`verify_skills_refusal` is outside CI.

- Add a `make` target that runs `ailang test` on `skills.ail`, `a6b_test.ail` and `register.ail`
  and fails if any test fails or the count is zero.
- Have CI run it and `verify_skills_refusal` on every pull request, in
  `.github/workflows/verify-extensions.yml`. Add a step; do not change what `make check_core`
  runs, because every session's local baseline uses it. Update the `Makefile` comment that says
  the refusal suite is outside CI.

**F-C. The sandbox flag and the real handler path are checked by something committed.**
`let sandbox_set = true;` at `register.ail:345` passes all 91 tests and all 41 checks.

- `scripts/verify_skills_startup.ail` prints the registration's `config` record, and dispatches a
  `Skill` call through the real host and the live port. Fable's report (F3) names the calls it
  used: `dispatch_tool_handle` with `ext_ports_of(live_ports(rt), …)`.
- The suite then checks: under the sandbox the record says the sandbox was set; a valid skill
  loads and its result begins with the directory line; a name not in the index returns the error
  that lists the names; and one **unsandboxed** start with an absolute workdir that is not the
  process's directory returns D7's error on a `Skill` call.

**F-D. Each profile says which extensions it omits, not only how many.**
In `src/core/dst_driver_plus_herdr.ail` the id `skills` can be changed to `skills_typo` and all
three inline tests pass. None of the four profile modules has a test that names an omitted id.

- Add an inline test to each of the four modules that requires `skills` and `ailang_tools` to be
  in its omitted list by name. Add no entry and move no count or version: this adds a check, not
  a pin.

**F-E. The symlink control checks the index.**
`c3-relative-symlink-inside` (`scripts/verify_skills_refusal.sh:240`) checks that the session
starts with one schema. Make it also require the symlinked skill's name in the index.

## Out of scope: do not change these

The reserved key reaching the host through `ailang_tools`' config file; the D7 guard seeing
"unset" and not "set to something else"; invalid UTF-8 and control characters; the envelope copy
pinned to a literal; `test_dummy`; the layout issue. They are recorded in the review and are the
operator's to rule on. If a fix here cannot be made without touching one of them, stop and say so.

## Mutation check: required, and how a kill counts

For each of F-A, F-C, F-D and F-E, show that the new check fails when the rule is broken.

1. One mutant per rule you fixed, at least. The list comes from the fixes above, not from your
   tests. These four are required: the `isFile` guard removed; `sandbox_set` forced to `true`;
   the sandbox variable's name misspelt; `skills` renamed to `skills_typo` in each of the four
   profile modules.
2. Name, before the run, the committed check you expect to fail for each mutant.
3. A mutant is killed only when that named check fails. A compile error, a panic, a timeout or
   some other check failing is recorded as what it is, and is not a kill.
4. A survivor gets a new check, or one sentence saying why no input can tell the two apart.
5. Run it once, at your last commit, with the tests green on the unmutated source first. Restore
   the source after every mutant and end with a clean tree.

The earlier parts' mutation tables counted three sandbox-flag mutants as killed by an evidence
script that no gate runs. That is the gap F-C closes: the check that kills a mutant must be one
that is committed and run.

## The checks that end this

- The new `make` target and `make verify_skills_refusal` pass.
- `ailang test` passes on `src/core/ext/registry_normalize.ail` and on each of the four profile
  modules.
- The mutant table has no unexplained survivor.
- No gate is newly red against P6's table (`evidence/p6/GATES.tsv`). Run, one at a time:
  `check_core`, `profile_definition`, `driver_only`, `driver_plus_herdr`, `herdr_graded`,
  `driver_plus_no_ops`, `driver_plus_compose`, `ext_call_inventory`, `ext_ambient_inventory`,
  `declared_vs_performed`. `driver_plus_no_ops` and `driver_plus_compose` are red today on
  `test_dummy`; they must be red on the same line and no other. `evidence/p6/run_gates.sh` and
  `compare_logs.py` are there to reuse. The machine is shared: one heavy run at a time, and do not
  run `make dst`.

## Evidence, and what to send back

Put the evidence under `.agent/projects/037_skills_system/evidence/r3/` and commit it:
`README.md` as the report, `mutants.tsv` with the columns rule, change, check expected to fail,
exit and result, the script that ran the mutants, the gate logs, and the commit each was run at.

`README.md` says, for each fix: the commit, what changed, the check that covers it and its
mutants. Then the gate table against P6's, and anything you could not do and why. Say plainly
what you ran and what you only read.

When it is committed, reply with one line: the last commit and whether every check above passed.
