# Handoff: WI-D10 — land Amendments B and A, and stop before the table

Audience: a fresh session grounded against HEAD. **Mostly a documentation item with one measurement
that matters.** Producing source changes beyond that measurement is a symptom.

**The review is done.** `REVIEW-adr-001-criterion-2-amendment.md`, by a reviewer independent of
D6–D9: **both amendments Accept with conditions** — B with 2, A with 4, **neither Revise** — and all
four re-derivations confirm WI-D9. The review's sign-off is what makes this item possible.

**Read first:** the review in full, then `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md`,
then the plan's `## Standing rules` — **S13 and S22 both grew at the review, and S15 governs this
item's central trap.**

## Mission

**Apply Amendment B, then Amendment A with conditions A-1 through A-4. Stop before the gate-mechanism
table and the Status block.**

The review sets three edits with three owners and this item is the first two:

| Edit | Pen | This item? |
|---|---|---|
| **B** — replace `ADR:1398-1418`, plus B-2's closed-row paragraph | ADR author, on the review + one reviewer independent of D6/D7/D8 — **which the review is** | **YES** |
| **A** — insert after `ADR:1396`, with A-1…A-4 | same, **plus WI-C5's owner** signs A-2's corrected cost claim | **YES**, subject to that signature |
| **The table + Status block** | **both ADR-001 acceptance reviewers, jointly** | **NO** |

**The third is not yours.** `ADR:20-22` says *"Three deferred gate mechanisms"* and `:2113` says
*"None of the three"*; both become four. **They signed a finite list of three and the count is theirs
to change.** Condition A-1 blocks that edit for a second reason — see below.

## The finding nobody has named: this insertion has a citation cascade

**This project has never edited the ADR's body mid-flight.** Every prior amendment appended a review
section. Amendment A inserts at `:1396` and Amendment B replaces a 21-line block above it, so **every
ADR line citation below those points moves.**

Measured at review of the review:

```
ADR line-number citations across project docs      551
  ... citing a line BELOW :1396                     91
  ... in source (src, packages, scripts, tools)      0
```

and the 91 split in the way that decides the work:

| Class | Count | Treatment |
|---|---|---|
| **The ADR's own self-citations** | **76** | **must be re-derived** — the document would otherwise cite itself wrongly |
| The plan | **1** | live; update it |
| **NOTE-\*, REVIEW-\*, HANDOFF-\*, DRAFT-\*** | **14** | **must NOT be rewritten** — see below |

**77 live citations to re-derive, 14 to leave alone deliberately.** Zero in source, so `make anchors`
and the attribution cascade are not involved — this is a documentation cascade only, and cheaper than
the four source-anchor cascades this project has paid.

## The rule you will break by accident

**Rewriting the 14 historical citations is S15's exact defect, and it is the one this project has
carried in five consecutive items.**

A note saying *"`ADR:1412`'s stated consequence is false of the ABI"* was **true when written**. After
the insertion, `:1412` holds different text. **Re-dating that citation in place makes the note claim
something it never claimed** — S15's *"a bare number silently re-dated inside a historical record
becomes a false claim about history"*, which is why D5 restated the 2026-07-24 naming claim rather
than deleting it, and why D7 left D6's report as written.

**The 14 stay.** Their documents carry dates and HEADs in their headers; that is what makes them
readable. **If you judge that insufficient, the fix is a note at the amendment's own site saying which
line ranges moved and when — not an edit to fourteen historical records.**

**And there is a structural option worth considering rather than assuming:** give the amended
paragraphs **named anchors** so future citations survive edits. That would stop this recurring, and
it is a decision to record rather than a change to slip in.

## A-1's substance is a MEASUREMENT, not an annotation

The review's condition A-1 asks the amendment to *"state the fallback route (per-declaration textual
parse)"* for classifier 3's symbol granularity. **Nobody has tested that route, and the amendment is
about to assert classifier 3 is buildable partly on it.**

The facts, verified at review of the review:

- `make effect_inventory_selftest` **exits 2**, `agree=0 disagree=0`, *"a pass-shaped absence, not a
  pass"*. All 46 `ailang iface` calls fail `MOD010`.
- `ADR:2108` still records classifier 1 as **"Built and independently verified … `agree=43
  disagree=0`"**, and its criterion has two clauses. **The second is failing.**
- Neither `effect_inventory` nor `effect_inventory_selftest` is in `make dst`, so this has been
  invisible for thirty-three items — across a toolchain repin the Makefile itself says to re-run
  after.

**So probe the fallback before the ADR asserts it.** The review's argument is that `textual_scan`
already locates each declaration and its row and merely collapses them to a bool, so returning a
per-symbol map is a small change. **That is a claim about a tool, and this project's record on
untested claims about tools is the reason S22 exists.** A short probe settles it, and the answer
belongs in A-1's text either way.

**Annotate classifier 1's row regardless.** A-1's blocking condition on the table edit is that the row
must not keep reading "Built and independently verified" without a note that its selftest is red.
**That annotation is yours; repairing classifier 1 is not.**

## Definition of done

**Amendment B applied**, including B-2's closed-row paragraph — *a named binding cannot declare
narrower than its slot, because the ABI record's rows are closed*, which the review measured and which
is load-bearing for the same passage.

**Amendment A applied with all four conditions**, and **A-2 signed by WI-C5's owner** or explicitly
deferred with the clause left out rather than silently softened. A-2 is the clause that says "Route B
plus classifier 3 buys all three barriers", which the review measured as **false** for the two
extensions it names.

**The 77 live citations re-derived and the 14 historical ones untouched**, with the decision recorded
either way — including whether named anchors are adopted.

**A-1's fallback probed**, with the result in the amendment's text.

**Classifier 1's row annotated**, and the underlying degradation left as owed work with its measurement.

**Nothing else in the ADR touched.** The table, the Status block, `:20-22` and `:2113` are the
acceptance reviewers'. **If this item moves the count from three to four, it has taken an edit that is
not its own.**

**Per S13/S9/S17/S19** — this item barely touches source, but run `make dst` and a cache-cold sweep
with `AILANG_RELAX_MODULES=1` anyway: the review found a red gate outside `make dst` precisely because
nobody was running things they assumed were fine. Clear every live `.ailang/cache`, leave
`~/.ailang/cache/registry` alone, check no other session is running a gate, and **run
`make sync_packages` first** — `.packages/` staleness has now cost **five** consecutive items.

## Out of scope

- **The gate-mechanism table and the Status block.** Both acceptance reviewers', jointly.
- **Building classifier 3.** Its authorisation is what the amendment grants; building it is next.
- **Repairing classifier 1**, the `ailang iface` MOD010 filing, and putting `effect_inventory` into
  `make dst` — all owed, none this item's, and the first two are the same underlying defect.
- **`compaction_structural` as the first installable extension** — the review's A-4, the cheapest path
  to non-zero coverage, and it comes after classifier 3.
- **Route B and WI-C5.** Unchanged, and the review confirmed Route B alone clears zero barriers.
- The `motoko-ext-abi` major at eight changed rows; `corpus_pr`'s box-measuring ceiling; the two
  sibling `st.world_state` finalize sites; D4's provider latency pair; the adversarial partial stream;
  the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds; `test_coverage` and
  `test_coverage_selftest`.

## Stop and report rather than deciding inline

- **If applying A requires changing criterion 1's wording**, stop. The draft and the review both
  withhold criterion 1 deliberately, and the ADR already records its basis as an assumption.
- **If WI-C5's owner cannot sign A-2**, land A without that clause rather than with a softened version.
  A cost claim nobody owns is the shape of the sentence D6 shipped and D7 spent an item correcting.
- **If the citation re-derivation turns up a citation that was already wrong before this item**, report
  it separately. That is a pre-existing defect and folding it into the cascade would hide it.

## Report back

Thirty-fourth calibration run, and the first item to edit the ADR's body.

- **The git wall-clock window.**
- **Both amendments' applied text**, and A-2's disposition — signed, or left out.
- **The citation cascade**: how many live citations moved, the 14 historical left untouched, and
  whether named anchors were adopted.
- **A-1's fallback probe result.** This is the item's one measurement and it is what a future
  classifier 3 rests on.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **66 across
  thirty-three runs; determinism has caught none.** This item writes almost no code; if it counts one
  it will be a citation or a claim, which is where the last four came from.
- **Whether the barrier count is still three, and whether the deferred-mechanism count is still
  three.** The first should be unchanged; **the second is not yours to move.**
