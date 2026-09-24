# QUESTION for 027 ADR-001 §4 — are test-only declarations in scope?

Raised 2026-09-24 by the 031 orchestrator (release line R, ABI 8.0), from a measured case. Not a
request to weaken the rule: a request to say which declarations it is about, before ~83 annotations
are written that may be the wrong thing.

## The case

`make new_contract_policy BASE=origin/main_dst` on `arniwesth/031-abi-8-0` at `77b0e16e`:

```
new_contract_policy: 107 of 109 new declarations unjustified
```

Same number in CI (run `35976700707`, job `verify`) and locally. By file: `ext/runtime.ail` 57,
`ext/registry_normalize.ail` 36, `dst_profile_coverage.ail` 5, `tool_catalog.ail` 4,
`test/ext_neutral_registration.ail` 4, `ext/ctx_defaults.ail` 1.

Classified by shape (orchestrator's reading, listed in full in the 031 handoff):

| | count | examples |
|---|---:|---|
| **production** | **24** | `canonical_json`, `ext_config_digest`, `compare_bytes`, `sort_kvs`, `vote_family`, `decision_view`, `decision_invocation_state`, `entry_base`, `stub_decision_answer`, `capability_purity_basis` |
| **test-only scaffolding** | **83** | every `test_*`; fixture builders (`p_judge`, `p_prepare_tool`, `probe_request`, `neutral_descriptor`, `descriptor_a/b`, `expected_a/b`); tag helpers whose whole body is a string (`tool_tag`, `judge_tag`, `state_tag`, `mode_tag`, `window_tag`); vote constructors (`allow_now`, `deny_now`, `accept_now`) |

The 24 are being given contracts now, regardless of the answer here.

## The question

§4 says "Every new `pure func` in `src/core/`". AILANG has no separate test file convention — inline
`tests [...]` blocks live beside the code, and a fixture builder is a `pure func` like any other. So a
part that adds one production function with five test fixtures and eight tag helpers owes fourteen
annotations, thirteen of them about scaffolding.

Three readings, all consistent with the text as written:

1. **As written — everything in scope.** ~83 annotations here. A tag helper returning `"judge"` would
   take `ensures { result == "judge" }`, which restates the body; the checker would accept it, and a
   reader learns nothing. The risk §4 names — free text that looks like a reason — is not what this
   produces; it produces true, empty contracts.
2. **Declarations reachable from a `tests [...]` block only are out of scope.** Mechanical to compute
   from the same walk the checker already does. The rule keeps its bite on shipped code.
3. **In scope, but a fixed excuse form is accepted for them**, e.g. `-- contracts: TEST-ONLY`, exempt
   from the synthesised-`ensures` check. Cheapest to implement, and it keeps the count visible.

**The orchestrator has no stake in which.** What 031 needs is an answer before someone writes 83
annotations that a later reading deletes. Until then those 83 stay unannotated and
`new_contract_policy` stays red on PR 186 — recorded, not hidden.

## Evidence

- `.agent/projects/031_system_one_decisions/HANDOFF-2026-09-24-contract-debt.md` — the full list by file.
- CI: run `35976700707`, job `verify + contract policy`; local reproduction identical at `77b0e16e`.

## ANSWERED — 2026-09-24, by the operator: **reading 2**

**A `pure func` in `src/core/` that is reachable ONLY from a `tests [...]` block is out of §4's scope.**
Everything else stays in scope, unchanged. Fallback if the reachability pass proves harder than this
question assumed: reading 3 (a fixed `-- contracts: TEST-ONLY` form), adopted explicitly rather than by
drift.

### Why 2 rather than 1 or 3

**The scope must be COMPUTED, not asserted.** Measured on the 83 held declarations, the two cheap
implementations are both wrong:

| slice | count of 83 | verdict |
|---|---:|---|
| named `test_*` | **14** | a naming convention catches 17% |
| under a `test/` path | **4** | a path rule catches 5% |
| inside production files (`ext/runtime.ail` 51, `ext/registry_normalize.ail` 22, `tool_catalog.ail` 4, `dst_profile_coverage.ail` 2) | **79** | test-only *declarations* in shipped *files* |

So "test-only" can only mean *reachable from a `tests [...]` block and nothing else*, derived from the call
graph. It cannot be a name or a directory.

Against **reading 3**: its exemption is **self-declared**. Nothing stops `-- contracts: TEST-ONLY` appearing
on production code, and §4 exists precisely because an honest comment and a misleading one look alike
(`compaction.ail` vs `agents_md.ail`, §4's own motivating case). A blessed token that means "trust me"
repeats that mistake in miniature.

Against **reading 1**: the cost is not the 83 annotations, it is the artefact. ~69 of them would restate a
one-line body (`ensures { result == "judge" }` on a helper whose body is `"judge"`). True, accepted by the
checker, and empty. A register where most entries restate their bodies trains readers to skim it, which
costs more on the day a real contract needs attention than the annotations ever saved.

**Reading 2 is also self-correcting**: the day a fixture is called from production it enters scope
automatically, with nobody needing to remember.

### Consequences

- The 24 production declarations keep their contracts (already landed, `87efff5f`).
- The 83 are expected to fall out of scope once the pass lands — **that number is a prediction, not a
  target**: if the pass leaves some in scope because they are genuinely reachable from production, those get
  real contracts.
- §4's text needs an amendment recording the scope. Drafted with the implementation, adopted by 027.
