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
- **Self-report.** Bare `not done` matched the heading "What I have not done:". `not done` and `not complete` now match only where they describe the task: "is not done", "not done yet", "is not complete", "not yet complete", "not complete yet".

This is not the old core persist nudge coming back. That nudge's marker is `[motoko-persist-nudge]`, it was deleted in 005 W2 (#257), and the journal never shows it. The nudge came from this extension, which is where stop policy now belongs.

## Changes

- fix(progress_contract_guard): a contract comes from the operator, not a tool result

2 files changed: the guard module, and `ailang.lock`, where only this package's `content_hash` and the timestamp changed.

## Governing docs

- `.agent/projects/005_harness_policy_boundary/PLAN-progress-contract-guard.md`: the guard's design, including trap #1, which this widens.
- `.agent/issues/progress-guard-prose-heuristics-permit-premature-stop.md`: the module's earlier misfires, in the other direction.
- `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md` (companion PR): why this only narrows the rules, and where the semantic judgment should move.

## Predicted outcome

A session that calls `MotokoRuntimeStatus` and has no contract from the operator is no longer nudged when it stops. A stop that reports "what I have not done" is no longer read as mid-task. Contracts the operator states in the task or in user turns still fire the guard, as all 20 DST wiring scenarios show. The interface hash is unchanged, so 013's E-records, which pin `interface_hash`, are unaffected. Running sessions resume, because the registration is unchanged.

## Test evidence

- `ailang test progress_contract_guard.ail`: **24/24 passed**. The 20 existing tests are unchanged, plus 4 new ones:
  - `test_tool_result_is_not_a_contract`
  - `test_earlier_assistant_turn_is_not_a_contract`
  - `test_not_done_heading_is_not_incomplete`
  - `test_live_false_positive_does_not_nudge`, the 2026-10-17 shape end to end
- Mutation check, each old rule restored in turn, **4/4 killed**:
  - tool-role counts again → `test_tool_result_is_not_a_contract` red
  - assistant-role counts again → `test_contract_not_from_candidate_alone` and `test_earlier_assistant_turn_is_not_a_contract` red
  - bare `not done` → `test_not_done_heading_is_not_incomplete` red
  - bare `not complete` → `test_not_done_heading_is_not_incomplete` red
- `ailang run … scripts/dst/phase_c2_wiring_scenarios.ail` (the `phase_c_l1` target's third leg): `phase_c2_wiring_scenarios PASS count=20`.
- `ailang check progress_contract_guard.ail`: no errors.
- **Not run:** the full `make dst` sweep and CI's other gates. `src/core` is untouched, so `make check_core` and the contract policy do not apply.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
