---
repo: arniwesth/motoko_agent
pr: 306
branch: docs/improving-experimentation
ticket: null
title: "docs(042): propose improving Motoko experimentation methods"
---

## Summary

Creates project 042 to investigate whether Motoko can improve how it chooses experiments and diagnoses failures, then carry those improvements into unfamiliar investigations. The proposed first experiment studies why existing tests miss defects and compares successive investigation methods under the same foundation model and comparable budgets.

## Changes

- Add a project overview and first milestone.
- Record the proposed experiment, evaluation criteria, evidence boundaries, and open design questions.
- Distinguish better investigation outcomes from an improved ability to discover subsequent method improvements.

## Governing docs

- `.agent/projects/042_improving_experimentation/README.md`
- `.agent/projects/042_improving_experimentation/RESEARCH-improving-experimentation.md`
- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md`

## Predicted outcome

The research direction becomes a discoverable project with a bounded starting experiment and explicit criteria for judging progress. Review should establish that the proposal separates hypotheses from achieved capabilities, accounts for development and evaluation costs, and preserves independent acceptance evidence. This PR changes documentation only.

## Test evidence

- Python local-link validation: all 8 links across the two project documents resolve.
- `git diff --cached --check`: passed before committing the documents.
- `make check_core`: passed, including prerequisite runtime checks and 61 core files type-checked with 0 failures. AILANG emitted an existing skills-package lock-content warning; the check completed successfully and this PR does not alter the lockfile.
