# 2026-08-06 Cluster 33: WI-D9 — does D5 criterion 2 read mediation from evidence, or only from a row?

## Context

Branch: `arniwesth/mot-71-wi-d9-does-d5-criterion-2-read-mediation-from-evidence`.

Session span: `995a6d6` → **uncommitted**. **No source file changed.** Two new documents plus an
`ailang.lock` moved by `make sync_packages`. Input was
`HANDOFF-execute-d9-does-criterion-2-read-mediation.md` (`995a6d6`), executed against HEAD `995a6d6`.
Thirty-third code session of project 009. Pin **v0.33.0**.

**A decision item, not a build.** The handoff revised its own post-D8 advice — it had said Route B was
next, and re-grounded to say Route B alone cannot clear a barrier. This item settled whether the wall
Route B would hit can be moved.

**Window: ~39 min**, `13:18:29Z` → `13:57Z`. One `make dst`, one cache-cold whole-tree sweep, and one
`corpus_pr` re-run to attribute a red. **The argument itself cost about fifteen minutes of compiler
time**, spent on **thirteen probe modules and one reverted source mutation**.

**Grounding was clean.** `git status` empty at start. **S9's concurrency check: no gate running** — the
same idle `src/core/supervisor.ail` agent session D5–D8 each found, now 2d elapsed against 8m16s CPU,
plus days-old `make claude` shells. Caches cleared, `~/.ailang/cache/registry` verified at 1 entry.
Per S17 a `tar` of `packages src scripts Makefile tools` was taken before anything else, and the one
mutation was restored by extraction and verified by checksum.

| Definition-of-done item | State |
|---|---|
| The question answered, with the argument recorded either way | **met** — **YES on the reading, NO on the evidence** |
| If YES: an ADR amendment DRAFTED, not applied, with reviewers named | **met** — two amendments drafted, reviewers named by role |
| If NO: say what that costs, in one paragraph | **met** — the NO half is costed explicitly |
| The binding-form split, RE-DERIVED (S22) | **met** — **14 inline / 1 named**, not D8's 8/7 |
| Do not touch the barrier count | **met** — derived **3**, printed twice, unmoved |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1` | **met** — 226/17 of 243, identical member for member |
| `make dst` in full | **met** — exit 2, and the third red is **attributed**, not new |
| S9/S17/S19 discipline | **met** — mutation restored by `tar`, artifacts read not transcripts |
| Route B itself (out of scope) | **respected** — untouched |
| Applying an amendment (out of scope) | **respected** — drafted only |
| Re-filing the record-field gap (out of scope) | **respected** — not filed; a *correction* to the existing filing recorded as owed |
| `motoko-ext-abi` major: state the count, do not cut it | **met** — **eight** changed rows, unchanged by this item |
| Stop if the answer requires changing criterion 1 | **not triggered** — criterion 1 untouched |
| Stop if the amendment needs the `register_with_config` measurement first | **not triggered** — it raises its stakes, does not block the draft |
| Report if D5's classifier-2 rule leans on the same reading | **checked — IT DOES NOT.** Its predicate is derived from typed field *calls* |

## THE ANSWER

**Criterion 2 admits evidence other than a declared row. Nothing in this tree can produce that
evidence. So the declared-row rule is retained, `on_pre_step` remains a barrier, and the count is
three.**

The item's value is in *which half* fails, and the two are independent.

### Half 1 — the reading. **YES, and the ADR concedes it.**

Criterion 2 (`ADR:1290-1291`) names no declared row. The declared-row rule is a **separate** sentence
at `ADR:1392` — *"Per-hook classification reads declared effect rows **in the interim**, not performed
ones"* — pending obligation 2's successor detector. **"In the interim" is the ADR stating its own
expiry.** Eleven items evaluated criterion 2 against rows and each was right to; none tested whether
the convention is what refuses `on_pre_step`. It is not.

### Half 2 — the evidence. **NO, and it is a category error rather than a gap.**

**The deferred successor detector is a declared-versus-performed reconciler: it reconciles effect
LABELS. Criterion 2 is a claim about the CALL PATH.** Measured against the shipped ABI, two-sided:

```
mediated(ctx,…) -> AiStepOutcome ! {AI, IO, Trace}   body: ctx.ports.ai_step(…)         ACCEPTED
ambient (ctx,…) -> AiStepOutcome ! {AI, IO, Trace}   body: println + event + ai.call    ACCEPTED

CONTROL, each arm declared one effect short:  BOTH REJECTED, "Missing effects: Trace"
```

The control proves the checker is running on both bodies and is sharply label-sensitive. **It assigns
the identical verdict to a fully port-mediated body and a fully ambient one. A declared row cannot say
"these arrive through a port", and neither can a reconciled performed row — both are label sets.**

## THE BINDING-FORM SPLIT, RE-DERIVED: **14 INLINE / 1 NAMED**

Per S22, derived from `registry_generated.ail`'s fifteen registrable extensions with the falsifier the
rule now requires — exactly one `on_pre_step:` site per package, all fifteen directories resolved,
residue empty.

| Binding form | Count | Effect-checked? |
|---|---|---|
| inline function expression in record-field position | **14 / 15** | **NO — inert in both directions** |
| named top-level function (`compaction_structural.pre_step`) | **1 / 15** | yes, at the function itself |

**WI-D8 reported 8 lambda-bound / 7 named-func and it could not be reconstructed under any reading of
the fifteen.** Six of the fourteen inline bindings put `on_pre_step:` alone on its line; eight put it
on one line — a classifier keying on the line rather than the binding form splits those 8/7. **D6, D7
and D8 each banked *"a binding that starts reading `Env` in this slot now fails to build"*; the prize
is real at ONE of fifteen bindings, not seven.**

**And the inert row is worse than "unchecked against its body"**, measured on the shipped `ExtPorts`:

```
inline, row ! {AI, IO, Trace}, body reads Env     -> Env escapes to the builder    (catches nothing)
inline, row ! {AI, IO, Trace}, body calls println -> IO ALSO escapes, though DECLARED (discharges nothing)
control: identical body as a NAMED top-level func -> REJECTED at the function itself
```

## THE ADR PARAGRAPH THIS ITEM WAS SENT TO STAND ON DOES NOT REPRODUCE ON THE ABI

The handoff's "Read first" list points at `ADR:1396-1422`. Grounding it found the repro at
`:1404-1410` is a property of a **locally declared** record type:

```
local   type Ports = { ai_step: … ! {AI, IO, Trace} },  rowless caller  ->  ACCEPTED
import  pkg/sunholo/motoko_ext_abi/types (ExtPorts),    rowless caller  ->  REJECTED
                                        Effect checking failed for function 'rowless_calls_ai_step'
                                        Missing effects: AI, IO, Trace
```

Bisected to one variable: an imported `ExtPorts` nested in a locally declared record still propagates;
a local copy of its `ai_step` field with the identical imported result type does not. **So the ADR's
stated consequence — "`ExtCtx.ports: ExtPorts` is exactly that shape" — is false of the ABI.**

**Every conclusion survives on the inert-inline-row mechanism instead.** `:1415`'s *"a rowless ABI slot
is not provably effect-free"* stands: an **inline** binding in a rowless slot can call
`ctx.ports.ai_step` and the demand escapes to `register_with_config`; a **named** one cannot.
`:1419-1425`'s rejection of the narrowing to five non-rowless hooks stands, with the qualifier that
its premise holds for inline bindings — 14 of 15, so the coarse rule is still right.

**WI-D8's chain measurement STANDS and is stronger than it looked.** `summarize_attempt`'s
`! {AI, IO, Trace}` is a genuine body verdict, because its only effectful call is `ctx.ports.ai_step`
on the imported ABI and that call does propagate. **A correction against D8 was already drafted when
the imported-versus-local distinction refuted it.**

## THE FAIL-CLOSURE TEST, WHICH IS WHY A NARROWER "YES" WAS REFUSED

A narrower amendment was available — *classify `WorldMediated` when the chain is named and the module
closure is ambient-free* — and `compaction_ai` looks like it qualifies: `compaction_ai.ail` imports
only proven-effect-free std plus two effect-free `src/core` modules, and `dst_driver_only.ail:597`
already argues exactly this in prose.

**It fails on fail-closure, measured rather than argued.** The hook is bound **inline** at
`register.ail:109`, in a module importing `getEnvOr` and `readFileResult`, under a
`register_with_config` declaring the full ten-effect row. One line added inside that lambda:

```
+     let _ = getEnvOr("MOTOKO_D9_MUTANT", "");

  ailang check               ->  ✓ No errors found!
  make profile_definition    ->  EXIT 0, "barrier count DERIVED … : 3"
  make declared_vs_performed ->  EXIT 0, 44 ✓ rows — byte-identical to the unmutated run
```

**An ambient environment read inside the most scrutinised hook in the tree, and NOTHING goes red.**

## WHAT WOULD HAVE TO EXIST — classifier 3, named and specified

The producer criterion 2 needs is a **provenance** instrument, and it is **not blocked by the
record-field limitation**, because it is structural rather than type-based.

| Property criterion 2 needs | Nearest thing built | Gap |
|---|---|---|
| provenance of each effect-producing call | classifier 2 (`ext_call_inventory`) | **positive** inventory of port calls; scans for no ambient call at all |
| every ambient effect source ruled out | classifier 1 (`effect-inventory`) | emits **module sets, repo-wide**; obligation 2 clause 2 specifies a *site*-granular per-module inventory and that half is unbuilt |
| per **extension**, transitive closure | — | classifier 1 is repo-wide; the one recorded mediation argument is scoped to **one file** |
| **symbol** granularity | — | module-granular, so `import std/ai (Message)` reads as effect-bearing |

Derived per extension, effect-bearing std imports at package granularity: **4 of 15 import none**
(`decision_framework`, `compaction_structural`, `empty_stop_guard`, `progress_contract_guard`).
`compose` uses ambient `std/process (exec)` and **zero** `ExtPorts.proc_exec` calls — which is exactly
the Route B work.

## WHY THIS HAD TO COME BEFORE ROUTE B — the handoff's revision was right

`check_barrier_count` (`tools/profile_definition/check_fixtures.py:226-230`) states the operative
reading in the gate itself: *"It could still pass criterion 2, but only if every effect in it is a
world-mediated port — and none of the effects in any of these rows is."* **That is a category error
stated plainly: an effect label is never a port.** Under it criterion 2 is unsatisfiable by
construction for any non-empty row, whatever the behaviour underneath. Route B's routed rows would
read `{Process, FS}` and be refused for exactly the reason `on_pre_step` is refused now.

**Route B alone clears zero barriers. Route B plus classifier 3 clears all three. Classifier 3 comes
first.**

A second structural finding: **the barrier count is derived per SLOT and criterion 2 is per
EXTENSION.** `check_barrier_count` reads the ABI row, which all fifteen extensions share. A measured
basis makes a barrier a property of the `(extension, slot)` pair — a change to the derivation, not to
a number.

## Deliverables

- `NOTE-d9-criterion-2-mediation-from-evidence.md` — the argument and the execution report.
- `DRAFT-amendment-adr-001-criterion-2-evidentiary-basis.md` — **DRAFTED, NOT APPLIED.** Two separable
  amendments: **A** names classifier 3 as the only admissible producer and retains the declared-row
  rule as the fail-closed default; **B** corrects the record-field mechanism. **B should land first,
  because A cites it.** Reviewers named by role: both ADR-001 acceptance reviewers (A adds a *fourth*
  deferred mechanism to a list they signed off as finite), the WI-C5 owner, and one reviewer
  independent of D6/D7/D8 for B.

## Gate state

- **`make dst` — EXIT 2, 880 ✓ rows, red set of THREE targets, not D8's two.** Three target `Error`
  lines (`Makefile:2022`, `2019`, **`1086`**) plus the top-level `Error 2`.
  - `test_coverage`, `test_coverage_selftest` — pre-existing since B2a.
  - **`corpus_pr` — NOT a regression, and attributed rather than assumed.** It failed on its wall-clock
    ceiling alone: *273000 ms against a declared ceiling of 80000 ms*. **Re-run alone on a quiet box:
    EXIT 0 in 25000 ms.** Every substantive row is ✓ in both runs — wire witness, both provider error
    classes reaching different branches, all 20 `CorpusRejection` constructors, unreachable register
    EMPTY, and **13 affordable at 381 ms/seed against a minimum of 12**, identical to D6, D7 and D8.
    **The 880 against D8's 881 is exactly this row.**
- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 / 17 of 243**, failing set identical
  member for member to D7's and D8's. Stable since B4.
- **`profile_definition` green, barrier count 3**, printed twice. **`driver_only` PASS at v12.
  `declared_vs_performed` 37/0. `hook_guard` 4/0.** All identical to D8.
- **`git diff ailang.toml` empty — C5's duplicate-dependency trap checked, did not fire.**
- **`.packages/` staleness recurred for the FOURTH consecutive item.** Still not a gate.

## Sites where two answers held up and one was silently wrong: **4** (base 62 → **66**)

The handoff predicted that in an item this light on code they would be in arguments rather than
expressions. **All four are.**

1. **THE ADR PARAGRAPH THE HANDOFF SENT ME TO STAND ON.** `:1398-1418` concludes correctly from a repro
   that does not reproduce on the ABI. It has been the stated mechanism for three decisions since B4
   and nobody cited it in between. Caught by running it against the real `ExtPorts`.
2. **MY OWN GENERALISATION FROM IT, ALREADY DRAFTED.** From four local-type probes: "a record-field
   call propagates nothing", therefore D8's chain fixpoint was an unchecked annotation. Every
   local-type probe supports it; it is false, and the correction would have retracted a sound
   measurement. Caught by the one probe using the imported ABI.
3. **THE BINDING-FORM SPLIT.** 8/7 and 14/1 are both "derived"; the one keying on the line rather than
   the binding form is silent and understates the exposure sevenfold.
4. **A FILE-SCOPED CLAIM READING AS EXTENSION-SCOPED.** `dst_driver_only.ail:597` is true of
   `compaction_ai.ail` and is cited as why the *extension* reaches effects only through `ai_step`.
   The hook is bound in the other file, which imports `std/env` and `std/fs`.

**Not counted:** the `.d9probe` module name AILANG rejects for the leading dot; `std/trace` exporting
`event` not `emit`; `ExtClockReading.now_ms` written as `value`; and running the first provenance probe
from the scratchpad, where **AILANG auto-relaxes MOD010 and says so in a warning** — the trap both
classifier tools' docstrings warn about, which is why every decisive probe was re-run under the repo.
**All four were LOUD.** **Closest call, also not counted: `corpus_pr`'s red** — attributing a ceiling
breach to the tree rather than the box would have been wrong, but it was a RED, not a silent pass.

## Corrections owed to the plan

1. **S16 NEEDS ITS FOURTH EXTENSION, AND IT IS ABOUT THE SUBJECT'S TYPE, NOT ITS SYNTAX.** C5's was
   about shared producers; D6's about a producer's reach; D8's about the subject's syntactic *form*.
   This one: **an instrument must exercise the subject through the same TYPE DECLARATION the subject
   uses.** A probe over a locally declared copy of an imported record measures a different language.
2. **A "MINIMAL REPRO" IS A CLAIM ABOUT WHAT WAS MINIMISED AWAY.** The ADR's four-line repro minimised
   away the import, which is the variable. *Suggested S1 extension: a repro recorded as evidence about
   production code must be re-run against the production type before it is cited a second time.* It was
   cited at B4 and not re-run for eleven items.
3. **S22's FALSIFIER REQUIREMENT PAID OFF ON ITS FIRST USE.** D8 asked for one; this item's
   binding-form derivation carried one, and it is why 14/1 is quotable against a report saying 8/7.
4. **`.packages/` STALENESS, FOURTH ITEM RUNNING.** A two-command fix that has now cost four items.
5. **A CEILING GATE WHOSE PRODUCER INCLUDES THE MACHINE.** `corpus_pr` moved **11×** between a loaded
   box and a quiet one with the tree unchanged. *Normalise against a same-run calibration, or state
   that it measures the box.* Four items have called its margin "thin" without establishing which of
   the two it measures.

## Out of scope, still owed

- **Classifier 3, the ambient-source inventory** — NEW, specified in the draft, and now the
  precondition for Route B being worth paying for.
- **Route B** — untouched. **Necessary and, alone, insufficient.**
- **WI-C5**, the last unbuilt item — still three barriers, and its precondition is now named.
- **The fourteen `register_with_config` rows** — still the sharpest un-owned item, and this item raises
  its stakes: with 14 of 15 bindings inline rather than 8, essentially all enforcement lives there.
- **A correction to the upstream filing `fb_74f53de3ae65854c`** — the filing is valid; the ADR applies
  it more widely than it holds, and the gap that actually reaches this tree is not in it. **Recorded as
  owed; not filed, per scope.**
- **The `motoko-ext-abi` major** — eight changed rows, stated not cut.
- The two sibling `st.world_state` finalize sites; interaction-log file reads; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream; the
  `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- `test_coverage` / `test_coverage_selftest`, red since B2a and untouched.

## DID COVERAGE MOVE? **NO.**

`driver_only` installs nothing and covers nothing. **Extension-model coverage is ZERO.** Eleven of
eleven rows hold, four still lean on the empty install list, and the acceptance table was not re-run.

**S21 re-asked: the count is still four, and nothing concentrated or withdrew.**

**D7 measured three barriers and removed none. D8 measured the port under one of them and removed
none. D9 measured the CRITERION and removed none** — and found that the criterion was never the
obstacle. Until classifier 3 exists, Route B buys zero barriers, WI-C5 cannot complete, and the axis's
extension-model coverage stays **structurally** zero. **What is new is that this is a missing
instrument with a name, a specification and an owner-shaped gap, rather than a property of the
criterion. That is the difference between a cost and a wall.**
