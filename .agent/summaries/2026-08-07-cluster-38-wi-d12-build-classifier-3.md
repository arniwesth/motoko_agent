# 2026-08-07 Cluster 38: WI-D12 — build classifier 3, the extension-closure ambient-source inventory

## Context

Branch: `arniwesth/mot-73-wi-d10-land-amendments-b-and-a`.

Session span: `cebe9a5` → **uncommitted**. **Zero AILANG source files changed. Zero documents
amended** — the ADR's gate-table State cell is the acceptance reviewers' and was left alone. Input
was `HANDOFF-execute-d12-build-classifier-3.md`, grounded against HEAD `cebe9a5`. Pin **v0.33.0**.

Built: `tools/ext_ambient_inventory/derive.py` (~640 lines), fourteen fixtures plus `expected.json`,
two Makefile targets **inside `make dst`**. Output note:
`NOTE-d12-build-classifier-3.md`.

Window: **~1h02m**, `10:14:39Z` → `11:16Z`. Two measurements dominate it, run as one sequence from a
fully cleared cache: the 220-file cache-cold sweep and `make dst` in full, twice.

| Definition-of-done item | State |
|---|---|
| `make classifier_3` green, in `make dst` | **met** — `ext_ambient_inventory{,_selftest}`, both in the aggregate gate |
| Selftest on classifier 2's pattern, resolving control beside each shape | **met** — 6 rejections, 8 controls, 4 breakages injected and all caught |
| Acceptance criterion met and stated in the gate table's form | **met** — note §7; State cell untouched, per scope |
| 4-of-15 yield derived by the tool, list resolved through `ailang.toml`, residue empty | **met** — and the resolution is asserted member by member, not counted |
| Cache precondition stated and enforced, resolution as a fraction | **met** — and **established by the tool**, which is more than was asked |
| Per S13, in `make dst`; per S9, cache-cold sweep incl. stdlib-adjacent cache | **met** |
| Stop before installing anything | **met** — `compaction_structural` clears; nothing installed |

---

## The answer

```text
PORT-MEDIATED (4 of 15): compaction_structural, decision_framework,
                         empty_stop_guard, progress_contract_guard
AMBIENT       (11)   UNRESOLVED (0)   RESOLUTION 19/19 std modules (100%)
```

**Third independent derivation, and it agrees.** The amendment review derived 4 of 15; the acceptance
reviewers re-derived it from source; this tool derives it from a producer neither used. Closures
**2–17 modules**, matching the amendment's range, none reaching `src/core/session.ail`.

---

## The item's central finding: effects have a SECOND door, and the target extension walks through it

**AILANG effects are performed by `_`-prefixed compiler builtins — `std/io.println` is literally
`_io_println(s)` — and a builtin needs no import.** An inventory that reads only import statements
sees none of them. The handoff, the amendment and both prior derivations are all import-based.

It is not hypothetical:

```text
packages/motoko-ext-compaction-structural/compaction_structural.ail:251
    _list_length(elide_old_tool_results(msgs, 2)) == 5
```

**`compaction_structural` is the one extension this instrument exists to clear**, and shipping
import-only would have cleared it with an unaudited raw builtin call in its closure — a clean-looking
answer over a door never opened. Seven distinct builtins are called across the fifteen closures.

**Their effects come from the same producer, not from a list.** A builtin is provably effect-free only
when some `std/*` export whose body calls it carries a **closed empty cached row**: if `_str_find`
performed an effect, `std/string.find` could not be pure, because the effect checker is transitive
through direct builtin calls. That transitivity is what makes the row evidence. 68 builtins are
wrapped by an effect-bearing export; all seven the tree uses resolve PURE, **so the yield is
unchanged — but it is unchanged by measurement now.**

---

## The cache precondition — not inherited, because the tool can build it

This is the defect WI-D11 bounded for classifier 1 and this item was told not to inherit. It is not
inherited, and the reason is structural rather than careful:

| | classifier 1 | classifier 3 |
|---|---|---|
| producer cache | `~/.local/share/ailang/std/.ailang/cache/` | repo-local `.ailang/cache/compile/` |
| rebuilt by a repository operation? | **no** (WI-D11) | **yes** |
| stated where | `derive.py` docstring only | docstring **and** the Makefile target |
| established by | nothing | **the tool itself, before deriving** |

The tool runs `AILANG_RELAX_MODULES=1 ailang check <package>/register.ail` per extension before
deriving, so neither target depends on the other having run, on `make dst` ordering, or on cache
state a reader would have to guess at. Measured two-sided from a fully cleared tree:

| tree state | RESOLUTION | PORT-MEDIATED | UNRESOLVED | exit |
|---|---|---|---|---|
| cold, `--no-provision` | **0/19 (0%)** | **0** | **15** | **1** |
| cold, tool provisions itself | 19/19 | **4** | 0 | 0 |
| after the 220-file cache-cold sweep | 19/19 | **4** | 0 | 0 |
| warm, as found at session start | 19/19 | **4** | 0 | 0 |

**A cold tree reports 0 clean and 15 unresolved and exits 1. It does not report "no findings."** That
is the `agree=0 disagree=0` shape refused at the only place it can be refused — in the denominator.
Resolution prints as a fraction and anything short of total is exit 1.

**Per S13 both targets are in `make dst`**, with the reason written at the target so a future reader
who wants to move them out finds it first.

---

## FINDING: the ADR's "1 of 15" for the textual route is 0 of 15, under the ADR's own property 2

Reported rather than decided inline. **It does not move the tool's yield**, which is 4 of 15 and
agrees with both prior derivations; it is a claim about a producer this item deliberately did not
build.

`ADR:2396` and the admission note §5 both state the textual route yields **1 of 15**, "because
`std/json.jo` carries no row and **three of those four import it**."

**The three-of-four count is exactly right about the extensions' own package sources** —
`compaction_structural`, `empty_stop_guard` and `progress_contract_guard` import `jo` directly;
`decision_framework` does not. **But the unit is the transitive closure**, which is the amendment's
own property 2, and `packages/motoko-ext-abi/types.ail:12` imports `std/json (Json, jo)` and sits in
**all fifteen** closures — `decision_framework`'s closure is exactly that file plus `register.ail`.
Simulated directly, with `export pure func` read as a textual purity claim and constructors resolved:

```text
TEXTUAL ROUTE  0 of 15   -- all four rejected on std/json.jo, reached through the ABI
CACHED ROUTE   4 of 15
```

**The correction strengthens the criterion rather than weakening it:** the clause exists to say the
cheapest producer would have destroyed the result, and under the criterion's own quantifier it
destroys all of it. The delta is 1 → 0 in a parenthetical, and the cell is the acceptance reviewers'.

---

## The producer disagrees with itself, and that is checked rather than assumed

A repo-local cache is written per source directory, so the same `std/*` module appears many times over
— **331 `std__*` interfaces at session start, 28 copies of `std/json` alone**. They are **not**
byte-identical: type variables are renumbered per compilation, so `std/json` carries 8 distinct
digests. **Picking whichever copy the directory walk reached first would have made the tool's answer a
function of walk order.** Every copy is read and compared:

```text
24 modules, 38 differing digests, IDENTICAL export sets, ZERO classification disagreements
```

Zero is the measurement. A disagreement is a rejection.

---

## What the fixture suite pins, and that it can fail

Fourteen fixtures: the five unresolvable shapes the criterion names, plus the builtin door, **each
paired with a resolving control** — because a rejection-only suite is passed by a classifier that
resolves nothing. The two controls the producer choice turns on are `std/json (jo)` (no textual row,
closed empty cached row) and `std/ai (Message)` (a type in the most effect-bearing module).

**Falsified, not assumed.** Four breakages injected, each caught:

```text
drop compaction_structural from the pinned yield   -> FAIL, residue named
pin scratchpad at packages/motoko-ext-scratchpad   -> FAIL, "resolved packages/motoko_scratchpad"
delete every resolving control                     -> FAIL x2, positive AND two-sided control
derive against a cold cache                        -> FAIL, precondition, BEFORE the yield is read
```

The second is **S22 with the review's strengthening**: the falsifier asserts the resolution **member
by member**, all fifteen package directories, not the count. `scratchpad` lives at
`packages/motoko_scratchpad`, so a name-convention resolver returns 14 — a plausible-looking answer
nothing downstream contradicts.

---

## Gates

- **`make dst` in full: EXIT 2. Red set `test_coverage` and `test_coverage_selftest`, and nothing
  else** — identical to the set recorded at D5, D10 and D11, **pre-existing since B2a**. This item
  changed zero AILANG source files. `test_coverage` fails on `src/core/prompts_test.ail` 0/6
  (`LDR001: module not found: src/core/prompts`, while `ailang check src/core/prompts.ail` is clean)
  plus one `stale_skip_record`.
- **Both new targets ran inside the aggregate gate and both are green**: `RESOLUTION 19/19`,
  `self-test: 0 failure(s)`.
- **Barrier count 3, DERIVED** by `make profile_definition` on this run. *"3 barrier(s) stand, so NO
  extension is installable in a conformant profile."*
- **`make ext_call_inventory_selftest` green** — classifier 2 is the host and its fixtures still pass
  after being imported by a second tool.
- **Cache-cold sweep, `AILANG_RELAX_MODULES=1`, after `make sync_packages`** (eighth consecutive
  item): 220 files, **13 non-zero exits, all pre-existing** — 8 `scripts/`, 5 `src/examples/`,
  **0 in `src/core`, 0 in `packages/`, 0 in any extension closure**.
- **The stdlib-adjacent cache stayed at 0** through the sweep, through `make sync_packages`, and
  through `make dst` in full **twice**. WI-D11 recorded 52 after that sequence; this run reproduces
  the finding **more strongly**. `make sync_packages` was isolated against a cleared cache: **0
  files**, so it is not the producer either. **What writes those 52 files is still unidentified and
  nothing this repository runs is a candidate.** It does not touch classifier 3 (repo-local producer)
  and it removes one candidate explanation for classifier 1's owed repair.
- `ailang.lock`'s `generated_at` was the only other tree effect of `make sync_packages`; **reverted**,
  per D11's precedent. The stdlib-adjacent cache was archived before clearing and **restored to the
  52 files found at session start**.

---

## Rules earned

- **A structural classifier must enumerate every door an effect can enter by, not the door the
  specification happened to name.** The amendment, the handoff and two independent derivations were
  all import-based; builtins need no import and the target extension calls one. **Ask what the
  language lets you do without the construct you are scanning for.**
- **A precondition a tool can establish should be established, not stated.** Classifier 1's cache
  precondition could only ever be documented, and its coverage moved 45 → 1 → 45 on an unchanged tree
  with nothing saying so. Classifier 3's is repo-local, so the tool builds it and then reports the
  fraction. **Documenting a precondition is what you do when you cannot enforce it — check which case
  you are in before writing the paragraph.**
- **A producer that exists in many copies is a producer that can disagree with itself.** Reading the
  first copy the walk finds makes the answer a function of walk order. Read them all and compare;
  cheap, and the alternative is nondeterminism that looks like a measurement.
- **Two names for the same file collide silently in the importer, not at the call.**
  `tools/ext_ambient_inventory/derive.py` importing `derive` resolved to itself; the module object
  exists and every shared-name lookup succeeds. **Load sibling tools by path under a distinct name.**
- **A count that is right about the package can be wrong about the closure.** "Three of those four
  import it" is exactly true of the extensions' own sources and exactly wrong under the criterion's
  own quantifier, because a file in every closure imports it too. **When a criterion names a unit,
  re-count in that unit.**

---

## Calibration

- **Thirty-sixth calibration run.** No new site admitting two type-checking answers with a silent
  wrong one — **still 69 across thirty-six runs, and determinism has caught none.** This item wrote
  no AILANG expressions; the fourteen fixtures are `.ail` sources read as text and never compiled.
- **The near-miss was the same shape one language over.** `derive.py` importing `derive.py` is a name
  resolving to two different things with one silently wrong. It surfaced as an `AttributeError` on
  the first classifier-2-only call rather than as a wrong answer, so it is a caught near-miss, not an
  admitted second answer. Recorded because the last seven were in claims, citations and instruments
  rather than in expressions, **and this is an instrument**.
- **Count discrepancy in the record itself, flagged not fixed:** cluster 36's summary reads *"still 66
  across thirty-five runs"*; this item's handoff reads *"69 across thirty-five runs"*. Both describe
  the same thirty-five runs. The handoff's figure was used here. **Someone owns reconciling it**, and
  it is exactly this project's most-recorded failure shape — a fact correct in one place and wrong in
  another.

---

## Owed, newly

1. **Reconcile the 66-vs-69 calibration count** across cluster 36's summary and the D12 handoff.
2. **The ADR's textual-route figure, 1 → 0** (`ADR:2396` and the admission note §5). The acceptance
   reviewers' cell; the correction strengthens their argument.
3. **`src/core/prompts_test.ail`'s `LDR001`** — `ailang check src/core/prompts.ail` is clean while
   `ailang test src/core/prompts_test.ail` cannot load the module it imports. Part of the
   pre-existing `test_coverage` red, but the mechanism is now named.

## Owed, carried forward unchanged

4. **Repair classifier 1** against its amended criterion, with a **cache-state precondition** as part
   of the repair (WI-D11), and amend `derive.py`'s zero-check to a coverage check. Putting both
   targets into `make dst` remains its precondition.
5. **The `MOD010` addendum:** one stdlib module resolves and forty-five do not.
6. **`HookClassificationEntry`'s `basis` field** — due with or before any change that lowers the
   barrier count. **This item does not lower it:** barriers are derived per-slot from the ABI row,
   nothing is installed, and a classifier clearing an extension is not a profile installing one.
7. **The gate-table State column** — three of five rows say "Deferred" for built, green mechanisms.
   Classifier 3 is now a fourth. The acceptance reviewers'.
8. **F3**, Route B, WI-C5's cost estimate, the fourteen `register_with_config` rows, the
   `motoko-ext-abi` major at eight rows.

## What is now unblocked and was not

**`compaction_structural` is the tree's first extension for which criterion 2 is established by
measurement.** Its three barrier-slot hook bodies were already measured effect-free with a two-sided
control, and it is the one extension of fifteen binding `on_pre_step` as a named top-level function —
the form the effect checker reads. Nothing else stands between it and **the first non-zero
extension-model coverage number in this project**. That is a separate item: a profile installing an
extension carries a coverage claim and a version bump, and the barrier count's derivation changes
shape, which is where the `basis` condition attaches.

## Operational

- **Nothing committed.** `Makefile` modified; `tools/ext_ambient_inventory/` and the D12 note
  untracked.
- `make sync_packages` run first, EXIT 0, eighth consecutive item.
