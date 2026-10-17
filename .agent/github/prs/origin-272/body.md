---
repo: arniwesth/motoko_agent
pr: 272
branch: docs/031-addendum-a-v2
ticket: null
title: "docs(031): addendum A v2 — the six findings of the #271 review"
---

## Summary

#271 merged v1 of PLAN-001 addendum A, which proposes moving `progress_contract_guard`'s "what kind of stop is this?" judgment to a structured decision answered by `typesafe/jev-1.14-20261014`. Codex `gpt-6.1-sol` (high) reviewed v1 while it was open and returned **REVISE** with six findings. This is v2, and it takes all six. Two are design errors in v1: the budget rule handed back spent allowance, and every `Unavailable` fell back to the rules, so #270's finding 2 came back on every failure path. The other four tighten staging, privacy, an identity claim and a rationale.

Documents only. No code, no ABI change, and no change to line R.

## Changes

- docs(031): addendum A v2 — the six findings of the #271 review

1 file changed: `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md`. #271's merged PR record is left as it was.

| # | sev | finding on v1 | v2 |
|---|---|---|---|
| 1 | P1 | the budget's `min(own_count, interventions_used)` hands back spent allowance (two stub-era nudges, then a host counter starting at 0, read as 0 used) | §4.3: `max(own, host)` against `min(budget, limit)`; the host counter is authoritative from P1.4x; reconciliation never lowers known usage |
| 2 | P1 | every `Unavailable` falls back to #270's rules, so approval handoffs are nudged again on every failure path; reproduced through the finalize fold | §4.1: `UnconfiguredBackend` → rules (stub compatibility; finding 2 stays as today's known limit); live failures → abstain (decision D6); §5.2 puts the approval handoffs in A3's gate for `Answered` and every `Unavailable` reason; D3 caps the `Unavailable` rate |
| 3 | P2 | A2's recorded live exchange came before the shadow run, against PLAN-001 §8; prerequisites incomplete | §5: A2 is offline against P3.1's scripted provider double; the first live call is in A3; A3 depends on A0–A2, P1.4x, P2G and P3G |
| 4 | P2 | A1 put session content under tracked evidence, against PLAN-001 §0.9 | §5.1: private, synthetic and aggregate tiers; only synthetic and aggregate are committed; decision D7; #270's near-verbatim fixture is replaced in A0 |
| 5 | P2 | `interface_hash` does not move on a registration-only change; reproduced by re-locking a copy | §4.2: `content_hash` moves; `interface_hash` moves only if `ailang.toml` does; PLAN-004 coordination is conditional |
| 6 | P3 | the pin's rationale misstated strict replay | §3: replay uses the recorded binding (ADR-001 D6); the pin keeps live evaluations about one known model |

The review's two near-miss anchors are corrected (`types.ail:1981`, `runtime.ail:1578`). A0 also gains a registration-level scenario, because the existing DST scenarios call `decide_with_budget` directly and do not exercise `register.ail`. The review raised that point among its verification notes.

## Governing docs

- `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md`: §0.9 (privacy), §1a (lines R/X), P1.3x, P1.4x, P2G, P3.1–P3.3, P3G, P4.1, §7 Q4, §8 (no live inference before a shadow run).
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`: D2, D3 (explicit absence, no identifiers on the wire), D5 (retained interventions), D6 (query identity and replay), D7 (digest).
- `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md`: the addendum, v1 as merged in #271.

## Predicted outcome

Nothing changes at runtime. The addendum on `main` becomes v2: five stages and **seven** operator decisions (§6). D6 (abstain on live `Unavailable`) and D7 (A1's private tier) are new. A0 (the stub-backed port) and A1 (the labelled set, in tiers) can still start now. A2 (offline), A3 (shadow, the first live call) and A4 (enforce) wait on line X.

## Test evidence

- **Review of v1:** Codex `gpt-6.1-sol` at high effort, read-only and unsandboxed. It returned REVISE with the six findings above. Findings 2 and 5 and the `ext_set_digest` claim were reproduced on temporary copies, and its `git status` was clean afterwards. It confirmed every other anchor and link at `602e1e4e`, the D3 fit of the Choice question, and the Jev 1.14 facts against OpenRouter, ZenMux and the SDK guide.
- **v2 anchors:** re-checked at `602e1e4e`. `types.ail:1981` is `| DecisionSolverJudge(`, and `runtime.ail:1578` is `ext_set_digest_sees_the_decision_variant_test`. The package's `[effects] max` is declared in its `ailang.toml`, which is consistent with finding 5.
- **Not done:** v2 has not been re-reviewed. Nothing here was executed: the design is a plan, and A0's tests are its first executable evidence.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
