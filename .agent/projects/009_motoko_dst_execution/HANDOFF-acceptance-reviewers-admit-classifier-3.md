# Handoff: to both ADR-001 acceptance reviewers — admit classifier 3, and rule on classifier 1

**Audience: both ADR-001 acceptance reviewers, jointly.** This is a **governance act**, not an
execution item and not a review of new work. Producing source here is a symptom. **The whole of it is
four cells and two sentences in one table, and one ruling that is harder than it looks.**

**Why it is yours and nobody else's, in the ADR's own words** (`:1493-1496`, landed at WI-D10):

> Its admission to *Gate mechanisms: built, and deferred* as a fourth deferred mechanism **is not made
> by this amendment**: that list was signed off as finite by both ADR-001 acceptance reviewers, and
> the count is theirs to change.

**Read first:** `REVIEW-adr-001-criterion-2-amendment.md`, then `NOTE-d10-land-the-amendment.md`, then
the amended `ADR:1470-1580` — the amendment is landed and this is the one edit it deliberately did
not make.

## The three edits

1. **Add classifier 3's row** to *Gate mechanisms: built, and deferred*, with an acceptance criterion
   in the same form as the other three. The amendment specifies four required properties
   (`ADR:1470-1490`); the row needs them as a criterion, not as a description.
2. **`ADR:20`** — *"**Three** deferred gate mechanisms"* → four.
3. **`ADR:2420`** — *"None of the **three** deferred mechanisms blocks acceptance"* → four. **Both
   sentences move or neither does**; they are the same claim in two places and this project has
   recorded five separate cases of a fact stated correctly in one place and wrongly in another.

## The test is yours to apply, not to inherit

The amendment records that the architecture test — *"if this mechanism turned out unbuildable, would
D1–D11 still be the right architecture?"* — was applied to classifier 3 at review and **answered
yes**, on the ground that its absence degrades conservatively to exactly HEAD, costing coverage rather
than correctness.

**Apply it again.** You applied it to the original three and the finite list is the thing you signed.
**A test inherited is a test not run**, which is this project's most frequently earned lesson: five
of the last ten items found a claim that was locally correct, carried forward, and wrong by the time
it was cited.

**One input the review supplies and you should weigh:** classifier 3's honest yield is **4 of 15
extensions** (`decision_framework`, `compaction_structural`, `empty_stop_guard`,
`progress_contract_guard`) — the only ones whose transitive closure imports no effect-bearing stdlib
module. Because the unit is the closure and the discipline is fail-closed, it can never clear a hook
of an extension whose closure is dirty. **That is what the mechanism is worth, and it belongs in the
criterion rather than in a note.**

## The ruling that is harder than the count

**WI-D10 edited a cell inside your table and flagged it rather than burying it.** Classifier 1's row
now reads:

> **Built; its acceptance criterion is NOT met at HEAD** (see the qualification below this table)

with *"Met at `a0d4edb`"* re-tensed to *"Was met"*, and an 18-line qualification added. **No row was
added, removed or reordered.** That edit needs your ratification or revision, and it raises a
question the table's shape cannot express:

**Is a mechanism whose acceptance criterion is unmet still "Built"?**

The facts, verified independently at review of WI-D10:

- `make effect_inventory_selftest` **exits 2**, reporting `agree=0 disagree=0` and *"a pass-shaped
  absence, not a pass."*
- All 46 `ailang iface` calls fail `MOD010`; every classification comes from an **unvalidated**
  textual fallback.
- Classifier 1's recorded criterion has **two clauses** — zero unresolved modules **and** the selftest
  reporting zero disagreements. **The second is failing.**
- **Neither `effect_inventory` nor `effect_inventory_selftest` is in `make dst`**, so this was
  invisible for thirty-three items, across a toolchain repin the Makefile itself says to re-run after.

**Three readings are available and they give different counts.** *Built* (state is historical, the
criterion was met once); *Deferred* (the criterion is the state, so it is unmet and the count is
**five**, not four); or a state this table has no vocabulary for. **The count you are being asked to
change from three depends on which you take**, which is why this is one handoff and not two.

## What is deliberately not asked of you

- **Repairing classifier 1.** Owed, unowned, and not a governance act. The `ailang iface` `MOD010`
  defect is already filed.
- **Putting `effect_inventory` into `make dst`.** Owed. It is the reason the degradation was
  invisible, and it is a Makefile change.
- **Building classifier 3.** Your admission is its precondition; building it is the next execution
  item.
- **Re-deriving the ADR's internal citation layer.** WI-D10 measured that **roughly one in seven**
  ADR self-citations pointed at a blank line or a code fence *before* its edit — independently
  confirmed at 14.0% — and refused to offset them, because a correct offset on an already-wrong number
  makes it look freshly maintained. **Do not offset the citations you touch either.** Named anchors
  were adopted for the two amended passages and are the recommended direction.
- **Anything in D5's criteria.** The amendment is landed and reviewed; this is its status table only.

## Definition of done

**The count moved in both places, or not at all**, with the ruling on classifier 1 recorded either
way — including the case where the ruling changes the count to five.

**Classifier 3's row carries a criterion, not a description**, in the same form as the other three,
and it states the 4-of-15 yield.

**D10's classifier-1 cell edit ratified or revised**, explicitly. It was flagged for you; leaving it
unremarked ratifies it silently, which is the failure mode this table has already had once.

**The architecture test applied by both of you and recorded**, not cited from the review.

**Nothing else in the ADR touched.** No source files. `make dst`'s barrier count is three and is not
this act's to move — if it moves, something was edited that should not have been.

## Report back

- **The disposition on classifier 3's admission**, and the count after it.
- **The ruling on classifier 1**, with which of the three readings you took and why.
- **Whether D10's cell edit stands as written.**
- **The architecture test, in your words.**
- **Whether the deferred-mechanism count now agrees in both `:20` and `:2420`**, checked rather than
  assumed — that is the specific shape this project has been bitten by five times.
