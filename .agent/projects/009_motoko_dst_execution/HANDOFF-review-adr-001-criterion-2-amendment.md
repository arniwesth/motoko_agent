# Handoff: review the ADR-001 D5 amendment — criterion 2's evidentiary basis

**This is a REVIEW, not an execution.** It is the first review round in this project since the scoped
architecture-acceptance review that accepted ADR-001 on 2026-08-02, and it is a different genre from
the thirty-three execution items between. **Producing source changes here is a symptom that something
went wrong.** The output is a disposition and its reasoning.

**Subject:** `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md`, written at WI-D9 against
`995a6d6`. Two amendments, separable. **B should be reviewed and land first, because A cites it.**

**Read first:** the draft in full, then `NOTE-d9-criterion-2-mediation-from-evidence.md` for the
measurements behind it, then **`ADR-001:1284-1296`** (criteria 1 and 2 verbatim) and **`:1392-1422`**
(the declared-row rule and the record-field paragraph B corrects).

## Why this needs a reviewer rather than another execution item

**D5 is Accepted.** Per this project's founding mandate, a correction to an accepted decision goes
through a normal amendment with named reviewers rather than an inline edit. WI-D9 drafted and
deliberately did not apply.

**And the author is not independent.** The WI-D7, WI-D8 and WI-D9 handoffs were all written by the
same reviewer who is writing this one, and one of them **carried a wrong figure into the item that
corrected it** — D8's binding-form split of 8 inline / 7 named, restated in the D9 handoff, which D9
then re-derived as **14 / 1**. That figure is load-bearing for Amendment A's second clause. **It must
be re-derived, not read.**

## What each amendment claims, in one line each

**Amendment B — a factual correction.** `ADR:1404-1410`'s record-field repro is a property of a
**locally declared** record type; through the imported `ExtPorts` the same rowless caller is
**rejected**. So the ADR's stated mechanism — *"`ExtCtx.ports: ExtPorts` is exactly that shape"* — is
false of the ABI. **Every conclusion the ADR draws survives**, carried instead by the inert *inline*
row. B changes no decision anywhere.

**Amendment A — a recorded test of a convention.** Criterion 2's text admits evidence other than a
declared row, and the ADR's own declared-row rule says it applies *"in the interim"*. A tests whether
the interim can end. **It finds it cannot yet**, retains the declared-row rule as the fail-closed
default, and specifies the missing producer as **classifier 3**.

## The four things a reviewer must re-derive rather than accept

1. **The binding-form split.** Amendment A clause 2 rests on *fourteen of fifteen extensions bind
   `on_pre_step` inline*. Derive it from `src/core/ext/registry_generated.ail` with S22's falsifier —
   one binding site per package, residue empty, all fifteen package directories resolved. **Two prior
   derivations disagree** (8/7 at D8, 14/1 at D9); a third that keys on the *binding form* rather than
   the *line* is the tiebreak. Note that six of the fourteen put `on_pre_step:` alone on its line.
2. **The provenance-blindness measurement**, which is A's whole argument. A port-mediated body and an
   ambient body at the identical declared row must get the identical verdict, **with the two-sided
   control** — each arm declared one effect short must be rejected. Without the control the result is
   consistent with the checker not running. **Re-run it against the imported ABI, not a local type
   copy** — that is exactly the error B corrects, and per S16's fourth extension an instrument must
   exercise the subject through the same type declaration the subject uses.
3. **B's local-versus-imported distinction.** One probe each way. It is four lines and it decides
   whether three ADR conclusions rest on a stated mechanism or on a different one.
4. **The fail-closure mutation.** A's safety rests on refusing a narrower amendment, and the refusal
   rests on one `getEnvOr` added inside `compaction_ai`'s `on_pre_step` lambda leaving `ailang check`,
   `make profile_definition` and `make declared_vs_performed` all green. **If that mutation is caught
   by anything, the narrower amendment becomes available and A is over-cautious.**

## The test Amendment A must survive, and it is not about the amendment

**Amendment A adds classifier 3 to the ADR's *Gate mechanisms: built, and deferred* table — a
FOURTH deferred mechanism to a list both acceptance reviewers signed off as finite.** Both applied
this test to the existing three:

> *If this mechanism turned out unbuildable, would D1–D11 still be the right architecture?*

**Apply it to classifier 3 before the row is added, not after.** The draft argues classifier 3 is
buildable — structural, an import-and-call-name closure, not blocked by the record-field limitation,
and most of obligation 2 clause 2 which the ADR already specifies. **That argument is the thing to
attack.** If classifier 3 is not buildable, criterion 2 has no evidentiary path at all and the
consequence is larger than an amendment: the extension model is uncoverable by construction, not
merely uncovered, and that is a D5-level finding rather than a D5 amendment.

## The reading to guard against

**Amendment A changes nothing today, and a reviewer who reads it as "criterion 2 now admits
evidence" has read it wrong.** Its operative sentence is the fail-closed default: *until classifier 3
exists and reports clean for an extension, criterion 2 is evaluated on declared rows and no profile
may record `WorldMediated` on any other basis.* **The barrier count stays at three, no extension
becomes installable, and coverage stays at zero.** If the amendment as drafted could be read to
license a `WorldMediated` classification at HEAD, that is a defect to report.

**The symmetric guard for B:** it corrects a mechanism, not a conclusion. But it does reduce a measured
claim — D6, D7 and D8 each recorded *"a binding that starts reading `Env` in this slot now fails to
build"*, and B says that is real at **1 of 15** bindings rather than 7. **A reviewer should decide
whether those three items' narrowings were still worth taking on the corrected number**, and say so;
the draft asserts they were and does not argue it.

## Disposition

Return **Accept**, **Accept with conditions**, or **Revise**, per this project's precedent, with the
conditions or defects enumerated and each tied to the clause it lands on. **Separate dispositions for
A and B** — they are independent, and B is much the safer of the two.

**Do not apply the amendment.** If the disposition is Accept, say what applying it consists of and
who holds the pen; the ADR's Status block and its gate-mechanism table both move, and neither is this
reviewer's to edit unilaterally.

**If the disposition is Revise on A**, say explicitly whether the revision is to the *argument* or to
the *fail-closed default*. Those have very different consequences for WI-C5's ordering.

## Out of scope

- **Building classifier 3.** Its authorization is what this review decides.
- **Route B, WI-C5, and the barrier count.** Untouched; if the review moves any of them, something was
  applied that should not have been.
- **Criterion 1.** The ADR already records its declared-row basis as an assumption. B supplies the
  correct mechanism for that assumption without widening it, and widening is an ADR-scope decision the
  draft deliberately withholds.
- **Re-filing `fb_74f53de3ae65854c`.** The record-field gap was filed at WI-A3. **What is owed is a
  correction to that filing** — the ADR applies it more widely than it holds, and the gap that
  actually reaches this tree (the inert inline row) is not in it. Owed, not this review's.

## Three operational debts worth folding into whatever runs next

Each has been deferred on individually correct grounds and each now has a measured cost:

- **`.packages/` staleness has cost four consecutive items** a `make sync_packages` step nothing
  enforces; at D9 it moved `ailang.lock`. Two commands, no gate.
- **`corpus_pr`'s wall-clock ceiling measures the machine.** It swung **11×** — 273 s to 25 s against
  an 80 s ceiling — between a loaded and a quiet box with the tree unchanged. Four items have called
  the margin "thin" without establishing which of the two it measures, and D9 nearly reported it as a
  new red.
- **The `motoko-ext-abi` major stands at eight changed rows**, declined by D6, D7 and D8 on the
  correct ground that a lockstep re-release is a release act. It is the largest deferred thing here.

## Report back

- **A disposition for each amendment**, with reasoning.
- **The four re-derivations**, with your numbers rather than the draft's — particularly the
  binding-form split, where two prior derivations disagree and the author of this handoff is
  implicated in the wrong one.
- **The architecture test applied to classifier 3**, stated as the acceptance reviewers stated it.
- **Whether Amendment A, as drafted, could license a `WorldMediated` classification at HEAD.** It
  should not be able to. If it can, that is the finding.
- **Whether anything in the review moved the barrier count.** It should still be three.
