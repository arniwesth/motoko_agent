# Meta-decision: author each artifact in the session whose assets it consumes

Date: 2026-07-07
Status: Standing discipline
Scope: any point where the operator asks "write this here, or in a new session?" — for an ADR, plan,
migration, review, handoff, or survey.

## The principle

An artifact is cheapest and most correct to write in the session that already holds its **inputs**.
Two kinds of input compete: *loaded conversational context* (the decisions, trade-offs, and rejected
alternatives a session has built up) and *current source* (what HEAD actually says right now). These
decay in opposite directions — context is freshest in a long-running session and absent in a new one;
source knowledge is freshest in a session that just read HEAD and rots in a long one. So the placement
rule is: **classify the artifact by which input it mostly consumes, and author it where that input is
freshest.**

## The taxonomy

- **Context-heavy, source-light → the session that made the decisions.** Decision syntheses, ADRs,
  disposition/adjudication logs, and handoff prompts are projections of session-local reasoning. The
  loaded context *is* the asset; a fresh session would re-derive it at high cost and risk
  re-litigating settled questions. Write them where the reasoning lives.
- **Source-heavy, context-light → a fresh session grounded against HEAD.** Implementation plans,
  migrations, code surveys, and DST/scenario suites are projections of now-stable committed documents
  (ADR, research, sketch) onto *current* code. Their hard work is a dense code survey — every call
  site, every seam, every CI target — and they are far denser in file:line anchors than the ADR they
  derive from. A long session carries stale line numbers; a citation-dense artifact compounds that
  risk per page. Fresh-at-HEAD is structural protection, not hygiene. (See the sibling discipline
  `re-ground-inherited-anchors-before-building.md`.)
- **Adjudication (author's response to review) → the authoring session,** with evidence-first
  discipline as the guard against defensiveness. The reviewers were the fresh eyes; the author holds
  the context needed to dispose of each finding.
- **Verification / review → always fresh eyes.** Distance from the authoring session is the asset that
  makes a review honest; never review your own artifact in the session that produced it.

## Why staleness, not just tidiness, drives this

The failure mode this prevents is proven in-repo: the highest-value review finding on the 004 project
was that an ADR had inherited compaction constants from a five-day-old grounding while the source had
moved — the constants no longer existed. A long session "knows" code shapes from reads that are now
hours and a commit old. Because source-heavy artifacts multiply anchors, the same drift that produces
a single stale sentence in an ADR produces many in a plan built from it. Moving that work to a fresh
session isn't neatness; it's the only structural defense against a defect class this project keeps
rediscovering.

## The completeness test (a free benefit of going fresh)

When a source-heavy artifact is authored fresh from the upstream decision docs alone, its ability to be
written *is itself a test of those docs*. If a fresh session cannot produce the plan from the ADR and
research doc without back-channel context, the ADR has a gap — and you have found it now, cheaply,
rather than mid-implementation. Plans are also checkable against the ADR's own gates, so a fresh
writer's errors surface in ways a fresh *decision*-writer's would not. This is why the completeness
test is safe to run on plans but not on ADRs: a plan has a spec to be wrong against; a from-scratch ADR
has nothing to catch it.

## The handoff mechanic

A closing session's residual context is a wasting asset — cash it out before it evaporates. **Write the
handoff prompt in the session that is ending; execute it in the new one.** A good handoff carries the
reading order of the upstream docs, the deliverable list with the acceptance gate, the mapping notes
only the closing session knows (e.g. "this 'export the constants' step is already partly done"), and —
mandatorily — the instruction to re-verify every cited anchor against HEAD before relying on it. That
last clause is what fuses this discipline to its sibling.

## Provenance and relationship to the sibling discipline

This generalizes `004_phase_core_refactor/NOTE-plan-authoring-session-choice.md` (the verbatim
reasoning from the session that kept an ADR local but sent its plan to a fresh session), condensed in
persistent memory as `artifact-session-matching`. It pairs with
`re-ground-inherited-anchors-before-building.md`: that doc governs *how* the fresh, source-heavy
session must treat inherited anchors (re-observe, don't re-cite); this one governs *which* session
should be doing that work in the first place. Together they reduce to a single habit — put source-dense
work where source is fresh, and re-run every inherited claim against it.
