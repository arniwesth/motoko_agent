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
| 1 | **A1 + A2** | `ports.ail`, `stub_step.ail`, `session.ail`, `scripted_ports.ail` | — | **Handoff written**: `HANDOFF-execute-a1-a2-port-widenings.md` |
| 2 | **A4 + A5 + A11** | `tools/`, Python; scans the tree, edits none of it | — | Safe to write now |
| 3 | **A6 + A7 + A8** | new artifacts + fail-closed validators | — | Safe to write now |
| 4 | **A9** | `session.ail`, `phase_vocab.ail` — driver surface again | after 1 (shared surface) | Wait for 1 |
| 5 | **A10** | profile/manifest machinery | 2 and 3 | Wait |
| 6 | **A12** | driver, all effect classes; internally staged one PR per class | 1 | Wait |
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

The corollary is that this note is **not** a licence to batch-generate the remaining seven handoffs.
Generate one when its cluster becomes groundable.

## Generating the next handoff

Use `HANDOFF-execute-a1-a2-port-widenings.md` as the template. Do not restate the plan; carry the
four things it cannot:

1. **Current grounding** — a table of the anchors the cluster will touch, re-verified at HEAD, gated
   behind `git diff --stat <last-known-good>..HEAD -- src packages scripts` with the instruction to
   re-measure everything if it is non-empty.
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

Until several clusters have landed, every estimate past cluster 1 is an analogy. Each handoff should
request actual time, files touched, and the **judgement-versus-mechanical site ratio** — M1's 7-of-69
is what the rest of Milestone A is scheduled against, and if it does not hold, that must surface
before A13 rather than inside it.

Plan defects found while building get filed as plan corrections. Never silently reconciled: executing
finds what reading does not, and that is the point of building cluster 1 first.

## Standing traps for any execution session

Clear `.ailang/cache` before believing a contradicting type error; the compiler reports one
record-field mismatch at a time, so write the fix-loop tooling before the edits; never probe from
`/tmp` (`MOD010` auto-relaxes); PR #103 must not be merged; the spike branch is not HEAD state; pin
is v0.26.0, Makefile-guarded.

## What invalidates this note

- The plan changing its dependency graph — the plan is authoritative, this map is derived.
- Cluster 1 landing, which unblocks clusters 4 and 6 and makes their handoffs writable.
- Any cluster proving to be the wrong cut. That is expected for the later ones: the clustering past
  cluster 5 is reasoned rather than measured, and the first two or three executions are what turn it
  into something known.
