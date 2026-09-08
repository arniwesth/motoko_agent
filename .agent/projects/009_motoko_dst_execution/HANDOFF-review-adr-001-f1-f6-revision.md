# Handoff: independently review the F1–F6 revision of ADR-001-deterministic-test-world-architecture.md

Audience: a fresh agent session with no context from the revising session. Your distance from the
author is the point — and it matters more this round than last, because **this revision was
dispositioned by the authoring side**. The findings it answers (F1–F6) came from a spike, and the
same side that ran the spike decided what each finding meant and wrote the fix. Per
`.agent/meta-decisions/author-each-artifact-in-the-session-whose-assets-it-consumes.md`, adjudication
belongs to the author but *verification never does*. You are the verification.

This is the **third** independent round. The ADR has already had an author self-review (Codex
`GPT-5`) and two independent reviews (Claude Code and Codex, both 2026-07-26), all recorded at the
end of the document. Assume the easy findings are gone twice over.

What is new since those reviews:

- **Six findings from executing the architecture, not reading it** (`NOTE-spike-findings-real-driver-vertical.md`,
  2026-07-31). Both prior reviews read D1 and neither caught F1 or F2. That is not a criticism of
  them — F1's wrong answer type-checks and passes the type-check gate, and F2's trap is an ordering
  that reads correctly on the page. It is a warning about what this document's failure modes look
  like.
- **A revision answering all six**, plus a new `## Upstream recorded-stream API status` section.
  **Corrected 2026-08-01:** earlier drafts of this handoff also promised a
  `## Spike-findings disposition (F1–F6)` section. No such section exists or is planned — the
  normative body is the disposition record, each finding answered in the decision it affects. Two of
  the three verifications correctly reported the section absent; the reference was the error.
- **Source has moved under the ADR.** `89a1d67` (WI-C13c) changed `src/core/session.ail` and
  `src/core/test/stub_step.ail` after both prior reviews certified the source diff was empty.

## Mission

Adversarially review the **revision** to
`.agent/projects/009_motoko_dst_execution/ADR-001-deterministic-test-world-architecture.md` for
acceptance.

You are not re-reviewing the whole ADR from scratch — D2, D3, D7–D11 were reviewed twice and are
substantially untouched by this round. Your target is what changed and what the changes touch.

**The failure modes that matter, in order:**

1. **A disposition that restates a finding instead of resolving it.** The author both found and
   fixed these. The characteristic failure is text that acknowledges the problem in the decision's
   voice without making anything newly decidable. For each of F1–F6, ask: could an implementer now
   get this wrong while still complying with the words?
2. **A new normative claim that is false, unenforceable, or contradicts an untouched decision.** The
   revision adds prohibitions and requirements (see the attack list). Each is new text that has never
   been reviewed by anyone.
3. **The narrowed blocking clause opening a hole.** D1 previously said complete streaming trace
   parity is blocked "and production migration must not begin." The revision narrows this to parity
   only, on F2's grounding. Check that the narrowing is correct *and* that it does not license
   starting the migration before this ADR is accepted.
4. **Anchors.** Same as always, but with a specific new gap named below.

## Inputs (read in this order)

1. **`NOTE-spike-findings-real-driver-vertical.md`** — the six findings, two measurements, and an
   explicit statement of what the spike does *not* establish. Read this before the ADR, so you meet
   the findings in their original voice rather than in the author's disposition of them.
2. **The ADR body's per-finding responses** — F1/F2 in D1, F3/F4 in D4, F5 in D6, F6 in D1 and
   Implementation Handoff item 2. These are the author's claims about what changed and where. Treat
   them as a defendant's summary, not a map. (There is no separate disposition section; see above.)
3. **The ADR body**, specifically D1, D4, D5, D6, Consequences, and Implementation handoff.
4. **`## Upstream recorded-stream API status`** and `REPLY-546-park-unbounded-drain.md`.
5. `spike/README.md`, section *"Vertical spike through the real driver"* — executed commands and
   recorded output behind F1–F6.
6. The two prior `## Review Comments` sections — the output quality bar, and the source of one
   superseded claim you should not mistake for a live one (below).
7. Source, as needed.

## Attack list — the specific new claims

Each of these is text that no reviewer has seen. Grounding is given so you can go straight at it.

### A1. D1's cursor-ownership rule (F1)

The revision makes `world_state` the sole owner of every replay/generator cursor and **prohibits
deriving replay position from mutable message history by name**.

- Is "sole owner" actually achievable given `StepProvider` remains the entry-point argument type and
  scenarios still pass `Scripted(script)`? The revision says the plan "retires `C2LoopState.provider`" —
  check that is a disposition, not a deferral.
- The prohibition makes the currently-executing implementation (`scripted_ports_from_steps`)
  non-conformant. An ADR that renders HEAD non-conformant needs to say so and sequence the
  transition. Does it?
- Both arrangements satisfied the old wording and one silently failed 6 of 18 scenarios. Does the new
  wording actually exclude the failing one, or does it exclude it only by naming it?

### A2. D1's narrowed blocking clause and the port-widening ordering (F2)

- Re-derive the core claim independently: does `Ports.model_step`'s
  `Result[StepResult, AIError]` return type structurally prevent carrying an emission log, and does
  `ported_provider` in fact funnel every provider through it before the loop starts? If that is
  wrong, the whole decoupling argument collapses.
- The revision states a general rule — *widen the port before adopting whatever fills it*. Is it
  right for `approval_read` and `clock_now` too, or is it over-generalised from one case?
- Failure mode 3 above: check the narrowing does not authorize migration pre-acceptance.

### A3. D5's reachability-aware routing audit (F2 consequence)

The hermeticity gate now requires the source/ABI routing audit to be reachability-aware.

- Is that **buildable** on this substrate, or is it aspirational — the exact defect the second review
  attacked elsewhere as "a checklist wearing a gate's clothes"? A reachability analysis over AILANG
  with ADT dispatch is not obviously cheap. If it is not buildable, the decision has traded a false
  positive for an unimplementable requirement.

### A4. D4's clock corrections (F3, F4)

- **F3:** re-run the probe. A function whose row contains `{Clock}` but whose taken branch never
  calls `now()` should complete with the capability withheld. Confirm the "stronger *and* weaker"
  framing is right and that D4 does not now under-claim.
- **F4:** re-count. The revision's table claims 14 reads — 4 driver, 1 `conversation_loop_v2`, 1
  `ext/runtime.ail` `test_dummy`, 8 in `packages/motoko-ext-compose` (compose 6, `author_tools` 1,
  `authoring/dispatcher` 1). **This count was measured on the spike branch at v0.31.0; verify it at
  HEAD on the pinned v0.26.0.**
- Verify `ExtPorts.clock_now` still has zero call sites repo-wide. This is load-bearing for a
  conformance condition now written into D5.

### A5. D6's event-vocabulary ruling (F5)

The revision states the artifact is new construction and that `ledger_record_name` cannot be grown
into it, then forbids scheduling classification-dependent D7/acceptance checks before it exists.

- Verify the 3-of-34 claim at `src/core/phase_vocab.ail`.
- The prohibition has teeth only if something currently schedules such a check. Does D7's parity
  invariant or acceptance row 7 actually depend on the classification? If not, the new sentence is
  inert and should say less.

### A6. D6.1's "zero on every terminal path" claim

The revision asserts that no `RunSummary` reaches the returned trace on any terminal path, because
every terminal summary routes through `emit_run_summary`, whose only ledger operation is the
projection `ledger_emit` rather than the pure `ledger_append` that builds the returned trace.

- Verify at HEAD. If any path appends, the claim is wrong in a way that changes scope.
- The cited call-site list was re-run on 2026-08-01 and **corrected** during the revision: the
  source note says "seven terminal returns", HEAD has five `emit_run_summary` call sites, one of
  which (`1325`) is a shared error-return helper reached from several terminal paths. The ADR now
  cites the sites rather than the count. Check the correction is right — and treat the original
  discrepancy as a live example of why the note's numbers should not be inherited without re-running
  them.
- Note the spike's fix for this lives on a throwaway branch and is **not** at HEAD.

### A7. The upstream status section

- The load-bearing claim is that **none of the parked options (a)/(b)/(c) changes the
  `{chunks, outcome}` type**, which is what licenses designing against the shape now. Re-derive it
  from the upstream design doc rather than accepting it.
- Check the section does not overstate: upstream *recommended* adoption and *parked* on scope. It is
  not merged, and the ADR must not read as though it were.

### A8. M2 on the critical path (Consequences)

- The repin forces an extension-ABI major via three widenings in
  `packages/motoko-ext-abi/types.ail`, and that file states bumping `ExtensionHooks` is a major
  version. Verify the file says that and that the three widenings are real.
- 381 edits across 71 files is a spike measurement, not a re-run. It does not need re-measuring, but
  check the ADR cites it as a measurement rather than as a certainty about the future.

## The anchor gap — read this before Pass 1

Both prior reviews certified that
`git diff --stat 7b9b4a4c..HEAD -- src packages scripts Makefile .github` was **empty**, so every
Context anchor was evaluable at the ADR's grounding revision. That is no longer true. `89a1d67`
changed `src/core/session.ail` (93 lines) and `src/core/test/stub_step.ail` (37).

What the revising session did, precisely, so you can scope your own audit:

- Re-checked the **five** Context rows anchoring into those two files. **Two were stale** — the
  approval/clock-bypass row and the `RunSummary`-emission row pointed at a `c2_loop` call, a type
  signature, and a record field. Both were corrected and marked *re-grounded 2026-08-01*.
- **Did not re-verify the remaining Context rows.** Those anchor into files unchanged since
  `7b9b4a4c`, so the two prior reviews' certification still covers them — but that is an inference,
  not an observation, and it is exactly the kind of inference this repo has been bitten by.

Spot-check the uncorrected rows. If the inference holds, say so; it is worth one explicit ruling.

## Leads already checked — do not spend time re-deriving these

Context, not findings.

- **Upstream #546 status, verified 2026-08-01 via `gh`.** Maintainer `sunholo-voight-kampff` triaged
  (`#issuecomment-5144148253`) and reviewed (`#issuecomment-5144770360`); this project replied
  (`#issuecomment-5149769680`). Issue open, label `enhancement`, not merged.
- **`ai.StreamChunk` is a sealed interface** — unexported `streamChunkMarker()`, exactly three
  implementers repo-wide at `130ad1da2` and at `dev` `386cf6d15`. Relevant only to the upstream reply.
- **WI-C13c landed as `89a1d67`.** `dispatch_step`'s `LiveAI`/`Scripted` branches were unreachable
  and are deleted. Notes referring to `dispatch_step`'s `LiveAI` branch as the live provider seam are
  describing a state that no longer exists.
- **The pin is v0.26.0 in two places** — `ailang.toml` floor and `scripts/install-prerequisites.sh:39`
  — with a Makefile guard that fails if they drift. There is no partial repin.
- **`scripts/dst/spike_scripted_cursor_probe.ail` exits 1 by design** and is deliberately not wired
  into any Makefile target. It is the executable statement of F6.
- **PR #103 must not be merged** — a test-merge conflicts in six files and reverts `89a1d67`.
- **A stale `.ailang` compile cache produces phantom type errors**, and this reproduced across a
  compiler *version* change during the spike. If you hit a type error contradicting the source you
  are reading, clear every `.ailang/cache` before believing it.

**One superseded claim, so you do not report it as live:** the second review's action list says
"complete routing of all four current clock reads". The count is neither 4 nor the 14 an earlier
revision claimed — it is **13** at HEAD, corrected in D4 after all three verifications converged on
the error. The review text is intentionally left as written — it is a historical record. Do not file
this as a contradiction.

## Output contract

**This round is closed.** It was executed three times (`claude-sonnet-5`, Codex `GPT-5`, Kimi
`kimi-k3`, all 2026-08-01); all three returned *Revise* and converged on the same defect set, and
those defects were corrected on 2026-08-01 after the third verification landed. The ADR now carries
five `## Review Comments` headings — two from 2026-07-26 and three from this round. **Do not execute
this handoff a fourth time**; its instruction to "append a third section" is spent, and following it
literally would falsify the record.

What the corrections need is a **delta review** scoped to the corrected text alone — the Status
block, the three re-grounded Context rows, D1's cursor-ownership and port-widening paragraphs, D4's
clock table, and D5's structural-first routing rule — not a fourth full round. F1, F2, F3, F5, F6,
the narrowed blocking clause, the upstream return-shape ruling, and M2 were each independently
confirmed three times, and D6.1's zero-`RunSummary` claim by two of the three (Codex and Kimi rule on
it; Claude's section cites only its call-site count), so none of those is reopened. That delta review
needs its own handoff.

**Executed 2026-08-01** by Claude Code `opus-5` and Codex `GPT-5`, per
`HANDOFF-delta-review-adr-001-f1-f6-corrections.md`. Both returned *Revise*. This handoff is fully
spent; see the ADR's Status block for the live acceptance state.

The contract below is retained as the historical record of what the three executed rounds were asked
for. Under it: do not rewrite the body, and do not edit any existing review section — they are
historical records.

State your model id and the date at the top, and the revision you reviewed at.

Number findings `R1..Rn`, most severe first. Each finding:

- The defect in one sentence.
- Grounding: the exact command you ran and its output, or a `file:line`.
- A concrete **Action:**.

Then, in this order:

1. **What is accurate** — name the claims you re-ran and confirmed. Three deserve an explicit ruling:
   whether each F1–F6 disposition actually resolves its finding, whether the narrowed blocking clause
   is correct, and whether the uncorrected Context anchors hold.
2. **Recommended pre-acceptance actions** — ordered by dependency, separating what this ADR must fix
   from what belongs to the implementation plan.
3. **Accept / revise recommendation** — one line. If you recommend acceptance, say explicitly what
   happens to the upstream API blocker, which is not yours to clear.

## Constraints

- **Findings only.** Do not modify source, scripts, the Makefile, the spike, other ADRs, or this
  ADR's body during review.
- **Do not re-litigate accepted 007**, and do not re-argue the decision to request an upstream API.
  Both are settled; a conflict with 007 is a finding against *this* ADR.
- **Do not re-derive whether the spike's observations happened.** The commands and output are in
  `spike/README.md`. What is open is whether the ADR's *response* to each is correct — attack the
  disposition, not the observation.
- **Do not treat the fork prototype as the gate cleared.** `arniwesth/ailang` carries a working
  `stepWithStreamRecorded` on the `v0.31.0` tag. D1 requires the API to have *landed* in a release
  and the toolchain to be *repinned*. A fork is not that, and upstream has merged nothing.
- **Verify by execution.** A claim you did not re-run is a claim you cannot certify.
- If nothing major survives, say so plainly and still record residual risk. The likeliest candidates:
  a disposition that is technically responsive but leaves the same trap reachable, and the
  reachability-aware audit requirement (A3) turning out to be unbuildable as stated.
