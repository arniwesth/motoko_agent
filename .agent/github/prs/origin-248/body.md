---
repo: arniwesth/motoko_agent
pr: 248
branch: research/llm-test-value
ticket: null
title: "Preregister Motoko CI experiment for LLM-written unit tests"
---

## Summary

Kun Chen's post and follow-up question the value of tests agents write on their own initiative, including after mutation feedback. This PR preregisters a Motoko trial that measures immediate coding success separately from future CI fault detection. Agents implement the same tasks with tests forbidden, normally allowed, or mutation feedback available. Their spontaneous test changes are evaluated against independently adjudicated held-out faults on a fixed correct implementation. No LLM trial result is claimed.

## Design

- The evaluator constructs a runnable baseline from correct source/configuration and **pre-change test files**, so the historical task's own tests cannot mask agent-added catches or conflict with test diffs.
- Unit-only and integration-only test changes are classified before faults are unsealed and run separately. Unit detection is the primary outcome; integration detection is secondary.
- A fixed 80-task confirmatory sample is selected before agent runs. Each arm has its own assessable-fault denominator; direct arm comparison uses the shared assessable set. Clean failures and patch conflicts earn zero, while infrastructure-inconclusive runs are reported and excluded from the affected arm.
- The scorer reports task-weighted catches, catch overlap, baseline and control outcomes, coding-arm success with exact McNemar comparison, costs, bootstrap intervals and an exact any-catch upper bound. A negligible-gain decision requires at least 60 scored tasks and an upper bound below 5%.
- Coding sandboxes contain a synthetic one-commit Git origin, preserving repository worktree instructions without exposing the historical fix. Reviewer A/B labels are randomized and sealed until adjudication.

## Governing docs

- `.agent/projects/040_llm_test_value/EXPERIMENT.md`
- `.agent/projects/040_llm_test_value/PROMPTS.md`

## Test evidence

`python3 -m unittest discover .agent/projects/040_llm_test_value -p 'test_*.py'` — 8 passed. `python3 -m py_compile .agent/projects/040_llm_test_value/score.py .agent/projects/040_llm_test_value/test_score.py` — passed. `make check_core` — 60 core files type-checked, 0 failed. `git diff --check` — passed.
