---
sources: [summaries/Omnigraph_Possibilities.md, summaries/omnigraph_ailang_improvement.md]
brief: Validating code against a graph-based architecture spec to detect drift and enforce constraints.
---

# Architectural Fitness

**Architectural Fitness** is the practice of treating a queryable, typed graph as the ground truth of a system’s architecture and continuously verifying that the actual implementation conforms to it. Instead of relying on static documentation or developer memory, architectural rules—such as allowed dependencies, layering constraints, and design decisions—are encoded as nodes and edges (e.g., `DependsOn`, `Governs`, `Constrains`). Automated checks then compare the real code structure against this specification, surfacing deviations before they become entrenched.

## Core Mechanism

1. **Model the Ideal State** – Using an [[omnigraph]] schema (see [[constraint-graph]]), define the intended architecture: components, their allowed dependencies, constraints (like \"no direct UI‑to‑infra\" edges), and the decisions that govern each part of the system.
2. **Parse the Actual Code** – A script (ideally run nightly or in CI) extracts the actual static dependencies, module imports, or structural information from source files.
3. **Fitness Check** – The extracted structure is diffed against the graph.
   - **Additions** – code introduces a dependency the graph says shouldn’t exist → flag as a violation.
   - **Orphans** – the graph declares a dependency the code no longer has → flag as a stale rule or missing dependency.
   - **Governance drift** – if a `Governs` edge links a decision to a component, any PR changing that component without referencing the decision is surfaced to reviewers (not blocked, but highlighted).

This turns architectural fitness into a testable property, not a wish.

## Benefits

- **Drift Detection:** Catches unauthorized dependencies, layering violations, and decisions that have become disconnected from the code, early and automatically.
- **Living Documentation:** Because the graph is the source of truth, generated architecture views, ADR indexes, and dependency maps are always in sync—documentation that can’t rot.
- **Queryable Guidance:** Developers and agents can query the graph proactively (e.g., “what are the constraints on component X?” or “which decisions govern this service?”) before making changes, reducing guesswork.
- **Decision Provenance:** Linking decisions to code via `Governs` edges and commit references creates a bidirectional audit trail from design intent to implementation.

## Relation to Other Concepts

- [[constraint-graph]] – The actual graph structure that stores rules, constraints, and patterns.
- [[semantic-patterns]] – Verified code patterns retrieved from the graph to enforce correctness.
- [[speculative-implementation]] – Designing alternatives on branches and using fitness checks to vet dependencies before merging.
- [[architectural-drift-detection]] – The specific automated check that compares the graph’s `DependsOn` edges with live code; a subset of architectural fitness.
- [[summaries/omnigraph_ailang_improvement]] – Original source describing fitness checks for AILang’s syntax and semantic rules.
- [[summaries/omnigraph_possibilities]] – Broader vision of graph‑based fitness across languages, nightly CI jobs, and governance surfacing.

## Summary

Architectural fitness transforms architecture from passive prose into an active, continuously tested model. By making the graph the ground truth, it catches drift, enforces constraints, and keeps design intent visibly connected to the codebase, thus keeping the system aligned with the decisions that shaped it.

## Related Documents
- [[summaries/Omnigraph_Possibilities]]
