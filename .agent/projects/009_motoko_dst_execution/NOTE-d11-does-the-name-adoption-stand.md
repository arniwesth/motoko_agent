# WI-D11 — does the name adoption stand? **VERDICT: YES, QUALIFIED.**

Thirty-fifth calibration run. Written against HEAD `a25de2a`, branch
`arniwesth/mot-73-wi-d10-land-amendments-b-and-a`. **Zero source files modified. Zero documents
amended.** This is a determination; its output is the answer below.

## Window

**~21 minutes** wall-clock: `2026-08-07T09:13:33Z` → `2026-08-07T09:34:25Z`. Two measurements
dominate it: the cache-cold sweep and `make dst` in full, run as one sequence from a cleared cache
(`09:16Z` → `09:31Z`). The determination itself is reading.

## THE ANSWER

**The name stands. D10's two conditions are met, and the ADR sentence that appears to unseat them
does not, because its stated antecedent is false and has been false since 2026-08-03.**

**It stands qualified, on one point D5 did not check and nobody has:** the routing audit's
citability requires classifier 1 as well as classifier 2, and **classifier 1 fails its amended
criterion under every cache state this repository is able to produce**. That does not unseat the
adoption — see §4 for why — but it is the live exposure and it is not what WI-D10, the governance
act, or this handoff expected the exposure to be.

**Nothing here is a remedy proposal, because the answer is not "no".** The public record
`m-motoko-dst-framework.md` is untouched and needs no withdrawal.

---

## 1. D10 states TWO conditions. Quoted.

`ADR:2340-2343`, in full:

> During implementation, new code and targets use a non-simulation working name. The unqualified
> "DST"/"simulation" label is adopted for the generated axis **only after the acceptance test below
> passes for a documented baseline profile and the project-007 definition/taxonomy ADR is accepted**.
> Every report names the profile; additional profiles earn coverage separately.

**Two, joined by "and".** The gate-mechanism sentence is 120 lines away, in a different section, and
D10 does not reference it. It is not a third condition on the name.

## 2. `ADR:2463-2465` is a constraint on ONE CLASS OF EVIDENCE, and the document says so three times

The sentence:

> **None of the four deferred mechanisms blocks acceptance of this ADR.** They block the *name*:
> D5's routing audit is not citable as name-adoption gate evidence until each is built and passes its
> criterion above.

The colon is doing the work. "They block the name" is not left as a bare assertion — it is
immediately glossed, and the gloss is narrower than the assertion: **one named instrument, D5's
routing audit, may not be cited for one named purpose.** Read as a third condition on adoption, the
gloss would be redundant.

Two other sites state the same thing operatively and neither is ambiguous:

- **`ADR:2036-2041`, the verification gate on obligation 2** — the passage that actually decides
  citability:
  > Classifier 1 is built and was independently run by both acceptance reviewers against its
  > published criterion (0 unresolved, `agree=43 disagree=0`); that half of the audit is citable.
  > **Classifier 2 is not built, so D5's routing audit as a whole remains non-citable as
  > name-adoption gate evidence** until it is.
- **`PLAN:3201`**, milestone A's exit criterion: *"the routing audit citable (**both classifiers
  built and verified**)"*.

So citability is a two-part condition on the audit, not a five-part condition on the name.

## 3. The constraint bites on exactly ONE row. Per-row, and this is the durable output.

| Row | Does its evidence rest on the routing audit or on a deferred mechanism? |
|---|---|
| 1 seed generates an execution | No. `discovery` · `strict_replay` · `seeded_generator` · `execution_program` |
| 2 modeled logical environment | No. `world_state` · A12 probe |
| **3 tested boundary is honest** | **Names classifier 2 in its own text — and the clause is VACUOUS.** See below |
| 4 faults reach recovery code | No. `corpus_pr` artifact · `fault_catalogue` |
| **5 virtual time matters** | **YES — names the routing audit in its own text, and its evidence is that audit's output** |
| 6 production logic under test | No. `smoke_driver` · `terminal_trace` · `world_state` |
| 7 oracle is complete | No. `invariants` · `ledger_parity` · `stream_parity` — the reading it turns on is about ledger emissions, not about any mechanism |
| 8 harness failures separate | No. `strict_replay` · `world_state` poison pairs |
| 9 discovery/replay stable | No. `discovery` · `strict_replay` |
| 10 hermeticity enforced | No. `world_state` — five two-sided poison pairs, run-time probes |
| 11 actual search | No. `corpus_pr` · `corpus_rotating` |

**Row 3 is not a dependency, and this is the reading that could have gone wrong.** Its
mechanism-naming clause (`ADR:2545`) is *"profile-definition validation found no installed extension
that calls a classifier-2 `ExtPorts` field while registering an un-excluded hook (D5 classifier 2)"*.
`driver_only` installs nothing, so the quantifier is empty and the clause holds **whether or not
classifier 2 exists**. A vacuously-true clause borrows no warrant from the instrument it names. Every
other clause of row 3 — manifest and profile named and validating, excluded hooks and adapter/parser
boundaries listed, dispatch-to-exclusion failing closed, per-extension id disclosure — is produced by
`profile_coverage`, `profile_definition` and `hook_guard`, none of which is the routing audit.

**Row 5 is the dependency, and it is real.** `ADR:2547` requires *"every time-bearing read reachable
in the profile is routed through the world clock — **no residual direct `std/clock` read survives the
routing audit**"*. Its evidence is `driver_only.routed_set_claim`, which is that audit's output,
reproduced this run:

```
✓ routed-set claim is a partition of the table: 7 reachable = 6 routed + 1 declared-unrouted
```

And `ADR:940-942` forecloses the escape that row 5 might mean the *clock* audit (a separate bullet at
`ADR:1801`) rather than the source/ABI one: *"the **source and ABI routing audit** enumerates such
reads as a conservative textual site inventory over explicit `src` + `packages` roots, per D5
obligation 2, **and is the one a profile depends on**"* — with capability-withholding named as a
per-run backstop that *"cannot on its own discharge the all-or-nothing routing requirement"*.

Row 5's second conjunct — the latency pair — is a differential experiment and is independent. But the
row's required evidence is a conjunction, so the first conjunct decides it.

**Therefore the whole question reduces to: is D5's routing audit citable?**

## 4. It is. The antecedent of the non-citability is FALSE, and was false when D5 adopted the name.

**`ADR:2038` says "Classifier 2 is not built". Classifier 2 was built on 2026-08-03 at `5ad3433`
(WI-A4) and has been in `make dst` and in CI ever since.**
`NOTE-cluster-2-execution-report-and-plan-corrections.md:19` records its definition of done as met:
*"classifier 2 reports the two known `ai_step` sites and **zero unresolved** at HEAD, with a fixture
per unresolvable form reported as unresolved."*

Measured at HEAD this run, against the criterion in `ADR:2410` — *"A type-aware field-call inventory
over the in-profile roots, failing closed on every alias, wrapper, re-export, or computed access it
cannot resolve"*:

```
make ext_call_inventory            EXIT 0
  ExtPorts fields    4: ai_step, proc_exec, clock_now, env_get
  membership (derived from D5's criterion, not from its enumeration)
  CLASSIFIER-2 SET (2): env_get, proc_exec
  member call sites (0):
  non-member port calls (2), recorded not gated

make ext_call_inventory_selftest   EXIT 0   self-test: 0 failure(s)
  ok  control_resolved.ail   control: typed path, must resolve   (0 unresolved, 1 resolved)
  ok  form_alias.ail         local alias (unannotated binding)   (1 unresolved, 0 resolved)
  ok  form_computed.ail      computed receiver                   (1 unresolved, 0 resolved)
  ok  form_reexport.ail      re-export                           (1 unresolved, 0 resolved)
  ok  form_wrapper.ail       wrapper                             (1 unresolved, 0 resolved)
```

Type-aware, over `src` + `packages`, membership re-derived from the criterion rather than read from a
list, fail-closed on all four unresolvable forms with a resolving control beside them, zero
unresolved. **That is the criterion, met.**

**So on 2026-08-06 the routing audit's stated blocker had been discharged for three days, and D5's
adoption was sound.** D5 did not reason its way there — its verdict section checks D10's two
conditions and never mentions citability, and neither did its handoff. It was right without checking.
That distinction is worth recording precisely because the next item in this position may not be.

## 5. The qualification: classifier 1's half, and it is the live exposure

`ADR:2036-2038` grants classifier 1's half of the audit on `agree=43 disagree=0` — a measurement from
`a0d4edb`. On 2026-08-06 the acceptance reviewers **amended** classifier 1's criterion to require the
self-test to compare **≥90% of the stdlib modules the profile's roots import**, and ruled that against
the amended criterion classifier 1 **fails** (`ADR:2440-2444`). The verification-gate box 400 lines
above was not updated and still reads *"that half of the audit is citable"*.

So the audit's citability now turns on classifier 1, and classifier 1 is the mechanism whose
measurement moved three times in one day.

### Classifier 1's status under a stated cache precondition — the measurement IS bounded

The denominator is printed by the tool: **`repo imports 21 distinct std/* modules`**. The numerator is
how many of those `ailang iface` can resolve and parse, which is what the self-test can compare.
Measured directly, per module, in four cache states:

| Cache precondition (`~/.local/share/ailang/std/.ailang/cache/`) | `effect_inventory` | selftest | coverage of the amended denominator | amended criterion |
|---|---|---|---|---|
| **230 files** — as found at session start | INTERFACE FAILURES **1** of 46 | `agree=45 disagree=0` | **21/21 = 100%** | **PASSES** |
| **0 files** — cleared | INTERFACE FAILURES **45** of 46 | `agree=1 disagree=0` | **0/21 = 0%** | **FAILS** |
| after the cache-cold whole-tree sweep (243 files) | — | `agree=1 disagree=0` | — | **FAILS** |
| **after `make sync_packages` + `make dst` in full, from cold** | — | **`agree=1 disagree=0`** | **0/21 = 0%** | **FAILS** |

**Demonstrated two-sided.** The 230 files were archived before clearing and restored afterwards:
clearing takes coverage 100% → 0% and the selftest 45 → 1; restoring takes both back. The tree did
not change between any two of these runs.

**And the new fact, which is the one that settles it: no repository operation produces the 230-file
cache.** The cache-cold whole-tree sweep — 243 `ailang check` invocations — leaves it at **0 files**.
`make dst` in full leaves it at **52**, and the selftest at `agree=1` in both. **The `agree=45` state
was found in this environment and cannot be re-established by anything this project runs.**

So the measurement does not need to be declared unbounded. **Under every cache precondition this
repository can establish, classifier 1's coverage against the amended criterion is 0% and it fails.**
The 100% row is real but is not a state the project can reach or reproduce, and a criterion met only
from a cache no gate can rebuild is not met in any useful sense.

### What that costs, bounded

**Classifier 1's derived set is cache-invariant. Only its validation coverage moves.** Cold and warm
produce byte-identical answers:

```
repo imports   21 distinct std/* modules
effect-bearing and imported (13)
proven effect-free (8): std/bytes, std/crypto, std/datetime, std/json,
                        std/list, std/option, std/result, std/string
```

So what is unavailable is not classifier 1's answers — it is the evidence that they are right. 45 of
46 classifications come from the unvalidated textual fallback, exactly as WI-D10 reported and exactly
as the governance act's amendment intends the criterion to catch.

**Why this qualifies the name rather than unseating it.** Row 5's clause is about `std/clock`, and
`std/clock`'s effect-bearing classification is stable across every cache state measured. The routed
set — 7 reachable, 6 routed, 1 declared unrouted — is unchanged, computed, and green. The exposure is
that the audit's first half currently rests on an unvalidated derivation, not that its answer is in
doubt. **Repairing classifier 1 against the amended criterion is already owed and unowned
(`ADR:2459-2461`); this determination adds that a cache-state precondition must be part of the
repair, because otherwise the repaired gate measures the cache again.**

---

## 6. FINDINGS TO REPORT, NOT TO RESOLVE

### F1. The ADR's gate-mechanism table contradicts the ADR's own body on three of five rows

Not this item's to move, and stated as measurement:

| Gate table says | The same document says | Measured at HEAD |
|---|---|---|
| `ADR:2410` Classifier 2 — **Deferred** | `ADR:1972-1976` (amendment, WI-A4): *"`tools/ext_call_inventory/derive.py` **re-derives membership from the criterion on every run** … `make ext_call_inventory_selftest` pins the current answer as a regression guard"* | Built `5ad3433`, 2026-08-03. Both targets EXIT 0, in `make dst` |
| `ADR:2411` Site-to-hook attribution table — **Deferred** | `ADR:1170-1172` (amendment, 2026-08-03, WI-A5): *"**The table now exists and validates** (`src/core/dst_attribution_table.ail`, `make attribution_table`)"* | Built. `make attribution_table` green, per-row named reviewer enforced, five rejection rules fire by name |
| `ADR:2412` Coverage floor validation — **Deferred** | `ADR:1329-1333` (WI-A6): the assertion and the `describe_tools_excluded` fixture in `scripts/dst/profile_coverage_dst.ail`, *"plus a structural guard in `make profile_coverage`"* | Built. Thirteen rejecting fixtures, each red by its own rule |
| `ADR:2413` Classifier 3 — Deferred | admitted 2026-08-06 | **Genuinely unbuilt.** The one true deferral |
| `ADR:2038` *"Classifier 2 is not built"* | `ADR:1972` describes the built tool | Stale |
| `ADR:2036-2038` *"classifier 1's half … is citable"* on `agree=43` | `ADR:2444` *"Against the amended criterion classifier 1 is **failing**"* | Stale in the opposite direction |

**The governance act's §6 count-agreement table checked five count sites and found two live ones the
handoff had not named. It did not check the State column, and the State column is where the
disagreement is.** Whose pen this is: the acceptance reviewers', who own this table.

### F2. `src/core/dst_driver_only.ail:597` rests a live conformance claim on classifier 1 — confirmed

The handoff's item 3 is correct. The omission reason for `compaction_ai` ends:

> compaction_ai in FACT reaches effects only through ExtPorts.ai_step — compaction_ai.ail imports
> std/ai (a type only), std/crypto, std/json, std/list, std/option, std/result and std/string,
> **every one of which classifier 1 derives as proven effect-free**, and calls no ambient builtin.

All six named modules are in the derived effect-free set under **both** cache states, so the claim is
true as written. **What it lacks is validation, not truth.** And it is not a row's evidence: row 3
passes on *disclosure* — that the result reports covered/excluded ids and names its omission — not on
the reason paragraph being sound. So it does not change the verdict. It is the tree's one live
citation of a mechanism now recorded as failing, and it should move when classifier 1 is repaired.

### F3. The producer-side completeness check is fed its own output at the only real call site

This is the finding about the acceptance table's *structure*, and it stands behind row 5.

`src/core/dst_attribution_table.ail:446-448` states the rule, correctly and emphatically:

> The discovered set is an ARGUMENT, never a constant in this module. It comes from an inventory run
> against the source, and **hardcoding it here would make this check agree with itself by
> construction.**

At the live call, `scripts/dst/attribution_table_dst.ail:208` passes `head_inventory()`, defined at
`:133-139` as:

```
unconditional_core_sites()
  ++ [ src/core/ext/runtime.ail:190 Clock, src/core/tool_phase.ail:314 Process ]
```

Those two sites are **exactly** the two sites in `attribution_rows()` (`:201`, `:208`). So the
"discovered" set is the union of the two lists `validate_completeness` checks membership against, and
**it cannot reject over it** — the check is green by construction at the one place it is asked a real
question. The negative fixture (`omitted_site()` → `[site-unaccounted]`) proves the *rule*
discriminates; no source inventory feeds the *instrument*.

The consequence for row 5: the routed-set claim is an honest partition of `reachable_core_sites`, and
its **completeness** — that no core clock site is missing from both lists — is guarded by a check
whose input is derived from the lists it validates. Reported, not resolved. It is the same shape as
`ADR:1967-1971`'s warning about a detector carrying a hardcoded member list, one level up.

---

## Gate state

- **Whole-tree sweep, cache-cold, `AILANG_RELAX_MODULES=1`: 226 pass / 17 fail of 243 files.** Run
  first, per S13. **Cache-cold this time includes `/home/motoko/.local/share/ailang/std/.ailang/cache/`**,
  which S9's own sweep misses — cleared to 0 files before the sweep. Repo caches cleared with the
  S9 `find` command; `~/.ailang/cache/registry` left alone and verified intact.
  **The failing set matches the expected seventeen member for member**: 7 `TC_ARITY_001` smoke
  scripts, `probe_phase_vocab_sealed`, 5 `src/examples/`, 3 code-graph fixtures, 1 test-coverage
  fixture. Stable across B4, C1, C3, C5, C4, D3, D4, D5 and now D11.
- **`make sync_packages` EXIT 0**, run first as required. Its only tree effect was a `generated_at`
  timestamp in `ailang.lock`, reverted — this item modifies nothing.
- **`make dst` — EXIT 2, red set `test_coverage` and `test_coverage_selftest`, and nothing else.**
  Identical to D5's red set. Both pre-existing since B2a.
- **Every row-5 and row-3 producer green**: `driver_only`, `profile_definition`, `profile_coverage`,
  `attribution_table`, `hook_guard`, `world_state`, `latency_pair`.
- **Barrier count 3, DERIVED** by `make profile_definition` on this run: `on_pre_step` `! {AI, IO,
  Trace}`, `on_response_intercept` `! {IO, Process, FS, Clock}`, `on_solver_candidate` `! {Process}`;
  `on_tool_handle` gated, so not a barrier. *"3 barrier(s) stand, so NO extension is installable in a
  conformant profile."*
- **The profile is now `driver_only/12`** under manifest `driver_only/3`. D5's table was run at
  `/10`. `:372` and `:452` record both bumps as claim-only: *"Install list, coverage claim, waived
  set, hook classifications, catalogue and attribution ref are all UNCHANGED. v12 installs exactly
  what v11 installed, which is nothing."* **So D5's eleven-row verdict transfers to `/12` on the same
  terms.** The public record names `/11` and is one version behind — a record-maintenance item, not a
  claim change.

## Recorded bindings: decided versus discovered

**Discovered — a tool or a measurement forced it:**

1. **`ADR:2038`'s "Classifier 2 is not built" is false and has been since 2026-08-03.** Found by
   running the mechanism rather than by reading the row that describes it. This is what decides the
   whole question.
2. **The ADR's gate-mechanism State column disagrees with the ADR's own amendment paragraphs on
   three of five rows** (F1). Found by asking, of each "Deferred" row, whether a target exists.
3. **No repository operation produces the 230-file stdlib cache.** A 243-file cache-cold sweep leaves
   it at 0; `make dst` in full leaves it at 52. This is what converts "the measurement is unbounded"
   into a bounded answer, and it is the opposite of what the handoff expected.
4. **Classifier 1's derived set is cache-invariant; only its validation coverage moves.** 13
   effect-bearing / 8 proven-effect-free, identical at 0 files and at 230. Measured, not argued.
5. **The amended criterion's denominator is 21, not 46**, and the tool prints it: *"repo imports 21
   distinct std/* modules"*. At 230 files the coverage is 21/21 = 100%; at 0 files it is 0/21. The
   selftest's own `agree=` count (45 vs 1) is over the 46-file stdlib walk and is not the criterion's
   fraction.
6. **`head_inventory()` is the union of the two lists it is validated against** (F3). Found by
   following row 5's evidence down to the check that guards its site set's completeness.
7. **Row 3's classifier-2 clause is vacuous and therefore borrows nothing from classifier 2.** The
   handoff asked whether rows 3 and 5 rest on the audit; the honest answer is one does and one does
   not, and the reason is the empty install list — the fifth thing that emptiness buys.

**Decided — a human chose:**

1. **The answer is "stands, qualified" rather than "stands".** The unqualified answer was available —
   both of D10's conditions are met and the citability antecedent is false — and it would have buried
   the classifier-1 exposure that survives.
2. **The `:2463` sentence is read as a constraint on evidence**, on its own colon, on `ADR:2036-2041`
   and on `PLAN:3201`, and not as a third condition. Stated so a reviewer who reads it the other way
   knows exactly which sentence to reopen.
3. **The measurement is declared bounded rather than unbounded**, on the ground in §5: the 100% state
   is unreachable by any project operation, so the failing answer is the project's answer.
4. **Nothing was edited.** The ADR's three stale rows, the stale verification-gate box, and the public
   record's `/11` are all reported and left. The gate table is the acceptance reviewers' pen, and
   `m-motoko-dst-framework.md` needs no withdrawal because the answer is not "no".
5. **F2 is reported as a citation to move when classifier 1 is repaired, not as a defect in row 3.**
   The reason paragraph's claim is true; only its warrant is weak.
6. **The count is not moved.** Recorded deferred count stays four; measured, one mechanism is unbuilt.
   Both numbers are stated and neither is changed here.

## Sites where two answers type-checked and one was silently wrong

**Three, all in claims and citations — and none of the three is reachable by any determinism check.**
This item wrote no code, which is exactly the handoff's prediction about where the last four came
from. Running total **69 across thirty-five runs**.

1. **"Deferred" in the gate table's State column** (`ADR:2407-2413`). Reading A: a live status —
   "not built at HEAD". Reading B: an ADR-time allocation of work — the section's own framing,
   `ADR:2396`, is *"the boundary between 'the ADR decides it' and 'the plan builds it'"*. Both are
   supported by the document, and **the wrong one is silent because the classifier-1 row's State
   column IS live-maintained** — WI-D10 edited it and the governance act revised it four days later,
   which teaches every reader that the column tracks HEAD. Under that reading three rows are false.
   **This is the reading the whole question turns on and no session has adjudicated it.**
2. **"the routing audit" in row 5** (`ADR:2547`). `ADR:1799-1804` lists *"a source/ABI routing
   audit"* and *"a profile-reachable clock audit"* as **separate bullets** of the same hermeticity
   gate, so row 5's *"survives the routing audit"* type-checks against either. Only one carries a
   citability constraint. The wrong reading is silent in the dangerous direction: it makes row 5
   unconditionally citable with no marker anywhere, and a reader entering at D4 gets exactly that —
   which is the defect `ADR:4875-4894` (R2) raised and which the fix has not fully closed.
   `ADR:940-942` settles it for the source/ABI audit.
3. **`head_inventory()`** (`scripts/dst/attribution_table_dst.ail:133`). Reading A: the discovered
   set, from an inventory run against source — what
   `src/core/dst_attribution_table.ail:446-448` requires. Reading B: the two lists' union — what the
   code actually passes. Both type-check, both produce a `[CoreSite]`, and the wrong one is **green**,
   which is the failure mode the module's own header was written to refuse.

## Counts, neither moved

- **Barrier count: 3.** Derived on this run by `make profile_definition`, not asserted.
- **Deferred count as recorded: 4.** Left at four. Measured, one of the four (classifier 3) is
  unbuilt and the other three are built and green in `make dst` — reported under F1 for whoever owns
  that table.

## What this item did NOT do, deliberately

- **Edit the ADR's gate table, its State cells, or the verification-gate box at `ADR:2036-2041`.**
  All three are the acceptance reviewers' pen and F1 is written for them.
- **Touch `m-motoko-dst-framework.md`.** The answer is not "no", so there is nothing to withdraw. Its
  `/11` reference is one profile version behind `/12`; both bumps are claim-only.
- **Repair classifier 1, amend `derive.py`'s zero-check to a coverage check, wire `effect_inventory`
  into `make dst`, build classifier 3, or land `basis`.** All owed, none this item's — and §5 adds one
  requirement to the first: the repair must state a cache precondition, or the repaired gate measures
  the cache again.
- **Fix F3.** Supplying a real discovered set to `validate_completeness` is a source change with a
  new instrument behind it, and it belongs to whoever owns the routing audit's completeness.
