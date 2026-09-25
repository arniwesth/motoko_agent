# 2026-08-06 Cluster 35: WI-D10 — land Amendments B and A, and stop before the table

## Context

Branch: `arniwesth/mot-72-review-the-adr-001-d5-amendment`.

Session span: `24d13fd` → **uncommitted**. **No source file changed.** Two documents modified, one
added. Input was `HANDOFF-execute-d10-land-the-amendment.md` (`5fdd9da`), grounded against HEAD
`24d13fd`. Pin **v0.33.0**. Git wall-clock window **17:22Z → 18:07Z (45 minutes)**.

**The first item in project 009 to edit ADR-001's BODY rather than append a review section to it.**
Every prior amendment appended; this one inserts at a paragraph boundary and rewrites a block above
it, which is why the item is mostly documentation with one measurement — and why its largest finding
is about the document's own citation layer rather than about the amendment.

Input documents: `REVIEW-adr-001-criterion-2-amendment.md` (both amendments **Accept with
conditions**, B with 2 and A with 4, neither Revise) and
`DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md` (drafted WI-D9, never applied). Output:
the amended ADR, plan rule extensions, and `NOTE-d10-land-the-amendment.md`.

**Grounding.** `make sync_packages` run first. Pre-edit **file copy** of the ADR taken before any
edit, per S17 (`md5sum 0ce6ab96…`). Every live `.ailang/cache` cleared (10 directories);
`~/.ailang/cache/registry` left alone and verified intact. Tree at exit: two `.agent/` markdown files
modified plus one new; `ailang.lock`'s `generated_at` moved on sync and was reverted, for the
**sixth** consecutive item.

| Definition-of-done item | State |
|---|---|
| Amendment B applied, incl. B-2's closed-row paragraph | **met** — and B-1's ground argued rather than asserted |
| Amendment A applied with A-1 … A-4 | **met** — all four |
| A-2 signed by WI-C5's owner, or left out rather than softened | **met** — **split**; measurement stated, cost estimate left out, nothing signed |
| 77 live citations re-derived, 14 historical untouched, decision recorded | **REFUSED, with a measurement** — see below. 25 historical untouched; the live set was **not** re-derived |
| Named anchors: adopted or not, recorded either way | **met** — **adopted** for the two amended passages only |
| A-1's fallback probed, result in the amendment's text | **met** — and two better producers found |
| Classifier 1's row annotated, degradation left owed | **met** — flagged as a table-cell edit |
| Nothing else in the ADR touched | **met** — table count, Status block, `:20-22`, "None of the three" all untouched |
| `make dst` + cache-cold sweep | **met** — sweep 226/17 clean; `dst` exit 2 on two pre-existing out-of-scope targets |

---

## The item's central inversion: the re-derivation was refused

The handoff directed that **77 live citations be re-derived and 14 historical ones left alone**. Both
numbers were wrong, and the premise behind the first was false.

**The census was wrong in both directions at once.** The ADR uses **two** citation forms; the review
counted only `ADR:NNN`. The second is a backticked bare `` `:NNN` `` with **197 instances** — so the
census was too small. **But most of that form is not an ADR citation at all:** it is a *file-relative
continuation* of the file named earlier in the same sentence (`session.ail:1770` … then `` `:1778` ``).
Counting them in bulk would have been too large. Each was classified individually.

**Then the layer turned out to be already gone.** Measured against the pre-edit copy:

```
ADR internal line-number self-citations                        753
  ... pointing at a BLANK LINE or a CODE-FENCE MARKER          105   (13.9%)
  ... of those, in the region this edit does not touch          72
hand-sample of 14 more: roughly 2 still matched their claim
```

`ADR:1519` cited as an acceptance row points at `INVOKE_FIELDS` regex parsing; `ADR:1807` cited as
"Implementation Handoff item 2" points at reachable terminal returns; `ADR:1644` and `ADR:4907` point
at blank lines. **The layer had decayed document-wide from ordinary growth and no item in thirty-four
had ever re-derived it.**

**So adding `+287` to 108 already-wrong numbers would have produced wrong numbers that look freshly
maintained** — S15's exact defect in the one medium where nothing can go red. The handoff itself
anticipated the case (*"if the citation re-derivation turns up a citation that was already wrong
before this item, report it separately"*); it turned up 105.

Corrected census, whole tracked tree: **927** ADR citations, **197** reclassified as file-relative,
**108** live below the edit, **25** historical below the edit, **0** in source — so no anchor cascade
and no attribution cascade.

**What was done instead:** a diff-derived line-number note at the amendment's own site
(`was :1..1397` unchanged; `was :1398..1429` rewritten in place; `was :1430..2113` **+287**;
`was :2114..10514` **+305**, verified against classifier 1's row moving `:2110` → `:2397`); **named
anchors adopted** for the two amended passages, with the ~300 lines of new text containing **zero**
numeric self-citations; and the plan's one live citation restated with a tense per S15.

---

## A-1's probe — the item's one measurement

The review argued classifier 3's symbol granularity was reachable because `textual_scan` "already
locates each declaration and its row and merely collapses them to a bool". **That is a claim about a
tool, so it was probed with three falsifiers rather than quoted.**

**The proposed route works:** 46 modules, **465** exported symbols, unclaimed-`export` residue **0**,
collapse-to-bool agrees with the shipped derivation **46/46**, and it resolves A-1's own example
(`std/ai.Message` → type, `std/ai.call` → `! {AI}`). Symbol granularity changes the answer for at
least one symbol in **10 of 46** modules.

**And it fails OPEN on 44 of 465** — 39 `export func` carrying no row at all (33 `std/json`, 4
`std/net`, 2 `std/yaml`) and 5 effect-**polymorphic** (`std/list.mapE` and siblings, `! {e}`). An
unannotated row reads as *infer*, not *performs nothing* — WI-D8's own finding. **`std/json.jo` is one
of the 39, and three of the four extensions A-3's yield rests on import it.** The amendment therefore
states the requirement rather than leaving it to the builder: those 44 must be **unresolved**, not
clean.

**Two strictly better producers existed and nobody had looked:**

- the compiler's **cached** `iface.json` (`ailang.iface/v1`, 589 files, **23 of 46** stdlib modules —
  exactly those this tree compiles), per-symbol and typed, separating `types`/`constructors` from
  `exports` and distinguishing an effect *variable* from concrete labels;
- **`ailang iface`'s own stdout**, which already emits `funcs[].effects` per symbol and is blocked
  only by MOD010's path rule, not by a missing capability. `derive.py` reads the right key — checked,
  because a schema drift there would have been a second silent fail-open, and there is none.

Classifier 1's degradation confirmed and left owed: `make effect_inventory_selftest` **exits 2**,
`agree=0 disagree=0`, "a pass-shaped absence, not a pass".

---

## Scope decisions, decided rather than discovered

1. **B's replacement range extended from the draft's `:1398-1418` to `:1398-1429`.** B's own
   consequence list addresses two passages below `:1418` — the classifier-2 rejection bullet whose
   premise "needs one qualifier", and the sentence saying the record-field gap "belongs in an AILANG
   issue" when the plan already records it **filed** (`fb_74f53de3ae65854c`, WI-A3) with "do not file
   it again". Stopping at `:1418` would have left the ADR contradicting its own correction.
2. **Classifier 1's table row annotated** — a **cell edit inside a table owned jointly by both
   acceptance reviewers**, done on the handoff's explicit instruction and flagged rather than buried.
   No row added, removed or reordered; the deferred count is untouched at three.
3. **A-2 split rather than signed or dropped.** The clause holds two kinds of sentence: a
   **measurement** (`compose` 17 modules imports `std/ai clock env fs io process`; `context_mode` 7
   imports `std/env fs process sem`; Route B routes *calls* while a closure classifier fails closed on
   *imports*, so both report DIRTY) and a **cost estimate** ("materially more work"). The measurement
   needs no owner and is stated in full; the estimate is left out and recorded as owed to WI-C5's
   owner. **Nothing was signed and no cost claim in the ADR now lacks an owner.** Dropping the clause
   entirely would have deleted the measurement and made WI-C5's owner rediscover it — this project's
   most-repeated failure.

---

## Gates

- **Cache-cold sweep, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail** over 243 files. Failing set
  matches the expected seventeen **member-for-member** (7 `TC_ARITY_001` smoke scripts, 1
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture). Stable
  across B4, C1, C3, C5, D10; count moved 225 → 226 because a file was added.
- **`make dst`: EXIT 2**, on **`test_coverage`** and **`test_coverage_selftest`** — both on this
  item's out-of-scope list and both **pre-existing**, since the item changed zero source files. Read
  from the artifact rather than the transcript tail, per D4. Everything else green, including
  `declared_vs_performed 37/0` and `hook_guard 4/0`.
- **Barrier count 3**, derived twice. **Deferred-mechanism count 3**, not moved and not this item's
  to move.
- `corpus_pr` deliberately not run, per the review's precedent.

---

## Rules earned, written into the plan

Extending **S15**:

- **A citation layer decays silently and the whole layer can already be gone.** Measure before
  re-deriving. **Adding a correct offset to an already-wrong number launders a guess into a fact.**
- **The detector is cheap and nobody had run it: a citation whose target is a blank line or a code
  fence is definitely wrong**, needs no semantics, covers a document in seconds. Run it on handoffs
  too — this item's handoff cited `:2113` for "None of the three"; the sentence was at `:2115`.
- **A census that does not know every citation FORM errs in both directions at once**, and naming the
  form is not enough — the form's **referent** has to be derived too.
- **A note stating a shift, placed above the region it describes, invalidates its own numbers.** S18
  one level up, and it bites twice because the correction is also an edit. **Derive the map from the
  DIFF, then patch only the digits.**
- **When a review proposes a fallback route, probe it AND enumerate the alternatives** — the proposed
  route is the first one someone thought of, not the best one available.

---

## Calibration

- **Thirty-fourth calibration run.** No new site admitting two type-checking answers with a silent
  wrong one — **still 66 across thirty-four runs, and determinism has caught none.** This item wrote
  no AILANG.
- **Its near-miss was in the class the handoff predicted** (*"if it counts one it will be a citation
  or a claim"*): the line-number note stated **`+260`**, sat above the region it described, and
  thereby falsified its own number — the true shifts are `+287`/`+305`. Well-formed, plausible, and
  invisible to every gate; caught only by re-deriving the map from the diff afterwards.

## Owed, and unowned

1. **Re-derive the ADR's internal citation layer** — 105 provably wrong before this item, an unknown
   number more merely wrong. Larger than an amendment; probably wants the anchor convention.
2. **Repair classifier 1** — the `ailang iface` MOD010 filing and a selftest that certifies nothing.
   Row annotated; repair not done.
3. **Put `effect_inventory` / `effect_inventory_selftest` into `make dst`.**
4. **The gate-mechanism table's fourth row and the Status block** — both acceptance reviewers',
   jointly. The architecture test on classifier 3 was applied at review and answered yes.
5. **WI-C5's owner** to revise the Route B cost estimate against A-2's measurement.
6. **The fourteen `register_with_config` rows**, raised by B-1 from deferred to the sharpest un-owned
   item in the project.

## Operational

- A `make run` / `ailang run src/core/supervisor.ail` session has been running in this tree since
  **2026-08-04 22:49 (1d 19h)**. Not a gate, so it did not block the run; almost certainly abandoned.
- **`.packages/` staleness and the `ailang.lock` timestamp recurred for the SIXTH consecutive item.**
  Nothing enforces either.
