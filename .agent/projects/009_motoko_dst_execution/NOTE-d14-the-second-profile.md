# WI-D14 — the second profile, and the first time row 3's clauses bind

Grounded against HEAD `7bf37c7`. Thirty-eighth calibration run.

**Headline: all four of ADR-001 row 3's installed-extension clauses BOUND, and all four held.** The
second profile is `driver_plus_no_ops/1`: four extensions installed, 32 hooks covered, **zero of them
mediating the world**. The slot-level barrier count is still THREE and no ABI row moved. `driver_only`
bumped v13 → v14 for two false sentences and its verdict did not move.

**And the item found the failure mode this project has been counting for thirty-eight runs, LIVE
rather than as a near-miss**: `driver_only` and every manifest built for it had been pinning
**ABI 4.0** since WI-B2b took the ABI to **5.0**. Both readings type-check; nothing compared them.
Found by having to write the number down for a second profile — see §9.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `7bf37c7` — `2026-08-07T14:47:53+00:00` |
| first command | `2026-08-07T15:38:34Z` |
| work window | ~50 min from the handoff commit to grounding |

## 2. Row 3's four installed-extension clauses — the item's durable output

**Every one of them has quantified over the empty set for the entire project.** This is the first
profile that gave them a non-empty set, and each is asserted TWICE — as it stands, and against a
mutation of *this same definition* that the clause must reject. A clause that only ever passes cannot
be told from one that does not run.

| Clause | Bound? | What it said |
|---|---|---|
| (1) coverage floor — every installed extension covers ≥1 hook | **YES, non-vacuously** | 4 extensions, 8 hooks each. Mutation (first extension's covered list emptied) → `[coverage-floor]` |
| (2) no unconditionally-dispatched hook excluded | **YES, non-vacuously** | 4 × 7 unconditional slots, and the excluded list is EMPTY for all four — not even `on_tool_handle`, the one gated slot this profile could legitimately exclude. Mutation (exclude `on_pre_step`) → `[unconditional-hook-excluded]` |
| (3) no installed extension calls a classifier-2 `ExtPorts` field | **HALF-BOUND, and said so** | see below |
| (4) per-extension covered/excluded hook **ids** in the result | **YES, non-vacuously** | 4 disclosures × 8 ids, printed as names |

**Clause 3 is the honest one and it is reported rather than claimed.** The AILANG rule quantifies over
the DERIVED CALL LIST, which is empty at HEAD, so on this run it passes over nothing exactly as it did
for `driver_only`. What is new is that it now has a non-empty INSTALL list to intersect with: a
classifier-2 call attributed to an installed extension is rejected by
`[classifier-2-extension-installed]`, which is a real question about this profile rather than about a
fixture. What discharges the clause substantively is a measurement on the other side —
**classifier 3 reports 0 `ExtPorts` field calls in each of the four installed closures** — and that is
a Python-side derivation in `check_no_op_profile.py`, not a green line in the script. Saying which
half is which is the point.

### The fifth thing row 3 asks for, and it is what the item is actually about

Row 3's final clause is *"so a profile covering only ABI-pure no-op slots is visible as such"*. **The
ids alone cannot do that** — a no-op hook and a mediating one disclose the same eight names. So the
vacuity is a FIELD:

```
CLASSIFICATION compaction_structural on_pre_step  world_mediated ext_ambient_inventory measured
                                                  vacuously vacuously substantively
CLASSIFICATION compaction_structural on_tool_policy effect_free  declared_row          assumed
                                                  not_applicable not_applicable not_applicable
```

`HookClassificationEntry` gains `clauses: Criterion2Clauses`, one status per criterion-2 clause, and
the gate requires a criterion-2 entry to record all three and any other entry to record none.
**Before this field, "this hook mediates the world through a port" and "this hook performs nothing,
so there is nothing to mediate" wrote the same string `world_mediated` into the same record** — which
is the shape `basis` closed one level up at WI-D13.

## 3. The four changed rows, and the seven not claimed

Per D10 this profile earns every row itself and inherits none of `driver_only`'s. WI-D5 tabulated the
four that lean on the empty install list; those four are re-earned here and **the other seven are NOT
claimed**, which the acceptance script states in its own output rather than leaving to a reader.

| Row | `driver_only`'s ground | This profile's answer |
|---|---|---|
| **3** boundary honesty | passes **vacuously** | **PASSES non-vacuously.** Four clauses bound; clause 3 half-bound and reported |
| **4** faults reach recovery | `extension_effect_fault` waived *"by construction"* | **WAIVED on different ground, measured**: four installed, none with an effectful hook — 0 `ExtPorts` calls per closure, so none can issue the class's delivery request (`ExtPorts.ai_step`). INAPPLICABLE by measurement, not by emptiness |
| **5** virtual time | pass real, **transfer** bought by emptiness | **TRANSFERS, measured**: classifier 3 reports 0 ambient sources in each installed closure, so no installed extension reads a clock. Installing four added NO reachable core site — asserted as an equality against the empty-install claim, not restated as 7/6/1 |
| **7** oracle completeness | `ScratchpadResult` exemption bought by emptiness | **RE-EARNED on two independent facts**, either sufficient: all four bind `provided_tools: []` (so the gated `on_tool_handle` dispatch is never reached — `ext/runtime.ail:356`), and all four return `Delegate`, never `Handled` |

**Rows 1, 2, 6, 8, 9, 10 and 11 are NOT re-earned for this profile.** Running the whole table is
WI-C4's shape and a separate item; a row not run is a row not earned.

### The row-4 finding: a shared catalogue carrying one profile's name

`extension_effect_fault`'s applicability condition reads *"…the selected D5 profile installs an
extension with an effectful hook that issues this world request; **driver_only installs none**, so it
waives this class by construction (plan P4)"*. The machinery requires a waiver's condition to match
the catalogue's **verbatim**, so **the second profile records a sentence about the first**. That is a
defect in the catalogue's wording rather than in either profile — a rule that applies to all profiles
with one profile's name inside it — and it is **reported, not fixed**: correcting it is a
fault-catalogue content change with its own version bump and its own ripple across every manifest.
The waiver's substance is unaffected and is stronger here than there.

## 4. What the coverage number means, in the result's own words

Computed by `coverage_statement`, printed by the target, and checked by the guard:

> **extension-model coverage is NON-ZERO and ENTIRELY OF NO-OPS: 32 hook(s) covered across 4
> installed extension(s) — 16 on criterion 1 and 16 on criterion 2, of which 16 satisfy criterion 2's
> port and origin-tag clauses VACUOUSLY, i.e. over an empty set of performed effects. ZERO covered
> hooks mediate the world substantively, so this coverage exercises NONE of the world-mediation
> machinery. It is a weaker claim than the number implies and a stronger one than zero.**

WI-D5's mandatory caveat — *"the axis's extension-model coverage is ZERO"* — is **computed rather than
deleted**. `coverage_statement` has three cases and still returns the ZERO sentence for an empty
install list, so the caveat did not disappear the moment it became inconvenient. `check_no_op_profile.py`
**fails** if a profile reports non-zero coverage without saying that none of it mediates: that is the
"fifth vacuity with a number attached" made into a rejection rather than a resolution.

The split, and why 16/16 rather than 32 of one kind:

- **16 hooks on criterion 1** — the four ABI slots with NO declared effect row (`on_describe_tools`,
  `on_build_system_prompt`, `on_budget_plan`, `on_tool_policy`). Basis `declared_row`, kind
  **Assumed** (`ADR:1415`). A reader sees from the record alone that these are READ, not measured.
- **16 hooks on criterion 2** — the four rowed slots (`on_pre_step`, `on_tool_handle`,
  `on_response_intercept`, `on_solver_candidate`). Criterion 1 is unavailable for them: a named
  binding cannot declare narrower than a closed ABI slot. Basis `ext_ambient_inventory`, kind
  **Measured**, clauses vacuous/vacuous/substantive.

**`on_tool_handle` is covered rather than excluded**, deliberately. It is the one gated slot and the
only one this profile could legitimately exclude; excluding it would have left clause 2 vacuous again
one level down. All four bind it to `{ decision: { Delegate }, next_state: ctx.world }`.

## 5. The machinery: two rules that bind for the first time

`profile_rules_version` moves **`profile-rules/1` → `profile-rules/2`**, because both rules can turn a
definition that loaded clean into a rejection.

| Rule | What it closes | Fixtures |
|---|---|---|
| `world-mediated-on-an-assumed-basis` | WI-D13 checked that a basis producer is RECOGNISED and not that its KIND is strong enough. `declared_row` is recognised and Assumed, so criterion 2 could be recorded off a declaration — the fail-open Amendment A names in so many words (`ADR:1548`) | rejecting arm + the control that keeps it scoped: the SAME read basis on an `EffectFree` entry is ACCEPTED, because criterion 1's basis *is* an assumption and Amendment A withheld criterion 1 |
| `criterion-2-clause-unrecorded` / `criterion-2-clauses-not-applicable` | criterion 2 is a conjunction of three clauses, and an entry claiming it must say how each holds | both directions, plus the control that resolves: classifier 3, dated, vacuous/vacuous/substantive |

Run at **two** levels as D13's were: `ailang test src/core/dst_profile.ail` calls
`validate_classifications` directly (the rule computes the right answer) and
`profile_definition_dst.ail` runs each through `validate_definition_at_load` — **the same call a
runner makes**. A rule that is correct and unwired is the fail-open the rule exists to close.

**`driver_only`'s verdict did not move, and that is checked rather than asserted:** both new rules
quantify over `hook_classifications`, and `driver_only` has none. `make driver_only` says so on the
same gate call.

## 6. The guard, and why it reads output rather than source

`tools/profile_definition/check_no_op_profile.py` takes the acceptance script's **output**, not
`dst_driver_plus_no_ops.ail`. The classification entries are computed — built by folding
`all_hook_slots()` — so the source text does not contain them, and a regex over the source would be
checking the constructor rather than the record. Six checks, each against a producer the profile does
not control:

```
✓ install list == the re-derived ZERO-BARRIER set (4 of 15 installable), over 3 barrier slot(s)
✓ installed (4) + omitted (11) == every resolved extension (15), no phantom, no unaccounted
✓ every installed package's version and source path matches the resolved lock graph
✓ all 32 classification entries agree with their producers: 16 criterion 1 (rowless slot,
  declared_row/assumed), 16 criterion 2 (rowed slot, classifier 3/measured)
✓ every criterion-2 entry's VACUITY is a measurement, not an assertion
✓ CLAIM row3c/row4/row5/row7 each re-derived from its own producer
✓ the coverage statement names the number AND what it means
```

**Two-sided, verified by mutating the output five ways** — a clause status flipped
`vacuously`→`substantively`, a rowless slot reclassified `world_mediated`, an omission dropped, an
extension with standing barriers installed, and the statement's "NO-OPS" removed. **All five were
rejected**, each by the check that owns it.

**Per S16 as D12 extended it**, each new scan enumerates first. Row 7's scan enumerates the ways an
extension can reach the `ScratchpadResult` path — `provided_tools` as a literal / an identifier / a
computed expression, and `on_tool_handle` bound inline / by name / threaded — and admits only the
literal-inline shapes. **Every other shape FAILS rather than passing**, so the scan can refuse an
extension that never emits and cannot bless one that does. The ABI scan's enumeration gained a fifth
entry the existing one lacked: **`on_describe_tools` returns `[ToolSchema]`, and a bare `\w+` capture
reads it as unfindable.** Caught by making an unfindable slot a FAIL; under a `continue` it would have
been one of the eight silently skipped.

## 7. Recorded bindings: decided versus discovered

**Decided** (mine, and reversible):

1. **The profile is named for what it covers, not for what it installs.** `driver_plus_no_ops` says
   the coverage is of no-ops in the profile's NAME, so a reader meets that fact before the numbers.
   D10 requires the name to describe the system under test; the driver plus four extensions that do
   nothing is what it is.
2. **All eight slots covered, nothing excluded.** Stronger than the floor asks for. The weaker
   version — cover one, exclude `on_tool_handle` — would have left clause 2 vacuous again.
3. **The basis-KIND rule is scoped to `WorldMediated`**, where D13's basis rule was deliberately
   uniform. Uniform asks "is there a basis"; this asks "is the basis strong enough for the claim",
   and the answer differs per claim. Requiring a measurement for `EffectFree` would be this module
   deciding an ADR-scope question the amendment withheld.
4. **The clause statuses are checked against classifier 3 in PYTHON, not in AILANG.** `Vacuously` vs
   `Substantively` is a fact about source; per P3 a constant in the module would make the profile
   agree with itself.
5. **The row-4 catalogue-wording defect is REPORTED, not fixed.** Correcting it is a fault-catalogue
   content change with a version bump and a ripple across every manifest; WI-D14's remit is the
   profile.
6. **`driver_only` bumped v13 → v14** for two false sentences and nothing else — see §8. A bump for a
   text correction is this file's established mechanism (v10→v11 at D6, v12→v13 at D13); the
   alternative was leaving a knowingly false sentence in a shipped record.
7. **The as-built design doc and the ABI's `on_budget_plan` comment are QUALIFIED with dates, not
   rewritten** (S15). The as-built's *"it is not a claim about any profile that installs an
   extension, because none exists"* became false on this date.

**Discovered** (the tree's, not mine):

8. **All four clauses held on the first measurement, and the third held only half.** The handoff said
   a failure would be worth more than the profile; none failed, and the finding is instead the
   *shape* of clause 3's passing — an empty derived list intersected with a non-empty install list is
   still an empty intersection, and only the producer on the other side makes it a measurement.
9. **`on_tool_handle` is coverable for these four and the barrier derivation never asked.** The
   derivation treats gated slots as non-barriers because they are excludable, so it says nothing
   about whether they are COVERABLE. They are, on the same evidence as the three barrier slots, and
   that raised the coverage from 12 hooks to 16 on criterion 2.
10. **Installing four extensions added NO reachable core site**, because the attribution table's two
    attributed rows belong to `test_dummy` and `scratchpad`. The routing declaration is
    byte-identical to `driver_only`'s, and that identity is a measured result rather than a copy.
11. **Row 7's exemption is over-determined for this profile.** `provided_tools: []` alone closes the
    gate; the `Delegate` binding alone closes the path. `driver_only` had one ground (emptiness);
    this profile has two, and neither is emptiness.
12. **`compaction_structural.on_build_system_prompt` and `decision_framework`'s are not equally
    no-op**, and the coverage statement's wording accommodates it: the rowless slots are *pure*, not
    necessarily *constant* — `decision_framework` computes a real prompt patch. "No-op" is precise
    about EFFECTS, which is what criterion 2 quantifies over, and imprecise about behaviour. Stated
    because the profile's name uses the shorter word.
13. **`driver_only` and `driver_only_dst` had been pinning the WRONG ABI VERSION for eleven items.**
    Both said `4.0`; the ABI package has declared `5.0` since WI-B2b added the world token and the
    four hook outcome records. Found by writing the second profile's boundary note and checking what
    number to put in it. **Nothing compared it to anything** — `abi_version` is a free string
    argument to the manifest builder, so both readings type-check and the stale one is silent, in the
    one artifact whose entire job is exact reproducibility. Corrected under the v14 bump, dated per
    S15, and now GUARDED: `check_fixtures.check_abi_version` re-derives it from
    `packages/motoko-ext-abi/ailang.toml` across **both** profiles' records and fixtures, and fails
    if it re-derives no site at all.
14. **The stdlib-adjacent cache's producer is `make sync_packages`** — see §11. Three items recorded
    it as unidentified; the identification cost nothing but running S9's steps in a different order.

## 8. `driver_only` v13 → v14, and why that is not moving its verdict

**Two things, and both are corrections to text rather than to claims.**

**One clause became false.** `compaction_structural`'s omission reason said installing it *"is
WI-C5's, not an instrument's side effect"*. **WI-D14 installed it — in a different profile.** Neither
WI-C5 nor an instrument took the decision; a second profile did, which D10 always permitted and which
the sentence did not contemplate. Qualified in place with its date per S15 rather than rewritten.

**One had already been false for eleven items.** The `extension.abi` boundary note said "ABI 4.0" and
`driver_only_dst`'s manifest argument passed `"4.0"`; the ABI has been 5.0 since WI-B2b. Corrected,
dated, and guarded — see §7.13. **This is the one place where a second profile did what a second
profile is supposed to do**: writing down the ABI version for a new record is what made anyone look at
the old one.

**Nothing else moved.** Install list still empty, coverage still zero, waivers unchanged, no
classification, no anchor, attribution ref unchanged, and the four vacuities WI-D5 tabulated for this
profile are unchanged in extent. This is the same kind of bump as v10→v11 (D6) and v12→v13 (D13): a
claim changed, no anchor moved. **`driver_only`'s eleven-row verdict is untouched**, and the two new
machinery rules cannot reach it because both quantify over an empty list.

## 9. Whether any site admitted two type-checking answers with a silent wrong one

**YES — ONE, and it is the first in this project's counting that was LIVE rather than a near-miss.
The count moves 69 → 70 across thirty-eight runs. Determinism has still caught none, and it did not
catch this one either.**

**The site: `abi_version`, in `driver_only`'s `extension.abi` adapter boundary and in every manifest
this tree builds for it.** Both said `4.0`. The ABI package has declared `5.0` since WI-B2b. Both
readings type-check — `abi_version` is a free `string` field and a free argument to the manifest
builder — and the wrong one was silent **for eleven items**, in the one artifact whose entire stated
purpose is exact reproducibility. The manifest's own module comment says a manifest "is a
transcription by nature … so every field that CAN be read back from an artifact is read back", and
lists four rule versions as "the composition defect's natural home". `abi_version` is a fifth and
nobody had put it on the list.

**What found it was not an instrument.** It was writing the SECOND profile's boundary note and having
to ask what number to put in it. That is the mechanism this project has recorded twice before under a
different name — a fact becomes checkable the moment a second consumer has to state it — and it is
the strongest argument in this item for a second profile existing at all.

**Now guarded**, and the guard is total rather than pointed: `check_abi_version` re-derives the
version from `packages/motoko-ext-abi/ailang.toml` across both profiles' records, fixtures and inline
tests, and **fails if it finds no site to check**. It caught a THIRD stale site on its first aggregate
run — `driver_only`'s own inline manifest test, which the two hand-fixes had missed.

Beyond that one, three near-misses in this item's own work, all **loud**:

- `PAT_INVALID_CONS` on `{ ... } :: f(...)` in a match arm: a parse error naming the construct, not a
  second answer. Fixed with a `let`.
- `on_describe_tools`'s `[ToolSchema]` return type made the ABI scan unable to find one of the eight
  slots. **Caught by the scan failing closed on an unfindable slot**, which was written that way
  before the pattern was; had it been a `continue`, one slot in eight would have gone unchecked and
  every count would still have looked right. This is the closest thing to the failure mode in this
  run, and what caught it was the fail-closed default rather than the compiler.
- an anonymous record type where `DisclosureIds` was expected: a type error at the field, immediate.

## 10. The slot-level barrier count

**STILL THREE.** `on_pre_step`, `on_response_intercept`, `on_solver_candidate`, re-derived by
`make profile_definition` on this run. `33 of 45 pairs stand` — unchanged, and the four cleared
extensions are the same four. **No ABI row moved**; the only ABI edit is a dated comment
qualification, as at WI-D13, with no version move on `motoko-ext-abi`.

`ailang.lock` moved by three lines and **two of them are real**: `sunholo/motoko_core` (this item
edited `dst_profile.ail` and `dst_driver_only.ail` and added a module) and `sunholo/motoko_ext_abi`
(the S15 comment qualification). `generated_at` moved with them and is **kept**.

## 11. Per S9 — the cache-cold sweep, and the cache producer IDENTIFIED

Run from a fully cleared cache (every repo-local `.ailang` removed **and** the stdlib-adjacent cache
emptied), `AILANG_RELAX_MODULES=1`, after `make sync_packages` (**eleventh** consecutive item):

```text
259 .ail files checked        22 non-zero exits, ALL PRE-EXISTING
                               8 scripts/ (7 smoke_v2_*, probe_phase_vocab_sealed)
                               5 src/examples/
                               3 tools/code-graph/tests/fixtures/
                               1 tools/test_coverage/fixtures/unrunnable.ail
                               5 tools/ext_ambient_inventory/fixtures/
                               0 in src/core, 0 in packages/, 0 in any extension closure
```

**Identical to WI-D13's 22, member for member.** The file count is 259 against D13's 257: the two new
files are this item's own (`src/core/dst_driver_plus_no_ops.ail` and
`scripts/dst/driver_plus_no_ops_dst.ail`), both of which check clean.

### The producer of the stdlib-adjacent cache is IDENTIFIED, and it is `make sync_packages`

WI-D11 found 52 files there after the S9 sequence, D12 and D13 reproduced 0, and three items running
have recorded the producer as unidentified with "nothing this repository runs is a candidate". **It
is a candidate and it is reproducible.** The identification came free from running the S9 steps in a
different ORDER — clear, then sync, then sweep, where D13 synced first and cleared after:

```text
find ~/.ailang -mindepth 1 -delete   →  0 files
make sync_packages                   →  4 files, and the same 4 every time:
    cache/registry/sunholo/logging/0.4.0/{AGENT.md, ailang.toml, logger.ail}
    state/collaboration.db
```

`sunholo/logging@0.4.0` is `ailang.toml:9`'s one REGISTRY-resolved dependency — the very package
`validate_scan_roots`' comment names as the reason the scan-root gate exists. Resolving it writes the
registry cache; the `state/` file arrives with the same command. **The sweep alone writes nothing
there**, which is why D12 and D13 measured 0 and concluded nothing this repo runs produces it.

**SCOPE, stated rather than overclaimed: this identifies the 4-file shape and does NOT account for
WI-D11's 52.** Four is not fifty-two, and a different population may still have a different producer.
What is now false is the claim that no command in this repository writes to that directory.

## 12. `make dst` in full

**Every target this item touches is GREEN inside the aggregate gate**, and both profiles load through
the same `validate_definition_at_load` a runner calls:

```text
  profile_definition_dst PASS
  ✓ SLOT-level barrier count DERIVED from the ABI rows and the dispatch table: 3
  ✓ barrier count RE-DERIVED per (extension, slot): 33 of 45 pairs stand
  ✓ the ABI version every profile record names is the one the package declares: 5.0
                                                     (6 sites across 4 files)
  driver_only_dst PASS                     ← v14, installs nothing, coverage still ZERO
  ✓ src/core/dst_driver_only.ail
  driver_plus_no_ops_dst PASS              ← the second profile, 32 hooks, all no-ops
  ✓ no claim in this profile is a stale transcription: the install set, every
    classification, every clause status and every row claim was re-derived
  ✓ src/core/dst_driver_plus_no_ops.ail
```

`src/core/dst_profile.ail` runs **42** inline tests, 0 failed (35 at WI-D13; the seven new ones are
this item's two rules, their controls, and the substance/statement assertions).
`src/core/dst_driver_plus_no_ops.ail` runs **7**, 0 failed.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — identical to the
set recorded at D5, D10, D11, D12 and D13, pre-existing since B2a. **914 ✓ rows in 4 669 lines**, and
neither red target is one this item added or edited.

(An earlier partial run of this session was DISCARDED rather than reported: two `make dst` invocations
raced on one output file when a queued waiter fired while an explicit run was already going. A garbled
aggregate log is exactly the kind of artifact a tired reader treats as evidence, so it was re-run
clean from a single invocation and only that run is above.)

**Two `make dst` invocations raced on one output file earlier in this session** (a queued waiter fired
while an explicit run was already going), and the interleaved output was discarded rather than read.
Recorded because a garbled aggregate log is exactly the kind of artifact a tired reader treats as
evidence.

## 13. Owed, unchanged and not touched here

- **WI-C5's compose-bearing profile.** Compose has real effects, three barriers stand for it, and it
  needs Route B. **This item is not that**, and calling this the second profile does not discharge
  C5. Nothing here covers a hook that performs an effect.
- **Route B** — world-mediated process and file seams on `ExtPorts`.
- **The full eleven-row table** for either profile. WI-C4's shape.
- **Criterion 1's evidentiary basis.** The ADR records it as an assumption and the amendment withheld
  it. Sixteen of this profile's 32 covered hooks rest on it, which is the largest weight that
  assumption has ever carried in this tree — recorded as `Assumed` in every one of those entries so
  the weight is visible.
- **The `extension_effect_fault` condition's wording**, per §3.
- Repairing classifier 1 and its zero-check; the `MOD010` addendum; the unidentified producer of the
  stdlib-adjacent cache; the gate-table State column; the ADR's "1 of 15" parenthetical; F3; the
  fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.
