# WI-B4 execution report — closing the repin wave, and a frontier nobody swept for

Twentieth calibration run, and the last of Milestone B. Written against HEAD `eed1d7c`, branch
`arniwesth/mot-59-execute-wi-b4`.

## Window

**~2h05m** wall-clock: `2026-08-04T19:51Z` → `2026-08-04T21:57Z`. Roughly a third of it was the two
verification steps the handoff put first, and that ordering paid for itself in the first ten minutes.

**Grounding, and this is the fifth handoff in a row to get commit state wrong — in the other
direction this time.** B2b's report says "Nothing is committed. 58 modified files plus the new
untracked `src/core/ext_world.ail`." It **was** committed, as `eed1d7c` ("Implemented"), *after* the
B4 handoff doc — so the log reads `63fa776 docs(009): hand off WI-B4` then `eed1d7c Implemented`,
which looks like B4's work already landed and is not. The tree was clean. **The handoff's own
instruction — "confirm the tree state with `git status` rather than believing any sentence in this
handoff" — is the rule that finally worked**, and it should stay exactly as written.

## The fifth frontier: 11 files, and only a sweep could see them

**The whole-tree sweep was the first thing run and it immediately refuted the wave's green claim.**
Cache-cold at HEAD: **208 pass / 28 fail**, against B2a's 218/17. **Eleven files that B2b left red**,
in two sub-classes, invisible to `make check_core` because nothing in `src/core/` imports them:

| Sub-class | Files | What |
|---|---|---|
| Un-migrated decision→outcome consumers | **6** | `compaction-ai/_smoke`, `ext_conformance/harness` + `fixtures/reject_fixtures`, `dst/conformance_registry_probe`, `dst/conformance_selftest`, `dst/long_qwen_compaction_dst` — matching on a bare `PreStepDecision` where a `PreStepOutcome` now arrives |
| `TC_ARITY_001` on `ai_step`'s new world argument | **5** | every fixture in `tools/ext_call_inventory/fixtures/` |

**B2b's commit edited five of the six in sub-class (a) and left them broken** — it changed
`hooks(... pre_step: ... -> PreStepOutcome ...)` in `reject_fixtures.ail` without migrating the three
functions passed to it, and without adding the `PreStepOutcome` import it had just started using.

**Sub-class (b) is the sharper one and it is a repeat.** Those five fixtures are the ones
**classifier 2's self-test reads**. B2a found exactly four of them the same way — "the honest sweep
earned its cost… surfaced four failures I had not seen in fifteen fixer rounds" — and B2b broke the
same five again, for the same reason: it did not sweep. **A repair loop seeded from the failing set
cannot see what its own change breaks, and that lesson has now been learned twice and lost once.**

Repaired, all eleven. Cache-cold after: **219 pass / 17 fail**, and the 17 are *byte-for-byte* B2a's
17 — 9 v0.26.0 baseline, 7 `TC_ARITY_001` smoke scripts, 1 sealing probe whose failure is its pass.
219 rather than 218 because `ext_world.ail` is new.

**One repair was more than a compile fix.** `long_qwen_compaction_dst.ail`'s `ai_step` shim called
`ports.model_step(empty_world_state(), …)` and returned `next_state: world` — the *same* fresh-empty-
world defect the fault catalogue described at the real seam, surviving in a test harness after the
real seam was fixed. It now threads `token_to_world` → `model_step` → `world_to_token`.

## The conformance decision, and it is the item's durable output

**`compaction_ai` stays OMITTED. `on_pre_step` does NOT qualify under D5 criterion 2.** Recorded in
`src/core/dst_driver_only.ail`, header and `omitted_extensions`, and the old reason is deleted rather
than annotated — a reason that has become false is worse than no reason, because it still reads as an
argument.

**Criterion 2 is a conjunction of three clauses**, and reading it as one test is how it gets passed:
*effectful only through D1 world-mediated ports*, **with** *origin tagged by extension id*, **and**
*explicit world state returned to the host*.

- **B2b bought the third, and only the third.** `PreStepOutcome.next_state` is threaded by the fold at
  `ext/runtime.ail:262-279`.
- **The second was already satisfied** and nobody had noticed: `PreStepStage = { ext_id, outcome }`
  tags origin at dispatch. So B2b's widening moved the count from one-of-three to two-of-three.
- **The first fails.** `on_pre_step`'s declared row is
  `{IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream, Trace}`, and `IO`, `FS`, `Net` and
  `Process` are not world-mediated ports.

**On the handoff's open question — whether the declared-row rule constrains criterion 1 only — the
answer is no, and the ADR's own sentence is the evidence.** It reads "**Per-hook classification** reads
*declared* effect rows in the interim, not performed ones." That is scoped to classification, full
stop; criterion 1 is its worked *example*, not its scope. And the paragraph immediately after says
why the rule has to be general: a declared row "does not bound them through function-valued record
fields at all", with a demonstration that a **rowless** function calling a port field performs effects
while declaring none. When rows bound nothing in either direction, the declared row is the only signal
there is.

**The independently sufficient argument, and it is the one to carry:** admitting `on_pre_step` under
criterion 2 **is** the claim that a hook performs less than it declares. D5 names the detector that
would license that claim — obligation 2's declared-versus-performed successor detector — and states it
is *explicitly unavailable*. It still is. WI-C5 owns it.

**Measured, and recorded because it says what C5 will find: `compaction_ai` in FACT performs effects
only through `ExtPorts.ai_step`.** `compaction_ai.ail` imports `std/ai` (a type only), `std/crypto`,
`std/json`, `std/list`, `std/option`, `std/result`, `std/string` — every one of which classifier 1
derives as **proven effect-free** — and calls no ambient builtin. **So criterion 2's first conjunct is
TRUE on performed effects and FALSE on declared ones.** The gap between those two sentences is exactly
the missing detector, and this extension is the cleanest test case it will ever get.

### The stronger claim the argument turned out to support

Chasing the four unconditionally-dispatched slots produced a result that does not depend on
`compaction_ai` at all:

> `ExtensionHooks.on_budget_plan` declares `! {Env, FS}` **in the ABI**. Rows are CLOSED, so every
> implementation declares exactly that row — there is no narrower binding available to any extension.
> `Env` and `FS` are not world-mediated, so criterion 1 fails on the declared row; `BudgetPatch` has
> no successor field, so criterion 2 fails for want of returned world state. `OnBudgetPlan` is
> **unconditionally dispatched**. D5 forbids installing an extension with any unconditionally-
> dispatched hook excluded.

**Therefore no extension in the tree is installable in a conformant profile, and `driver_only`'s empty
install list is FORCED rather than chosen.** That is a sharper statement than the header used to make,
and it is now guarded rather than asserted.

### The guard, because the old one went vacuous at exactly the wrong moment

`tools/profile_definition/check_fixtures.py` check 3 re-derived the omission from
`member_call_sites` — while `ai_step` was a classifier-2 member, `driver_only` could not silently drop
`compaction_ai`. **`ai_step` leaving the set emptied that list, so check 3 now passes because it
requires nothing.** It went from a real check to a vacuous one with no diagnostic, at the same commit
that made the omission's stated reason false. Absent reading identically to unchanged, one more time.

The replacement pins the ABI facts above, and it **prints its own vacuity** rather than letting the
green line imply coverage it no longer has:

```
  ✓ omission basis intact: on_budget_plan is Unconditional, declares ! {Env, FS},
    and returns BudgetPatch (no successor)
    → no extension is installable under D5 on declared rows; the empty install list is forced
    ! note: check 3 is now VACUOUS (zero classifier-2 member call sites).
      This check, not that one, is what holds the omission.
```

**Mutation-tested, four mutants, each killed by its own clause** (S8's sequenced-clause form: each
control rejected by its own clause and accepted by the others): drop `on_budget_plan`'s row → red;
give `BudgetPatch` a successor → red; make `OnBudgetPlan` `Gated` → red; stop omitting
`compaction_ai` → red. It goes red the day WI-C5 widens `on_budget_plan`, which is the day the
decision must be retaken rather than inherited.

## The four artifacts, and the fourth needed a version bump

| Artifact | State |
|---|---|
| The derived classifier-2 set | **2** — `env_get`, `proc_exec`; zero member call sites. Re-derived at scan-root `eed1d7c` |
| The pin (`tools/ext_call_inventory/fixtures/expected.json`) | green, **membership read** — `ai_step returns-it seam=Ports.model_step`, and now pins the **seam** as well as the state |
| `driver_only`'s omission record | **rewritten** (above); `make driver_only` exit 0 |
| `dst_fault_catalogue.ail:299-333` | **rewritten**, and it forced `fault-catalogue/1` → **`/2`** |

**The fourth was the dangerous one exactly as the handoff said, and correcting it was not prose work.**
Its `NoReachableBranch` said the seam "hands the port a FRESH EMPTY world … and the extension is told
the model answered". Both halves are now false: `ext_ports_of` decodes `ctx.world`, and B2b's
`ScriptedStep.error_code` means a scripted entry can serve `Err` — before B2b, `stub_step`'s provider
wrapped every entry in `Ok(...)` and the `provider_error_*` classes had **no scripted delivery at
all**. So the class has a real delivery **and a real recovery branch**
(`compaction_ai.compact_with_ai/summarizer_failed`, `compaction_ai.ail:514`), and
`recovery_branch: NoReachableBranch(…)` became `Branch(…)`.

**That is a content change to a row a profile reads to decide whether it may claim a class, so D8
requires the version bump.** Class ids and `applicability` are unchanged, so `conditional_class_ids()`
and every profile's waived set are unaffected — **`driver_only`'s coverage does not move.** The
coverage-gap row narrowed with it: the `ai_step` half of that gap is closed; `clock_now` (S2,
un-bridgeable) and `proc_exec` (projects the typed outcome down to a string — WI-C5's) remain.

**Coverage delta, stated rather than absorbed, per the handoff's stop condition:** `driver_only` v3 →
**v4**, for two D-rule-mandated reasons and no housekeeping — D4 (the attribution table was re-derived)
and D5/D8 (the catalogue version). Install list still empty, waived set still every conditional class,
no hook classification moved.

## A5's anchors: all ten re-derived, and nine had moved

| Anchor | Was | Now |
|---|---|---|
| `ext/runtime.ail` ambient clock | 190 | **190** (the one that matched) |
| `tool_phase.ail` mixed guard | 286 | **288** |
| `tool_phase.ail` scratchpad call | 287 | **289** |
| `session.ail` S2 un-routed ext clock | 807 | **851** |
| `stub_step.ail` live clock | 161 | **163** |
| `session.ail` routed core clock ×4 | 948, 1053, 2290, 2400 | **992, 1097, 2360, 2470** |
| `tool_phase.ail` fifth routed site | 342 | **344** |

**The D4 judgement turned out not to be a judgement, and that is worth saying plainly rather than
claiming credit for exercising one.** Each anchor had exactly one candidate at HEAD — `session.ail`
has precisely four `ports.clock_now(` call sites, `tool_phase.ail` one, and the two ambient `now()`
sites are unique in their files. The *set* did not change; only the line numbers did. Where a real
choice existed I would have had to make one; there wasn't.

The cascade fired as designed and cost what D4 says it should: the content hash moved to
`sha256:ef253d92…` at revision `eed1d7c`, `make driver_only` went red with
`[attribution-identity-stale]`, and the profile was re-issued. **That red was the rule working, and it
is the only mechanism that would have caught the drift** — nine of ten anchors were already stale
*before any Milestone B edit*, and nothing said so for four items because `make dst` exited 2 before
reaching the check.

**B2a's line-count guard now has a durable home, and it is stronger than a line count.**
`tools/predicate-anchors/anchors.sh` + `make anchors`: no compilation, milliseconds, callable every
round of a mechanical edit loop. `attribution_table` delegates to it, so there is one copy. **A line
COUNT only catches edits that change the total; this reads the anchored lines, so a one-line insertion
balanced by a one-line deletion above an anchor is caught too.** The whole reason nine anchors drifted
unnoticed is that the only thing checking them sat behind a target that never finished.

## The mutation loops, measured — and B2a's structural argument is REFUTED

**Population, derived rather than asserted:** the function rows the wave itself widened, name-matched
against their pre-wave form across `cf5a395..HEAD` — **139 rows in 45 files, 199 (row, effect)
pairs.** That is B2a's "180 across 42 files" as closely as it can be reconstructed; the difference is
rows added wholesale, which have no pre-wave row to compare against.

**Every probe cache-cold with every live cache cleared, per S9 as corrected.** Note that B2a's own
`mut2.py` cleared `.ailang/cache` — the root only — so B2a's row mutations were run on the instrument
S9 exists to condemn.

| Verdict | Pairs |
|---|---|
| LOAD-BEARING | **140** |
| INCONCLUSIVE | **51** |
| **OVER-WIDE** | **7** |
| SKIP | 1 |

**The instrument was controlled in both directions before any verdict was believed, and the first
control FAILED.** B1's three known over-widenings (`context_mode.ail:163`, `omnigraph.ail:79`, `:113`)
all read **LOAD-BEARING** at HEAD — the compiler demands the effect, checked by reading the error. So
there was no known-positive case, and *everything reading load-bearing* is precisely the inert-
instrument shape. A positive control was constructed instead: inject a spurious `Rand` into a row that
does not use it, and confirm the probe calls it OVER-WIDE. It did.

**`INCONCLUSIVE` is a verdict, not a gap, and adding it caught something.** A RED result must be red
*because of the dropped effect*; a file red for any other reason would otherwise read LOAD-BEARING and
mask a real over-wide row. All 51 are closed-row lockstep sites — `stub_ai_step`, `noop_ai_step`,
`canned_ai_step`, `poison_ai_step` — which fail with a *unification* error rather than
`Missing effects`. **The instrument separates B2a's two populations by itself.**

### The refutation, and it is this item's most transferable finding

B2a's argument — which this plan used to excuse **123 sites** from mutation testing — is that a closed
row admits exactly one width, so a lockstep site has no band where two answers type-check. Its
companion claim is that *function* rows are the risky ones because "a **wider** row type-checks fine."

**Both halves are wrong at HEAD, and the loop found the counterexample by accident while building a
control.**

**A wider function row does NOT type-check fine — it propagates.** Widen `omnigraph.handle_branch` to
`! {Process, Rand}` and its *caller* `on_tool_handle` immediately demands `Rand`, and the file is RED.
The effect checker is transitive through named helpers, so an over-wide function row is only silent if
every caller above it already declares the effect all the way up to a closed row that also declares
it. **The "silent band" the loop was scoped on is far narrower than described** — which is why 140 of
199 came back load-bearing and why B1's three are load-bearing now.

**And the closed-row guarantee has a hole: a FUNCTION-TYPED PARAMETER.** All seven OVER-WIDE findings
are the same shape and nothing else was found:

```
reject_fixtures.ail::hooks -Trace          scripted_cursor_probe.ail::hooks, ::rt_with -Trace
world_state_probe.ail::hooks, ::rt_with    smoke_v2_compaction_chain.ail::base_hook
ext/runtime.ail::chain_base_hook -Trace
```

Reproduced and confirmed tree-wide: `ext/runtime.ail:545`'s
`chain_base_hook(id, pre: (ExtCtx, [Msg]) -> PreStepOutcome ! {…})` assigns `pre` straight into
`on_pre_step`, whose ABI row is **closed and includes `Trace`**. Drop `Trace` from that *parameter's*
row and `ailang check` is green **and `make check_core` is green, 52/52**. **Two widths type-check and
the narrower one is silent — in exactly the population B2a declared structurally incapable of it.**

**All seven are deliberately held at the full row** and the finding is recorded at
`packages/motoko-ext-abi/types.ail` beside `PreStepOutcome`, where the guarantee is about, so a future
tidy-up does not narrow them. It is the declaration-side view of `fb_74f53de3ae65854c`, which D5
already records from the performed side.

**B1's 20 and B3's 64, as the handoff asked.** B1's 20 cascade-site files: **covered** — all are in the
45 and all their widened rows are in the 199. B3's 64 `images` sites: **not covered by this loop and
not coverable by it** — `images` is a record-field question, not an effect row, and B2a repaired the
8 that were reachable. The remaining ones are behind the same absent-file frontier; they are
type-checked by the sweep (219/17) and that is the honest extent of it.

## S12: the instrument exists, and the counter B2b said was missing was already in the token

B2b wrote that a real instrument "needs a counter the `ExtWorld` does not carry." **That is wrong, and
it is the reason this could be built.** `WorldState.log` is D2's ordered record of every request the
driver made, `record_interaction` appends to it at every recorded seam, and `world_json`/`world_of_json`
round-trip it in full — asserted field by field by the codec tests B2b itself wrote. **A hook that
performed a recorded call returns a world with a longer log; one that returned `ctx.world` returns one
of exactly the same length.** Distinguishable, mechanically, from the token alone.

Shipped in `src/core/ext_world.ail`:

```ailang
world_interaction_count(t)                       -- the counter
world_advanced(before, after)                    -- log growth
dropped_successor(before, after, performed)      -- performed && not advanced
```

**One-directional by design.** `advanced == false` proves nothing alone — a hook that legitimately did
nothing also returns an unchanged world, and S12 says that identity transition is *correct*. The caller
supplies "did it perform a call"; the predicate supplies the rest.

Four unit tests, and **three mutants, each killed by its own row**: make the predicate ignore
advancement → the detection row dies; make it ignore `performed_a_call` → the identity-transition row
dies; make the codec drop the log → the counter rows die.

**And it is wired to the one hook in the tree that actually calls `ai_step`.**
`compaction.compaction_ai_successor_is_not_dropped` in `long_qwen_compaction_dst.ail` drives the real
`compact_with_ai` through `stub_step.recording_ports` and asserts **both** directions — over threshold
the summarizer runs and the world must advance; under threshold nothing runs and the identity
transition must not be reported as a defect.

**C5 on the wired check, against B2b's actual defect:** rewrite `compaction_ai`'s four
`next_state: s.next_state` returns to `next_state: ctx.world` — the exact re-wrap B2b found and
mitigated with a comment — and the scenario goes red with
`hot_advanced=false hot_log_in=0 hot_log_out=0`. **The mitigation is now a check.**

## Gate state

- **`make check_core` — EXIT 0.** `src/core/` **52 passed, 0 failed**, cache-cold.
- **Whole-tree sweep — 219 pass / 17 fail**, cache-cold with S9's corrected command and both
  exclusions. The 17 are identical to B2a's, member for member.
- **`make dst` — EXIT 2, with TWO red targets**, down from six at the start of this item and three at
  B2a. 26 suite PASS markers. Both remaining reds are pre-existing and neither is this milestone's
  class:
  - **`test_coverage`** — `src/core/prompts_test.ail: 0/6`, `LDR001: module not found`. B2a measured
    it deterministic across three runs; it is a working-directory/module-resolution failure in
    `ailang test`, not a repin artifact.
  - **`test_coverage_selftest`** — `stale_skip_record` (a skip reason reading
    `Named test blocks not yet implemented`) and a `named_only.ail` finding.
- **Four targets went from red to green in this item:** `terminal_trace`, `driver_only`,
  `attribution_table`, `profile_definition` — plus `run_report` and `program_persistence`, which this
  item turned red and then fixed (below).
- **`make ext_call_inventory_selftest` — exit 0, membership read**, not inferred from the exit code.
- **`make effect_inventory_selftest` — NOW RED, deliberately, and it is a finding (below).**

### `terminal_trace`'s red was a guard false-positive, and tightening it cost no coverage

`FAIL: 3 terminal record literals in session.ail, expected 1`. The guard greps `^[^-]*{ result:` as a
proxy for "a `TracedSessionResult` literal", and B2b introduced a second record that also opens
`{ result:` and is not one — `ExtAiStepResult`, its declaration and the `ai_step` bridge that builds
one. **It named a bypassing terminal return that does not exist.**

Narrowed on a property the terminal record **cannot** have: `TracedSessionResult` is
`{ result, trace, world }` and has no `next_state` field, while every record B2b added does. Lines
carrying `next_state:` — with the colon, which `world: reading.next_state` does not have — are
excluded. **Verified in both directions with the same two plausible bypassing shapes the previous
tightening used: 1 at HEAD, 3 with an inline and a multi-line bypassing return added.**

### Two targets this item broke and fixed, and one of them caught me correctly

- **`program_persistence`.** The sweep of stale `ailang 0.26.0` manifest strings rewrote the **frozen
  v1 specimen** too, and the gate went red with exactly the right complaint: *"the frozen v1 specimen
  decodes to a DIFFERENT program: manifest.toolchain ('ailang 0.33.0 (pinned)' vs 'ailang 0.26.0
  (pinned)') — this build silently reinterprets an old artifact, which is what D8 forbids."*
  **Reverted, with the reason written at the site.** A frozen specimen is a historical artifact, not a
  live claim; it is pinned to v0.26.0 forever. **This is the only place in the run where a gate caught
  a real defect of mine, and it caught it immediately.**
- **`run_report`.** `test_no_reachable_branch_becomes_a_structural_gap` read `extension_effect_fault`
  out of the **live** catalogue, which happened to be the one class carrying `NoReachableBranch`.
  Giving that class a real branch left the test red having found nothing wrong with the mechanism it
  exists to check. **Rewritten onto its own fixture**, plus a new control asserting the same builder
  does *not* report a structural gap for a class that has a branch. **A test keyed on whichever row
  currently happens to have the shape is a test whose subject can be legislated away**, and an empty
  `NoReachableBranch` set is good news about the system rather than a reason to stop checking.

## Classifier 1 fails open on this pin, and its self-test certified NOTHING

**The highest-value finding after the sweep, and both targets were exiting 0 over it.**

`make effect_inventory` reports **46 INTERFACE FAILURES**, every stdlib module, each "resolved by
textual fallback". At v0.26.0 there was **one** (`std/secret`) and `make effect_inventory_selftest`
reported **`agree=43 disagree=0`**. At v0.33.0 it reports **`agree=0 disagree=0`** — and the old
`return 1 if disagree else 0` called that a **pass**.

**So the textual fallback became the sole derivation for all 46 modules at the same moment the check
that makes it trustworthy stopped checking anything.** A17's site 32 verbatim: a control that must
survive certifies nothing if the mechanism never reached it.

The derived answer is unchanged (13 effect-bearing, 8 proven effect-free, 0 unresolved, scan-root
commit matching), so nothing downstream is known to be wrong — but it is now unvalidated, and that had
to become visible. **Zero comparisons is now a FAILURE.** `make effect_inventory_selftest` is
consequently RED, deliberately, and that red is the accurate state.

**The cause is an AILANG defect and it needs filing.** `ailang iface <abs path>` fails `MOD010` for
every installed stdlib module, and **names two escape hatches in its own error message, neither of
which works for that subcommand**: `AILANG_RELAX_MODULES=1` is ignored by `iface`, and
`--relax-modules` is not a defined flag for it (`flag provided but not defined: -relax-modules`).

## Classifier 2 now has the positive control the handoff asked for

`control_resolved.ail` proves the **call-site matcher** works; nothing proved that `bridge_map` still
follows `ext_ports_of` down to a core `Ports` seam. **That is the half that fails open** — a parsing
slip returns `unrouted` for everything, which reads like a clean result while meaning the field has
left the gated set. B2b hit it twice in one item.

Two changes, and the second is what the pin could never have caught:

1. The membership pin carries **`seam`** beside `state`. `"seam": null` is legitimate only for a
   genuinely unrouted field (`clock_now`, per S2).
2. A **bridge positive control**: if not one `ExtPorts` field resolves to a core seam, that is a
   parsing slip, not an empty bridge.

**Mutation-tested, and the second mutant is the new coverage:**

| Mutant | Result |
|---|---|
| Re-inline the token conversion (B2b's nested-paren slip) | RED — `ai_step: expected returns-it, derived unrouted` |
| Point the bridge at the **wrong** core seam | RED — `state returns-it agrees but the BRIDGE SEAM moved: expected Ports.model_step, derived Ports.tool_exec` |

**The old pin could not have caught the second**: state stays `returns-it` and nothing moves.

## `fb_2ad074d754cd2c25` does not reproduce on v0.33.0

Re-created identically — the same one-line test with the same body appended to `dst_invariants.ail` —
and run ten times: **0 failures in 10**, against **6-in-10** on v0.26.0 measured twice independently.
**Checked that the probe RAN**, because absent and passing are the same observation: every run reported
`9 tests: 9 passed` with the probe named and green. Source restored; `dst_invariants.ail` byte-identical
to HEAD.

**Not closed on this evidence.** 0-in-10 against a 60% base rate is strong, but the defect was never
minimised and its trigger was never understood, so "fixed" and "perturbed out of reach by an unrelated
change" are not distinguishable from here. The issue file now says *not reproducing on the current
pin*, and the workaround comment in the `Makefile` stays.

## Sites where two answers type-checked and one was silently wrong: 4 found, 3 fixed, 1 held

**Running total 39 → 43 across twenty runs. Determinism has still caught none.**

1. **The seven function-typed parameter rows** (counted as one site class, above). Two widths
   type-check; the narrower is silent; `check_core` is green either way. **Held wide deliberately** and
   documented at the ABI — this is the one that is *not* fixed, because the fix is upstream.
2. **`long_qwen_compaction_dst`'s `ai_step` shim** returning `next_state: world` after calling
   `model_step` with a fresh empty world. Type-checks perfectly. **Fixed.**
3. **`reject_fixtures.nocache_pre_step`** — the tree's *other* `ai_step` caller. Writing
   `next_state: ctx.world` there type-checks and replays the consumed script entry. **Written correctly
   and annotated**, and it is now the second site the S12 instrument would catch.
4. **The frozen v1 specimen's toolchain string.** Both values type-check and both look like the same
   kind of fact; one is a live claim and one is a historical record. **Caught by `program_persistence`,
   which is the one gate that fired on my own work.**

## Recorded bindings: decided versus discovered

**Discovered — the compiler, a tool or a gate forced it and I transcribed:**

1. Every one of the eleven fifth-frontier repairs.
2. All ten re-derived anchor line numbers, and the attribution content hash `sha256:ef253d92…`.
3. The frozen specimen's toolchain revert — `program_persistence` refused the edit.
4. The `run_report` test's rewrite — the catalogue change removed its subject.
5. **The function-typed-parameter hole.** Measured, not reasoned to; found while building a control
   for something else.

**Decided — a human chose:**

1. **`compaction_ai` stays omitted, on the declared-row reading of criterion 2.** The argument above.
2. **Bumping `fault-catalogue` to /2 and `driver_only` to v4** rather than leaving the prose stale.
3. **Tightening `terminal_trace`'s proxy** on a property the terminal record cannot have, rather than
   renaming B2b's fields or silencing the guard.
4. **Making `effect_inventory_selftest` red** rather than letting `agree=0 disagree=0` read as a pass.
5. **Holding the seven parameter rows wide** and documenting, rather than narrowing to the minimum the
   compiler accepts.
6. **`make anchors` as a separate fast target**, so the guard is cheap enough to run every round.
7. **NOT touching the 7 `TC_ARITY_001` smoke scripts** — still a behavioural decision, still nobody's
   to take silently, and B2a's argument that they are superseded rather than broken is unchanged.
8. **NOT bumping package versions or `[effects]` ceilings.** The ABI is now at three changed rows plus
   a shape change across B1/B2a/B2b; **the `motoko-ext-abi` major and its lockstep re-release are still
   owed** and are still the plan's call. No package declares `Trace` or `Rand` in its ceiling.

## Corrections owed to the plan

1. **B2a's closed-row argument is REFUTED for function-typed parameters, and S12's companion claim
   about function rows is refuted too.** A wider function row does *not* type-check fine — it
   propagates to callers. And a closed record field *does* admit two widths when the value arrives
   through a function-typed parameter, measured at `ext/runtime.ail:545` with `check_core` green both
   ways. The 123 lockstep sites are still mostly safe, but "no band exists" is too strong.
2. **The stale-toolchain-string count is 14, not 13** — 8 via `driver_only_manifest`, **6** inline (the
   handoff says 5). A fifteenth occurrence in `dst_secrets.ail:736` is *scan text* for a secrets rule,
   not a toolchain claim, and is correctly left alone. **And one of the 14 must not be rewritten**: the
   frozen v1 specimen in `program_persistence_dst.ail`.
3. **Classifier 1's self-test certifies nothing on v0.33.0**, and the underlying `ailang iface` MOD010
   failure with two non-working documented workarounds should be filed upstream.
4. **S9's exclusion rationale is stale and the history is worth recording.** `tools/code-graph`'s
   fixture cache directories are **empty and untracked at HEAD**: B2a's commit `7bca61c` accidentally
   added 34 such files and B2b's `eed1d7c` **deleted all of them** — B2b's `sweep.sh` has no
   `tools/code-graph` exclusion, which is precisely the hazard S9 names, and the deletion was committed.
   Keep the exclusion (`.gitignore:54` un-ignores `tools/code-graph/**`, so anything compiled there
   becomes tracked), but do not describe those files as currently committed.
5. **A mutation loop must not run concurrently with editing.** The loop restores each file from a
   snapshot taken at probe start, so an edit made during a probe of the same file is silently reverted
   — it clobbered one edit and left one file mutated, caught only by the final sweep. Run it to
   completion, or scope the edits away from its queue.
6. **Say "the D4 judgement was not a judgement" when it wasn't.** Every anchor had exactly one
   candidate; claiming to have exercised judgement would misdescribe the evidence for the next reader.
7. **`.gitignore:54`'s `!tools/code-graph/**` is a live trap, not just a sweep hazard.** Any whole-tree
   sweep compiles `tools/code-graph/tests/fixtures/**/*.ail` and writes `.ailang/cache` directories
   there, and because that line un-ignores the whole subtree they appear as **untracked build output
   asking to be committed** — which is exactly how B2a came to commit 34 of them. They are left
   untracked here, deliberately, and neither added nor deleted. The durable fix is a narrower
   un-ignore or an explicit `tools/code-graph/**/.ailang/` ignore, and it is a one-line change nobody
   has made in three items.

## Deliberately not done

- **The 7 `TC_ARITY_001` smoke scripts** — argued above, unchanged from B2a.
- **Package versions, `[effects]` ceilings, and the `motoko-ext-abi` major** — still owed, still the
  plan's.
- **The two v0.33.0-fixed defect workarounds** (`fb_e44ba922db1c42be`, `fb_b39697480a4e8bbc`) — each
  carries a comment pointing at its issue file; a deliberate item.
- **`ExtPorts.proc_exec` / `env_get` widening** — WI-C5's, deliberately left as live classifier-2
  members so C5 keeps a real target.
- **Filing the `ailang iface` MOD010 defect upstream** — measured and written up here; the filing
  itself is a separate action.
- **Milestone C entirely.**

## Closing view of Milestone B — and what C needs that no item report says

**Four items, five frontiers.** Effect rows (B1), `images` (B3), the third frontier — compose's row,
`live_ports`, `GeneratorBounds` (B2a) — the world token's shape cascade (B2b), and **this one: eleven
files nothing compiled.** Each was invisible behind the last, and **the fifth differs in kind from the
other four.** The first four were found by a compiler that could not reach them yet. **The fifth was
found by nobody for two items, because `check_core` is a subset gate and the only instrument that sees
the whole tree — the sweep — is the one step every item under budget pressure drops.** B2b dropped it
and said so; B4 ran it first and it was the highest-yield ten minutes of the run.

**The pattern under all five, and it is the milestone's real lesson:** absent reads identically to
unchanged. It appeared as unreachable files (B1, B3), as `make dst` exiting before the anchor check
(nine anchors stale for four items), as `agree=0 disagree=0` (classifier 1 certifying nothing), as a
`member_call_sites` list going empty (check 3 becoming vacuous), and as `derive.py`'s `unrouted`
(a fail-open that looks like a pass). **Five instruments, one failure mode, and in every case the exit
code was 0.** The remedy that worked every time was the same: make the check report what it *saw*, not
only what it *found*.

**What Milestone C needs that no item report says.**

**C is where the name is earned, and the name is a claim about coverage that nothing currently
measures.** Three things are true simultaneously and no report puts them together:

1. **`driver_only` covers nothing, and that is now provable rather than circumstantial.** The
   `on_budget_plan` argument means no extension is installable under D5 on declared rows. So every
   D5 mechanism — the coverage floor, per-hook disclosure, the exclusion check — is **vacuously
   satisfied**, and `driver_only_dst` says so in its own output for the exclusion check. C4's name gate
   will be asked to bless a profile whose entire extension surface is empty by construction.
2. **The one thing that would change that is the detector D5 already names and defers** — declared-
   versus-performed reconciliation. `compaction_ai` is the measured proof it would work: it performs
   effects *only* through `ExtPorts.ai_step` and declares nine it does not perform. **C5 is not a
   tidy-up of two un-widened ports; it is the item that decides whether any extension can ever be
   covered.** Widening `proc_exec` and `env_get` without it changes nothing about installability.
3. **The type system will not hold the line C assumes it holds.** The function-typed-parameter hole
   means a hook can be assigned into a closed ABI row while declaring less than that row — so
   "declared rows are the interim signal" is a weaker guarantee than D5 supposes, and C5's detector
   cannot be built on declarations alone.

**And the practical one: whoever takes C will be reading D1's acceptance table for the first time in a
long while, and should read it before C1.** C1 adopts the recorded-stream API in one `live_ports`
closure; C2 is the positive integration probe that is D1's *actual* gate evidence. **B2b's
`ScriptedStep` fault/latency widening quietly moved C2's starting line**: the `provider_error_*`
classes now have scripted delivery, which they did not before, and `extension_effect_fault` now has a
reachable branch. C2 can assert more than its handoff will say it can — and the emission log is still
unconditionally `[]` until C1 lands, which is the one thing D1 names as its own trap.
