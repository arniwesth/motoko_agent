---
repo: arniwesth/motoko_agent
pr: 236
branch: docs/readme-pbt-and-logical-faults
ticket: null
title: "docs(readme): logical-fault DST, property-based testing, and a section on why AILANG"
---

## Summary

A follow-up to #233, asked for by the operator on 2026-10-08. The README did not mention
property-based testing, and it did not say that the simulation covers logical faults only. It now
says both: the simulated faults are the ones at the agent's own boundary, hardware and network
faults are not simulated, and contracts also run as property tests on generated inputs. The
operator then asked for AILANG to be featured more: it is now the first Key Features bullet, and a
"Why AILANG" section sits before the DST section.

## Changes

- docs(readme): name the DST scope as logical faults, and mention property-based testing
- docs(readme): feature AILANG — a Key Features bullet and a "Why AILANG" section

1 file changed, and this record.

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
| Deterministic Simulation Testing | One paragraph: this is single-actor, logical-fault DST; physical faults and several actors are out of scope; the invariant families are properties in the property-based-testing sense, and what is generated is an execution of the production driver in a controlled environment. A link to 007 ADR-001 |
| Limits | The simulation-boundary line names physical faults and several actors. A new line says a failing run is not minimized |
| Key Features | A first bullet, "Written in AILANG", linking the new section |
| Why AILANG, new, before the DST section | Five reasons the language suits verified software written by models: effects in the type, granted capabilities, deterministic semantics, proved contracts, and a toolchain an agent can drive. One real contract from `src/core/recovery.ail` with its `ailang verify` result. A paragraph on AILANG's limits: young, a pinned release, proofs over unbounded integers, bounded proofs for recursion, and builtins Z3 cannot encode |

## The name

The operator proposed "logic-based Deterministic Simulation Testing", to stress that hardware and
network errors are not simulated, and on 2026-10-08 chose "logical-fault" for it: the term 007
ADR-001 D1 adopted, and one that cannot be read as formal logic next to the Z3 material. The title
and the section heading are unchanged. 007's D3 says the name "logical-fault DST" is available once
its D2 bar is met; no record was found that declares the bar met, and the merged README already
uses "DST" without a qualifier.

## Review

Reviewed on 2026-10-08 at `e7e01b3c` by Codex on GPT-6.1-Sol (high reasoning), read-only, in the
session that reviewed #233, briefed to check claims about AILANG against the installed CLI and
AILANG's own documentation. It reported four verified errors and three opinions. The authoring
session reproduced the four and fixed them in the commit after `e7e01b3c`:

| Finding | Fix |
|---|---|
| "Checked by Z3 for every input": the proof assumes the `requires`, and Z3 reasons over unbounded integers. AILANG's own example `doubleRange` is VERIFIED and fails its `ensures` at run time for 2^62 | The bullet says what is proved under what, and the limits paragraph names overflow |
| "Enforced by the language", "lists every effect": the ABI documents effects escaping through function-valued record fields, and a dropped world successor compiles | The lead says the language gives the footing and Motoko's ports, state threading and tests build the discipline. The effects bullet says "declares" and links Limits. The determinism bullet says the types do not check that the right state is passed |
| "What DST adds is that whole executions are generated": 007 ADR-001 says state-machine property testing also generates command sequences | The sentence now says what is generated here, without claiming it as the difference |
| "A function that recurses is left unproved": v0.47.2 gives recursive functions a proof to a bounded depth | Stated as a bounded proof, not an inductive one |

Also taken, from an opinion with a factual part: the skipped property test in
`context_limit.ail` is skipped because the generated input did not meet its `requires`, so "where
it can build the arguments" was replaced.

Open, for the operator: say that durable resume activates the fault catalogue's triggers for
reconsidering the physical-fault exclusion, so "out of scope by decision" is not read as settled;
and shorten "Why AILANG" to two reasons plus the example and move it after the DST section. The
position before the DST section and the first Key Features bullet were the operator's request.

The reviewer found the scoped name consistent with 007 D1 and no naming violation, noting that
009's ADR and its D5 and D28 notes carry the name. It found the retry sample, the release pin, the
no-loops claim, the logical fault classes and the shrinking limit correct, and the in-page links
and code blocks rendering.

## Predicted outcome

- **A reader expecting FoundationDB-style fault simulation is corrected in the first paragraph.**
- **No build, test or gate result changes.** The diff is one markdown file.
- **Nothing a session does changes.**

## Test evidence

Run on 2026-10-08 in the branch's worktree at `b07e760f`, AILANG v0.47.2.

- [x] **`ailang test src/core/context_limit.ail`** prints contract-derived property tests:
  `raw_window_of_property_1 (100 cases)`, `working_budget_for_ext_property_2 (100 cases)`, and
  one skipped, `working_budget_for_ext_property_1 (1 cases)`, because the generated input did not
  meet its `requires`. The README says the tests run on inputs "that meet its preconditions" and
  that skips are reported.
- [x] **No shrinker exists.** A search of `src/core`, `scripts/dst` and the `Makefile` for
  `ddmin`, `shrink_program` and `minimize_program` finds nothing, and 011 ADR-001 is Proposed.
- [x] **Every relative link in the README resolves**, the new link to 007 ADR-001 included.
- [x] **`ailang verify src/core/recovery.ail`** prints `✓ VERIFIED should_retry_stream_error`, and
  the code block in the README is that function, identical to lines 23 to 29 of the source.
- [x] **What the section says about AILANG is from AILANG's README and documentation**, read on
  2026-10-07 and -08: the effect rows, `--caps`, no loops, Z3 contracts and `ailang prompt`. Its
  claim that models write AILANG more correctly than other languages is not repeated.
- [x] **The name.** 009's ADR-001 is titled for "Motoko Logical-Fault DST" and states what earns
  the name. The reviewer reports that 009's D5 and D28 notes record its adoption; the authoring
  session did not read those two notes.
- [ ] **CI was not awaited.** The change is documents only.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
