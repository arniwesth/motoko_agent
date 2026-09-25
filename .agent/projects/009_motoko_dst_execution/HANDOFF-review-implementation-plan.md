# Handoff: review `PLAN-implementation-deterministic-test-world.md`

Audience: a fresh agent session with no context from the authoring side. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

Target: `.agent/projects/009_motoko_dst_execution/PLAN-implementation-deterministic-test-world.md`
(357 lines, committed `1a18f65`, reviewed to convergence at `a339629`). Source ground: HEAD, pinned
AILANG v0.26.0.

## Mission

Answer one question: **is this plan safe to execute?**

A plan is safe to execute when its work items are in a buildable order, its dependencies are real and
complete, its sizing will not mislead whoever schedules the work, and its acceptance evidence would
actually discharge the obligation it claims to discharge. That is the whole question.

**It is not "is the architecture right"** — ADR-001 was Accepted on 2026-08-02 by two independent
reviewers after nineteen review sections, and D1–D11 have been reopened by nobody in eight rounds.
**It is not "is every detector specified soundly"** — that question is what this project has already
paid for, twice over, and the plan's whole design answers it by scheduling builds instead.

## Read this first: the failure mode you are joining

ADR-001 took **19 review sections and 154 findings** before acceptance, and **the loop diverged for
six rounds**: findings per delta round went 15, 12, 16, 16, 17, 19, 20 while every individual round
looked like progress. Zero source changed across 24 commits. The diagnosis is in
`.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-specifying-them.md`
and the project record in `NOTE-review-loop-retrospective.md`. **Read both; they are short.**

Two rules fall out of it, and they bind this review:

1. **Count your findings and report the count.** If you run more than one pass, report findings per
   pass. Falling is healthy, flat is a warning, rising means stop and say so rather than continuing.
2. **The plan is a build order, not a specification.** If you find yourself writing that a detector's
   decision procedure is under-specified, check first whether the plan *schedules building it with an
   acceptance criterion*. If it does, that is the correct treatment and not a finding — the ADR's
   *Gate mechanisms* section is the boundary, and prose refinement of those mechanisms is precisely
   what diverged. A finding that the plan should specify a classifier more tightly is out of scope by
   construction; a finding that its stated acceptance evidence **would not actually discharge the
   criterion** is in scope and valuable.

**You are explicitly licensed to reject that framing.** If you think this scoping protects the
artifact from legitimate criticism, say so as your first finding and argue it.

## What is settled — do not re-derive

- **ADR-001's D1–D11**, its *Gate mechanisms* boundary, its acceptance table, and its
  `## Implementation handoff` three-item ordering. Accepted. Not this review's subject.
- **The survey in the plan's first section.** Every row was re-measured against HEAD by the author,
  and `git diff --stat a0d4edb..HEAD -- src packages scripts Makefile .github tools` is empty — so
  every figure the two acceptance reviewers independently verified still holds. **Spot-check it, do
  not re-run it wholesale.** If you spot-check, the cheapest high-value checks are the clock
  inventory (13 sites), the `.ai_step(` call sites (2), and `ExtPorts.clock_now` (0 calls).
- **M1 and M2**, the spike's measurements, in `NOTE-spike-findings-real-driver-vertical.md`. Cite,
  do not re-estimate.
- **Classifier 1**, built and verified: `make effect_inventory` → 0 unresolved,
  `make effect_inventory_selftest` → `agree=43 disagree=0`. Re-run it if you like (it is fast); do
  not re-specify it.

## In scope

**1. The six decisions the plan owns** (`:42-97`). The ADR left these open and the plan answers
them. Each is a genuine judgement call that could be wrong:

| | Decision | The claim to test |
|---|---|---|
| P1 (`:47`) | `ProviderState` is a record, not a sum | Does the M1 citation actually license this? See *Where I am least confident* |
| P2 (`:55`) | Approval/clock cursors do **not** ride along | The ADR warns that guessing wrong reproduces the bidirectional widening. This is the highest-stakes decision in the plan |
| P3 (`:66`) | Clock routing order; `driver_only` claims 4 sites | Is the ordering right, and is the claim properly gated on the attribution table? |
| P4 (`:75`) | First profile named `driver_only` | Does an empty install list actually satisfy D5's per-extension disclosure row, or is that row undefined for the empty case? |
| P5 (`:89`) | Stale-comment deletion folded into WI-A2 | Trivial; check the anchor is right |
| P6 (`:94`) | `Ports.hooks_runtime` removed | Author verified *zero calls of the field*. Not the same as *zero cost to remove* — it changes `ports_shape_probe`'s signature |

**2. The dependency graph** (`:98-315`). Every `Depends on` clause. Look for missing edges, false
edges, and cycles. The two scheduling prohibitions are load-bearing and the plan claims to honour
both: D6's (no parity invariant depending on the logical/display-only classification before the
vocabulary exists) and D4's (no routing-completeness claim before the attribution table validates).
Check they are actually honoured, not merely asserted — the ADR was burned five times by passes that
asserted successful propagation in the same edit that failed to propagate.

**3. Acceptance evidence, item by item.** For each work item: would the stated evidence actually
demonstrate the thing was done? This is where a reviewer adds the most value. Specifically, is any
item's evidence *unfalsifiable*, *circular*, or *weaker than the ADR criterion it points at*?

**4. Sizing honesty.** The handoff mandated sizing against M1/M2 rather than re-estimating. Items
covered by M1/M2 cite them. Items not covered (A1, A2, A4) carry estimates by analogy. Are those
analogies sound, and are they visibly marked as estimates rather than measurements?

**5. Milestone boundaries** (`:328-338`). Does each milestone end where the plan says, and does
Milestone A genuinely deliver everything except streaming parity and extension-model coverage?

**6. Completeness against the ADR.** Is there an ADR obligation with no home in this plan? The
author found two such gaps in self-review (D8's generator canary, D8's shrinking-deferral record) and
scheduled both. **Assume there are more.** This is the single most likely place for a real finding.

## Out of scope

- The architecture (D1–D11). Accepted.
- How any detector decides anything. Scheduled as builds; that is the design.
- Whether the upstream recorded-stream API will land, and when. Externally blocked, tracked at
  `sunholo-data/ailang#546`, and the plan is deliberately structured not to idle against it.
- Restating the ADR's own `## Implementation handoff`. The plan extends it by mandate.

## Where I am least confident — probe these

Per the standing discipline, **probe the case you do not already believe**. Three ADR passes
asserted a category property without checking the artifact and each was caught by a reviewer building
the probe the author should have built. These are the author's own candidates, offered so you can
spend your effort where it is most likely to pay:

1. **P2 is the highest-stakes claim and rests on an argument, not a build.** The plan says the risk
   of a second bidirectional widening is "closed structurally": because `ProviderState` is a record
   (P1), adding a clock or approval cursor later is an additive field, and the *port signature*
   does not change. **If that is wrong — if a later cursor forces the port's input shape to change
   again — P2 is wrong and the ADR's warning has landed.** Nobody has built it. A three-module probe
   on the pin would settle it in an afternoon, the same way the `ProviderState`-in-`ports.ail`
   question was settled. This is the probe I would build first.
2. **P1's M1 citation does lighter work than it looks.** M1 measured the `Message` migration: 69
   additive record sites, and 7 judgement sites that were about *type identity* (`Msg` vs `Message`),
   not about record-versus-sum. The inference "record widening is cheap, therefore prefer a record"
   is an analogy across a boundary M1 did not test. It may still be the right call — but if you think
   the citation over-claims, that is a fair finding.
3. **WI-A9's acceptance evidence may need WI-A8.** A9 asserts "exactly one `RunSummary` as the final
   record on every terminal path." The author's judgement is that this is a *structural* check on the
   returned trace and therefore decidable without the event vocabulary, so A9 carries no A8
   dependency. If you think appending or identifying a `RunSummary` requires the vocabulary's wire
   names or classification, D6's scheduling prohibition bites and the dependency is missing.
4. **P4's vacuous satisfaction.** `driver_only` installs nothing, so the coverage floor and
   per-extension hook disclosure hold with no extensions to hold over. The plan says "vacuously";
   check whether D5's acceptance-table row wants something a profile with an empty install list
   cannot supply, in which case the first profile cannot pass its own gate.
5. **The 32 `provider:` figure** (`:27`, `:127-128`) is a grep count over `session.ail` that mixes
   loop-state successor literals with entry-point signatures. It is used to *bound* an edit surface,
   which is the conservative direction, but it is not a count of anything precise. If you need a
   precise number, derive it; if you think the plan should not cite an imprecise number at all, say
   so.

## What the author already did, so you do not repeat it

Four self-review passes, findings **11 → 9 → 1 → 0**, committed at `a339629` with the full list in
the commit message. Round 1 caught a field miscount, three line drifts, an imprecise P2 claim, two
missing dependencies, and the two D8 gaps. Round 2 caught two wrong cross-references (P3 pointed at
the wrong work items), a self-referential count, and a stale-risk figure. Round 3 caught one
malformed list. Round 4 was clean, which is why the loop stopped.

**Read that commit message before starting.** Re-finding a corrected defect is a signal the
correction failed to propagate — genuinely worth reporting — but re-finding one that *was* corrected
is noise, and telling the two apart is cheap.

## Known traps

- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors**, reproducibly across a compiler
  version change. Clear every `.ailang/cache` before believing a type error that contradicts source.
- **Do not run probes from `/tmp`.** AILANG auto-relaxes `MOD010` there, so a stdlib walk reports
  clean when CI would not. Verified again on 2026-08-02 while filing the upstream report.
- **The spike branch is not HEAD state.** It carries driver surgery that is not in the tree;
  importing its measurements as HEAD facts is a defect this ADR paid for repeatedly. Note the plan
  deliberately cites the spike for *measurements* (M1/M2) and *feasibility*, never for HEAD state.
- **The `arniwesth/ailang` fork is not the upstream gate cleared.** D1 requires a *release*.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`, Makefile-guarded.

## Output

**File your findings in a new document in this directory — `REVIEW-implementation-plan-*.md` — not
appended to the plan.** This is deliberate and it is the one process change this project's
retrospective most clearly earns: ADR-001 became 78% review commentary by volume (7,640 review lines
against 2,127 body lines), and that growth was itself a cause of the propagation failures. Keep the
plan a plan.

Use the same finding shape the ADR reviews used — numbered `R1…Rn`, each with **Defect**,
**Grounding** (file:line, or the command you ran and its output), and **Action**. Close with:

- **findings per pass**, if you ran more than one;
- an explicit **Accept / Accept-with-conditions / Revise** recommendation on the question in *Mission*;
- and, if you built any probe, what it showed — including the negative results. A probe that
  confirmed the plan is worth as much as one that broke it, and this project has under-recorded the
  former.

If your review is clean, say so plainly and stop. A short clean review is the correct output when the
artifact is sound, and padding it to look thorough is the failure mode that produced 154 findings.
