# WI-D12 — classifier 3 is BUILT, GREEN, and IN `make dst`. Yield **4 of 15**, resolution **19/19**.

Thirty-sixth calibration run. Written against HEAD `cebe9a5`, branch
`arniwesth/mot-73-wi-d10-land-amendments-b-and-a`.

**What was built:** `tools/ext_ambient_inventory/derive.py` (~640 lines), fourteen fixtures plus
`expected.json`, two Makefile targets, **both inside `make dst`**. Zero AILANG source files
modified. Zero documents amended — the ADR's gate-table State cell is the acceptance reviewers' and
is untouched; §7 states the criterion in the form they will need to move it.

## Window

**~1h02m** wall-clock: `2026-08-07T10:14:39Z` → `2026-08-07T11:16Z`. Two measurements dominate it,
both run as one sequence from a fully cleared cache: the 220-file cache-cold sweep and `make dst` in
full.

---

## 1. THE ANSWER

```text
PORT-MEDIATED (4 of 15): compaction_structural, decision_framework,
                         empty_stop_guard, progress_contract_guard
AMBIENT       (11 of 15)
UNRESOLVED    ( 0 of 15)
RESOLUTION    19/19 std modules (100%) imported by the fifteen closures
```

**Third independent derivation, and it agrees.** The amendment review derived 4 of 15; the
acceptance reviewers re-derived it from source rather than accepting it; this tool derives it from a
different producer than either used. Closures measure **2–17 modules**, matching the amendment's
range, and none reaches `src/core/session.ail`.

`compaction_structural` clears. **Nothing has been installed and no profile written** — that is a
separate item and §8 says why the line is there.

---

## 2. The producer, and the one thing it is not

`.ailang/cache/compile/modules/std__*/iface.json`, schema `ailang.iface/v1`, exactly as the
amendment's condition A-1 requires by name. It makes the distinction the whole yield turns on:

```text
jo          purity: true   effect_row: labels {}          -- CLOSED EMPTY ROW
allNumbers  purity: true   effect_row: tail rowvar 'ρ2'   -- EFFECT VARIABLE
```

**The producer disagrees with itself across cache copies, and that is checked rather than assumed.**
A repo-local cache is written per source directory, so the same `std/*` module appears many times
over — 331 `std__*` interfaces at session start, 28 copies of `std/json` alone. They are **not**
byte-identical: type variables are renumbered per compilation, so `std/json` carries 8 distinct
digests and `std/ai` 8. Picking whichever copy the directory walk reached first would have made this
tool's answer a function of walk order. Every copy is read and its per-symbol classification
compared:

```text
24 modules, 38 differing digests, IDENTICAL export sets, ZERO classification disagreements
```

Zero is the measurement, not the assumption. A disagreement is a rejection.

---

## 3. THE CACHE PRECONDITION — the tool builds it, which is what classifier 1 could not do

This is the defect WI-D11 bounded and this item was told not to inherit. It is not inherited, and
the reason is structural rather than careful:

| | classifier 1 | classifier 3 |
|---|---|---|
| producer cache | `~/.local/share/ailang/std/.ailang/cache/` | repo-local `.ailang/cache/compile/` |
| rebuilt by a repository operation? | **no** — WI-D11: 243-file sweep leaves it at 0, `make dst` at 52 | **yes** |
| stated where | `derive.py` docstring only | docstring **and** the Makefile target |
| established by | nothing | **the tool itself, before deriving** |

The tool runs `AILANG_RELAX_MODULES=1 ailang check <package>/register.ail` for each of the fifteen
extensions before deriving. Neither target depends on the other having run, on `make dst` ordering,
or on cache state a reader would have to guess at.

**Measured two-sided, and the two-sidedness is the point.** With every repo-local `.ailang` removed
and the stdlib-adjacent cache emptied:

| tree state | RESOLUTION | PORT-MEDIATED | UNRESOLVED | exit |
|---|---|---|---|---|
| cold, `--no-provision` | **0/19 (0%)** | **0** | **15** | **1** |
| cold, tool provisions itself | 19/19 (100%) | **4** | 0 | 0 |
| after the 220-file cache-cold sweep | 19/19 (100%) | **4** | 0 | 0 |
| warm, as found at session start | 19/19 (100%) | **4** | 0 | 0 |

**A cold tree reports 0 clean and 15 unresolved and exits 1.** It does not report "no findings". That
is the `agree=0 disagree=0` shape refused at the only place it can be refused — in the denominator.

**Resolution is printed as a fraction and enforced: anything short of total is exit 1.** Per S16 as
WI-D6 extended it, the tool reports what the producer can reach as a fraction, not the subset it
happens to cover. A green run means *every extension resolved AND these were clean*; it cannot mean
*the tool found nothing to look at*.

**And per S13, both targets are in `make dst`.** Classifier 1's degradation from `agree=43` to
`agree=1` was invisible for thirty-three items because neither of its targets is. The Makefile
comment says so at the target, so a future reader who wants to move them out finds the reason first.

---

## 4. A door an import-only inventory does not watch — and `compaction_structural` walks through it

**Effects do not enter a closure only through imports.** AILANG's effects are performed by
`_`-prefixed compiler builtins — `std/io.println` is literally `_io_println(s)` — and **a builtin
needs no import**. An inventory that reads only import statements sees none of them.

This is not hypothetical. `compaction_structural` — the one extension this instrument exists to
clear — calls one directly:

```text
packages/motoko-ext-compaction-structural/compaction_structural.ail:251
    _list_length(elide_old_tool_results(msgs, 2)) == 5
```

Seven distinct builtins are called across the extension closures (`_int_to_float`, `_str_len`,
`_str_slice`, `_list_length`, `_float_to_int`, `_str_find`, `_stringToInt`). Had the tool shipped
import-only it would have cleared `compaction_structural` with an unaudited raw builtin call in its
closure — a clean-looking answer over a door it never opened.

**Their effects come from the same producer, not from a list.** A builtin is provably effect-free
only when some `std/*` export whose body calls it carries a **closed empty cached row**: if
`_str_find` performed an effect, `std/string.find` could not be pure, because the effect checker is
transitive through direct builtin calls. That transitivity is what makes the row evidence. Anything
reached only from private helpers, from effect-variable exports, or from a module with no cached
interface is a rejection. **68 builtins are wrapped by an effect-bearing export; all seven the tree
uses resolve PURE, so the yield is unchanged** — but it is unchanged by measurement now.

---

## 5. What the fixture suite pins, and that it can fail

Fourteen fixtures. Six rejections — the five unresolvable shapes the acceptance criterion names, plus
the builtin door — **each paired with a resolving control**, because a rejection-only suite is passed
by a classifier that resolves nothing.

| shape (must be rejected) | its control (must resolve) |
|---|---|
| whole-module alias `import std/trace as Trace` | symbol rename `getEnvOr as ge` → still AMBIENT |
| bare module import, no symbol list | wrapped multi-line list, effectful symbol on the **last** line |
| no cached interface for the module | — (the cache precondition, §3) |
| symbol absent from the interface | `std/json (jo)` → **CLEAN** |
| effect-**variable** row (`std/list.foldlE`) | `std/ai (Message)` → **CLEAN**, a type in the most effect-bearing module |
| builtin of unknown effect | `_list_length` → **CLEAN** on `std/list.length`'s row |
| | `_io_println` → **AMBIENT**, and prose/string mentions → **CLEAN** |

**Falsified, not assumed.** Four independent breakages were introduced and each was caught:

```text
drop compaction_structural from the pinned yield   -> FAIL, residue named
pin scratchpad at packages/motoko-ext-scratchpad   -> FAIL, "resolved packages/motoko_scratchpad"
delete every resolving control                     -> FAIL x2, positive AND two-sided control
run the derivation against a cold cache            -> FAIL, precondition, before the yield is read
```

The second is S22 with the review's strengthening: the falsifier **asserts the resolution member by
member**, all fifteen package directories, not the count. `scratchpad` lives at
`packages/motoko_scratchpad`, so a name-convention resolver returns 14 — and 14 is a plausible-looking
answer that nothing downstream contradicts.

---

## 6. FINDING — the ADR's "1 of 15" for the textual route is **0 of 15** under the ADR's own property 2

Reported rather than decided inline, per the handoff. **It does not move this tool's yield**, which is
4 of 15 on the cached producer and agrees with both prior derivations. It is a claim about a producer
this item deliberately did not build.

`ADR:2396` and `NOTE-acceptance-reviewers-classifier-3-admission.md` §5 both state that on the
per-declaration textual route the same fail-closed discipline yields **1 of 15**, "because
`std/json.jo` carries no row and **three of those four import it**."

**The three-of-four count is exactly right about the extensions' own package sources:**

```text
compaction_structural/compaction_structural.ail:6   import std/json (jo)
empty_stop_guard/empty_stop_guard.ail:4             import std/json (Json, jo)
progress_contract_guard/progress_contract_guard.ail:4  import std/json (Json, jo)
decision_framework                                   -- none
```

**But the unit is the transitive closure, not the package**, which is the amendment's own property 2.
`packages/motoko-ext-abi/types.ail:12` imports `std/json (Json, jo)`, and it is in **all fifteen**
closures — `decision_framework`'s closure is exactly two modules, `register.ail` and that file.
Simulated directly, with `export pure func` read as a textual purity claim and constructors resolved:

```text
TEXTUAL ROUTE  yield 0 of 15   -- all four rejected on std/json.jo, reached through the ABI
CACHED ROUTE   yield 4 of 15
```

**The correction strengthens the criterion rather than weakening it.** The clause exists to say the
cheapest producer would have destroyed the result; under the criterion's own quantifier it destroys
*all* of it. The delta is 1 → 0 in a parenthetical, and it is the acceptance reviewers' cell to
correct if they want it corrected.

---

## 7. The acceptance criterion, stated so it can be run

In the gate table's form. **The State cell is not touched** — it is the acceptance reviewers', per
this item's scope.

> **Met at `cebe9a5`.** `make ext_ambient_inventory` exits 0 having resolved **15 of 15** registrable
> extensions through `ailang.toml` and **19 of 19** stdlib modules their closures import, with zero
> unresolved symbols, and reports its producer (`ailang.iface/v1`) and that producer's per-module
> revision for every extension. `make ext_ambient_inventory_selftest` exits 0 over fourteen fixtures:
> each of the five unresolvable shapes rejected, the sixth (compiler builtin of unknown effect)
> rejected, every one paired with a resolving control, and the **4-of-15 yield pinned in both
> directions with all fifteen package directories asserted member by member**. Both targets are in
> `make dst`. The cache precondition is stated at the target and **established by the tool**, and a
> tree with no cache reports 0 clean / 15 unresolved / exit 1 rather than an absence of findings.

Reproduce with: `make sync_packages && make ext_ambient_inventory ext_ambient_inventory_selftest`,
from the repository root. Under `/tmp` the tool refuses — AILANG auto-relaxes MOD010 there, which
hides the interface failures it exists to report. Inherited refusal, classifier 1 → 2 → 3.

---

## 8. The barrier count is still THREE, and classifier 3 does not move it

`on_pre_step`, `on_response_intercept`, `on_solver_candidate`. Re-derived from
`make profile_definition`, not carried forward.

**A classifier clearing an extension does not clear a barrier; a profile installing one does.**
`check_barrier_count` (`tools/profile_definition/check_fixtures.py:205`) derives barriers from the
ABI row alone — a per-**slot** fact shared by all fifteen extensions. Criterion 2 is per hook of an
*installed* extension, and nothing is installed: `driver_only` installs nothing and there are zero
classification entries in the tree. So classifier 3 clearing `compaction_structural` changes the
count by exactly nothing until a profile acts on it.

**Stopped before that, as instructed.** A profile that installs an extension carries a coverage claim
and a version bump, and the barrier count's derivation changes shape — a measured basis makes a
barrier a property of the **(extension, slot)** pair rather than the slot. The acceptance reviewers'
`basis` condition on `HookClassificationEntry` attaches there, and is due with or before any change
that lowers the count.

**What is now unblocked and was not:** `compaction_structural` is the tree's first extension for
which criterion 2 is established by measurement. Its three barrier-slot hook bodies were already
measured effect-free with a two-sided control, and it is the one extension of fifteen binding
`on_pre_step` as a named top-level function — the form the effect checker reads. Nothing else stands
between it and the first non-zero extension-model coverage number in this project.

---

## 9. Recorded bindings

**Decided** (mine, and reversible):

1. **Tool named `ext_ambient_inventory`, not `classifier_3`** — sibling to `ext_call_inventory`,
   which is its host. The Makefile comment names it classifier 3 in the first line.
2. **An import alone is a rejection; a call site is not required.** Conservative, and it is the
   coarsening both prior derivations used, so the three agree on one rule rather than three.
3. **A whole-module alias is a rejection; a symbol rename is not.** A rename names its source symbol.
   Lumping them would look more conservative while losing the ability to say what an extension does.
4. **`ExtPorts` field calls in the closure are reported but do not soften a verdict.** They are
   property 1's positive half: a classifier that only ever reports absence cannot be told from one
   that resolves nothing. `compaction_ai` shows 1; the four clean extensions show 0 — which is the
   amendment's own prediction, that the first hook classifier 3 clears performs nothing rather than
   mediates.

**Discovered** (the tree's, not mine):

5. **Builtins are a second door and `compaction_structural` uses one** (§4). Not in the handoff, not
   in the amendment, and it would have been a silent fail-open.
6. **The producer is many copies with differing digests** (§2). Walk-order dependence, avoided.
7. **`derive.py` importing `derive.py`.** Classifier 2's module is also named `derive`, so
   `sys.path`-based `import derive` from this tool's own directory resolves to **itself** — silently.
   The module object exists and every shared attribute lookup succeeds; only the first
   classifier-2-only attribute raises. Loaded by explicit path under a distinct name instead.
8. **The ADR's textual-route figure is 0, not 1** (§6).

---

## 10. Whether any site admitted two type-checking answers with a silent wrong one

**No. The count stands at 69 across thirty-six runs; determinism has still caught none.**

This item wrote no AILANG expressions — the fourteen fixtures are `.ail` sources but are read as text
by a Python tool, never compiled, and nothing in `src/` or `packages/` changed. The nearest thing to
the failure mode was item 7 above, and it is the same *shape* in a different language: a name that
resolves to two different modules with one silently wrong. It surfaced as an `AttributeError` on the
first classifier-2-only call rather than as a wrong answer, so it is a caught near-miss, not an
admitted second answer. Recorded here because the seven before it were in claims, citations and
instruments rather than in expressions, and this is an instrument.

---

## 11. Per S9 — the cache-cold sweep

Run from a fully cleared cache (every repo-local `.ailang` removed **and** the stdlib-adjacent cache
emptied), `AILANG_RELAX_MODULES=1`, after `make sync_packages` (eighth consecutive item):

```text
220 .ail files checked          13 non-zero exits, ALL PRE-EXISTING
                                8 scripts/ (smoke_v2_*, probe_phase_vocab_sealed)
                                5 src/examples/
                                0 in src/core, 0 in packages/, 0 in any extension closure
stdlib-adjacent cache after the sweep:  0 files
repo-local std interfaces after the sweep: 324    -- and the tool needs 19 of them
```

**The stdlib-adjacent cache stayed at 0 through the sweep, through `make sync_packages`, and through
`make dst` in full — twice.** WI-D11 recorded 52 after that sequence; this run reproduces the
finding more strongly, not less. `make sync_packages` alone was isolated and measured against a
cleared cache: **0 files**, so it is not the producer of the 52 either. **What produces that cache is
still unidentified, and nothing this repository runs is a candidate.** It does not touch classifier
3, whose producer is repo-local, and it does not change classifier 1's owed repair — it removes one
more candidate explanation for it.

### `make dst` in full

**EXIT 2. Red set: `test_coverage` and `test_coverage_selftest`, and nothing else.** Identical to the
red set recorded at D5, D10 and D11, pre-existing since B2a. `test_coverage` fails on
`src/core/prompts_test.ail` 0/6 (`LDR001: module not found: src/core/prompts`, while
`ailang check src/core/prompts.ail` is clean) and one `stale_skip_record`. This item changed **zero**
AILANG source files, so it cannot have caused either.

**Both new targets ran inside the aggregate gate and both are green**, at `RESOLUTION 19/19` and
`self-test: 0 failure(s)`. **Barrier count 3, DERIVED** by `make profile_definition` on this run:
*"3 barrier(s) stand, so NO extension is installable in a conformant profile."*

`ailang.lock`'s `generated_at` timestamp was the only other tree effect of `make sync_packages`, and
it is reverted, per D11's precedent. The stdlib-adjacent cache was archived before clearing and
restored to the 52 files found at session start.

---

## 12. Owed, unchanged and not touched here

- Repairing classifier 1 against its amended criterion, with a **cache-state precondition** as part
  of the repair (WI-D11), and amending `derive.py`'s zero-check to a coverage check.
- The `MOD010` addendum: one stdlib module resolves and forty-five do not.
- `HookClassificationEntry`'s `basis` field — due with or before any change that lowers the barrier
  count. This item does not lower it (§8).
- The gate-table **State** column: three of five rows say "Deferred" for built, green mechanisms.
  The acceptance reviewers'.
- F3, Route B, WI-C5's cost estimate, the fourteen `register_with_config` rows, the
  `motoko-ext-abi` major at eight rows.
