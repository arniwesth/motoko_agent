# Review: Core_Extension_System_for_Semi_Formal.md

Date: 2026-04-06
Reviewer: Claude (claude-sonnet-4-6)
Plan author: gpt-5.3-codex (medium)

---

## Summary Verdict

The architectural instinct is correct: separating extension concerns from the kernel makes
future capabilities cheaper to add and keeps safety logic centralized. The conflict
resolution rules and failure model are well-specified. The problems are mostly in
AILANG-specific realizability and plan sequencing.

---

## Critical Issues

### 1. `Ctx` type is never defined

Every hook takes `ctx` as its first argument but `Ctx` has no type definition anywhere in
the plan. In AILANG's explicit type system this is a blocking omission — you cannot write
a single line of the registry without it. At minimum `Ctx` needs:

```ailang
type ExtCtx = {
  task:   string,
  step:   int,
  model:  string,
  cwd:    string,
  budget: BudgetPlan
}
```

Define this in `src/core/ext/types.ail` before anything else.

### 2. Effect signatures on record-stored hooks are unresolved

The plan marks `on_solver_candidate` as effectful `! {IO, Process, FS, AI, Env, Net,
SharedMem, Clock}`. In AILANG, a function value stored in a record field must have a
fixed, declared effect set in the type. This means `Extension` would look like:

```ailang
type Extension = {
  on_build_system_prompt: (ExtCtx, string) -> PromptPatch,
  on_tool_call: (ExtCtx, ToolCallReq) -> ToolDecision,
  on_solver_candidate: (ExtCtx, string) -> FinalizeDecision
    ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock},
  ...
}
```

Every extension — including lightweight ones that only do string manipulation — must
satisfy the maximal effect signature for effectful hooks. That means a prompt-only
extension technically declares `! {IO, Process, FS, AI, ...}` even though it never
touches those effects. This is safe but surprising. The plan should acknowledge this and
specify that each hook's declared effect set is the union across all hooks of that type.
Pure hooks can stay pure.

Alternative: split pure and effectful hooks into separate registry types and dispatch
them separately. More complex but avoids forcing pure extensions to declare effects they
don't use.

### 3. Sequencing conflict with the Semi-Formal plan

The Semi-Formal plan's "Immediate Next Action" is **Phase B** (budget controls). This
extension plan's "Immediate Next Action" is **Phase X1** (extension substrate). These are
mutually exclusive starting points.

If this plan supersedes the A–F phases of the Semi-Formal plan, that must be stated
explicitly — Phase A (prompt templates) would become X2, Phase B (budget) becomes X1's
`on_budget_plan` hook, Phase C (policy) becomes X3, Phase D (verifier) becomes X4. The
Semi-Formal plan's phases A–B then become dead work unless X1 is shipped first.

If this plan runs in parallel (X1 built later, Semi-Formal A–B shipped inline first), the
plan needs a migration note: "Semi-Formal A–D land as direct rpc.ail changes; X2 migrates
them into extension hooks afterward."

Without resolution, two plans with different "next actions" will diverge in
implementation.

---

## High Issues

### 4. 8 hooks is too broad for a first iteration

The plan itself notes "Hook surface too broad too early → slow delivery" as a risk but
doesn't act on it. Semi-Formal only needs 4 hooks:

| Hook | Used by |
|---|---|
| `on_build_system_prompt` | Phase A (prompt templates) |
| `on_budget_plan` | Phase B (budget split) |
| `on_tool_call` | Phase C (read-only policy) |
| `on_solver_candidate` | Phase D (verifier invocation) |

`on_boot_config`, `on_tool_result`, `on_finalize`, `on_error` are not required for
Semi-Formal phases A–D. Shipping 8 hooks in X1 means testing 8 dispatch paths, 8
fallback behaviors, and 8 no-op implementations before Semi-Formal ships a single
feature.

**Recommendation:** X1 ships with 4 hooks. `on_finalize` and `on_error` defer to X3/X4
when Phase E/F (typed certificates) needs them.

---

## Medium Issues

### 5. `on_solver_candidate` trigger condition is imprecise

The hook fires when "the solver has a candidate final answer." In the current `rpc_loop`,
the candidate-final-answer detection point is inside `run_legacy_step` (when
`extract_bash` returns `None`) and `run_hybrid_step` (when `parse_tool_calls` returns
`NoToolCalls`). The plan doesn't say which path triggers the hook or whether it fires in
both. Since the verifier is only meaningful in hybrid mode (structured tool calls),
`on_solver_candidate` probably fires only from `run_hybrid_step`. This should be
explicit.

### 6. No-op extension for Phase X1 is underspecified

"No-op extension support" is a Phase X1 deliverable but the plan doesn't say who creates
the no-op or where it lives. The simpler option: the registry handles empty extension
lists without a no-op stub. State this explicitly so Phase X1 doesn't ship an unnecessary
built-in extension.

### 7. `BudgetPatch` interaction with kernel defaults unspecified

The Semi-Formal plan specifies a concrete budget formula:
`verifier = max(1, floor(total * 0.25))`, `solver = total - verifier`. Under the
extension model, `on_budget_plan` returns a `BudgetPatch` with `Option[int]` fields and
"kernel clamps to hard caps after patches." But the plan doesn't say:

1. What the kernel's default budget is when no extension sets a patch (currently
   hardcoded `50` in two call sites)
2. Whether the kernel applies the 75/25 formula before or after extension patches
3. Whether `BudgetPatch.requested_verifier = None` means "use kernel default" or "no
   verifier budget"

Specify the kernel-default budget computation (the 75/25 formula from the Semi-Formal
plan), then define extension patches as overrides applied on top of it.

---

## Low Issues

### 8. `CORE_EXTENSIONS` deprecation note is spurious

"If both `CORE_EXT_ORDER` and `CORE_EXTENSIONS` are set, startup fails with a config
error." `CORE_EXTENSIONS` isn't defined in any existing code or plan — it's being
deprecated before it exists. Drop the deprecation note; just define `CORE_EXT_ORDER` as
the single config key.

### 9. Phase X3 redundancy

Phase X3 "Policy Hardening" lists `tool_runtime.ail` and `semi_formal/policy.ail`. But
Phase C of the Semi-Formal plan already specifies full `ToolPolicy` implementation in
`tool_runtime.ail`. If X1/X2 run before Semi-Formal A–D, then X3 lands the policy. If
Semi-Formal A–D land first and X2 migrates them, X3 has nothing new to add. This
redundancy is a symptom of the unsettled sequencing (issue 3).

---

## What's Solid

- Kernel-vs-extension split is correct. Safety (abort, hard budget cap, tool deny) stays
  in the kernel; behavior (prompt shaping, verifier invocation) moves to extensions. The
  line is drawn correctly.
- `ToolDecision = Allow | Deny | NoOpinion` with deny-wins is the right design for
  composing tool policies across extensions. The existing `has_shell_tokens` in
  `tool_runtime.ail` becomes a kernel-level guard that runs before extension decisions.
- `FinalizeDecision` aggregation rules are well-specified and handle multi-extension
  conflicts deterministically.
- Fail-closed on `on_tool_call` errors in read-only mode is the right safety default.
- Hook timeout via `CORE_EXT_HOOK_TIMEOUT_MS` is important and often omitted in similar
  designs.
- Using `CORE_EXT_ORDER` as the single source of truth for enablement + order is cleaner
  than separate enable/order flags.

---

## Issue Summary

| # | Issue | Severity |
|---|---|---|
| 1 | `Ctx` type undefined | Critical |
| 2 | Effect signatures on record hooks unresolved | Critical |
| 3 | Sequencing conflict with Semi-Formal plan next action | Critical |
| 4 | 8 hooks too broad for X1; start with 4 | High |
| 5 | `on_solver_candidate` trigger condition imprecise | Medium |
| 6 | No-op extension underspecified | Medium |
| 7 | `BudgetPatch` + kernel default interaction unspecified | Medium |
| 8 | `CORE_EXTENSIONS` deprecation note is spurious | Low |
| 9 | Phase X3 redundancy (consequence of sequencing gap) | Low |
