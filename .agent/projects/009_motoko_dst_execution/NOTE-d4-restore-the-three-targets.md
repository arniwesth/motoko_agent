# WI-D4 — the three targets restored, and the conflation had a third channel

Twenty-eighth calibration run. Written against HEAD `e129ac1`, branch
`arniwesth/mot-66-close-acceptance-row-10`.

## Window

**~3h25m** wall-clock: `2026-08-05T19:57Z` → `2026-08-05T21:22Z` plus the blocked interval below.

**Grounding was not clean, and the first finding is procedural.** A *second Claude session* had a
`make dst` running in this same working tree at session start — sharing the `.ailang` caches and
`/tmp/corpus_pr.out`, which both `corpus_pr` recipes write and grep. Every measurement this item needs
would have been poisoned. I stopped my own run, asked, and waited for theirs. It exited 2 and its red
set is used below as an independent confirmation of the baseline.

The tree also carried **uncommitted WIP** — a partial `smoke_parity` candidate. It was stashed for the
baseline and adopted, corrected, in the repair.

## THE ANSWER

**All three targets are green and `make dst` is back to its two pre-existing red targets.**

| | D3 | D4 |
|---|---|---|
| `make dst` red targets | 5 | **2** (`test_coverage`, `test_coverage_selftest` — pre-existing since B2a) |
| ✓ rows | 745 | **845** |
| Whole-tree sweep | 226/17 | **226/17**, member-for-member |
| `corpus_pr` class-coverage rows | RED | **GREEN, and printed** |
| `resolve_context_limit` sites on a run's path | 8 | **1** |

## THE HANDOFF WAS WRONG ABOUT TWO THINGS, AND BOTH MATTER

### 1. `corpus_pr`'s class rows were never missing. They were RED.

The handoff reports that `corpus_pr` "aborts at the WI-A15 commit gate *before* printing" its
class-coverage rows, and that both strings are "absent" — so rows 4 and 11 "did not fail; they went
missing."

**`main` runs every scenario before `exit(1)`.** The rows were produced on every run. They are absent
from the *make log* because the recipe's failure path is
`grep -v '^{' /tmp/corpus_pr.out | tail -40` — a 40-line window the rows scroll off. `/tmp/corpus_pr.out`
carried them the whole time:

```
✗ the corpus validates against 9 expected class(es): …
    [required-class-not-covered] no member of the fixed bank reaches
    required class 'ToolCorrelationMismatch'
✗ every expected class was OBSERVED (declared ⊆ observed)
    declared but never observed: ToolCorrelationMismatch
```

**This is worse than the handoff's reading, not better.** "Unclaimable for want of evidence" is a
bookkeeping problem. A required fault class that no member of D11's blocking bank reaches is a
coverage regression, and rows 4 and 11 were *failing*, not unevidenced.

**S19 generalises, and the generalisation is the finding.** S19 says a gate's success markers are an
inventory and a missing tick is a failure report. Here the tick was neither present nor missing — it
was **produced and then truncated by the reporting path**. A recipe that shows less on failure than on
success is a recipe whose failure output cannot be read as an inventory at all. Suggested extension:
*"a gate that truncates its own output on failure has an inventory only on the happy path; check the
artifact, not the transcript."*

### 2. The conflation has THREE channels, and the handoff named one.

The handoff identifies the budget channel: `seeded_generator_dst.ail:738`'s `3 * max_interactions`
compares a generator budget against a log the driver also writes into. True, and incomplete.

**Channel 1 — the budget.** `ports.ail:982` passed `List.length(state.log)` as `interactions_so_far`,
and `dst_generator.ail:588` spends `max_interactions` against it. Driver env reads therefore consumed
the generator's budget and **truncated trajectories**.

**Channel 2 — THE SALT, and this is the one that hid.** All three generating seams salted every choice
with `n=${List.length(state.log)}` — `ports.ail:932` (tool), `ports.ail:1025` (approval),
`stub_step.ail:481` (provider). So the driver's config reads did not merely shorten trajectories, they
**changed which branch every generated choice took**.

**A generated trajectory was a function of how many times the driver happened to read its
configuration.** That is why:

* WI-D3 reshuffled the entire fixed bank and `ToolCorrelationMismatch` stopped being reached by the
  two seeds pinned as its witnesses;
* `seeded_generator` was red on **six** checks, not one — `tool faults=0`, `tool=0`, `reads=0` are
  starved trajectories, not check-fidelity problems;
* giving `rich` **more** budget by removing the re-resolutions made it **shorter** (provider 5 → 2),
  which is what sent me looking at the salt.

**Raising the slack would have hidden all of it.** The handoff was right to forbid it and right about
why; it under-estimated what it was forbidding.

**Channel 3 — the assertion**, which is the one the handoff named, and it is the least of the three.

## What was done

### The four `c2_loop` sites, and the measurement that licensed it

**657 site executions across the WHOLE of `make dst`, zero mismatches, all four sites reached.**

| Site | `session.ail` | Executions | Mismatches |
|---|---|---|---|
| `CallModel` | 2262 | 282 | 0 |
| `RunTools` | 2188 | 205 | 0 |
| `AwaitApproval` | 2144 | 95 | 0 |
| `Finalize` | 2034 | 75 | 0 |

D3 owed this measurement at the three sites it had not covered and said so. It is taken here over
every scenario in the gate rather than four suites, and it compares **both** halves — the stored limit
against a fresh resolution, and the loop's `model` against `policy.step.model`. The structural reason
they agree: every `session_policy_init` caller passes the same model it passes the loop, and the one
model SWITCH (`conversation_loop_v2_with_policy`'s `model_change`) rebuilds the policy through
`session_policy_with_model` and passes both.

The instrument reddened `anchors` and `attribution_table` while installed, which is the anchor cascade
announcing itself early. It was removed by `cp` (S17).

### The four successor answers, per site

**Three of four are NOT load-bearing. One is, and it is the trap the handoff named.**

| Site | Successor | Answer |
|---|---|---|
| `Finalize` 2034 | `r_limit.next_state` → `c2_finalize` | **Not load-bearing.** Descended from `st.world_state` with nothing between. |
| `AwaitApproval` 2144 | `post_ctx` → 5 uses | **LOAD-BEARING.** `post_ctx` is `post` advanced past the resolution; `post` is `st` advanced past the **approval read**. Collapsed to `post`, never to `st`. |
| `RunTools` 2188 | `st_ctx` → dispatcher | **Not load-bearing.** Only `c2_done_step` and `c2_pending_context`, both pure, stand between. |
| `CallModel` 2262 | `st_ctx` → 5 uses | **Not load-bearing.** The resolution was the first thing the arm did to the world. |

**The approval site is exactly WI-D1's defect in reverse and the type checker accepts the wrong
answer.** `{ post | … }` and `{ st | … }` both compile; only one keeps the approval cursor. The
existing comment at that site says the arm is prone to precisely this, which is why it was caught.

The two sibling `st.world_state` finalize sites (`SealSystemPromptEmpty`, `SealExhausted`) return to
`st.world_state` — where they stood before D3. **This is not a narrowing.** D3 pointed them at `st_ctx`
only so that item did not newly widen them; with no resolution in the arm there is no widening to
preserve. They still ignore `chain.next_state`. **Out of scope, unchanged, still owed.**

### The conflation, fixed at the source rather than padded

`dst_interaction.generator_authored_count` counts the three kinds the **generating** adapters serve —
`expect_provider`, `expect_tool`, `expect_approval` — derived from `identity_kind` rather than written
as three string literals. It replaces `List.length(state.log)` at all four places: the budget and the
three salts.

**The `3 *` is gone, and the exact relationship it was hiding is now asserted.** Spending the budget
does not stop the generator mid-request — `choose_provider` answers the request that spent it by
terminating, and that terminating exchange is itself authored. So a run that reaches its budget authors
**exactly budget + 1**, and the row says `==` rather than `<=`: fewer means the trajectory terminated
on its own and the axis graded a bound that never bound anything; more means the generator kept
authoring after reporting the failure.

**Two new rows, and the first is an S16 guard.** `budget_spent` and the check now read the same
function, so a `generator_authored_count` returning 0 would make the bound never fire and the check
always pass — two sides, one producer, both green. `ok_counted` is the independent side: the count must
be **non-zero and strictly below the raw log length**, i.e. the filter must both count something and
exclude something. `ok_is_tightening` is the second: the tightened literal must be **below the seed's
measured natural trajectory**, generated in the same run, so the literal goes red rather than stale
when trajectories move.

### `smoke_parity`, and the design decision

**A scripted run reads the model catalogue from the WORLD** — D3's answer for the driver, kept.

`run_v2_with_scripted_world` takes a whole `WorldState`; the fixture declares
`test/tiny: 100` and `anthropic/claude-sonnet-4-6: 200000` at the path the driver computes from an
empty env table. `totally-unknown-model` is deliberately **not** declared, so test 4 asserts what it
says rather than passing because no catalogue was found at all.

**`run_v2_with_scripted_ports` now DELEGATES**, which the adopted WIP claimed and did not do.
`ported_provider` maps `Scripted(script)` to `{ scripted_ports(), scripted_world_state(script) }` and
`ScriptedWorld(w)` to `{ scripted_ports(), w }`, so the delegation is behaviour-identical by
construction. A claim that two paths cannot drift should be enforced by there being one call.

**Seeding the catalogue by default was refused, and not only for the C1b reason.** Reading the host at
construction time is C1b wearing a different hat. But a *hard-coded* default is no better: every DST
fixture resolves 0 today precisely **because** its model is absent, so any default changes what those
fixtures resolve. The handoff asked for the delta to be reported before taking it; the option is
refused, so there is no delta. **No ambient fallback was added.**

**The WIP's call-site count was inherited prose and wrong** — it said eighteen; measured, it is
**thirteen**, across seven `scripts/smoke_*.ail` files.

### The re-pins, both of which are re-derivations rather than relaxations

**`seeded_generator`'s S7 fixture.** All 260 seeds swept and graded. Exactly two satisfy both
obligations — 1 and 110. **Seed 1 was tried first and rejected by the gate**, and that is worth
recording: `axis_s7` grades distinctness on the witness of the **replayed** run, not the generated one,
and the two differ in `approvals_consumed` because a generated world starts with an empty approval
queue. Seed 1 is distinct on the generated witness and collides on the replayed one at
`served=5/dispatches=5`. `rich` 77 → **110**; `pairB` 176 → **12**, the lowest seed whose interaction
count (23) equals `pairA`'s and whose outcomes differ, which is what the anti-count control needs.

**`corpus_pr`'s fixed bank, re-derived exactly as WI-D1 re-derived it.** Only seeds 1 and 5 appear in
both banks and neither for its old reason. 13 members → **15**; every one is load-bearing under the
unchanged selection rules (two witnesses per class, both trajectory extremes, the richest
Err-terminating trajectory). Class counts over 260 seeds all moved; the partition did not, and
`provider_empty_terminal_response` is still unreachable by search, so the constructed member's
justification holds.

**This should be the last re-pin the driver can force.** With the salts decoupled, a trajectory is a
function of the seed and the generator, and of nothing else.

### The cost constants, re-measured rather than raised

`measured_ms_per_seed` **292 → 381**, measured over 100 seeds *built* — generated, programmed, encoded,
persisted, loaded back — in 38.2 s. **The rise is a consequence, not noise:** the old constant was
measuring a generator that had been quietly truncated, and restoring full-length trajectories costs
more to run, encode and persist.

Every piece of arithmetic over it moved with it, which is what the Makefile's message demands.
`5000/381 = 13` seeds affordable against a declared minimum of 12 — **still fits, by one seed rather
than five**, and that is stated plainly at the site: the next rise puts the affordable count below the
minimum, and the honest response then is to raise the budget or lower the minimum, not to re-measure
until the number is convenient.

`pr_target_ceiling_ms` **45000 → 80000**, set from the **slow end** of an observed range (47–50 s cold,
24 s warm within `make dst`) at the same headroom ratio the previous pair had (1.58). A ceiling set
from the fast end fails on the first cold run and teaches whoever meets it to raise the ceiling.

### The census, which S1 caught

`discovery` and `strict_replay` went red on D3's per-scenario resolution counts — **12, 12, 12, 19, 8 →
1, 1, 1, 1, 1**. The driver now reaches `resolve_context_limit` exactly once per run.

**The parameter STAYS even though every caller passes the same number.** What makes the answer 1 is a
property of the driver's call graph, not of these suites. A parameter that is currently constant
expresses "this may differ per scenario and today does not"; folding it into a shared literal would
express "this cannot differ" — the claim D3 measured to be false.

**This is D3's own instrument working exactly as designed.** It failed loudly, immediately, and named
the quantity.

### The anchor cascade, paid once

Two anchors moved: `session.ail` 2654 → 2677 and 2764 → 2787, both pushed down by WI-D4's comment
blocks in `c2_loop`. `session.ail` 881/1126/1232, `stub_step.ail:203`, `tool_phase.ail` 313/314/373 and
`ext/runtime.ail:190` did not.

**No judgement was available** — `session.ail` still has exactly four `ports.clock_now(` sites, so the
third and fourth are the third and fourth. **The claim did not change**: same seven sites, still 6
routed of 7.

**Three consumers**, including the one D3 found the hard way: `dst_attribution_table.ail`,
`tools/predicate-anchors/anchors.sh`, and `driver_only`'s content hash.

**`driver_only` re-issued v9 → v10**, `sha256:affd2463…` → `sha256:ccfc1e34…`. A re-measurement, not a
correction.

**Paid exactly once (S18)** — every comment block was rewritten before any anchor number was derived.

**D3's historical record is LEFT AS D3 WROTE IT**, including its "eight call sites". That is what was
true at D3, and S15's trap is precisely that a bare number re-dated inside a historical record becomes
a false claim about history. The four-site fact belongs in D4's paragraph, and is there.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **The salt channel** (`ports.ail` 932/1025, `stub_step.ail` 481). The generator's *choices*, not
   just its budget, were a function of the driver's read count. Found by the trajectory getting
   shorter when given more budget.
2. **`corpus_pr`'s rows were red, not missing**, and the recipe's `tail -40` is why nobody saw them.
3. **Zero mismatches at all four sites**, 657 executions, whole gate.
4. **The approval site's successor is load-bearing**; the other three are not.
5. **`axis_s7` grades on the REPLAY witness**, which rejected the seed the generated-witness sweep
   recommended.
6. **`authored == budget + 1`**, exactly — the terminating exchange is itself authored.
7. **`measured_ms_per_seed` was measuring a truncated generator**, 292 → 381.
8. **The WIP's "eighteen call sites" was thirteen.**
9. **A concurrent session in the same tree** will silently poison every measurement through shared
   caches and `/tmp/corpus_pr.out`.

**Decided — a human chose:**

1. **The generator's budget counts `expect_provider` + `expect_tool` + `expect_approval`** — the three
   kinds the generating adapters answer by CHOOSING. Env reads come from a map chosen up front, clock
   advances are read back from the seam that caused them, extension effects come from installed hooks.
2. **`==` rather than `<=`** on the bound, because both directions are defects worth a red row.
3. **A LITERAL tightened bound with a measured tightening row**, rather than deriving the bound from
   the measurement — deriving it would put the bound and its own justification on one producer.
4. **The parameter stays at 1** rather than collapsing to a shared constant.
5. **A sibling entry point taking the whole world**, with the original delegating to it.
6. **The scheduled/PR ceiling set from the slow end** of the observed range.
7. **The bank keeps 15 members** rather than being trimmed to the old 13; every member is load-bearing
   under the unchanged rules, and trimming would mean dropping a class witness.
8. **D3's historical records not re-dated.**

## Sites where two answers type-checked and one was silently wrong

**ONE, and it is in the tree rather than the instrument.** The `AwaitApproval` arm: collapsing
`post_ctx` to `st` rather than to `post` type-checks, compiles, and silently discards the approval
cursor — WI-D1's production defect in reverse, in exactly the population the handoff said to look at.
It was **not shipped**; it was caught by reading the arm's own comment before editing, which is S1's
argument for the comment existing.

**The counter is 55**, from D3's 54.

**Determinism has still caught none of the fifty-five.** Worth stating for this item specifically:
determinism would have been *actively misleading* here. The generator was perfectly deterministic
throughout — the same seed gave the same trajectory on every run. It was deterministic and **wrong**,
because the function it was deterministic *in* included the driver's environment surface.

**Worth recording separately and NOT counted:** the sweep that recommended seed 1 graded the wrong
witness. It type-checked, ran, and produced a confident answer the gate then rejected on the next run.
That is S1 working, not a silent site — but it is a second instance of D3's "a derivation whose input
is wrong disagrees with the literal it checks", one layer out: **a derivation whose input is wrong
recommends a value the gate rejects.**

## Corrections owed to the plan

1. **S19 EXTENDS TO A GATE'S OWN REPORTING PATH.** A recipe that shows less on failure than on success
   has an inventory only on the happy path. `corpus_pr`'s rows were produced, red, and truncated by
   `tail -40`, and two sessions read that as "missing". Suggested extension: *"check the artifact, not
   the transcript — a gate whose failure path truncates cannot be read as an inventory."*
2. **A SEEDED GENERATOR'S INPUT SET IS PART OF ITS CONTRACT, AND NOTHING GUARDED IT.** The generator
   salted its choices with a quantity the driver contributes to, so "the same seed gives the same
   program" was true while "the program is a function of the seed" was false. Determinism cannot see
   this; only a change to the driver reveals it, and then it reads as fixture drift. Suggested
   extension: *"for a generator, assert what its output is a function OF, not only that it is a
   function."*
3. **A RE-DERIVATION MUST BE GRADED BY THE GATE'S OWN PREDICATE, ON THE GATE'S OWN SUBJECT.** The seed
   sweep used the right predicate on the wrong witness and recommended a rejected value. Suggested
   extension: *"when re-pinning a fixture, drive the sweep through the assertion, not through a
   re-implementation of it."*
4. **CONCURRENT SESSIONS IN ONE WORKING TREE ARE A MEASUREMENT HAZARD**, and nothing in the plan names
   it. Shared `.ailang` caches and hard-coded `/tmp` paths in recipes mean two `make dst` runs corrupt
   each other silently. Suggested addition to S9: *"before believing any gate, check that nothing else
   is running one."*
5. **The plan still has no item after Milestone C.** C4's planning defect 1 stands, unchanged by this
   item. The work list is the `on_budget_plan` ABI change plus the acceptance-table re-run.

## Out of scope, unchanged and still owed

* **Re-running C4's acceptance table and adopting the name** — the next item. See below.
* **The `on_budget_plan` ABI change**, and `ScratchpadResult`'s and `SessionSuspend`'s coverage.
* **The two sibling `st.world_state` finalize sites** — returned to `st.world_state`, still ignoring
  `chain.next_state`. The successor audit gives a cheap answer and it is **reported rather than
  taken**: `chain` is `dispatch_pre_step_chain`'s result, and its `next_state` is the pre-step chain's
  successor, so both sites finalize from a world that predates the extension chain's own effects. Same
  shape as WI-D1's defect. Not fixed here.
* **File reads in the interaction log** (D3 decision 6); **`FS` in
  `driver_only.forbidden_capabilities`** (D3 decision 9); D4's provider latency pair; the adversarial
  partial stream; the `motoko-ext-abi` major; the `ailang iface` MOD010 filing; the 7 `TC_ARITY_001`
  scripts; the two v0.33.0-fixed workarounds.

## CAN C4's TABLE BE CLAIMED GREEN AGAIN?

**The obstruction is removed. The claim is NOT made here, and making it is the NEXT item's job.**

Rows 4 and 11's evidence is green and printed. Rows 7 and 10 were green throughout. Nothing in this
item touched the other seven rows, and nothing in it re-ran the table.

**Three things the next item must not inherit as settled:**

1. **The env census numbers D3 pinned have MOVED** — 12/12/12/19/8 → 1 across the board. The handoff
   said this item's changes would move them, and they did.
2. **The `driver_only` profile is v10**, not v9. Any artifact or report naming v9 is stale.
3. **Two of the eleven passes remain VACUOUS in their installed-extension clauses** (rows 3 and 5's
   transfer caveat). Nothing here makes them non-vacuous, and per D10 they transfer to no second
   profile.

**Twelve items have now declined the name and this is the twelfth.**
