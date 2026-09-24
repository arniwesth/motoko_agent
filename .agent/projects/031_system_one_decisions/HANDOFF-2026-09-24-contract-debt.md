# HANDOFF 2026-09-24 — 031 line R's contract debt under 027 ADR-001 §4

`make new_contract_policy BASE=origin/main_dst` reports **107 of 109 new declarations unjustified** at
`77b0e16e` — identical in CI (run `35976700707`) and locally. The gate is keyed on the diff against the
PR base, so these are genuinely new declarations added by line R. It had never run in CI on this branch:
the single job always timed out before reaching it, and `make new_contract_policy` is not on R-G's
checklist, so the orchestrator's pre-gate did not run it either. That is how a rule the line was
breaking stayed invisible until the CI split let the job finish.

**What the gate accepts.** A real contract (`ensures`, optionally `requires`), or a
`-- contracts: <reason>` line that the checker *tests*: it synthesises `ensures { true }` and confirms
the verifier genuinely rejects the function. An excuse on a function that would have verified fine is
refused. So "SKIPPED — test helper" does not pass unless the function is actually unverifiable
(higher-order, recursive, unencodable builtin — `compaction.ail` and `agents_md.ail` hold precedents).

## The split

| | count | who |
|---|---:|---|
| production declarations | **24** | **being given contracts now** (see the current delegate brief) |
| test-only scaffolding | **83** | **held** pending 027's ruling — `QUESTION-2026-09-24-test-scaffolding-in-scope.md` |

Writing 83 annotations before 027 answers risks doing the wrong work twice; a tag helper's honest
contract restates its body and teaches a reader nothing. Until the answer lands, `new_contract_policy`
stays red on PR 186, recorded here rather than hidden.

## By file

| file | findings |
|---|---:|
| `src/core/ext/runtime.ail` | 57 |
| `src/core/ext/registry_normalize.ail` | 36 |
| `src/core/dst_profile_coverage.ail` | 5 |
| `src/core/tool_catalog.ail` | 4 |
| `src/core/test/ext_neutral_registration.ail` | 4 |
| `src/core/ext/ctx_defaults.ail` | 1 |

The full list of 107, file and name, is reproducible with
`make new_contract_policy BASE=origin/main_dst` (needs `git fetch origin main_dst` first).
