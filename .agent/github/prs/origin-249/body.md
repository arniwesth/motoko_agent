---
repo: arniwesth/motoko_agent
pr: 249
branch: docs/005-adr001-amendment-dp7-to-extension
ticket: null
title: "docs(005): Amendment 1 to ADR-001 and its plan — pre-finalize verification (DP7) leaves core"
---

## Summary

Proposes Amendment 1 to 005 ADR-001 (the harness policy boundary). Core's DP7 verifier runs a
profile's shell command after every non-blank final answer and rejects the answer when the command
fails, with no limit on how often. The amendment says that is finalize policy and removes it from
core. The persist nudge moves to a guard extension in the same plan.

Two sessions forced it. On 2026-10-08 and 2026-10-09 the verifier's command could not pass inside
a session, so it rejected every final answer, 320 and 57 times. The repetition guard was never
called, because a rejected candidate does not reach the extension judges.

**Rewritten on 2026-10-09 to the operator's ruling.** The first draft moved the verifier into a
guard extension and asked which profiles should ship it. The ruling: none, and nothing should
trigger Motoko's own `make check_core` automatically. So the verifier is removed and no guard
replaces it. The amendment keeps only the rules a verifier guard would have to respect if one
were ever written. #251 turns the verifier off in the eight profiles that enabled it.

**The plan is here too.** `PLAN-finalize-policy-migration.md` has two workstreams:

- **W1 removes the verifier from core** in ten work items. It is ready to start: #250 and #251
  merged on 2026-10-09.
- **W2 is the persist nudge, and it is not ready.** Planning found that its budget is an
  environment read that recorded runs and the evaluation's fixtures count, and that nothing
  outside tests sets it. The plan recommends deleting it instead of migrating it, and asks.

The plan needs four decisions from the operator, listed in a table at its top.

**The amendment is a proposal. Merging this records it and does not accept it.** One open question
remains, about a field of the extension ABI that 031 ADR-001 defines. The two positions most
likely to change:

- **No new core ceiling on finalize feedback (A6).** The amendment leaves the step budget, the cost
  cap and context exhaustion as the only ceilings in core.
- **Merge precedence is unchanged (A3).** `ContinueWithFeedback` still outranks `Accept`, so what
  ends a run is each continuing guard reaching its own bound.

On acceptance it supersedes text in 011 ADR-003 (one control run), 013 ADR-002 D2, 028 ADR-001,
031 ADR-001 D4, the DP7 design doc and one sentence of `SYSTEM.md`. The amendment has a table
naming each passage and what replaces it. None of those files is edited here.

## Changes

- docs(005): propose Amendment 1 to ADR-001 — pre-finalize verification (DP7) moves to an extension
- docs(005): Amendment 1 names #250 as the Makefile fix, in place of the unpushed commit
- docs(005): Amendment 1 follows the operator's ruling — the verifier is removed, not moved
- docs(005): plan for Amendment 1 — remove the DP7 verifier; the persist nudge waits on two decisions

2 files changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/ADR-001-harness-policy-boundary.md`
- `.agent/projects/005_harness_policy_boundary/PLAN-finalize-policy-migration.md`

## Predicted outcome

- **Nothing a session does changes.** Checked: `git diff --name-only origin/main...HEAD` lists the
  ADR and this pull request's own record, and nothing else.
- **The ADR carries a proposed amendment the operator can accept, edit or reject.** Acceptance is
  a later edit to the amendment's status line, not this merge.
- **W1 of the plan can start from `main` once this has merged.** It is one pull request touching
  `src/core`, seven DST scripts, the `Makefile`, `SYSTEM.md` and five records.
- **W2 does not start until the operator answers the plan's decisions 3 and 4.**
- **The loop itself is not fixed by this.** #250 fixed the trigger and #251 turned the verifier
  off in every tracked profile; both are merged. Its code stays in core until W1 lands.

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
- [x] **028 ADR-001's finalization item and item 1 of its PLAN-001 were read at `36a96b1e`.**
  The ADR is Proposed, and `run_dp7_verifier` still has `Err(_) => Approve`, so the item was not
  built.
- [x] **Every `file:line` reference in the plan was read at `36a96b1e`.**
- [x] **The session journal holds no verifier rejection.** The journal of the 2026-10-09 session
  has six record kinds: `header`, `run_started`, `history_appended`, `state_delta`, `exit` and
  `resumed`.
- [x] **The evaluation's protected manifest already refuses `main`.** `python3
  tools/eval_protected/protected.py check --manifest tools/eval_protected/manifest-A.json --tree
  HEAD` at `36a96b1e`: 119 spans, 2 findings, one of them `session.ail`'s import region.
- [x] **Nothing sets `MOTOKO_PERSIST_RETRIES` outside tests.** `git grep` over the `Makefile`,
  `.github`, `.motoko`, `tools`, and the evaluation's scripts finds only DST scripts and a
  fixture generator.
- [x] **Two files changed besides this record.** `git diff --name-only origin/main...HEAD`.
- [ ] The plan's W2 replay question (what a stored program does when the driver makes one read
  fewer) was not measured. It is W2's first work item.
- [ ] The plan was not reviewed by a second reader, and no work item was tried.
- [ ] The two session logs are not committed. They are in the shared checkout's gitignored
  `.motoko/logfile/`.
- [ ] No second reviewer has read the amendment.
- [ ] No code changed, so no gate was run. CI was not awaited.
- [ ] Why the delegate this session spawned (`session_1791533296010-1695c0abcc275cc3`) finished
  with no rejection under the same profile was not determined.
- [ ] The 2026-10-08 log was not checked for `ext_solver_feedback` events.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
