# Semi-Formal Reasoning Integration Plan (Revised)

Date: 2026-04-06
Created by: gpt-5.3-codex (medium)
Revised by: sonnet-4.6 (medium), gemini-3.1-pro-preview
Scope: `src/core/*`, optional `src/tui/*` visibility only if needed
Status: Proposed

## Plan Dependency

This plan's implementation path depends on extension substrate direction in:

1. `.agent/plans/Core_Extension_System_for_Semi_Formal.md`

Execution rule:

1. If extension architecture is adopted, implement X1 there first, then map Phase A-F behavior through extension hooks.
2. If extension architecture is not adopted, proceed with direct `src/core/*` implementation in this plan.

## Planned File Changes

Expected to be modified:

1. `src/core/prompts.ail`
2. `src/core/rpc.ail`
3. `src/core/tool_runtime.ail`
4. `src/core/types.ail` (if shared policy/certificate ADTs are needed)
5. `src/core/prompts_test.ail`
6. `src/core/parse_test.ail` (if integration coverage is added here)
7. `.agent/plans/Semi_Formal_Reasoning_Integration.md`

Expected to be added:

1. `src/core/certificate.ail` (Phase F)
2. `.agent/fixtures/patches/e2e_patch_a.diff`
3. `.agent/fixtures/patches/e2e_patch_b.diff`
4. `.agent/fixtures/patches/e2e_test_scope.txt`
5. `.agent/fixtures/fault_loc/e2e_fault_loc_context.txt`

## Objective

Integrate semi-formal reasoning into the Motoko/AILANG runtime in a way that is:

1. measurable,
2. safe by default,
3. structurally enforceable (beyond prompt-only formatting).

## Design Principles

1. Do not rely on prompt compliance alone.
2. Keep protocol stable unless a measurable benefit requires protocol changes.
3. Enforce verifier constraints in runtime policy, not only in prompt text.
4. Separate structural validity from semantic validity.
5. Keep budget controls explicit and configurable.

## Phase A: Prompt + Deterministic Routing

Files:

- `src/core/prompts.ail`
- `src/core/rpc.ail`
- `src/core/prompts_test.ail`

Changes:

1. Add deterministic task routing for semi-formal templates.
2. Add template families:
   - patch equivalence
   - fault localization
   - code QA
3. Add runtime flags:
   - `SEMI_FORMAL_ENABLED=0|1`
   - `SEMI_FORMAL_TASKS=patch_eq,fault_loc,code_qa`
4. Keep default behavior backward-compatible when disabled.
5. Template injection point in `rpc.ail::main()` is after `with_cache_hint`, not inside
   `base_system`. This survives the `SYSTEM_MD` override path because `main()` always
   assembles: `raw_system → with_agents_context → with_cache_hint → with_reasoning_template`.
   The template appends to whatever the base system is, regardless of source.

Pre-condition:

- Fix or remove the stale property test in `src/core/prompts_test.ail`:
  `"base_system contains sentinel"` checks for `COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`
  in `base_system`, but that string is not in the current implementation (it lives in
  `parse.ail::is_done`). Remove or correct this test before adding new routing tests,
  otherwise the test suite has a known failure.

Validation:

1. Prompt routing tests (identity + per-task match).
2. `SEMI_FORMAL_ENABLED=0` produces identical output to current behavior (regression guard).
3. No regression in existing prompt assembly.

## Phase B: Step Budget Controls (Pre-Verifier)

Files:

- `src/core/rpc.ail`

Implementation note:

`parse_env_int`, `clamp_positive`, and `clamp_non_negative` already exist in `rpc.ail`
(used by the delegated-tool timeout logic). Phase B reuses them directly — no new
parsing infrastructure is needed.

The hardcoded value `50` appears in **two** call sites that must both be updated:
- `rpc.ail` line in `main()`: `rpc_loop(state, model, 50, step_delay, hybrid_enabled)`
- `rpc.ail` line in `conversation_loop`: `rpc_loop(next_state, model, 50, step_delay, hybrid_enabled)`

Missing either site leaves follow-up tasks (multi-turn conversation) on a hardcoded budget
even when env vars are set.

Changes:

1. Replace hardcoded depth with env-configurable values:
   - `AI_MAX_STEPS`
   - `AI_MAX_STEPS_SOLVER`
   - `AI_MAX_STEPS_VERIFIER`
2. Add clamp/fallback logic for invalid env values (reuse existing helpers).
3. Reserve verifier budget when verifier mode is enabled.
4. Define budget precedence and invariants:
   - precedence:
     1) if both `AI_MAX_STEPS_SOLVER` and `AI_MAX_STEPS_VERIFIER` are set, use them directly (`total = solver + verifier`)
        and if `AI_MAX_STEPS` is also set, enforce `effective_total = min(total, AI_MAX_STEPS)`
     2) else if `AI_MAX_STEPS` is set, derive split using:
        `verifier_steps = max(1, floor(total * 0.25))`
        `solver_steps   = total - verifier_steps`
        (floor for verifier, remainder to solver; guarantees solver + verifier == total exactly)
     3) else use runtime defaults
   - invariants:
     - every active budget must be `>= 1`
     - verifier budget is reserved only when verifier is enabled
     - effective runtime must never exceed computed total cap
   - note: verifier budget env vars are parsed in Phase B but the verifier split path
     is dead code until Phase D enables verifier invocation

Validation:

1. Parsing/clamp tests for env values.
2. Rounding invariant: `solver_steps + verifier_steps == total` for all valid inputs.
3. Both `main()` and `conversation_loop` call sites use the computed depth.
4. Solver path unaffected when verifier disabled.

## Phase C: Read-Only Verifier Tool Policy

Files:

- `src/core/types.ail` (policy ADT)
- `src/core/tool_runtime.ail` (policy enforcement)
- `src/core/rpc.ail` (policy threading through call chain)

Threading approach:

Policy must reach `run_native_call` in `tool_runtime.ail`. The call chain is:

```
rpc_loop → run_hybrid_step → run_native_batch → run_native_call
```

Add `policy: ToolPolicy` as an explicit parameter to `rpc_loop`, `run_hybrid_step`,
`run_legacy_step`, and `run_native_batch`. This mirrors the existing `hybrid_enabled`
pattern and keeps policy per-invocation (required for Phase D two-pass flow where
solver and verifier use different policies in the same process). Reading policy from env
inside `run_native_call` is an alternative but cannot be toggled mid-run and makes
the two-pass flow harder to reason about.

Changes:

1. Add to `src/core/types.ail`:
   ```ailang
   export type ToolPolicy = FullAccess | ReadOnly
   ```
2. Add `policy: ToolPolicy` parameter to `rpc_loop`, `run_hybrid_step`, `run_legacy_step`,
   `run_native_batch`, and `run_native_call` in `tool_runtime.ail`.
3. In `ReadOnly` mode:
   - allow: `ReadFile`, `Search`
   - deny: `WriteFile`, `RunTests`
   - allow `BashExec` only for strict readonly allowlist (`cat`, `sed -n`, `rg`, `find`, `ls`, `git show`)
   - reject shell metacharacter/compound commands (note: `has_shell_tokens` in
     `tool_runtime.ail` already checks `|`, `>`, `<`, `&&`, `||`, `;`, `$(`, `` ` ``;
     reuse this for the metacharacter rejection path)
   - policy decision: pragmatic readonly parity is intentional; `git show` is allowed
     for diff inspection while other git/history-mutating commands remain disallowed
4. Return explicit structured `ToolErrorResult` for policy violations.
5. Pass `FullAccess` at all existing `rpc_loop` call sites in `main()` and
   `conversation_loop` — no behavioral change when verifier is disabled.

Validation:

1. Policy denies mutating calls.
2. Allowed readonly calls still function.
3. Error payloads are model-corrective and machine-readable.
4. All existing call sites compile cleanly with `FullAccess` threaded through.

## Phase D: Verifier Pass Orchestration

Files:

- `src/core/rpc.ail`

Changes:

1. Add optional second-pass verifier flow (start with patch equivalence tasks only).
2. Flow:
   - solver pass (`FullAccess`)
   - verifier pass (`ReadOnly`)
   - if verifier verdict is `not_equivalent` or `inconclusive`, inject findings to solver and continue
   - if `equivalent` with sufficient evidence, allow completion
3. Verifier initial messages — the verifier loop receives a fresh message history:
   - `[system]` verifier system prompt (semi-formal patch-equivalence template)
   - `[user]` the original task string plus the solver's final answer (the candidate output)
   
   The full solver conversation is NOT passed to the verifier. This matches the paper's
   setup (verifier sees task + candidate, not solver reasoning chain), keeps context
   bounded, and forces the verifier to re-derive evidence from the repository rather
   than rationalizing the solver's conclusions.
4. Verifier pass is invoked via a direct `rpc_loop` call from inside `main()` (or a
   thin orchestration function called from `main()`). It does NOT go through
   `conversation_loop`. `conversation_loop` is for multi-turn human interaction; the
   verifier is a programmatic sub-invocation.
5. Keep existing event protocol stable (`thinking`, `done`, `error`, `tool_calls`, `tool_results`).
   Add `"pass": "verifier"` field to all events emitted during the verifier loop. This
   costs nothing on the wire, is ignored by the current TUI, and enables future TUI
   labeling without a protocol break.
6. Add `VerifierAcceptanceV1` (so orchestration is well-defined before full Phase E):
   - `verdict == equivalent`
   - non-empty `premises`
   - at least 2 evidence entries containing `file` and `line > 0`
   - `alternative_hypothesis_checked == true`
   - otherwise downgrade verifier outcome to `inconclusive`
7. Add verifier outcome matrix:
   - `verified_equivalent` -> allow completion
   - `not_equivalent` -> inject findings into solver context and continue
   - `inconclusive` -> inject findings into solver context and continue
   - `timeout` / `tool_policy_violation` / `decode_error` -> treat as `inconclusive` with machine-readable reason and continue
   - hard fail only on explicit abort or global step budget exhaustion

Validation:

1. No protocol changes required for baseline TUI operation.
2. Verifier pass triggers only under configured conditions.
3. Verifier events carry `"pass": "verifier"` field; solver events carry `"pass": "solver"`
   (or omit the field — both are valid since TUI ignores unknown fields).

## Phase E: Certificate Schema + Semantic Validators

Files:

- `src/core/rpc.ail` (initial JSON enforcement)
- `src/core/certificate.ail` (introduced in Phase F, optional early)

Schema (initial JSON contract):

- `verdict`: `equivalent | not_equivalent | inconclusive`
- `confidence`: `low | medium | high`
- `premises`: list
- `evidence`: list with `file`, `line`, `note`/trace details
- `gaps`: list
- `alternative_hypothesis_checked`: bool
- `next_actions`: list

Semantic validators (required):

1. Non-empty premises/evidence for non-trivial verdicts.
2. Evidence entries require `file` and `line > 0`.
3. `inconclusive` requires non-empty `gaps`.
4. `high` confidence requires citation coverage threshold.
5. Alternative-hypothesis check must be present.

Failure behavior:

- Decode/validate failure injects machine-readable correction message back into loop.

## Phase F: Typed Certificates (ADT-Backed)

Files:

- `src/core/certificate.ail`
- `src/core/types.ail` (if shared types are needed)
- `src/core/rpc.ail`

Changes:

1. Model certificates as ADTs.
2. Replace ad-hoc JSON checks with typed decode + validation pipeline.
3. Maintain backward compatibility in error messages so model can self-correct.

Validation:

1. Unit tests for decode success/failure classes.
2. End-to-end verifier loop tests with malformed and partial certificates.

## Optional Formal Assurance (Non-Blocking)

1. Use contracts/Z3 for small invariants (classifier helpers, simple validators).
2. Do not block delivery on proving full string-routing correctness.

## Runtime Flags

Core flags to support rollout control:

1. `SEMI_FORMAL_ENABLED`
2. `SEMI_FORMAL_TASKS`
3. `VERIFIER_ENABLED`
4. `VERIFIER_READONLY_ENFORCED`
5. `AI_MAX_STEPS`
6. `AI_MAX_STEPS_SOLVER`
7. `AI_MAX_STEPS_VERIFIER`

Default values for rollout:

1. `SEMI_FORMAL_ENABLED=0`
2. `SEMI_FORMAL_TASKS=patch_eq`
3. `VERIFIER_ENABLED=0`
4. `VERIFIER_READONLY_ENFORCED=1`
5. `AI_MAX_STEPS=50`
6. `AI_MAX_STEPS_SOLVER` unset
7. `AI_MAX_STEPS_VERIFIER` unset

## Rollout Strategy

1. Roll out Phase A behind flags.
2. Enable Phase C policy before enabling Phase D verifier by default.
3. Enable patch-equivalence verifier first; expand to other task classes only after metrics stabilize.
4. Migration sequence:
   - ship flags first with defaults (no behavioral change)
   - enable Phase A in canary environments via env toggles
   - enable verifier for patch-equivalence only
   - expand task classes only after evaluation gates pass

## Evaluation Gates (Required)

1. Accuracy improvement on target tasks vs standard baseline.
2. Step/cost overhead within configured budget envelope.
3. False-positive verifier rate below threshold.
4. No regressions on standard coding tasks when semi-formal is disabled.

## Immediate Next Action

If extension architecture is adopted: implement X1 in `.agent/plans/Core_Extension_System_for_Semi_Formal.md` first.
If not: implement Phase B (step budget env config) before verifier orchestration.

## Final Step: Example Usage (End-to-End)

After Phases A-D are implemented, run a concrete patch-equivalence verification session.

Example configuration:

1. `SEMI_FORMAL_ENABLED=1`
2. `SEMI_FORMAL_TASKS=patch_eq`
3. `VERIFIER_ENABLED=1`
4. `VERIFIER_READONLY_ENFORCED=1`
5. `AI_MAX_STEPS=100`
6. `AI_MAX_STEPS_SOLVER=75`
7. `AI_MAX_STEPS_VERIFIER=25`
8. `HYBRID_TOOLS=1`

Patch artifacts for this E2E test (explicit definitions):

1. Patch A: `.agent/fixtures/patches/e2e_patch_a.diff`
   - change intent: update `with_cache_hint` behavior inline in `src/core/prompts.ail` to treat empty/blank hints conservatively.
2. Patch B: `.agent/fixtures/patches/e2e_patch_b.diff`
   - change intent: update `with_cache_hint` behavior in `src/core/prompts.ail` by trimming once (`let h = trim(hint)`) and reusing `h`.
3. Test scope reference: `.agent/fixtures/patches/e2e_test_scope.txt`
   - includes the relevant F2P/P2P checks in `src/core/parse_test.ail` (named tests/functions).
4. Fixture note:
   - `e2e_patch_a.diff` and `e2e_patch_b.diff` are reasoning fixtures for verifier behavior
     validation; they are not guaranteed apply-clean production patches.
   - `e2e_patch_a.diff` uses `_str_len(trim(hint))` as its blank-hint guard. `_str_len` is
     not a valid AILANG stdlib name (the correct name is `length` from `std/string`). This
     is **intentional**: it makes Patch A syntactically invalid AILANG, so the correct
     verifier conclusion is `not_equivalent` — the patches differ in more than just style.
     A verifier that concludes `equivalent` without noting this divergence has failed to
     trace the code. If you want a purely behavioral equivalence fixture (both patches
     valid, same semantics), replace `_str_len(trim(hint))` with `length(trim(hint))` and
     update the expected verdict accordingly.

Example task (fully grounded):

`Determine whether Patch A (.agent/fixtures/patches/e2e_patch_a.diff) and Patch B (.agent/fixtures/patches/e2e_patch_b.diff) are equivalent modulo tests listed in .agent/fixtures/patches/e2e_test_scope.txt.`

Expected runtime behavior:

1. Prompt assembly appends the patch-equivalence semi-formal template.
2. Solver pass explores repository with `FullAccess`.
3. Verifier pass runs in `ReadOnly` policy.
4. Verifier emits certificate JSON with premises/evidence/verdict.
5. Runtime applies `VerifierAcceptanceV1`:
   - if accepted equivalent -> finalize
   - if not_equivalent/inconclusive -> inject findings and continue solver (within remaining budget)

Example verifier certificate (shape):

```json
{
  "verdict": "equivalent",
  "confidence": "medium",
  "premises": [
    {"id":"P1","text":"Patch A modifies with_cache_hint blank-hint handling inline in src/core/prompts.ail"},
    {"id":"P2","text":"Patch B modifies with_cache_hint blank-hint handling via trimmed local binding in src/core/prompts.ail"}
  ],
  "evidence": [
    {"test_or_path":"src/core/parse_test.ail::ptc_think_preface_unfenced","trace":[{"file":"src/core/parse.ail","line":469,"note":"both patches leave parse_tool_calls behavior unchanged for unfenced JSON after <think>"}],"delta":"same"},
    {"test_or_path":"src/core/parse_test.ail::ptc_ignore_think_fenced_json","trace":[{"file":"src/core/parse.ail","line":345,"note":"both patches preserve ignoring fenced JSON inside <think> spans"}],"delta":"same"}
  ],
  "gaps": [],
  "alternative_hypothesis_checked": true,
  "next_actions": []
}
```

Acceptance criteria for this example run:

1. No mutating tools executed during verifier pass.
2. Certificate passes structural and semantic checks.
3. Final verdict and reasoning trace are reproducible with same inputs/config.
4. Verifier premises explicitly reference both patch artifact paths and the test-scope file.

How to run this test in practice:

1. Build TUI entrypoint (if needed):

```bash
cd src/tui
npm install
npm run build
cd ../..
```

2. Run the agent with semi-formal + verifier flags enabled:

```bash
SEMI_FORMAL_ENABLED=1 \
SEMI_FORMAL_TASKS=patch_eq \
VERIFIER_ENABLED=1 \
VERIFIER_READONLY_ENFORCED=1 \
AI_MAX_STEPS=100 \
AI_MAX_STEPS_SOLVER=75 \
AI_MAX_STEPS_VERIFIER=25 \
HYBRID_TOOLS=1 \
MODEL=anthropic/claude-sonnet-4-6 \
WORKDIR="$(pwd)" \
./scripts/run-agent.sh "Determine whether Patch A (.agent/fixtures/patches/e2e_patch_a.diff) and Patch B (.agent/fixtures/patches/e2e_patch_b.diff) are equivalent modulo tests listed in .agent/fixtures/patches/e2e_test_scope.txt."
```

3. In-session checks (operator checklist):
   - confirm semi-formal patch-equivalence framing appears in reasoning output
   - confirm verifier pass occurs after solver reasoning
   - confirm verifier-side tool usage is read-only (no `WriteFile`, no `RunTests`)
   - confirm final output includes verdict rationale tied to patch/test-scope artifacts

4. Optional reproducibility check:
   - rerun the same command with identical env/task and compare final verdict + core cited evidence.

## Second Example: Fault Localization Mode (End-to-End)

Use this example to validate semi-formal fault-localization behavior without patch-equivalence comparison.

Example configuration:

1. `SEMI_FORMAL_ENABLED=1`
2. `SEMI_FORMAL_TASKS=fault_loc`
3. `VERIFIER_ENABLED=0` (single-pass fault localization; no patch-equivalence verifier needed)
4. `AI_MAX_STEPS=100`
5. `HYBRID_TOOLS=1`

Fault-localization artifacts for this E2E test:

1. Context file: `.agent/fixtures/fault_loc/e2e_fault_loc_context.txt`
   - contains failing test name, test intent, and candidate source files.

Example task (fully grounded):

`Using .agent/fixtures/fault_loc/e2e_fault_loc_context.txt, localize the top 5 most likely buggy locations (file:line ranges) for the failing test and provide PREMISE -> TRACE -> DIVERGENCE reasoning.`

Expected runtime behavior:

1. Prompt assembly appends the fault-localization semi-formal template.
2. Agent explores code with read/search tooling.
3. Final answer contains ranked predictions (Top-5) with explicit file:line citations.
4. Reasoning follows the required phases:
   - test semantics premises
   - code path trace
   - divergence claims
   - ranked predictions

How to run in practice:

```bash
SEMI_FORMAL_ENABLED=1 \
SEMI_FORMAL_TASKS=fault_loc \
VERIFIER_ENABLED=0 \
AI_MAX_STEPS=100 \
HYBRID_TOOLS=1 \
MODEL=anthropic/claude-sonnet-4-6 \
WORKDIR="$(pwd)" \
./scripts/run-agent.sh "Using .agent/fixtures/fault_loc/e2e_fault_loc_context.txt, localize the top 5 most likely buggy locations (file:line ranges) for the failing test and provide PREMISE -> TRACE -> DIVERGENCE reasoning."
```

Operator checklist:

1. Confirm fault-localization semi-formal framing appears in reasoning output.
2. Confirm output includes Top-5 ranked locations with file:line ranges.
3. Confirm each prediction cites at least one divergence claim tied to a premise.
4. Rerun once and compare whether top predictions are stable.
