# The four contracts — text, class, and why each is weaker than its body

Twenty of the 24 production declarations are outside the Z3 fragment
(`verifier-words.md` records what the verifier says about each, for the trivial
contract AND for the property the excuse claims). Four verify, so four had to
carry a real contract: the policy checker REFUSES an excuse on a function that
would have verified.

ADR-001 §1 classifies a contract by two solver probes, and only **substantive**
counts — falsifiable (TAUT VIOLATION) *and* admitting results the body would not
produce (DETERMINE VIOLATION). **All four classify substantive.**

| declaration | file | class | TAUT | DETERMINE | solve |
|---|---|---|---|---|---|
| `capability_purity_basis` | `src/core/dst_profile_coverage.ail` | substantive | VIOLATION | VIOLATION | 15.3ms |
| `purity_name`             | `src/core/dst_profile_coverage.ail` | substantive | VIOLATION | VIOLATION | 16.5ms |
| `stub_usage`              | `src/core/ext/runtime.ail`          | substantive | VIOLATION | VIOLATION | 16.3ms |
| `site_label`              | `src/core/ext/runtime.ail`          | substantive | VIOLATION | VIOLATION | 71.4ms |

The first two are pinned in `tools/verify_classify/contracts.register`, which
moved `10 substantive` -> `12 substantive`.

**The other two are NOT in the register, and that is a gap this leg did not
create and did not close.** `classify.py:collect()` and `verify_core` both glob
`src/core/*.ail` — FLAT, so nothing under `src/core/ext/` is classified or
pinned. `site_label` and `stub_usage` are proven by `make verify_ext`
(`✓ src/core/ext/runtime.ail (2 proven)`) but their class is computed nowhere
that a gate reads. The table above reports them from a by-hand run of ADR-001
§1's own two probes against `runtime.ail`; the run is reproducible with
`classify-ext.py` beside this file. Recorded rather than fixed: widening the
glob is a change to the register's contents and to `verify_core`'s cost model,
which is 027's call and not this leg's.

(Doing that by-hand run also surfaced a latent bug in `classify.py`:
`probe_source` derives the probe module name from `path.stem`, so
`src/core/foo.ail` and `src/core/ext/foo.ail` would write the same probe file
and answer for each other. It is unreachable today for exactly the reason above
— the glob never leaves `src/core/` — and it is the same collision
`new_contract_policy.py` already fixed for itself by flattening the relative
path instead. Named here so whoever widens the glob widens it knowingly.)

---

## `capability_purity_basis(k: CapabilityKind) -> PurityBasis`

```ail
  ensures { (result == ViewsPlusBoundary)
              == (k == DecisionSolverJudgeKind || k == DecisionToolPolicyKind) }
```

D2's re-basing, both directions, and nothing wider. A decision kind quietly
filed `DeclaredEmptyRow` would claim compile-time purity the pin does not check
(NOTE-001); a 7.x rowless kind promoted to `ViewsPlusBoundary` would widen the
ADR by table edit. **Weaker than the body:** the ten remaining kinds' split
between `EffectRow` and `DeclaredEmptyRow` is left free, so a slot that gains an
effect row moves without touching the contract. That freedom is what makes
DETERMINE come back VIOLATION.

## `purity_name(b: PurityBasis) -> string`

```ail
  ensures { result != ""
              && ((b == ViewsPlusBoundary) == (result == "views-plus-boundary")) }
```

This is `count_purity`'s bucket key. Two bases sharing a name would merge two
buckets while the six/four/two split still added to twelve — the failure the
count assertion cannot see by itself. The contract pins the one separation
carrying the ADR's weight and leaves the other two spellings free.

## `stub_usage() -> DecisionUsage`

```ail
  ensures { result.cost_millicents == Some(0) }
```

One term, not the record. `None` would leave the run's cost accounting
incomplete for a call that demonstrably cost nothing; `Some(n > 0)` would bill
for a provider never reached. Those are the two ways this stub can lie. The
token counts are left free.

## `site_label(site: DecisionSite) -> string`

```ail
  ensures { result != "" && ((site == FinalizeSite) == (result == "finalize")) }
```

About `invocation_id`, which is `ext/site/local` with this as the middle
segment. `result != ""` refuses `ext//local`; the equivalence refuses an id
collision between one extension's finalize and tool-policy invocations, from the
finalize side an id collision must pass through. **Weaker than the body:** the
tool-policy arm's spelling is free.

## What was tried and rejected as not-saying-anything

`ensures { result == "judge" }` on a body of `"judge"` is the shape the brief
names, and each of these was written to avoid it. `site_label` and `purity_name`
are the two that came closest — pinning BOTH arms of a two-way match would have
been spec-equals-body, which ADR-001 §1 counts as zero. Each pins one arm, and
the solver agrees: DETERMINE VIOLATION for both.
