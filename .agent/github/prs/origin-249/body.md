---
repo: arniwesth/motoko_agent
pr: 249
branch: docs/005-adr001-amendment-dp7-to-extension
ticket: null
title: "docs(005): propose Amendment 1 to ADR-001 — pre-finalize verification (DP7) moves to an extension"
---

## Summary

Proposes Amendment 1 to 005 ADR-001 (the harness policy boundary). Core's DP7 verifier runs a
profile's shell command after every non-blank final answer and rejects the answer when the command
fails, with no limit on how often. The amendment says that is finalize policy and moves it to a
bounded guard extension, together with the persist nudge.

Two sessions forced it. On 2026-10-08 and 2026-10-09 the verifier's command could not pass inside
a session, so it rejected every final answer, 320 and 57 times. The repetition guard was never
called, because a rejected candidate does not reach the extension judges.

**The amendment is a proposal. Merging this records it and does not accept it.** Six positions in
it are the operator's to confirm, and it lists six open questions. The two most likely to change:

- **No new core ceiling on finalize feedback (A6).** The amendment leaves the step budget, the cost
  cap and context exhaustion as the only ceilings in core.
- **Merge precedence is unchanged (A3).** `ContinueWithFeedback` still outranks `Accept`, so what
  ends a run is each continuing guard reaching its own bound.

On acceptance it supersedes text in 013 ADR-002 D2, 031 ADR-001 D4 and the DP7 design doc. The
amendment has a table naming each passage and what replaces it. None of those files is edited
here.

## Changes

- docs(005): propose Amendment 1 to ADR-001 — pre-finalize verification (DP7) moves to an extension

1 file changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`

## Predicted outcome

- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` lists the
  ADR and this pull request's own record, and nothing else.
- **The ADR carries a proposed amendment the operator can accept, edit or reject.** Acceptance is
  a later edit to the amendment's status line, not this merge.
- **If accepted, one plan follows.** `PLAN-finalize-policy-migration.md` covers the verifier
  guard, the persist-nudge guard, the removals from core, the migration of the eight profiles that
  enable verification, and the edits to 013 ADR-002 and 031 ADR-001.
- **The loop itself is not fixed by this.** The trigger is fixed by `69f7353a` on
  `fix/verify-native-path-guard-strip-sandbox`, a local branch that is not pushed and has no pull
  request. The unbounded rejection stays in core until the plan lands.

## Test evidence

Checked on 2026-10-09 at `36a96b1e`, AILANG v0.52.5.

- [x] **The verifier's command fails only inside a session's environment.** In this branch's clean
  worktree, `env -u AILANG_FS_SANDBOX make verify_native_path_guard` exits 0 with 6 `OK` lines.
  With `AILANG_FS_SANDBOX` set to the workdir it exits 2 with 4 `OK` and 2 `FAIL` lines, the same
  two the sessions' rejections carry.
- [x] **The counts in the amendment were computed from the two session logs.** 57 and 320
  `dp7_verifier_rejected` events, no `ext_solver_feedback` event in the 2026-10-09 log, 103 model
  calls and 16.8M input tokens after the first rejection, 679 KB of injected verifier output, and
  37 then 10 consecutive rejections with no tool call between them.
- [x] **Replaying the repetition guard's exact-text rule over the 2026-10-09 log** matches nothing
  in the first run and the third identical answer in the resumed run.
- [x] **Every `file:line` reference in the amendment was read at `36a96b1e`.**
- [x] **Before `a2113e85` an accepted candidate still went to the verifier.**
  `git show a2113e85^:src/core/session.ail` has `Accept(output) => c2_after_dp7(…)` at `:3723`.
- [x] **One file changed besides this record.** `git diff --name-only origin/main...HEAD`.
- [ ] The two session logs are not committed. They are in the shared checkout's gitignored
  `.motoko/logfile/`.
- [ ] No second reviewer has read the amendment.
- [ ] No code changed, so no gate was run. CI was not awaited.
- [ ] Why the delegate this session spawned (`session_1791533296010-1695c0abcc275cc3`) finished
  with no rejection under the same profile was not determined.
- [ ] The 2026-10-08 log was not checked for `ext_solver_feedback` events.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
