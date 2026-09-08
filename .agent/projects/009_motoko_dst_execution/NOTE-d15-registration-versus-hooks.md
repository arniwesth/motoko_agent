# WI-D15 — criterion 2 quantifies over HOOKS, and the closure was never the scope

Grounded against HEAD `a75d8a0`. Thirty-ninth calibration run.

**The reading: criterion 2 quantifies over hooks. Registration is not in its scope.** The answer rests
entirely on two sentences already in the ADR, and the second of them already calls classifier 3's unit
a *coarsening*. Nothing was reversed; the ADR was taken at its own word.

**Classifier 3 is sharpened, fail-closed, and in `make dst` as `ext_hook_scope`. The yield moves
4 of 15 → 5 of 15, and the two sets are NOT nested.** Hook scope ADDS `mcp` and `test_dummy`; it
**DROPS `compaction_structural`** — not because a hook of it reaches an effect, but because `show` is
a door the shipped tool does not watch. That drop is the item's most important finding.

**`compaction_ai` does not clear.** It is HOOK-UNRESOLVED as built, and HOOK-PORT-MEDIATED only in a
labelled counterfactual. **No profile acted**, and the stop rule was not tripped.

---

## 1. The git wall-clock window

| | |
|---|---|
| HEAD at session start | `a75d8a0` — `2026-08-07T16:45:00+00:00` |
| first command | `2026-08-07T16:47Z` |
| work window | ~45 min |

## 2. The reading, and its reasoning — the item's durable output

**D5, `ADR:1295-1300`:** *"An extension may appear as covered in a conformant profile only when
**every hook reachable within that profile** is either (1) … or (2) effectful only through D1
world-mediated ports…"* The quantifier is over hooks. `register_with_config` is not one of the eight
ABI slots.

**Amendment A's property 2, `ADR:1484-1490`, opens by agreeing and then derives the unit from it:**
*"Criterion 2 quantifies over every hook an installed extension registers, **so** the unit is the
extension's transitive module closure."* **The `so` is the whole argument.** The closure is offered as
the unit that makes the measurement *total over hooks* — a means, not a redefinition.

**And the amendment already calls it a coarsening, in its own words** (`ADR` yield paragraph):

> Because the unit is the extension's closure and the discipline is fail-closed, classifier 3 can
> never clear a single hook of an extension whose closure is dirty — `compaction_ai` included, via
> `register.ail`'s `std/env` and `std/fs`. **The coarsening is *conservative*, so it is the right
> direction, but it caps the instrument's reach at four extensions.**

**A coarsening is not a definition.** The ADR names its own unit as coarser than the criterion and
prices the difference. So the tree does not hold a contradiction between the verdict and
`driver_only.ail:597`'s counter-claim — it holds a conservative instrument and a sharper claim, and
until this item nothing compared them.

**Where a reader goes wrong is property 2's parenthetical**, which reads like registration is in
scope: *"the hook is bound in `register.ail`, which imports `std/env` and `std/fs`."* The stated
reason is *where hook-reachable text lives*, not that registration is a hook. **Property 2 was
written to defeat a FILE-scoped argument** — the `dst_driver_only.ail:597` defect WI-D9 named — and
the closure defeats it. It overshoots only if read as fixing the quantifier.

**Consequence, stated plainly: `driver_only.ail:597`'s claim about `compaction_ai` was scoped
correctly in KIND and wrongly in EXTENT.** Scoping to `compaction_ai.ail` was too narrow — the hook is
bound in `register.ail` and `compaction_ai.ail` is not the whole of what it reaches. Scoping to the
closure is too wide. The right unit is neither file, and this item built it.

## 3. The file is not the split, and the tree holds the proof

**The obvious sharpening — drop `register.ail` from the closure — is FAIL-OPEN, and it is refuted by
this repository rather than by argument.**

`packages/motoko-ext-microrag/register.ail` holds `microrag_tool_handle`, **bound to `on_tool_handle`**,
which reaches `std/fs.writeFile` and `std/process.exec` through `auto_write_with_microrag`. Dropping
"the registration module" clears microrag of two ambient sources a hook really reaches.

**Measured, and the numbers are larger than the argument needs:**

- **9 of 15** extensions have the `ExtensionHooks` record — and therefore every inline hook body —
  located in `register.ail` itself;
- **6 of 15** go further and declare NAMED top-level hook functions there: `compaction_structural`
  (`pre_step`, `no_budget_patch`), `microrag` (`microrag_tool_handle`, `microrag_tool_policy`,
  `microrag_describe_tools`), `context_mode`, `decision_framework`, `empty_stop_guard`,
  `progress_contract_guard`.

**So dropping "the registration module" drops hook-reachable text for nine of fifteen extensions.**
It is not the registration module; it is a module that usually holds registration AND hooks. A
file-level split would have moved the yield 4 → 7 with **microrag among the three**, which is
admitting by accident.

**So the split is REACHABILITY-granular**, computed outward from the eight bindings, and every step it
cannot resolve is a rejection.

## 4. The doors, enumerated BEFORE the unit was chosen (S16, as D12 extended it)

D12 found the builtin door this way. Re-running the enumeration for a hook-scoped unit found **two
more**, and one of them is live in the shipped tool.

| # | Door | Status |
|---|---|---|
| 1 | an effect-bearing `std/*` symbol applied in hook-reachable text | watched |
| 2 | a `_`-prefixed compiler builtin applied there — D12's door | watched |
| **3** | **a NON-underscore LANGUAGE builtin — `show`** | **NEW, and `derive.py` does not watch it — §6** |
| **4** | **a call site inside a STRING INTERPOLATION** | **NEW; `strip_noise` blanks it — closed here by `keep_interpolations`** |
| 5 | a hook bound to something unresolvable — computed, threaded, over the hop limit | rejection |
| 6 | an effect performed at REGISTRATION whose result a hook closes over | out of scope, **and reported** — §7 |

**Door 4, measured:** over the fifteen closures, **10 builtin calls and 2 effectful std-symbol calls
exist ONLY inside string interpolations**. None changes the shipped import-granular verdict — which is
why it has cost nothing so far — but a call-granular reader that inherited `strip_noise`'s lid would
be blind to every one. `control_interpolated_call.ail` is the two-sided fixture.

**Six binding shapes were enumerated before the walker was written**, all present in the tree: inline
lambda; named top-level function in the same module; named function imported from another closure
module; a local `let` holding a lambda; the whole record produced by a delegated call (5 of 15,
including one reached through a RENAMED import); and a call through a registration-computed value.

## 5. The yield, both readings, side by side

```text
extension                 closure unit      hook scope            reg-only sources
  a2a                     AMBIENT           HOOK-AMBIENT          4
  ailang_docs             AMBIENT           HOOK-UNRESOLVED       2
  compaction_ai           AMBIENT           HOOK-UNRESOLVED       2
  compaction_structural   PORT-MEDIATED     HOOK-UNRESOLVED       0
  compose                 AMBIENT           HOOK-UNRESOLVED       1
  context_mode            AMBIENT           HOOK-UNRESOLVED       3
  decision_framework      PORT-MEDIATED     HOOK-PORT-MEDIATED    0
  empty_stop_guard        PORT-MEDIATED     HOOK-PORT-MEDIATED    0
  exa_search              AMBIENT           HOOK-UNRESOLVED       3
  mcp                     AMBIENT           HOOK-PORT-MEDIATED    3
  microrag                AMBIENT           HOOK-UNRESOLVED       0
  omnigraph               AMBIENT           HOOK-UNRESOLVED       4
  progress_contract_guard PORT-MEDIATED     HOOK-PORT-MEDIATED    0
  scratchpad              AMBIENT           HOOK-AMBIENT          1
  test_dummy              AMBIENT           HOOK-PORT-MEDIATED    1

HOOK-PORT-MEDIATED (5 of 15)  decision_framework, empty_stop_guard, mcp,
                              progress_contract_guard, test_dummy
```

**+2, −1, and the sets are not nested.**

- **`mcp` and `test_dummy` ADDED**, and both are the WI-D6 shape exactly: registration reads
  `Env`/`FS`, the hooks close over the resulting DATA and perform nothing. **`mcp` was verified by
  hand rather than taken from the tool**: `readFile`/`fileExists` appear only in `read_mcp_config`,
  called at registration; `make_hooks`'s `handle` pattern-matches `servers` and returns `Delegate` or
  an error envelope.
- **`compaction_structural` DROPPED** — on door 3, not on behaviour. §6.

**`compaction_ai` does NOT clear as built.** Its `ExtPorts.ai_step` call IS resolved — the tool
reports `ports=1`, property 1's positive half — and its hooks reach no ambient source. It is
HOOK-UNRESOLVED solely on `show`. **In the labelled counterfactual where door 3's residue is resolved
effect-free, the yield is 7 of 15 and `compaction_ai` is among them** — which is
`driver_only.ail:597`'s claim, independently derived. That number is printed as a counterfactual and
is not a verdict.

**Nothing was installed and no profile acted**, per the handoff's stop rule.

## 6. Door 3 — the finding that matters most, and it is in the SHIPPED tool

**`show` is applied in eight of the fifteen closures, including `compaction_structural`.** It needs no
import, is declared nowhere, and is not `_`-prefixed — so **`derive.py` neither resolves it nor
rejects it. It does not look at it.**

**`compaction_structural` is the extension `driver_plus_no_ops` rests on**: four installed extensions
and sixteen criterion-2 entries trace back to classifier 3 clearing it. It calls `show(...)` at five
sites in `compaction_structural.ail`. Under the closure unit that costs nothing, because the verdict
is import-granular. **Under any call-granular unit it is the dominant term** — the only reason the
hook-scope yield is 5 rather than 7.

**No producer at HEAD can classify it, and this was measured rather than assumed:**

- **Every `show(` in the 46-module stdlib corpus is inside a `--` COMMENT.** Interpolation-aware or
  not, no cached row anywhere carries evidence for it.
- **A textual derivation was tried and DISCARDED.** Applying the `_`-builtin evidence rule to
  non-underscore names cannot tell a language builtin from a higher-order PARAMETER applied in a std
  body: it resolved `f`, `p`, `pred`, `get`, `put` and `cas` as "language builtins", classifying `f`
  EFFECTFUL and `p` PURE. **A rule that invents evidence is worse than one that reports its absence**,
  so it was removed and the names are reported as a named residue.

**This is condition A-1's shape and it is OWED**, named in the draft rather than worked around. The
shipped verdict is deliberately NOT flipped: doing so would take `compaction_structural` to
UNRESOLVED and invalidate the second profile's basis for sixteen entries, which is a stop-and-report,
not an instrument's call.

## 7. What accounts for registration effects — the obligation the reading creates

**Ruling registration out of criterion 2 does not make it stop happening.** Derived per extension:

```text
  a2a          4   std/net.httpGet, std/fs.fileExists, std/fs.readFile, std/env.getEnvOr
  omnigraph    4   std/fs.fileExists, std/fs.readFile, std/env.getEnvOr,
                   std/extension.requireWorkdirFile
  context_mode 3 | exa_search 3 | mcp 3 | ailang_docs 2 | compaction_ai 2
  compose 1 | scratchpad 1 | test_dummy 1
```

**`a2a` performs a NETWORK GET at registration.** Under the closure reading that was counted — wrongly
— as a criterion-2 failure. Under the hooks reading it is correctly not one, **and it must not
thereby become invisible.**

**The home is D5's disclosure obligation**, drafted as a new `registration_effects` field in
`DRAFT-amendment-adr-001-registration-effects.md`. Disclosure rather than a new criterion, because D5
already carries exactly one mechanism for facts that are real, bounded and not conformance-deciding.
**Drafted and NOT applied**: ADR-001 is Accepted and corrections route through a normal round.

**Criterion 2's text needs no amendment** — it already says "every hook" — so the stop rule *"if the
reading requires amending D5's criterion 2 text, draft and stop"* did not fire on the criterion. It
fired on the obligation, and that is drafted.

## 8. Route B's revised cost, for WI-C5's owner — DOWN, with a new prerequisite

D9's condition A-2 priced Route B as stripping every effect-bearing import from a **17-module
closure**. Re-derived under the hooks reading:

| | closure ambient | hook-reachable | reg-only | closure modules | modules holding hook-reachable sources |
|---|---|---|---|---|---|
| `compose` | 28 | **≥23** | 1 | 17 | **6** |
| `context_mode` | 6 | **≥3** | 3 | 7 | **2** |

**The revision is large in MODULES and small in SOURCES.** For `compose`, Route B's surface falls from
17 modules to 6; the source count barely moves (28 → 23). For `context_mode` it roughly halves on both.
**So Route B gets cheaper to SCOPE, not much cheaper to DO.**

**The hook-reachable figures are LOWER BOUNDS and are marked as such**: both extensions are
HOOK-UNRESOLVED, so the walk stops at rejections and has not enumerated everything. A floor is what
this item can honestly hand over.

**And a prerequisite appears that D9 did not price: door 3.** `compose` and `context_mode` are
HOOK-UNRESOLVED on `show` **regardless of Route B**. So Route B alone still clears no barrier for
either — it now needs Route B **plus** a producer for language builtins. **That is new information and
it is the actionable half for WI-C5.**

## 9. Recorded bindings: decided versus discovered

**Decided** (mine, and reversible):

1. **The hook-scope answer REPORTS; it does not replace.** `ext_ambient_inventory`'s verdict is
   unchanged and is what a profile may rely on. Promoting the sharper unit is an ADR-scope decision,
   and the selftest asserts the shipped verdict has NOT moved so a future edit cannot promote it
   quietly.
2. **A new sibling module, `hook_scope.py`, loaded by explicit path** — the same discipline as
   `_load_classifier_2`, for the reason D12 recorded: this directory already contains one `derive.py`
   that resolves to itself under a name-based import.
3. **Door 3 is REPORTED, not closed, and the shipped verdict is not flipped.** Flipping it takes
   `compaction_structural` to UNRESOLVED and invalidates sixteen of `driver_plus_no_ops`'s entries.
4. **The counterfactual yield is printed and LABELLED as a counterfactual.** A number that is not a
   verdict must not read as one.
5. **`ailang.lock`'s `generated_at`-only change was REVERTED.** This item modified zero AILANG package
   sources, so no digest moved; keeping the timestamp would claim a change that did not happen (S15).

**Discovered** (the tree's, not mine):

6. **`register.ail` holds the hooks record in 9 of 15 extensions and named hook functions in 6**, so
   the file-level split is fail-open and `microrag` is the live counterexample (§3).
7. **Door 3 exists and is live in `compaction_structural`** (§6). Not in the handoff, not in the
   amendment, and it is the reason the sharpened yield is not simply "the coarse one plus
   `compaction_ai`".
8. **Door 4 exists and is currently harmless** — 10 builtin and 2 std-symbol calls live only inside
   string interpolations, and none changes an import-granular verdict (§4).
9. **`mcp` and `test_dummy` are the WI-D6 shape** and were invisible to the closure unit. WI-D6
   measured nine of fifteen registrations reading `Env` and solved the confound for the RUNTIME trap
   with paired arms; the static side had never had the same treatment, and two extensions were
   sitting in it.
10. **A brace-delimited RECORD TYPE in a return signature reads as a function body.**
    `exec.ail`'s `-> Result[{ stdout: string, ... }, string] ! {Process} {` made the first walker
    return `stdout: string, ...` as `shell_exec`'s body — so `run_omnigraph` looked effect-free, and
    with it **`omnigraph` reported HOOK-PORT-MEDIATED while its `on_tool_handle` calls
    `std/process.exec`.** §10.
11. **A body that LOOKS like an effect row is skipped by a content test.** `{ NoOpinion }`,
    `{ Delegate }`, `{ PassThrough }` all match "a bare comma-separated list of capitalised names" —
    the test classifier 2 uses. Recognising effect rows SYNTACTICALLY, by the `!`, is the fix.
12. **A file-wide `source -> local` rename map is wrong when two modules export the same name.**
    `compaction_ai.ail` imports `std/list (length as list_length)` AND
    `std/string (length as string_length)`; a file-wide map keeps one and drops the other.
13. **AILANG has an expression-bodied declaration form** (`func f(...) = <expr>`,
    `mcp/assets.ail:20`) and a type-annotated `let` (`scratchpad.ail:100`). A reader that knows only
    the brace forms rejects both as unresolvable.

## 10. Whether any site admitted two type-checking answers with a silent wrong one

**NO live instance in the tree. The count stays at 70 across thirty-nine runs.** Determinism has still
caught none.

**Per S23, this item's stated constants were checked against the artifacts that state them.** The
numbers this note asserts — 4 of 15, 5 of 15, 7 counterfactual, 2 residue names, 3 barriers, 33 of 45
— are each stated by **at least two** artifacts: `expected.json` pins them, the selftest re-derives
them, and `make dst` prints them. **The one constant that only one artifact stated was the eight-slot
list**, and it is now a tiling ASSERTION rather than a scan: a ninth ABI slot makes
`ext_hook_scope_selftest` fail rather than silently scan eight. That is the `ADR:1317-1337` lesson —
*"when a count and an enumeration disagree by one, the enumeration is the claim"* — applied before the
disagreement rather than after.

**Four near-misses in this item's own work, all caught, and two of them were FAIL-OPEN:**

- **the record-type-as-body slip (§9.10) — FAIL-OPEN and it produced a wrong verdict**: `omnigraph`
  read HOOK-PORT-MEDIATED with `std/process.exec` in its `on_tool_handle`. **Caught by hand-checking a
  verdict that looked too good**, not by any assertion. The tool would have shipped a clean answer for
  an extension that shells out. This is the closest thing to the counted failure mode in this run, and
  what caught it was suspicion rather than an instrument.
- **the effect-row content test (§9.11) — FAIL-CLOSED**: `a2a` and `mcp` reported
  `hook-binding-unresolvable` on hooks that resolve fine. Loud, and wrong in the safe direction.
- **the file-wide rename map (§9.12) — FAIL-CLOSED**: `string_length` became an `unknown-callee`.
  Loud, safe direction, and easy to mistake for the tool working.
- **`reject_applied_local` diagnosed as `unknown-callee`** — both rejections, so no verdict moved, but
  the wrong name. Caught by the fixture asserting the SHAPE and not merely the verdict.

**The lesson recorded: two of four slips were fail-open, and the assertion suite caught neither.**
Both were caught by reading a verdict that was better than the source justified. A fixture suite
proves the shapes it enumerates; it does not prove the walker reached the code.

## 11. The slot-level barrier count

**STILL THREE.** `on_pre_step`, `on_response_intercept`, `on_solver_candidate`, re-derived by
`make profile_definition` on this run, with `33 of 45 pairs stand` — unchanged, and the four cleared
extensions are the same four. **No ABI row moved and no ABI version moved**; the ABI-version guard
re-derives `5.0` across 6 sites in 4 files.

**Nothing this item built feeds the barrier derivation.** `ext_hook_scope` is a reporting target; the
per-`(extension, slot)` derivation still reads classifier 3's closure verdict, which did not move.

## 12. `make dst` in full, and the cache-cold sweep

```text
  profile_definition_dst PASS
  ✓ SLOT-level barrier count DERIVED from the ABI rows and the dispatch table: 3
  ✓ barrier count RE-DERIVED per (extension, slot) — classifier 3 is the third producer: 33 of 45
  ✓ the ABI version every profile record names is the one the package declares: 5.0 (6 sites/4 files)
  driver_only_dst PASS                     ← v14, unchanged
  driver_plus_no_ops_dst PASS              ← unchanged
  ext_ambient_inventory  RESULT: PASS — 15/15 extensions, 19/19 std modules, 0 unresolved symbols
  ext_hook_scope_selftest  0 failure(s)    ← NEW, inside the aggregate gate
```

**EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, and nothing else** — identical to the
set recorded at D5, D10, D11, D12, D13 and D14, pre-existing since B2a. **914 ✓ rows in 4 684 lines**
(D14: 914 in 4 669; the new target prints `ok` rows, not `✓`). Neither red target is one this item
touched.

**Cache-cold sweep** (every repo-local `.ailang` removed AND the stdlib-adjacent cache emptied,
`AILANG_RELAX_MODULES=1`, after `make sync_packages` — **twelfth** consecutive item):

```text
271 .ail files checked      34 non-zero exits
   22 PRE-EXISTING, identical to WI-D13/D14 member for member
        8 scripts/, 5 src/examples/, 3 tools/code-graph/tests/fixtures/,
        1 tools/test_coverage/fixtures/, 5 tools/ext_ambient_inventory/fixtures/
   10 THIS ITEM'S OWN hook_scope fixtures — same status as the 5 existing
        classifier-3 fixtures, which also do not compile: they are read
        TEXTUALLY by the selftest and are never run
    2 examples/ — pre-existing; D14's sweep roots did not include this directory
  0 in src/core, 0 in packages/, 0 in any extension closure
```

**The cache producer identification REPRODUCES**: from a fully cleared cache, `make sync_packages`
writes exactly the same 4 files under `~/.ailang` (`sunholo/logging@0.4.0`'s three files plus
`state/collaboration.db`), and the stdlib-adjacent cache stays at **0**. **WI-D11's 52-file population
remains unaccounted**, exactly as D14 scoped it — untouched here, and still owed.

## 13. Owed, unchanged and not touched here

- **Door 3's producer.** New, and the largest thing this item found. Named in the draft.
- **The drafted amendment's disposition** — a reviewer's, per the D9→D10 round.
- **Route B and WI-C5's compose-bearing profile.** Priced here, not built.
- **Promoting the hook-scope verdict**, and any profile acting on it.
- **The full eleven-row table** for either profile (WI-C4's shape); criterion 1's evidentiary basis;
  repairing classifier 1 and its zero-check; the stdlib-adjacent cache's 52-file producer; the
  gate-table State column; the ADR's "1 of 15"; F3; the `extension_effect_fault` wording; the
  fourteen `register_with_config` rows as a hygiene question; the `motoko-ext-abi` major at eight rows.
