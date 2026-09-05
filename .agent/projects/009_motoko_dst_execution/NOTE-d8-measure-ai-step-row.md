# WI-D8 — `ExtPorts.ai_step`'s row, measured. **IT WAS OVER-DECLARED BY SEVEN. THE BARRIER STILL STANDS AND THE COUNT IS STILL THREE.**

Thirty-second calibration run. Written against HEAD `9022333`, branch
`arniwesth/mot-69-wi-d7-the-three-remaining-barriers`.

## Window

**~80 minutes** wall-clock: `2026-08-06T11:43:38Z` → `2026-08-06T13:05Z`. Three runs dominate it:
`make dst` in full and TWO cache-cold whole-tree sweeps. **The measurement itself cost about
twenty-five minutes** — a baseline plus a tree-wide narrowing pass plus a per-implementation body
pass plus two chain fixpoint walks, and then **four syntactic-position probes that were not planned
and that changed the item's central finding.**

**The cheapest surprise was NOT the ratio D6 and D7 both reported.** For them, measuring the rows was
most of the work and moving them was nearly free. Here moving the rows was genuinely free — 63+17
sites by script, one pass — and the expensive half was **discovering that the instrument every
narrowing since D6 has relied on does not reach the construct the subjects are written in.**

## Grounding

**Clean at `9022333`.** `git status` empty at start; the handoff's probe was reverted as it said and
the tree was byte-identical to `eed91bd` plus the two documentation commits.

**S9's concurrency check: no other session is running a gate.** The same idle
`src/core/supervisor.ail` agent session D5, D6 and D7 each found — now 2d elapsed against 7m56s CPU —
plus days-old `make claude` shells. No gate, no `make dst`. **Caches cleared before every
measurement**, `~/.ailang/cache/registry` left alone and verified at 1 entry throughout. **Per S17 a
full `tar` of `packages src scripts Makefile tools` was taken before the first edit** and every
mutant restored by extraction, never by `git checkout`. **Per S19, `$?` was never read after a pipe**
and both long runs were captured to files and read as artifacts.

## THE MEASUREMENT — `ExtPorts.ai_step`, which nothing had ever measured

**The item's durable output.** Declared **ten**. Performs **three**.

```
ExtPorts.ai_step  DECLARED  ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream, Trace}
ExtPorts.ai_step  PERFORMED ! {AI, IO, Trace}
OVER-DECLARED BY SEVEN:      Process, FS, Env, Net, SharedMem, Clock, Stream
```

**Named by the compiler, from a BODY and not from an annotation**, which is the distinction D7 counted
as a silently-wrong site and this item was made entirely of:

```
Error: effect checking failed in src/core/session:
  Effect checking failed for function 'ext_ai_step'
  Missing effects: AI, IO, Trace
```

`session.ext_ai_step`'s whole body is one call to `Ports.model_step`, which has been `! {AI, IO, Trace}`
since WI-A1. **The seven surplus effects are effects `model_step` cannot produce.**

### Every refusal, classified — annotation or body

**Nine bindings of the field, derived from source rather than taken from the handoff.**

| Binding | Form | Verdict | Producer |
|---|---|---|---|
| `ctx_defaults.noop_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `compaction_ai.stub_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `empty_stop_guard.noop_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `progress_contract_guard.noop_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `conformance.canned_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `conformance.poison_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `declared_vs_performed.probe_ai_step` | top-level func | accepts `! {}` | effect checker, **body** |
| `session.ext_ports_of`'s closure | **record-field lambda** | performs `{AI, IO, Trace}` | **transitively, via `ext_ai_step`'s body — the compiler cannot read the lambda** |
| `long_qwen_compaction_dst`'s closure | **record-field lambda** | performs `{AI, IO, Trace}` | calls `ports.model_step` directly; same |

**The first refusal I recorded was an ANNOTATION and I nearly filed it as a body.** Narrowing the
seven top-level implementations while leaving the ABI field at ten gives

```
failed to unify record field 'ai_step': incompatible closed rows:
  r1 has extra labels [], r2 has extra labels [AI Clock Env FS IO Net Process SharedMem Stream Trace]
```

which is **two annotations failing to unify** and says nothing about any body. Narrowing the field
too — so the annotations agree — leaves all seven green, and *that* is the body verdict.

### And the consequence for `on_pre_step`, re-measured end to end

With the port at three, **every step of `compaction_ai`'s chain was read off the effect checker one at
a time**, each narrowed to `! {}` and the demand taken from the error:

```
summarize_attempt        demands {AI, IO, Trace}
summarize_with_ai_result demands {AI, IO, Trace}
summarize_with_ai        demands {AI, IO, Trace}
fresh_compaction         demands {AI, IO, Trace}
compact_with_ai          demands {AI, IO, Trace}     <- fixpoint
```

Then D7's slot measurement repeated with the port narrowed: **14 of 15 bindings accept the empty row;
exactly one refuses — `compaction_ai`, at `register.ail:93` — now at `extra labels [AI IO Trace]`
rather than ten.** Same shape, one third the width.

The dispatch folds settle at `{AI, Clock, IO, Trace}` — the hook's three plus the host's own `Clock`,
the same host contribution D7 recorded through `emit_dummy_hook`.

## THE `on_pre_step` DECISION. **IT IS STILL A BARRIER, AND THE COUNT IS STILL THREE.**

**D7's vocabulary conclusion SURVIVES. That is the sentence WI-C5 inherits.**

The handoff asked for this to be decided against D5 criterion 2 read directly, in either direction,
and not left to the narrowing. D5 admits an effectful hook only when it is *"effectful only through D1
world-mediated ports, with explicit world state returned to the host"*.

- **Conjunct 2 is satisfied** and has been since B2b: `PreStepOutcome.next_state`, and
  `compact_with_ai` returns `s.next_state` rather than `ctx.world`.
- **Conjunct 1 is not established by the row, and the narrowing does not change that.**

**What the narrowing DOES change is real and worth stating precisely, because it is the reason the
handoff thought the answer might flip.** At ten effects the row was **positive evidence AGAINST**
mediation: seven of the ten are effects the mediating port cannot produce, so a reader comparing the
row against the claim found them in contradiction. **At three, the row stops contradicting the claim.**
Every declared effect is exactly what the mediated port performs.

**It does not start supporting it.** `! {AI, IO, Trace}` is equally consistent with a binding that
calls `println` and an ambient provider directly, and nothing in the row distinguishes the two. The
barrier is the row's vocabulary, exactly as D7 said — the narrowing removes an objection to mediation
without supplying the vocabulary criterion 2 needs.

**`make profile_definition` derived the count itself and said so without being told:**

```
✓ barrier count DERIVED from the ABI rows and the dispatch table: 3
    BARRIER  on_pre_step: unconditionally dispatched, declares ! {AI, IO, Trace}
    BARRIER  on_response_intercept: unconditionally dispatched, declares ! {IO, Process, FS, Clock}
    BARRIER  on_solver_candidate: unconditionally dispatched, declares ! {Process}
  → 3 barrier(s) stand, so NO extension is installable in a conformant profile
```

That is D7's gate working as designed: the row changed width, the count did not move, and no artifact
had to be told either fact. **The zero trigger never fired and nothing was installed.**

## THE FINDING THAT WAS NOT IN THE MISSION, AND IT IS THE BIGGEST ONE

**AILANG DOES NOT EFFECT-CHECK A LAMBDA'S DECLARED ROW WHEN THE LAMBDA IS IN RECORD-FIELD POSITION —
WHICH IS HOW EVERY HOOK IN THIS TREE IS BOUND.**

Measured across four syntactic positions, and **the first reading of it was wrong in the permissive
direction**:

| Position | row `! {IO}`, body reads `Env` | |
|---|---|---|
| top-level `func` | **REJECTED** | |
| `let`-bound lambda | **REJECTED** | |
| argument-position lambda | **REJECTED** | |
| **record-field lambda** | **ACCEPTED** | ← the gap |

and separately, at any position:

| | | |
|---|---|---|
| lambda, row `! {}`, body performs | **ACCEPTED** | an empty row on a lambda reads as *unannotated, infer* — not as the claim *performs nothing* |

**My first probe was a `let`-bound lambda at `! {}` and it was accepted, from which I concluded "a
lambda's row is never checked". That is FALSE**, and a single probe would have shipped it. It took a
matrix to find that the gap is *positional*.

### What this costs D6's and D7's recorded prize

Both items recorded the same reward for narrowing: *"a binding that starts reading `Env` in this slot
now fails to build."* **That is true for a binding written as a top-level function and false for one
written inline in the record.** Derived per slot:

| Slot | lambda-bound (unchecked) | named-func (checked) |
|---|---|---|
| `on_pre_step` | **8 / 15** | 7 / 15 |
| `on_budget_plan` (D6's) | **4 / 15** | 11 / 15 |
| `on_response_intercept` (D7's) | **7 / 15** | 8 / 15 |
| `on_solver_candidate` (D7's) | **6 / 15** | 9 / 15 |

**And the gate's two-sided control could not have caught it, for S16's reason one level down again.**
`write_slot_mutant` emits `export func mutant_hook(...)` — a **top-level function**. The control is
sound and it measures a construct that roughly half the subjects do not use.

### But the effect is not lost — it MOVES, and that half matters more

The lambda's own annotation is unchecked; **the body's effects still propagate to the enclosing
top-level function, whose row IS checked.** So the enforcement is real and it lives one level up from
where D6 and D7 put it:

> narrowing a **hook slot's** row constrains a binding written as a top-level function, and constrains
> nothing about a binding written inline — for that one, the constraint is **`register_with_config`'s**
> row.

**Measured in `empty_stop_guard`:** an inline `on_pre_step` reading `Env` under `! {AI, IO, Trace}`
compiles while the registration row admits `Env`, and is rejected the moment it does not —
`Effect checking failed for function 'register_with_config' … Missing effects: Env`.

**The absorption is PER EFFECT, not global, and my first draft of this claim said "all fifteen carry
the wide row and absorb anything". The derivation refuted it on sight.** Fifteen extensions declare
**fourteen** registration rows between them (`decision_framework` and `microrag` declare none;
`compose` declares two):

| Effect | absorbed by |
|---|---|
| `Env` | **14 of 14** — every row that exists |
| `FS` | 12 of 14 |
| `Process` | 7 of 14 |

Exactly **one** registration — `compaction_ai`'s — still carries the full ten-effect row and absorbs
everything. **Reported, not fixed:** D6 measured that nine of fifteen genuinely read `Env` at
registration, so narrowing those rows is its own measurement item rather than an ABI edit.

## What narrowed

| Row | Before | After | Barrier? |
|---|---|---|---|
| `ExtPorts.ai_step` | ten effects | **`! {AI, IO, Trace}`** | n/a — a port, not a hook |
| `ExtensionHooks.on_pre_step` | ten effects | **`! {AI, IO, Trace}`** | **YES, unchanged** |
| `fold_pre_step_chain_rec` / `dispatch_pre_step_chain` | ten effects | **`! {AI, Clock, IO, Trace}`** | host cascade |

**80 annotation sites moved** across 55 files. The barrier count did not.

## S22, and it bit TWICE in this item — once against the handoff and once against my own instrument

**The handoff said "the eleven annotation sites carrying the same ten-effect row". Deriving them found
SEVENTEEN.**

**And the first derivation I wrote MISSED THREE MORE**, because it classified a site by the return
type named on the same line — which lambda-form bindings do not name:

```
src/core/ext/runtime.ail:504   on_pre_step: \ctx _msgs. { decision: PassThrough, ... } ! {IO, Process, ...}
src/core/ext/runtime.ail:531   on_pre_step: \ctx _msgs. { decision: PassThrough, ... } ! {IO, Process, ...}
scripts/dst/long_qwen_compaction_dst.ail:432   (same form)
```

**The handoff predicted those three would appear as "an annotation mismatch on the dispatch folds' own
rows".** They are not the folds. They are three lambda-form binding sites my classifier could not see,
and once they narrowed, `runtime.ail` and `session.ail` both passed with the folds untouched. **A
prediction from a probe and a derivation from source disagreed, and the derivation was right.**

Both undercounts are now asserted in the gate as a derived set rather than an enumerated one.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243.** Failing set
  **identical member for member** to D7's: 7 `TC_ARITY_001` smoke scripts, `probe_phase_vocab_sealed`,
  5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture. Stable since B4.
- **Run TWICE**, once after the narrowings and once after the documentation edits, per S18 — this item
  rewrote a great deal of commentary after the code was green. The failing sets are **identical member
  for member** across both.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Both pre-existing since B2a. `make --keep-going` emitted exactly **two** target `Error` lines
  (`Makefile:2022` and `Makefile:2019`) plus the top-level `Error 2`.
- **881 ✓ rows against D7's 870. The +11 is fully attributable and was CHECKED rather than assumed:**
  `declared_vs_performed` contributes 37 rows where it contributed 26. **No other target's row count
  moved.**
- **`declared_vs_performed`: 37 passed, 0 failed** (D7: 26). **`hook_guard`: 4 passed, 0 failed.**
  **`driver_only`: 6/6.** **`profile_definition`: green, barrier count 3**, printed twice per
  `make dst` as at D7.
- **The corpus artifact is unchanged**, read from `/tmp/corpus_pr.out` per S19 (deleted before the run,
  so it was written by this item's own `make dst`): the unreachable register is EMPTY,
  `declared ⊆ observed` **and** `observed ⊆ declared`, both budget mutants fire, and the same thin
  margin D5 flagged — **13 affordable at 381 ms/seed against a minimum of 12**, identical to D6 and D7.
- **`git diff ailang.toml` is empty — C5's duplicate-dependency trap was checked and did not fire.**
  `ailang.lock` moved as part of the normal build.
- **`.packages/` staleness recurred for the THIRD consecutive item.** `make sync_packages` was needed
  again before any gate would read source-consistent state. D6 and D7 both recorded it; it is still
  not a gate.

### The new gate rows, and every one is falsifiable

`make declared_vs_performed` gained **eleven** rows:

- **the two narrowed rows**, `ExtPorts.ai_step` and `ExtensionHooks.on_pre_step`, each asserted at the
  width measured from bodies.
- **a derived stale-site row** over both slots, which is why the three lambda-form sites cannot come
  back unnoticed.
- **the two LIMITATION rows**, each stating what it costs the narrowings, plus **a two-sided control**
  proving the record-field acceptance is caused by the *position* rather than by the effect checker
  being absent, the file being unreachable, or the probe being malformed. **They go RED if the
  limitation is FIXED upstream**, because that is the day the controls in this file have to be
  re-sited and the D6/D7/D8 enforcement claims become true at more sites than they are.
- **four absorption rows**, deriving how many registration rows admit `Env`, `FS` and `Process`, with
  the denominator asserted separately because rows and extensions differ.
- **`compaction_ai`'s total-absorption registration**, named rather than counted.

**D7's `on_pre_step` slot-row pin went RED on the narrowing rather than accepting it** —
*"a change of width is a change of claim and must be re-measured, not inherited"* — which is the row
doing exactly its job. It was re-measured, and the pin follows the measurement.

## The controls had to move again, one slot later, and there was nowhere left to go

D6 moved the runtime vacuity controls from `on_budget_plan` to `on_pre_step` because narrowing the
first slot made a performing body unwritable there. **D8 narrowed `on_pre_step`, and a top-level
control reading `Env` stopped compiling for the identical reason.**

There is no third slot with a wide unconditional row. **What keeps the controls alive is the
limitation rather than a slot**: they are now bound inline in record-field position — *the same form
the subjects use*, which is what S16 asks of an instrument — with the builders declaring `! {Env}` and
`! {FS}` because the leak reaches them and they are honest about it. Passing the hook in as a
parameter does not work: argument position **is** checked.

## The owed `motoko-ext-abi` major

**EIGHT changed rows now, and this item changed the eighth.** B1/B2a/B2b/C5 changed four; D6 changed
`on_budget_plan`; D7 changed `on_response_intercept` and `on_solver_candidate`; **D8 changes
`ExtPorts.ai_step` and `ExtensionHooks.on_pre_step` — the fourth and seventh of those rows moving for
the second time.**

**This item did NOT cut the major**, for D6's and D7's reason unchanged: cutting it is a release act.
`ailang lock` re-recorded the interface hashes as part of the normal build. **C5's trap was checked and
did not fire**: `git diff ailang.toml` is empty.

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **`ExtPorts.ai_step` WAS OVER-DECLARED BY SEVEN EFFECTS AND NOTHING HAD EVER MEASURED IT.** D7's
   central conclusion rested on the clause "whose own port row is exactly those ten", taken as given.
   The port performs three.
2. **AILANG DOES NOT EFFECT-CHECK A RECORD-FIELD LAMBDA'S DECLARED ROW.** Every hook in this tree is
   bound that way; eight of fifteen bind `on_pre_step` that way. Not in the mission, and it is the
   item's largest finding.
3. **AN EMPTY ROW ON A LAMBDA IS NOT A CLAIM** — it reads as *unannotated, infer*. So D6's narrowing
   of `on_budget_plan` to no row constrains its four lambda bindings not at all.
4. **THE ENFORCEMENT LIVES ON `register_with_config`, NOT ON THE SLOT**, for inline bindings — and
   `Env` is admitted by all fourteen registration rows that exist.
5. **THE GATE'S TWO-SIDED CONTROL USES A TOP-LEVEL FUNCTION**, so it is sound and measures a construct
   roughly half the subjects do not use. S16 one level down, again.
6. **THE SITE COUNT WAS 17, NOT 11** — and my own first derivation missed three more.
7. **THE HANDOFF'S PREDICTED "FOLD MISMATCH" WAS NOT THE FOLDS.** It was three lambda-form binding
   sites; the folds needed no edit to pass.
8. **THE CONTROLS RAN OUT OF SLOTS.** Three consecutive items have now narrowed the slot the vacuity
   controls lived in.

**Decided — a human chose:**

1. **`on_pre_step` REMAINS A BARRIER, decided against criterion 2 read directly** rather than inferred
   from the narrowing. Recorded with the distinction between *stops contradicting* and *starts
   supporting*.
2. **Narrow both rows anyway**, for D7's reason: it buys the compiler at the seven bindings written as
   top-level functions, and a row seven effects wider than any body needs is a row that lets a binding
   start performing `Process` silently.
3. **Do NOT narrow the fourteen `register_with_config` rows.** Nine of fifteen genuinely read `Env` at
   registration; that is a measurement item, not an ABI edit.
4. **Record the two limitations as GATE ROWS that go red when FIXED**, rather than as prose.
5. **Bind the controls in the form the subjects use**, accepting that this makes them depend on a
   limitation — and asserting the limitation so the dependency is visible.
6. **No ADR amendment.** The barrier stands, so criterion 2 did not need amending, and D5 is Accepted.
7. **The ABI major is not cut here**, and the count is stated at eight.
8. **Nothing was installed.**

## Sites where two answers type-checked and one was silently wrong: **3**

**Base 59 from D7's report. This run makes it 62. Determinism has still caught none.**

The handoff said to look first and hardest at anything reading a declared row as evidence of
behaviour, *"because this item is made entirely of that reading"*. **All three are that.**

1. **THE TREE-WIDE GREEN THAT MEANT NOTHING.** Narrowing all seventeen `ai_step` sites to `! {}` left
   **every one of the 31 subject files green, including `session.ail`**, whose bridge closure calls a
   helper still declared at ten effects. That reads as *the port performs nothing*. It is not: the
   closure is a record-field lambda and its row is not checked at all. **The handoff's own four-minute
   probe is this reading** — it reports five modules GREEN with `ai_step` at three, and offers it as
   suggestive. It is consistent with the true answer and it is not evidence for it.
2. **AN ANNOTATION REJECTION READ AS A BODY VERDICT** — D7's site 1, recurring in the item warned about
   it. Narrowing the seven top-level implementations while the ABI field stood at ten produces
   `incompatible closed rows … extra labels [AI Clock Env …]`, which looks like the effect checker
   reporting behaviour. Settled by narrowing the field too, so the annotations agree and the body is
   the only remaining producer.
3. **A SINGLE PROBE THAT GENERALISED IN THE PERMISSIVE DIRECTION.** From one `let`-bound lambda at
   `! {}` I concluded "a lambda's declared row is never checked". Both the probe and the conclusion
   type-check against the observation; the conclusion is false in three of four positions. Had it
   shipped, this note would have told WI-C5 that no hook row anywhere constrains anything — which is
   *more* alarming than the truth and wrong in the direction that voids D6's and D7's work entirely.

**Not counted, and said so rather than inflating the number:** the `[^\n]` in a grep ERE that means
"not backslash or n" and stopped matching at the `n` in `ExtensionHooks`; the `set -euo pipefail`
assignment whose failing grep killed the script; the absorption denominator counted over extensions
where the grep counts rows. **All three were LOUD** — each turned a gate row red or stopped the script
on its first execution. The counter tracks answers that are *silently* wrong.

## Corrections owed to the plan

1. **THIS ITEM HAS A PLAN ENTRY.** D7's report said D5's and D6's were still owed; **they are not — both
   exist, written at review, and D7 corrected itself on this point in the plan.** C4's planning defect
   1 is now discharged for four consecutive items. **WI-C5 remains the only unbuilt work item in the
   plan and the next one.**
2. **S16 NEEDS A THIRD EXTENSION, AND IT IS ABOUT THE SUBJECT'S SYNTAX RATHER THAN THE CHECK'S
   PRODUCERS.** *Suggested: an instrument must exercise the subject in the FORM the subject is
   written in.* C5's version was about a check's two sides sharing a producer; D6's was about a
   producer's reach over a subject set. This one is narrower and sharper: the control was written as a
   top-level function, the subjects are record-field lambdas, and AILANG treats those differently.
   **A control in the wrong syntactic form is green for the same reason a control in the wrong process
   was.**
3. **A COMPILER GUARANTEE IS A CLAIM ABOUT A LANGUAGE, AND IT IS FALSIFIABLE THE SAME WAY A COUNT IS.**
   D6 and D7 each recorded "a binding that starts reading `Env` now fails to build" from a control
   that demonstrated it once, in one form. *Suggested extension to S1: when an item's prize is "the
   compiler now enforces X", probe the enforcement in every syntactic position the subjects actually
   use, and assert the fraction.* Three items in a row have banked this prize; this one measured it and
   it is roughly half of what was recorded.
4. **S22 BIT AGAINST THE DERIVATION ITSELF, NOT ONLY AGAINST PROSE.** The rule says derive the list
   from a producer rather than take it from prose. **This item derived it and the derivation was still
   wrong by three**, because the classifier keyed on a return type that one binding form does not
   name. *Suggested: a derived set needs its own falsifier — the check that the residue is empty —
   not just a derivation.* That row is what found the three.
5. **`.packages/` STALENESS RECURS FOR THE THIRD ITEM.** `make sync_packages` needed again. D6 and D7
   both recorded it. It is a two-command fix and it has now cost three items; it is worth a gate.

## Out of scope, unchanged and still owed

- **WI-C5, the `compose`-bearing profile** — the next item and the last unbuilt one. It must still
  clear **three** barriers.
- **Route B for the other two slots** — world-mediated process and file seams on `ExtPorts`. Untouched
  here, as the handoff required, and it is where `on_response_intercept` and `on_solver_candidate`
  remain: compose's inline path genuinely spawns the compiler and writes files, and
  `context_mode.finalize_with_index` genuinely spawns a `node` bridge. **No narrowing reaches those.**
- **The fourteen `register_with_config` rows** — new, and now the sharpest un-owned item, because it
  is where the enforcement for inline hook bindings actually lives.
- **Filing the record-field lambda gap upstream** — measured here with a minimal four-position repro,
  not filed.
- **The `motoko-ext-abi` major and lockstep re-release** — eight changed rows now.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.

## DID COVERAGE MOVE? **NO.**

`driver_only` installs nothing. It covers nothing. **The axis's extension-model coverage is ZERO.**
Eleven of eleven rows still hold, four of them still lean on the empty install list, and the
acceptance table was not re-run because nothing here changes a row's answer.

**S21, re-asked: the count is still four, and nothing concentrated or withdrew.** No row closed, so no
reason was removed from any surviving exemption — which is the rule returning "no change" honestly
rather than finding nothing.

**D7 measured three barriers and removed none. D8 measured the port underneath one of them, found it
over-declared by seven, narrowed two rows — and removed none.** The empty install list is **FORCED**,
exactly as it was at D5, D6 and D7.

**And the sentence WI-C5 inherits is the one it inherited from D7, now standing on a measurement
instead of an assumption: `on_pre_step`'s barrier is THE ROW'S VOCABULARY.** What is new is that the
row is no longer evidence against mediation, and that a declared row is a weaker instrument than three
consecutive items have treated it as.
