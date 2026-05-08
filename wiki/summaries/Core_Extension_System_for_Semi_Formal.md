---
doc_type: short
full_text: sources/Core_Extension_System_for_Semi_Formal.md
---

# Review Summary: Core Extension System for Semi-Formal

This review finds the architectural instinct correct—separating extension concerns from the kernel makes future capabilities cheaper and keeps safety central—but exposes several blocking issues, particularly around AILANG type realisability and plan sequencing with the Semi-Formal roadmap.

## Critical Issues

- **`Ctx` type undefined**: Every hook receives a `ctx` argument, but `Ctx` (or `ExtCtx`) has no type definition. This blocks all code. A concrete type must be defined in `src/core/ext/types.ail`. See [[concepts/ailang types]].
- **Effect signatures on record-stored hooks unresolved**: Storing effectful functions in a record forces every field to declare the maximal effect set (`! {IO, Process, FS, AI, ...}`), burdening pure extensions. Acknowledge this or split pure/effectful hooks into separate registries. See [[concepts/effect system]] and [[concepts/hook composition]].
- **Sequencing conflict with Semi-Formal plan**: The extension plan's "Phase X1" (extension substrate) and the Semi-Formal plan's "Phase B" (budget controls) are mutually exclusive starting points. Without explicit resolution—either X1 supersedes earlier phases or the plans run in parallel with migration notes—implementation will diverge. See [[concepts/semi-formal plan]] and [[concepts/phase sequencing]].

## High Issues

- **8 hooks too broad for X1**: Only 4 hooks (`on_build_system_prompt`, `on_budget_plan`, `on_tool_call`, `on_solver_candidate`) are needed for Semi-Formal phases A–D. Starting with 4 reduces delivery risk and testing overhead.
- **`on_solver_candidate` trigger condition imprecise**: The hook must specify which solver path (hybrid or legacy) fires it, as verifier integration only makes sense in hybrid mode.

## Medium Issues

- **No-op extension underspecified**: The registry should handle empty extension lists without a built-in no-op stub.
- **`BudgetPatch` and kernel defaults**: The kernel's default budget computation (the 75/25 split from Semi-Formal) and how patches override it need definition. See [[concepts/budget-formula]].
- **Deprecation of non-existent `CORE_EXTENSIONS`** is spurious; define only `CORE_EXT_ORDER`.

## Low Issues

- **Phase X3 redundancy** with Semi-Formal Phase C if sequencing remains unsettled.

## Solid Design Elements

- Kernel vs. extension split correctly: safety actions (abort, hard caps, tool deny) stay in kernel; behavior (prompt shaping, verifier invocation) belongs to extensions.
- `ToolDecision` composition with deny-wins and `FinalizeDecision` aggregation rules are well-specified.
- Fail-closed defaults and hook timeouts via `CORE_EXT_HOOK_TIMEOUT_MS` are important safety nets.
- Using `CORE_EXT_ORDER` as single truth for enablement and ordering is clean.

## Key Recommendations

1. Define `ExtCtx` type before any implementation.
2. Resolve effect signatures—either document that pure hooks carry overbroad effects or split registries.
3. Align extension plan and Semi-Formal plan next actions: choose X1‑first or migration path.
4. Ship X1 with 4 hooks; defer `on_finalize` and `on_error` to later phases.

This review serves as a checkpoint before coding begins, linking the extension plan to the concrete [[concepts/semi-formal plan]], [[concepts/tool-policy]], and [[concepts/hook-composition]].