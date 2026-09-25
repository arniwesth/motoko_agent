# WI-D10 execution report — Amendments B and A landed, and the citation layer was already gone

**Grounded against HEAD `24d13fd`.** Git wall-clock window **17:22Z → 18:07Z, 2026-08-06 (45
minutes)**. Thirty-fourth calibration run, and the first item to edit the ADR's body.

**Tree at exit: two `.agent/` markdown files modified, zero source files.** `ailang.lock`'s
`generated_at` moved on `make sync_packages` and was reverted, for the **sixth** consecutive item.

---

## What was applied

**Amendment B**, rewriting the record-field passage in place, and **Amendment A**, inserted after the
paragraph that states the interim declared-row rule. Both carry their conditions. **The
gate-mechanism table gained no row, and neither `:20-22`'s "Three deferred gate mechanisms" nor the
"None of the three" sentence was touched** — those are both acceptance reviewers' jointly.

### Two scope decisions, both DECIDED rather than discovered, and both reported rather than slipped in

1. **B's replacement range was extended from the draft's `:1398-1418` to `:1398-1429`.** The draft's
   own consequence list addresses three passages, and two of them lie below `:1418`: the
   classifier-2 rejection bullet at `:1419-1425`, whose premise B says "needs one qualifier", and the
   upstream-filing sentence at `:1427-1428`, which said the record-field gap "belongs in an AILANG
   issue" when the plan already records it as **filed** (`fb_74f53de3ae65854c`, WI-A3) with "do not
   file it again". Stopping at `:1418` would have left the ADR contradicting its own correction two
   paragraphs later.
2. **Classifier 1's table row was annotated**, per the handoff's explicit instruction that "that
   annotation is yours". **This is a cell edit inside a table owned jointly by both acceptance
   reviewers**, so it is flagged rather than buried: the row's State cell now reads "Built; its
   acceptance criterion is NOT met at HEAD", the criterion cell's "Met at `a0d4edb`" is re-tensed to
   "Was met", and an 18-line qualification sits below the table. **No row was added, removed or
   reordered, and the count of deferred mechanisms is untouched at three.**

### A-2's disposition: the clause was SPLIT, and nothing was signed

A-2 contains two different kinds of sentence and only one needed an owner.

- The **measurement** — `compose` (17 modules) imports `std/ai`, `std/clock`, `std/env`, `std/fs`,
  `std/io`, `std/process`; `context_mode` (7 modules) imports `std/env`, `std/fs`, `std/process`,
  `std/sem`; Route B routes *calls* while a closure classifier fails closed on *imports*, so both
  report DIRTY — **is stated in full.** It needs no signature; it is what makes the draft's claim
  false, and deleting it would have made WI-C5's owner rediscover it.
- The **cost estimate** — "materially more work than routing the calls" — **is left out entirely**
  and recorded as owed to WI-C5's owner.

So the amendment says Route B is necessary, says the sufficiency claim is **withdrawn as measured
false**, and does not replace it with a softened version. **Nothing was signed, and no cost claim in
the ADR now lacks an owner.**

---

## A-1's fallback probe — the item's one measurement

The review's argument was that `textual_scan` "already locates each declaration and its row and
merely collapses them to a bool, so returning a dict is a small change." **That is a claim about a
tool, so it was probed rather than quoted.** Three falsifiers, and then the alternatives were
enumerated rather than assumed away.

**The proposed route works:**

```
modules parsed                            46
exported symbols resolved                465
FALSIFIER 1  collapse-to-bool vs the shipped textual_scan   agree=46 disagree=0
FALSIFIER 2  unclaimed `export` residue                     0
FALSIFIER 3  A-1's own example    std/ai.Message -> type,  std/ai.call -> ! {AI}
symbol granularity changes the answer for >=1 symbol in     10 of 46 modules
```

**And it fails OPEN on 44 of 465 symbols, which for a fail-closed instrument is the wrong
direction:**

```
232  declared `export pure func`                          -- safe, the compiler's own claim
 39  `export func` with NO row at all                     -- 33 std/json, 4 std/net, 2 std/yaml
  5  row is an effect VARIABLE (std/list.mapE & siblings) -- `! {e}`, instantiable at {IO}
```

An unannotated row reads as *infer*, not as *performs nothing* — WI-D8's own finding. **`std/json.jo`
is one of the 39, and three of the four extensions A-3's yield rests on import it.** The amendment
therefore states the requirement rather than leaving it to the builder: **those 44 must be reported
UNRESOLVED, not clean.**

**Two strictly better producers existed and nobody had looked.** Both are recorded in the amendment:

- **The compiler's own cached interface data** — `.ailang/cache/compile/modules/*/iface.json`, schema
  `ailang.iface/v1`, 589 files, **23 of 46 stdlib modules: exactly those this tree compiles against.**
  Per-symbol, typed, separates `types` and `constructors` from `exports`, and distinguishes an effect
  *variable* from concrete labels — `std/list` shows 38 exports with **zero** effect labels, which is
  the honest answer the textual rule cannot give. It resolves A-1's example directly:
  `std/ai.Message` is in `types`; `std/ai.call` is in `exports` with `["AI"]`.
- **`ailang iface`'s own stdout**, which already emits `funcs[].effects` per symbol
  (`std/env.getEnv -> ["Env"]`). **It is blocked only by MOD010's path rule, not by a missing
  capability.** `derive.py`'s `doc.get("funcs")` reads the right key — checked, because a schema
  drift there would have been a second silent fail-open, and there is none.

**So classifier 3's symbol-granular property is buildable and the amendment does not rest on the
broken route.** Classifier 1's degradation is confirmed and left owed: `make effect_inventory_selftest`
**exits 2**, `agree=0 disagree=0`, "a pass-shaped absence, not a pass".

---

## The citation cascade — and why the re-derivation was NOT performed

**This is the item's largest finding and it inverts the handoff's instruction.** The handoff directed
that 77 live citations be re-derived and 14 historical ones left alone. **Both numbers were wrong, and
more importantly the premise behind the first was false.**

### The census was wrong in both directions at once

The ADR uses **two** citation forms. The review counted `ADR:NNN` only. There is also a backticked
bare `` `:NNN` ``, with **197 instances** — so the census was too small. **But most of that form is
not an ADR citation at all:** it is a *file-relative continuation* of the file named earlier in the
same sentence (`session.ail:1770` … then `` `:1778` ``), so counting them in bulk would have been too
large. Each was classified individually.

Corrected census, whole tracked tree:

| | n |
|---|---|
| ADR line citations (form A + self-referential form B) | **927** |
| form-B references reclassified as file-relative, **not** ADR citations | **197** |
| below the edit and **live** (ADR self-citations + the plan) | **108** |
| below the edit and **historical** (`NOTE-`/`REVIEW-`/`HANDOFF-`/`DRAFT-`/summaries) | **25** |
| in **source** (`src`, `packages`, `scripts`, `tools`) | **0** |

Zero in source, so `make anchors` and the attribution cascade are not involved, exactly as the
handoff predicted.

### The layer was already gone, measured before the edit

**105 of the ADR's 753 internal line-number self-citations (13.9%) pointed at a BLANK LINE or a
CODE-FENCE MARKER in the pre-edit file** — and **72 of those are in the region this edit does not
touch at all.** A hand-sample of fourteen more found roughly two that still matched their claim:
`ADR:1519` cited as an acceptance row points at `INVOKE_FIELDS` regex parsing; `ADR:1807` cited as
"Implementation Handoff item 2" points at a sentence about reachable terminal returns; `ADR:1644` and
`ADR:4907` point at blank lines.

**So the re-derivation was deliberately not performed.** Adding a correct offset to a number that is
already wrong by an unknown amount does not make it right — it makes it *look* freshly maintained,
which is plan rule S15's exact defect in the one medium where nothing can go red. **The decay is
reported, priced and left owed rather than disguised as a cascade.** The handoff anticipated this
case: *"if the citation re-derivation turns up a citation that was already wrong before this item,
report it separately."* It turned up 105.

**The 25 historical citations were left untouched**, as instructed and for the reason S15 gives.

### What was done instead

- **A line-number note at the amendment's own site**, giving the map derived **from the diff**:
  `was :1..1397` unchanged; `was :1398..1429` rewritten in place; `was :1430..2113` **+287**;
  `was :2114..10514` **+305**. Verified: classifier 1's row was `:2110`, is `:2397`.
- **Named anchors ADOPTED for the two amended passages** — `#adr-criterion-2-evidentiary-basis` and
  `#adr-record-field-mechanism`. **The ~300 lines of new amendment text introduce zero numeric ADR
  self-citations**, so the fix is demonstrated in place rather than only recommended. Converting the
  rest of the document is a separate item and is **not** started.
- **The plan's one live citation was corrected with a tense**, per S15: classifier 1's row "was
  `ADR:2110` when the review wrote this, is `ADR:2397` after WI-D10's amendment."

### A pre-existing defect in the handoff itself

The handoff states that `:2113` says *"None of the three"*. **It does not** — `:2113` was the
coverage-floor row; the sentence was at `:2115`. Reported, not corrected in place.

---

## Gates

**`make sync_packages` first**, then every live `.ailang/cache` cleared (10 directories),
`~/.ailang/cache/registry` left alone and verified intact.

- **Cache-cold sweep, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail** over 243 files. **The failing set
  matches the expected seventeen member-for-member** — 7 `TC_ARITY_001` smoke scripts, 1
  sealed-vocabulary probe, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable
  across B4, C1, C3, C5 and now D10; the count moved from 225 to 226 because a file was added.
- **`make dst`: EXIT 2.** The two red targets are **`test_coverage` and `test_coverage_selftest`**,
  both on this item's out-of-scope list and both **pre-existing** — this item changed **zero** source
  files, so it cannot have caused them. Everything else green, including
  `declared_vs_performed 37 passed / 0 failed` and `hook_guard 4 passed / 0 failed`.
- **`corpus_pr` deliberately not run**, per the amendment review's precedent: its ceiling gate
  measures the box as much as the tree.
- **Operational note:** a `make run` / `ailang run src/core/supervisor.ail` session has been running
  in this tree since **2026-08-04 22:49 (1d 19h)**. It is not a gate, so it did not block the run, but
  it is almost certainly abandoned and any timing-sensitive result should be read against it.

---

## Report-back answers

- **Git wall-clock window:** 17:22Z → 18:07Z, **45 minutes**.
- **Both amendments applied**, B first, with B-1's argued ground and B-2's closed-row paragraph, and
  A with all four conditions.
- **A-2's disposition:** **split, and nothing signed.** Measurement stated in full; cost estimate left
  out and recorded as owed to WI-C5's owner.
- **Citation cascade:** 108 live, 25 historical left untouched, 0 in source, 197 form-B references
  reclassified as file-relative. **The 108 were NOT re-derived**, because 105 of 753 self-citations
  were already pointing at blank lines before the edit. **Named anchors adopted** for the two amended
  passages only.
- **A-1's fallback probe:** the proposed route works (465 symbols, residue 0, 46/46 collapse
  agreement) and **fails open on 44 of 465**; two strictly better producers exist and are recorded.
- **Recorded bindings, decided vs discovered.** *Decided:* B's range extended to `:1398-1429`;
  classifier 1's row annotated; A-2 split rather than signed or dropped; named anchors adopted for
  the amended passages only; the numeric re-derivation refused. *Discovered:* the 13.9% pre-existing
  citation decay; the second citation form and its file-relative referent; the 44 fail-open symbols;
  the two better per-symbol producers; the handoff's own stale `:2113`.
- **Did any site admit two type-checking answers with a silent wrong one?** **No new one — the count
  stays at 66 across thirty-four runs, and determinism has still caught none.** This item wrote no
  AILANG. Its near-miss was in the predicted class: the line-number note **stated `+260`, was written
  above the region it describes, and thereby made its own number wrong** (`+287`/`+305`). Well-formed,
  plausible, and invisible to every gate — caught only by deriving the map from the diff afterwards.
  **That is S18 one level up and it is recorded as a rule.**
- **Barrier count: still 3**, derived twice by `make profile_definition` — `on_pre_step`,
  `on_response_intercept`, `on_solver_candidate`; `on_budget_plan` coverable, `on_tool_handle` gated.
- **Deferred-mechanism count: still 3.** Not moved, and not this item's to move.

---

## Owed, and unowned

1. **Re-derive the ADR's internal citation layer** — 105 provably wrong before this item, an unknown
   number more merely wrong. Larger than an amendment; needs its own item and probably a convention
   change to anchors.
2. **Repair classifier 1** — the `ailang iface` MOD010 filing, and the selftest that certifies
   nothing. Its row is now annotated; the repair is not done.
3. **Put `effect_inventory` and `effect_inventory_selftest` into `make dst`.** A gate outside the
   aggregate target degrades invisibly however loudly it fails.
4. **The gate-mechanism table's fourth row and the Status block** — both acceptance reviewers',
   jointly. The architecture test on classifier 3 was applied at review and answered yes.
5. **WI-C5's owner** to revise the Route B cost estimate against A-2's measurement.
6. **The fourteen `register_with_config` rows**, which B-1 raises from deferred to the sharpest
   un-owned item in the project.
