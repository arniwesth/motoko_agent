# Why the two skipped properties cannot be made to RUN on this toolchain

The orchestrator asked this first, and it is the right question: if the two
contract properties ran for real, `make profile_coverage` would need no change
at all. They cannot, on the pinned toolchain, and the reason is not a missing
declaration in this repo.

## There is no "supply a generator" syntax

AILANG does not let a module declare a generator for one of its types.
Generators are **derived structurally from the type** by the test runner
(`internal/testing/derive.go`), so "write a generator for `CapabilityKind`" is
not something a repo author can do — it is a compiler capability or it is
absent. `ailang test --help` lists no generator flag; the only relevant option
is `--allow-skips`, which is a tolerance, not a generator.

## The derivation exists upstream, and landed after our pin

`deriveType` handles scalars, `()`, records, tuples, lists and same-file named
types. ADTs go through `deriveAlgebraicType`. Both of our parameter types are
declared in the very file that uses them —

| type | declared | used by |
|---|---|---|
| `CapabilityKind` | `src/core/dst_profile_coverage.ail:152` | `capability_purity_basis` |
| `PurityBasis`    | `src/core/dst_profile_coverage.ail:272` | `purity_name` |

— so the same-file lookup (`findTypeDecl`) would resolve them. The blocker is
purely the toolchain's age:

```
M4 (ADT generator derivation)  03ab3e7de  2026-08-11  #653 Lane B1 M4
release we run (ailang.lock)   ae36986c5  2026-08-04  Release v0.33.0
$ git merge-base --is-ancestor 03ab3e7de ae36986c5  ->  NO
```

ADT derivation landed **one week after** the release this repo pins. The
vendored source at `ailang/` is well past it, but the installed binary is not.

## Measured, not inferred

Minimal case, a three-constructor same-file ADT with a contract:

```
$ ailang test adt.ail                      # pinned v0.33.0
  ⊘ name_of_property_1   no generator for parameter b: Basis
  1 tests: 0 passed, 0 failed, 1 skipped

$ ./ailang-head test adt.ail               # built from ailang/ (post-M4)
  ✓ name_of_property_1 (100 cases, 20.156809ms)
  1 tests: 1 passed, 0 failed, 0 skipped
```

And on the real files, under the post-M4 build, **all four of this leg's
contracts run and pass**:

```
src/core/dst_profile_coverage.ail
  ✓ capability_purity_basis_property_1 (100 cases,  93.951109ms)
  ✓ purity_name_property_1             (100 cases, 105.989344ms)
  17 tests: 17 passed, 0 failed, 0 skipped

src/core/ext/runtime.ail
  ✓ stub_usage_property_1              (100 cases,   1.082989019s)
  ✓ site_label_property_1              (100 cases,   1.360104128s)
  37 tests: 37 passed, 0 failed, 0 skipped
```

That is worth more than an unblocked target: it is 100 random `CapabilityKind`s
agreeing with the D2 equivalence, and 100 random `DecisionSite`s agreeing that
`"finalize"` names exactly the finalize site. Z3 proved these; the generator
independently sampled them.

## Consequences for the pin

Bumping AILANG to get this is far outside a contracts leg — and `ailang.lock`
is already modified in the working tree, so a bump appears to be in flight
elsewhere. Two things follow:

1. `Makefile:773` pins the skipped set **by identity**, not by count, and
2. it treats an **empty** skipped set as success, announcing that the pin has
   expired. On the bump this target must not red because the news was good.

The mutgate's M3/M4 cover the two ways the pin can be wrong; nothing covers the
expiry path except that it is written down here and in the recipe.
