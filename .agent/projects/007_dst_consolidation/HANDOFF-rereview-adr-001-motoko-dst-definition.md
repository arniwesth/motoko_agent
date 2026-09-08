# Handoff: re-review ADR-001-motoko-dst-definition-and-taxonomy.md

Audience: a fresh agent session with no context from the authoring session or from the first
independent review. This ADR has already been reviewed once (12 findings, `R1`–`R12`) and revised.
Your job is **not** to repeat that review. It is to decide whether the revision earned acceptance.

Two ADRs are blocked behind this one. `../009_motoko_dst_execution/ADR-001-…` declares
`Depends on: 007 … after review disposition and acceptance`, and the naming rule in D3 governs what
every future PR in this repo is allowed to call itself. An ADR accepted on a disposition that only
*looks* complete propagates into both.

## Mission

Re-review `.agent/projects/007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md`
for acceptance.

It is a **definitional** ADR: it decides what "DST" is entitled to mean in this repo (D2), a scope
boundary (D1: single-actor, logical-fault; physical-fault and multi-actor excluded), a naming rule
(D3: HEAD is PBT, the word "simulation" is barred until the bar is met), and where the environment
boundary sits (D4). It decides no implementation.

**Three failure modes, in order of how much damage they do:**

1. **A disposition that did not actually land.** The `## Review Disposition` table claims all twelve
   findings were absorbed, and states plainly: *"No finding was rejected."* That is a pattern worth
   suspicion, not comfort. A self-dispositioned review is exactly where a finding gets marked
   *Accepted* while the body change is cosmetic — or where a claim is "fixed" by being watered down
   until it no longer says anything. Grade every one.
2. **New text nobody has reviewed.** The revision did not just patch sentences. It added the
   conformance-profile reframing, six D2 evidence criteria, a rescoped HEAD scorecard, and a
   "Revisit tripwires" block carrying four fresh source anchors. **None of that has ever been
   independently reviewed.** It is the largest unexamined surface in the document.
3. **The acceptance deadlock.** See below — it may make acceptance impossible as currently written.

## The deadlock, stated plainly

Resolve this; it is the single most consequential thing in the re-review.

- `009/ADR-001` header: depends on 007 "after review disposition and **acceptance**."
- `007` §*Residual items blocking acceptance*, item 3 (preventive hermeticity rule, from R10):
  "**Owned by 009** — it is the concrete form of D2 evidence item 6."
- 009 cannot be accepted until an upstream AILANG API lands (independently blocked).

So 007 is blocked on 009, 009 is blocked on 007, and 009 is additionally blocked on a third party.
Taken literally, neither ADR can ever be accepted.

Rule on it. The plausible resolutions — pick one and say why:

- Item 3 is **not** actually acceptance-blocking for 007 (it is future implementation work), and the
  section heading over-promises. The residual list would need re-partitioning into
  *blocking* vs *tracked*.
- Item 3 belongs to 007 after all, and should be discharged here as a review/gate rule.
- The 009 dependency is on 007's *disposition*, not its *acceptance*, and 009's header is wrong.

## Inputs (read in this order)

1. **The ADR itself** — read `## Review Disposition`, `### Residual items blocking acceptance`, and
   `## Review Comments` *before* the body. The disposition table is your worklist; the preserved
   findings are the specification the revision was written against.
2. `HANDOFF-review-adr-001-motoko-dst-definition.md` (this directory) — what the first reviewer was
   asked to do. Anything that handoff demanded and the first review did *not* deliver is still
   open, and will not appear in the disposition table.
3. `../009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` — the follow-up
   that inherits every delegation. Six findings were dispositioned "Delegated" to it; confirm it
   actually accepted them.
4. `design_docs/implemented/motoko_agent/m-motoko-dst-framework.md` — residual item 1 claims this
   was refreshed on 2026-07-24 and marks itself `~~struck through~~ closed`. Verify.
5. `NOTE-Motoko-Agent-DST-vs-LLM-trace-replay.md` (this directory) — the source analysis. R1 turned
   on the ADR having escalated the note's "small step" claim; check the revision did not
   re-introduce it elsewhere.
6. Source, for the citation audit in Pass 2.

## Review method (five passes, all required)

### Pass 1 — Disposition audit (the load-bearing pass)

For each of `R1`–`R12`: go to the claimed landing site, read what is actually there, and grade it.

| Grade | Meaning |
|---|---|
| **LANDED** | The body change addresses the defect the finding named |
| **COSMETIC** | Wording changed; the defect survives |
| **OVERCORRECTED** | The claim was weakened past the point of saying anything, or a new defect was introduced |
| **NOT FOUND** | The claimed change is not in the body |

Three deserve extra weight because the disposition table itself flags them as incomplete —
`R4`, `R7`, `R9`, and `R10` are marked **Partial**, each with a named residual. A *Partial* whose
residual is quietly discharged elsewhere, or never discharged at all, is a finding.

Two to attack hardest:

- **R3 → the conformance-profile reframing.** The fix was to stop presenting seven pillars as the
  field's definition and present them as *this repo's policy*, with pillar 2 as the definitional
  center. Read the new section. Does it now under-claim — i.e. if 3/4/5 are "local policy," does D2
  still have any authority to *withhold* the name? The naming rule's force depends on the answer.
- **R8 → the six D2 evidence criteria.** R8's defect was that D2 was a checklist, not a gate. Six
  criteria were added. Pass 5 tests whether they are actually enforceable.

### Pass 2 — Citation audit of the *new* text

Every anchor added by the revision is unreviewed. Verify each against current source, and confirm
the line ranges say what the ADR claims:

- D1.1 tripwire: `src/core/tool_phase.ail:314-357`, `src/core/tool_runtime.ail:155-160`,
  `src/tui/src/runtime-process.ts:628-634`
- D1.3 tripwire: `src/core/session.ail:2209-2216`
- D1.3 gap: `src/core/session.ail:1525-1529,1609-1614` and `:1538-1557`
- Scorecard: `src/core/ports.ail`, `src/core/test/scripted_ports.ail`,
  `scripts/dst/phase_c_seeded_dst.ail`
- R11's replacement claim: that `config.ail:110` is a production comment and that no test
  scheduler / injected fault / virtual clock implementation exists. **Re-run the grep.** This is the
  claim that was literally false last time.

### Pass 3 — Residual-item audit

- Items 1 and 2 are struck through as closed. Verify both against the artifacts, not the prose.
- Item 4 (per-class naming inventory) is open and was "folded into item 1." If item 1 is closed and
  item 4 is still open, one of those two statements is wrong.
- Item 3 — the deadlock. Rule on it per the section above.

### Pass 4 — Cross-ADR consistency with 009

007 and 009 make overlapping claims about the same source, written at different times.

- Do they cite the same anchors for the same facts? (007 D1.1 cites `tool_phase.ail:314-357`; 009
  cites `:302-357` for a related claim. Decide whether both are right.)
- 009 carries a "Mapping to the project-007 conformance profile" table. Does each mapping hold, and
  does 009 actually accept the six delegations 007 sent it?
- 007 pillar 5 requires "a stepped virtual clock carried in the script; timeouts reachable."
  009's streaming spike has since established a relevant fact: the provider chunk callback's
  effect row is closed to `{IO}` and rejects `Clock`, so chunk arrival times cannot be observed
  (`spike/README.md`, D1 world-protocol slice section). 009 concluded this is not a gap, because
  discovery *generates* latency rather than observing it. Confirm 007's pillar-5 wording is
  consistent with that and does not imply an observation capability that does not exist.

### Pass 5 — Enforceability re-test

R8's defect was that a future reviewer could not mechanically decide when the bar is met. Test the
fix by using it: take the six D2 evidence criteria and apply them to HEAD as if reviewing a PR that
claimed the DST name.

- Can you reach a yes/no on each, or does one still require judgement?
- Criterion 6 (hermeticity probe) is the one whose enforcement mechanism is residual item 3 — the
  deadlocked one. If the gate's own enforcement is unbuilt, is D2 enforceable today?
- Does the D3 grandfather clause cover every existing `dst` identifier, or does an uncovered class
  still contradict the rule? (`make dst` / `dst_seeded` at `Makefile:75-80`, the module and PASS
  names in `scripts/dst/*_seeded_dst.ail`, the `DST seeded gate` workflow label, the as-built title.)

## Leads I already checked, so you don't spend time on them

Reported so you know what has and has not been touched. None of these is a finding yet — each is a
call for you to make.

- **As-built doc (residual 1) looks genuinely closed.** The claimed additions are present: a
  `Naming` caveat (`:5`), an "Amendment: what this framework is *not*" section (`:36`), a "The
  seeded axis" section (`:130`), and `dst_seeded` in the gate tree (`:202`). I did not check whether
  the content is *correct*, only that it exists.
- **The tui anchor narrowed between reviews.** The first review cited
  `src/tui/src/runtime-process.ts:618-642`; the revision cites `:628-634`. The narrowed range does
  land on the `for (const call of calls)` loop with its sequential `await`. Confirm the narrowing
  did not drop the part that made the claim load-bearing — this anchor carries D1.1, and D1.1
  carries the whole multi-actor exclusion.
- **`DST_SEEDS` is not defined in the Makefile.** The pillar-7 scorecard row says "default
  `DST_SEEDS=5 DST_BASE_SEED=1`" and R9's grounding cites `Makefile:74-80`. The default actually
  lives in the script — `getEnvOr("DST_SEEDS", "5")` at `scripts/dst/phase_c_seeded_dst.ail:568` —
  and the only place the variables are *set* is `.github/workflows/verify-extensions.yml:101,103`.
  The number is right; the attribution is loose. Your call whether that clears the bar for an ADR
  whose whole subject is claims resting on accurate grounding.

## Output contract

Append a `## Re-Review Comments` section to the ADR. **Do not** rewrite the body, and do not touch
the existing `## Review Comments` or `## Review Disposition` — they are the audit record.

State your model id and the date at the top.

Number findings `RR1..RRn`, most severe first, so they cannot be confused with the first review's
`R1`–`R12`. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then include, in this order:

1. **Disposition audit table** — one row per `R1`–`R12` with your grade and a one-line justification.
   This is the deliverable the author most needs; it is what says whether the revision worked.
2. **Deadlock ruling** — one paragraph. Which resolution, and why.
3. **What is accurate** — name the claims you re-verified and confirmed, so a later reader knows the
   evidence was checked rather than assumed.
4. **Accept / revise recommendation** — one line: accept, accept after N specific edits, or revise.
   If you recommend acceptance, say explicitly what happens to the open residual items.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, other ADRs, the as-built doc, or
  this ADR's body.
- **Do not re-litigate settled decisions on taste.** The naming rule (logical-fault DST, "Soft DST"
  rejected, HEAD = PBT) and the two exclusions (D1.1 single-actor, D1.3 physical-fault) stand unless
  you can show they conflict with source reality, the DST literature, or the ADR's own internal
  logic. Attack the claims underneath them, not the preference.
- **Do not re-derive the first review.** Its twelve findings are settled *as findings*. Your question
  is whether the revision discharged them. A thirteenth defect is welcome, but hunt it in the new
  text first — that is where the odds are.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify. Report the exact
  command for any failing or surprising result.
- If nothing survives, say so plainly and still record residual risk. The likeliest one: this ADR's
  authority is a naming discipline the team has to keep by hand, and nothing in the repo enforces
  D3 today.
