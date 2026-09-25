# Handoff: independently review ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the authoring session. Your distance from the
author is the point — you are the check the author cannot perform on themselves.

This ADR has had an **author self-review** (Codex `GPT-5`, five adversarial passes, recorded at the
end of the document) and it says plainly that this "is an iterative author-side review, not the
independent review required before acceptance." That is you. Assume the easy findings are gone and
the surviving defects are conceptual, empirical, or architectural.

Two things now depend on the outcome. `../007_dst_consolidation/ADR-001` was **accepted
2026-07-26** and its D2 gate now points at *this* ADR's D3 as the normative fault catalogue, so a
defect here propagates into an accepted decision. And this ADR is the one that authorizes a
migration touching the session driver, tool runtime, approvals, extensions, clock, and trace — the
most invasive change proposed in this repo so far.

## Mission

Adversarially review
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md`
for acceptance.

It is an **implementation-architecture** ADR: eleven coupled decisions (D1–D11) that specify a
driver-owned deterministic world, a seed-driven discovery/replay split, a fault catalogue, a virtual
clock, a profile/manifest model, a terminal-trace contract, whole-execution invariants, a
reproduction artifact, a sequentiality boundary, a naming rule, and a search gate.

**The failure modes that matter, in order:**

1. **A decision resting on a false claim about the source.** The Context section carries a
   seventeen-row table of `file:line` anchors (`ADR:109-127`) and D1–D11 add more. Every one is
   load-bearing for a decision. This is the same failure that produced eleven of the twelve findings
   in the 007 review.
2. **An architecture that does not work.** Eleven decisions that must hold *together*. D1's
   explicitly-threaded world state is the keystone: if it cannot actually be threaded through the
   real driver, most of the rest is unbuildable and the ADR is a plan for a thing that cannot exist.
3. **A gate that cannot be applied.** The acceptance test (`ADR:698-718`) is eleven rows of required
   evidence. If a future reviewer cannot mechanically decide them, the ADR has the defect 007's R8
   named — a checklist wearing a gate's clothes.

## Inputs (read in this order)

1. **The ADR.** Read `## Author self-review record` (`ADR:880`) first — it tells you which attacks
   were already run, so you can spend your effort elsewhere.
2. `../007_dst_consolidation/ADR-001-motoko-dst-definition-and-taxonomy.md` — **now Accepted**, so
   its D1–D4 are binding constraints on this ADR, not peer opinions. Its `## Review Comments` and
   `## Re-Review Comments` are also the output quality bar.
3. `spike/README.md` — the executable evidence base, including two probes added 2026-07-25 that
   post-date the ADR body: a direct positive integration probe and a D1 world-protocol vertical
   slice. Both pass against a local prototype. **Read the caveats, not just the PASS lines.**
4. `NOTE-scope-and-sequence.md` and `NOTE-ailang-world-overlap.md` — project boundary, rollout
   order, and the AILANG World terminology-collision risk.
5. `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` and
   `../001_DST/ADR-001-deterministic-simulation-testing-architecture.md` — the two ADRs this one
   **amends** (`ADR:16-26`). Verify it amends what it claims and preserves what it claims.
6. Source, as needed for the citation audit.

## Review method (six passes, all required)

### Pass 1 — Citation audit

Verify every `file:line` in `ADR:109-127` and every source-grounded claim in D1–D11 against current
source. A wrong line, a stale name, or a paraphrase the source does not support is a finding. Note
the ADR is grounded at `7b9b4a4c` while HEAD has moved; re-verify at HEAD and say which revision you
used.

### Pass 2 — Attack D1, the keystone (highest priority)

D1 requires the real driver to own and thread `world_state` explicitly — no `SharedMem` cursor, no
process global, no ambient RNG, no mutable test singleton. Everything else assumes it.

- Is that *actually* threadable through `C2LoopState`, provider dispatch, tool phases, approval
  resumption, and the traced entry point — or does something in the current recursion make it
  infeasible without a rewrite the ADR does not budget for?
- D1 says the same request/response types and transition code serve both `LiveWorld` and
  `DeterministicWorld`, and that production code "does not branch on test mode." Is that reachable
  from the current seams, or does it require production code to know it is being simulated?
- The ADR forbids hiding the simulator behind `Ports.hooks_runtime` and requires that callback to
  gain a demonstrated purpose or be removed. Check that is a real disposition, not a deferral.

### Pass 3 — The streaming gate: what is actually proven

This is where the evidence has moved most since the body was written, and where the risk of
over-reading it is highest.

- The ADR states the blocker is current through v0.30.0. It is also current on `dev`
  (`24120ade2`) — verify.
- A **working local prototype** of the proposed API exists at `~/src/ailang` (branch `dev`,
  uncommitted), and the spike's integration probe and world-protocol slice both pass against it.
  **A prototype is not the gate.** D1 requires the API to have *landed* and the toolchain to be
  *repinned*. Confirm the ADR's acceptance conditions cannot be read as satisfied by a local patch,
  and that `spike/README.md` says so too.
- The spike established that the chunk callback's closed `{IO}` row rejects `Clock`, so chunk
  arrival times cannot be observed. The conclusion recorded is that this is *not* a gap, because D2
  generates latency rather than observing it. **Re-derive that independently** — if it is wrong, D2's
  "non-decreasing virtual offsets" clause is unreachable and the upstream ask is incomplete.

### Pass 4 — Consistency with accepted 007

007 is no longer negotiable, so a conflict is this ADR's defect to fix.

- Walk the mapping table (`ADR:686-696`) row by row. Does each 007 pillar actually get what it
  claims from the named decision?
- **007 D2 now names this ADR's D3 as the normative minimum fault catalogue.** D3 was written as
  this project's internal requirement, before it carried that authority. Is it complete and precise
  enough to be normative for another ADR's gate? Does it map every class to a *named* production
  recovery branch, as it promises?
- 007's accepted D1.3 excludes physical faults and D1.1 excludes multi-actor concurrency. Does D9's
  sequentiality boundary agree, and do the tripwires match on both sides?
- 007's Consequences now enumerate four independent versioned axes — program schema, generator
  version, profile version, execution manifest — plus a wire vocabulary shared with the TUI. Does
  D5/D8 actually deliver all four, or does 007 now promise something this ADR does not supply?

### Pass 5 — Enforceability of the acceptance test

Apply the eleven rows of `ADR:698-718` to HEAD as if reviewing a PR claiming the DST name.

- Can you reach yes/no on each, or does one need judgement?
- The trace contract (D6) requires exactly one canonical `RunSummary` per `SystemRun` and every
  logical event in the returned trace. `LedgerEvent` currently has 34 variants whose wire names live
  in trailing comments rather than in a type, and the TUI dispatches on those names in a separate
  process. Is D6 enforceable across that boundary, or does it need a mechanism it does not name?
- D5's hermeticity gate combines capabilities, a routing audit, poison probes, and profile
  validation. Is that buildable as described, or is any leg aspirational?

### Pass 6 — Amendment fidelity and internal consistency

- Does it amend 004 and 001 exactly as claimed, preserving what it says it preserves?
- Are D1–D11 mutually consistent? Look hardest where two decisions touch the same object: D1 and D6
  on emissions versus trace append; D2 and D8 on program identity; D4 and D3 on deadline-derived
  timeouts; D5 and D7 on what invariants can see.
- The ADR rejects splitting itself into separate ADRs (`ADR:775-780`). Attack that: is any decision
  genuinely independent enough that coupling it here obscures rather than clarifies?

## Leads already checked — do not spend time re-deriving these

Reported so you know what has been verified and by whom. None is a finding; each is context.

- **The v0.30.0 claims hold.** Release archive SHA-256 `58561c11…`, compiler commit `e37b370d…`,
  `std/ai.ail:331-337` unchanged, both negative probes reproduce. Re-verified 2026-07-25.
- **`dev` also lacks the API.** `24120ade2`, `std/ai.ail:330-337` identical, full-source search finds
  no recorded-stream variant. This post-dates the ADR body.
- **Both new spike probes pass and fail correctly.** Each exits non-zero against the stock v0.26.0
  toolchain, so neither is vacuously green.
- **The `tool_phase.ail` anchor divergence is benign.** 007 cites `:314-357`, this ADR `:302-357`;
  the 007 re-reviewer adjudicated both as correct for their respective claims.
- **A stale `.ailang` compile cache once produced a phantom type error** in `spike/`, and a wrong
  diagnosis of it nearly reached an upstream report. The cache is deleted and the README corrected.
  If you hit a type error that contradicts the stdlib you think you are using, suspect cache
  invalidation before you suspect the compiler.

## Output contract

Append a `## Review Comments` section to the ADR itself. Do **not** rewrite the body.

State your model id and the date at the top.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name the claims you re-ran and confirmed. D1's threadability, the
   single-actor boundary, and the streaming disposition are the three worth an explicit ruling.
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line. If you recommend acceptance, say explicitly what
   happens to the upstream API blocker, which is not yours to clear.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007.** Its definition, scope boundary, naming rule, and conformance
  profile are settled. If this ADR conflicts with them, that is a finding *against this ADR*.
- **Do not re-argue the decision to request an upstream API.** The spike settled it: the IO-only
  projection alternative moves the oracle off the driver. Attack the ADR's claims and its
  architecture, not that premise.
- **Do not treat the local prototype as the gate cleared.** It is evidence that the proposed shape
  works, nothing more.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify. Report the exact
  command for any failing or surprising result.
- If nothing major survives, say so plainly and still record residual risk. The likeliest candidates:
  a concurrency feature silently invalidating D9, and the migration being under-estimated despite
  the ADR's own warning that it must not be treated as a small diff.
