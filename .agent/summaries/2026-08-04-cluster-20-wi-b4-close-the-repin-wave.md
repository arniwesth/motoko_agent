# 2026-08-04 Cluster 20: WI-B4 — closing the repin wave, and a frontier nobody swept for

## Context

Branch: `arniwesth/mot-59-execute-wi-b4`.

Session span: `eed1d7c` → **uncommitted working tree, 36 modified files + 2 new untracked files**
(`tools/predicate-anchors/anchors.sh`, the execution note). Input was
`HANDOFF-execute-b4-close-the-repin-wave.md`, executed cold against HEAD. Twentieth code session of
project 009, and **the last of Milestone B**. Pin **v0.33.0**.

**Window: ~2h05m**, `19:51Z` → `21:57Z`. Roughly a third was the two verification steps the handoff
put first, and that ordering paid for itself in the first ten minutes.

| Definition-of-done item | State |
|---|---|
| `make check_core` exit 0 | **met** — 52 passed, 0 failed, cache-cold |
| Whole-tree sweep, cache-cold, S9's corrected command | **met** — 219 pass / 17 fail |
| `make dst` status reported, each red attributed | **met** — exit 2, **two** reds, both pre-existing |
| Both classifiers re-derived, sets + scan-root commit re-recorded | **met** |
| `ext_call_inventory_selftest` green **with membership read** | **met** — read, not inferred from exit code |
| All four artifacts agree, conformance decision recorded | **met** — and it forced two version bumps |
| Mutation loops over the function rows, stated as measured or unmeasurable | **met** — 199 pairs, and B2a's premise refuted |
| A5's ten anchors re-derived | **met** — nine had moved |
| S12: build the instrument, or say the mitigation is weaker | **built**, and wired to the real hook |

## Grounding correction, and it is the fifth consecutive one — in the other direction

B2b's report says "Nothing is committed. 58 modified files plus the new untracked
`src/core/ext_world.ail`." **It was committed afterwards, as `eed1d7c` ("Implemented") — after the B4
handoff doc.** So the log reads `63fa776 docs(009): hand off WI-B4` then `eed1d7c Implemented`, which
looks like B4's work already landed and is not. The tree was clean.

Five for five now, and **the handoff's own instruction is the rule that finally worked**: "confirm the
tree state with `git status` rather than believing any sentence in this handoff." Keep it exactly as
written.

## The headline: the sweep found an eleven-file frontier that two items had walked past

**The whole-tree sweep ran first and immediately refuted the wave's green claim.** Cache-cold at HEAD:
**208 pass / 28 fail**, against B2a's 218/17. Eleven files B2b left red, in two sub-classes, invisible
to `make check_core` because nothing in `src/core/` imports them:

| Sub-class | Files | What |
|---|---|---|
| Un-migrated decision→outcome consumers | **6** | matching on a bare `PreStepDecision` where a `PreStepOutcome` now arrives |
| `TC_ARITY_001` on `ai_step`'s new world argument | **5** | every fixture in `tools/ext_call_inventory/fixtures/` |

B2b's commit had **edited five of the six** in sub-class (a) and left them broken — it changed
`reject_fixtures.hooks` to take a `PreStepOutcome` without migrating the three functions passed to it,
and without adding the import it had started using.

**Sub-class (b) is the sharper one and it is a repeat.** Those are the fixtures classifier 2's
self-test reads. **B2a found four of the same five the same way**, one item earlier — "the honest
sweep earned its cost… surfaced four failures I had not seen in fifteen fixer rounds" — and B2b broke
them again, for the same reason: it did not sweep. *A repair loop seeded from the failing set cannot
see what its own change breaks*, learned twice and lost once.

All eleven repaired. Cache-cold after: **219 / 17**, and the 17 are byte-for-byte B2a's 17.

**One repair was more than a compile fix.** `long_qwen_compaction_dst.ail`'s `ai_step` shim called
`ports.model_step(empty_world_state(), …)` and returned `next_state: world` — the *same* fresh-empty-
world defect the fault catalogue described at the real seam, surviving in a test harness after the
real seam was fixed.

## The conformance decision, which is the item's durable output

**`compaction_ai` stays OMITTED. `on_pre_step` does NOT qualify under D5 criterion 2.**

The handoff's open question was whether the declared-row rule constrains criterion 1 only. **It does
not.** The ADR reads "**Per-hook classification** reads *declared* effect rows in the interim" —
scoped to classification, full stop; criterion 1 is its worked *example*. The paragraph after it says
why the rule must be general: a declared row "does not bound them through function-valued record
fields at all."

Criterion 2 is a **conjunction of three clauses**, and reading it as one test is how it gets passed:

- **B2b bought the third, and only the third** — `PreStepOutcome.next_state`, threaded at
  `ext/runtime.ail:262-279`.
- **The second was already satisfied** and nobody had noticed — `PreStepStage = { ext_id, outcome }`.
- **The first fails** — the declared row carries `IO`, `FS`, `Net`, `Process`, none world-mediated.

**The independently sufficient argument:** admitting it under criterion 2 *is* the claim that a hook
performs less than it declares, and D5 names the detector that would license that claim as explicitly
unavailable. It still is.

**Measured, and recorded because it says what C5 will find:** `compaction_ai` in fact performs effects
**only** through `ExtPorts.ai_step` — it imports `std/ai` (a type only), `std/crypto`, `std/json`,
`std/list`, `std/option`, `std/result`, `std/string`, every one derived by classifier 1 as *proven
effect-free*, and calls no ambient builtin. **Criterion 2's first conjunct is TRUE on performed
effects and FALSE on declared ones**, and that gap is exactly the missing detector.

### The stronger claim it turned out to support

`ExtensionHooks.on_budget_plan` declares `! {Env, FS}` **in the ABI**; rows are closed, so every
implementation declares exactly that. `Env`/`FS` are not world-mediated (criterion 1 fails);
`BudgetPatch` has no successor field (criterion 2 fails). `OnBudgetPlan` is **unconditionally
dispatched**, and D5 forbids installing an extension with any unconditionally-dispatched hook excluded.

**So no extension in the tree is installable in a conformant profile, and `driver_only`'s empty install
list is FORCED rather than chosen.**

### The guard, because the old one went vacuous at exactly the wrong moment

`check_fixtures.py` check 3 re-derived the omission from `member_call_sites`. **`ai_step` leaving the
classifier-2 set emptied that list, so check 3 now passes because it requires nothing** — it went from
a real check to a vacuous one, with no diagnostic, at the same commit that made the omission's stated
reason false.

The replacement pins the ABI facts above and **prints its own vacuity** rather than letting a green
line imply coverage it no longer has. **Four mutants, each killed by its own clause** (S8's
sequenced-clause form).

## The four artifacts, and the fourth needed a version bump

| Artifact | Outcome |
|---|---|
| Derived classifier-2 set | **2** — `env_get`, `proc_exec`; zero member call sites; scan-root `eed1d7c` |
| The pin | green, **membership read**; now pins the **seam** as well as the state |
| `driver_only`'s omission record | **rewritten**; `make driver_only` exit 0 |
| `dst_fault_catalogue.ail:299-333` | **rewritten**, forcing `fault-catalogue/1 → /2` |

**The fourth was the dangerous one exactly as the handoff said, and it was not prose work.** Its
`NoReachableBranch` said the seam "hands the port a FRESH EMPTY world … and the extension is told the
model answered." Both halves are false now: `ext_ports_of` decodes `ctx.world`, and B2b's
`ScriptedStep.error_code` means a scripted entry can serve `Err` — before B2b, `stub_step`'s provider
wrapped every entry in `Ok(...)` and the `provider_error_*` classes had **no scripted delivery at
all**. The class has a real delivery and a real recovery branch
(`compaction_ai.compact_with_ai/summarizer_failed`), so `NoReachableBranch` became `Branch`.

**Version bumps, stated rather than absorbed:** `fault-catalogue/2`, and `driver_only` **v3 → v4** for
two D-rule-mandated reasons (D4's table re-derivation, D5/D8's catalogue version). **Coverage did not
move** — install list still empty, waived set still every conditional class.

## A5's anchors: all ten re-derived, nine had moved

`ext/runtime.ail:190` held; `tool_phase` 286/287/342 → 288/289/344; `session.ail` 807 → 851;
`stub_step` 161 → 163; `session.ail`'s four routed clock sites 948/1053/2290/2400 → 992/1097/2360/2470.

**The D4 judgement turned out not to be a judgement, and saying so plainly matters more than claiming
credit.** Each anchor had exactly one candidate at HEAD. The *set* did not change; only the lines did.

The cascade fired as designed and cost what D4 says it should: content hash → `sha256:ef253d92…`,
`make driver_only` went red with `[attribution-identity-stale]`, profile re-issued. **That red was the
rule working** — nine of ten anchors were already stale *before any Milestone B edit*, and nothing said
so for four items because `make dst` exited 2 before reaching the check.

**B2a's line-count guard now has a durable home and is stronger than a line count.**
`tools/predicate-anchors/anchors.sh` + `make anchors`: no compilation, milliseconds, callable every
round; `attribution_table` delegates to it, so there is one copy. A line *count* only catches edits
that change the total; this reads the anchored lines.

## The mutation loops — and B2a's structural argument is REFUTED

Population derived rather than asserted: the function rows the wave itself widened, name-matched
across `cf5a395..HEAD` — **139 rows in 45 files, 199 (row, effect) pairs**, every probe cache-cold with
every live cache cleared. (B2a's own `mut2.py` cleared the root cache only — the instrument S9 exists
to condemn.)

**140 LOAD-BEARING · 51 INCONCLUSIVE · 7 OVER-WIDE · 1 SKIP**

**The first control FAILED and that is why anything here is trustworthy.** B1's three known
over-widenings all read LOAD-BEARING at HEAD, so there was no known-positive case — and *everything
reading load-bearing* is the inert-instrument shape. A positive control was constructed instead
(inject a spurious `Rand`, confirm the probe calls it over-wide). `INCONCLUSIVE` was added as a real
verdict so a file red for an unrelated reason cannot mask a genuine over-wide row; all 51 are
closed-row lockstep sites failing with a *unification* error, so **the instrument separates B2a's two
populations by itself**.

### The refutation

- **A wider function row does NOT type-check fine — it propagates.** Widen `omnigraph.handle_branch`
  and its *caller* immediately demands the effect. The effect checker is transitive through named
  helpers, so the "silent band" the loop was scoped on is far narrower than described — which is why
  140 of 199 came back load-bearing.
- **The closed-row guarantee has a hole: a FUNCTION-TYPED PARAMETER.** All seven over-wide findings
  are that one shape. `ext/runtime.ail:545`'s `chain_base_hook(id, pre: … ! {…})` assigns `pre`
  straight into `on_pre_step`, whose ABI row is closed and includes `Trace`. Drop `Trace` from the
  *parameter's* row and `ailang check` is green **and `make check_core` is green, 52/52**. Two widths
  type-check, in exactly the population B2a declared structurally incapable of it.

All seven are **held wide deliberately** and the finding is recorded at `motoko-ext-abi/types.ail`.

## S12: the instrument exists, and the counter B2b said was missing was already in the token

B2b wrote that a real instrument "needs a counter the `ExtWorld` does not carry." **Wrong, and that is
why this could be built.** `WorldState.log` is D2's ordered record, `record_interaction` appends at
every recorded seam, and the codec round-trips it in full — asserted field by field by B2b's own tests.

Shipped in `ext_world.ail`: `world_interaction_count`, `world_advanced`, `dropped_successor`.
**One-directional by design** — the caller supplies "did it perform a call", the predicate supplies the
rest, because an identity transition is *correct* for a hook that did nothing.

Four unit tests; **three mutants, each killed by its own row**. And **wired to the one hook in the tree
that actually calls `ai_step`**: `compaction.compaction_ai_successor_is_not_dropped` drives the real
`compact_with_ai` through `recording_ports` and asserts both directions. **C5 against B2b's actual
defect** — rewrite the four `next_state: s.next_state` returns to `ctx.world` and the scenario goes red
with `hot_advanced=false hot_log_in=0 hot_log_out=0`. The mitigation is now a check.

## Classifier 1 fails open on this pin, and its self-test certified NOTHING

`make effect_inventory` reports **46 interface failures** — every stdlib module — each "resolved by
textual fallback". At v0.26.0 there was **one**, and the self-test reported `agree=43 disagree=0`. At
v0.33.0 it reports **`agree=0 disagree=0`**, and the old `return 1 if disagree else 0` called that a
pass. **The fallback became the sole derivation for all 46 modules at the same moment the check that
makes it trustworthy stopped checking anything.**

**Zero comparisons is now a FAILURE**, so `make effect_inventory_selftest` is red, deliberately, and
that red is the accurate state. The cause is an AILANG defect worth filing: `ailang iface <abs path>`
fails `MOD010` for every stdlib module and **names two escape hatches in its own error message,
neither of which works for that subcommand**.

## Classifier 2 now has the bridge positive control

`control_resolved.ail` proves the call-site matcher works; nothing proved `bridge_map` still follows
`ext_ports_of` to a core seam — the half that fails open. The pin now carries **`seam`** beside
`state`, plus a control for "not one field resolved". **Mutation-tested, and the second mutant is the
new coverage:** re-inlining the token conversion → `unrouted` (red); pointing the bridge at the *wrong*
seam → red with `the BRIDGE SEAM moved`. **The old pin could not have caught the second.**

## `fb_2ad074d754cd2c25` does not reproduce on v0.33.0

**0 failures in 10**, against 6-in-10 on v0.26.0 measured twice independently. **Checked that the probe
RAN** — every run reported `9 tests: 9 passed` with the probe named and green — because absent and
passing are the same observation. **Not closed**: the defect was never minimised, so "fixed" and
"perturbed out of reach" are not distinguishable from here.

## Gate state

- **`make check_core` — exit 0**, 52/52, cache-cold.
- **Whole-tree sweep — 219 / 17**, cache-cold, S9's corrected command with both exclusions.
- **`make dst` — exit 2, TWO red targets**, down from six at the start and three at B2a. 26 suite PASS
  markers. Both remaining reds are pre-existing and neither is this milestone's class: `test_coverage`
  (`prompts_test.ail: 0/6`, `LDR001`) and `test_coverage_selftest` (`stale_skip_record`, `named_only`).
- **Four targets went red → green**: `terminal_trace`, `driver_only`, `attribution_table`,
  `profile_definition`.

### Two targets this item broke and fixed, and one caught me correctly

- **`program_persistence`.** The toolchain-string sweep rewrote the **frozen v1 specimen** too, and the
  gate went red with exactly the right complaint — *"the frozen v1 specimen decodes to a DIFFERENT
  program … this build silently reinterprets an old artifact, which is what D8 forbids."* Reverted,
  with the reason at the site. **The only gate that fired on my own work, and it fired immediately.**
- **`run_report`.** `test_no_reachable_branch_becomes_a_structural_gap` read the **live** catalogue,
  which happened to be the one class carrying `NoReachableBranch`. Rewritten onto its own fixture, plus
  a control for the opposite case. **A test keyed on whichever row currently has the shape is a test
  whose subject can be legislated away.**

### `terminal_trace`'s red was a guard false-positive

`3 terminal record literals … expected 1`. The guard greps `^[^-]*{ result:` as a proxy for a
`TracedSessionResult` literal, and B2b introduced a second record that also opens `{ result:`.
Narrowed on a property the terminal record **cannot** have (`next_state:`), and **verified in both
directions with the same two plausible bypassing shapes the previous tightening used**: 1 at HEAD, 3
with them added.

## Sites where two answers type-checked and one was silently wrong

**4 found, 3 fixed, 1 held. Running total 39 → 43 across twenty runs. Determinism has caught none.**

1. The seven function-typed parameter rows — **held**, the fix is upstream.
2. `long_qwen`'s `ai_step` shim returning `next_state: world` after a real call — fixed.
3. `reject_fixtures.nocache_pre_step`, the tree's other `ai_step` caller — written correctly and
   annotated.
4. The frozen v1 specimen's toolchain string — caught by `program_persistence`.

## Corrections owed to the plan

1. **B2a's closed-row argument is refuted for function-typed parameters**, and its companion claim
   that a wider function row type-checks fine is refuted too.
2. **The stale-toolchain count is 14, not 13** — 8 via `driver_only_manifest`, **6** inline. A
   fifteenth in `dst_secrets.ail:736` is scan text, correctly left alone. **And one of the 14 must not
   be rewritten**: the frozen v1 specimen.
3. **Classifier 1's self-test certifies nothing on v0.33.0**; the `ailang iface` MOD010 defect should
   be filed upstream.
4. **S9's exclusion rationale is stale.** `tools/code-graph`'s fixture cache dirs are empty and
   untracked at HEAD: B2a's commit added 34 such files, **B2b's deleted all of them** (its `sweep.sh`
   has no `tools/code-graph` exclusion — the exact hazard S9 names). Keep the exclusion; stop calling
   those files committed.
5. **A mutation loop must not run concurrently with editing.** It restores from a snapshot taken at
   probe start, so a concurrent edit to the same file is silently reverted — it clobbered one edit and
   left one file mutated, caught only by the final sweep.
6. **Say "the D4 judgement was not a judgement" when it wasn't.**
7. **`.gitignore:54`'s `!tools/code-graph/**` is a live trap**: any sweep writes `.ailang/cache` there
   and it appears as untracked build output asking to be committed. One-line fix, unmade for three
   items.

## Deliberately not done

- The 7 `TC_ARITY_001` smoke scripts — a behavioural decision, unchanged from B2a.
- Package versions, `[effects]` ceilings, and the `motoko-ext-abi` major — still owed, still the plan's.
- The two v0.33.0-fixed defect workarounds.
- `ExtPorts.proc_exec` / `env_get` widening — WI-C5's, left as live classifier-2 members.
- Filing the `ailang iface` defect upstream — measured and written up; the filing is a separate action.
- Milestone C entirely.

## Closing view of Milestone B, and what C needs that no item report says

**Four items, five frontiers**: effect rows (B1), `images` (B3), the third frontier (B2a), the world
token's shape cascade (B2b), and **eleven files nothing compiled** (B4). **The fifth differs in kind.**
The first four were found by a compiler that could not reach them yet; **the fifth was found by nobody
for two items, because `check_core` is a subset gate and the only instrument that sees the whole tree
is the step every item under budget pressure drops.**

**The pattern under all five is one failure mode: absent reads identically to unchanged.** Unreachable
files; `make dst` exiting before the anchor check; `agree=0 disagree=0`; `member_call_sites` going
empty; `derive.py`'s `unrouted`. **Five instruments, one failure mode, exit code 0 every time.** The
remedy that worked every time was the same: make the check report what it *saw*, not only what it
*found*.

**What C needs, and no item report puts these three together:**

1. **`driver_only` covers nothing, and that is now provable rather than circumstantial.** Every D5
   mechanism — coverage floor, per-hook disclosure, exclusion check — is vacuously satisfied. C4's name
   gate will be asked to bless a profile whose extension surface is empty **by construction**.
2. **The one thing that would change that is the detector D5 already names and defers.**
   `compaction_ai` is the measured proof it would work. **C5 is not a tidy-up of two un-widened ports;
   it is the item that decides whether any extension can ever be covered.** Widening `proc_exec` and
   `env_get` without it changes nothing about installability.
3. **The type system will not hold the line C assumes it holds.** The function-typed-parameter hole
   means a hook can be assigned into a closed ABI row while declaring less than it — so C5's detector
   cannot be built on declarations alone.

**And the practical one:** whoever takes C should read D1's acceptance table before C1. **B2b's
`ScriptedStep` widening quietly moved C2's starting line** — the `provider_error_*` classes now have
scripted delivery and `extension_effect_fault` has a reachable branch, so C2 can assert more than its
handoff will say it can. The emission log is still unconditionally `[]` until C1 lands, which is the
one thing D1 names as its own trap.
