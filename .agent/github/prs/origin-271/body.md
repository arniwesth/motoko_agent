---
repo: arniwesth/motoko_agent
pr: 271
branch: docs/031-progress-guard-jev-addendum
ticket: null
title: "docs(031): addendum A — progress_contract_guard as a structured-decision consumer, on Jev 1.14"
---

## Summary

#270 narrows `progress_contract_guard`'s substring rules after the 2026-10-17 false nudge. The class of error remains. Deciding whether a stop is "finished", "asking the operator", "waiting on something else" or "stopped mid-task" is a semantic judgment, and ADR-001 (031) built the seam for it. This addendum to PLAN-001 proposes moving that one judgment to a typed `Choice` question answered by `typesafe/jev-1.14-20261014`. The structural checks stay deterministic in `prepare`: whether there is a contract, whether work is in flight or a wait is open, and the budget. When a query comes back `Unavailable`, the guard falls back to #270's rules, so a port under line R's stub behaves exactly as today.

Documents only. No code, no ABI change, and no change to line R.

## Changes

- docs(031): addendum A — progress_contract_guard as a structured-decision consumer, on Jev 1.14

2 files changed: the new addendum, and one cross-reference line in PLAN-001.

## Governing docs

- `.agent/projects/031_system_one_decisions/PLAN-001-implement-adr-001-abi-8.md`: line X (P1.3x, P1.4x, P2, P3), P4.1, §7 Q4, §8. The addendum extends line X and answers Q4 for this guard only.
- `.agent/projects/031_system_one_decisions/ADR-001-extension-owned-structured-decisions.md`: D2, D3, D5, D6, D7.
- `.agent/projects/031_system_one_decisions/PLAN-001-addendum-progress-guard-on-jev.md`: the addendum itself.

## Predicted outcome

Nothing changes at runtime. Merging records a proposal with five stages and five operator decisions (§6):

- **Can start now:** A0, the stub-backed port, and A1, a labelled set from the 25 past firings in 14 local sessions.
- **Waits on line X:** A2 (the binding), A3 (shadow) and A4 (enforce) follow P1.3x, P2 and P3.

The two changes A0 would bring are named up front: `ext_set_digest` moves, so pre-change sessions will not resume, and `interface_hash` moves, which 013's E-records pin.

## Test evidence

Every anchor was checked at `602e1e4e`:

- `packages/motoko-ext-abi/types.ail`: `:1983` `DecisionSolverJudge`, `:570-621` the vocabulary, `:871-894` `PureCtx`.
- `src/core/ext/runtime.ail`: `:311` the stub arm, `:369-380` `decision_invocation_state`, `:877` the finalize fold, `:1567` the digest test.
- `scripts/dst/phase_c2_wiring_scenarios.ail`: `:79` and `:277`.
- `evidence/plan004-v2/erecords/*.json`: `packages/19` pins `interface_hash` only.
- The count of 25 injections across 14 of 185 journals was computed from local `.motoko/sessions` on 2026-10-17.
- Jev 1.14's listing facts (release date, price, the 262K vs 32K context discrepancy) come from OpenRouter, ZenMux and the TypeSafe SDK guide, cited in the addendum. The SDK guide still documents 1.13, and the addendum says so.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
