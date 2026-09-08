# Handoff: delta review of the third correction pass to ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the correcting session. The corrections you are
reviewing were written by the authoring side in response to two delta reviews. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

**This is a narrow delta review.** The ADR has had an author self-review, two independent reviews
(2026-07-26), three independent verifications of the F1–F6 revision (2026-08-01), and two independent
delta reviews of the second correction pass (2026-08-01) — seven `## Review Comments` sections. The
architecture has been reviewed to exhaustion. Your target is one commit.

## Mission

Verify the **third correction pass**, which answers all findings from the two delta reviews recorded
as the ADR's sixth and seventh review sections.

## You have a real diff this time

The previous two rounds had no reviewable baseline, and it cost them: the first delta review reported
that three of its seven findings were anchor errors "a two-line diff would have surfaced in seconds."
That is fixed. The record is now committed one pass per commit:

```text
4ea8862  the two delta reviews (verbatim, committed before any response)  <-- YOUR BASELINE
5db6706  third correction pass
<HEAD>   the "profile-reachable" definition (A3) + this handoff
```

Your target is everything after the reviews:

```text
$ git diff 4ea8862..HEAD -- .agent/projects/009_motoko_dst_execution/
```

That range is the complete, exhaustive set of corrections. Note it spans **two** commits: `5db6706`
answers the delta reviews' findings directly, and the follow-up adds the `profile-reachable`
definition (A3), which no reviewer requested — it resolves a tension the corrections exposed and is
therefore the least-scrutinized text in the range.

**There is no hand-maintained edit table this time, deliberately** — the last one was incomplete and
both delta reviews caught it. If the diff and the commit messages disagree, the diff wins and that is
a finding.

## What changed, and what to attack

Six substantive corrections and five mechanical ones. Grounding is given so you can go straight at
each.

### A1. The `Ports.model_step` bidirectional widening may not be expressible as specified

D1 now says the interim provider operation "takes the current provider state and returns its
successor, alongside `emissions` and the outcome," with the sole persistent copy in a named
`C2LoopState` field. Both delta reviews demanded this shape; **neither specified it, and neither
verified it is buildable.**

- `live_ports` (`src/core/test/stub_step.ail:148-154`) is stateless — it wraps `stepWithStream` and
  holds nothing. What does the live adapter return as its successor state? If the answer is a unit or
  an ignored value, the ADR does not say so, and every construction site now carries a field with no
  meaning on the live path.
- `Ports` is a record of closures and `C2LoopState` is an immutable record threaded through
  recursion. Confirm the state-in/state-out shape composes with both — that a closure can accept
  state it did not capture and that the driver can thread the successor without a second home
  appearing.
- Six construction sites funnel through `ported_provider` (`src/core/session.ail:695-701`, called at
  `2015, 2051, 2114, 2137, 2267, 2295`). Check the widening is actually applicable at all six, not
  just the scripted one.
- If the shape does not work, say what does. This is now sequenced first in the implementation plan.

### A2. D5 obligation 2 names a detector but does not enumerate what it detects

The replacement is "a conservative textual inventory of ambient-effect imports and call names."
**"Ambient-effect imports" is never defined anywhere in the ADR.**

- Is that set enumerable and stable? `std/clock`, `std/fs`, `std/process`, `std/net`, `std/env`,
  `std/rand`, `std/ai`, `SharedMem` — is that the list, is it complete against pinned v0.26.0, and
  does it change when the toolchain repins to v0.31.0 (which the Consequences section says forces an
  ABI major)?
- Does the specification handle **aliased imports** (`import std/clock (now) as c`) and re-export
  chains? There are no aliased `std/clock` imports at HEAD — confirmed by two prior reviews — but a
  detector that only works because the tree happens to be clean is not a gate.
- The stated soundness boundary is: blind outside the AILANG tree, and does not decide reachability.
  Is that boundary complete? Consider effects reached through `ExtPorts` closures supplied by a
  package the inventory did scan.
- The prior two attempts at this obligation were both wrong, in opposite directions. Assume this one
  may be too.

### A3. "Profile-reachable" was just defined as installation-scoped — check the definition holds everywhere the term is used

D4 now defines a read as profile-reachable "when it occurs in the core driver or in a module the
profile *installs*", explicitly **not** the result of a reachability analysis, because D5 obligation
3 declines to require one. This definition is new in this pass and is the author's resolution of a
tension the delta reviews did not raise.

- Check every other use of "profile-reachable" and "reachable in the profile" is consistent with it —
  in particular the acceptance table row *Does virtual time matter?* and the row *Is the tested
  boundary honest?* (which says "every profile-reachable hook"). If a hook's classification was meant
  to be reachability-scoped, the definition just changed what that row demands.
- Is installation-scoped the right choice? It is deliberately conservative — a read in an installed
  extension must be routed even if unreachable — which makes conformance harder, not easier. Confirm
  that is a sound trade and that it does not make some existing profile unachievable.

### A4. D4's profile relabelling (Codex R3) — verify the underlying configuration facts

The pass asserts that no checked-in configuration realizes all thirteen clock reads.

- Re-verify: `.motoko/config/default/config.json`'s extension order, that `compose` appears only in
  `.motoko/config/ailang/config.json`, that `test_dummy` appears in no checked-in config, and that
  `parse_tokens` (`src/core/ext/registry_generated.ail:51-65`) instantiates only names in the order.
- Check the arithmetic in the new text: "a profile installing no clock-reading extension has four
  sites to route; one installing `compose` has twelve." Confirm 12 is right and that excluding
  `test_dummy` from that figure is correct.
- The per-row "reachable when" column is new. Verify each condition.

### A5. Anchors, again — three consecutive passes have each shipped anchor errors

Every anchor introduced or changed in `5db6706` is unverified by any reviewer. Re-run all of them:

`src/core/ext/registry_generated.ail:51-65`; `src/core/test/scripted_ports.ail:38-48`;
`tools/code-graph/extractor/config.py:13-17`; `tools/code-graph/extractor/source_parser.py:176-199`;
`src/core/agents_md.ail:106`; `src/core/ports.ail:18`; and the re-corrected
`src/core/test/stub_step.ail` ranges — `88-96`, `148-154`, `157-168`, `192-199`, plus the *Known
stale source comment* note's `171-172` and `190-191`.

The note's ranges were wrong in the previous pass in a way that would have deleted a correct line
(`:170`) and left a stale one (`:172`). Verify the corrected ranges are exact, because a deferred
source fix is only safe if its target is.

### A6. The Status block has been rewritten three times

It now claims two blockers distinguished by kind, and that neither the correction set nor the
acceptance state is complete. The previous version contradicted itself on exactly this
(Codex R4).

- Check it does not contradict itself or the body a third time.
- Check the "settled" list is accurate against what the seven review sections actually ruled — the
  previous pass overstated D6.1 as confirmed three times when it was two.

### A7. Did the corrections break anything untouched?

The pass edited D1, D4, D5, the Status block, the Context table, and Implementation Handoff items 1–2.

- D5's third hermeticity bullet and D4's clock-detector sentence were both rewritten so they no
  longer assert the withdrawn over-approximation claim. Confirm they now agree with obligation 2 and
  with each other.
- The 007 pillar-mapping table (pillar 1 cites "capability/routing audits") and the acceptance table
  both reference the audit. Confirm they still describe what D5 now requires.

## Settled — do not reopen

Confirmed across the prior seven sections, on executed evidence:

- **F1, F2, F3, F5, F6**; the **narrowed D1 blocking clause**; the **upstream return-shape ruling**;
  **M2**. Confirmed by all three verifications.
- **D6.1's zero-`RunSummary` claim** — by two of the three (Codex and Kimi; Claude cites only its
  call-site count).
- **D4's clock count of 13** and **"nothing is routed at HEAD"** — independently re-derived by both
  delta reviews. A4 above is about the *label* on that set, not the count.
- **Corrections C3, C4, C5, C9, C14** from the second pass — confirmed by both delta reviews.
- **Anchors in files untouched since `7b9b4a4c`** — spot-checked by five reviewers.

## Leads already checked — do not re-derive

- The pre-correction blob for the *second* pass (`374d46fbe`) is unretrievable. Irrelevant now; your
  target commit has a clean parent.
- `ExtPorts.clock_now` has **zero call sites repo-wide**; `clock_now` hits are constructions,
  definitions, or the `p.clock_now` pass-through at `session.ail:675`.
- `ledger_record_name` names 3 of 34 `LedgerEvent` variants.
- No aliased `std/clock` imports; zero `sleep(` sites in `src`, `packages`, `scripts`.
- `scripts/dst/spike_scripted_cursor_probe.ail` exits 1 by design and is deliberately unwired.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors.** Clear every `.ailang/cache`
  before believing a type error that contradicts the source you are reading.
- The pin is v0.26.0 in `ailang.toml` and `scripts/install-prerequisites.sh:39`.

## Output contract

Append an **eighth** `## Review Comments` section to the ADR. There are seven. Count them yourself
before appending — a previous handoff said "third" and was executed three times.

Do not rewrite the body, and do not edit any existing review section. All seven are historical
records, including the two that overturned the authoring side's own diagnosis.

State your model id, the date, and the commit you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name what you re-ran and confirmed. Three deserve an explicit ruling:
   whether the bidirectional widening (A1) is buildable as specified, whether D5 obligation 2 is now
   specified well enough to build (A2), and whether the new "profile-reachable" definition holds
   across every use (A3).
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line, and say explicitly what happens to the upstream API
   blocker.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify.
- **Do not treat the fork prototype as the gate cleared.** `arniwesth/ailang` carries a working
  `stepWithStreamRecorded` on the `v0.31.0` tag; D1 requires the API to land in a *release* with the
  toolchain repinned. A fork is not that.
- **Do not treat the throwaway spike branch as HEAD state.**
- If the corrections hold, say so plainly and record residual risk. The likeliest surviving
  candidates, in order: A1 (a widening shape specified but never checked against the live adapter),
  A2 (a detector named but its detection set undefined), and A3 (a term defined in this pass whose
  other uses were not all re-read).
