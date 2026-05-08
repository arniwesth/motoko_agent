---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md]
brief: Mutation guardrail that denies all changes on main and restricts bulk deletions to safety-prefixed branches.
---

# Branch-Aware Guardrail Policy

## Overview
The **Branch-Aware Guardrail Policy** is the safety enforcement layer in [[concepts/omnigraph]] that prevents destructive or unapproved mutations by inspecting both the operation type and the current git branch context. It replaces the earlier flat `is_main_branch_mutation` boolean check with a structured function that returns an optional denial reason, making the policy explicit, testable, and extensible.

This policy was introduced as part of the Omnigraph deletion capability rollout described in [[summaries/2026-04-26-abort-history-and-omnigraph-delete]].

## How it works

### Core function
A single entry point, `denied_mutation_reason`, takes a `ToolCallEnvelope` and returns `Option[string]`:

- **`None`** → the mutation is allowed to proceed.
- **`Some(reason)`** → the mutation is blocked, and the human-readable reason is returned to the caller.

### Rule ordering
The policy applies two rules in strict priority order:

1. **Main-branch protection** — *any* mutation targeting the `main` branch is denied immediately. There are no exceptions. This ensures that every graph change happens on a working branch first.

2. **Bulk-delete prefix guard** — `delete_all_*` operations (e.g. `delete_all_decisions`, `delete_all_components`, `delete_all_dependencies`, `delete_all_governs`) are denied *unless* the current branch name starts with `wipe/` or `cleanup/`. This prevents accidental mass deletion on experimental branches while still allowing intentional full resets.

Mutations that pass both rules (e.g. a single-node delete on a branch named `fix/123`) are allowed.

### Shared argument helper
A new module, `args.ail`, was extracted to hold reusable argument-access logic for both the guardrail policy and the Omnigraph extension itself, keeping the code DRY and testable.

## Test coverage
The policy is verified through a full allow/deny matrix in [[concepts/omnigraph]]'s test suite (`omnigraph_test.ail`). The test suite exercises:

| Scenario | Branch | Mutation type | Expected |
|---|---|---|---|
| Any mutation on `main` | `main` | any | ❌ Denied |
| Bulk delete on regular branch | `feature/xyz` | `delete_all_*` | ❌ Denied |
| Bulk delete on `wipe/` branch | `wipe/reset` | `delete_all_*` | ✅ Allowed |
| Bulk delete on `cleanup/` branch | `cleanup/old` | `delete_all_*` | ✅ Allowed |
| Single delete on regular branch | `feature/xyz` | `delete_decision` | ✅ Allowed |

## Integration with deletion workflow
This guardrail is the enforcement mechanism behind the [[concepts/branch-based-deletion-workflow]] pattern. The workflow prescribed in the Omnigraph agent prompt—branch, edge cleanup, node deletion, verify, merge—is only possible because the guardrail allows targeted operations on feature branches while blocking everything on `main`.

## Related concepts
- [[concepts/omnigraph]] — the graph-based decision system this policy protects
- [[concepts/branch-based-deletion-workflow]] — the safe deletion procedure the guardrail enables
- [[concepts/abort-handling]] — another runtime safety improvement from the same change set

## Source
- [[summaries/2026-04-26-abort-history-and-omnigraph-delete]] — the implementation document that introduced this policy