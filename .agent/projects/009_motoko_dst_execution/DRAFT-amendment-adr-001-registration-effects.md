# DRAFT amendment to ADR-001 — registration effects, and criterion 2's quantifier

**Status: DRAFTED, NOT APPLIED.** Measured at WI-D15. ADR-001 is Accepted and this project's mandate
routes corrections through a normal round — WI-D9 drafted, a reviewer dispositioned, WI-D10 applied.
This follows that shape.

**This amendment does NOT change criterion 2's text**, and that is its first claim. D5 already
quantifies over hooks. What is missing is a home for the effects the hooks reading rules out.

---

## 1. What WI-D15 measured, in one paragraph

Criterion 2's scope is HOOKS. Classifier 3's unit is the extension's transitive CLOSURE. The closure
is a sound over-approximation of hook reachability, not an enlargement of the quantifier — and
because it is an over-approximation, it sweeps in `register.ail`'s imports, which is why no
extension that mediates can ever clear. Measured over the fifteen registrable extensions, the two
readings give **4 of 15** (closure) and **5 of 15** (hooks), and **the sets are not nested**.

## 2. The reading, and the two sentences that settle it

**D5, `ADR:1295-1300`:**

> An extension may appear as covered in a conformant profile only when **every hook reachable within
> that profile** is either: (1) deterministic and effect-free for its explicit inputs; or (2)
> effectful only through D1 world-mediated ports…

The quantifier is over hooks. `register_with_config` is not one of the eight ABI slots and is not a
hook.

**Amendment A's property 2, `ADR:1484-1490`, opens by agreeing:**

> **Total over the extension, not over one file.** *Criterion 2 quantifies over every hook an
> installed extension registers*, **so** the unit is the extension's transitive module closure — not
> the module that happens to hold the hook's chain.

The `so` is doing the work. The closure is derived FROM the hooks quantifier as the unit that makes
the measurement total over it. It is a means, not a redefinition. **And the amendment already says
so in its own words**, at the yield paragraph:

> Because the unit is the extension's closure and the discipline is fail-closed, classifier 3 can
> never clear a single hook of an extension whose closure is dirty — `compaction_ai` included, via
> `register.ail`'s `std/env` and `std/fs`. **The coarsening is *conservative*, so it is the right
> direction, but it caps the instrument's reach at four extensions.**

**A coarsening is not a definition.** The ADR names classifier 3's unit as coarser than the criterion
and prices the difference. Nothing in this amendment is therefore a reversal; it is the ADR taking
its own qualification at face value.

**Property 2's parenthetical is where a reader goes wrong**, and it is worth quoting because it is
the sentence that reads like registration is in scope:

> (The claim currently recorded for `compaction_ai` at `src/core/dst_driver_only.ail:597` is scoped
> to `compaction_ai.ail`; **the hook is bound in `register.ail`**, which imports `std/env` and
> `std/fs`.)

The stated reason is *"the hook is bound in register.ail"* — a fact about where hook-reachable text
lives, not a claim that registration is a hook. Property 2 was written to defeat a FILE-scoped
argument, and the closure defeats it. It overshoots only if read as fixing the quantifier.

## 3. The proposed change — one new obligation, no change to criterion 2

**Criterion 2's text stands unamended.** What is added is the home for what the hooks reading rules
out, because ruling an effect out of a criterion does not make it stop happening.

> **Proposed addition to D5's versioned profile definition fields:**
>
> - **`registration_effects`**: for every installed extension, the ambient effect sources reachable
>   from `register_with_config` but NOT from any of its eight hook bindings — named as
>   `(module, symbol)` pairs with the producer and revision that derived them, on the same basis
>   discipline as `HookClassificationEntry`. These effects are performed once, at install time,
>   before any hook is dispatched. **They are outside criterion 2 and inside the profile.** An
>   installed extension with an empty list must say so; an unstated list is indistinguishable from
>   an undisclosed one, which is the defect the `exercised_fault_classes` amendment closed for
>   waivers.

**Why disclosure rather than a criterion.** Criterion 2 is about the call path a hook takes and it
has a producer. Registration effects are a different claim — *what a profile does when it installs
something* — and D5 already carries exactly one mechanism for facts that are real, bounded, and not
conformance-deciding: the per-extension disclosure. This uses it rather than inventing a third
classification.

**Why it must not be silent.** WI-D6 measured nine of fifteen `register_with_config` implementations
reading `Env` before any hook is dispatched. WI-D15 re-derived the whole set per extension:

```text
REGISTRATION-ONLY AMBIENT SOURCES (in the closure, out of criterion 2's scope)
  a2a          4   std/net.httpGet, std/fs.fileExists, std/fs.readFile, std/env.getEnvOr
  omnigraph    4   std/fs.fileExists, std/fs.readFile, std/env.getEnvOr,
                   std/extension.requireWorkdirFile
  context_mode 3   std/fs.fileExists, std/fs.readFile, std/env.getEnvOr
  exa_search   3   std/fs.fileExists, std/fs.readFile, std/env.getEnvOr
  mcp          3   std/fs.fileExists, std/fs.readFile, std/env.getEnvOr
  ailang_docs  2   std/fs.fileExists, std/env.getEnvOr
  compaction_ai 2  std/env.getEnvOr, std/fs.readFileResult
  compose      1   std/env.getEnvOr
  scratchpad   1   std/env.getEnvOr
  test_dummy   1   std/env.getEnvOr
```

**`a2a` performs a NETWORK GET at registration.** That is not a config read and it is not something a
hermeticity claim can leave unstated. Under the closure reading it was counted, wrongly, as a
criterion-2 failure; under the hooks reading it is correctly not a criterion-2 failure, and it must
not thereby become invisible. **That is precisely the vacuity this project has spent fourteen items
marking, and the field above is what stops the reading from creating one.**

## 4. What this amendment does NOT do

- **It does not promote classifier 3's hook-scope answer.** `ext_hook_scope` reports; the shipped
  closure verdict is what `ext_ambient_inventory` returns and what a profile may rely on. Changing
  that is a separate decision and this draft does not ask for it.
- **It does not install anything.** `compaction_ai` is measured HOOK-PORT-MEDIATED only in the
  counterfactual where door 3 is resolved (see §5); it is HOOK-UNRESOLVED as built.
- **It does not touch criterion 1**, whose evidentiary basis the ADR records as an assumption and
  which Amendment A withheld.

## 5. The dependency this amendment must name, on condition A-1's precedent

Amendment A named classifier 1's broken producer rather than working around it. The same is owed
here.

**Door 3: non-underscore LANGUAGE builtins.** Classifier 3 watches `_`-prefixed builtins (WI-D12's
finding) and nothing else. `show` is applied in **eight of the fifteen closures, including
`compaction_structural`** — the extension `driver_plus_no_ops` rests four installed extensions and
sixteen criterion-2 entries on. It needs no import, is declared nowhere, and **every `show(` in the
46-module stdlib corpus is inside a `--` comment**, so no cached row anywhere carries evidence for
it, interpolation-aware or not.

**Under the closure unit this costs nothing** — the verdict is import-granular, so an unwatched
callee changes no answer. **Under a call-granular unit it is the dominant term:** it is the only
reason the hook-scope yield is 5 rather than 7, and the only reason `compaction_structural` differs
between the two readings.

**A textual workaround was tried at WI-D15 and discarded.** Deriving language-builtin rows the way
`_`-builtin rows are derived cannot distinguish a builtin from a higher-order PARAMETER applied in a
std body: it resolved `f`, `p`, `pred`, `get`, `put` and `cas` as language builtins, classifying `f`
EFFECTFUL and `p` PURE. **A rule that invents evidence is worse than one that reports its absence**,
so the names are reported as a named residue with the counterfactual beside them, labelled as a
counterfactual.

**Closing door 3 needs a producer this tree does not have.** It is the same shape as A-1 and it is
OWED. Until then, the hook-scope answer is 5 of 15 and says why.

## 6. What a reviewer should decide

1. **Is the reading right?** Criterion 2 quantifies over hooks; the closure is a conservative unit,
   not the scope. §2 rests entirely on sentences already in the ADR.
2. **Is disclosure the right home for registration effects**, or do they warrant a criterion of their
   own? The draft argues disclosure, on the ground that D5 already uses it for exactly this class of
   fact.
3. **Should the `registration_effects` field bind for `driver_only`?** It installs nothing, so the
   field would be empty and the obligation vacuous — the same vacuity every row-3 clause carried
   until WI-D14. `driver_plus_no_ops` installs four and would bind it non-vacuously at 8 sources
   across 4 extensions.
4. **Door 3's producer** — whether closing it is in this amendment's scope or its own item. The draft
   assumes its own item.
