# 2026-08-02 ADR-001 accepted, the review loop measured and closed, implementation plan handed off

## Context

Branch: `arniwesth/mot-44-motoko_dst_execution_primer`

Session span: `99749c7d` → `414c868`, **36 commits**, all documentation and one tool. **No production
source changed.**

The session began with a single instruction — read
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` and relate
it to the review comments — and then ran the review loop that instruction implied, eight more times.
Partway through, a question from the user (*"is there any pattern in this?"*) turned the session
around: the loop was measured, found to be diverging, and deliberately closed. The ADR was accepted
nine hours later by a different kind of review.

Three phases, and the middle one is the point.

## Phase 1 — eight rounds of paired delta review (passes 2–9)

Each round: two independent agents review the previous correction pass, their sections are committed
verbatim before any response, a correction pass answers them, a handoff scopes the next round.

| Round | Findings | Notable |
|---|---|---|
| 2nd pass | 15 | six were provenance/anchor errors a diff would have caught |
| 3rd | 12 | first round with a real two-commit diff; zero provenance findings |
| 4th | 16 | `ext_ai_step` — a second `Ports.model_step` seam nobody had seen |
| 5th | 16 | "not conformance-eligible" was stronger than D5 licenses |
| 6th | 17 | the coarse rule's grep selected both guards the ADR depends on |
| 7th | 19 | the closed ABI defeats both rules added in the same pass |
| 8th | 20 | a rowless hook *can* call `ai_step` — the effect checker isn't transitive through record fields |

Real defects every round, several introduced by the correction passes themselves. Notable mechanism
churn: **classifier 1 rewritten four times** (fail-open each time), classifier 2's matcher three, the
attribution table three, the coverage floor three dispositions ending where it began.

Two upstream defects surfaced and were confirmed by execution:

- **Effect propagation through function-valued record-field calls.** A rowless function calling an
  effectful record field type-checks and performs the effect; direct and named-helper calls are
  correctly caught. `ExtCtx.ports` is exactly that shape. A soundness gap.
- **`ailang iface`** — `pure` contradicts `effects` on 12 `std/ai` exports; the documented
  `iface <module>` invocation doesn't work; `std/secret.ail` fails `MOD010` outside a temp directory
  and **auto-relaxes inside one**, so probes run from `/tmp` report a clean walk CI would not see.
  That last one produced a genuine disagreement between two reviewers, both correct.

## Phase 2 — measuring the loop, and closing it

Asked whether there was a pattern, I counted instead of speculating.

```
19 review sections, 154 findings
delta-round findings: 15, 12, 16, 16, 17, 19, 20   ← bottomed out at round 2, rising since
78% of the file was review commentary (7,640 vs 2,127 lines)
zero source changed across 24 commits
```

**The loop was diverging and had been for six rounds**, invisible because every individual round
looked productive. Two blockers were being conflated: an external one (upstream API in a release) and
an internal one — "this pass has not been independently verified" — which is **true after every pass
by construction** and therefore a fixed point wearing the costume of progress.

Written up in two documents:

- `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
  — standing discipline. Count findings per round; a detector cannot be specified to buildability in
  prose. Plus the four sub-patterns: specifying detectors without building them, propagation failure
  across a document where one idea lives at six sites, unverified generalisation from the confirming
  case, and self-referential claims that go stale on edit.
- `NOTE-review-loop-retrospective.md` — the project record and the recommendation.

Then the recommendations were applied:

1. **Built classifier 1** (`tools/effect-inventory/derive.py`, `make effect_inventory`). ~200 lines.
   Ran correctly first time and immediately produced what four prose revisions had missed:
   `std/extension` and `std/sem` are **source-only** effect-bearing modules invisible to the builtin
   projection, and `std/sem`'s `! {SharedMem}` is reached from `src/core/rpc.ail:200`. Self-test
   cross-validates its textual fallback against `ailang iface`: `agree=43 disagree=0`.
2. **Deferred the remaining three mechanisms** behind a *Gate mechanisms: built, and deferred* section
   with stated acceptance criteria — they block the DST name, not the ADR.
3. **Retired the self-regenerating blocker**, with the measured evidence recorded in place.

## Phase 3 — acceptance

A scoped architecture-acceptance review, deliberately a different document: one question (*should this
be accepted as an architecture decision?*), the mechanism layer explicitly out of scope, the narrowing
itself offered as attack item A1 with the reviewer licensed to reject it.

**Both reviewers returned *Accept with conditions*** — the first non-Revise verdict in twenty sections
— and both produced short reviews rather than twenty findings. Both independently applied the
handoff's own test (*if all three deferred mechanisms were unbuildable, would D1–D11 still be right?*)
and both answered yes, because each mechanism's absence degrades conservatively.

**The one architectural finding, convergent and new after 154 prior findings:**

```
205: (h.on_build_system_prompt)(ctx)   ← unconditional fold over rt.registry.hooks
238: (h.on_pre_step)(ctx, msgs)        ← unconditional fold
338:   if contains_tool(...) then ...  ← the ONLY gated slot
```

Six of eight ABI hook slots dispatch unconditionally, so a profile installing an extension with all
hooks excluded fails closed on the first system-prompt build. **"Conformant and inert" was
unreachable** — zero `SystemRun`s, so neither D11's minimum count nor any D7 invariant is satisfiable.
It survived 154 findings because every round reasoned about profile-definition *validity* without
checking whether such a profile can *execute*.

The fix — omit the extension rather than exclude its hooks — **reduces machinery**: the coverage-floor
carve-out deleted, deferred mechanism 4 collapsed, classifier 2 out of the floor's dependency chain,
and the one fail-open direction in the deferred layer gone.

Conditions applied; **ADR-001 Accepted 2026-08-02**, with the boundary written into the Status block:
accepted means D1–D11 are the selected architecture; it does *not* mean the DST name is earned.

## Phase 4 — the implementation plan (other sessions, from this session's handoff)

`HANDOFF-implementation-plan.md` was written as an authoring handoff leading with the review-loop
failure mode. Subsequent sessions executed it:
`PLAN-implementation-deterministic-test-world.md` (541 lines, three milestones), reviewed twice.

**The contrast is the retrospective validating itself:**

| | ADR-001 review loop | Implementation plan review |
|---|---|---|
| Findings trajectory | 15 → 20, rising over 7 rounds | 11 → 9 → 1 → 0 in one session |
| Second round | — | 10 findings, one pass, *Accept with conditions* |

The plan opens by declaring itself "a build order, not a second specification," names the first
conformant profile (`driver_only`, v1), and settles the two questions the ADR deliberately left open:
`ProviderState` is a record, and the approval/clock cursors do **not** ride along in the interim
widening.

## State at session end

| | |
|---|---|
| **ADR-001** | Accepted 2026-08-02; 20 review sections; body 2,146 lines |
| **Classifier 1** | Built, verified by both acceptance reviewers, wired to `make` |
| **Deferred artifacts** | 4, criteria stated, blocking the name only |
| **External prerequisite** | upstream `#546` released + repin + positive probe — moved zero all session |
| **Implementation plan** | Proposed, reviewed twice, milestones A/B/C |
| **Working tree** | clean apart from untracked `mmd/` (diagrams from another session) |

## What I'd carry forward

**The measurement is the intervention.** Nine correction passes did not notice a diverging loop; one
`grep -c` over section headings did. Any iterative review process should count findings per round from
round one.

**Writing the next handoff found a defect in the pass just committed, five rounds running.** That is a
strong signal the pass was under-verified before commit — and an argument for drafting the attack list
*before* the correction rather than after.

**Two blockers of different kinds must never be listed as peers.** An external dependency is finite; a
"latest pass unverified" condition regenerates on every edit. Conflating them made the ADR
un-acceptable in principle for six rounds, and nobody noticed because each round's version of the
sentence was individually true.

**The reviews were never the problem.** Paired independent reviewers caught real defects every round,
disagreed productively twice, and the author-adjudicates/verifier-verifies split held throughout. What
failed was asking a document to answer a question only a running program can.
