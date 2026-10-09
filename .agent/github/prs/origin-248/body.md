---
repo: arniwesth/motoko_agent
pr: 248
branch: research/llm-test-value
ticket: null
title: "Preregister Motoko CI experiment for LLM-written unit tests"
---

## Summary

The linked post measures coding-task success when agents can or cannot write tests; it does not measure whether their tests protect future CI changes. This PR preregisters a paired Motoko experiment comparing existing CI, LLM-written unit tests, and LLM-written unit tests guided by development mutants against independently adjudicated held-out faults.

## Changes

- research: preregister Motoko LLM test value experiment

4 files changed.

## Governing docs

- `.agent/projects/040_llm_test_value/EXPERIMENT.md`
- `.agent/projects/040_llm_test_value/PROMPTS.md`

## Predicted outcome

The protocol fixes prompts, fault blinding, adjudication, sample size and decision thresholds before trial results exist. The scorer produces task-weighted detection estimates and an exact upper bound that prevents a zero-catch bootstrap interval from being read as proof of no value. A six-task calibration pilot can then be run, followed by a 60-task confirmatory sample if feasible; this PR reports no trial result.

## Test evidence

`python3 -m unittest discover .agent/projects/040_llm_test_value -p 'test_*.py'` — 5 passed. `python3 -m py_compile .agent/projects/040_llm_test_value/score.py .agent/projects/040_llm_test_value/test_score.py` — passed. `git diff --cached --check` — passed.
