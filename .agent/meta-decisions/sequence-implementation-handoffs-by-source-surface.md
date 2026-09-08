# Meta-decision: cut implementation into sessions by shared source surface, and write only the handoff you can ground

Date: 2026-08-02
Status: Standing discipline
Scope: any point where an accepted plan with many work items has to be turned into executable
sessions — "one handoff per item, one for the whole milestone, or something else?"

## The principle

Two rules.

**1. Cluster by shared source surface, not by work item and not by milestone.** A session should own
the set of items that touch the same files and can end in **one green state**. Per-item handoffs
restate a plan that already carries dependencies, contents, and acceptance evidence — producing
prose faster than code. A whole-milestone session cannot hold the context and, worse, spends its
back half building on anchors it invalidated itself.

**2. Write the handoff for the next cluster you can ground honestly, and no further.** A handoff is
dense in file:line anchors. Writing handoffs for clusters whose surface an earlier cluster is about
to edit bakes in staleness on purpose. The exception is a cluster that *reads* the tree rather than
editing it — tooling, inventories, scanners — which is anchor-independent and can be written at any
time, and often run in parallel.

## Why this follows from the two sibling disciplines rather than competing with them

`author-each-artifact-in-the-session-whose-assets-it-consumes` classifies artifacts by which input
they mostly consume and sends source-heavy work to a fresh session at HEAD.
`re-ground-inherited-anchors-before-building` governs how that session must treat inherited anchors.

Implementation is the most source-heavy work there is, so both apply at full strength — but they
were written about *authoring artifacts* and leave the sequencing question open. This one closes it:
**the unit of freshness is the source surface, so that is the unit the sessions should be cut
along.** Once work starts landing, the two disciplines stop being advice about where to write a
document and become a hard constraint on how far ahead you can plan sessions at all.

## The instance that motivates it

Project 009's `PLAN-implementation-deterministic-test-world.md`: 24 work items, six-plus weeks,
across a driver surface, a tooling surface, new artifacts, and CI. Per-item handoffs would have been
23 documents on a project whose measured pathology was already documentation outgrowing code — 78%
of its ADR was review commentary across 24 commits that changed no source. A single milestone
session would have had A13 citing `ports.ail` line numbers that A1 and A2 moved in week one.

The clustering that survived scrutiny was eight clusters, three of them mutually independent and
parallelisable, with a four-cluster critical path. Only the first handoff was written.

## What a handoff carries, given the plan already exists

Not a restatement. Four things the plan cannot hold:

1. **Current grounding** — the anchors this cluster touches, re-verified now, gated behind a
   source-unchanged check with instructions to re-measure if it fails.
2. **The rule the session will break by accident.** Every cluster has one, and it is usually a
   distinction the plan states once that a builder would naturally collapse. Find it deliberately.
3. **Definition of done per commit**, with a runnable check — and where a known defect is being
   fixed, its current failing output verbatim, so a real regression is distinguishable from the
   pre-existing state.
4. **Scope fence, traps, and stop-and-report triggers.** Anything the plan names as a *decision*
   belongs to the plan; a building session that hits one stops and reports rather than deciding
   inline.

## The calibration clause

Until two or three clusters have landed, every estimate beyond the first is an analogy. **Make the
first cluster the cheapest one that produces real cost data**, and have every handoff ask back for
actual time, files touched, and the ratio of sites needing judgement versus mechanical edit. That
ratio is what the rest of the schedule rests on; discovering it is wrong is worth far more early
than late.

Expect the clustering past the first two or three to be reasoned rather than measured, and say so
where it is recorded. Executing corrects it — which is the same lesson as
[[measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them]], one layer up:
you cannot plan a build order to correctness in prose either.

## Related

- [[author-each-artifact-in-the-session-whose-assets-it-consumes]] — which session authors what;
  this doc extends it from artifacts to implementation sessions.
- [[re-ground-inherited-anchors-before-building]] — how a fresh session must treat inherited
  anchors; the reason handoffs cannot be batch-generated ahead of the work.
- [[measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them]] — build the
  smallest real thing rather than specifying further; the calibration clause is that rule applied to
  schedule estimates.
