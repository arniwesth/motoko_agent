# WI-D7 — the three remaining barriers, measured. **NONE OF THEM FELL. THE COUNT IS STILL THREE.**

Thirty-first calibration run. Written against HEAD `b1cc558`, branch
`arniwesth/mot-68-wi-d6-unblock-the-install`.

## Window

**~45 minutes** wall-clock: `2026-08-06T10:26:46Z` → `2026-08-06T11:12:10Z`. Three runs dominate it:
`make dst` in full (`10:54:34Z` → `11:05:23Z`, **10m49s** — half D6's 21m19s, because the caches were
warm from the sweep that preceded it), and **two** cache-cold whole-tree sweeps at **3m22s** each,
one after the narrowings and one after the documentation edits.

**The measurement itself cost about ten minutes** — a baseline plus three slot passes plus three body
probes, eight apply/check/restore cycles in all, at ~41s per pass over the fifteen packages. **The
narrowing that followed cost about five.** That is D6's ratio repeated, and it is the item's cheapest
surprise for the second time running: **measuring the rows is most of the work and moving them is
nearly free.** The expensive half of this item was neither — it was reconciling **six** artifacts that
disagreed about what D6 had done, **two of them executable**, and finding the sixth only after the
first five had been made to agree.

## Grounding

**Clean at `b1cc558`.** The handoff warned that D6's source work was uncommitted — **it is not**. It
landed as `7677e24` "Implementation" (47 files) plus `b1cc558` "Added summary", and `git status` was
empty at start. Nothing was resolved silently and nothing had to be recovered.

**S9's concurrency check: no other session is running a gate.** The same idle
`src/core/supervisor.ail` agent session D5 and D6 both found — now **1d12h elapsed against 7m47s
CPU** — plus four days-old `make claude` shells and a `make run`. No gate, no `make dst`. Re-checked
before the sweep.

**Caches cleared before every measurement**, `~/.ailang/cache/registry` left alone and verified at 1
entry throughout. **Per S17 a full `tar` of `packages src scripts Makefile tools` was taken before
the first edit** and every mutant restored from it by extraction, never by `git checkout`. The
measurement below is a mutation loop with **eight** apply/restore cycles; the tar was the only copy
of the work underneath them.

**Per S19, `$?` was never read after a pipe.** `PIPESTATUS[0]` or a bare `$?` on an unpiped command
throughout — this is the rule's fourth medium and D6 hit it, so it was watched for deliberately.

## THE MEASUREMENT TABLE — three slots, every binding

**The item's durable output.** Subject list **derived from `registry_generated.ail`** per S22, which
this item then discovered was load-bearing in a second way (see below). Fifteen subjects, **71 `.ail`
files** across their packages, all green at baseline.

**Method.** Narrow the slot's row to nothing *tree-wide*, then re-check all 71 files. That makes the
**effect checker** the producer — total over all inputs, where the capability trap is a witness over
the one path an arm exercises. Then, for each refusal, narrow the *refusing helper's own* row and
read the effect checker again, so the verdict comes from the **body** rather than from a comparison
of two annotations.

| Slot | Bindings accepting `! {}` | Refused by | Effects, named by the compiler | Route A |
|---|---|---|---|---|
| `on_pre_step` | **14 / 15** | `compaction_ai` | `AI Clock Env FS IO Net Process SharedMem Stream Trace` | **REFUSED** |
| `on_response_intercept` | **14 / 15** | `compose` | `Clock FS IO Process` | **REFUSED** |
| `on_solver_candidate` | **14 / 15** | `context_mode` | `Process` | **REFUSED** |

The compiler's exact words, one per slot:

```
register.ail:93   on_pre_step:           extra labels [AI Clock Env FS IO Net Process SharedMem Stream Trace]
compose.ail:816   on_response_intercept: extra labels [Clock FS IO Process]
register.ail:56   on_solver_candidate:   extra labels [Process]
```

and the second producer, from the bodies rather than the annotations:

```
Effect checking failed for function 'fresh_compaction'        (compaction_ai)
Effect checking failed for function 'on_response_intercept'   (compose)
Effect checking failed for function 'finalize_with_index'     (context_mode)
```

### Producer reach, as a fraction, per S16

| Producer | Reach on this question |
|---|---|
| DECLARED — the annotation, grepped from source | **15/15** |
| PERFORMED (runtime capability trap) | **0/15** — see below |
| PERFORMED (effect checker, over the body) | **15/15**, total over inputs |

**The runtime trap reaches NONE of these three slots, and that is the fraction rather than the
subset.** D6's per-process capability confound applies unchanged and harder: nine of fifteen
`register_with_config` implementations read `Env` before any hook is dispatched, and for these slots
there is no regime that recovers the rest, because the effects at stake (`Process`, `FS`, `IO`,
`Clock`) are the same ones registration performs. **So for D7 the compiler is not the third producer,
it is the only one**, and the gate's new rows say so rather than implying a witness they do not have.
D6's rule — *ask what fraction of the new subject set your producer can reach* — returns **zero**
here, which is exactly the answer it was written to make visible.

## The route, and it is the same answer three times

**ROUTE A IS REFUSED FOR ALL THREE SLOTS.** The handoff predicted `A, probably` for
`on_solver_candidate`, `A or B — genuinely open` for `on_pre_step`, and `B` for
`on_response_intercept`. **It was right once.**

### `on_solver_candidate` — the prediction that was wrong, and why it was reasonable

The handoff said *"bindings return constants; measure and see"*. **Twelve of the fifteen do.**
`context_mode`'s does not:

```ail
export func finalize_with_index(cfg, ctx, candidate) -> FinalizeDecision ! {Process} {
  ...
  let _ = run_context_mode_fire_and_forget("node", bridge_args_for(...), ctx.cwd, cfg.timeout_ms);
  NoDecision
}
```

It spawns a `node` bridge fire-and-forget to index the final output. **A real subprocess, on the
default path, not a fixture.** Reading twelve bindings and generalising is precisely the shape S22
exists to refuse — and this time the undercount was not of *subjects* but of *barriers*.

### `on_response_intercept` — the one C5 already knew about

`must_die_on compose_intercept_inline FS` has been in the gate since C5 for exactly this reason, and
the handoff was right to flag it. **The compiler is more specific than the runtime witness was**: the
inline path performs `Clock, FS, IO, Process` — `now()` for the snippet name, `mkdirAll`/`writeFile`/
`removeFile` for the scratch module, and `check_snippet`/`run_snippet` spawning the compiler. C5's
row named one effect; the effect checker names four.

### `on_pre_step` — the sharpest result, and it is a SHAPE finding

`compaction_ai` reaches **all ten** of its effects through a **single call**: `ctx.ports.ai_step`,
whose own port row is exactly those ten. So the slot's row is a consequence of the **port's** row,
and narrowing it is a port-surface change rather than a hook-row change — WI-C5/D1 work, deliberately
not done here.

**But `ai_step` IS a D1 world-mediated port.** B2b widened it to return `AiStepOutcome` with
`next_state`; `PreStepOutcome` carries `next_state`; and `compact_with_ai` returns `s.next_state`
rather than `ctx.world`. **Criterion 2's substance is already satisfied by the only binding that
performs anything.** What refuses the slot is that criterion 2 is evaluated against the DECLARED row,
and **a declared row has no vocabulary for saying that an effect arrives through a world-mediated
port.**

**THE BARRIER THERE IS THE ROW'S VOCABULARY — NOT THE BEHAVIOUR, AND NOT THE ROW'S WIDTH.** No amount
of narrowing reaches it. It needs a port-surface change or a criterion that can read mediation. B4
argued this; it is now measured rather than argued.

## What narrowed, and why it removes nothing

| Slot | Before | After | Barrier? |
|---|---|---|---|
| `on_pre_step` | ten effects | **ten effects — unchanged** | **YES** |
| `on_response_intercept` | nine effects | **`! {IO, Process, FS, Clock}`** | **YES** |
| `on_solver_candidate` | nine effects | **`! {Process}`** | **YES** |

**NEITHER NARROWING REMOVES A BARRIER, AND SAYING SO IS THE POINT OF THIS ITEM.** A non-empty row
fails D5 criterion 1 at four effects exactly as it did at nine. None of `Process`, `FS`, `IO`,
`Clock` is a world-mediated port, so criterion 2 fails too, even though both outcome records already
carry `next_state`.

**What the narrowings buy is the compiler.** A binding that starts reading `Env` in either slot now
**fails to build** — verified two-sided in the gate, rejected under the narrowed row and accepted
under a widened one. At nine effects it would have compiled silently. That is the same prize D6 took
on `on_budget_plan`, bought here without a coverage claim attached.

**Cascade: three lines, and the compiler found them.** `decide_one_finalize`,
`collect_finalize_decisions` and `dispatch_solver_candidate` hold `! {Process, IO, Clock}` — wider
than the slot, and the extra `{IO, Clock}` is the **host's**, through `emit_dummy_hook`'s
test-instrumentation `println` and timestamp. Recorded at the site, because a reader comparing the
dispatcher's row against the ABI's would otherwise read the difference as staleness.

## THE INSTALL QUESTION, ANSWERED PLAINLY

> **THREE BARRIERS REMAIN: `on_pre_step`, `on_response_intercept`, `on_solver_candidate`.**
> **NO EXTENSION IS INSTALLABLE IN A CONFORMANT PROFILE.**

The handoff's stop-and-report condition never triggered, because nothing became installable. No
profile was changed to install anything.

**And the count is no longer prose.** `make profile_definition` now **derives** it on every run from
the ABI rows and `dst_profile_coverage.hook_dispatch` — two producers, neither derived from the other
— and prints it as a number:

```
✓ barrier count DERIVED from the ABI rows and the dispatch table: 3
    BARRIER  on_pre_step: unconditionally dispatched, declares ! {IO, Process, FS, AI, Env, ...}
    BARRIER  on_response_intercept: unconditionally dispatched, declares ! {IO, Process, FS, Clock}
    BARRIER  on_solver_candidate: unconditionally dispatched, declares ! {Process}
    coverable on_budget_plan: unconditionally dispatched, declares NO row
    gated     on_tool_handle: excludable, so not a barrier
  → 3 barrier(s) stand, so NO extension is installable in a conformant profile
```

**It goes RED at zero**, verified two-sided: driving all three rows empty gives
`FAIL: the barrier count has reached ZERO … That is WI-C5's trigger and it must be DECIDED, not
inherited as a side effect of an ABI edit`, exit 1; restored, exit 0. **This replaces a line that was
false.** Through D6 the same script printed, on every run:

> `→ the slot is coverable under D5 criterion 1, so an extension IS installable`

which does not follow from one slot of four. **That is D5 planning defect 4 — "the caveat needs to be
a checked artifact, not prose" — discharged for this specific claim.**

## The disagreement D6 left, and it was in THREE artifacts, not two

The handoff said D6's report and its design-document edit disagreed with `dst_driver_only.ail`, and
that the profile was right. **The profile was right in its `omitted_extensions` reason and wrong in
its own header, thirty lines apart, both written by D6 on the same day.**

| Artifact | Said |
|---|---|
| `dst_driver_only.ail` `omitted_extensions` | *"The three other former barriers stand and are unaffected"* — **correct** |
| `dst_driver_only.ail` header | *"the empty install list below is now CHOSEN rather than FORCED"* — **wrong** |
| `tools/profile_definition/check_fixtures.py` | *"so an extension IS installable"*, **printed on every run** — wrong |
| `src/core/dst_fault_catalogue.ail` | *"so an extension IS now installable"* — wrong |
| `src/core/dst_hook_guard.ail` | *"an extension IS now installable in a conformant profile"* — wrong |
| `scripts/dst/hook_guard_dst.ail` | *"so an extension IS now installable"*, **`println`'d on every run** — wrong |
| the plan | corrected at review, before this item started |

**Six source-side statements, five of them wrong, TWO of them executable.** All six now agree, and
the reason they could disagree indefinitely is that **no artifact computed the count** — each passage
reasoned locally about the slot in front of it and every one of them was locally sound.

**`NOTE-d6-…md` WAS NOT EDITED, AND THAT IS DELIBERATE.** Its summary still says an extension is
installable. The plan's correction, applied at review before this item began, ruled that the report
**stands as written per S15** because it is a historical record of what D6 concluded, not a live
claim about the tree. **This item did not re-open that.** The distinction is the one S15 exists for:
a record of a past conclusion and a current assertion are indistinguishable by inspection, so the
current assertions were all moved and the record was left dated. **A reader who finds D6's report
first will still be misled** — which is why the count is now a checked artifact, and why this note
exists beside it.

**`driver_only` v11 → v12.** Same kind of bump as v10 → v11: a **claim** changed, no anchor moved.
Install list, coverage claim, waived set, hook classifications, catalogue and attribution ref are all
unchanged. **v12 installs exactly what v11 installed, which is nothing.**

## S21, re-asked. **The count is still four — and TWO OF D6'S CONCENTRATIONS ARE WITHDRAWN.**

D6 reported that removing a barrier **concentrated** the reasons three surviving exemptions rest on.
**Those concentrations rested on the wrong installability conclusion and did not happen.**

| Row | D6 said | D7 says |
|---|---|---|
| 3 | Vacuous on an install list this profile **chooses** not to fill | **WITHDRAWN.** Still an install list no profile *can* fill. Unchanged from D5 |
| 4 | `extension_effect_fault` waived; rested on two reasons, **now one** | **WITHDRAWN.** Still two: the profile installs nothing **and** nothing is installable |
| 5 | Compose's clock reads **now actionable**: "compose is installable" | **WITHDRAWN.** Compose is not installable. Unchanged from D5 |
| 7 | `ScratchpadResult` needs a hook returning `Handled` with a `cells` key | **Unchanged**, and D6 did not claim otherwise |

**A fifth site, outside the acceptance table:** `dst_hook_guard`'s unreachability. D6 recorded it as
concentrating from two reasons to one. **It still rests on two**, and the site now says so.

**So S21's answer this item is not "a reason concentrated" but "a reported concentration was
withdrawn".** That is a new failure mode for the rule and worth naming: **a concentration is a claim
about what a closure removed, so a closure that did not happen produces a concentration that did not
happen** — and it propagates into every reason the closing item touched. D6 recorded three of them in
three different files, each locally consistent, all downstream of one wrong sentence.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243 files.** Run
  **twice** — once after the narrowings, once after the documentation edits — and the failing set is
  **identical member for member** across both and to D6's expected seventeen: 7 `TC_ARITY_001` smoke
  scripts, `probe_phase_vocab_sealed`, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage
  fixture. Stable across B4, C1, C3, C5, C4, D3, D4, D5, D6 and now D7. **The second sweep is the one
  that matters**: S18 says tensing a comment is a source edit, and this item rewrote a great deal of
  commentary after the code was green.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Both pre-existing since B2a. `make --keep-going` emitted exactly **two** target `Error` lines
  (`Makefile:2022` and `Makefile:2019`) plus the top-level `Error 2`.
- **870 ✓ rows against D6's 857.** Same methodology (`grep -c '✓'` over the transcript). **The +13 is
  fully attributable and was checked rather than assumed**: `declared_vs_performed` contributes 33
  rows where it contributed 22 (**+11**), and the barrier-count row contributes **+2**, because
  `check_fixtures.py` runs twice in a `make dst` — once for `profile_definition` and once for
  `driver_only`. 11 + 2 = 13. **No other target's row count moved.**
- **`declared_vs_performed`: 26 passed, 0 failed** (D6: 15). **`hook_guard`: 4 passed, 0 failed.**
  **`driver_only`: 6/6.**
- **Every other target green**, including all eleven rows' producers: `world_state`,
  `profile_coverage`, `profile_definition`, `driver_only`, `fault_catalogue`, `event_vocabulary`,
  `invariants`, `run_report`, `latency_pair`, `corpus_pr`, `corpus_rotating`, `attribution_table`,
  `execution_program`, `discovery`, `strict_replay`, `seeded_generator`, `program_persistence`,
  `predicate_anchors`, `recorded_stream`, `stream_parity`, `ledger_parity`, `smoke_driver`,
  `smoke_parity`.
- **The corpus artifact is unchanged**, read from `/tmp/corpus_pr.out` per S19 (deleted before the
  run, so it was written by this item's own `make dst`): the unreachable register is EMPTY,
  `declared ⊆ observed` **and** `observed ⊆ declared`, 15 ≥ 12 seeds, both budget mutants fire, and
  the same thin margin D5 flagged — **13 affordable at 381 ms/seed against a minimum of 12**,
  identical to D6.

### The new gate rows, and every one is falsifiable

`make declared_vs_performed` gained **eleven** rows, each mutation-tested rather than merely written:

- the **three slot rows**, asserted at the widths D7 measured. Re-widening `on_solver_candidate` back
  to nine turns **two** rows red and takes the target to **exit 2**; restored, exit 0.
- the **three refusing bindings**, read from *their own* declarations rather than from the slot rows
  — a second producer for the same fact, neither derived from the other.
- **no binding site left at the pre-D7 nine-effect row**, scoped to the two return types.
- **two two-sided compile-time controls**, one per narrowed slot: the mutant is rejected with
  `Effect checking failed for function 'mutant_hook'` under the narrowed row **and accepted** under a
  widened one, so the rejection is attributable to the row rather than to anything else in the file.

And `make profile_definition` gained the **barrier count**, which is the row that would have caught
D6's disagreement.

## The owed `motoko-ext-abi` major

**Seven changed rows now, and this item changed the sixth and seventh.** B1/B2a/B2b/C5 changed four
(`ExtPorts.ai_step`, `on_pre_step`, the four outcome records, `ExtPorts.clock_now` +
`ExtClockReading`); **D6 changed `ExtensionHooks.on_budget_plan`; D7 changes
`ExtensionHooks.on_response_intercept` and `ExtensionHooks.on_solver_candidate`.**

**This item did NOT cut the major**, for D6's reason unchanged: cutting it is a release act — a
lockstep re-release of every package in `ailang.toml`'s `[extensions]` — which is neither in this
item's scope nor decidable by it. `ailang lock` re-recorded the interface hashes as part of the
normal build (**19 entries moved**, same as D6). **C5's trap was checked and did not fire**:
`git diff ailang.toml` is empty, so no duplicate dependency key was appended.

**The count now stands at seven changed rows and one added type, with the lock file moved five
times.** Stated rather than cut.

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **ALL THREE SLOTS REFUSE ROUTE A, AND EACH IS REFUSED BY EXACTLY ONE BINDING OF FIFTEEN.** The
   handoff predicted Route A for one of them and "genuinely open" for another. The measurement is the
   same shape three times: 14/15 clean, 1/15 refusing, the refuser named by the compiler.
2. **`context_mode.finalize_with_index` SPAWNS A SUBPROCESS IN `on_solver_candidate`.** No document in
   this project names it. Twelve of the fifteen bindings in that slot are constants, which is how
   both the handoff and the plan came to say all of them were.
3. **THE RUNTIME CAPABILITY TRAP REACHES ZERO OF FIFTEEN ON THESE SLOTS.** Not a reduced fraction —
   zero. The effects at stake are the same ones `register_with_config` performs, so no regime
   separates them. The compiler is the only producer available, and the gate says so.
4. **`on_pre_step`'S BARRIER IS THE ROW'S VOCABULARY.** Its one performing binding reaches every
   effect through a world-mediated port and returns explicit successor state — criterion 2's
   substance, satisfied — and is refused because the declared row cannot express mediation.
5. **A COMPILER REJECTION ON A RECORD FIELD COMPARES TWO ANNOTATIONS, NOT A BODY AND A ROW.** The
   first measurement pass read `extra labels [...]` as "the binding performs these". It does not: it
   means the binding's *annotation* says so. Settled by narrowing each refusing helper's own row and
   re-reading. **Counted below as a silently-wrong site.**
6. **`driver_only.ail` DISAGREED WITH ITSELF**, header against `omitted_extensions`, thirty lines
   apart, same item, same day.
7. **TWO LIVE GATES WERE PRINTING THE FALSE CLAIM.** `check_fixtures.py` asserted installability in
   `print()` and `hook_guard_dst.ail` in `println` — on every run since D6. **Prose in a script is
   still prose.** The second was found only by grepping for the claim's *wording* across all of
   `src/ tools/ scripts/ packages/` after the first five artifacts had been reconciled, which is the
   only reason it did not survive this item too.
8. **`make hook_guard`'s DISCLOSURE BLOCK IS FILTERED OUT OF ITS OWN OUTPUT.** The recipe pipes
   through `grep -v 'STRICT_FALLBACK\|^  '`, and every line of the synthetic-fixture disclosure is
   indented two spaces. **So the false claim was never actually displayed by the target that carries
   it** — it printed only when the script was run directly. That is S19's shape once more, inverted:
   the rule is about a check that vanishes from a gate's output, and here it is a *disclosure* that
   vanishes. A disclosure nobody can see is not a disclosure, and a gate that filters its own
   caveats will filter a real one the same way.
9. **THE CASCADE WAS THREE LINES**, and the extra `{IO, Clock}` on all three is the host's own
   `emit_dummy_hook`, not any extension's.

**Decided — a human chose:**

1. **Narrow the two slots that CAN narrow, even though neither narrowing removes a barrier.** The
   alternative — leave rows at widths no binding needs because narrowing changes no status — forfeits
   the compiler as an enforcer, which is the one thing D6 established these narrowings are for.
2. **Do NOT narrow `on_pre_step`**, and record the port-surface reason rather than the row.
3. **The barrier count is a DERIVED, CHECKED ARTIFACT** that goes red at zero, rather than a sentence
   any item can restate. This is the mechanism that would have caught D6's disagreement.
4. **Every new gate row is two-sided**, per D6's lesson about controls that die for the wrong reason.
5. **The stale-row grep is scoped to the two RETURN TYPES**, after its first version matched the
   conformance harness's scenario *runners* — hook callers, not hook bindings, whose nine-effect row
   is honest because `on_pre_step` did not narrow.
6. **`driver_only` v12**, described as a claim change rather than a re-measurement.
7. **D6's three recorded S21 concentrations are WITHDRAWN rather than re-dated**, because they were
   never true, and S15's "kept in the past tense" applies to claims that *were* true.
8. **The ABI major is not cut here**, and the count is stated at seven.
9. **Nothing was installed.**

## Sites where two answers type-checked and one was silently wrong: **2**

**Base 57 from D6's report. This run makes it 59. Determinism has still caught none.**

1. **A CLOSED-ROW REJECTION READ AS A STATEMENT ABOUT BEHAVIOUR.** Narrowing a slot row and reading
   `incompatible closed rows: r1 has extra labels [Clock FS IO Process]` looks exactly like the
   effect checker reporting what a body performs. **It is not** — it is two *annotations* failing to
   unify, and an over-wide annotation on an effect-free body produces a byte-identical message. Had
   the three refusing helpers been merely over-annotated, this item would have reported three
   barriers that were not there and left two narrowings untaken. Both readings are consistent with
   the exit status and with the message; the distinguishing evidence is a *second* narrowing, of the
   helper's own row, which produces `Effect checking failed for function '<name>'` instead.
   **Per the handoff's S20 pointer, the place to look was anything reading a DECLARED row as evidence
   of behaviour — and this is that, in the instrument built to escape exactly that mistake.**
2. **AN INSTRUMENT EXCERPT ATTRIBUTING A FAILURE TO THE WRONG CAUSE.** The check harness printed the
   first three non-filtered lines of `ailang check`, and for `compaction_ai` those are a **VER001
   toolchain-skew warning** — that package's own `ailang.lock` is at v0.26.0 against a v0.33.0
   binary. The real error was four lines further down. A reader of that row would conclude
   `compaction_ai` fails for skew and that the slot is therefore unmeasured, which is the answer that
   *stops* the investigation. Same species as D6's site 2, one level up: not a control dying for the
   wrong reason, but a report *naming* the wrong reason for a correct verdict.

**Not counted, and said so rather than inflating the number:** the greedy `->` match that read
`on_pre_step` as declaring no row, `grep` reading `->` as an option, and the stale-row grep matching
hook callers. All three are real defects from this run and all three were **LOUD** — each turned a
gate row red on its first execution. The counter tracks answers that are *silently* wrong.

## Corrections owed to the plan

1. **THE PLAN NOW HAS A D7 ENTRY, AND THE STANDING DEFECT IS DISCHARGED FOR THIS ITEM ONLY.** C4's
   planning defect 1 stood through D1–D6: six consecutive items with no plan entry. **This item wrote
   one.** D5's and D6's are still owed, and **WI-C5 remains the only unbuilt work item in the plan and
   the next one.**
2. **A BARRIER COUNT IS A COMPLETENESS CLAIM AND IT WAS WRONG BY THREE.** S22 was earned against a
   *subject* count; this item found the identical failure one level up, in a *barrier* count, in the
   item that wrote S22. *Suggested extension to S22: when an item's conclusion is "X is now
   unblocked", derive the list of things that block X from a producer and assert the count, not just
   the list of things you changed.* D6 derived its subject list correctly and then took its barrier
   count from prose.
3. **A REPORTED CONCENTRATION IS A CLAIM ABOUT A CLOSURE, AND A CLOSURE THAT DID NOT HAPPEN PRODUCES
   CONCENTRATIONS THAT DID NOT HAPPEN.** S21 asks each surviving exemption why it survives. D6 asked,
   answered "the reason concentrated" in three files, and all three were downstream of one wrong
   sentence. *Suggested extension to S21: when an item reports a concentration, the reason it says
   was REMOVED must be checked as an artifact, not asserted — a concentration is falsifiable and
   nothing was falsifying these.*
4. **THE COMPILER IS NOW THE ONLY PRODUCER FOR THIS QUESTION, NOT THE STRONGEST ONE.** D6's rule
   ("ask what fraction of the new subject set your producer can reach") returns **zero** for the
   runtime trap on all three of these slots. That is the rule working, and it means the gate's
   claims here rest on a single producer by necessity rather than by choice — recorded because S16's
   independence requirement cannot be met for these rows and a reader deserves to know which rows
   those are.
5. **`.packages/` STALENESS RECURS.** `make sync_packages` was needed again before the gate would
   read source-consistent state, exactly as D6 found. It is a two-command fix and it has now bitten
   two consecutive items; it is worth a gate of its own rather than a step each item remembers.

## Out of scope, unchanged and still owed

- **WI-C5, the `compose`-bearing profile** — the next item and the last unbuilt one in the plan. It
  is now a *larger* item than D6 left it: it must clear **three** barriers, not zero, and at least
  one of them (`on_pre_step`) needs a port-surface change or a criterion that can read world
  mediation.
- **Route B for the three slots** — world-mediating `Process`, `FS`, `IO` and `Clock` on the
  extension surface. **Reported, not built**, per the handoff's stop-and-report condition. It is a
  port-surface change with D1 behind it and it is larger than everything D6 and D7 did together.
- **The `motoko-ext-abi` major and lockstep re-release** — seven changed rows now.
- **Compose's eight unrouted clock reads**, `ExtPorts.proc_exec`/`env_get` widening — WI-C5's.
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.

## DID COVERAGE MOVE? **NO. AND UNLIKE AT D6, NOTHING EVEN LOOKS LIKE IT DID.**

`driver_only` installs nothing. It covers nothing. **The axis's extension-model coverage is ZERO and
nothing about the extension model has been tested by this gate.** Eleven of eleven rows still hold,
four of them still lean on the empty install list, and the acceptance table was not re-run because
nothing here changes a row's answer.

**D6 removed one barrier of four and reported it as unblocking the install. D7 measured the other
three, narrowed two rows that needed narrowing, and removed none.** The empty install list is
**FORCED**, exactly as it was at D5 — and the difference between this item and D6 is not the result
but the fact that **the count is now something the tree computes rather than something a report
asserts.**
