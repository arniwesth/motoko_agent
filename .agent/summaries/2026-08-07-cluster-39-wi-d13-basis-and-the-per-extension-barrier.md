# 2026-08-07 Cluster 39: WI-D13 — land `basis`, re-shape the barrier derivation, decide what `compaction_structural` earns

## Context

Branch: `arniwesth/mot-75-wi-d13-land-basis`.

Session span: `c3de56f` → **uncommitted**. Input was
`HANDOFF-execute-d13-basis-and-the-per-extension-barrier.md`, grounded against HEAD `c3de56f`
(`2026-08-07T11:42:34Z`). Pin **v0.33.0**. First command `11:47:13Z`.

**The first source-shaped item in five.** Seven files changed, **735 insertions / 35 deletions**: a
record type gained a field, a validator gained a rule, a derivation changed its unit, a profile gained
four entries and a version. Output note: `NOTE-d13-basis-and-the-per-extension-barrier.md`.

```text
ailang.lock                                  6 +-     two REAL hashes (motoko_core, motoko_ext_abi)
packages/motoko-ext-abi/types.ail           43 +      S15 qualification, COMMENT-ONLY
scripts/dst/driver_only_dst.ail             59 +-     the omission scenario, re-shaped
scripts/dst/profile_definition_dst.ail      39 +      basis fixtures at the LOAD-TIME gate
src/core/dst_driver_only.ail               108 +-     v12 -> v13, four omissions
src/core/dst_profile.ail                   247 +-     ClassificationBasis + the rule + 5 tests
tools/profile_definition/check_fixtures.py 268 +-     the (extension, slot) derivation
```

| Definition-of-done item | State |
|---|---|
| `basis` landed and validated, rejecting fixture **and** resolving control | **met** — 3 rejections + 1 control, at two levels |
| `check_barrier_count` per `(extension, slot)`, naming the extension, global count still derived and printed | **met** — both granularities, 33 of 45 pairs |
| A decision on `compaction_structural` against **both** criteria, vacuity named | **met** — criterion 2, two clauses vacuous |
| Profile version bump if a recorded claim changed | **met** — v12 → v13 |
| Per S13, both new behaviours inside `make dst` | **met** — green, twice each |
| Per S9, cache-cold sweep incl. the stdlib-adjacent cache; `make sync_packages` first | **met** — tenth consecutive item |
| Per S16, enumerate the ways a subject reaches the scanned-for thing before choosing the unit | **met** — five shapes for clause 3, four fail closed |
| Stop before installing | **met** — the trigger fired and nothing was installed |

---

## The three-part mission, and the one thing the handoff got wrong

### 1. `basis` — the enforcement Amendment A's default lacked

`HookClassificationEntry` gains `basis: ClassificationBasis = { producer, revision }`.

**Why it was owed.** WI-D11 measured that the amendment's fail-closed default (`ADR:1548`) was
*unenforced*: `classification_agrees` validated a `WorldMediated` entry against the disclosure's
excluded-id list **and nothing else**. A profile author could write `WorldMediated` and pass the gate;
what kept that unreachable was the barrier count, not the rule. The acceptance reviewers made the
field the condition of classifier 3's admission, due *"with or before any change that lowers the
barrier count"* — and part 2 of this item is that change.

**Applied to every entry, not only `WorldMediated`.** The reviewers' condition names `WorldMediated`
and it is the entry that can launder an unmeasured claim into coverage — but `EffectFree` is criterion
1, whose basis the ADR itself calls an assumption, and `ExplicitlyExcluded` is a decision. Uniform is
strictly stronger and costs nothing: `basis` is a record field, so every entry already has one and the
only question is whether anything reads it.

**Both halves, because either alone is defeated by a one-word entry.** A blank producer is an unstated
basis. A recognised producer with a blank revision is a claim about a tree that may no longer exist —
and an undatable stale measurement is a failure mode this project has already hit twice.

```text
WorldMediated, NO producer      -> [classification-basis-not-recorded]
real producer, UNDATED          -> [classification-basis-not-recorded]
producer "successor_detector"   -> [classification-basis-unrecognised]
CONTROL: ext_ambient_inventory @ c3de56f  -> LOADS CLEAN, rejection count == 0
```

**Run at two levels deliberately.** `ailang test src/core/dst_profile.ail` calls
`validate_classifications` directly — that proves the rule computes the right answer and proves
nothing about whether the gate asks it. `scripts/dst/profile_definition_dst.ail` runs all four through
`validate_definition_at_load`, **the same call a runner makes**. A rule that is correct and unwired is
the fail-open the field exists to close, and only the second level distinguishes them.

**The catalogue is closed and guarded, and `kind` is the finding's actual answer.**

```text
Measured   ext_ambient_inventory   classifier 3 — the only producer that can establish criterion 2
Measured   ext_call_inventory      classifier 2
Measured   effect_inventory        classifier 1 (a real producer; its answer is load-bearing for nothing here)
Assumed    declared_row            criterion 1's basis, Amendment A's interim rule (ADR:1415/1548)
Assumed    disclosure              the only admissible basis for ExplicitlyExcluded
```

`check_fixtures.py` re-derives the three **Measured** ids from the Makefile and fails if one has no
`.PHONY` target — the list transcribes facts living outside AILANG, and a transcription is what goes
stale silently. The two **Assumed** ids are deliberately *not* checked: they are not tools. That
separation is the point. **Before this field, a measured `WorldMediated` and a read one wrote the same
three characters into the same record.**

Three producers exist, three were needed. **No fourth requirement appeared** — the handoff's
stop-and-report condition on that did not fire.

### 2. The barrier derivation — from the slot to the `(extension, slot)` pair

The slot-level derivation is **retained unchanged**, and its zero-trigger with it. The finer
derivation sits beside it.

```text
✓ SLOT-level barrier count DERIVED from the ABI rows and the dispatch table: 3
  → 3 slot-level barrier(s) stand: no extension is installable on the DECLARED ROW alone

✓ barrier count RE-DERIVED per (extension, slot) — classifier 3 is the third producer: 33 of 45 pairs stand
    CLEARED for 'compaction_structural':   on_pre_step, on_response_intercept, on_solver_candidate — ZERO barriers remain
    CLEARED for 'decision_framework':      … — ZERO barriers remain
    CLEARED for 'empty_stop_guard':        … — ZERO barriers remain
    CLEARED for 'progress_contract_guard': … — ZERO barriers remain
    all 3 barriers stand unchanged for the other 11 extension(s)
```

**Three producers, none deriving from another (S16):** the ABI row, the dispatch table
(`dst_profile_coverage.ail`), and classifier 3 (`ext_ambient_inventory --json`).

**Criterion 2 is a conjunction and the derivation discharges all three clauses or refuses.** Clause 1
is classifier 3's. Clause 3 — explicit world state returned — is derived from the ABI's own outcome-type
declarations. **Clause 2 (origin tagged by extension id) has no producer in this tree** — WI-B4 read
`on_pre_step`'s dispatch by hand, which is one slot and not a derivation — so the check clears a
barrier only when classifier 3 reports **zero** `ExtPorts` field calls, i.e. when there is nothing to
tag. An extension that is PORT-MEDIATED *and* calls a port is refused with `clause 2 UNDISCHARGED`,
naming the call count.

**S16 on the clause-3 scan, enumerated before the unit was chosen:** five ways a slot's outcome type
could carry explicit world state — flat `next_state` field, nested record, alias, type parameter,
renamed field. Only the first is matched; **the other four read as absent, which leaves the barrier
standing.** Fail-closed in the direction that can refuse a hook that in fact returns world state and
cannot clear one that does not.

### 3. The criterion decision — the item's durable output

**CRITERION 2, on a measured basis, with clauses 1 and 2 VACUOUS and clause 3 substantive.** The
handoff's criterion-1 stop rule does **not** fire.

**Criterion 1 — true in substance, unavailable as a basis.** Re-measured at this item rather than
carried forward, two-sided, over **all twelve** barrier-slot hook bodies of the four extensions:

```text
                                      rowless      control (+ println)
compaction_structural   ×3            ACCEPTED     REJECTED  Missing effects: IO
decision_framework      ×3            ACCEPTED     REJECTED  Missing effects: IO
empty_stop_guard        ×3            ACCEPTED     REJECTED  Missing effects: IO
progress_contract_guard ×3            ACCEPTED     REJECTED  Missing effects: IO
```

But criterion 1's basis is the **declared row** (`ADR:1415`; WI-B4 settled that its scope is
classification generally, not criterion 1 alone). Those rows are `! {AI, IO, Trace}`,
`! {IO, Process, FS, Clock}`, `! {Process}`, and a named binding cannot narrow a closed ABI slot.
**On its own basis criterion 1 fails.** Admitting a measurement into it is an ADR-scope act the
amendment withheld — so criterion 1 is *unavailable*, not merely unearned, and that is precisely why
the stop rule does not fire. The answer is not "criterion 1"; it is "criterion 1 has no route".

**Criterion 2:**

| Clause | Verdict | Basis |
|---|---|---|
| (1) effectful only through D1 world-mediated ports | **VACUOUS** | 0 ambient sources, 0 `ExtPorts` calls — the quantifier holds over an empty set |
| (2) origin tagged by extension id | **VACUOUS** | nothing performed, so no origin to tag |
| (3) explicit world state returned | **satisfied, NON-vacuously** | all twelve return `next_state: ctx.world`; the field is derived from the ABI |

**The vacuity is named rather than banked.** Amendment A predicted it in advance (`ADR:1611`): *"the
first hook classifier 3 clears will be one that performs nothing, not one that mediates."* The
coverage these four would buy is coverage of **no-ops** — a true measurement producing a real non-zero
number, and **not** evidence that the world-mediation machinery works, because installing them
exercises none of it. `driver_only`'s acceptance table already leans on an empty install list in four
places; this would be a fifth vacuity, **harder to see because it arrives with a number attached.**
That is the reason recorded for declining, and it is a reason about *evidence*, not correctness.

---

## The one thing the handoff got wrong: it is FOUR extensions, not one

The handoff is built end-to-end around `compaction_structural`. **`decision_framework`,
`empty_stop_guard` and `progress_contract_guard` clear on identical evidence** — they were already the
other three of classifier 3's `4 of 15`, and nothing distinguished them once the derivation acquired
the per-extension unit.

**`compaction_structural`'s distinguishing property is real but is not what clears it.** It is the one
extension of fifteen binding `on_pre_step` as a **named top-level function** — the form the effect
checker reads — which makes its declared row *operative* where the other fourteen's is inert. That is
why it looked like the sole candidate. But classifier 3 does not read declarations at all (S16), so
the property is orthogonal to the clearance.

---

## The trigger: fired, and discharged by NAMING rather than spent

The armed trigger was the item's central design question. Three readings were available and the third
is the one taken:

- **Let it go red and stop.** Accurate, but leaves the aggregate gate blocked on a decision that is
  out of scope, permanently.
- **Weaken it to a warning.** A fail-open, and exactly the shape this project keeps catching.
- **Require the zero-barrier set to be ACCOUNTED FOR BY NAME** — installed *or* omitted. Taken. It is
  check 3's own shape (the classifier-2 omission check) one field over. **Naming is not a coverage
  claim; installing is.** The trigger stays armed rather than being spent, and the handoff's own DoD
  anticipated the profile version bump this implies.

Two-sided, because a guard that only ever passes cannot be told from one that does not run:

| Arm | Result |
|---|---|
| four zero-barrier extensions, none named | `FAIL: … has reached ZERO for extension(s) ['compaction_structural', 'decision_framework', 'empty_stop_guard', 'progress_contract_guard']` |
| one entry removed after the other four landed | `FAIL: … ['empty_stop_guard']` — fires **per extension**, naming it |
| all named | green, with the derived set printed |

**Nothing was installed.** The install, its coverage claim and its version bump remain WI-C5's.

---

## Two artifacts that disagreed with the tree the moment the unit changed

**The ABI's own comments.** Three passages in `packages/motoko-ext-abi/types.ail` assert *"THE SLOT IS
STILL A BARRIER"* — true of the slot, and read as a claim about all fifteen extensions because until
today there was no other unit. Qualified in place per S15 rather than rewritten: one shared block above
`on_pre_step`, pointers at the other two. **Comment-only — no ABI surface change, no `motoko-ext-abi`
version move.** This is the same shape as the header/`omitted_extensions` disagreement WI-D7 caught
inside `dst_driver_only.ail`, one file over.

**`scenario_names_its_omission` asserted the omission list was EXACTLY one entry.** Correct while every
extension was un-installable for a reason no profile could restate. It had to change **shape**, not
just its count: it now asserts the structural property (`compaction_ai` still named, every entry
carries a reason) and deliberately does **not** restate which extensions are at zero barriers. That set
is derived by `check_fixtures.py`, and a constant here would be plan rule P3's defect exactly — a
profile made to agree with itself.

---

## Recorded bindings

**Decided** (mine, and reversible):

1. `basis` validated on **every** entry, not only `WorldMediated` — a strict superset in the same
   fail-closed direction.
2. `basis` is `{ producer, revision }`; **`kind` lives in the catalogue, not the field.** Whether an
   instrument measures or assumes is a property of the instrument; in the field it would let a profile
   assert its own evidence was a measurement.
3. **Clause 2 is discharged only by vacuity.** No producer exists; the derivation refuses and names the
   clause it cannot discharge.
4. **The zero-barrier trigger is discharged by NAMING, not by red.**
5. **The four are OMITTED, not installed.**

**Discovered** (the tree's, not mine):

6. **Four extensions reach zero barriers, not one.**
7. `compaction_structural`'s named-binding property is orthogonal to the clearance.
8. The ABI's three "STILL A BARRIER" comments disagreed with the derivation on re-shape.
9. `scenario_names_its_omission` pinned a count where it should have pinned a shape.

---

## Whether any site admitted two type-checking answers with a silent wrong one

**No. 69 across thirty-seven runs; determinism has still caught none.**

The population genuinely differs from the last seven runs, which were claims and instruments — this one
changed a record type, a validator and a derivation. Three near-misses, **all loud**:

- `++` on strings in `join_ids` — a type error naming the operator *and* the fix. AILANG reserves `++`
  for lists.
- **the probe's first run returned `REJECTED` on all twenty-four arms**, including the twelve that must
  be `ACCEPTED`. That is the `agree=0` shape — a uniform answer certifying nothing — and it was caught
  **by the two-sided control, not by the count**. Cause: `MOD010` without `AILANG_RELAX_MODULES=1`. One-sided
  it would have read as *"everything is effectful"* and been silently wrong.
- `re.findall` on `block.group(1)` where the pattern had no capture group — `IndexError`, immediate.

The middle one is the closest this project has come to the failure mode from a **measurement** rather
than from a claim, and it is recorded because what caught it was the control and not the compiler.

---

## The global barrier count

**STILL THREE**, re-derived by `make profile_definition` on this run — `on_pre_step`,
`on_response_intercept`, `on_solver_candidate`. **No profile acted**, no ABI row moved.

**`driver_only` v12 → v13**, per the D2/D3/D4/D6/D7 precedent: a claim changed, no anchor moved. The
claim is the one this file has carried for two versions — *"the empty install list is FORCED"* — which
is still true of eleven extensions and **false of four**. v13 installs exactly what v12 installed,
which is nothing, and covers exactly what v12 covered, which is nothing.

---

## Gates

**`make dst`: EXIT 2. Red set `test_coverage` and `test_coverage_selftest`, and nothing else** —
identical to D5, D10, D11 and D12, pre-existing since B2a. Only three `Error N` lines in 4 543 lines of
output, two of them that pair. Both new behaviours green inside the aggregate, twice each (they run
under `profile_definition` and again under `driver_only`). Classifier 3 in the same run:
`RESOLUTION 19/19`, `PORT-MEDIATED (4 of 15)`. `src/core/dst_profile.ail`: 35 inline tests, 0 failed.

**S9 cache-cold sweep**, every repo-local `.ailang` removed and the stdlib-adjacent cache emptied,
`AILANG_RELAX_MODULES=1`, after `make sync_packages` (tenth consecutive item):

```text
257 .ail files checked      22 non-zero exits, ALL PRE-EXISTING
                             8 scripts/     5 src/examples/     3 code-graph fixtures
                             1 test_coverage fixture
                             5 ext_ambient_inventory fixtures (D12's deliberately unresolvable shapes)
                             0 in src/core, 0 in packages/, 0 in any extension closure
```

The stable seventeen from B4/C1/C3/C5 are present member-for-member. **WI-D12 reported 220 files / 13
exits because it swept `src scripts packages`; this one adds `tools`, where the other nine live.**
Recorded so the two are not read as a regression.

**The stdlib-adjacent cache held at 0 through the sweep and through `make sync_packages`** — 52 at
session start, 0 after clearing and through everything, archived and restored to 52. WI-D11 found 52
after that sequence; D12 and now D13 both reproduce 0. **Its producer is still unidentified and
nothing this repository runs is a candidate.**

`ailang.lock` moved three lines and **two are real**: `sunholo/motoko_core` (this item edited two
`src/core` modules) and `sunholo/motoko_ext_abi` (the S15 comment qualification). `generated_at` moved
with them and is **kept** — D11/D12's revert precedent covers a lock whose *only* change was the
timestamp, which is not this case.

---

## Owed, unchanged and not touched here

- **Installing the four**, and the profile that would do it — WI-C5's. The reading it would rest on and
  the vacuity it would carry are recorded in the note's §2 and in `omitted_extensions`.
- Repairing classifier 1 against its amended criterion, with a cache-state precondition (WI-D11), and
  amending `derive.py`'s zero-check to a coverage check.
- The `MOD010` addendum: one stdlib module resolves and forty-five do not.
- The unidentified producer of the stdlib-adjacent cache.
- The gate-table **State** column — three of five rows say "Deferred" for built, green mechanisms. The
  acceptance reviewers'.
- The ADR's "1 of 15" parenthetical, which D12 measured as 0 of 15. Theirs too.
- **Criterion 1's basis.** The ADR records it as an assumption and the amendment withheld it — and this
  is the first item to hit that wall from the **measurement** side rather than the argument side.
- F3, Route B, WI-C5's cost estimate, the fourteen `register_with_config` rows, the `motoko-ext-abi`
  major at eight rows.
