# DRAFT — ADR-001 §4 amendment: scope by reachability

**Status: DRAFT, not adopted.** Drafted with the implementation by 031's `LEG-CONTRACTS-SCOPE`
delegate, as the ANSWERED section of `QUESTION-2026-09-24-test-scaffolding-in-scope.md` asks.
§4 is 027's text. This file proposes wording and does not change `ADR-001-contract-classification-register.md`.
027 adopts it, amends it, or refuses it.

## Proposed §4 text

Replace the first sentence of §4 and append the **Scope** paragraph. Everything else in §4
stays as it is.

> ### 4. Justifications name a rejection reason
>
> Every new `pure func` in `src/core/`, **except one reachable only from a `tests [...]` block**,
> carries a contract, or a comment naming what blocks it:
>
> ```
> -- contracts: SKIPPED — uses an unencodable builtin: std/string.concat (rewrite to concat_String)
> -- contracts: SKIPPED — RECURSIVE (find_last)
> ```
>
> Free text is what let `compaction.ail`'s honest comments and `agents_md.ail`'s misleading
> banner look alike. A checkable reason is better than an excuse. Applied to **new** declarations
> only, keyed on `git diff` — v1's form applied to ~1500 existing declarations with no migration
> story, which is not a policy.
>
> **Scope (amended 2026-09-24).** A declaration reachable **only** from a `tests [...]` block is
> out of scope. Reachability is **computed** for each module from a reference graph. There is an
> edge wherever one declaration's text names another, whether or not it is applied. Every
> `export`ed declaration and `main` is a production root. Every `tests [...]` clause is a test root.
> A declaration is out of scope when a test root reaches it and no production root does. A
> declaration reached from production at all is in scope, even if tests reach it too. A
> declaration reached by neither (dead code) is also in scope. Scope is never read off a name, a
> path, a file suffix or a comment, and there is no exemption list. A fixture that production code
> starts to reach is in scope on the next run, and nobody has to edit anything. Where the analysis
> cannot read a module, every new declaration in that module stays in scope.

## Why each clause is there

- **Computed, not a name or a path.** The ruling was measured on 83 test-only declarations.
  14 of them were named `test_*`, 4 sat under a `test/` path, and 79 lived in production files.
  A naming rule would catch 17% of them and a path rule 5%.
- **No self-declared form (reading 3).** Nothing stops `-- contracts: TEST-ONLY` from appearing
  on production code. §4's own motivating case is two comments that look alike, one honest
  and one misleading. The implementation's mutation gate puts exactly that comment on a
  production function, and the gate stays red.
- **The edge is the mention, not the call.** AILANG has no reflection and cannot look up a
  private declaration by name. A function value exists only where some text names it. So a
  function stored unapplied in a record, aliased, or handed to a higher-order call is in scope
  as soon as any production-reachable text names it. The analysis does not need to follow
  higher-order calls.
- **Exports are production roots.** Outside its module, a private declaration cannot be named
  (a selective import of one is `undefined variable`), and `ailang run --entry` finds only
  exports. So one module at a time is enough, and no export is ever exempt.
- **Fail toward scope.** If the analysis mis-reads something, the error adds reachability and
  puts a declaration in scope. It never takes one out. If a module cannot be read at all
  (unterminated string, a top-level form with no rule), every new declaration in it stays in scope.

## Implementation and evidence

- `tools/verify_classify/new_contract_policy.py`: the SCOPE section holds the reasoning next
  to the code.
- `tools/verify_classify/test_new_contract_policy.py` is the mutation gate, and
  `verify_classify_check` runs it in CI. It runs the real policy script against a scratch repository:
  - a test-only helper that production reaches (applied, unapplied, aliased, interpolated, in a
    contract, in a lambda, exported, or through the test itself) turns the gate red;
  - a production function stays red when it is renamed `test_*` / `*_test`, moved under `test/`,
    put in a `*_test.ail` file, commented TEST-ONLY with a `-- contracts:` excuse, or given its
    own `tests` block;
  - the unmutated fixture is green.
- The same change removed a path rule the implementation already had: it skipped every
  `*_test.ail` file. §4 never stated that rule, and the scope above replaces it.
- First run: `make new_contract_policy BASE=origin/main_dst` on `arniwesth/031-abi-8-0` found 109
  new declarations. 22 are in scope and justified, and 87 are out of scope. The 87 are all 83
  that were predicted, plus 4 that were already justified: `count_purity` and `purity_name`
  (hand-classified as production, but reached only by `test_purity_basis_split_six_four_two`)
  and two `test_*` functions that carried checked excuses. None of the 83 is reachable from
  production.
