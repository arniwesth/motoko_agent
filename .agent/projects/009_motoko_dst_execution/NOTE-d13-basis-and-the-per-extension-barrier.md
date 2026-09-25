# WI-D13 — `basis` landed, the barrier derivation re-shaped, and what `compaction_structural` earns

Grounded against HEAD `c3de56f`. Thirty-seventh calibration run.

**Headline: the criterion decision is CRITERION 2, with two of its three clauses VACUOUS — and the
re-shaped derivation reaches zero barriers for FOUR extensions, not one.** The trigger fired,
two-sided. Nothing was installed. The SLOT-level barrier count is still THREE and no ABI row moved.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `c3de56f` — `2026-08-07T11:42:34+00:00` |
| first command | `2026-08-07T11:47:13Z` |
| work window | ~4 min 39 s from the handoff commit to grounding |

## 2. The criterion decision — the item's durable output

**`compaction_structural` earns CRITERION 2, on a measured basis, with clauses 1 and 2 VACUOUS and
clause 3 substantive.** So do `decision_framework`, `empty_stop_guard` and `progress_contract_guard`.
The criterion-1 stop rule does **not** fire.

Decided explicitly against both, because these hooks read most naturally as criterion 1 and that is
the trap the handoff named.

### Criterion 1 — *"deterministic and effect-free for its explicit inputs"*

**True in substance. Not available as a basis.**

Re-measured at this item rather than carried forward, two-sided, over **all twelve** barrier-slot
hook bodies of the four extensions — each body verbatim, declared with **no** effect row outside the
ABI record, plus a control adding one `println`:

```text
                                            rowless      control (+ println)
compaction_structural    on_pre_step         ACCEPTED     REJECTED  Missing effects: IO
compaction_structural    on_response_intercept ACCEPTED   REJECTED  Missing effects: IO
compaction_structural    on_solver_candidate ACCEPTED     REJECTED  Missing effects: IO
decision_framework       (all three)         ACCEPTED     REJECTED  Missing effects: IO
empty_stop_guard         (all three)         ACCEPTED     REJECTED  Missing effects: IO
progress_contract_guard  (all three)         ACCEPTED     REJECTED  Missing effects: IO
```

Twelve for twelve, and the control establishes the effect checker was running on every one of them.

**But criterion 1's basis is the DECLARED ROW.** `ADR:1415` records the declared-row reading as an
interim rule and an assumption, and WI-B4 settled that its scope is classification generally rather
than criterion 1 alone. These slots' rows are `! {AI, IO, Trace}`, `! {IO, Process, FS, Clock}` and
`! {Process}`; a named binding cannot declare narrower than a closed ABI slot. **On its own basis
criterion 1 fails.** Admitting a measurement into that basis is an ADR-scope act, and Amendment A
withheld criterion 1 deliberately. So criterion 1 is *unavailable*, not merely unearned — which is
why the stop rule does not fire: the answer is not criterion 1, it is that criterion 1 has no route.

### Criterion 2 — *"effectful only through D1 world-mediated ports, with origin tagged by extension id and explicit world state returned to the host"*

Read as WI-B4 read it, as a conjunction of three clauses:

| Clause | Verdict | Basis |
|---|---|---|
| (1) effectful only through D1 world-mediated ports | **satisfied VACUOUSLY** | classifier 3: PORT-MEDIATED, **0** ambient sources, **0** `ExtPorts` field calls. The set of performed effects is empty, so the quantifier holds over nothing. |
| (2) origin tagged by extension id | **satisfied VACUOUSLY** | nothing is performed, so there is no origin to tag. (WI-B4 established `PreStepStage = { ext_id, outcome }` tags `on_pre_step`'s dispatch, so the clause *is* satisfiable non-vacuously — just not by an extension that performs nothing.) |
| (3) explicit world state returned to the host | **satisfied, NON-vacuously** | all twelve bodies return `next_state: ctx.world`, and the four outcome types carry the field — derived from the ABI's own type declarations, not assumed. |

### The vacuity, named rather than banked

**Two of criterion 2's three clauses hold because nothing happens.** Amendment A predicted exactly
this in advance (`ADR:1611`): *"the first hook classifier 3 clears will be one that performs nothing,
not one that mediates."*

So the coverage these four would buy is **coverage of no-ops**. That is a true measurement and would
produce a real, non-zero extension-model coverage number — and it is **not** evidence that the
world-mediation machinery works, because installing them exercises none of it. `driver_only`'s
acceptance table already leans on an empty install list in four places; installing these would make a
**fifth vacuity that is harder to see, because it arrives with a number attached.** That is the reason
recorded for declining, and it is a reason about *evidence*, not about correctness.

**Nothing was installed.** The four are named in `omitted_extensions` with the reading above; the
install decision, its coverage claim and its profile version bump remain WI-C5's.

## 3. The re-shaped derivation — per extension and globally

`check_barrier_count` now derives at both granularities. The slot-level derivation is retained
unchanged, and its zero-trigger is retained unchanged.

```text
✓ SLOT-level barrier count DERIVED from the ABI rows and the dispatch table: 3
    BARRIER  on_pre_step: unconditionally dispatched, declares ! {AI, IO, Trace}   (outcome returns world state: yes)
    BARRIER  on_response_intercept: ... ! {IO, Process, FS, Clock}                 (outcome returns world state: yes)
    BARRIER  on_solver_candidate: ... ! {Process}                                  (outcome returns world state: yes)
    coverable on_budget_plan: unconditionally dispatched, declares NO row
    gated     on_tool_handle: excludable, so not a barrier
  → 3 slot-level barrier(s) stand: no extension is installable on the DECLARED ROW alone

✓ barrier count RE-DERIVED per (extension, slot) — classifier 3 is the third producer: 33 of 45 pairs stand
    CLEARED for 'compaction_structural':   on_pre_step, on_response_intercept, on_solver_candidate — ZERO barriers remain
    CLEARED for 'decision_framework':      on_pre_step, on_response_intercept, on_solver_candidate — ZERO barriers remain
    CLEARED for 'empty_stop_guard':        on_pre_step, on_response_intercept, on_solver_candidate — ZERO barriers remain
    CLEARED for 'progress_contract_guard': on_pre_step, on_response_intercept, on_solver_candidate — ZERO barriers remain
    all 3 barriers stand unchanged for the other 11 extension(s)
  → ZERO barriers remain for those four, so those extensions ARE installable
  → each is accounted for BY NAME in the profile
```

**Three producers, none deriving from another (S16):** the ABI row, the dispatch table
(`dst_profile_coverage.ail`), and classifier 3 (`tools/ext_ambient_inventory/derive.py --json`).

**Clause 2 fails closed and says so.** This tree has no producer for *"is this port call
origin-tagged"* — WI-B4 read `on_pre_step`'s dispatch by hand, which is one slot and not a
derivation. So the check clears a barrier only when classifier 3 reports **zero** `ExtPorts` field
calls, i.e. when there is nothing to tag. An extension that is PORT-MEDIATED *and* actually calls a
port is refused with `clause 2 UNDISCHARGED`, naming the call count. That is why the clearance set is
the four no-op extensions and not `compaction_ai`, which classifier 3 reports AMBIENT anyway.

**Clause 3 is derived, and the S16 enumeration was done before the unit was chosen** — five ways a
slot's outcome type could carry explicit world state (flat `next_state` field; nested record; alias;
type parameter; renamed field). Only the first is matched; every other shape reads as **absent**,
which leaves the barrier standing. Fail-closed in the direction that can refuse a hook that in fact
returns world state and cannot clear one that does not.

### The trigger, fired and resolved — two-sided

| Arm | Result |
|---|---|
| four zero-barrier extensions, none named in the profile | `FAIL: the barrier count has reached ZERO for extension(s) [...] which the profile neither installs nor omits by name` |
| one entry removed (`empty_stop_guard`) after the other four landed | `FAIL: ... ['empty_stop_guard']` — fires **per extension**, naming it |
| all named | green, with the derived set printed |

A guard that only ever passes cannot be told from one that does not run, which is why the middle arm
was run rather than inferred from the first.

## 4. `basis`'s validation, and what it rejects

`HookClassificationEntry` gains `basis: ClassificationBasis = { producer, revision }`.

**What made this owed, and what it fixes.** WI-D11 measured that Amendment A's fail-closed default
(`ADR:1548`) was *unenforced*: `classification_agrees` validated a `WorldMediated` entry against the
disclosure's excluded-id list **and nothing else**. A profile author could write `WorldMediated` and
pass the gate; what kept that unreachable was the barrier count, not the rule. This item is the
change the acceptance reviewers' condition attached to, so the field lands with it.

**The rule, applied to every entry rather than only to `WorldMediated`.** Uniform is strictly
stronger and costs nothing — `basis` is a record field, so every entry already has one and the only
question is whether anything reads it. `EffectFree` is criterion 1, whose basis the ADR names as an
assumption; `ExplicitlyExcluded` is a decision; none of the three is self-evident.

Three rejections, each with its own fixture:

| Fixture | Rule |
|---|---|
| `WorldMediated` with **no producer** — the entry that passed the gate until today | `classification-basis-not-recorded` |
| a real producer, **undated** — a measurement that cannot be dated cannot be told from a stale one | `classification-basis-not-recorded` |
| producer `successor_detector`, which this tree does not have | `classification-basis-unrecognised` |
| **CONTROL:** `ext_ambient_inventory` @ `c3de56f` | **loads clean**, rejection count `== 0` |

Run at **two** levels deliberately: `ailang test src/core/dst_profile.ail` calls
`validate_classifications` directly (the rule computes the right answer), and
`scripts/dst/profile_definition_dst.ail` runs all four through `validate_definition_at_load` — **the
same call a runner makes**. A rule that is correct and unwired is the fail-open the field exists to
close, and only the second level can tell the two apart.

**The producer catalogue is closed and guarded, not trusted.** `recognised_producers()` names five,
each with a `kind`:

```text
Measured   ext_ambient_inventory   classifier 3 — the only producer that can establish criterion 2
Measured   ext_call_inventory      classifier 2
Measured   effect_inventory        classifier 1 (recognised as a real producer; its answer is not
                                   load-bearing for anything here — see §7)
Assumed    declared_row            criterion 1's basis and Amendment A's interim rule (ADR:1415/1548)
Assumed    disclosure              the only admissible basis for ExplicitlyExcluded
```

`check_fixtures.py` re-derives the three **Measured** ids from the Makefile and fails if one has no
`.PHONY` target — the list is a transcription of facts living outside AILANG, and a transcription is
what goes stale silently. The two **Assumed** ids are deliberately *not* checked against the
Makefile: they are not tools. That separation is the finding's actual answer — **before this field, a
measured `WorldMediated` and a read one wrote the same three characters into the same record.**

**Nothing was blocked.** Three producers exist and three were needed; no fourth requirement appeared.

## 5. Recorded bindings

**Decided** (mine, and reversible):

1. **`basis` is validated on EVERY entry, not only `WorldMediated`.** The reviewers' condition names
   `WorldMediated`; uniform is a strict superset in the same fail-closed direction.
2. **`basis` is `{ producer, revision }`, and `kind` lives in the catalogue rather than in the
   field.** A profile records *what answered and when*; whether that thing measures or assumes is a
   property of the instrument, not of the claim, and putting it in the field would let a profile
   assert its own evidence was a measurement.
3. **Clause 2 (origin tagging) is discharged only by vacuity.** No producer exists; the derivation
   refuses rather than assuming, and names the clause it cannot discharge.
4. **The zero-barrier trigger is discharged by NAMING, not by red.** An extension at zero barriers
   must appear in `installed_packages` or `omitted_extensions`. Naming is not a coverage claim;
   installing is. This is check 3's own shape (`the classifier-2 omission check`) one field over, and
   it keeps the trigger armed rather than spending it.
5. **The four are OMITTED, not installed** — see §2's vacuity argument. Reversible by WI-C5, which
   owns the install.

**Discovered** (the tree's, not mine):

6. **FOUR extensions reach zero barriers, not one.** The handoff anticipated `compaction_structural`
   alone. `decision_framework`, `empty_stop_guard` and `progress_contract_guard` clear on identical
   evidence — they were already the other three of classifier 3's `4 of 15`, and nothing distinguished
   them once the derivation acquired the per-extension unit.
7. **`compaction_structural`'s distinguishing property is real but is not what clears it.** It is the
   one extension of fifteen binding `on_pre_step` as a named top-level function — the form the effect
   checker reads. That makes its declared row *operative* where the other fourteen's is inert, and it
   is why it looked like the sole candidate. But classifier 3 does not read declarations at all
   (S16), so the property is orthogonal to the clearance.
8. **The ABI's own comments disagreed with the derivation the moment it re-shaped.** Three passages
   in `packages/motoko-ext-abi/types.ail` assert *"THE SLOT IS STILL A BARRIER"* — true of the slot,
   and read as a claim about all fifteen extensions because until today there was no other unit.
   Qualified in place per S15 rather than rewritten; one shared block above `on_pre_step`, pointers at
   the other two. Comment-only: no ABI surface change, no `motoko-ext-abi` version move.
9. **`scenario_names_its_omission` asserted the omission list was EXACTLY one entry.** Correct while
   every extension was un-installable for a reason no profile could restate; it had to change *shape*,
   not just its count. It now asserts the structural property (`compaction_ai` still named, every
   entry carries a reason) and deliberately does **not** restate which extensions are at zero
   barriers — that set is derived by `check_fixtures.py`, and a constant here would be P3's defect
   exactly.

## 6. Whether any site admitted two type-checking answers with a silent wrong one

**No. The count stands at 69 across thirty-seven runs; determinism has still caught none.**

This is the first source-shaped item in five — a record type gained a field, a validator gained a
rule, a profile gained four entries — so the population genuinely differs from the last seven, which
were claims and instruments. Three near-misses, all of which surfaced **loudly**:

- `++` on strings in `join_ids`: a **type error naming the operator and the fix**, not a second
  answer. AILANG reserves `++` for lists.
- the probe's first run returned `REJECTED` on **all twenty-four arms**, including the twelve that
  must be `ACCEPTED`. That is the `agree=0` shape — a uniform answer that certifies nothing — and it
  was caught **by the two-sided control**, not by the count. Cause: `MOD010` without
  `AILANG_RELAX_MODULES=1`. Had the probe been one-sided it would have read as "everything is
  effectful" and been silently wrong.
- `re.findall` on `block.group(1)` where the pattern had no capture group: `IndexError`, immediate.

The middle one is the closest this project has come to the failure mode from a *measurement* rather
than from a claim, and it is recorded because the thing that caught it was the control and not the
compiler.

## 7. The global barrier count

**STILL THREE, and nothing moved it.** `on_pre_step`, `on_response_intercept`,
`on_solver_candidate`, re-derived by `make profile_definition` on this run — not carried forward.

**No profile acted.** `driver_only` v13 installs exactly what v12 installed, which is nothing, and
covers exactly what v12 covered, which is nothing. Zero ABI rows changed. What changed is the
*derivation's unit* and, for four extensions, whether the empty install list is FORCED or CHOSEN.

**Profile version bumped v12 → v13**, per the D2/D3/D4/D6/D7 precedent: a claim changed, no anchor
moved. The claim that changed is the one this file has now carried for two versions — *"the empty
install list is FORCED"* — which is still true of eleven extensions and false of four.

## 8. Per S9 — the cache-cold sweep

Run from a fully cleared cache (every repo-local `.ailang` removed **and** the stdlib-adjacent cache
emptied), `AILANG_RELAX_MODULES=1`, after `make sync_packages` (**tenth** consecutive item):

```text
257 .ail files checked        22 non-zero exits, ALL PRE-EXISTING
                               8 scripts/ (7 smoke_v2_*, probe_phase_vocab_sealed)
                               5 src/examples/
                               3 tools/code-graph/tests/fixtures/
                               1 tools/test_coverage/fixtures/unrunnable.ail
                               5 tools/ext_ambient_inventory/fixtures/  (D12's deliberately
                                 unresolvable self-test shapes — read as TEXT by the tool,
                                 never compiled)
                               0 in src/core, 0 in packages/, 0 in any extension closure
```

The stable seventeen from B4/C1/C3/C5 are present member-for-member (8 + 5 + 3 + 1); the five new
ones are D12's fixtures. **WI-D12's sweep reported 220 files and 13 exits: it swept `src scripts
packages` and this one adds `tools`, which is where the 3 code-graph, 1 test-coverage and 5
classifier-3 fixtures live.** Recorded so the two numbers are not read as a regression.

```text
stdlib-adjacent cache at session start:  52 files
after clearing + the whole sweep:         0 files
repo-local std interfaces after sweep:  342
```

**The stdlib-adjacent cache stayed at 0 through the sweep and through `make sync_packages`.** WI-D11
found 52 after that sequence and WI-D12 reproduced 0; this run reproduces D12. **Its producer is
still unidentified and nothing this repository runs is a candidate.** It was archived before clearing
and restored to the 52 files found at session start.

## 9. `make dst` in full

**EXIT 2. Red set: `test_coverage` and `test_coverage_selftest`, and nothing else.** Identical to the
red set recorded at D5, D10, D11 and D12, pre-existing since B2a. `test_coverage` fails on
`src/core/prompts_test.ail` 0/6 (`LDR001: module not found: src/core/prompts`, while
`ailang check src/core/prompts.ail` is clean) and one `stale_skip_record`. Only three `Error N` lines
in 4 543 lines of output, and two of them are that pair.

**Both new behaviours ran inside the aggregate gate and both are green**, twice each (they run under
`profile_definition` and again under `driver_only`):

```text
  ✓ WorldMediated on NO producer …                : rejected by [classification-basis-not-recorded]
  ✓ a real producer, UNDATED …                    : rejected by [classification-basis-not-recorded]
  ✓ a producer this tree does not have            : rejected by [classification-basis-unrecognised]
  ✓ WorldMediated MEASURED by classifier 3, dated : loads clean          ← the control
  ✓ SLOT-level barrier count DERIVED …            : 3
  ✓ barrier count RE-DERIVED per (extension, slot): 33 of 45 pairs stand
  ✓ classification-basis producers re-derived     : 3 measured, 2 assumed
  ✓ src/core/dst_profile.ail                      : 35 inline tests, 0 failed
```

Classifier 3 in the same run: `RESOLUTION 19/19`, `PORT-MEDIATED (4 of 15)`. **Barrier count 3,
DERIVED.**

`ailang.lock` moved by three lines and **two of them are real**: `sunholo/motoko_core` (this item
edited `dst_profile.ail` and `dst_driver_only.ail`) and `sunholo/motoko_ext_abi` (the S15 comment
qualification). `generated_at` moved with them and is **kept** rather than reverted — D11/D12's
precedent covers a lock whose *only* change was the timestamp, and that is not this case.

## 10. Owed, unchanged and not touched here

- **Installing the four**, and the profile that would do it. WI-C5's, and the trigger exists to stop
  an instrument taking it. §2 records the reading it would rest on and the vacuity it would carry.
- Repairing classifier 1 against its amended criterion, with a cache-state precondition (WI-D11), and
  amending `derive.py`'s zero-check to a coverage check.
- The `MOD010` addendum: one stdlib module resolves and forty-five do not.
- The unidentified producer of the stdlib-adjacent cache.
- The gate-table **State** column: three of five rows say "Deferred" for built, green mechanisms. The
  acceptance reviewers'.
- The ADR's "1 of 15" parenthetical, which D12 measured as 0 of 15. Theirs too.
- Criterion 1's basis. The ADR records it as an assumption and the amendment withheld it — and §2 is
  the first item to hit that wall from the measurement side rather than the argument side.
- F3, Route B, WI-C5's cost estimate, the fourteen `register_with_config` rows, the `motoko-ext-abi`
  major at eight rows.
