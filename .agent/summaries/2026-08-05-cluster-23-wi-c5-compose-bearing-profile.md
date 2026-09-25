# 2026-08-05 Cluster 23: WI-C5 — the clock seam routed, D5's detector built, and the install refused

## Context

Branch: `arniwesth/mot-62-execute-wi-c5`.

Session span: `a3c3998` → **`05275ab`, one commit, working tree clean**. Input was
`HANDOFF-execute-c5-compose-bearing-profile.md`, executed cold against HEAD. Twenty-third code
session of project 009, third of Milestone C. Pin **v0.33.0**.

**Window: ~95 min**, `10:39Z` → `12:14Z`. The distribution inverts C3's: **the detector cost the most
and was worth the most** (~30 min including three mutation rounds); the ABI widening the handoff
warned would "not survive contact unchanged" cost ~10 min and survived it exactly; the anchor cascade
cost ~15, **paid twice again**. And **~15 minutes went to a self-inflicted wound that is the most
transferable thing here** — see "The fifteen minutes I lost to my own repair".

**The item's name is a promise it does not keep, and that is the finding.** It was scoped as "the
second profile: `compose`-bearing". There is no compose-bearing profile, because compose cannot be
installed, and this session's job turned out to be establishing *why* with a measurement rather than
an argument.

| Definition-of-done item | State |
|---|---|
| The install question answered explicitly, ABI row named | **met** — NO, on `on_budget_plan`; C4's input |
| The detector's two producers named at the site | **met** — static ABI row vs out-of-process capability trap |
| `ExtPorts.clock_now` widened, first call sites landed | **met** — `(ExtWorld) -> ExtClockReading`, routed in `ext_ports_of` |
| **The eight compose clock reads routed** | **NOT met** — measured, rejected as all-or-nothing; see below |
| `routing_violation_at` called from production | **met** — `dst_hook_guard`, gated slot, 4 acceptance rows |
| Routed set claimed at 12 post-table / 13 fail-closed | **met differently** — both numbers are stale; computed answer is **6 of 7** |
| S13 sweep cache-cold, failing set member-for-member | **met** — 242 checked / 17 fail, identical membership |
| S17: mutation loop restores by `cp` | **met** — used throughout, including the full-tree revert experiment |
| Anchor rule: all source edits before the cascade | **failed, and recorded** — paid twice, cause is new (S18) |
| Three rowless slots byte-identical | **met** — `make profile_coverage` green; fifth consecutive item |

## Grounding

HEAD `a3c3998`, tree clean — exactly what the handoff said. **Third consecutive handoff to get commit
state right.**

The handoff's grounding table was accurate on every row I checked except one: it said
`routing_violation_at` has "only three call sites, all self-tests". There are **seven** — three
self-tests plus four in two acceptance scripts. The substance held (none in production), so it changed
nothing, but it is the kind of number worth re-deriving rather than inheriting.

## The install answer, and it is the durable output because C4 reads it

**Compose is NOT installable, and this item did not make it installable.**

```ailang
  on_budget_plan: (ExtCtx, BudgetPlan) -> BudgetPatch ! {Env, FS},   -- types.ail:298
```

Under D5 the slot is coverable under **neither** criterion, and both halves are structural:

- **Criterion 1 fails on the declared row** — closed, names `Env` and `FS`.
- **Criterion 2 fails for want of a successor.** `BudgetPatch` **has no `next_state` field at all**.
  It is the one effectful slot in the ABI whose result is a bare patch rather than an outcome record,
  so even if `Env`/`FS` were world-mediated there is nowhere to put the returned world.

And it is **unconditionally dispatched** (`ext/runtime.ail:220`), so excluding it is not a coverage
cost but an un-runnable configuration. Making it installable needs the row to become an
outcome-returning, world-mediated slot — **a second ABI major on top of the one Milestone B owes**,
touching a row every extension in the tree binds. Reported, not taken, per the handoff's
stop-and-report rule.

**What the item DID move:** the detector establishes **by measurement** that compose's binding of that
slot performs neither `Env` nor `FS`. **The barrier is now known to be the RULE, not the BEHAVIOUR** —
which is exactly the input a decision to change the row needs and did not previously have.

## The detector, and S16 bound it by name

`make declared_vs_performed` — **10 rows, exit 0.** D5 names this instrument and records it as
unavailable; this is its first build.

| | Producer | Where it comes from |
|---|---|---|
| **DECLARED** | the effect row on the ABI slot and the extension's binding site | a static annotation a human wrote; the runner **greps it out of source** |
| **PERFORMED** | the AILANG runtime's capability enforcement | the **exit status of `ailang run --caps <row minus X>`**, out of process |

Neither derives from the other. The mechanism was already in the tree at `src/core/ports.ail:406` —
*"AILANG fails on a capability only when a read is PERFORMED"* — and `make world_state`'s poison pairs
already rely on it. **The detector is that mechanism pointed at a hook instead of at the driver.**

```
DECLARED  on_budget_plan : ! {Env, FS}   (ABI row, static, authored)
PERFORMED on_budget_plan : ! {}          (runtime, out of process, witnessed)
```

**Every subject is paired with a control that must DIE on the NAMED capability.** A control dying for
an unrelated reason would make the subject's completion read as evidence when it is noise, so the
runner matches the interpreter's exact error string. `control_env` dies on `Env`, `control_fs` on `FS`.

**The rejected alternative matters as much as the chosen one.** The world interaction log looks like a
second producer and is not one for ambient effects: it records what was requested *through the world*,
so absence from it is not absence of the effect. That fails **open**, in the direction that grants
coverage credit. The capability trap cannot be silent.

### The limit is an executable row, not a caveat

`compose_intercept_noninline` completes with FS withheld. `compose_intercept_inline` — **the same
hook, the same declared row**, differing only in `mode` and in the response carrying an AILANG fence —
**dies on FS**, and the runner asserts that death.

That row exists so the first green cannot be read as *"`on_response_intercept` performs no FS"*, which
is false. **Performed is a property of a hook AND ITS INPUTS**; a detector reporting a per-hook fact
would report something that does not exist. Three limits are stated in the file header: it is a
**witness over exercised paths, not a proof**; it **cannot see an ungated effect**; it establishes
**over-declaration only, never under-declaration** (B4's dangerous direction is untouched and not
claimed).

## The session's headline: the detector was green over its own deletion

**The first version was green at NINE OF NINE ROWS over an arm whose dispatch had been DELETED.** The
completion marker was printed by the arm's own code, so a program measuring nothing scored identically
to one measuring everything.

**That is S16 one level down, inside the instrument built to answer S16.** The property's two
producers were genuinely independent; the *instrument's own plumbing* had one producer. It is exactly
the "fourth instrument to certify nothing while exiting 0" the handoff named in advance — and it
happened anyway, which is the argument for building instruments before the work they measure.

The fix: every subject asserts a sentinel it can only obtain **by dispatching**. A `dvp_witness` hook
is registered **after** compose in the same registry; the folds are unconditional and ordered, so the
sentinel appears only if the fold ran and invoked compose first. Sentinels are pairwise distinct (S7).

| Mutant | Result |
|---|---|
| compose's `budget_hook` performs `Env` | **RED** — subject dies |
| the Env control stops performing | **RED** — vacuity row fires |
| dispatch DELETED, marker left behind | **RED** (was green before the witness) |
| dispatch deleted **and the sentinel hardcoded** | **GREEN** |
| **compose removed from the shared registry** | **RED at 2 rows — and only two** |

**Two of these are load-bearing and both are stated in the runner rather than buried.**

**The hardcoded-sentinel mutant stays green and no gate in this project can do better.** It is
deliberate forgery of a check's own expected value, not a deletion. What the witness bought is that
*careless deletion* is caught; faking now requires an edit whose only purpose is to fake.

**Removing compose from the registry reddens only ONE subject row.** `compose_pre_step` names compose
by `ext_id` because `PreStepChainResult.stages` carries an entry per hook. The other three cannot:
**compose's binding of those slots is a constant no-op, and a no-op is unobservable in a dispatch
result by definition.** So three of four rows establish *"the fold ran and performed nothing"*, not
*"compose ran and performed nothing"*. That is inherent to the subject, not a gate defect — and it is
**joined** by `compose_pre_step` plus a structural row asserting all five dispatching arms build their
registry from the same constructor.

## The ABI widening, which survived contact unchanged

`ExtPorts.clock_now`: `() -> int ! {Clock}` → `(ExtWorld) -> ExtClockReading ! {Clock}`, with
`ExtClockReading = { now_ms, next_state }` — the same record shape as `AiStepOutcome` and core's
`ClockReading`, per P1.

**The handoff budgeted for this not surviving contact. It did, and the reason is carryable: the field
had ZERO call sites**, so the widening touched seven *construction* sites and nothing else — six of
them the identical `noop_clock_now() -> int { 0 }` stub. **S3 predicted this**: the cheap instance of a
seam is cheap because of parameter count, not importance.

`session.ext_ports_of` now routes the extension clock through `Ports.clock_now` using the same
`token_to_world`/`world_to_token` codec `ai_step` uses (and the same `let w0` shape, for the
inventory tool's documented fail-open matcher rather than for symmetry). **`ext_unrouted_clock` is
DELETED and `session.ail:878` has LEFT the declared-unrouted set** — removed, not reclassified,
because the function that carried it no longer exists.

**Plan rule S2's only live exception is retired.** S2 chose an ambient read over a frozen snapshot
because the zero-argument shape admitted no world capture. The obstacle was the **shape**; widening it
removed the obstacle. The pin measurement S2 rests on is still true and is **kept in `session.ail` in
the past tense per S15** — the evidence survives, the conclusion is retired.

**It did NOT make any extension coverable**, and the ABI comment says so, so a future reader cannot
take the widening for a coverage claim.

### Independent corroboration, from a tool that knows nothing about the intent

`tools/ext_call_inventory/derive.py` **re-derived `clock_now` as routed before I looked**, resolved its
bridge seam to `Ports.clock_now`, and then its self-test went **red** on the pinned expectation
`{"state": "unrouted", "seam": null}`. That pin doing its job is stronger evidence the routing is real
than either gate I wrote for it. Consequence: **`seam: null` is now an unreachable pinned value** —
`clock_now` was the only field that could carry it. The pin is kept and its emptiness described,
because the next un-widened seam re-introduces it.

## The routed set: 6 of 7, and the plan's 12/13 was stale

The claim is **computed** (`routed_set_claim`), not recorded: `reachable_total: 7, routed: 6,
declared_unrouted: 1`.

The handoff asked for **12 post-table / 13 fail-closed**. Both are stale: D4's 4/12/13 and 5/13/13
predate WI-A5's measurement, which found **seven** unconditional-core clock sites, not thirteen. The
attribution table has carried the correction for the routed half since A5 (*"D4's table says four and
predates it"*) and it was never propagated to the totals. **The plan's WI-C5 text now points at
`routed_set_claim` instead of carrying either number.**

What moved this item: **5 routed / 2 unrouted → 6 routed / 1 unrouted.**

## `routing_violation_at`'s production call site

`src/core/dst_hook_guard.guarded_dispatch_tool_handle`, with `make hook_guard` — **4 rows, exit 0** —
driven **through the guarded dispatch** rather than by calling the predicate. That is S14 one level
down: a direct probe of the check is not evidence that the DISPATCH consults it.

A separate module for a layering reason, not a preference: `ExtRuntime` is in the ABI package and
`ProfileDefinition` in core, so the runtime record has nowhere to carry a profile. It composes over
the folds, which also keeps `ext/runtime.ail` free of any DST dependency.

**Scoped to the ONE gated slot, and the reason is not arbitrary.** Seven of eight are unconditionally
dispatched, and D5's load-time rules already reject a profile excluding one of those. For those seven
a dispatch-time check is unreachable by construction — the load-time rejection fires first, always.

Two assertions a weaker version would have skipped:

- **the excluded hook's BODY DID NOT RUN.** The hook returns a marker in `stdout`; the covering row
  asserts it is present, the excluded row asserts `Err`. A guard returning the right error *after*
  invoking the hook has relabelled the effects, not prevented them.
- **the check is DISPATCH-scoped, not registry-scoped** — the same excluding definition with a tool the
  hook does not provide must not violate. That row pins `provides_tool` to `first_handle`'s gate.
  **The guard MIRRORS that predicate and a mirror that drifts fails OPEN**; the liability is written at
  the site.

**It is vacuous today and says so on every run** — four printed lines. No profile can reach it:
`driver_only` installs nothing, and nothing is installable while `on_budget_plan` stands. **The same
blocker gates the guard and the install**, which is one fact, not two.

## What was measured and then refused: compose's eight clock reads

**Not routed, and partial routing was rejected rather than attempted.** Measured before deciding: the
reads sit in `telemetry_json` (12 params, no `ctx`), `run_attempts` (**30 parameters, 4 call sites,
recursive**), `handle_compose_tool`, `on_response_intercept`, plus `author_tools.ail:101` and
`authoring/dispatcher.ail:217`. Threading a world successor means changing the return type of every one
and every call site.

**Partial threading is worse than none** — a world threaded through some reads and not others is a
dropped cursor, which is F6 and S2's frozen-snapshot defect exactly. And the coverage value is **zero
today**: the package is un-installable, and its sites are installation-scoped (clause 2), so no
profile's reachable set contains them.

**This is the largest thing the handoff asked for that the item did not deliver.**

## The fifteen minutes I lost to my own repair

An over-aggressive cache clear (`rm -rf ~/.ailang/cache`) **uninstalled a registry package** —
`~/.ailang/cache` holds installed registry packages, not just compilation output. Repairing it with
`ailang install sunholo/logging@0.4.0` **appended a SECOND `"sunholo/logging" = "0.4.0"` line to
`ailang.toml`**, and a duplicated key in `[dependencies]` **silently breaks `pkg/` resolution across
the entire tree**, with an error (*"requires ailang.toml and ailang.lock"*) that names neither the
duplicate nor the file.

**Four hypotheses were eliminated before the cause was found** — the lock, empty `.ailang` directories,
`.packages/`, a parent-directory cache — each by clean-tree comparison against a `git archive` of HEAD
with the working diff applied. The thing that found it was `git diff ailang.toml`. **The file had not
been in `git status` when I last looked, because the install came after.**

Two lessons, both now in the plan: **`ailang install` is not idempotent**, and **`git status` before a
tool run is not evidence about the tree after it.** The cache-cold recipe I wrote into S9 earlier in
this same item was itself wrong and is corrected there.

## Sites where two answers type-checked and one was silently wrong: 2 → counter 50

Base **48** from C3. **Determinism has still caught none.**

1. **The completion marker produced by the arm rather than by the dispatch.** Both forms type-check,
   both run, and the wrong one is **green over a program that measures nothing**. Caught by mutation,
   which ran only because the handoff argued for building the detector before the routing. Nothing
   else in the tree could have seen it — the gate was the newest thing in it.
2. **`unrouted_fields: []` reading as "field missing".** `require_manifest_list` rejects an empty list,
   and until this item `clock_now` was always a member so the case never arose. The wrong reading
   rejects a correct manifest. **Found by a gate**, and fixed by a deliberate weakening.

Both are C3's species: **a value well-formed under both readings whose wrong reading changes whether a
check passes.**

## A rule deliberately weakened, and said so at both sites

`unrouted_fields` is no longer required to be non-empty, because **empty became the correct value**.
The cost is stated rather than hidden: an empty set no longer distinguishes *"nothing is unrouted"*
from *"nobody gathered this"*. What stands in for it is `check_fixtures.py` **re-deriving** the set
from the tool — a check in a different artifact, not in this rule. The discrimination is kept alive by
the sibling row: an empty **classifier-2** set is still rejected, so this is not a blanket "empty lists
are fine".

## Does `driver_only` still cover nothing provably? YES, unchanged

Said plainly because it is the sentence C4 most needs and a green `make dst` does not contain it.
`driver_only` installs nothing, discloses nothing, covers nothing provably. Its `omitted_extensions`
reason for `compaction_ai` — which already *predicted* what C5 would find — is unchanged and correct in
every clause.

**The one thing that is different:** that reason said the declared-versus-performed gap *"is exactly
the missing successor detector"* and that D5 *"names the detector that would license that claim as
explicitly unavailable"*. **The detector is no longer unavailable.** Whether it licenses the claim is a
D5 decision, not a consequence of a green — and the gate prints that in its own output.

## Gate state

- **`make declared_vs_performed` — exit 0**, 10 rows. **`make hook_guard` — exit 0**, 4 rows.
- **`make driver_only` — exit 0 at v7**, attribution ref re-recorded to `sha256:addd5e2c…`.
- **`make attribution_table` / `anchors` / `profile_definition` / `profile_coverage` — exit 0.**
- **`make dst` — EXIT 2, the SAME TWO red targets as B4, C1 and C3** (`test_coverage`,
  `test_coverage_selftest`), cache-cold. **757 pass rows / 7 fails.** The row count is deliberately
  **not** compared to C3's reported 770: that number came from a different measurement I did not
  reproduce, so quoting a delta would be inventing a comparison. The comparable claim is the **red
  target set**, identical member-for-member.
- **Whole-tree sweep — 242 checked / 17 fail**, cache-cold with `AILANG_RELAX_MODULES=1`, **membership
  identical to baseline**; 242 rather than 239 because three files are new, all passing.
- **0 tracked `.ailang/cache` paths.**

### Three targets went red during the item, all three pins doing their job

`attribution_table` (moved anchors, in both the completeness fixture and a unit test),
`ext_call_inventory_selftest` (the `clock_now` membership pin), `driver_only` (the emptied unrouted
set). **None was a defect in the change**; each was an artifact correctly refusing a stale literal.

## Plan corrections landed

1. **S13's sweep command names a root that does not exist and fails SILENTLY TO ZERO.**
   `find src scripts packages tools cmd` — there is no `cmd/`. GNU `find` warns and continues; this
   environment's `find` is `bfs`, which **aborts**, so the loop iterates over nothing and reports **0
   failures**. A perfect green over zero files. `cmd` removed. **The fourth instrument in this project
   to have a green that means nothing, and the cheapest to have prevented.**
2. **`.ailang/cache` is PER-SOURCE-DIRECTORY** — 20+ of them — so clearing the root one is not
   cache-cold. Command added to S13. **But NOT `~/.ailang/cache`**, which holds installed registry
   packages; the `ailang install` non-idempotence trap is written up beside it.
3. **S16 sharpened: it extends to the instrument's OWN plumbing.** The value a check asserts on must be
   one the subject can only produce by doing the work. With the measured limit that a constant no-op is
   unobservable, and the finding that **enforcement beats record** for any "did X perform E" question.
4. **S18 (new): tensing a comment IS a source edit for anchor-cascade purposes.** Second consecutive
   item to pay the cascade twice; this time the cause was rewriting a historical block for tense
   **under S15** after the anchors were derived. **S15 and the anchor rule interact, and the
   interaction is the trap.**
5. **WI-C5's 12/13 routed figure is stale**; the plan now points at `routed_set_claim`.
6. **A third anchor consumer surfaced** that no checklist names: `dst_attribution_table`'s own unit
   test. Known consumers now four.
7. **The counter is 50.**

## Deliberately not done

- **Compose's eight clock reads.** Measured and refused — see above.
- **`ExtPorts.proc_exec` / `env_get` widening.** Still classifier-2 members, still WI-C5's by the
  plan's text. `clock_now` went first per S3 and consumed the seam budget.
- **The `on_budget_plan` ABI change.** Stop-and-report, discharged by reporting.
- **WI-C4, the name gate.** No target adopted the "DST" or "simulation" name.
- **Wiring the seeded runners through `execution_of`**; the extension bridge's emission channel; the
  `motoko-ext-abi` major and lockstep re-release; the `ailang iface` MOD010 filing; the 7
  `TC_ARITY_001` scripts; the two v0.33.0-fixed workarounds.

**On the owed ABI major:** this item changed **one row** (`ExtPorts.clock_now`) and added **one type**
(`ExtClockReading`); `ailang lock` re-recorded the interface hash as part of the normal build. **The
owed major now covers four changed rows rather than three**, and it stopped being deferrable in the
narrow sense that the lock file has already moved.

## Artifacts

- `scripts/dst/declared_vs_performed.ail` — **new.** D5's detector, probe half; arms selected by
  `--entry` because `Env` is under test.
- `scripts/dst/run_declared_vs_performed.sh` — **new.** Out-of-process half; both producers named.
- `src/core/dst_hook_guard.ail` — **new.** `routing_violation_at`'s production call site.
- `scripts/dst/hook_guard_dst.ail` — **new.** Its acceptance, driven through the guarded dispatch.
- `packages/motoko-ext-abi/types.ail` — `ExtClockReading`; `clock_now` widened.
- `src/core/session.ail` — the seam routed; `ext_unrouted_clock` deleted; S2's block tensed.
- `.agent/projects/009_motoko_dst_execution/NOTE-c5-execution-report-and-plan-corrections.md`
- Commit **`05275ab`**.
