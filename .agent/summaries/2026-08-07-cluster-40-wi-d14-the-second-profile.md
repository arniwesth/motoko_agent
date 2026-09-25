# 2026-08-07 Cluster 40: WI-D14 — the second profile, and the first time row 3's clauses bind

## Context

Branch: `arniwesth/mot-76-wi-d14-the-second-profile`.

Session span: `7bf37c7` → **uncommitted**. Input was
`HANDOFF-execute-d14-the-second-profile.md`, grounded against HEAD `7bf37c7`
(`2026-08-07T14:47:53Z`). Pin **v0.33.0**. First command `15:38:34Z`.

**The second source-shaped item in a row, and the first one in this project to SHIP A PROFILE THAT
INSTALLS SOMETHING.** Eight files changed (**623 insertions / 16 deletions**) plus three new ones
totalling **1 803** lines. Output note: `NOTE-d14-the-second-profile.md`.

```text
Makefile                                    37 +-    the new target + the dst aggregate (S13)
design_docs/.../m-motoko-dst-framework.md   24 +-    S15 qualification of the public record
packages/motoko-ext-abi/types.ail           11 +     S15 qualification, COMMENT-ONLY
scripts/dst/driver_only_dst.ail              6 +-    the stale ABI version
scripts/dst/profile_definition_dst.ail      81 +-    two new rules at the LOAD-TIME gate
src/core/dst_driver_only.ail                35 +-    v13 -> v14, two false sentences
src/core/dst_profile.ail                   390 +-    Criterion2Clauses + 2 rules + coverage_statement
tools/profile_definition/check_fixtures.py  55 +     the ABI-version re-derivation

NEW  src/core/dst_driver_plus_no_ops.ail           720   the second profile
NEW  scripts/dst/driver_plus_no_ops_dst.ail        585   its acceptance
NEW  tools/profile_definition/check_no_op_profile.py 498 its guard
```

| Definition-of-done item | State |
|---|---|
| The profile defined, loading, validating; four extensions installed with `basis` per entry | **met** — `driver_plus_no_ops/1`, 32 entries, `make profile_definition` + its own target green |
| The four changed rows re-earned or reported; the other seven explicitly not claimed | **met** — rows 3/4/5/7 re-earned, the seven named as unclaimed in the script's own output |
| A statement of what the coverage number means, **in the result** | **met** — `coverage_statement`, computed and guarded |
| The slot-level barrier count unchanged at three | **met** — 3, `33 of 45 pairs stand` |
| Per S13, the new profile's targets inside `make dst` | **met** — green in the aggregate |
| Per S9, cache-cold sweep incl. the stdlib-adjacent cache; `make sync_packages` first | **met** — **eleventh** consecutive item, 259 files / 22 pre-existing exits |
| Per S16 as D12 extended it, enumerate before choosing the scan unit | **met** — and the enumeration caught a slot the pattern would have skipped |
| Stop-and-report conditions | **none fired** — all four clauses held |

---

## The finding the item was for

**Four clauses of ADR-001's acceptance row 3 quantify over INSTALLED extensions**: the coverage floor,
the unconditional-hook rule, the classifier-2 rule, and the per-extension covered/excluded id
disclosure. Every one of them has been **VACUOUS for the entire project**, because `driver_only`
installs nothing. This is the first profile that gave them a non-empty set.

**All four bound. All four held.** Each is asserted twice — as it stands, and against a mutation of
*this same definition* that the clause must reject, because a clause that only ever passes cannot be
told from one that does not run.

| Clause | Bound? | Evidence |
|---|---|---|
| coverage floor | **YES, non-vacuously** | 4 extensions × 8 hooks; emptying the first's covered list → `[coverage-floor]` |
| no unconditionally-dispatched hook excluded | **YES, non-vacuously** | excluded list EMPTY for all four — not even `on_tool_handle`, the one gated slot it could legitimately exclude; excluding `on_pre_step` → `[unconditional-hook-excluded]` |
| classifier-2 rule | **HALF-BOUND, said so** | the derived call list is still empty, so the AILANG rule passes over nothing exactly as for `driver_only`; a call attributed to an installed extension → `[classifier-2-extension-installed]`; what discharges it substantively is classifier 3's `0 ExtPorts calls` per closure, in the guard |
| per-extension covered/excluded **ids** | **YES, non-vacuously** | 4 disclosures × 8 ids, as names |

**The honest half is clause 3 and it is reported rather than claimed.** An empty derived list
intersected with a non-empty install list is still an empty intersection; only the producer on the
other side makes it a measurement.

## The disclosure: row 3's fifth ask, which the ids cannot satisfy

Row 3 ends *"so a profile covering only ABI-pure no-op slots is visible as such"*. **The ids alone
cannot do that** — a no-op hook and a mediating one disclose the same eight names. So the vacuity is a
FIELD and not prose beside the profile:

```text
CLASSIFICATION compaction_structural on_pre_step  world_mediated ext_ambient_inventory measured
                                                  vacuously vacuously substantively
CLASSIFICATION compaction_structural on_tool_policy effect_free  declared_row          assumed
                                                  not_applicable not_applicable not_applicable
```

`HookClassificationEntry` gains `clauses: Criterion2Clauses` — one `ClauseStatus` per criterion-2
clause. **Before this field, "this hook mediates the world through a port" and "this hook performs
nothing, so there is nothing to mediate" wrote the same string `world_mediated` into the same
record** — the shape `basis` closed one level up at WI-D13.

## What the coverage number means, in the result's own words

> **extension-model coverage is NON-ZERO and ENTIRELY OF NO-OPS: 32 hook(s) covered across 4 installed
> extension(s) — 16 on criterion 1 and 16 on criterion 2, of which 16 satisfy criterion 2's port and
> origin-tag clauses VACUOUSLY, i.e. over an empty set of performed effects. ZERO covered hooks
> mediate the world substantively, so this coverage exercises NONE of the world-mediation machinery.
> It is a weaker claim than the number implies and a stronger one than zero.**

WI-D5's mandatory caveat — *"the axis's extension-model coverage is ZERO"* — is **computed rather than
deleted**: `coverage_statement` has three cases and still returns the ZERO sentence for an empty
install list, so the caveat did not vanish the moment it became inconvenient.
`check_no_op_profile.py` **fails** if a profile ever reports non-zero coverage without saying that
none of it mediates. That is WI-D13's "fifth vacuity with a number attached" turned into a rejection
rather than a resolution.

**The 16/16 split, and why not 32 of one kind.** Four ABI slots declare no effect row
(`on_describe_tools`, `on_build_system_prompt`, `on_budget_plan`, `on_tool_policy`) → criterion 1,
basis `declared_row`, kind **Assumed** (`ADR:1415`). Four declare a row (`on_pre_step`,
`on_tool_handle`, `on_response_intercept`, `on_solver_candidate`) → criterion 1 is unavailable (a
named binding cannot declare narrower than a closed ABI slot), so criterion 2, basis
`ext_ambient_inventory`, kind **Measured**, clauses vacuous/vacuous/substantive.

## The four rows that change, and the seven that are not claimed

Per D10 a second profile earns every row itself. WI-D5 tabulated the four `driver_only` buys with its
empty install list; those four are re-earned, and the other seven are **not claimed** — the script
says so in its own output, because a reader who sees four rows earned will otherwise assume the table.

| Row | `driver_only`'s ground | This profile |
|---|---|---|
| **3** | passes **vacuously** | passes **non-vacuously** |
| **4** | `extension_effect_fault` waived *"by construction"* | waived on **different, measured** ground: four installed, none effectful (0 `ExtPorts` calls each), so none can issue the class's delivery request |
| **5** | pass real, **transfer** bought by emptiness | transfers by measurement: 0 ambient sources per installed closure, and installing four added **no** reachable core site |
| **7** | `ScratchpadResult` exemption bought by emptiness | **over-determined**: `provided_tools: []` closes the gated dispatch, and `Delegate`-never-`Handled` closes the path; either alone suffices |

**Row 4's finding, reported not fixed:** the catalogue's condition for `extension_effect_fault` reads
*"…driver_only installs none, so it waives this class by construction"*, and the machinery requires a
waiver's condition to match **verbatim** — so **the second profile records a sentence about the
first**. A shared artifact carrying one profile's name inside a rule that applies to all of them.
Correcting it is a fault-catalogue content change with a version bump and a ripple across every
manifest; WI-D14's remit is the profile.

## The machinery: two rules that bind for the first time

`profile_rules_version` moves **`profile-rules/1` → `profile-rules/2`** — both rules can turn a
definition that loaded clean into a rejection, and D5 versions "what conformant means" on its own
footing.

| Rule | What it closes |
|---|---|
| `world-mediated-on-an-assumed-basis` | D13 checked that a producer is RECOGNISED, not that its KIND is strong enough. `declared_row` is recognised and **Assumed**, so criterion 2 could be recorded off a declaration — the fail-open Amendment A names in so many words (`ADR:1548`). Scoped to `WorldMediated`, with the control that keeps it scoped: the SAME read basis on an `EffectFree` entry is ACCEPTED, because criterion 1's basis *is* an assumption and the amendment withheld criterion 1 |
| `criterion-2-clause-unrecorded` / `criterion-2-clauses-not-applicable` | criterion 2 is a conjunction of three clauses; an entry claiming it must say how each holds, and an entry not resting on it may not carry the evidence. Both directions, plus a resolving control |

Run at **two** levels as D13's were: `ailang test src/core/dst_profile.ail` calls
`validate_classifications` directly, and `profile_definition_dst.ail` runs each through
`validate_definition_at_load` — the same call a runner makes. A rule that is correct and unwired is
the fail-open it exists to close.

**`driver_only`'s verdict did not move, and it is checked rather than asserted:** both rules quantify
over `hook_classifications`, and `driver_only` has none.

## The guard, and why it reads output rather than source

`check_no_op_profile.py` takes the acceptance script's **output**. The classification entries are
computed — built by folding `all_hook_slots()` — so the source does not contain them, and a regex over
the source would check the constructor rather than the record.

```text
✓ install list == the re-derived ZERO-BARRIER set (4 of 15 installable), over 3 barrier slot(s)
✓ installed (4) + omitted (11) == every resolved extension (15), no phantom, no unaccounted
✓ every installed package's version and source path matches the resolved lock graph
✓ all 32 classification entries agree with their producers: 16 criterion 1, 16 criterion 2
✓ every criterion-2 entry's VACUITY is a measurement, not an assertion
✓ CLAIM row3c/row4/row5/row7 each re-derived from its own producer
✓ the coverage statement names the number AND what it means
```

**Two-sided, verified by mutating the output five ways** — a clause status flipped
`vacuously`→`substantively`, a rowless slot reclassified `world_mediated`, an omission dropped, an
extension with standing barriers installed, and the statement's "NO-OPS" removed. **All five
rejected**, each by the check that owns it.

**S16 in force.** Row 7's scan enumerates how an extension can reach the `ScratchpadResult` path —
`provided_tools` as literal / identifier / computed, and `on_tool_handle` bound inline / by name /
threaded — and admits only the literal-inline shapes; every other shape FAILS rather than passing.
The ABI scan's enumeration gained a fifth entry the existing one lacked: **`on_describe_tools` returns
`[ToolSchema]`, and a bare `\w+` capture reads it as unfindable.**

## Whether any site admitted two type-checking answers with a silent wrong one

**YES — ONE, and it is the first LIVE instance rather than a near-miss. The count moves 69 → 70 across
thirty-eight runs. Determinism has still caught none, and did not catch this one.**

**`abi_version`.** `driver_only`'s `extension.abi` boundary note and every manifest built for it said
**4.0**; the ABI package has declared **5.0** since WI-B2b added the world token and the four hook
outcome records. Both readings type-check — `abi_version` is a free `string` field and a free argument
— and the wrong one was silent **for eleven items**, in the one artifact whose entire stated purpose is
exact reproducibility. `dst_profile.ail`'s own header says a manifest "is a transcription by nature …
so every field that CAN be read back from an artifact is read back" and names four rule versions as
"the composition defect's natural home". `abi_version` is a fifth and nobody had put it on the list.

**What found it was not an instrument.** It was writing the SECOND profile's boundary note and having
to ask what number to put in it — a fact becomes checkable the moment a second consumer has to state
it, which is the strongest argument in this item for a second profile existing at all.

**Now guarded, and the guard is total rather than pointed:** `check_abi_version` re-derives the version
from `packages/motoko-ext-abi/ailang.toml` across both profiles' records, fixtures and inline tests,
and **fails if it finds no site to check**. It caught a **third** stale site on its first aggregate run
— `driver_only`'s own inline manifest test, which the two hand-fixes had missed.

Three near-misses in the item's own work, all **loud**: `PAT_INVALID_CONS` on `{…} :: f(…)` in a match
arm; an anonymous record where `DisclosureIds` was expected; and the `[ToolSchema]` return type, caught
by the scan failing closed on an unfindable slot — under a `continue` one slot in eight would have gone
unchecked with every count still looking right.

## Recorded bindings

**Decided** (mine, reversible):

1. **Named for what it covers, not what it installs.** `driver_plus_no_ops` puts the no-op fact in the
   NAME, so a reader meets it before the numbers.
2. **All eight slots covered, nothing excluded.** Stronger than the floor asks; the weaker version
   (cover one, exclude `on_tool_handle`) would leave clause 2 vacuous one level down.
3. **The basis-KIND rule is scoped to `WorldMediated`**, where D13's basis rule was uniform. Uniform
   asks "is there a basis"; this asks "is it strong enough for the claim".
4. **Clause vacuity is checked in PYTHON, not AILANG** — it is a fact about source, and per P3 a
   constant in the module would make the profile agree with itself.
5. **Row 4's catalogue-wording defect is REPORTED, not fixed.**
6. **`driver_only` bumped v13 → v14** for two false sentences and nothing else. A bump for a text
   correction is this file's established mechanism (v10→v11 at D6, v12→v13 at D13); the alternative was
   leaving a knowingly false sentence in a shipped record.
7. **The as-built doc and the ABI comment are QUALIFIED with dates, not rewritten** (S15). The
   as-built's *"it is not a claim about any profile that installs an extension, because none exists"*
   became false on this date.

**Discovered** (the tree's):

8. **All four clauses held on first measurement; the third held only half** — and the *shape* of clause
   3's passing is the finding, not a failure.
9. **`on_tool_handle` is coverable for these four and the barrier derivation never asked.** It treats
   gated slots as non-barriers because they are *excludable*, which says nothing about whether they are
   *coverable*. They are, on the same evidence — raising criterion-2 coverage from 12 hooks to 16.
10. **Installing four extensions added NO reachable core site** — the table's two attributed rows
    belong to `test_dummy` and `scratchpad`. The routing declaration is identical to `driver_only`'s,
    and that identity is a measured result rather than a copy.
11. **Row 7's exemption is over-determined here**, where `driver_only` had one ground.
12. **The rowless slots are *pure*, not always *constant*** — `decision_framework` computes a real
    prompt patch. "No-op" is precise about EFFECTS, which is what criterion 2 quantifies over, and
    imprecise about behaviour. Said because the profile's name uses the shorter word.
13. **The wrong ABI version, live for eleven items** — see above.
14. **The stdlib-adjacent cache's producer is `make sync_packages`.** Three items recorded it as
    unidentified with "nothing this repository runs is a candidate". Clearing first and syncing second
    (rather than D13's order) makes it reproducible: `cache/registry/sunholo/logging/0.4.0/{AGENT.md,
    ailang.toml, logger.ail}` + `state/collaboration.db`, the same four every time.
    **SCOPE: this identifies the 4-file shape and does NOT account for WI-D11's 52.**

## Gates

**Cache-cold whole-tree sweep** (every repo-local `.ailang` removed **and** the stdlib-adjacent cache
emptied, `AILANG_RELAX_MODULES=1`, after `make sync_packages` — eleventh consecutive item):

```text
259 .ail files checked        22 non-zero exits, ALL PRE-EXISTING and identical to D13's
                              member for member (8 scripts/, 5 src/examples/, 3 code-graph
                              fixtures, 1 test-coverage fixture, 5 classifier-3 fixtures)
                              0 in src/core, 0 in packages/, 0 in any extension closure
```

259 against D13's 257: the two new files are this item's own, both clean.

**`make dst`** — every target this item touches is green in the aggregate:

```text
profile_definition_dst PASS       ✓ SLOT barrier count 3   ✓ 33 of 45 pairs stand
                                  ✓ ABI version 5.0 across 6 sites in 4 files
driver_only_dst PASS              ← v14, installs nothing, its coverage still ZERO
driver_plus_no_ops_dst PASS       ← 32 hooks, all no-ops, all guard checks re-derived
```

`src/core/dst_profile.ail`: **42** inline tests, 0 failed (35 at D13). `dst_driver_plus_no_ops.ail`:
**7**, 0 failed.

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — the same pair
recorded at D5, D10, D11, D12 and D13, pre-existing since B2a. **914 ✓ rows in 4 669 lines**, and
neither red target is one this item added or edited.

`ailang.lock` moved by three lines, **two of them real** — `sunholo/motoko_core` and
`sunholo/motoko_ext_abi` (the S15 comment qualification). `generated_at` moved with them and is kept.

**Process note worth recording:** two `make dst` invocations raced on one output file mid-session (a
queued waiter fired while an explicit run was already going). The interleaved log was **discarded
rather than read** — a garbled aggregate log is exactly the kind of artifact a tired reader treats as
evidence.

## Owed, unchanged and not touched here

- **WI-C5's compose-bearing profile.** Compose has real effects, three barriers stand for it, and it
  needs Route B. **Calling this the second profile does not discharge C5** — nothing here covers a hook
  that performs an effect.
- **Route B** — world-mediated process and file seams on `ExtPorts`.
- **The full eleven-row table** for either profile. WI-C4's shape.
- **Criterion 1's evidentiary basis.** Sixteen of this profile's 32 covered hooks rest on it — the
  largest weight that assumption has ever carried in this tree, recorded as `Assumed` in every one of
  those entries so the weight is visible.
- **The `extension_effect_fault` condition's wording.**
- Repairing classifier 1 and its zero-check; the `MOD010` addendum; the remaining unexplained
  stdlib-adjacent cache population (D11's 52); the gate-table **State** column; the ADR's "1 of 15"
  parenthetical; F3; the fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.
