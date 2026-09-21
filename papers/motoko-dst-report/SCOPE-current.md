# Scope and evidence notes — current-system report

Date: 2026-09-19. Source snapshot: `7e5ec5f9daf7d19076c2792e91701a896fc79126`.
Status: working scope accompanying [DRAFT-current.md](DRAFT-current.md).

## Why a new draft

The August report explains the original ports swap and the conditions under which
particular execution profiles earned a deterministic simulation testing claim.
That remains useful background. Project 013 changes the account in four substantial
ways:

1. World-state threading has an explicit ordinal, request witnesses, a source
   inventory, and a checker over separately framed executions.
2. Waiting and suspension are represented in the runtime. A session can park on
   external work and resume across child-process lifetimes.
3. A host-owned journal reconstructs durable session state. Its fold introduces a
   separate consistency obligation against the state returned by the driver.
4. Journal-derived evaluation connects the journal and host-log observations to
   the existing simulation machinery. Admission records an execution program;
   candidates use the same replay, witnesses, and invariant evaluator. The corpus
   entry binds the source snapshot, excerpt, selector, and program because the
   initial history remains in the snapshot. Implementation and validation are
   still at different stages.

The framing is therefore **how deterministic worlds and durable session state are
connected and checked**. Conformance and vacuity accounting remain central to the
strength of the claims. A history of project 013's review rounds is not the report's
organizing principle.

## Working boundaries

Retain the original scope's external technical audience and architecture-first
approach, with roughly 8–12 pages as a later editing target. Explain enough of
Motoko and AILANG to make the boundary and capability arguments readable. Use
source-backed examples and existing evidence; a new benchmark campaign is outside
this drafting pass.

The source snapshot is the current checkout, not the separate evaluator worktree
or sweep clones. Existing uncommitted project notes inform the status discussion
but do not establish shipped behavior. ADR headers and code comments sometimes
describe an earlier revision; executable definitions and call sites take priority
for implementation claims.

## Changes to the old account

| August account | Treatment in the new draft |
|---|---|
| Three execution profiles | Four profile definitions are present; versions are read from source. Definition presence is not a fresh conformance verdict. |
| One-of-forty coverage headline | Historical measurement only. Capability registration and herdr coverage have changed the population; recompute before stating a new aggregate. |
| Ledger described primarily as the test oracle | Show how journal observations, recorded programs, and trace evidence connect through admission and the shared replay/checking path; retain their distinct evidentiary roles. |
| Twelve single-execution invariant families | Thirteen registered families, including `JournalFold`; the determinism relation still compares two runs separately. |
| Logical faults with physical recovery excluded | Describe existing resume tests and the remaining crash/durability coverage question. Resume activates the catalogue's own reconsideration triggers. |
| CI presented as the deterministic suite | Report the checked-in CI commands separately from the larger `make dst` target list. |
| Future architectural improvements | Do not imply that a generic profile runner, `WorldM`, or a full command/interpreter rewrite landed in project 013. ADR-001 explicitly deferred or dropped these. |

## Evidence collected for this draft

- Inspected the current core, profile declarations, journal writer/fold, evaluator
  entrypoints, Makefile, CI workflow, and project 013's decisions and implementation
  records. The draft links its principal sources.
- Ran `bash scripts/dst/run_world_framed_wire.sh --selftest`: PASS. This checks the
  wire checker against synthetic valid and invalid frames; it does not execute
  the production driver.
- Ran `python3 tools/driver_leaf_inventory/derive.py --self-test`: zero failures.
  It reported 26 leaves clean/returned and six clean receipts in the unmutated
  tree, and detected its deliberately broken fixtures and mutations. These are
  this scanner's categories, not counts of all effects in Motoko.
- Confirmed that `scripts/eval/journal_replay.ail` routes `RealEntry` admission to
  `jr_real_refused` at this snapshot. Later real-entry work must be grounded again
  after integration.

No full `make dst`, live-provider experiment, corpus admission, memory benchmark,
or independent paper review was performed for this drafting pass.

## Before publication

- Pin the intended publication revision and reconcile the evaluator section with
  its integrated implementation and review results.
- Obtain a full sweep at that revision and record all failures and exclusions.
  A Makefile target or an older green run is not a current passing result.
- Recompute profile coverage over the current capability atoms and distinguish
  declared, measured, substantive, excluded, and vacuous entries.
- Audit which runners invoke each invariant family. A registered family does not
  establish universal execution of that family.
- Establish the scope of journal crash/recovery testing, including the difference
  between synthetic journal damage and host/filesystem durability testing.
- Add and verify external related-work citations, update the figures for the new
  architecture, and undertake an independent review. The original review's
  unresolved bug-yield and systematic mutation-study questions remain open.
- Export a new PDF only after those publication edits; the existing PDF is the
  original draft.
