# Note: how Milestone A is clustered into sessions, and how to generate the next handoff

Date: 2026-08-02. Status: active execution map.
Companion discipline: `.agent/meta-decisions/sequence-implementation-handoffs-by-source-surface.md`.
Source of truth for *what* to build: `PLAN-implementation-deterministic-test-world.md`. This note is
only about *how the work is cut into sessions*.

It exists so a session that picks this up cold can generate the next handoff without re-deriving the
clustering argument.

## The question this answers

Milestone A is 24 work items and six-plus weeks. Two obvious approaches were considered and both
rejected:

- **One session for all of Milestone A.** Rejected: implementation is source-heavy work, and each
  landed item invalidates the file:line anchors the next one cites. A session running A1→A15 would
  spend its back half building on line numbers it had itself moved — the defect class
  `re-ground-inherited-anchors-before-building.md` exists to prevent.
- **One handoff per work item (23 of them).** Rejected: the plan already carries each item's
  dependencies, contents, and acceptance evidence, so per-item handoffs would mostly restate it.
  This project's measured pathology is documentation growing faster than code (78% of ADR-001 was
  review commentary across 24 commits that changed no source). A handoff's genuine value-add is
  narrow — current grounding, traps, scope fence, green state — and that is a page.

**The cut that works is by shared source surface**: a cluster is a set of items that touch the same
files and can end in one green state.

## The cluster map

Dependencies are from the plan; clusters inherit them. Nothing here overrides the plan — if they
disagree, the plan wins and this note is stale.

| # | Items | Surface | Depends on | Status |
|---|---|---|---|---|
| 1 | **A1 + P6 + A2** | `ports.ail`, `stub_step.ail`, `session.ail`, `scripted_ports.ail` | — | **DONE 2026-08-02** — `e59acaa`, `4ad2c7a`, `6dd1bbe`. Report: `NOTE-cluster-1-execution-report-and-plan-corrections.md` |
| 2 | **A4 + A5 + A11** | `tools/`, Python; scans the tree, edits none of it | — | Safe to write now |
| 3 | **A6 + A7 + A8** | new artifacts + fail-closed validators | — | Safe to write now |
| 4 | **A16 + A9** | `Makefile`/CI, then `session.ail`, `phase_vocab.ail` | 1 (landed) | **DONE 2026-08-02** — `61f38db`, `ff8d8e5`. Report: `NOTE-cluster-4-execution-report-and-plan-corrections.md`. Spawned **WI-A17** (the `ailang test` coverage axis), unassigned to a cluster |
| 5 | **A10** | profile/manifest machinery | 2 and 3 | Wait |
| 6 | **A12** | driver, all effect classes; internally staged one PR per class | 1, 4 (both landed) | **DONE 2026-08-02** — `2b938e1`…`3c2f4ab`, all six classes plus the typed tool contract, ~92 min against "several days". Report: `NOTE-cluster-6-execution-report-and-plan-corrections.md` |
| 7 | **A13** | discovery/replay | 3, 4, 5, 6 | Wait |
| 8 | **A14 + A15** | invariants, latency pair, corpora, CI | 7 | Wait |

**Clusters 1, 2 and 3 are mutually independent and can run in parallel** across sessions or agents.
Cluster 2 in particular is anchor-independent of the driver work — it inventories source rather than
editing it — which is why its handoff is safe to write before cluster 1 lands.

**The critical path is 1 → 6 → 7 → 8** (A1 → A2 → A12 → A13 → A14/A15). Clusters 2–5 feed it but do
not lengthen it. A13 and B2 are the two 1–2 week items and dominate the schedule.

## The rule that governs handoff *timing*

**Write the handoff for the next cluster you can ground honestly, and no further.**

Handoffs for clusters 4, 6, 7 and 8 must not be written yet. They would cite anchors into
`ports.ail`, `stub_step.ail` and `session.ail` that cluster 1 is about to move, so writing them now
guarantees the staleness the whole discipline exists to prevent. Clusters 2 and 3 are the exception
and may be written at any time.

The corollary is that this note is **not** a licence to batch-generate the remaining handoffs.
Generate one when its cluster becomes groundable.

**Cluster 4 is the evidence this rule is worth its cost.** Its handoff was written after cluster 1
landed, and re-grounding found that *every* WI-A9 anchor had moved: `emit_run_summary` 833→858, all
five of its call sites shifted, `finish_reason_str` 820→845. A handoff written before cluster 1
would have shipped five wrong line numbers into the session least able to notice — one working in a
file it had never read.

## Generating the next handoff

Use `HANDOFF-execute-a1-a2-port-widenings.md` as the template. Do not restate the plan; carry the
four things it cannot:

1. **Current grounding** — a table of the anchors the cluster will touch, re-verified at HEAD, gated
   behind `git diff --stat <last-known-good>..HEAD -- src packages scripts` with the instruction to
   re-measure everything if it is non-empty.

   **The anchor table is itself a source of defects, and cluster 6 proved it.** The A12 handoff's
   table named *three* dispatch carry sites; there are **six**, and **cluster 1's report had said six
   all along** — the handoff lost three in transcription from the report it was built on. It changed
   nothing only because the class turned out to be a uniform rename; a session hand-threading from
   that list would have frozen three sites, which is precisely the defect cluster 1 filed,
   reintroduced by the artifact meant to prevent it. **Derive every count in the table from a command
   you run while writing it, paste the command, and never carry a number across from prose** —
   including prose you wrote yourself.
2. **The rule the session will break by accident** — every cluster has one. Cluster 1's is that A1
   and A2 are two commits because one is behaviour-preserving and the other is not. Find the
   equivalent before writing: it is usually a distinction the plan states once and a builder would
   naturally collapse.
3. **Definition of done, per commit**, with a runnable check and — where a defect is being fixed —
   the current failing output verbatim, so a real regression is distinguishable from the
   pre-existing state.
4. **Scope fence and traps.** What the cluster must *not* do (usually: the next cluster's work), plus
   the standing traps below.

Also carry, every time: **stop-and-report triggers** rather than inline judgement calls. Cluster 1's
is P2's reopening condition. Anything the plan names as a decision belongs to the plan, not to the
building session.

## What to ask back, every cluster

Each handoff should request actual time, **sites touched** and the
**judgement-versus-mechanical ratio**. Cluster 1 established why all three matter and corrected the
model: file-count sizing was wrong by two orders of magnitude, **sites** is the right driver for
widen-and-converge work, and the judgement ratio for contract-changing work is **~19%**, not M1's
10%. Neither correction reaches new-artifact work (A13, A14, A15, B2), whose estimates remain
unmeasured.

Ask also for the *kind* of judgement, not only the count. This has now paid twice, and it is the
single highest-value question in the report-back:

- **Cluster 1**: two of nine judgement sites admitted two type-checking answers with a silent wrong
  one — wrong successor literals that froze a cursor. That finding added A12's advancement-assertion
  requirement.
- **Cluster 4**: four of ten, and *worse in kind* — trace arguments where the wrong value yields a
  trace that **still passes its own invariant**. That finding forced A12's assertion to cover trace
  completeness, not just cursor advancement.

A count alone would have hidden both. **Ask what could have been wrong silently, and what caught
it** — in cluster 4's case, one of the four was caught only by reading emitted JSONL, because
`smoke_parity` diffs a build against itself and a consistent reordering is consistent.

**Write acceptance clauses that must be *demonstrated*, not asserted.** Cluster 4's C1 is the
evidence: "verified by breaking one deliberately" could not be satisfied, because four of the eight
scripts exited 0 on a failed assertion. An assertable clause would have shipped the illusion of
coverage.

Plan defects found while building get filed as plan corrections. Never silently reconciled: executing
finds what reading does not, and that is the point of building cluster 1 first.

## Standing traps for any execution session

Clear `.ailang/cache` before believing a contradicting type error; the compiler reports one
record-field mismatch at a time, so write the fix-loop tooling before the edits; never probe from
`/tmp` (`MOD010` auto-relaxes); PR #103 must not be merged; the spike branch is not HEAD state; pin
is v0.26.0, Makefile-guarded.

## What invalidates this note

- The plan changing its dependency graph — the plan is authoritative, this map is derived.
- ~~Cluster 1 landing~~ — **landed 2026-08-02. Clusters 4 and 6 are now groundable and their handoffs
  writable.** Both must re-ground first: cluster 1 moved `ScriptedStep` to `ports.ail`, widened
  `Ports.model_step` in both directions, removed `Ports.hooks_runtime`, and added
  `C2LoopState.provider_state`, so every anchor into those three files has shifted.

**One correction this map owed and now carries (C3).** Cluster 1's row said "A1 + A2". P6 is a plan
*decision* rather than a work item, so it appeared in no row, yet the plan sequences it into A1's
edit wave because both touch every construction site. A session working from this map alone would
have skipped it and a later one would have paid a third full pass. **When generating a handoff, sweep
the plan's decisions for ones that name an edit wave, not just its work items.**
- Any cluster proving to be the wrong cut. That is expected for the later ones: the clustering past
  cluster 5 is reasoned rather than measured, and the first two or three executions are what turn it
  into something known.
