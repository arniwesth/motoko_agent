---
repo: arniwesth/motoko_agent
pr: 315
branch: arniwesth/042-preregistered-comparison
ticket: null
title: "docs(042): NOTE-001, running a pre-registered comparison of two methods"
---

## Summary

042's research direction asks for an incumbent and a candidate method to be compared "on fresh tasks" with the evidence kept credible. It leaves the protocol to be specified before a pilot runs. Project 043 built one for its trial of Lean against executed checks (`PLAN-001`, PR #314). This note extracts that protocol for the next comparison. It sets out the parts the result depends on, maps them onto 042's "Keeping the evidence credible", and records what running it on this machine taught.

043's trial is still running: planting, sealing and the first batch are done. So the note says plainly that the protocol has run, but not yet produced a result.

## Changes

- docs(042): NOTE-001, running a pre-registered comparison of two methods

1. **`NOTE-001-preregistered-method-comparison.md`**, new:
   - **When it is worth it**, with 043's cost.
   - **The protocol in nine parts**, each naming the failure it prevents:
     1. two named hypotheses;
     2. a decision rule fixed before the answer key exists;
     3. predictions with probabilities;
     4. freezing everything by hash and logging every deviation;
     5. arms that differ only in method, with replicates;
     6. an answer key planted by a separate session and sealed under the operator's passphrase;
     7. blinding, enforced where possible and audited where not;
     8. scoring by reproduction command;
     9. a dry run that does not count.
   - **A table against 042's principles.** It states that transfer is not covered.
   - **What running it taught**, one row per problem met in 043:
     - deny rules are not a sandbox;
     - leak channels: other panes through `herdr`, the public upstream code, jest's transform cache, a sibling session pushing to the same branch;
     - the passphrase step needs a real terminal;
     - clocks died with the operator's session;
     - a container restart dropped the arms' deny rules;
     - eight sessions froze the container;
     - the plan had no rule for an interrupted batch.
   - **A lighter version.**
   - **Where it falls short** of the research direction.
   - **Starting points:** 043's plan, record and scripts, and the separate pre-registration in PR #248.
2. **`README.md`**: one entry in the document list.

2 files changed.

## Governing docs

- `.agent/projects/042_improving_experimentation/RESEARCH-improving-experimentation.md`, the direction this note serves (unchanged)
- `.agent/projects/042_improving_experimentation/NOTE-001-preregistered-method-comparison.md`
- `.agent/projects/042_improving_experimentation/README.md`
- `.agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md`, the source (on PR #314)

## Predicted outcome

Nothing in the harness changes. The next experiment that compares two methods, including 042's first, starts from a written protocol and a list of known traps, not from scratch.

Two things will need follow-up:
- **When 043's trial reaches its decision:** a dated update to the note's status, saying whether the protocol produced a usable result and what it cost in the end.
- **Until PR #314 merges:** the note's three links into `043_lean_harness_properties/` do not resolve on `main`. Merging this first is harmless; the links resolve once #314 lands.

## Test evidence

**1. Files changed.** Only project 042: `git diff --name-only origin/main...HEAD`

```
.agent/projects/042_improving_experimentation/NOTE-001-preregistered-method-comparison.md
.agent/projects/042_improving_experimentation/README.md
```

**2. Links.** Every relative link in the note and the README, checked on this branch and on PR #314's branch (`yes`/`no` = the target exists):

```
this branch  #314  target
yes          yes   design_docs/planned/m-motoko-dst-recursive-self-improvement.md
no           yes   .agent/projects/043_lean_harness_properties/PLAN-001-trial-lean-against-differential-checks.md
no           yes   .agent/projects/043_lean_harness_properties/trial/scripts
no           yes   .agent/projects/043_lean_harness_properties/trial/sequence.log
yes          no    .agent/projects/042_improving_experimentation/NOTE-001-preregistered-method-comparison.md
yes          no    .agent/projects/042_improving_experimentation/RESEARCH-improving-experimentation.md
```

The last two are `no` on #314 only because that branch was cut before #306 merged.

**3. Facts, read against the record.** Every number and event in the note comes from 043's `PLAN-001` or `trial/sequence.log` on PR #314:
- **The planter:** started 22:19:38Z, finished 23:32Z, about 70 minutes.
- **The dry run:** 20 minutes per arm. It led to four changes and found three real defects (K8–K10, amendment A3).
- **The freeze:** the arms' last tool calls were 4 to 7 minutes in, and the container restarted at 15:57:37Z.
- **The watchdog:** limits of 6 GiB and 3 GiB.
- **Predictions:** D 0.60, L 0.25, X 0.15.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
