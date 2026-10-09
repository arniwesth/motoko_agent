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

- **W1 removes the verifier from core** in nine work items. It is ready to start: #250 and #251
  merged on 2026-10-09.
- **W2 deletes the persist nudge completely**, its environment read included, and builds no
  guard. The operator decided that on 2026-10-09: it is off by default, so it has not run for a
  long time. Planning found that the read still runs in every session and that DST tables and
  the evaluation's fixtures count it. Nothing stored depends on it, so the removal is safe and
  wide. W2 follows W1.

No decision is left open. The operator answered all four on 2026-10-09 and the plan records
them:

- The corpus gate's `verifier-rejection` control is replaced by a `solver-feedback` control.
- The persist nudge is deleted in full, its environment read included.
- A profile that still sets `verification.enabled` is not handled here. After W1 the key is read
  and ignored. What the host does with config entries it does not use gets its own pull request.

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

## Review

Codex Sol (GPT-6.1-Sol) reviewed the plan on 2026-10-09 at `f9a7c89c`, in a detached checkout,
from a brief that gave it none of the author's conclusions. It ran for 17 minutes and restored
its checkout. **Its verdict: revise before implementing.** Followed literally, the plan left
compile failures, failing gates and a vocabulary change with no version change.

Each finding was reproduced against the code before anything was changed. All eight hold, and
all eight are fixed in the plan.

| # | Finding | How it was reproduced | What changed |
|---|---|---|---|
| 1 | WI-7 removed a block holding six scenarios but only four list entries, and left `f6`/`r6` and two imports behind | Read `phase_c2_wiring_scenarios.ail:1141-1391` and `ledger_parity_dst.ail:632-638` | WI-7 deletes five scenarios and keeps one, fixes the final checks and counts, and names two wrapper scripts that pin nine |
| 2 | Two inline tests in `dst_event_vocabulary.ail` still asserted 45 rows | Read `:863` and `:929` | WI-4 |
| 3 | W2's checklist missed the `ledger_parity` order strings and the depth canary's record pins | Read `ledger_parity_dst.ail:616`, `:619` and `run_depth_canary.sh:172`. The reviewer ran both targets red. | W2-1 and W2-4 |
| 4 | Deleting a wire variant is a vocabulary version change, and the plan made none | Read `dst_event_vocabulary.ail:117-121`, 009 ADR-001 D6 and `dst_profile.ail:1568` | WI-4 moves the version to `event-vocabulary/2` and W2-2 to `/3`; six pinned strings follow |
| 5 | Deleting the code-graph rule breaks three pinned counts that no gate runs | Read `test_event_subjects.py:38` and `validate_overlay.py:45`; found no `make` target or CI job for them | WI-4 moves the pins; WI-10 runs the test by hand |
| 6 | W2 did not name the `CandidateNudge` arm, an exported session helper, three local helpers, several tests and three inventory entries | Read each cited line | W2-2 |
| 7 | 013 ADR-004's settings and read-count tables still require the removed behaviour | Read `:604-611` and `:966` | WI-9, W2-6, and the amendment's table |
| 8 | The driver has twelve environment keys, not eleven; the vocabulary's callers were misnamed | Counted `dst_discovery.ail:224-236`; listed callers with `git grep` | *Verified state* and W2 |

Its four opinions were also taken: land the variant's deletion in one commit with the script
edits, drop "they share no code", make the attribution re-baseline explicit (six files and three
re-issued DST profiles), and add the targets only CI runs.

**One choice in the fixes is the author's, not the reviewer's.** 009 ADR-001 D6 says old traces
are either still decoded or read by a pinned runner. The plan pins a runner, because the tree has
no decoder for wire events. That is the operator's to overrule.

**What the review confirmed.** The verifier's structure and ordering; that the journal holds no
rejection, environment read or nudge count; the two sessions' rejection counts; that no contract
register entry is affected; and that every `make` target the plan names exists. It also built
the `solver-feedback` control: it passed `make corpus_judge`, its mutant went red on both named
rules, and the same mutant passed with the control removed.

**What the review did not do.** It implemented neither workstream in full and did not run
`make dst`, `eval_matrix`, `check_core`, the contract gates, `corpus_pr` or a live session.

## Changes

- docs(005): propose Amendment 1 to ADR-001 — pre-finalize verification (DP7) moves to an extension
- docs(005): Amendment 1 names #250 as the Makefile fix, in place of the unpushed commit
- docs(005): Amendment 1 follows the operator's ruling — the verifier is removed, not moved
- docs(005): plan for Amendment 1 — remove the DP7 verifier; the persist nudge waits on two decisions
- docs(005): the plan and PR #249 record note that #250 and #251 have merged
- docs(005): the persist nudge is deleted outright — the operator's decision, in the amendment and the plan
- docs(005): the plan records the operator's confirmation — the persist nudge goes in full, its read included
- docs(005): the corpus gate's control moves to the solver-feedback branch — the operator's decision
- docs(005): W1 does not handle a leftover verification.enabled — unused config entries get their own PR
- docs(005): re-wrap one line in Amendment 1's follow-on
- docs(005): the plan takes Codex Sol's review — eight findings, all reproduced and fixed

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
- **W2 follows W1 as its own pull request.** Its first item removes only the read in a scratch
  tree and lists what goes red, before the wide edit.
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
- [x] **Nothing stored records the persist-nudge budget.** The 2026-10-09 journal's header has no
  such field, `journal.ail:2288-2290` recomputes the count from history, and no stored execution
  program is committed. Six evidence logs name the key; they are records.
- [ ] What goes red when the read is removed was not run. It is W2's first work item.
- [ ] No work item was implemented in full. The reviewer tried parts of WI-4, WI-7 and WI-8 and
  the read removal in W2, in a scratch checkout.
- [ ] The two session logs are not committed. They are in the shared checkout's gitignored
  `.motoko/logfile/`.
- [x] **A second reader reviewed the plan.** Codex Sol, see *Review*. The amendment itself was in
  its reading but was not the subject of the review.
- [ ] No code changed, so no gate was run. CI was not awaited.
- [ ] Why the delegate this session spawned (`session_1791533296010-1695c0abcc275cc3`) finished
  with no rejection under the same profile was not determined.
- [ ] The 2026-10-08 log was not checked for `ext_solver_feedback` events.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
