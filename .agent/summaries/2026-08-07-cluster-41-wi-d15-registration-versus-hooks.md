# 2026-08-07 Cluster 41: WI-D15 — criterion 2 quantifies over HOOKS, and the closure was never the scope

## Context

Branch: `arniwesth/mot-77-wi-d15-does-criterion-2-quantify-over-hooks-or-over`.

Session span: `a75d8a0` → **uncommitted**. Input was
`HANDOFF-execute-d15-registration-versus-hooks.md`, grounded against HEAD `a75d8a0`
(`2026-08-07T16:45:00Z`). Pin **v0.33.0**. First command `16:47Z`, ~45 min.

**A reading question with a build behind it, and the reading came first.** Two files changed
(**93 insertions / 1 deletion**) plus twelve new ones totalling **1 384** lines of tooling and
fixtures, and **520** lines of record. **Zero AILANG package sources modified**, so no digest moved
and `ailang.lock` was reverted to its committed state — a `generated_at`-only change would have
claimed work that did not happen (S15).

```text
Makefile                                33 +-   two new targets + the dst aggregate (S13)
tools/ext_ambient_inventory/derive.py   61 +    --hook-scope / --hook-scope-selftest modes

NEW  tools/ext_ambient_inventory/hook_scope.py           1058   the sharpened classifier
NEW  tools/ext_ambient_inventory/fixtures/hook_scope/     326   10 fixtures + expected.json
NEW  .agent/.../NOTE-d15-registration-versus-hooks.md     364   the record
NEW  .agent/.../DRAFT-amendment-adr-001-registration-effects.md 156  drafted, NOT applied
```

| Definition-of-done item | State |
|---|---|
| The reading decided against D5 and the amendment, reasoning recorded | **met** — hooks, on two sentences already in the ADR |
| Classifier 3 sharpened, registration separated, fail-closed preserved, yield re-derived | **met** — `ext_hook_scope`, 5 of 15, ten fixtures |
| The delta reported with extensions named and evidence | **met** — +`mcp`, +`test_dummy`, −`compaction_structural` |
| What accounts for registration effects, named | **met** — D5 disclosure, drafted as `registration_effects` |
| Route B's revised cost for WI-C5's owner | **met** — down in scope, flat in work, new prerequisite |
| Per S13, targets inside `make dst` | **met** — green in the aggregate |
| Per S9, cache-cold sweep incl. stdlib-adjacent; `make sync_packages` first | **met** — **twelfth** consecutive item |
| Per S16 as D12 extended it, enumerate the doors before choosing the unit | **met** — and it found **two new doors**, one live |
| Stop-and-report: amend criterion 2's text | **did not fire** — D5 already says "every hook" |
| Stop-and-report: sharpening clears an extension that mediates | **did not fire** — `compaction_ai` is UNRESOLVED as built |
| Stop-and-report: split cannot be made fail-closed | **did not fire** — it can, and the coarse rule is kept anyway |

---

## The reading — the item's durable output

**Criterion 2 quantifies over hooks. Registration is not in its scope.** The answer rests entirely on
two sentences already in the ADR; nothing was reversed.

**D5, `ADR:1295-1300`:** *"…only when **every hook reachable within that profile** is either (1) … or
(2) effectful only through D1 world-mediated ports."* `register_with_config` is not one of the eight
ABI slots.

**Amendment A's property 2, `ADR:1484-1490`, opens by agreeing and derives the unit from it:**
*"Criterion 2 quantifies over every hook an installed extension registers, **so** the unit is the
extension's transitive module closure."* **The `so` is the whole argument** — the closure is the unit
chosen to make the measurement *total over hooks*, a means rather than a redefinition.

**And the amendment already calls its own unit a coarsening**, at the yield paragraph: *"The
coarsening is conservative, so it is the right direction, but it caps the instrument's reach at four
extensions."* **A coarsening is not a definition.**

So the tree never held a contradiction between classifier 3's AMBIENT verdict and
`driver_only.ail:597`'s counter-claim. It held **a conservative instrument and a sharper claim**, and
nothing compared them until this item. `:597` was scoped correctly in KIND and wrongly in EXTENT:
`compaction_ai.ail` alone is too narrow, the closure is too wide, and the right unit is neither file.

**Where a reader goes wrong** is property 2's parenthetical — *"the hook is bound in `register.ail`,
which imports `std/env` and `std/fs`"*. The stated reason is *where hook-reachable text lives*, not
that registration is a hook. Property 2 was written to defeat a FILE-scoped argument and it does;
it overshoots only if read as fixing the quantifier.

## The file is not the split, and the repo refutes it

The obvious sharpening — drop `register.ail` — is **FAIL-OPEN**.
`microrag/register.ail` holds `microrag_tool_handle`, **bound to `on_tool_handle`**, reaching
`std/fs.writeFile` and `std/process.exec` via `auto_write_with_microrag`.

Measured, larger than the argument needs: **9 of 15** extensions hold the `ExtensionHooks` record
(and therefore every inline hook body) in `register.ail`; **6 of 15** declare named top-level hook
functions there. A file-level split moves the yield 4 → 7 **with microrag among the three** — which is
admitting by accident. The split had to be **reachability-granular**, computed outward from the eight
bindings, with every unresolvable step a rejection.

## The doors, enumerated before the unit was chosen (S16) — two are new

| # | Door | Status |
|---|---|---|
| 1 | effect-bearing `std/*` symbol applied in hook-reachable text | watched |
| 2 | `_`-prefixed compiler builtin — D12's door | watched |
| **3** | **non-underscore LANGUAGE builtin (`show`)** | **NEW, LIVE, and `derive.py` does not watch it** |
| **4** | **a call site inside a STRING INTERPOLATION** | **NEW; `strip_noise` blanks it; closed here** |
| 5 | a hook bound to something unresolvable | rejection |
| 6 | an effect at REGISTRATION whose result a hook closes over | out of scope, **and reported** |

**Door 4, measured:** 10 builtin calls and 2 effectful std-symbol calls exist ONLY inside string
interpolations across the fifteen closures. None changes the shipped import-granular verdict — which
is why it has cost nothing — but a call-granular reader inheriting `strip_noise`'s lid is blind to
every one.

Six hook-binding shapes were also enumerated before the walker was written, all present in the tree,
including one record reached through a **renamed import** (`compose`).

## The yield — 4 of 15 → 5 of 15, and the sets are NOT nested

```text
HOOK-PORT-MEDIATED (5 of 15)  decision_framework, empty_stop_guard, mcp,
                              progress_contract_guard, test_dummy
closure PORT-MEDIATED (4)     compaction_structural, decision_framework,
                              empty_stop_guard, progress_contract_guard
```

- **`mcp` and `test_dummy` ADDED** — both the WI-D6 shape exactly: registration reads `Env`/`FS`, the
  hooks close over the resulting DATA and perform nothing. WI-D6 solved this confound for the runtime
  trap with paired arms; the **static** side never got the same treatment, and two extensions were
  sitting in it. `mcp` was verified by hand, not taken from the tool.
- **`compaction_structural` DROPPED** — on door 3, not on behaviour.

**`compaction_ai` does not clear.** Its `ExtPorts.ai_step` IS resolved (property 1's positive half,
`ports=1`) and its hooks reach no ambient source; it is UNRESOLVED solely on `show`. In the labelled
counterfactual the yield is 7 of 15 and includes it — which is `:597`'s claim, independently derived.
**Printed as a counterfactual, not a verdict. No profile acted.**

## Door 3 — the finding that matters most, and it is in the SHIPPED tool

`show` needs no import, is declared nowhere, is not `_`-prefixed, so **`derive.py` neither resolves nor
rejects it — it does not look at it.** It is reachable from a hook in **8 of 15**, including
`compaction_structural`, on which `driver_plus_no_ops` rests four installed extensions and sixteen
criterion-2 entries.

**No producer at HEAD can classify it**, measured rather than assumed: every `show(` in the 46-module
stdlib corpus is inside a `--` COMMENT. **A textual derivation was tried and DISCARDED** — applying the
`_`-builtin evidence rule to non-underscore names cannot tell a builtin from a higher-order PARAMETER,
and it resolved `f`, `p`, `pred`, `get`, `put`, `cas` as language builtins, calling `f` EFFECTFUL and
`p` PURE. **A rule that invents evidence is worse than one that reports its absence.**

**The shipped verdict was deliberately NOT flipped.** Doing so takes `compaction_structural` to
UNRESOLVED and invalidates sixteen of the second profile's entries — a stop-and-report, not an
instrument's call. The selftest asserts the shipped verdict has **not moved**, so a later edit cannot
promote the sharper unit quietly.

## Registration effects — the obligation the reading creates

Ruling registration out of criterion 2 does not make it stop happening. Derived per extension: `a2a` 4,
`omnigraph` 4, `context_mode`/`exa_search`/`mcp` 3, `ailang_docs`/`compaction_ai` 2,
`compose`/`scratchpad`/`test_dummy` 1.

**`a2a` performs a NETWORK GET at registration.** Under the closure reading that was counted — wrongly
— as a criterion-2 failure; under the hooks reading it correctly is not one, **and must not thereby
become invisible.** Drafted as a new `registration_effects` disclosure field, because D5 already
carries exactly one mechanism for facts that are real, bounded, and not conformance-deciding.
**Drafted and NOT applied** — ADR-001 is Accepted and corrections route D9 → reviewer → D10.

## Route B, for WI-C5's owner — down in scope, flat in work, new prerequisite

| | closure ambient | hook-reachable | closure modules | modules holding hook-reachable sources |
|---|---|---|---|---|
| `compose` | 28 | **≥23** | 17 | **6** |
| `context_mode` | 6 | **≥3** | 7 | **2** |

D9's condition A-2 priced Route B as stripping every effect-bearing import from a 17-module closure.
**The revision is large in MODULES and small in SOURCES** — cheaper to scope, not much cheaper to do.
Both figures are **lower bounds** and marked as such (the extensions are UNRESOLVED, so the walk stops
at rejections). **And a prerequisite D9 did not price appears:** both are UNRESOLVED on `show`
*regardless of Route B*, so Route B alone still clears no barrier — it now needs Route B **plus** a
producer for language builtins.

## Whether any site admitted two type-checking answers with a silent wrong one

**NO live instance. The count stays at 70 across thirty-nine runs.** Determinism has still caught none.

**Four near-misses, all in this item's own work, all caught — and TWO WERE FAIL-OPEN:**

- **A record type in a return signature read as a function body.** `exec.ail`'s
  `-> Result[{ stdout: string, … }, string] ! {Process} {` made the walker return `stdout: string, …`
  as `shell_exec`'s body, so `run_omnigraph` looked effect-free and **`omnigraph` reported
  HOOK-PORT-MEDIATED while its `on_tool_handle` calls `std/process.exec`.** Caught by hand-checking a
  verdict that looked too good — not by any assertion.
- **A body that LOOKS like an effect row was skipped by a content test.** `{ NoOpinion }`,
  `{ Delegate }`, `{ PassThrough }` all match "a bare comma-separated list of capitalised names" — the
  test classifier 2 uses. Fixed by recognising effect rows syntactically, by the `!`. Fail-closed.
- **A file-wide rename map** lost `string_length` where two modules export `length` under different
  aliases. Fail-closed, and easy to mistake for the tool working.
- **`reject_applied_local` diagnosed as `unknown-callee`** — both rejections, no verdict moved, wrong
  name. Caught by the fixture asserting the SHAPE, not just the verdict.

**The lesson recorded: two of four were fail-open and the assertion suite caught neither.** Both were
caught by reading a verdict better than the source justified. **A fixture suite proves the shapes it
enumerates; it does not prove the walker reached the code.**

Per S23, every constant this note states is stated by at least two artifacts (`expected.json` pins,
the selftest re-derives, `make dst` prints). The one constant only one artifact stated — the eight-slot
list — is now a **tiling assertion**: a ninth ABI slot fails the selftest rather than silently scanning
eight. That is `ADR:1317-1337`'s lesson applied before the disagreement rather than after.

## Gate and sweep

**`make dst` EXIT 2. Red set: `test_coverage_selftest` and `test_coverage`, nothing else** — identical
to D5, D10, D11, D12, D13, D14; pre-existing since B2a. **914 ✓ rows in 4 684 lines** (D14: 914 in
4 669; the new target prints `ok`, not `✓`). Barrier count **still THREE**, `33 of 45 pairs stand`,
ABI `5.0` across 6 sites in 4 files. `driver_only` and `driver_plus_no_ops` both unchanged and PASS.

**Cache-cold sweep**, twelfth consecutive `make sync_packages`: 271 files, 34 non-zero exits — **22
pre-existing, identical to D13/D14 member for member**, 10 this item's own fixtures (same status as
the 5 existing classifier-3 fixtures, which also do not compile and are read textually), 2 in
`examples/` which D14's roots excluded. **0 in `src/core`, 0 in `packages/`, 0 in any closure.**
The 4-file `~/.ailang` producer reproduces exactly; **the stdlib-adjacent 52-file population remains
unaccounted**, as D14 scoped it.

## Recorded bindings

**Decided:** the hook-scope answer REPORTS and does not replace, with the shipped verdict asserted
unmoved; a sibling module loaded by explicit path (D12's self-import trap); door 3 reported not
closed; the counterfactual printed and labelled as such; `ailang.lock` reverted.

**Discovered:** `register.ail` holds hooks in 9 of 15; door 3 is live in `compaction_structural`;
door 4 exists and is currently harmless; `mcp` and `test_dummy` are the WI-D6 shape and were invisible
to the closure unit; plus the four parsing findings above and two AILANG declaration forms the walker
had to learn (expression-bodied `func f(…) = expr`, type-annotated `let`).

## Owed

**Door 3's producer** — new, and the largest thing this item found. The drafted amendment's
disposition. Promoting the hook-scope verdict, and any profile acting on it. Route B and WI-C5's
compose-bearing profile (priced here, not built). Unchanged from D14: the full eleven-row table
(WI-C4's shape), criterion 1's evidentiary basis, classifier 1 and its zero-check, the stdlib-adjacent
cache's 52-file producer, the gate-table State column, the ADR's "1 of 15", F3, the
`extension_effect_fault` wording, the fourteen `register_with_config` rows as a hygiene question, the
`motoko-ext-abi` major at eight rows.
