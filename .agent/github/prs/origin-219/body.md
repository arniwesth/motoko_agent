---
repo: arniwesth/motoko_agent
pr: 219
branch: docs/meta-decision-one-mutant-per-rule
ticket: null
title: "docs(meta): mutate each stated rule once and see its test fail"
---

## Summary

Adds a standing discipline: a test covers a rule only when breaking that rule makes the test fail.
For each rule a decision document states and a test claims to cover, the author changes the source
to break that rule, names the test that should notice, and counts the mutant as killed only when
that test fails.

It comes from project 037, where two delegates ran mutation checks that nobody had asked for (55
and 45 mutants, all killed). The operator wants the practice to be the rule. This document sets its
extent: one mutant per stated rule, run once per part, not mutation coverage of the code and not a
CI gate.

## Changes

- docs(meta): mutate each stated rule once and see its test fail

1 file added: `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`.

## Governing docs

No `.agent/projects/` document governs this; it is itself a standing discipline. It builds on:

- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  (rule 5: pair mutation with a case that must survive)
- `.agent/meta-decisions/re-ground-inherited-anchors-before-building.md`

Its evidence is in `.agent/projects/037_skills_system/evidence/p3/` and `evidence/p4/` on branch
`feat/skills-extension` (draft PR #213), which is not on `main`.

## Predicted outcome

- A part whose acceptance rests on tests hands in a `mutants.tsv` whose rows name the rule, the
  change and the test expected to fail, with the script and the commit it ran at.
- A mutant that only fails to compile, panics, or trips some other test is no longer counted as
  killed. Both of 037's scripts count at least one of those today.
- A surviving mutant shows up in the evidence as a new test or a stated reason.

Nothing enforces this: it is a discipline carried in plans and briefs, and it applies to parts
briefed after it is adopted. Checked by reading the evidence of the first part that follows it.
The document names a shared runner as the thing that would make it cheap to follow, and says it is
not built.

## Test evidence

A document; no code changed and no gate was run.

- [x] **The motivating facts were read from the 037 branch.** P3: 55 mutants, 55 killed, run at
  `928009c4`, with one of them (`m06`) counted as killed by a divide-by-zero panic. P4: 45
  mutants, 45 killed, 18:31 to 18:52 UTC on 2026-10-04.
- [x] **Nobody asked for them.** The word "mutant" or "mutation", in this sense, does not appear in
  037's ADR, plan, orchestrator handoff, the P3 and P4 briefs, or the two task prompts.
- [x] **The cited lines exist at `b863ee20`.** `Makefile:1601`–`1602` is the DST suite's
  "single-field mutation per rule, each asserting ITS OWN rule".
- [ ] **Not yet applied to a part.**
