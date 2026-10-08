---
repo: arniwesth/motoko_agent
pr: 236
branch: docs/readme-pbt-and-logical-faults
ticket: null
title: "docs(readme): name the DST scope as logical faults, and mention property-based testing"
---

## Summary

A follow-up to #233, asked for by the operator on 2026-10-08. The README did not mention
property-based testing, and it did not say that the simulation covers logical faults only. It now
says both: the simulated faults are the ones at the agent's own boundary, hardware and network
faults are not simulated, and contracts also run as property tests on generated inputs.

## Changes

- docs(readme): name the DST scope as logical faults, and mention property-based testing

1 file changed.

## Governing docs

- `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md`: D1, the
  target method is "single-actor, logical-fault DST", with physical faults and several actors out
  of scope by decision. D3, the naming rule.
- `.agent/projects/011_improve_test_axises/ADR-001-adopt-program-shrinking.md`: Proposed, which
  is why shrinking is listed as a limit.
- `.agent/projects/027_z3_contracts/FINDINGS-implementation.md`: F4, an `ensures` also becomes a
  generated property test.

## What changed in the README

| Where | Change |
|---|---|
| Opening paragraph | Two sentences: the simulated faults are logical ones at the agent's boundary, and hardware and network faults are not simulated |
| Key Features | "Fault injection" becomes "Logical fault injection" and says no hardware or network faults. The contracts bullet adds that `ailang test` runs a contract as a property test on generated inputs, where it can build the arguments |
| Deterministic Simulation Testing | One paragraph: this is single-actor, logical-fault DST; physical faults and several actors are out of scope; the invariant families are properties in the property-based-testing sense, and DST differs in generating whole executions. A link to 007 ADR-001 |
| Limits | The simulation-boundary line names physical faults and several actors. A new line says a failing run is not minimized |

## The name

The operator proposed "logic-based Deterministic Simulation Testing", to stress that hardware and
network errors are not simulated, and on 2026-10-08 chose "logical-fault" for it: the term 007
ADR-001 D1 adopted, and one that cannot be read as formal logic next to the Z3 material. The title
and the section heading are unchanged. 007's D3 says the name "logical-fault DST" is available once
its D2 bar is met; no record was found that declares the bar met, and the merged README already
uses "DST" without a qualifier.

## Predicted outcome

- **A reader expecting FoundationDB-style fault simulation is corrected in the first paragraph.**
- **No build, test or gate result changes.** The diff is one markdown file.
- **Nothing a session does changes.**

## Test evidence

Run on 2026-10-08 in the branch's worktree at `b07e760f`, AILANG v0.47.2.

- [x] **`ailang test src/core/context_limit.ail`** prints contract-derived property tests:
  `raw_window_of_property_1 (100 cases)`, `working_budget_for_ext_property_2 (100 cases)`, and
  one skipped, `working_budget_for_ext_property_1 (1 cases)`. The README says "where it can build
  the arguments" for that reason.
- [x] **No shrinker exists.** A search of `src/core`, `scripts/dst` and the `Makefile` for
  `ddmin`, `shrink_program` and `minimize_program` finds nothing, and 011 ADR-001 is Proposed.
- [x] **Every relative link in the README resolves**, the new link to 007 ADR-001 included.
- [ ] **No record was found that 007's D2 bar has been declared met.** Searched 009's final
  acceptance note and ADR, and the DST report and its scope notes.
- [ ] **CI was not awaited.** The change is documents only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
