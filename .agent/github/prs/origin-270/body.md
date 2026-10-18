---
repo: arniwesth/motoko_agent
pr: 270
branch: fix/progress-guard-contract-source
ticket: null
title: "fix(progress_contract_guard): a contract comes from the operator, not a tool result"
---

## Summary

On 2026-10-17, `progress_contract_guard` nudged a model that had stopped on purpose to ask the operator before running a probe ("it does write a probe directory, so I won't fire it unasked. Say the word and I'll run it"). The nudge made it run the probe unasked (`session_1792237668002-c09a3fc81a468129`, step 13). Two predicates had matched text that meant something else:

- **Contract.** The guard read contract words like `current_step` and `step_budget` from every role except the candidate. `MotokoRuntimeStatus` writes those field names into every result, so one status call made the whole session look contracted. Contracts now come from `ctx.task` and user-role messages only. Earlier assistant turns are excluded too: trap #1, widened. The AI compaction summary is assistant-role, and the task it quotes is `ctx.task`.
- **Self-report.** Bare `not done` matched the heading "What I have not done:". `not done` and `not complete` are now read with the retrospective headings blanked out first: "what I have not done", "what I've not done" (both apostrophes) and "what I have not completed". The first version narrowed the phrases instead and lost real reports. Review finding 1 below covers that.

This is not the old core persist nudge coming back. That nudge's marker is `[motoko-persist-nudge]`, it was deleted in 005 W2 (#257), and the journal never shows it. The nudge came from this extension, which is where stop policy now belongs.

## Changes

- fix(progress_contract_guard): a contract comes from the operator, not a tool result
- fix(progress_contract_guard): blank the heading, not the words (#270 review, finding 1)

2 files changed: the guard module, and `ailang.lock`, where only this package's `content_hash` and the timestamp changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PLAN-progress-contract-guard.md`: the guard's design, including trap #1, which this widens.
- `.agent/issues/progress-guard-prose-heuristics-permit-premature-stop.md`: the module's earlier misfires, in the other direction.
- `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md` (companion PR): why this only narrows the rules, and where the semantic judgment should move.

## Review (Codex `gpt-6.1-sol`, high): CHANGES-REQUESTED → finding 1 fixed, finding 2 deferred

- **Finding 1 (P2), fixed.** The narrowed phrases stopped nudging "I am not done with phase 3." and "I have not completed phase 3." under a real contract. Now only the heading is blanked, so both count again, and so does a real report next to a heading. `test_real_incomplete_reports_still_count` pins them.
- **Finding 2 (P1), deferred, and it predates this PR.** Under a real contract, a stop that hands a decision to the operator is still nudged when it also says `remaining`, `continue to` or `step N/M`. For example: "Work remaining: the probe writes a directory. I need your permission before running it. Say the word." This PR does not fix that. A substring rule that lets "asks for approval" stop the run would also let "Would you like me to continue?" through under "do not stop early", and that is the premature stop the guard exists to catch. Telling the two apart is the semantic judgment the companion addendum (#271) moves to a structured decision.
- The reviewer independently reproduced the four original mutant kills. It found no contract lost to compaction: structural compaction keeps user messages, and a scripted compaction scenario kept an earlier user contract. It confirmed the lock diff is this package's hash only.

## Predicted outcome

A session that calls `MotokoRuntimeStatus` and has no contract from the operator is no longer nudged when it stops. A stop that reports "what I have not done" is no longer read as mid-task. Contracts the operator states in the task or in user turns still fire the guard, as all 20 DST wiring scenarios show. The interface hash is unchanged, so 013's E-records, which pin `interface_hash`, are unaffected. Running sessions resume, because the registration is unchanged.

## Test evidence

- `ailang test progress_contract_guard.ail`: **25/25 passed**. The 20 existing tests are unchanged, plus 5 new ones:
  - `test_tool_result_is_not_a_contract`
  - `test_earlier_assistant_turn_is_not_a_contract`
  - `test_not_done_heading_is_not_incomplete`
  - `test_live_false_positive_does_not_nudge`, the 2026-10-17 shape end to end
  - `test_real_incomplete_reports_still_count`, review finding 1
- Mutation check, each old rule restored in turn, **4/4 killed**:
  - tool-role counts again → `test_tool_result_is_not_a_contract` red
  - assistant-role counts again → `test_contract_not_from_candidate_alone` and `test_earlier_assistant_turn_is_not_a_contract` red
  - bare `not done` → `test_not_done_heading_is_not_incomplete` red
  - bare `not complete` → `test_not_done_heading_is_not_incomplete` red
- Mutation check on the finding-1 fix, **4/4 killed**:
  - no heading strip → `test_not_done_heading_is_not_incomplete` red
  - back to the narrowed phrases → `test_real_incomplete_reports_still_count` red
  - the curly-apostrophe "what i’ve not done" entry dropped → `test_not_done_heading_is_not_incomplete` red
  - strip "not done" itself instead of the heading → both red
  - A fifth mutant survived at first. Dropping the "haven't done" entries changed nothing, because "haven't done" never contains "not done". Those entries were dead and are removed.
- `ailang run … scripts/dst/phase_c2_wiring_scenarios.ail` (the `phase_c_l1` target's third leg): `phase_c2_wiring_scenarios PASS count=20`.
- `ailang check progress_contract_guard.ail`: no errors.
- **Not run:** the full `make dst` sweep and CI's other gates. `src/core` is untouched, so `make check_core` and the contract policy do not apply.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
