---
repo: arniwesth/motoko_agent
pr: 273
branch: docs/034-plan-001
ticket: null
title: "docs(034): ADR-001 accepted as amended; PLAN-001 for effect disclosure"
---

## Summary

ADR-001 for project 034 (effect disclosure for tool faults) moves from Proposed to **Accepted, as amended**. Before the operator ruled on 2026-10-17, it was re-grounded at `e69aaad7` on AILANG v0.52.5. The PR adds that re-grounding, the operator's five rulings, probe evidence on the pinned binary, and **PLAN-001**: 24 tasks with a `dagr` graph. Phase 0, the live change that gives every tool fault the model reads a `fault` object with `effects: none | unknown`, is ready to implement. Docs and evidence only; no source changes.

## Changes

- docs(034): ADR-001 accepted as amended; PLAN-001 for effect disclosure

6 files changed.

- **ADR-001**
  - The status line now reads Accepted.
  - §6 *Rulings* records the operator's five rulings:
    1. D1–D9 accepted as amended.
    2. `NotAllowed` → `none`.
    3. `PermissionDenied` → `unknown`.
    4. The upstream asks are filed.
    5. The deterministic suites are the eval baselines.
  - Each affected decision has a "Ruled" note.
  - §7 records the re-grounding: anchors that moved, and facts the ADR did not have. Two examples: P3 is not covered by 011's `DriverStepRepeated`, and P1/P3 move `invariant-set/2` → `/3`.
- **evidence/start_probe.sh** (new): cases 13–21, `NotAllowed` and `PermissionDenied`.
- **evidence/RESULTS-v0.52.5.md**: cases 1–21 on v0.52.5. The upstream state is also recorded: v0.54.14 kills the process group on timeout.
- **PLAN-001-effect-disclosure.md** and **PLAN-001.dagr.json**:
  - Workstreams W0, W0b and W1–W3, one per ADR phase.
  - Phase 0's mutants (m01–m15) and live witness rows are named in advance.
  - Five choices the ADR left open (C1–C5) are argued. C1 keeps `tool_phase.ail` out of Phase 0, so the anchor/profile-hash cascade is paid once, in Phase 1.
- **NOTE**: the status line points at the accepted ADR.

Filed upstream the same day, under ruling 4: sunholo-data/ailang#1878, #1879, #1880.

## Governing docs

- `.agent/projects/034_ambiguous_tool_outcomes/ADR-001-effect-disclosure-for-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/NOTE-scope-effect-unknown-tool-faults.md`
- `.agent/projects/034_ambiguous_tool_outcomes/PLAN-001-effect-disclosure.md`
- `.agent/projects/034_ambiguous_tool_outcomes/evidence/RESULTS-v0.52.5.md`
- `.agent/meta-decisions/mutate-each-stated-rule-once-and-see-its-test-fail.md`
- `.agent/projects/008_docs_system/ADR-001-plan-structure-in-dagr-and-retiring-linear.md` (D2, D3: plan structure lives in the dagr document)

## Predicted outcome

- **Code:** none from this PR.
- **The plan becomes the work queue.** Tasks are addressed as `034/PLAN-001/<id>`, and `W0.1` (record the `make dst` and `make eval_matrix` baseline) is the first ready task.
- **How it will be checked:**
  - A reader can find every ruling in ADR §6.
  - A reader can reproduce every measured claim with the two evidence scripts.
  - `dagr check --strict` stays clean on the graph.
- **What would show the plan wrong:** Phase 0's own gate, W0.7, finding a changed DST or eval-matrix row beyond the ones the plan lists.

## Test evidence

- `dagr check .agent/projects/034_ambiguous_tool_outcomes/PLAN-001.dagr.json --strict` → `✓ clean — 24 tasks, 0 attempts, 0 events` (dagr 0.3.1).
- `bash .agent/projects/034_ambiguous_tool_outcomes/evidence/exec_probe.sh` on AILANG v0.52.5 (`7200786`):
  - cases 1–12 match the v0.47.2 results recorded in the NOTE and ADR;
  - the full table is in `RESULTS-v0.52.5.md`.
- `bash .agent/projects/034_ambiguous_tool_outcomes/evidence/start_probe.sh` on v0.52.5:
  - cases 13–14 return `NotAllowed` with no launch trace;
  - cases 15–17 and 20–21 return `PermissionDenied`, and the target program never ran;
  - cases 18–19 return `Ok`.
- Standalone reproductions for the upstream issues were run on v0.52.5. One case is new: exit 7 with a held pipe returns `Ok exitCode=7`, while exit 0 with a held pipe returns `SpawnFailed`. This is recorded in `RESULTS-v0.52.5.md`.
- No source changed, so `make check_core` / `make dst` were not run. Phase 0's W0.1 records them as the baseline.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
