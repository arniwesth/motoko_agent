# WI-D9 — does D5 criterion 2 read mediation from evidence, or only from a row? **YES ON THE READING. NO ON THE EVIDENCE. THE COUNT IS STILL THREE.**

Thirty-third calibration run. Written against HEAD `995a6d6`, branch
`arniwesth/mot-71-wi-d9-does-d5-criterion-2-read-mediation-from-evidence`.

## Window

**~39 minutes** wall-clock: `2026-08-06T13:18:29Z` → `2026-08-06T13:57Z`.

Almost all of it is one `make dst`, one cache-cold whole-tree sweep, and one re-run of `corpus_pr` to
attribute a red. **The argument itself cost about fifteen minutes of compiler time**, spent on
**thirteen probe modules and one reverted source mutation** — of which **two overturned the premise
this item was handed**, one overturned a paragraph of the ADR, and one overturned a correction I had
already drafted against WI-D8.

## Grounding

**Clean at `995a6d6`.** `git status` empty at start.

**S9's concurrency check: no other session is running a gate.** The same idle `src/core/supervisor.ail`
agent session D5–D8 each found (now 2d elapsed, 8m16s CPU) plus days-old `make claude` shells. No gate,
no `make dst`. **Caches cleared before the run**, `~/.ailang/cache/registry` left alone and verified at
1 entry. **Per S17 a full `tar` of `packages src scripts Makefile tools` was taken before anything
else** and the one mutation this item performed was restored by extraction. **Per S19, `$?` was never
read after a pipe** and every long run was captured to a file and read as an artifact.

**`.packages/` staleness recurred for the FOURTH consecutive item.** `make sync_packages` was needed
again before any gate would read source-consistent state; it moved `ailang.lock`. D6, D7 and D8 each
recorded it. **Four items is no longer a nuisance, it is a missing gate.**

## THE ANSWER

**Criterion 2 admits evidence other than a declared row. Nothing in this tree can produce that
evidence, and the successor detector the ADR names cannot produce it in principle. So the declared-row
rule is retained, `on_pre_step` remains a barrier, and the count is three.**

The two halves are independent and both are needed, because the item's value is in which one fails.

### Half 1 — the reading. **YES, and the ADR says so itself.**

Criterion 2 (`ADR:1290-1291`) reads *"effectful only through D1 world-mediated ports, with origin
tagged by extension id and explicit world state returned to the host."* It names no declared row. The
declared-row rule is a **separate** sentence at `ADR:1392`:

> **Per-hook classification reads *declared* effect rows in the interim, not performed ones.** The
> reconciling detector that would let a profile claim a hook performs less than it declares is
> explicitly unavailable (obligation 2's successor detector) …

**"In the interim" is the ADR conceding that the reading is a convention with a stated expiry.**
Eleven items evaluated criterion 2 against rows and every one was right to; what none of them did was
test whether the convention is what refuses `on_pre_step`. It is not.

### Half 2 — the evidence. **NO, and the reason is a category error, not a gap.**

**The successor detector the ADR defers is a declared-versus-performed reconciler. It reconciles
LABELS. Criterion 2 is a claim about the CALL PATH.** No reconciliation of label sets, at any
precision, produces the sentence criterion 2 needs.

**Measured, against the shipped ABI, in the subjects' own types, two-sided:**

```
mediated(ctx, w, m, msgs) -> AiStepOutcome ! {AI, IO, Trace}
    body: ctx.ports.ai_step(w, m, msgs)              -- every effect through the D1 port
ambient (ctx, w, m, msgs) -> AiStepOutcome ! {AI, IO, Trace}
    body: println(m); event(…); ai.call(m)           -- every effect ambient, no port touched

  ailang check  ->  ✓ No errors found!     BOTH ARMS, IDENTICAL ROW, IDENTICAL VERDICT

CONTROL, each arm declared one effect short:
  mediated ! {AI, IO}  ->  REJECTED  "Missing effects: Trace"
  ambient  ! {AI, IO}  ->  REJECTED  "Missing effects: Trace"
```

**The control is what makes the probe mean something.** It shows the effect checker is running on both
bodies and is sharply sensitive to labels — so the acceptance above is not the checker being absent,
the file being unreachable, or the probe being malformed. **The checker sees labels and is blind to
provenance by construction. A declared row cannot say "these arrive through a port", and neither can a
measured performed row, because both are label sets.**

That is the whole refusal. It is not about `on_pre_step`'s width, which WI-D8 already measured down to
what `ai_step` performs; it is that the instrument answers a different question.

## THE BINDING-FORM SPLIT, RE-DERIVED. **IT IS 14 INLINE / 1 NAMED, NOT 8 / 7.**

Per S22, derived from `src/core/ext/registry_generated.ail`'s fifteen registrable extensions rather
than taken from the handoff, **with the falsifier the rule now requires: exactly one `on_pre_step:`
site per package, residue empty, all fifteen package directories resolved.**

| Binding form | Count | Effect-checked? |
|---|---|---|
| inline function expression in record-field position | **14 / 15** | **NO — the row is inert in both directions** |
| named top-level function (`compaction_structural.pre_step`) | **1 / 15** | yes, at the function itself |

```
test_dummy omnigraph context_mode mcp exa_search ailang_docs compose a2a
decision_framework microrag compaction_ai scratchpad empty_stop_guard
progress_contract_guard                                      -> INLINE  (14)
compaction_structural  (register.ail:34 -> pre_step, register.ail:23)  -> NAMED   (1)
```

**WI-D8 reported 8 lambda-bound / 7 named-func for this slot and I could not reconstruct that under
any reading of the fifteen.** Six of the fourteen inline bindings put `on_pre_step:` alone on its line
and the function expression on the next; eight put it on one line. A classifier keying on the line
rather than on the binding form would split those 8/6+1 — which is D8's number. **The derivation is
the claim; the report's number is what it disagrees with.** This is not a small correction: D6, D7 and
D8 each banked the prize *"a binding that starts reading `Env` in this slot now fails to build"*, and
the prize is real at **one** of fifteen `on_pre_step` bindings, not at seven.

**And the inert row is worse than "unchecked against its body".** Measured on the shipped `ExtPorts`
record, both directions:

```
inline, row ! {AI, IO, Trace}, body reads Env  -> Env escapes to the enclosing builder   (catches nothing)
inline, row ! {AI, IO, Trace}, body calls println -> IO ALSO escapes, though DECLARED    (discharges nothing)
control: the identical body as a named top-level func -> REJECTED at the function itself
```

## THE ADR PARAGRAPH THIS ITEM WAS SENT TO STAND ON DOES NOT REPRODUCE ON THE ABI

**The handoff's "Read first" list points at `ADR:1396-1422`, and grounding it found the repro at
`:1404-1410` is a property of a LOCALLY DECLARED record type.** Through an imported one the call *is*
transitive.

```
local   type Ports = { ai_step: … ! {AI, IO, Trace} },  rowless caller  ->  ACCEPTED
import  pkg/sunholo/motoko_ext_abi/types (ExtPorts),    rowless caller  ->  REJECTED
                                        Effect checking failed for function 'rowless_calls_ai_step'
                                        Missing effects: AI, IO, Trace
```

Bisected to one variable: an imported `ExtPorts` nested inside a locally declared record still
propagates; a local copy of `ExtPorts`' `ai_step` field, with the identical imported result type, does
not. **So the ADR's stated consequence — "`ExtCtx.ports: ExtPorts` is exactly that shape, and a field
call is the only way an extension reaches a port at all" — is false of the ABI.**

**Every conclusion the ADR draws from it survives, and the mechanism that carries them is the inert
inline row instead.** Detail in `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md`,
Amendment B. In particular `:1415`'s *"a rowless ABI slot is not provably effect-free"* stands: an
**inline** binding in a rowless slot can call `ctx.ports.ai_step` and the demand escapes to
`register_with_config`. A **named** one cannot — it is rejected.

**And WI-D8's chain measurement STANDS, and is stronger than it looked.** `summarize_attempt`'s
`! {AI, IO, Trace}` is a genuine body verdict, because its only effectful call is
`ctx.ports.ai_step` on the imported ABI and that call propagates. **I had a correction to WI-D8
drafted and the imported-versus-local distinction refuted it.** See the silently-wrong list below.

## WHAT WOULD HAVE TO EXIST, NAMED AND SPECIFIED

The producer criterion 2 needs is a **provenance** instrument, not a reconciler — and it is **not
blocked by the record-field limitation**, because it is structural rather than type-based. Half of it
is specified in obligation 2 clause 2 and built in its module-classification half only:

| Property criterion 2 needs | Nearest thing built | Gap |
|---|---|---|
| provenance of each effect-producing call | classifier 2 (`ext_call_inventory`) — typed `ExtPorts` field calls, fail-closed on aliases/wrappers | **positive** inventory of port calls; scans for no ambient call at all |
| every ambient effect source ruled out | classifier 1 (`effect-inventory`) — std module partition, fail-closed on unresolved | emits **module sets, repo-wide**; no per-module site enumeration, though obligation 2 clause 2 specifies one |
| per **extension**, over its transitive closure | — | classifier 1 is repo-wide; the one recorded mediation argument (`dst_driver_only.ail:597`) is scoped to **one file** |
| **symbol** granularity | — | classifier 1 is module-granular, so `import std/ai (Message)` reads as effect-bearing |

Derived at WI-D9, per extension, effect-bearing std imports at **package** granularity:

```
NONE:  decision_framework  compaction_structural  empty_stop_guard  progress_contract_guard   (4/15)
some:  the other eleven, including compaction_ai (std/ai std/env std/fs std/io — all four in
       register.ail and compaction_ai.ail's own imports are proven effect-free plus two
       effect-free src/core modules)
```

**The instrument is one work item and it is ORDERED BEFORE ROUTE B, not after.** Call it classifier
3; the draft amendment names it and gives it the status row the other three carry.

## WHY THIS HAD TO COME BEFORE ROUTE B, WHICH IS WHAT THE HANDOFF ASKED

**Confirmed, and the handoff's revision of its own advice was right.** Route B routes `compose`'s
`FS`/`Process` and `context_mode`'s `Process` through world-mediated `ExtPorts` seams; the resulting
declared rows read `{Process, FS}` and are refused by `check_barrier_count` for exactly the reason
`on_pre_step` is refused now — *"a non-empty row fails criterion 1 outright. It could still pass
criterion 2, but only if every effect in it is a world-mediated port — and none of the effects in any
of these rows is"* (`tools/profile_definition/check_fixtures.py:226-230`). **That sentence is a
category error stated plainly in the gate: an effect label is never a port. Under it criterion 2 is
unsatisfiable by construction for any non-empty row, whatever the behaviour underneath.**

So: **Route B alone clears zero barriers. Route B plus classifier 3 clears all three.** That ordering
is this item's most useful output and it is worth more than the answer itself.

## THE FAIL-CLOSURE TEST, WHICH IS WHY A NARROWER "YES" WAS REJECTED

A narrower amendment was available and is refused: *classify a hook `WorldMediated` when its chain is
bound as named functions and its module closure is ambient-free.* `compaction_ai` looks like it
qualifies — `compaction_ai.ail` imports only proven-effect-free std plus two effect-free `src/core`
modules, and `dst_driver_only.ail:597` already argues exactly this in prose.

**It fails on fail-closure, and the failure is a one-line edit that nothing catches.** The hook is
bound **inline** at `packages/motoko-ext-compaction-ai/register.ail:109`, in a module that imports
`getEnvOr` and `readFileResult`, under a `register_with_config` declaring the full ten-effect row.
**Mutation-measured and reverted** — one line added inside that lambda:

```
    on_pre_step: func(ctx: ExtCtx, msgs) -> PreStepOutcome ! {AI, IO, Trace} {
+     let _ = getEnvOr("MOTOKO_D9_MUTANT", "");
      compact_with_ai(ctx, msgs, compaction_cfg)
    },

  ailang check                  ->  ✓ No errors found!
  make profile_definition       ->  EXIT 0, "barrier count DERIVED … : 3"
  make declared_vs_performed    ->  EXIT 0, 44 ✓ rows — byte-identical to the unmutated run
```

**An ambient environment read inside the most scrutinised hook in the tree, and NOTHING goes red.**
Restored by extraction from the S17 tar and verified by checksum.

**A classification rule must not be true-today-and-silently-false-tomorrow.** That is the shape of
every failure this project has counted, and it is what the handoff warned the amendment would license
by accident.

## Gate state

- **`make dst` — EXIT 2, 880 ✓ rows, and the red set is THREE targets, not D8's two.** `make
  --keep-going` emitted exactly three target `Error` lines (`Makefile:2022`, `2019`, **`1086`**) plus
  the top-level `Error 2`.
  - `test_coverage` and `test_coverage_selftest` — **pre-existing since B2a**, untouched here.
  - **`corpus_pr` — NOT a regression, and attributed rather than assumed.** It failed on its
    wall-clock ceiling alone: *"the PR corpus target took 273000 ms against a declared ceiling of
    80000 ms"*. **Re-run alone on a quiet box: EXIT 0 in 25000 ms** — *"measured CI cost, WHOLE
    TARGET: 25000 ms against a declared ceiling of 80000 ms"*. Every substantive row above the
    failure is ✓ in both runs: the wire witness, both provider error classes reaching different
    branches, all 20 `CorpusRejection` constructors, the unreachable register EMPTY, and the same thin
    margin D5 flagged — **13 affordable at 381 ms/seed against a minimum of 12**, identical to D6, D7
    and D8. **The 880 against D8's 881 is exactly this row and nothing else.**
  - **The instrument observation, because it is worth more than the red:** this gate's producer
    includes the machine's other tenants. It moved **11×** between a loaded box and a quiet one while
    the tree did not change at all. A ceiling gate that swings by an order of magnitude on contention
    cannot distinguish a slow tree from a busy one, and this project has called that margin "thin" for
    four items running.
- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Failing set
  **identical member for member** to D7's and D8's: 7 `TC_ARITY_001` smoke scripts,
  `probe_phase_vocab_sealed`, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture.
  Stable since B4.
- **`make profile_definition`: green, barrier count 3**, printed twice per `make dst` as at D7 and D8.
  **`driver_only`: PASS at v12. `declared_vs_performed`: 37 passed, 0 failed. `hook_guard`: 4 passed,
  0 failed.** All identical to D8.
- **`git diff ailang.toml` is empty — C5's duplicate-dependency trap was checked and did not fire.**
  `ailang.lock` moved as part of `make sync_packages`.
- **No source file was changed by this item.** The one mutation was reverted by extraction from the
  S17 tar and verified by checksum against the pre-mutation hash; the thirteen probe modules were
  written outside every scan root and deleted.

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a derivation forced it:**

1. **THE EFFECT CHECKER IS BLIND TO PROVENANCE BY CONSTRUCTION.** A fully port-mediated body and a
   fully ambient one, at the identical declared row, get the identical verdict — with a two-sided
   control proving the checker is running and label-sensitive. **This is the item's answer and it was
   measured, not argued.**
2. **THE BINDING-FORM SPLIT IS 14 INLINE / 1 NAMED, NOT 8 / 7.** D6's, D7's and D8's recorded prize is
   real at one binding of fifteen.
3. **THE ADR'S RECORD-FIELD REPRO DOES NOT REPRODUCE ON THE ABI.** Non-transitivity is a property of
   locally declared record types; imported ones propagate. Every conclusion survives on a different
   mechanism.
4. **AN INLINE RECORD-FIELD ROW IS INERT IN BOTH DIRECTIONS** — it neither catches an undeclared
   effect nor discharges a declared one. D8 measured the first half; the second is new.
5. **WI-D8's CHAIN MEASUREMENT IS SOUND**, and I had a correction against it drafted before finding
   why.
6. **CLASSIFIER 1 EMITS MODULE SETS, REPO-WIDE.** Obligation 2 clause 2 specifies a *site*-granular
   per-module inventory; that half is not built, and it is the half criterion 2 needs.
7. **CLASSIFIER 2 DOES NOT LEAN ON THE DECLARED-ROW READING.** Its predicate is derived from typed
   field *calls*. It is the natural host for classifier 3 — same matcher, same fail-closed discipline.
8. **THE BARRIER COUNT IS DERIVED PER SLOT, AND CRITERION 2 IS PER EXTENSION.** `check_barrier_count`
   reads the ABI row, which fifteen extensions share. A measured basis makes a barrier a property of
   the `(extension, slot)` pair, which is a change to the derivation.
9. **THE RECORDED MEDIATION ARGUMENT IS FILE-SCOPED.** `dst_driver_only.ail:597` argues over
   `compaction_ai.ail`; the hook is bound in `register.ail`, which imports `std/env` and `std/fs`.

**Decided — a human chose:**

1. **The answer is YES on the reading and NO on the evidence**, recorded as two separable halves so
   the next item can see which one moved.
2. **The declared-row rule is RETAINED**, and the amendment says so as its fail-closed default rather
   than leaving retention implicit.
3. **A narrower "named bindings plus an ambient-free closure" amendment is REFUSED**, on fail-closure,
   with the mutation that establishes it.
4. **Two amendments are drafted, not one**, because the mechanism correction is separable and should
   land first.
5. **NOTHING IS APPLIED.** D5 is Accepted; the draft names its reviewers and stops.
6. **The record-field filing is not re-filed**, per scope. That the ADR applies it more widely than it
   holds is recorded as owed, not filed.
7. **Classifier 3 is named and specified but not built**, and it is ordered before Route B.
8. **The barrier count was not touched.** Nothing was installed.

## Sites where two answers held up and one was silently wrong: **4**

**Base 62 from WI-D8. This run makes it 66. Determinism has still caught none.** The handoff predicted
that in an item this light on code they would be in arguments rather than expressions. **All four
are.**

1. **THE ADR PARAGRAPH THE HANDOFF SENT ME TO STAND ON.** `:1398-1418` concludes correctly from a
   repro that does not reproduce on the ABI. Both readings are consistent with the repro as written;
   the wrong one has been the stated mechanism for three decisions since B4 and nobody cited it in
   between. **Caught by running the repro against the real `ExtPorts` instead of the ADR's local
   `type Ports`.**
2. **MY OWN GENERALISATION FROM IT, AND IT WAS ALREADY DRAFTED.** From four local-type probes I
   concluded "a record-field call propagates nothing", and therefore that WI-D8's chain fixpoint was
   an unchecked annotation and its central measurement unfounded. Every local-type probe supports it.
   **It is false, and the correction would have retracted a sound measurement.** Caught by the one
   probe that used the imported ABI.
3. **THE BINDING-FORM SPLIT.** 8/7 and 14/1 are both "derived"; the one that keys on the line rather
   than on the binding form is silent and understates the exposure sevenfold.
4. **A FILE-SCOPED CLAIM READING AS EXTENSION-SCOPED.** `dst_driver_only.ail:597` is true of
   `compaction_ai.ail` and is cited as the reason the *extension* reaches effects only through
   `ai_step`. Criterion 2 quantifies over the extension. The hook is bound in the other file.

**Not counted, and said so rather than inflating the number:** the `.d9probe` module name that AILANG
rejects because a module path may not start with `.`; `std/trace` exporting `event` rather than
`emit`; `ExtClockReading.now_ms` written as `value`; and running the first provenance probe from the
scratchpad, where **AILANG auto-relaxes MOD010 and says so in a warning** — the trap both classifier
tools' docstrings warn about, which is why every decisive probe was re-run under the repo. **All four
were LOUD.** The counter tracks answers that are *silently* wrong.

**Also not counted, and it is the closest call: `corpus_pr`'s red.** Attributing a wall-clock ceiling
breach to the tree rather than to the box would have been wrong, and the artifact alone does not
distinguish them — but the failure was a RED, not a silent pass, and the re-run that settled it took
25 seconds. A loud failure with the wrong cause attached is a reporting error, not a silent one.

## Corrections owed to the plan

1. **S16 NEEDS ITS FOURTH EXTENSION AND IT IS ABOUT THE SUBJECT'S TYPE, NOT ITS SYNTAX.** C5's version
   was about a check's two sides sharing a producer; D6's about a producer's reach over a subject set;
   D8's about the subject's syntactic *form*. This one: **an instrument must exercise the subject
   through the same TYPE DECLARATION the subject uses.** A probe over a locally declared copy of an
   imported record measures a different language. Three ADR conclusions and one of my own drafts rest
   on a probe that did exactly that.
2. **A "MINIMAL REPRO" IS A CLAIM ABOUT WHAT WAS MINIMISED AWAY.** The ADR's four-line repro
   minimised away the import, which is the variable. *Suggested extension to S1: a repro recorded as
   evidence for a claim about production code must be re-run against the production type before it is
   cited a second time.* It was cited at B4 and not run again for eleven items.
3. **S22's FALSIFIER REQUIREMENT PAID OFF ON ITS FIRST USE.** D8 asked for one — "a derived set needs
   its own falsifier, the check that the residue is empty". This item's binding-form derivation
   carried one (exactly one site per package, all fifteen directories resolved) and it is the reason
   the 14/1 split is quotable against a report that says 8/7.
4. **`.packages/` STALENESS RECURS FOR THE FOURTH ITEM.** `make sync_packages` needed again, and it
   moved `ailang.lock`. D6, D7 and D8 all recorded it. **It is a two-command fix that has now cost
   four consecutive items.**
5. **A CEILING GATE WHOSE PRODUCER INCLUDES THE MACHINE.** `corpus_pr` moved **11×** — 273000 ms to
   25000 ms against an 80000 ms ceiling — between a loaded box and a quiet one, with the tree
   unchanged. *Suggested: a wall-clock gate must either normalise against a same-run calibration
   measurement or state that it measures the box; as written it reports a tree regression when the
   box is busy, and four items have now called its margin "thin" without anyone establishing which
   of the two it is measuring.* This item nearly reported it as a new red.

## Out of scope, unchanged and still owed

- **Classifier 3, the ambient-source inventory** — NEW, specified in the draft amendment, and now the
  precondition for Route B being worth paying for.
- **Route B** — untouched, as the handoff required. **Necessary and, alone, insufficient.**
- **WI-C5, the `compose`-bearing profile** — still the last unbuilt item, still needs three barriers
  cleared, and its precondition is now named.
- **The fourteen `register_with_config` rows** — still the sharpest un-owned item, and this item
  raises its stakes: with 14 of 15 bindings inline rather than 8, those rows are where essentially all
  of the enforcement lives.
- **A correction to the upstream filing `fb_74f53de3ae65854c`** — the filing is valid; the ADR applies
  it more widely than it holds, and the gap that actually reaches this tree (the inert inline row) is
  not in it. **Recorded as owed. Not filed — WI-D9's scope excludes filing.**
- **The `motoko-ext-abi` major and lockstep re-release — EIGHT changed rows, unchanged by this item.**
  Stated, not cut; cutting it is a release act.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.

## DID COVERAGE MOVE? **NO.**

`driver_only` installs nothing and covers nothing. **The axis's extension-model coverage is ZERO.**
Eleven of eleven acceptance rows still hold, four still lean on the empty install list, and the table
was not re-run because nothing here changes a row's answer.

**S21, re-asked: the count is still four, and nothing concentrated or withdrew.**

**And what this item costs, stated plainly because the handoff asked for it in the NO case and half
the answer is NO.** Until classifier 3 exists: Route B is necessary-but-insufficient and buys zero
barriers on its own; WI-C5 cannot complete; and the axis's extension-model coverage stays
**structurally** zero — not for want of hermetic extensions, but because the ABI's effect vocabulary
cannot express mediation and the only instrument that could is unbuilt. **What is new is that this is
now a missing instrument with a name, a specification and an owner-shaped gap, rather than a property
of the criterion.** That is the difference between a cost and a wall.
