# evidence/CONTRACTS-PROD — 031 line R's 24 production contracts (027 ADR-001 §4)

`make new_contract_policy BASE=origin/main_dst` reported **107 of 109** new
declarations unjustified. This leg took the **24 production** ones. The other
**83 are test-only scaffolding and are untouched**, held pending 027's ruling
(`.agent/projects/027_z3_contracts/QUESTION-2026-09-24-test-scaffolding-in-scope.md`);
the gate therefore still reports **83 of 109**, which is the expected number and
not a partial job.

| file | declarations | contracts | excuses |
|---|---:|---:|---:|
| `src/core/ext/registry_normalize.ail` | 14 | 0 | 14 |
| `src/core/ext/runtime.ail` | 6 | 2 | 4 |
| `src/core/dst_profile_coverage.ail` | 3 | 2 | 1 |
| `src/core/ext/ctx_defaults.ail` | 1 | 0 | 1 |
| **total** | **24** | **4** | **20** |

Four verify, so four carry contracts — the checker refuses an excuse on a
function that would have verified, so this split was decided by the solver and
not chosen. All four classify **substantive** under ADR-001 §1's two probes.

## Files

| file | what it is |
|---|---|
| `contracts.md` | the four contracts: text, class, and why each is weaker than its body |
| `verifier-words.md` | for each of the 20 excuses, the verifier's actual words — for the trivial `ensures { true }` AND for the honest property the excuse claims it could not state |
| `generators.md` | why the two skipped properties cannot be made to run on the pinned toolchain, measured against a post-M4 build |
| `probe.py` | regenerates `verifier-words.md` |
| `classify-ext.py` | runs ADR-001 §1's probes on a file `classify.py`'s glob does not reach (`src/core/ext/`) |
| `mutgate.sh` | the mutation gate; takes a fresh clone path |
| `mutgate.txt` | its run, 14 passed / 0 failed |
| `new_contract_policy.txt` | the gate's output after this leg |

## Reading the excuses

An excuse here is not "this is a test helper". The checker synthesises
`ensures { true }` and confirms the verifier really rejects the function, so an
excuse on a function that would have verified is refused. `verifier-words.md`
records a **second** probe per declaration — the property the excuse says it
wanted — because a rejected `true` only shows the function is outside the
fragment, while the second shows the real property was tried rather than assumed
impossible. No probe in that file returns `VERIFIED`; if one ever does, that
excuse is wrong and the contract should be written.

The twenty divide into four blockers, all of them the fragment's and none of
them a missing idea:

* **`Json` sorts cannot be declared** — `"Record_key_value" referenced in
  declaration of "Json" is not declared`, or a call to `js`/`kv`/`jo`.
* **recursion over a list** — `unsupported pattern type *core.ListPattern`;
  the fragment cannot unroll a cons pattern at all.
* **mutual recursion** — `circular function call detected: canonical_list →
  canonical → canonical_kvs → canonical`.
* **an unencodable builtin** — `std/string.charAt`, or `show` behind a
  `"${...}"` interpolation.

Two of the properties worth stating are **two-call** properties —
`canonical_json` is deterministic for equal inputs, `ext_config_digest` moves
when config or an atom's data position moves (ADR-001 (031) N58). A
single-result `ensures` cannot state those at all, at any fragment. The digest
fixtures in `registry_normalize.ail` compare two calls directly, which is the
shape the claim actually has.

## Scope note

`Makefile:773` is changed, on the orchestrator's explicit extension of scope and
nothing else in the Makefile. `ailang test` exits 1 on any skip, and this leg's
contracts are properties whose ADT parameters have no generator on the pinned
toolchain — so the bare `ailang test ... &&` on that line would red
`profile_coverage` and the `dst` aggregate for a reason that is not a defect.
The recipe now pins the skipped set **by name**; see `generators.md`.
