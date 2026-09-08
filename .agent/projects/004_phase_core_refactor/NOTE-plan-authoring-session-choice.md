# Note: why the implementation plan is written in a fresh session (and the ADR was not)

Date: 2026-07-03
Provenance: verbatim answer from the ADR-authoring session (Claude Fable 5), in response to the
operator asking whether to write the implementation plan in the same session or a new one.
Recorded because the reasoning generalizes: it is a reusable rule for deciding where a given
artifact should be authored. See `HANDOFF-write-phase-a-plan.md` for the handoff it motivates.

---

New session — and this time the reasoning that kept the ADR here points the other way.

The ADR was a synthesis of *session-local decisions*: context-heavy, source-light. Loaded
context was the asset, so writing it here was right. An implementation plan inverts that: it's
a projection of now-*stable, committed documents* (ADR, research doc, sketch — all deliberately
self-contained) onto *current source* — source-heavy, context-light. The plan's hard work is a
deep code survey: every call site of the transcript helpers being extracted, the exact seams in
`rpc.ail` and the TUI's event consumption, Makefile/CI targets, test coverage around the
touched code. I've read maybe a third of `agent_loop_v2.ail` and almost none of the TUI; a
fresh session reads HEAD with a full budget.

Two sharper arguments for fresh:

1. **Staleness is this project's proven failure mode.** The review's highest-value finding was
   that I'd inherited DST ADR-001's compaction constants from a 5-day-old grounding while the
   source had moved. A long session accumulates exactly that risk — I "know" line numbers and
   code shapes from reads that are now hours and one commit old. A plan is *denser* in source
   citations than an ADR, so the risk compounds. A fresh session grounded against HEAD is
   structural protection, not just hygiene.

2. **The ADR-completeness test lands in the right place.** Earlier you floated testing the
   research doc by having a fresh agent write the ADR; I argued the reviewer should carry that
   test instead. For the plan, the test is safe to run directly: if a fresh session can't
   produce the Phase A plan from the ADR alone, the ADR has a gap — and we *want* to discover
   that now, cheaply, rather than during implementation. The plan is also inherently checkable
   against the ADR's gates, so a fresh writer's errors get caught in ways a fresh ADR-writer's
   wouldn't have been.

Two recommendations to go with it:

- **Scope the first plan to Phase A only** (vocabulary module, measurement-primitive exports,
  transcript builder extraction, zero-behavior-change gate). It's close-ended and its gate is
  mechanical. Phase B (chain conversion + ladder extraction + ledger centralization) deserves
  its own plan once Phase A's real shape is known — the 003 project's one-plan-per-phase
  convention (`PLAN-phase1-*`, `PLAN-phase1b-*`) had this right.
- **Let me write the handoff here** — that's where this session's residual context still pays.
  `HANDOFF-write-phase-a-plan.md` would carry: the reading order (ADR → research doc → sketch),
  the mandate to re-verify every cited line number against HEAD and re-run the artifacts before
  relying on them (the staleness lesson, made procedural), the Phase A deliverable list with
  its gate as acceptance criteria, the sketch-to-real-module mapping notes (e.g.,
  `estimate_tokens`/`usage_percent` are already exported — the plan should catch that Phase A's
  "export constants" is partly done), and the constraint that Phase A must not change the event
  stream.

---

## The generalized rule (added for reuse)

Author an artifact in the session whose assets it consumes:

- **Context-heavy, source-light** artifacts (decision syntheses, ADRs, disposition logs,
  handoffs themselves) → the session that made the decisions. Fresh sessions re-derive at high
  cost and risk re-litigating settled questions.
- **Source-heavy, context-light** artifacts (implementation plans, migrations, code surveys) →
  a fresh session grounded against HEAD. Long sessions carry stale line numbers and code
  shapes; citation-dense artifacts compound the risk.
- **Adjudication** (review responses) → the authoring session, with evidence-first discipline
  as the defensiveness mitigation; the reviewers were the fresh eyes.
- **Verification/review** → always fresh eyes; distance is the asset.
- The handoff prompt is where a closing session's residual context is cashed out: write it in
  the old session, execute it in the new one.
