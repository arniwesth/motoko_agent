# Handoff: WI-D7 — the three remaining barriers, and a correction to what D6 delivered

Audience: a fresh session grounded against HEAD. Source-heavy ABI and measurement work.

**Read first:** `NOTE-d6-unblock-the-install-on-budget-plan.md` — its measurement table and its
`register_with_config` confound are your method. Then `src/core/dst_driver_only.ail`'s
`omitted_extensions` reason, which is the most accurate statement of the current position anywhere in
the tree. Then the plan's `## Standing rules`; **S22 is new and this item is where it bites.**

**D6's source work was uncommitted at the time of writing** — 50 modified files including the ABI row
and 48 binding sites. **Confirm with `git status`.**

## The correction this item opens with

**D6's report and its design-document edit both say an extension is now installable. It is not, and
D6's own profile text says so.**

`on_budget_plan` was **one of four barriers**, not the only one. The other three are all
**unconditionally dispatched** — verified at review in `dst_profile_coverage.hook_dispatch`:

```
OnPreStep           => Unconditional     -- ext/runtime.ail:275
OnResponseIntercept => Unconditional     -- ext/runtime.ail:363
OnSolverCandidate   => Unconditional     -- ext/runtime.ail:414
OnToolHandle        => Gated             -- the only one
```

Under D5 an extension may not be installed with any unconditionally-dispatched hook excluded, so all
three must be **covered** — and none is:

| Slot | Declared row | Why it fails |
|---|---|---|
| `on_pre_step` | `! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Trace}` | criterion 1 fails on the row; criterion 2 fails because `IO`, `FS`, `Net`, `Process` are not world-mediated ports |
| `on_response_intercept` | nine effects | same, and it returns a constant beside `ctx.world` |
| `on_solver_candidate` | nine effects | same |

**`dst_driver_only.ail` states this correctly** — *"The three other former barriers stand and are
unaffected"* — so the two artifacts D6 wrote in the same item disagree, **and the profile is right.**
I corrected the design document at review; **the report's own summary and the plan entry still need
it, and this item should confirm the correction rather than inherit either version.**

**What D6 actually delivered is one barrier of four removed, and the argument that could remove the
others.** That is a real result and the item is not diminished by stating its size correctly.

## Mission

**Measure the three remaining unconditionally-dispatched slots, and narrow what can honestly be
narrowed.** This is D6's Route A pointed at the rest of the surface — D6 says so in as many words:
*"the same move is available to each, with its own measurement, none of which was taken here."*

## The rule you will break by accident

**Route A is NOT available for `on_response_intercept`, and C5 already measured why.**

`make declared_vs_performed` carries this row today:

```
must_die_on compose_intercept_inline FS
```

**Compose's `on_response_intercept` genuinely performs `FS` on the inline path** — same hook, same
declared row, different input. C5 built that row precisely so the non-inline green could not be read
as *"`on_response_intercept` performs no FS"*, which is false.

So for this slot the honest narrow row is not `! {}`. It is whatever the widest honest binding
performs — and a non-empty row still fails criterion 1. **That leaves criterion 2, which needs the
effects world-mediated**, i.e. **Route B**, which is the work C5's original scope called *"make the
effectful hooks world-mediated"* and which no item has done.

**`ResponseInterceptOutcome` and `FinalizeOutcome` already carry `next_state`**, so criterion 2's
successor conjunct is structurally satisfied for both. What is missing is the port-mediation of the
effects themselves.

**The three slots are therefore not one job:**

| Slot | Likely route | Why |
|---|---|---|
| `on_solver_candidate` | **A**, probably | bindings return constants; measure and see |
| `on_pre_step` | **A or B** — genuinely open | B4 argued it reaches effects through `ExtPorts.ai_step`, which is world-mediated, and returns `PreStepOutcome.next_state`; its *declared* row is what refuses it |
| `on_response_intercept` | **B** | compose performs `FS` on a measured path |

**Do not narrow all three to `! {}` because two of them measure clean.** The row is shared across
every binding, and C5's inline measurement is the counterexample that a single-arm sweep will miss.

## Method, inherited from D6 and not to be re-derived

**Per S22, derive the subject list from `registry_generated.ail` and assert the agreement** — D6's
gate already does, and my own handoff for D6 undercounted the population by six, which is why the
rule exists.

**Per D6's confound, every runtime subject is a PAIR** — `reg_<ext>` (registration only) and
`budget_<ext>`-style (registration then dispatch) — because nine of fifteen `register_with_config`
implementations read `Env` before any hook is dispatched, and the naive arm scores every one of those
as *"the hook performs `Env`"*, a false positive **in the direction that refuses the narrowing**.

**Per D6's third producer, the compiler is stronger than the trap here and only becomes available by
doing the work.** The capability trap witnesses 7 of 15; the effect checker covers 15 of 15 total over
inputs, once the row is a variable. **Report the fraction each producer reaches, per S16, rather than
the subset it happens to cover.**

## Definition of done

**Each of the three slots measured across every binding**, with its route decided and recorded — and
**for any slot where Route A is refused, the binding that refuses it named**, as C5 named
`compose_intercept_inline`.

**Whatever narrows, narrows; whatever does not, is reported with what would have to change.** Per S15
that reason records a **measurement**, not a diagnosis, and per D2 a structural reason names the thing
that would have to change rather than where the code lives.

**The install question answered plainly: is any extension installable at the end of this item?** If
not, say how many barriers remain and which. **D6's headline is the failure mode to avoid** — a real
result described as a larger one.

**D5's caveat and `driver_only`'s omission reason kept in agreement.** They disagreed after D6 and the
profile was right; whichever moves, both move.

**Per S21, re-ask the four leaning rows.** Removing a barrier did not close any of them at D6 and
probably will not here — but the rule is to ask, and D6's answer was that every reason *concentrated*.

**Per S13/S9/S17/S19** — sweep cache-cold with `AILANG_RELAX_MODULES=1`, failing set member-for-member;
run `make dst` in full; clear every live `.ailang/cache` and leave `~/.ailang/cache/registry` alone;
check no other session is running a gate; restore mutants by `cp`; read artifacts, not transcripts,
and **do not read `$?` after a pipe** — that is S19's fourth medium and D6 hit it.

## Out of scope

- **Installing anything.** A profile that installs an extension is WI-C5's `compose`-bearing profile,
  carries a coverage claim and a version bump, and is not a side effect of an ABI edit. **If this item
  makes an extension installable, stop and report it** — that is the trigger for C5, not for this.
- **Compose's eight unrouted clock reads** and `ExtPorts.proc_exec`/`env_get` widening — WI-C5's.
- **The `motoko-ext-abi` major and lockstep re-release.** Five changed rows now; this item may add
  more. **Say what the count stands at rather than cutting it.**
- The two sibling `st.world_state` finalize sites; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds;
  `test_coverage` and `test_coverage_selftest`, red since B2a.

## Stop and report rather than deciding inline

- **If a slot needs Route B**, report the design before building it. World-mediating a nine-effect
  hook is a port-surface change with D1 behind it, and it is larger than everything D6 did.
- **If narrowing a row makes an extension installable**, stop — see out of scope.
- **If the three slots turn out to need different rows from each other**, that is a shape finding
  about `ExtensionHooks` and worth reporting before editing.

## Report back

Thirty-first calibration run.

- **The git wall-clock window.**
- **The measurement table for all three slots**, every binding, with each producer's reach as a
  fraction. The item's durable output.
- **Which slots narrowed, which did not, and what each remaining one needs.**
- **How many barriers remain, stated as a number**, and whether any extension is installable.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **57 across thirty
  runs; determinism has caught none.** D6's two were both in its instrument; per S20 the place to look
  is anything reading a declared row as evidence of behaviour.
- **Whether the design document, the profile's omission reason, and your own report all say the same
  thing about installability.** D6's did not, and nothing went red.
