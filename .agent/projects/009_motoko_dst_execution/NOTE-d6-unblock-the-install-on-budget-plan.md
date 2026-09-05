# WI-D6 — the install is unblocked. **ROUTE A. The row is narrowed. COVERAGE DID NOT MOVE.**

Thirtieth calibration run. Written against HEAD `596299f`, branch
`arniwesth/mot-67-wi-d4-restore-the-three-targets-d3-reddened`.

## Window

**~66 minutes** wall-clock: `2026-08-06T07:40Z` → `2026-08-06T08:46Z`. Two measurements dominate it:
`make dst` in full (`08:23:08Z` → `08:44:27Z`, 21m19s) and the cache-cold sweep (`08:19:25Z` →
`08:22:45Z`, 3m20s). The measurement table itself cost about twelve minutes; **the narrowing cost
about four**, which is the item's cheapest surprise and the one the handoff predicted.

## Grounding

**Clean at `596299f`**, one commit past the handoff's `9f10bf2` (`596299f` "Added summary" adds only
`.agent/summaries/2026-08-06-cluster-29-…`). Nothing was resolved silently.

**S9's concurrency check: no other session is running a gate.** One live `ailang` process, the same
idle `src/core/supervisor.ail` agent session D5 found — now 1d09h elapsed against 7m33s CPU, holding
no `.ailang/cache` or `/tmp/*.out` descriptors. Four `make claude` shells are days old. Re-checked
immediately before the sweep.

**Caches cleared twice** (before the sweep and before `make dst`), `~/.ailang/cache/registry` left
alone and verified intact at 1 entry. `/tmp/corpus_pr.out`, `/tmp/latency_pair.out`,
`/tmp/corpus_rot.out`, `/tmp/corpus_job.out` deleted before the run, so every artifact read below was
written by this item's own `make dst`. **Per S19 the class-coverage rows are read from
`/tmp/corpus_pr.out` itself.** **Per S17 every mutant was saved and restored by `cp`** — a full
`tar` of `packages src scripts Makefile` was taken before the first edit and four individual file
copies beside it.

## THE MEASUREMENT TABLE — every binding, declared against performed

**The item's durable output, and the first time this slot has been measured beyond compose.** Taken
**before** anything was narrowed, so every row describes the tree as WI-D5 left it.

**FIRST CORRECTION, AND IT IS THE HANDOFF'S OWN COUNT.** The handoff names eight extensions besides
compose. **There are fourteen.** The six it does not name are `mcp`, `context_mode`, `ailang_docs`,
`decision_framework`, `compaction_structural` and `empty_stop_guard`. The list is not a matter of
judgement — `src/core/ext/registry_generated.ail` is the host's own install set, and the gate now
derives the subject list from it and compares member for member, so the next extension added cannot
escape measurement by not being noticed.

| # | Extension | DECLARED (source) | PERFORMED (runtime trap) | PERFORMED (effect checker) |
|---|---|---|---|---|
| 1 | `compose` | `! {Env, FS}` | **`! {}`** — witnessed (literal-config arm, C5's) | `! {}` |
| 2 | `test_dummy` | `! {Env, FS}` | **`! {}`** — witnessed (regime B) | `! {}` |
| 3 | `scratchpad` | `! {Env, FS}` | **`! {}`** — witnessed (regime B) | `! {}` |
| 4 | `decision_framework` | `! {Env, FS}` | **`! {}`** — witnessed (regime A) | `! {}` |
| 5 | `microrag` | `! {Env, FS}` | **`! {}`** — witnessed (regime A) | `! {}` |
| 6 | `compaction_structural` | `! {Env, FS}` | **`! {}`** — witnessed (regime A) | `! {}` |
| 7 | `empty_stop_guard` | `! {Env, FS}` | **`! {}`** — witnessed (regime A) | `! {}` |
| 8 | `progress_contract_guard` | `! {Env, FS}` | **`! {}`** — witnessed (regime A) | `! {}` |
| 9 | `omnigraph` | `! {Env, FS}` | CONFOUNDED — registration reads `Env`, then `FS` | `! {}` |
| 10 | `context_mode` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |
| 11 | `mcp` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |
| 12 | `exa_search` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |
| 13 | `ailang_docs` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |
| 14 | `a2a` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |
| 15 | `compaction_ai` | `! {Env, FS}` | CONFOUNDED — same | `! {}` |

**ZERO BLOCKING. Not one dispatch, in either regime, died on `Env` or `FS`.** The one answer that
would have refused Route A did not appear.

### The confound, which is the measurement's real finding

**`register_with_config` is not effect-free for most of these packages.** Nine of fifteen read `Env`
at registration — a `getEnvOr` for `MOTOKO_WORKDIR` or `MOTOKO_PROFILE_DIR` — and seven of those
also read `FS`, a config file or a portability gate probing for a marker. **Those reads happen
before any hook is dispatched.**

**So the naive arm — install, dispatch, capability withheld — dies for nine of fifteen subjects, and
every one of those deaths reads as "the hook performs Env".** That is a false positive **in the
direction that blocks the narrowing**, and nothing in the exit status distinguishes it from the real
thing. Measured before the arms were written, which is why the arms come in pairs:

```
reg_<ext>     registration only, no dispatch
budget_<ext>  the same registration, then the dispatch
```

and the runner reads the **pair**, not either arm. `reg` completes and `budget` completes → the hook
performs neither. `reg` completes and `budget` dies → the hook performs it. `reg` dies → registration
got there first and this instrument cannot settle it.

**Regime B recovers two more.** With `Env` granted and `FS` withheld, `test_dummy` and `scratchpad`
become measurable — their registrations read `Env` but not `FS`. The other seven read both.

### Why the third producer exists, and it is not a convenience

**Eight of fifteen are unreachable by the runtime trap, permanently, for a reason no arm can
engineer around**: the capability set is per-process, so a registration that performs `Env` cannot be
granted `Env` while the dispatch is denied it. **The compiler has no such blind spot.** Narrow the
row and the effect checker rejects any body that performs more — over **all inputs**, where the
capability trap is a witness over the one path an arm exercises.

So `make declared_vs_performed` now names **three** producers, per S16, none derived from another:

| | Producer | Coverage |
|---|---|---|
| DECLARED | the annotation a human wrote, grepped from source | 15/15 |
| PERFORMED (runtime) | the interpreter's capability trap, out of process | **7/15** witnessed, +compose = 8 |
| PERFORMED (static) | the effect checker's inference over the body | **15/15**, total over inputs |

**The static producer is strictly stronger than the runtime one on this question, and it only became
available because the row was narrowed.** C5 could not use it: it was asking about a hook whose
declaration it was not changing.

## The route, and why

**ROUTE A. The declared row is narrowed to what is performed.** `on_budget_plan` went from the ABI's
closed `! {Env, FS}` to no row at all, at `packages/motoko-ext-abi/types.ail` and at **48 binding
sites** across 38 files — 44 in the `BudgetPatch ! {Env, FS}` form and 4 lambda-annotation forms.
Every one of the 48 was verified to be a live annotation and **not** prose or a string before the
mechanical edit, per S15's data/prose split.

Route B was not taken and did not need weighing: criterion 1 is satisfied outright, so adding a
successor field to `BudgetPatch` would be a result-type change across every binding plus port work,
bought for a criterion the slot no longer needs.

**The cascade was two lines and the compiler found them**: `fold_budget_hooks` and
`dispatch_budget_plan` in `src/core/ext/runtime.ail` dropped `Env, FS` from `! {IO, Clock, Env, FS}`.
The one production caller (`src/core/rpc.ail:135`) needed no change.

### The compiler is the enforcer, and that is the point rather than a bonus

Verified directly at three points, each with its control:

```
narrow ONE binding, leave the ABI row wide
  -> REJECTED: failed to unify record field 'on_budget_plan': incompatible closed
     rows: r1 has extra labels [], r2 has extra labels [Env FS]

narrow the ABI row AND the binding
  -> ACCEPTED

narrow both, and make the body actually read env
  -> REJECTED: Effect checking failed for function 'budget_hook'
```

**Closed-row equality admits exactly one width**, so an extension that starts reading a config file
in its budget hook **fails to build**. Re-widening is now a deliberate act rather than a drift.

**The third test failed for the wrong reason on the first attempt** — `undefined variable: getEnvOr`,
because `compose.ail` does not import `std/env`. A control that dies for an unrelated reason
establishes nothing; C5's `must_die_on` discipline exists for exactly that and it caught this one. The
compile-time control in the gate is therefore **two-sided**: the mutant must be rejected with the
narrowed row **and accepted with a widened one**, so the rejection is attributable to the row.

## `make declared_vs_performed`: 10 rows → **15 rows, exit 0**

New rows, each with its two producers named at the site per S16:

- the ABI row asserts the **narrow** state — a re-widening turns it red rather than passing quietly;
- **no binding site in the tree** declares an effect row on a `BudgetPatch`-returning hook;
- the **subject list equals `registry_generated.ail`'s install set member for member**;
- the fifteen register-vs-dispatch differentials, in two regimes, with **zero BLOCKING** asserted;
- the compile-time control, two-sided.

**The vacuity controls moved from `on_budget_plan` to `on_pre_step`, and the reason is the item's own
result.** The narrowed row made a performing body in that slot **unwritable** — the compiler rejected
both controls where C5 had them. They now perform inside `on_pre_step`, dispatched through its own
unconditional fold, and still die on the named capability. **The control that was lost is not lost,
it is promoted**: it is the compile-time control, which is total where the runtime one was a witness.

## Three defects the new gate found in itself, and one in the tree

1. **`.packages/` was two days stale.** The first version of the no-stale-rows grep went red on five
   rows inside `.packages/motoko_core/`, the resolved tree `make sync_packages` writes. Real
   staleness, found by accident. `make sync_packages` fixed it; the gate is now scoped to source,
   because asserting an ABI property over build output reports staleness as a conformance failure.
2. **A character class truncated `register_a2a` to `a`.** `[a-z_]*` does not match digits, so the
   subject-list row reported a disagreement that did not exist. **A character class is a claim about
   the data too.**
3. **A count that exceeded its own denominator.** The first accounting incremented per row and
   reported "7 measured, 18 confounded" over fifteen subjects, because regime B re-counts what regime
   A could not reach. Now counted as sets of names.
4. **`exit=0` from a `tail` in the pipeline.** While confirming the re-widening guard bites, the first
   check read `$?` after piping through `tail` and reported success over a failing script. S19's exact
   shape, caught immediately, and the guard was then verified properly: `check_fixtures.py` exits 1
   and `make driver_only` exits 2 on a re-widened row, 0 on restore.

## The guard that was built to fire on this day, and did

`tools/profile_definition/check_fixtures.py` carried, since WI-B4:

> This goes red the day WI-C5 widens `on_budget_plan` — which is exactly the day the omission has to
> be decided again rather than inherited.

**WI-D6 narrowed it instead of widening it and the guard fired anyway**, on the same clause, with
`FAIL: ExtensionHooks.on_budget_plan no longer declares an effect row … Re-decide the omission; do
not inherit it.` **It did not care which direction the row moved, only that the basis had changed.**
That is the best behaviour any pin in this project has shown, and it is worth recording as the
standard: a guard written against a *specific* anticipated change caught the *opposite* change
because it pinned the fact rather than the direction.

Its polarity is now inverted — the row must declare **no** effects — and re-widening is falsifiable
in both directions, verified above.

## `driver_only/10` → `/11`, and it is a different kind of bump

v8→v9 (D3), v9→v10 (D4) and D2's before them were **re-measurements**: anchors moved, claims did not.
**This one changes a claim.** `omitted_extensions`' reason for `compaction_ai` no longer says the
omission is forced by the ABI, because it is not.

Install list, coverage claim, waived set, hook classifications, catalogue and attribution ref are
**all unchanged**, so no anchor moved. The bump exists because the reason is part of the definition,
and a consumer reading v10's reason would be reading a sentence this tree no longer asserts — which
is precisely S15's failure mode.

**A reader of v11 must not conclude that anything is covered.** v11 installs exactly what v10
installed, which is nothing.

## What D5's caveat now says

Updated in **both** places it appears, **dated rather than deleted** per S15 — exactly as D5 restated
the 2026-07-24 naming claim it superseded.

**FALSE FROM 2026-08-06:** *"and that is structural rather than incidental"*, and the whole **forced**
clause. An extension is installable in a conformant profile.

**STILL TRUE, STILL MANDATORY IN EVERY REPORT:** *"the axis's extension-model coverage is ZERO …
nothing about the extension model has been tested by this gate."*

**The emptiness moved from FORCED to CHOSEN, which is a WEAKER claim than D5's, not a stronger one.**
A chosen emptiness covers exactly as much as a forced one. The gate prints this on every run rather
than leaving it to a reader — which is D5's planning defect 4 ("the caveat needs to be a checked
artifact, not prose") partially discharged.

## S21, applied deliberately for the first time. **The count is still four.**

D5 measured that four acceptance rows lean on the empty install list, and required each to be
re-asked. **None closed. Each one's REASON concentrated.**

| Row | Before WI-D6 | After WI-D6 |
|---|---|---|
| 3 | Vacuous, on an install list **no profile could fill** | Vacuous, on an install list **this profile chooses not to fill** |
| 4 | `extension_effect_fault` waived by construction — **doubly** secured, by the empty list AND by the ABI | Waived by construction. **The waiver text never named the ABI**, so it is *unchanged in words*; it now rests on one reason where it rested on two |
| 5 | Compose's eight unrouted clock reads outside reach because nothing is installed | Unchanged, and now **actionable**: compose is installable, so the next profile must route them or declare them |
| 7 | `ScratchpadResult` unreachable because no hook is installed to emit it | Unchanged. Needs a hook returning `Handled` with a `cells` key, and a profile that installs one |

**WI-D6 removed a barrier, not a vacuity.** S21 exists because the count moved from two to four
without any item noticing; this item re-asked and the count held at four, which is the rule working
rather than the rule finding nothing.

**A fifth site concentrated the same way, outside the acceptance table**: `dst_hook_guard`'s
unreachability. It rested on two reasons — the empty install list and the ABI barrier — and now rests
on the first alone. Recorded at the site.

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243 files.** Run
  first, per S13. **The failing set matches the expected seventeen member for member**: 7
  `TC_ARITY_001` smoke scripts, `probe_phase_vocab_sealed`, 5 `src/examples/`, 3 code-graph fixtures,
  1 test-coverage fixture. Stable across B4, C1, C3, C5, C4, D3, D4, D5 and now D6.
  *(The raw run read 227/17 of 244 — the extra file was this item's own scratch probe, which was
  deleted; the tree is 243 files and the pass count 226. Stated rather than quietly adjusted.)*
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Both pre-existing since B2a, with D5's exact symptoms (`Named test blocks not yet implemented
  [stale_skip_record]`, `named_only.ail: also fired ['failing']`). `make --keep-going` emitted
  exactly two `Error` lines.
- **857 ✓ rows against D5's 845.** Same methodology (`grep -c '✓'` over the transcript). **The +12 is
  fully attributable to this item's own gate**: `declared_vs_performed` contributes 22 rows where it
  contributed 10. No other target's row count moved.
- **Every other target green**, including all eleven rows' producers: `world_state`,
  `profile_coverage`, `profile_definition`, `driver_only`, `fault_catalogue`, `event_vocabulary`,
  `invariants`, `run_report`, `latency_pair`, `corpus_pr`, `corpus_rotating`, `attribution_table`,
  `execution_program`, `discovery`, `strict_replay`, `seeded_generator`, `program_persistence`,
  `predicate_anchors`, `recorded_stream`, `stream_parity`, `ledger_parity`,
  `declared_vs_performed` (**15 passed, 0 failed**), `hook_guard` (4 passed, 0 failed),
  `smoke_driver`, `smoke_parity`.
- **The corpus artifact is unchanged**, read from `/tmp/corpus_pr.out` per S19: nine of nine expected
  classes, `the unreachable register is EMPTY`, `declared ⊆ observed`, 15 ≥ 12 seeds, and the same
  thin margin D5 flagged — **13 affordable at 381 ms/seed against a minimum of 12**.

## The owed `motoko-ext-abi` major

**Five changed rows now, and this item changed the fifth.** B1/B2a/B2b/C5 changed four
(`ExtPorts.ai_step`, `on_pre_step`, the four outcome records, `ExtPorts.clock_now` + `ExtClockReading`);
**D6 changes `ExtensionHooks.on_budget_plan`.**

**This item did NOT cut the major**, and the reason is that cutting it is a release act — a lockstep
re-release of every package in `ailang.toml`'s `[extensions]` — which is neither in this item's scope
nor decidable by it. `ailang lock` re-recorded the interface hashes as part of the normal build (19
entries moved). **C5's trap was checked and did not fire**: `git diff ailang.toml` is empty, so no
duplicate dependency key was appended.

**The count now stands at five changed rows and one added type, with the lock file moved four times.**

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **The handoff's binding count was wrong: fifteen, not nine.** Six extensions bind the slot that no
   document in this project names. Found by deriving the list from `registry_generated.ail` instead
   of from the handoff.
2. **REGISTRATION IS THE CONFOUND, AND IT WOULD HAVE PRODUCED NINE FALSE POSITIVES.** Nine of fifteen
   `register_with_config` implementations read `Env` before any hook is dispatched; seven also read
   `FS`. The naive arm scores every one as "the hook performs Env" — the answer that refuses Route A.
   Measured before the arms were written, which is the only reason it is a design note rather than a
   wrong conclusion.
3. **The runtime capability trap has a permanent blind spot here**, because capabilities are
   per-process: a registration that performs `Env` cannot be granted it while the dispatch is denied
   it. Eight of fifteen subjects are unreachable by C5's instrument no matter how the arm is written.
4. **Narrowing the row makes the compiler a STRONGER producer than the trap**, and it only becomes
   available by doing the work. Total over inputs, 15 of 15, where the trap witnesses 7.
5. **The narrowed row rejected the detector's own controls.** `env_reading_budget` and
   `fs_reading_budget` stopped compiling the moment the row narrowed —
   `incompatible closed rows: r1 has extra labels [], r2 has extra labels [Env]`. The strongest
   evidence the narrowing is real: after D6 a performing body in this slot is not merely absent, it
   is **unwritable**.
6. **B4's guard fired on the OPPOSITE change from the one it anticipated**, because it pinned the
   fact rather than the direction.
7. **`.packages/` was two days stale** and would have kept `pkg/` imports resolving against
   pre-D6 core. Found by the new gate's grep, not by anything designed to look for it.
8. **The cascade was two lines.** `fold_budget_hooks` and `dispatch_budget_plan`; one production
   caller, no change. The handoff budgeted for "one ABI row; every binding must match exactly" and
   that is exactly what it cost.

**Decided — a human chose:**

1. **Route A**, on criterion 1, with Route B not attempted — the slot does not need criterion 2.
2. **The subject list is DERIVED from `registry_generated.ail`, not written**, and the gate asserts
   the agreement. A handoff that undercounts by six is the argument for it.
3. **Every runtime subject is a PAIR**, and the confound is reported as a first-class outcome
   (CONFOUNDED) rather than folded into MEASURED or into BLOCKING.
4. **The compile-time control is two-sided**, after the one-sided version died for the wrong reason.
5. **The vacuity controls move to `on_pre_step`** rather than being deleted or weakened, with the
   promotion written at the site.
6. **The gate's stale-row grep is scoped to source.** `.packages/` staleness is real and is not this
   gate's subject.
7. **`driver_only` v11**, and the bump is described as a claim change rather than a re-measurement.
8. **The four leaning rows are re-asked and reported as UNCHANGED IN EXTENT**, with only their
   reasons moved. Reporting "extensions are now installable" as coverage movement is the specific
   error the mandatory caveat exists to prevent.
9. **The ABI major is not cut here**, and the count is stated instead.
10. **Nothing was installed.** The handoff's stop-and-report condition never triggered because no
    profile was changed to install anything.

## Sites where two answers type-checked and one was silently wrong: **2**

**Base 55 from D5's report. This run makes it 57. Determinism has still caught none.**

1. **The detector arm without its register-only twin.** Both forms type-check and both run; the
   version without the differential reports nine extensions as performing `Env` when what performs it
   is their registration. **The wrong answer is a false conformance fact about a real extension**, it
   is perfectly reproducible, and nothing else in the tree would have contradicted it — the gate would
   have gone red and the honest-looking conclusion would have been "Route A is blocked". Same species
   as C5's site 1: the instrument's own plumbing producing the evidence.
2. **A control that dies for the wrong reason.** `Effect checking failed` and
   `undefined variable: getEnvOr` are both non-zero exits from `ailang check` on a mutant, and a check
   asserting only "the mutant was rejected" passes on both. The second establishes nothing about the
   effect row.

**Per the handoff's S20 pointer, the place to look was anything reading a DECLARED row as evidence of
behaviour — and that is where site 1 was.** Not in the narrowing, where the compiler rejects the wrong
answer, but in the *instrument built to justify* the narrowing.

**Not counted, and said so rather than inflating the number:** the `[a-z_]*` truncation of
`register_a2a`, the confounded count exceeding its denominator, and the `tail` swallowing an exit
status are all real defects from this run, but each was **loud** — the gate went red or printed an
impossible number on the first run. The counter tracks answers that are *silently* wrong, and these
three were not.

## Corrections owed to the plan

1. **THE PLAN STILL HAS NO ITEM AFTER MILESTONE C, AND SIX CONSECUTIVE ITEMS HAVE NOW EXECUTED WITH
   NO PLAN ENTRY.** C4's planning defect 1 stands through D1, D2, D3, D4, D5 and D6. The last work
   item in the plan is **WI-C5**, unbuilt, and it is now the *only* remaining work item and the next
   one. The plan should record D5, D6 and the adoption.
2. **A HANDOFF'S SUBJECT COUNT IS A CLAIM AND IT WAS WRONG BY SIX.** The D6 handoff names eight
   extensions binding `on_budget_plan`; there are fourteen besides compose. Every one of the six it
   missed binds the slot with a constant, so nothing turned on it here — **but the handoff also said
   "a single binding that genuinely performs `Env` or `FS` blocks Route A", which makes the count
   load-bearing by its own argument.** *Suggested rule: when an item's scope is "every X", derive the
   list of X from a producer in the tree and assert the agreement in the gate; never take it from
   prose.* This is S16's independence requirement applied to a work item's *scope* rather than to a
   check's two sides.
3. **A PRODUCER'S BLIND SPOT IS A PROPERTY OF THE QUESTION, NOT OF THE INSTRUMENT.** C5's detector is
   sound and its second producer is the right one for the question C5 asked. Pointed at fifteen
   extensions instead of one it can answer for seven, and no amount of arm-writing changes that,
   because AILANG's capabilities are per-process. **The fix was not a better arm — it was a third
   producer.** *Suggested rule: before extending an instrument to a larger subject set, ask what
   fraction of the new set its producer can reach, and report the fraction rather than the subset.*
4. **THE COMPILER IS AN UNDERUSED PRODUCER IN THIS PROJECT, AND NARROWING A ROW UNLOCKS IT.** Every
   declared-versus-performed argument since D5 has been framed as needing a runtime witness, because
   the declaration was assumed fixed. The moment the declaration is a variable, the effect checker
   answers the same question **totally**. `on_response_intercept`, `on_solver_candidate` and
   `on_pre_step` are the three slots D5 still refuses on declared rows, and the same move is available
   to each — with its own measurement, none of which was taken here.
5. **S19 EARNED ITSELF AGAIN, IN A NEW MEDIUM.** `$?` after a pipe through `tail` reported success
   over a script that exited 1. Caught within one command, but it is the fourth medium this rule has
   surfaced in (absent tick, absent count, absent artifact row, and now a swallowed exit code).

## Out of scope, unchanged and still owed

- **WI-C5, the `compose`-bearing profile.** The next item, the last unbuilt one in the plan, and the
  one that turns this into coverage.
- **The `motoko-ext-abi` major and lockstep re-release** — five changed rows now.
- **The two sibling `st.world_state` finalize sites**; file reads in the interaction log; `FS` in
  `driver_only.forbidden_capabilities`; D4's provider latency pair; the adversarial partial stream;
  the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.
- **`test_coverage` and `test_coverage_selftest`**, red since B2a and untouched here.
- **`ExtPorts.proc_exec` and `env_get` widening**, still classifier-2 members, still WI-C5's.

## DID COVERAGE MOVE? **NO. IT SHOULD NOT HAVE, AND IT DID NOT.**

Said plainly because it is the sentence this item is most likely to be misread on, and because a
green `make declared_vs_performed` at fifteen rows looks like progress on a coverage claim.

**`driver_only` installs nothing. It covers nothing. Every clause of its acceptance table that
quantifies over installed extensions is vacuous to exactly the extent it was at WI-D5.** Eleven of
eleven rows still hold, four of them still lean on the empty install list, and the acceptance table
was not re-run because nothing here changes a row's answer.

**What moved is the modality of one sentence.** The empty install list was FORCED; it is now CHOSEN.
That is the whole delivery, and it is a precondition rather than a result.

**D5 called this "the one item that would make the name transfer." It was necessary and it was not
sufficient, and the name did not transfer.** The rows are earned by a profile that installs
something and passes the table. This item removed the blocker; **WI-C5 spends it.**
