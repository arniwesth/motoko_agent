# Handoff: WI-D12 — build classifier 3, the ambient-source inventory

Audience: a fresh session grounded against HEAD. Source-heavy tooling work, in Python, alongside
classifier 2.

**Classifier 3 was admitted on 2026-08-06** by both ADR-001 acceptance reviewers jointly, as the
fourth deferred gate mechanism, on an architecture test they applied on two arms rather than
inheriting. **Its specification is landed in the ADR** at Amendment A. This item builds it.

**Read first:** the amendment's four required properties (`ADR:1470-1495`), then
`NOTE-acceptance-reviewers-classifier-3-admission.md` §5 — the producer-conditioning finding is the
reason this item is not a straightforward port of classifier 1. Then
`NOTE-d11-does-the-name-adoption-stand.md` §5, which bounds a defect this item can inherit.

## Mission

**Build the instrument that decides, per extension, whether every effect it can perform arrives
through a world-mediated port.** It is the producer D5 criterion 2 needs and does not have, and it is
the precondition for the cheapest non-zero coverage number in the project.

**The four properties, from the amendment, not to be re-derived:**

1. **Provenance, not labels.** For each effect a hook can perform, decide whether the call performing
   it is a field call on an `ExtPorts`-typed value. **Per S16 it must not derive from the declaration
   being tested**, which rules out every row-reading instrument.
2. **Total over the extension's transitive closure**, not over the module holding the hook's chain.
   Closures measured at 2–17 modules; none reaches `src/core/session.ail`.
3. **Symbol-granular.** `std/ai.Message` is a type; `std/ai.call` is `! {AI}`. Module granularity
   fails every extension that touches a type from an effect-bearing module.
4. **Fail-closed on the unresolvable**, on classifier 2's discipline — every alias, wrapper,
   re-export and computed access it cannot resolve to a typed receiver is a rejection.

**Classifier 2 is the host.** Same matcher, same fail-closed discipline, ambient symbols instead of
`ExtPorts` fields — the amendment says so and `tools/ext_call_inventory/derive.py` is green with a
five-fixture selftest that fail-closes on all four unresolvable forms.

## The producer question is SETTLED, and the answer is neither of the two the review proposed

**This is the item's most useful grounding and it was measured at review.** WI-D10 named two candidate
producers and both are wrong for this job:

- **The per-declaration textual parse** — the route A-1 was written around — **fails open on 44 of 465
  symbols**: 39 `export func` with no row at all, 5 with an effect *variable*. An unannotated row reads
  as *infer*, not as *performs nothing*.
- **`ailang iface`'s stdout** needs the stdlib-adjacent cache at
  `/home/motoko/.local/share/ailang/std/.ailang/cache/`, and **WI-D11 proved no repository operation
  produces it** — a 243-file cache-cold sweep leaves it at 0, `make dst` in full leaves it at 52.

**Use the compiler's own cached interface data**, `.ailang/cache/compile/modules/std__*/iface.json`,
schema `ailang.iface/v1`. Measured at review of D11:

| | |
|---|---|
| `iface.json` files in repo-local caches | **1172**, of which **331** are `std__*` |
| distinct std modules with a cached interface | **24** |
| **of the 21 std modules the repo imports** | **21 — zero missing** |
| shape | `exports` is a **dict keyed by symbol**, with `purity` and a typed `effect_row` |

**And it makes the distinction the whole yield turns on.** `std/json`'s 38 exports all lack a textual
effect row, so the textual route reports all 38 UNRESOLVED — including `jo`, which three of the four
clean extensions import, which is why the governance act measured the textual route's yield at **1 of
15 rather than 4**. The cached interface answers it directly:

```
jo          purity: true   effect_row: labels {}          -- CLOSED EMPTY ROW, provably effect-free
allNumbers  purity: true   effect_row: tail rowvar 'ρ2'   -- EFFECT VARIABLE, instantiable
```

**A closed empty row and an effect variable are different facts and only this producer separates
them.** The criterion the reviewers wrote requires a compiler-derived producer **by name**; this is it.

## The rule you will break by accident

**Classifier 3's coverage is a function of what has been compiled, and that is exactly the defect
WI-D11 bounded for classifier 1. Do not inherit it.**

Classifier 1's selftest returned `agree=0`, `agree=1` and `agree=45` on the same tree in one day
because its answer depended on a cache. **Its derived set was cache-invariant; only its validation
coverage moved** — which is why the failure is real but narrow.

The cached-interface producer is **better placed** — its cache is repo-local and the project's own
compilation produces it — **but it is still a cache.** So:

- **State the precondition explicitly** in the tool and in the Makefile target: the cache must be
  populated, and by what.
- **Fail closed on any module without a cached interface**, and report the fraction. Per S16 as WI-D6
  extended it: *report what the producer can reach as a fraction, not the subset it happens to cover.*
- **Do not let a green run mean "all clean" when it means "all resolvable were clean".** That is the
  `agree=0 disagree=0` shape, and it has now cost this project two items.

**And per S22 with the review's strengthening: derive the extension list from `ailang.toml`, not by
directory-name convention.** `scratchpad` lives at `packages/motoko_scratchpad`, so a name-convention
resolver silently returns **14 of 15** — and 14 is a plausible-looking answer. **The falsifier must
assert the resolution, not just count the members.**

## The expected yield, and the first thing it should clear

**4 of 15 extensions** have closures importing no effect-bearing std module —
`decision_framework`, `compaction_structural`, `empty_stop_guard`, `progress_contract_guard` —
independently derived twice. That is what the instrument is worth, and it belongs in the tool's own
output rather than in a note.

**`compaction_structural` is the one to aim at, and the review measured why.** Its three barrier-slot
hook bodies are effect-free with a two-sided control; its closure imports only `std/string`,
`std/list`, `std/result`, `std/json`, `std/option`; and it is **the one extension of fifteen binding
`on_pre_step` as a named top-level function**, which is the form the effect checker reads.

**If classifier 3 clears it, it becomes the tree's first installable extension and the first non-zero
extension-model coverage in the project.** That is a separate item — see out of scope — but it is what
this instrument is for, and the tool should be able to say so.

## Definition of done

**`make classifier_3` (or its chosen name) green, in `make dst`**, and with a selftest on classifier
2's pattern — a fixture per unresolvable form, each failing closed, with a **resolving control beside
them** so the selftest cannot pass by finding nothing.

**Its acceptance criterion met and stated**, in the form the ADR's gate table uses. The reviewers will
want to move its State cell; give them a criterion that can be run.

**The 4-of-15 yield derived by the tool**, with the extension list resolved through `ailang.toml`, and
the residue asserted empty.

**A cache precondition stated and enforced**, with per-module resolution reported as a fraction.

**Per S13 — put it IN `make dst`.** Classifier 1's degradation was invisible for thirty-three items
because neither of its targets is, and that is now recorded as owed. **Do not add the fifth mechanism
outside the aggregate gate.**

**Per S9 — sweep cache-cold with `AILANG_RELAX_MODULES=1`, and include the stdlib-adjacent cache**,
which S9's own sweep misses. Run `make sync_packages` first — seven consecutive items.

## Out of scope

- **Installing anything, and `compaction_structural`'s profile.** If classifier 3 clears it, **stop
  and report** — a profile that installs an extension carries a coverage claim and a version bump, and
  the barrier count's derivation changes shape (the acceptance reviewers' `basis` condition attaches
  there).
- **The `basis` field on `HookClassificationEntry`** — due with or before any change that lowers the
  barrier count, per the admission's condition. Not this item, unless this item lowers it.
- **Repairing classifier 1**, amending `derive.py`'s zero-check to a coverage check, and the `MOD010`
  addendum. Owed; and D11 adds that the repair must state a cache precondition.
- **The ADR's gate-table State column** — three of five rows say "Deferred" for built, green
  mechanisms. The acceptance reviewers'.
- **F3**, `head_inventory()` feeding `validate_completeness` its own output. Owed to whoever owns the
  routing audit's completeness.
- Route B; WI-C5; the fourteen `register_with_config` rows; the `motoko-ext-abi` major at eight rows.

## Stop and report rather than deciding inline

- **If the cached-interface producer cannot resolve a module the repo imports**, report the fraction
  before building around it. 21/21 was measured at review on a warm tree; a cold one may differ, and
  that difference is the precondition.
- **If the yield comes out other than 4 of 15**, report the delta with the extension named. Two
  independent derivations agree at four; a third disagreeing is a finding.
- **If classifier 3 clears an extension**, stop before anything installs it.

## Report back

Thirty-sixth calibration run.

- **The git wall-clock window.**
- **The tool's yield**, with the extension list's resolution asserted.
- **The cache precondition**, and the resolution fraction under it.
- **Recorded bindings, decided versus discovered.**
- **Whether any site admitted two type-checking answers with a silent wrong one.** **69 across
  thirty-five runs; determinism has caught none**, and the last seven were in claims, citations and
  instruments rather than in expressions.
- **Whether the barrier count is still three.** If classifier 3 clears an extension it does not move
  on its own — a profile has to install one — but say so explicitly either way.
