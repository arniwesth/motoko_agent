# LEG-CONTRACTS-PROD — contracts for line R's 24 production `pure func`s (027 ADR-001 §4)

You are a delegate of the 031 orchestrator (pane `w3:p5X`). Line R is complete and `R-G` is settled;
this is debt that line incurred and that CI only surfaced once the workflow split let the job finish.
You do not edit the ADRs or PLAN-001, you do not write the dagr run file, and you do not touch other
panes or worktrees.

## What is red

`make new_contract_policy BASE=origin/main_dst` (run `git fetch origin main_dst` first):
**107 of 109 new declarations unjustified** — identical in CI (run `35976700707`, job `verify`).
Background and the full list: `HANDOFF-2026-09-24-contract-debt.md`.

**Your scope is the 24 PRODUCTION declarations below. Leave the other 83 (test-only scaffolding)
untouched** — they are held pending 027's ruling
(`.agent/projects/027_z3_contracts/QUESTION-2026-09-24-test-scaffolding-in-scope.md`). Annotating them
now risks writing work a later reading deletes.

| file | declarations |
|---|---|
| `src/core/ext/registry_normalize.ail` (18) | `vote_family`, `capability_data`, `strings_json`, `atoms_data`, `config_digest_material`, `compare_bytes`, `insert_kv`, `sort_kvs`, `canonical_kvs`, `canonical_list`, `canonical`, `canonical_json`, `ext_config_digest`, `ext_config_digests` |
| `src/core/ext/runtime.ail` (6) | `entry_base`, `stub_usage`, `stub_decision_answer`, `site_label`, `decision_invocation_state`, `decision_view` |
| `src/core/dst_profile_coverage.ail` (3) | `capability_purity_basis`, `count_purity`, `purity_name` |
| `src/core/ext/ctx_defaults.ail` (1) | `empty_tool_evidence` |

(That table lists 28 names because `registry_normalize.ail`'s row names every one the checker reports
there; run the gate and work from its output, which is the authority. If a name in the gate's output is
missing here, it is still yours if it is production code; if it is a `test_*` or a fixture builder, it
is not.)

## What the gate accepts, exactly

Read `tools/verify_classify/new_contract_policy.py`'s docstring and **027 ADR-001 §4** first.

- A **contract**: `ensures { … }`, optionally `requires { … }`. Precedent:
  `src/core/agents_md.ail:79` `is_root` — `ensures { not result || str_length(path) <= 3 }`.
- Or a **`-- contracts: <reason>`** line, which the checker **tests**: it synthesises `ensures { true }`
  and confirms the verifier really rejects the function. Precedents:
  `src/core/compaction.ail:16` (`uses foldl — Z3 fragment requires non-higher-order`),
  `src/core/agents_md.ail:38` (`BLOCKED — RECURSIVE`).
  **An excuse on a function that would have verified is refused.** So do not reach for an excuse first:
  try the contract, and let the verifier decide.

**Write contracts that say something.** `ensures { result == "judge" }` on a function whose body is
`"judge"` passes and teaches nothing. Prefer the property the function exists for: `compare_bytes`
returns an ordering that is antisymmetric on equal inputs; `sort_kvs` returns a list of the same length
as its input; `canonical_json` is deterministic for equal inputs; `ext_config_digest` depends on config
**and** the constructor data positions (ADR-001 (031) N58). Where the honest statement is beyond the Z3
fragment, that is what the excuse is for — and the checker will confirm it.

## Grounding

Branch `arniwesth/031-abi-8-0`, HEAD at or after `1afad23b`. You are the only delegate running. The tree
is green: `make dst DST_JOBS=1` passed whole at `d78a7c3e`, and the R-G pre-gate is 15/16. Do not change
behaviour — contracts and comments only. If a contract cannot be written without changing code, stop and
report rather than refactor.

## Exit checks

1. `make new_contract_policy BASE=origin/main_dst`: the 24 are gone from its output; **83 remain and
   that is expected** — quote the new count (`83 of 109 unjustified`).
2. `make verify_core`, `make verify_mutations`, `make verify_classify_check` green — your contracts are
   now verified objects; a contract the solver rejects is a finding, not a pass.
3. `make check_core` green; `ailang test` green on every file you touched (counts before and after).
4. For each declaration: contract **or** excuse, and for every excuse the verifier's actual words that
   justify it, quoted in `evidence/CONTRACTS-PROD/`.
5. **mutgate** from a fresh clone, spec under `evidence/CONTRACTS-PROD/`: weaken one contract to
   `ensures { true }` → `verify_mutations` or the classify check → red; delete one excuse → the policy
   gate → red. Known trap: `cmd | grep -q X` under `set -o pipefail` scores baseline red (exit 141).

## Last act

Commit `031 line R: contracts for the 24 production pure funcs (027 ADR-001 §4)`, then print
`RESULT CONTRACTS-PROD` (head, commit, per-declaration contract-or-excuse table, the four gate results,
mutgate, and anything you could not write with the reason). Scope: the four files listed and
`evidence/CONTRACTS-PROD/`. Stage only your own paths; never `git stash`; do not touch pane `w3:p1`,
tab `w3:t1`, pane `w3:pZ` or `/workspaces/motoko_agent-eval`.
