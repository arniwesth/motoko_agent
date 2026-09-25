# 2026-08-06 Cluster 32: WI-D8 — `ExtPorts.ai_step` measured, and the compiler's guarantee measured with it

## Context

Branch: `arniwesth/mot-69-wi-d7-the-three-remaining-barriers`.

Session span: `9022333` → **uncommitted**. 56 files modified plus the execution NOTE. Input was
`HANDOFF-execute-d8-measure-ai-step-row.md` (`48ecf09`), executed against HEAD `9022333`.
Thirty-second code session of project 009. Pin **v0.33.0**.

**The handoff's grounding claim was accurate.** It said its probe was reverted and the tree was
byte-identical to `eed91bd`; `git status` was empty at start and nothing had to be recovered. This is
the first item in three where the handoff's opening statement about tree state needed no correction.

**Window: ~80 min**, `11:43:38Z` → `13:05Z`. Three runs dominate it: `make dst` in full and **two**
cache-cold whole-tree sweeps. **The measurement cost about twenty-five minutes and moving the rows was
genuinely free** — 80 sites by script in one pass. **The expensive half was neither**: it was four
syntactic-position probes that were not planned, and that changed what the item concluded about every
narrowing since D6.

**Grounding was clean.** **S9's concurrency check: no gate running** — the same idle
`src/core/supervisor.ail` agent session D5, D6 and D7 each found, now 2d elapsed against 7m56s CPU,
plus days-old `make claude` shells. Caches cleared before every measurement, `~/.ailang/cache/registry`
verified at 1 entry throughout. Per S17 a `tar` of `packages src scripts Makefile tools` was taken
before the first edit and every mutant restored by extraction.

| Definition-of-done item | State |
|---|---|
| `ExtPorts.ai_step`'s row measured, every refusal driven to a body or an annotation | **met** — 9 bindings, each classified |
| The two distinguished per D7's method, not by reading `extra labels` | **met** — and the annotation reading was hit once and caught |
| A decision on `on_pre_step`, recorded either way, against D5 criterion 2 read directly | **met** — **it remains a barrier** |
| The derived barrier count moves on its own if the barrier falls | **met** — it did not fall; gate derived **3** unprompted |
| Whatever narrows, narrows | **met** — both rows to `! {AI, IO, Trace}`, 80 sites |
| S22: derive every list the item quantifies over, and assert it | **met** — and the derivation was **still wrong by three** |
| S13 sweep cache-cold with `AILANG_RELAX_MODULES=1`, member-for-member | **met** — 226/17 of 243, run **twice**, identical |
| `make dst` in full | **met** — exit 2, red set exactly the two pre-existing |
| S9/S17: caches cleared, registry untouched, mutants restored by `cp`/`tar` | **met** |
| S19: read artifacts not transcripts, never `$?` after a pipe | **met** — both long runs captured to files |
| Route B for the other two slots (out of scope) | **respected** — untouched |
| Stop and report if the count reaches zero | **not triggered** — count held at 3 |
| Stop and report rather than writing an ADR amendment | **not triggered** — barrier stands, so none needed |
| The `motoko-ext-abi` major: state the count, do not cut it | **met** — now **eight** changed rows |

## THE ANSWER

**The port was over-declared by seven effects. Both rows narrowed. The barrier did not move.**

```
ExtPorts.ai_step  DECLARED  ! {AI, IO, Process, FS, Env, Net, SharedMem, Clock, Stream, Trace}
ExtPorts.ai_step  PERFORMED ! {AI, IO, Trace}
OVER-DECLARED BY SEVEN:      Process, FS, Env, Net, SharedMem, Clock, Stream
```

| | D6 | D7 | **D8** |
|---|---|---|---|
| `ExtPorts.ai_step` row | ten effects | ten effects, **assumed** | **`! {AI, IO, Trace}`, measured** |
| `on_pre_step` ABI row | ten effects | ten effects — did not move | **`! {AI, IO, Trace}`** |
| `on_response_intercept` ABI row | nine | `! {IO, Process, FS, Clock}` | unchanged |
| `on_solver_candidate` ABI row | nine | `! {Process}` | unchanged |
| **Barriers** | *reported as 0* | 3, derived | **3, derived — unmoved** |
| **Extensions installable** | *reported as 15* | 0 | **0** |
| `driver_only` install list | *reported CHOSEN* | FORCED empty | **FORCED empty** |
| Rows leaning on the empty install list | 4 | 4 | **4** |
| `declared_vs_performed` | 15 rows | 26 rows | **37 rows** |
| ✓ rows in `make dst` | 857 | 870 | **881** (+11, all attributed) |
| `motoko-ext-abi` changed rows | 5 | 7 | **8** |

**The measurement, from bodies rather than annotations.** `session.ext_ai_step`'s whole body is one
call to `Ports.model_step`, `! {AI, IO, Trace}` since WI-A1, and the effect checker names it when the
declaration is narrowed:

```
Effect checking failed for function 'ext_ai_step'
Missing effects: AI, IO, Trace
```

Nine bindings derived from source: **seven top-level functions whose bodies accept `! {}`** (a genuine
body verdict, obtained only after narrowing the ABI field too so the annotations agreed), and **two
record-field lambdas** that reach `model_step` and nothing else.

Then `compaction_ai`'s chain re-derived one function at a time — `summarize_attempt`,
`summarize_with_ai_result`, `summarize_with_ai`, `fresh_compaction`, `compact_with_ai` — each
demanding `{AI, IO, Trace}` and nothing more. D7's slot measurement repeated with the port narrowed:
**14 of 15 accept the empty row, `compaction_ai` alone refuses, now at `extra labels [AI IO Trace]`.**

## THE DECISION, and it was taken against the criterion rather than inferred from the narrowing

**`on_pre_step` REMAINS A BARRIER. D7's vocabulary conclusion SURVIVES.** That is the sentence WI-C5
inherits.

D5 admits an effectful hook only when it is *"effectful only through D1 world-mediated ports, with
explicit world state returned to the host"*. Conjunct 2 has been satisfied since B2b. Conjunct 1 is
not established by the row, and narrowing does not change that.

**What the narrowing does change is worth stating precisely, because it is why the handoff thought the
answer might flip.** At ten effects the row was **positive evidence against** mediation — seven of the
ten are effects the mediating port cannot produce. **At three it stops contradicting the claim**;
every declared effect is exactly what the mediated port performs. **It does not start supporting it**:
`! {AI, IO, Trace}` is equally consistent with a binding calling an ambient provider directly.

`make profile_definition` derived `3` on its own and printed `on_pre_step`'s new row without being
told either fact — D7's gate working exactly as designed.

## THE FINDING THAT WAS NOT IN THE MISSION, AND IT IS THE LARGEST ONE

**AILANG does not effect-check a lambda's declared row in RECORD-FIELD position — which is how every
hook in this tree is bound.**

| Position | row `! {IO}`, body reads `Env` |
|---|---|
| top-level `func` | **REJECTED** |
| `let`-bound lambda | **REJECTED** |
| argument-position lambda | **REJECTED** |
| **record-field lambda** | **ACCEPTED** ← the gap |

and separately, at any position, a lambda declaring `! {}` whose body performs is **ACCEPTED** —
an empty row reads as *unannotated, infer*, not as the claim *performs nothing*.

**What it costs D6's and D7's recorded prize.** Both banked *"a binding that starts reading `Env` in
this slot now fails to build"*. Derived per slot:

| Slot | lambda-bound (unchecked) | named-func (checked) |
|---|---|---|
| `on_pre_step` | **8 / 15** | 7 / 15 |
| `on_budget_plan` (D6's) | **4 / 15** | 11 / 15 |
| `on_response_intercept` (D7's) | **7 / 15** | 8 / 15 |
| `on_solver_candidate` (D7's) | **6 / 15** | 9 / 15 |

**The gate's own two-sided control could not have caught it**, for S16's reason one level down again:
`write_slot_mutant` emits `export func mutant_hook(...)` — a top-level function — so the control is
sound and measures a construct roughly half the subjects do not use.

**But the effect is not lost, it MOVES, and that half matters more.** The lambda's annotation is
unchecked; its body's effects still propagate to the enclosing function, whose row **is** checked. So
the enforcement is real and lives one level up:

> narrowing a **hook slot's** row constrains a binding written as a top-level function, and constrains
> nothing about one written inline — for that, the constraint is **`register_with_config`'s** row.

Measured in `empty_stop_guard`, two-sided. And the absorption is **per effect, not global** — the
first draft of this claim said "all fifteen carry the wide row" and the derivation refuted it on
sight. Fifteen extensions declare **fourteen** registration rows (`decision_framework` and `microrag`
declare none; `compose` declares two):

| Effect | absorbed by |
|---|---|
| `Env` | **14 of 14 — every row that exists** |
| `FS` | 12 of 14 |
| `Process` | 7 of 14 |

Exactly one registration — `compaction_ai`'s — still carries the full ten-effect row. **Reported, not
fixed**: D6 measured that nine of fifteen genuinely read `Env` at registration, so narrowing those is
its own measurement item.

## S22 bit twice, and once against the derivation itself

**The handoff said "eleven annotation sites". Deriving them found SEVENTEEN.**

**And the first derivation written here MISSED THREE MORE**, because it classified a site by the return
type named on the same line — which lambda-form bindings do not name:

```
src/core/ext/runtime.ail:504   on_pre_step: \ctx _msgs. { ... } ! {IO, Process, ...}
src/core/ext/runtime.ail:531   on_pre_step: \ctx _msgs. { ... } ! {IO, Process, ...}
scripts/dst/long_qwen_compaction_dst.ail:432   (same form)
```

**The handoff predicted these would appear as "an annotation mismatch on the dispatch folds' own
rows". They are not the folds** — once the three narrowed, `runtime.ail` and `session.ail` both passed
with the folds untouched. A prediction from a probe and a derivation from source disagreed, and the
derivation was right.

## The controls ran out of slots, for the third item running

D6 moved the runtime vacuity controls from `on_budget_plan` to `on_pre_step` because narrowing the
first made a performing body unwritable there. **D8 narrowed `on_pre_step` and a top-level control
reading `Env` stopped compiling for the identical reason.** There is no third slot with a wide
unconditional row.

**What keeps them alive is the limitation rather than a slot.** They are now bound inline in
record-field position — *the same form the subjects use*, which is what S16 asks of an instrument —
with the builders declaring `! {Env}` and `! {FS}` because the leak reaches them. Passing the hook in
as a parameter does not work: argument position **is** checked.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 / 17 of 243.** Run **twice**, once
  after the narrowings and once after the documentation edits (S18), **identical member for member**
  and identical to D7's expected set: 7 `TC_ARITY_001` smoke scripts, `probe_phase_vocab_sealed`,
  5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage fixture.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, nothing else.** Both
  pre-existing since B2a. Exactly two target `Error` lines plus the top-level `Error 2`.
- **881 ✓ rows against D7's 870. The +11 was CHECKED, not assumed**: `declared_vs_performed` 26 → 37,
  and no other target's count moved.
- **`declared_vs_performed` 37/0, `hook_guard` 4/0, `driver_only` 6/6, `profile_definition` green with
  barrier count 3** (printed twice per `make dst`, as at D7).
- **Corpus artifact unchanged**, read from `/tmp/corpus_pr.out` per S19 (deleted before the run): the
  unreachable register EMPTY, `declared ⊆ observed` and `observed ⊆ declared`, both budget mutants
  fire, 13 affordable at 381 ms/seed against a minimum of 12 — identical to D6 and D7.
- **`git diff ailang.toml` empty — C5's duplicate-dependency trap checked, did not fire.**
- **`.packages/` staleness recurred for the THIRD consecutive item.** Still not a gate.

### The eleven new gate rows, and every one is falsifiable

- the **two narrowed rows**, each asserted at the width measured from bodies;
- a **derived stale-site row** over both slots, which is what found the three missed sites;
- the **two LIMITATION rows**, plus a **two-sided control** proving the record-field acceptance is
  caused by the *position* rather than by the checker being absent or the probe malformed. **They go
  RED if the limitation is FIXED upstream**, because that is the day these controls must be re-sited;
- **four absorption rows** with the denominator asserted separately, because rows and extensions
  differ;
- **`compaction_ai`'s total-absorption registration**, named rather than counted.

**D7's `on_pre_step` slot-row pin went RED on the narrowing rather than accepting it** — *"a change of
width is a change of claim and must be re-measured, not inherited"*. It was re-measured; the pin
follows the measurement.

## Sites where two answers type-checked and one was silently wrong: **3** (base 59 → **62**)

The handoff said to look first and hardest at anything reading a declared row as evidence of
behaviour. **All three are that.**

1. **THE TREE-WIDE GREEN THAT MEANT NOTHING.** Narrowing all seventeen `ai_step` sites to `! {}` left
   every one of the 31 subject files green **including `session.ail`**, whose bridge closure calls a
   helper still at ten effects. **The handoff's own four-minute probe is this reading** — consistent
   with the true answer, and not evidence for it.
2. **AN ANNOTATION REJECTION READ AS A BODY VERDICT** — D7's site 1, recurring inside the item warned
   about it. Settled by narrowing the ABI field too, so the annotations agree and the body is the only
   remaining producer.
3. **A SINGLE PROBE GENERALISED IN THE PERMISSIVE DIRECTION.** From one `let`-bound lambda at `! {}` I
   concluded "a lambda's row is never checked" — false in three of four positions, and wrong in the
   direction that would have voided D6's and D7's work entirely.

**Not counted, and said so rather than inflating the number:** the `[^\n]` in a grep ERE (a bracket
set excluding literal `n`, which stopped matching at `ExtensionHooks`); a `set -euo pipefail`
assignment whose failing grep killed the script; an absorption denominator counted over extensions
where the grep counts rows. **All three were LOUD.**

## Corrections owed to the plan — written into it

1. **This item has a plan entry.** D7 said D5's and D6's were still owed; **they are not** — both
   exist, and D7 corrected itself on that point. Four consecutive items now have entries.
2. **S16 extended: an instrument must exercise the subject in the FORM the subject is written in.**
   C5's version was about shared producers; D6's about a producer's reach; this one is positional.
   *A control in the wrong syntactic form is green for exactly the reason a control in the wrong
   process was.*
3. **S1 corollary: a compiler guarantee is a claim about a language, falsifiable the same way a count
   is.** Three items banked "the compiler now enforces X" from one demonstration in one form.
   *Probe every syntactic position the subjects use, and assert the fraction.*
4. **S22 extended: a derived set needs its own falsifier — an assertion that the residue is EMPTY —
   not just a derivation.** D8 derived correctly and was still wrong by three; the residue row is what
   caught them.
5. **`.packages/` staleness, third item running.** Worth a gate.

## Out of scope, still owed

- **WI-C5**, the `compose`-bearing profile — the next and last unbuilt item. Still three barriers.
- **Route B for the other two slots** — untouched, as required. `compose`'s inline path genuinely
  spawns the compiler and writes files; `context_mode.finalize_with_index` genuinely spawns a `node`
  bridge. **No narrowing reaches those.**
- **The fourteen `register_with_config` rows** — new, and now the sharpest un-owned item, because it
  is where enforcement for inline hook bindings actually lives.
- **Filing the record-field lambda gap upstream** — measured with a minimal four-position repro,
  **not filed**; offered to the user at hand-back.
- **The `motoko-ext-abi` major and lockstep re-release** — eight changed rows now.
- `test_coverage` / `test_coverage_selftest`, red since B2a and untouched.

## DID COVERAGE MOVE? **NO.**

`driver_only` installs nothing and covers nothing. **Extension-model coverage is ZERO.** Eleven of
eleven rows hold, four still lean on the empty install list, and the acceptance table was not re-run
because nothing here changes a row's answer.

**S21 re-asked: the count is still four, and nothing concentrated or withdrew** — no row closed, so no
reason was removed. That is the rule returning "no change" honestly rather than finding nothing.

**D7 measured three barriers and removed none. D8 measured the port underneath one of them, found it
over-declared by seven, narrowed two rows — and removed none.** The empty install list is **FORCED**,
exactly as at D5, D6 and D7. What is new is that the row is no longer evidence against mediation, and
that **a declared row is a weaker instrument than three consecutive items have treated it as.**
