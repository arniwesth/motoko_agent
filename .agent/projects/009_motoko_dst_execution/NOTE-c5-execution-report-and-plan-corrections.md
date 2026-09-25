# WI-C5 execution report — the seam routed, the detector built, and the install still refused

Twenty-third calibration run. Written against HEAD `a3c3998`, branch
`arniwesth/mot-62-execute-wi-c5`.

## Window

**~95 minutes** wall-clock: `2026-08-05T10:39Z` → `2026-08-05T12:14Z`. Grounding was clean: `git
status` clean at `a3c3998`, exactly what the handoff said, which is the third handoff in a row to get
commit state right.

The distribution is worth carrying because it inverts C3's. **The detector cost the most and was
worth the most** (~30 min including three mutation rounds); the ABI widening the handoff warned would
"not survive contact unchanged" cost about ten minutes and survived it exactly; the anchor cascade
cost about fifteen, **paid twice again**, for the same reason C3 paid it twice.

**And roughly fifteen minutes went to a self-inflicted wound that is the most transferable thing
here**: an over-aggressive cache clear uninstalled a registry package, and `ailang install` repairing
it corrupted `ailang.toml` with a duplicate key that broke `pkg/` resolution tree-wide. Four
hypotheses were eliminated before `git diff ailang.toml` found it. See corrections 4 and 5 — the
recipe I wrote into S9 earlier in this same item was itself wrong, and is corrected there.

## THE INSTALL ANSWER, with the ABI row named

**Compose is NOT installable, and this item did not make it installable.** The blocking row is

```ailang
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},   -- types.ail:298
```

Re-verified at HEAD and unchanged by anything here. Under D5 that slot is coverable under **neither**
criterion, and both halves of that are structural rather than a matter of degree:

- **Criterion 1 (deterministic and effect-free) fails on the declared row.** The row is closed and
  names `Env` and `FS`.
- **Criterion 2 (effectful only through world-mediated ports, with explicit world state returned)
  fails for want of a successor.** `BudgetPatch` has **no `next_state` field at all** — it is the one
  effectful slot in the ABI whose result type is a bare patch rather than an outcome record. So even
  if `Env` and `FS` were world-mediated, there is nowhere to put the returned world.

And the slot is **unconditionally dispatched** (`ext/runtime.ail:220`), so excluding it is not a
coverage cost but an un-runnable configuration. **The item therefore delivers the routing and the
detector but NOT the install, and that is stated plainly because C4 reads this paragraph.**

**Making compose installable needs `on_budget_plan` to become an outcome-returning, world-mediated
slot.** That is a second ABI major on top of the one Milestone B already owes, it changes a row every
extension in the tree binds, and per the handoff's stop-and-report rule it was NOT done inline.

**What this item DID move, and it is not nothing:** the detector below establishes by measurement
that compose's binding of that slot **performs neither `Env` nor `FS`**. So the barrier is now known
to be the *rule*, not the *behaviour* — which is exactly the input a decision to change the row needs
and did not have before.

## The detector, and its two producers named at the site

`make declared_vs_performed` — `scripts/dst/declared_vs_performed.ail` plus
`scripts/dst/run_declared_vs_performed.sh`. **10 rows, exit 0.** S16 binds this by name and both
producers are named in the file header, in the runner, and in the Makefile:

| | Producer | Where it comes from |
|---|---|---|
| **DECLARED** | the effect row on the ABI slot and on the extension's binding site | a static annotation a human wrote; the runner **greps it out of source** |
| **PERFORMED** | the AILANG runtime's capability enforcement | the **exit status of `ailang run --caps <row minus X>`**, out of process |

**Neither derives from the other**, which is the whole point. The mechanism is already recorded in
this tree at `src/core/ports.ail:406` — *"AILANG fails on a capability only when a read is
PERFORMED"* — and `make world_state`'s poison pairs already rely on it. The detector is that
mechanism pointed at a hook instead of at the driver.

**The headline measurement:**

```
DECLARED  on_budget_plan : ! {Env, FS}   (ABI row, static, authored)
PERFORMED on_budget_plan : ! {}          (runtime, out of process, witnessed)
```

**Every subject is paired with a control that must DIE on the named capability**, and the controls
are checked for *which* capability killed them — a control dying for an unrelated reason would make
the subject's completion read as evidence when it is noise. `control_env` dies on `Env`,
`control_fs` on `FS`, both verbatim from the interpreter.

### The limit is executable, not a caveat

`compose_intercept_noninline` completes with FS withheld. `compose_intercept_inline` — **the same
hook, the same declared row**, differing only in `mode` and in the response carrying an AILANG fence
— **dies on FS**. The runner asserts that death.

That row exists so the non-inline green cannot be read as *"`on_response_intercept` performs no FS"*,
which is false. **Performed is a property of a hook AND ITS INPUTS**, and a detector reporting a
per-hook fact would be reporting something that does not exist. This is written at the site and
stated three ways in the file header:

1. it is a **witness over exercised paths, not a proof over all inputs**;
2. it **cannot see an effect the runtime does not gate**;
3. it establishes **over-declaration only, never under-declaration** — B4's dangerous direction, a
   wider row on a function-typed parameter, is untouched and not claimed.

## The mutant that caught the detector certifying nothing, and it is the item's sharpest finding

**The first version of this detector was green at nine of nine rows over an arm whose dispatch had
been DELETED.** The completion marker was printed by the arm's own code, so a program that measured
nothing scored identically to one that measured everything. **That is S16 one level down, inside the
instrument built to answer S16** — and it is exactly the fourth-instrument-certifying-nothing failure
the handoff named in advance.

The fix: every subject arm now prints a value it can only obtain **by dispatching**. A `dvp_witness`
hook is registered **after** compose in the same registry, and the folds in `ext/runtime.ail` are
unconditional and ordered, so the sentinel can only appear if the fold ran and invoked compose first.
Sentinels are pairwise distinct per S7.

**Measured after the fix:**

| Mutant | Result |
|---|---|
| compose's `budget_hook` performs `Env` | **RED** — the subject dies |
| the Env control stops performing | **RED** — vacuity row fires |
| an arm's dispatch DELETED, marker left behind | **RED** (was green before the witness) |
| an arm's dispatch deleted and the sentinel **hardcoded** | **GREEN** — see below |
| **compose removed from the shared registry** | **RED at 2 rows** — and only two |

**Two of those deserve to be carried rather than buried.**

**First, the hardcoded-sentinel mutant stays green, and no gate in this project can do better.** It is
deliberate forgery of a check's own expected value, not a deletion. What the witness bought is that
**careless deletion is now caught**; faking requires an edit whose only purpose is to fake. Said
plainly rather than left as an implied "all mutants caught".

**Second — and this is the real one — removing compose from the registry reddens only ONE subject
row.** `compose_pre_step` names compose by `ext_id`, because `PreStepChainResult.stages` carries an
entry per hook. The other three arms cannot: **compose's binding of those slots is a constant no-op,
and a no-op is unobservable in a dispatch result by definition.** So three of four rows establish
*"the fold ran and performed nothing"*, not *"compose ran and performed nothing"*.

That is inherent to the subject rather than a defect in the gate, and it is joined rather than hidden:
`compose_pre_step` certifies compose is in the registry, and a **structural row** asserts all five
dispatching arms build their registry from the same constructor. Both are in the runner; neither is
prose.

## The ABI widening, which survived contact unchanged

`ExtPorts.clock_now` went from `() -> int ! {Clock}` to `(ExtWorld) -> ExtClockReading ! {Clock}`,
with `ExtClockReading = { now_ms: int, next_state: ExtWorld }` — the same record shape as
`AiStepOutcome` and core's `ClockReading`, for P1's reason.

**The handoff budgeted for this not surviving contact unchanged. It did survive, and the reason is
worth recording: the field had ZERO call sites**, so the widening touched seven *construction* sites
and nothing else. Six were the identical `noop_clock_now() -> int { 0 }` stub. **S3 is the rule that
predicted this** — the cheap instance of a seam is cheap because of parameter count, not because of
importance.

**What it bought, precisely, because the shape and the coverage are different questions:**

`session.ext_ports_of` now routes the extension clock through `Ports.clock_now` using the same
`token_to_world`/`world_to_token` codec `ai_step` uses. **`ext_unrouted_clock` is deleted and
`src/core/session.ail:878` has LEFT the declared-unrouted set** — not been reclassified, *removed*,
because the function that carried it no longer exists.

**Plan rule S2's only live exception is retired.** S2 chose an ambient read over a frozen snapshot
because `ExtPorts.clock_now`'s zero-argument shape admitted no world capture on the pin. The
obstacle was the **shape**; widening it removed the obstacle. The measurement S2 rests on (that
zero-argument lambdas do not parse in expression position on the pin) is **still true and is kept in
`session.ail` in the past tense per S15** — the evidence survives, the conclusion is retired.

**It did NOT make any extension coverable.** Coverage is D5's per-hook question and it is blocked on
`on_budget_plan`, not on this row. Written into the ABI comment so a future reader cannot take the
widening for a coverage claim.

### The routed set: 6 of 7, and the plan's 12/13 is stale

**The claim is COMPUTED, not recorded** (`routed_set_claim`), and it computes:

```
reachable_total: 7    routed: 6    declared unrouted: 1
```

**The handoff asked for 12 post-table and 13 fail-closed. Both numbers are stale and this is a plan
correction, not a shortfall** — see corrections below. The measured unconditional-core clock
inventory has been **7 sites** since WI-A5 measured it, against D4's prose of 13; the attribution
table already carried the note that *"D4's table says four and predates it"* for the routed half, and
the same staleness applies to the totals. `driver_only`'s own acceptance prints the computed answer
against the plan's prose rather than transcribing either.

What moved this item: **5 routed / 2 unrouted → 6 routed / 1 unrouted.**

## `routing_violation_at`'s production call site

`src/core/dst_hook_guard.guarded_dispatch_tool_handle`, with `make hook_guard` as acceptance — **4
rows, exit 0**, driven **through the guarded dispatch** rather than by calling the predicate, because
S14 one level down: a direct probe of the check is not evidence that the DISPATCH consults it.

It is a separate module for a layering reason, not a preference: `ExtRuntime` lives in the ABI
package and `ProfileDefinition` in core, so the runtime record has nowhere to carry a profile and the
guard cannot live inside the folds. It composes over them, which also keeps `ext/runtime.ail` free of
any DST dependency.

**Scoped to the ONE gated slot, and the reason is not arbitrary.** Seven of eight slots are
unconditionally dispatched, and D5's load-time rules already reject a profile excluding one of those,
because such a profile cannot complete a run. For those seven a dispatch-time check is unreachable by
construction — the load-time rejection fires first, always. `on_tool_handle` is the only slot whose
dispatch can be reached-or-not at runtime.

**Two things are asserted that a weaker version would have skipped:**

- **the excluded hook's BODY DID NOT RUN.** The hook returns a marker in `stdout`; the covering-profile
  row asserts the marker is present and the excluded row asserts an `Err`. A guard returning the right
  error *after* invoking the hook would be useless — D5 exists to stop the effects, not to relabel
  them.
- **the check is DISPATCH-scoped, not registry-scoped.** The same excluding definition with a tool the
  hook does not provide must NOT violate. That row pins `dst_hook_guard.provides_tool` to
  `ext/runtime.first_handle`'s gate — **the guard MIRRORS that predicate, and a mirror that drifts
  fails OPEN.** The liability is written at the site rather than left implicit.

**IT IS VACUOUS TODAY AND SAYS SO ON EVERY RUN.** No profile in this tree can reach it: `driver_only`
installs nothing, and no extension is installable while `on_budget_plan` carries its row. The fixture
is synthetic and the script prints that in four lines at the end of every invocation. **The same
blocker gates the guard and the install**, which is worth noticing: they are one fact, not two.

## Sites where two answers type-checked and one was silently wrong: 2

**Base 48 from C3's report. This run makes it 50. Determinism has still caught none.**

1. **The completion marker produced by the arm rather than by the dispatch.** Both forms type-check,
   both run, and the wrong one is **green over a program that measures nothing**. Caught by mutation,
   which this item ran *because the handoff argued for building the detector before the routing*.
   Nothing else in the tree could have seen it — the gate was the newest thing in the tree.
2. **`unrouted_fields: []` reading as "field missing".** `require_manifest_list` rejects an empty
   list, and until this item `clock_now` was always a member so the case never arose. Both readings
   type-check; the wrong one rejects a correct manifest. **Found by a gate** (`make driver_only`),
   which is the good outcome, and the fix is a deliberate weakening described below.

Both are the same species as C3's three: **a value well-formed under both readings whose wrong
reading changes whether a check passes.**

## Does `driver_only` still cover nothing provably? **YES. Unchanged.**

Said plainly because it is the sentence C4 most needs and a green `make dst` does not contain it:

**`driver_only` installs nothing, discloses nothing, and covers nothing provably. This item did not
change that.** Its `omitted_extensions` reason for `compaction_ai` — which already predicted what C5
would find — is unchanged and still correct in every clause. The routed-set arithmetic moved; the
coverage claim did not.

**The one thing that IS different:** that reason's final clause said the declared-versus-performed
gap *"is exactly the missing successor detector"* and that D5 *"names the detector that would license
that claim as explicitly unavailable"*. **The detector is no longer unavailable.** Whether it
licenses the claim is a D5 decision, not a consequence of the gate going green, and the gate says so
in its own output.

## Recorded bindings: decided versus discovered

**Discovered — a tool, the compiler or a measurement forced it:**

1. **The detector was green over a deleted dispatch.** The item's sharpest finding, found by mutation,
   and the argument for building instruments before the work they measure.
2. **Only ONE of four subject arms can name compose.** A constant no-op is unobservable in a dispatch
   result. Measured by removing compose from the registry, not reasoned about.
3. **`ExtPorts.clock_now` had zero call sites, so the widening cost seven constructions and nothing
   else.** The handoff's "budget for it not surviving contact" did not come due, and S3 explains why.
4. **`clock_now` LEFT the classifier-2 unrouted set automatically.** `derive.py` looks for a literal
   `next_state` field; `ExtClockReading` has one. The tool reported it before I looked, and
   `check_fixtures.py` went red on the stale fixture.
5. **An empty `unrouted_fields` is rejected as "missing".** See two-answer site 2.
6. **`.ailang/cache` is PER-DIRECTORY and scattered through the repo.** `rm -rf .ailang/cache` at the
   root leaves a warm cache in 20+ directories. This produced a **phantom type error** in
   `long_qwen_compaction_dst.ail` that survived `ailang lock` and vanished when every cache was
   cleared. See corrections — this is the third item to be bitten by cache state.
7. **The anchor cascade was paid TWICE, again**, for C3's exact reason: comment edits landed after the
   first payment and moved four line numbers by nine.
8. **`omitted_site()`'s fixture anchor fired**, exactly as C3's report predicted it would — **and a
   THIRD consumer surfaced that no checklist in this project names**:
   `dst_attribution_table`'s own unit test `test_discovered_site_in_neither_list_is_rejected` carries
   a copy of a moved anchor. It passed `make attribution_table`'s *script* and `make anchors`, and
   was caught only by `ailang test` inside `make dst`. The known consumer list is now four:
   `anchors.sh`, the `predicate-anchors` script, `omitted_site()`, and this unit test.
9. **The classifier tool RE-DERIVED `clock_now` as routed before I looked**, and independently
   resolved its bridge seam to `Ports.clock_now`. Its self-test then went red on the pinned
   expectation `{"state": "unrouted", "seam": null}` — a pin doing exactly its job. Corroboration
   from an instrument that knows nothing about this item's intent is the strongest evidence the
   routing is real, and it is worth more than the two gates I wrote for it.
10. **`unrouted`/`seam: null` is now an UNREACHABLE pinned value.** `clock_now` was the only field
    that could carry it. The pin is kept and its emptiness described, because the next un-widened
    seam re-introduces it.
11. **The whole-tree sweep's `find` root list contains `cmd`, which does not exist**, and this shell's
   `find` is `bfs`, which ABORTS rather than warning. The sweep silently checked zero files.

**Decided — a human chose:**

1. **The install answer is NO, reported rather than resolved inline.** Changing `on_budget_plan` is an
   ABI major with a profile version bump behind it and the handoff's stop-and-report rule covers it.
2. **The detector's second producer is the RUNTIME's capability trap, observed out of process.** The
   alternative — the world's interaction log — was rejected: `Env`/`FS` here are ambient, not
   world-mediated, so the log under-reports and absence of an entry would not prove absence of an
   effect. That is fail-OPEN, in the direction that grants coverage credit.
3. **Every subject is paired with a control, and the control's DEATH REASON is asserted**, not just
   its exit status.
4. **The limit arm is a passing row rather than a comment.** `compose_intercept_inline` must die.
5. **Compose's eight clock reads are NOT routed, and partially routing them was rejected.** See below.
6. **`unrouted_fields` may now be empty, and the weakening is written at both sites** rather than
   quietly relaxed.
7. **The `session.ail` S2 history block is KEPT in the past tense** rather than deleted: the pin
   measurement inside it is still true and a future zero-argument port will want it.
8. **The guard is scoped to the gated slot**, with the seven unconditional ones argued unreachable
   rather than forgotten.
9. **`table_source_revision` stays `c0fbf10`.** The attribution ROWS are unchanged; only the
   unconditional-core set moved. Same call C3 made.

## Gate state

- **`make declared_vs_performed` — exit 0.** 10 rows.
- **`make hook_guard` — exit 0.** 4 rows.
- **`make driver_only` — exit 0** at **v7**, attribution ref re-recorded to
  `sha256:addd5e2c…`, routed claim computed at 6/7.
- **`make attribution_table` / `make anchors` / `make profile_definition` /
  `make profile_coverage` — exit 0.**
- **The three rowless slots are BYTE-IDENTICAL.** `on_describe_tools`, `on_build_system_prompt` and
  `on_tool_policy` are untouched, `make profile_coverage` passes, and the handoff's stop-and-report
  condition for them did not trigger. Five consecutive items now.
- **`make dst` — EXIT 2, with the SAME TWO red targets as B4, C1 and C3**, cache-cold with every
  `.ailang/cache` cleared:
  - **`test_coverage`** and **`test_coverage_selftest`** — both pre-existing, unchanged, attributed by
    B2a to module resolution in `ailang test`.
  - **Every other target passes**, including `attribution_table`, `driver_only`, `profile_definition`,
    `profile_coverage`, `invariants`, `stream_parity` (both gates), `recorded_stream`, and the two new
    ones. **757 pass rows / 7 fails.** The row count is NOT compared to C3's reported 770: that number
    was produced at review by a different measurement and I did not reproduce its methodology, so
    quoting a delta would be inventing a comparison. What IS comparable, and is the claim that
    matters, is the RED TARGET SET, which is identical member-for-member.
  - **Three targets went red DURING this item and all three were pins doing their job**:
    `attribution_table`'s completeness fixture and unit test (moved anchors),
    `ext_call_inventory_selftest` (the `clock_now` membership pin), and `driver_only`'s manifest
    fixture (the emptied unrouted set). None was a defect in the change; each was an artifact
    correctly refusing a stale literal.

## Corrections owed to the plan

1. **WI-C5's routed-set figure of "12 post-table, 13 fail-closed" is STALE, and the correct answer is
   COMPUTED anyway.** D4's 4/12/13 versus 5/13/13 split predates WI-A5's measurement of the actual
   inventory, which found **7** unconditional-core clock sites, not 13. The attribution table already
   carried this correction for the routed half (*"D4's table says four and predates it"*); it was
   never propagated to the totals, and the C5 handoff inherited the stale pair. **The profile's claim
   is derived from the table at the bound revision and prints against the plan's prose**, so no
   number was transcribed. **Replace the 12/13 pair in the plan's WI-C5 text with a pointer to
   `routed_set_claim`.**
2. **`.ailang/cache` DIRECTORIES ARE PER-SOURCE-DIRECTORY, and clearing the root one is not
   cache-cold.** S9 and S13 both require cache-cold runs and neither says where the caches are. At
   HEAD there are **20+** of them under `src/`, `scripts/`, `packages/` and `tools/`. A partially
   warm tree produced a type error that contradicted the source, survived `ailang lock`, and vanished
   on a full clear — **the exact trap the plan's "clear `.ailang` caches before believing type errors
   that contradict source" already names, with the location it omits.** The command is:
   `find . -type d -name cache -path "*.ailang*" -exec rm -rf {} +` plus `~/.ailang/cache`.
   **Add it to S9.**
3. **S13's sweep command names a root that does not exist, and on this shell it fails SILENTLY TO
   ZERO.** `find src scripts packages tools cmd` — there is no `cmd/` in this repo. GNU `find` warns
   and continues; this environment's `find` is `bfs`, which **aborts**, so the loop iterates over
   nothing and the sweep reports **0 failures** — a perfect green over zero files checked. **Drop
   `cmd` from S13's command.** This is the fourth instrument in this project to have a green that
   means nothing, and the cheapest one to have prevented.
4. **`ailang install <pkg>` APPENDS A DUPLICATE DEPENDENCY KEY, and a duplicated key in
   `[dependencies]` silently breaks `pkg/` resolution ACROSS THE WHOLE TREE.** Found the expensive
   way. Running `ailang install sunholo/logging@0.4.0` — to repair a registry package I had deleted
   with an over-aggressive cache clear — wrote a SECOND `"sunholo/logging" = "0.4.0"` line into
   `ailang.toml` beside the one already there. Every `pkg/...` import in the repo then failed with
   *"requires ailang.toml and ailang.lock"*, which names neither the duplicate nor the file.
   **Diagnosis cost roughly fifteen minutes and produced four wrong hypotheses** (the lock, the empty
   `.ailang` directories, `.packages/`, the parent-directory cache), each eliminated by a clean-tree
   comparison. The thing that found it was `git diff ailang.toml` — the file had not been in
   `git status` when I last looked, because the install came after. **Two lessons: `ailang install`
   is not idempotent, and `git status` before a tool run is not evidence about the tree after it.**
   Worth filing upstream.
5. **`~/.ailang/cache` HOLDS INSTALLED REGISTRY PACKAGES, not just compilation output.** Deleting it
   uninstalls every registry dependency, which is what set the trap above. **The cache-cold recipe
   must clear the per-directory `.ailang/cache` dirs and leave `~/.ailang/cache/registry` alone.**
   This corrects the recipe I first wrote into S9 in this same item.
6. **A "PERFORMED" observation needs a producer the hook cannot influence, and the world interaction
   log is NOT one for ambient effects.** The log records what was requested *through the world*;
   `Env` and `FS` on this hook are ambient, so absence from the log is not absence of the effect. The
   capability trap is the right producer because it is enforced by the interpreter. **Generalises: for
   any "did component X perform effect E" question, prefer the enforcement mechanism over the record,
   because a record can be silent and enforcement cannot.**
7. **An instrument whose evidence is produced by the thing under test is green over its own
   deletion**, and S16 should say this covers the instrument's OWN plumbing, not only the property's
   two sides. Measured: nine of nine rows green over a deleted dispatch. **The fix generalises —
   make the assertion a value the subject can only produce by doing the work.**
8. **The anchor cascade is not paid once per item — this is the SECOND consecutive item to pay it
   twice**, both times because comment edits landed after the first payment. C3's operational rule
   ("finish every source edit, including comments, BEFORE running the cascade") is correct and was
   followed for the *source* edits; what broke it was editing a **historical comment block for tense**
   after the anchors were computed. **S15 and the anchor rule interact: tensing a comment IS a source
   edit for cascade purposes.**
9. **The counter is 50**, from C3's 48.

## Deliberately not done

- **Compose's eight clock reads are NOT routed, and partial routing was REJECTED rather than
  attempted.** Measured before deciding: the reads sit in `telemetry_json` (12 parameters, no `ctx`),
  `run_attempts` (**30 parameters, 4 call sites, recursive**), `handle_compose_tool`,
  `on_response_intercept`, plus `author_tools.ail:101` and `authoring/dispatcher.ail:217`. Threading a
  world successor through them means changing the return type of every one and every call site.
  **Partial threading is worse than none** — a world threaded through some reads and not others is a
  dropped cursor, which is F6 and plan rule S2's frozen-snapshot defect exactly. And the coverage
  value is **zero today**, because the package is un-installable for the `on_budget_plan` reason and
  its sites are installation-scoped (clause 2), so no profile's reachable set contains them. **This is
  the largest single thing the handoff asked for that this item did not deliver, and it is named here
  rather than softened.**
- **`ExtPorts.proc_exec` and `env_get` widening.** Still classifier-2 members, still WI-C5's by the
  plan's text, still un-widened. `clock_now` was chosen first per S3 and consumed the budget the
  handoff allotted to the seam.
- **The `on_budget_plan` ABI change.** Stop-and-report, discharged by reporting.
- **WI-C4, the name gate.** **No target adopted the "DST" or "simulation" name.**
- **Wiring the seeded runners through `execution_of`**; the extension bridge's emission channel; the
  `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds. Unchanged, still owed.

**On the owed ABI major, per the handoff's instruction to say so rather than add a fourth row:** this
item **changed one ABI row** (`ExtPorts.clock_now`) and **added one type** (`ExtClockReading`).
`ailang lock` re-recorded the interface hash, which is part of the normal build. **The owed major now
covers four changed rows rather than three**, and it stopped being deferrable in the narrow sense that
the lock file has already moved.
