---
doc_type: short
full_text: sources/Omnigraph_Possibilities.md
---

# Summary: Omnigraph Possibilities

This document explores the broader potential of Omnigraph, a tool that models decisions and system structure as a **typed, branch‑isolated, persistent across sessions** graph. Its three foundational properties enable far more than the initial components‑and‑decisions proof‑of‑concept.

## Core Properties as a Foundation

- **Typed schema** acts as a design‑thinking forcing function: you commit to what a thing *is* before you can describe it.  
- **Branch isolation** lets you explore speculative alternatives without polluting the main line, like a queryable, diffable whiteboard.  
- **Persistence across agent sessions** turns the graph into durable context that doesn’t evaporate with a chat window.

## Key Applications Explored

1. **Structured long‑term memory**—beyond RAG. The agent records its learnings as typed nodes (e.g., a `Decision` with `status=superseded` capturing a failed approach). Future sessions can query failure modes, known footguns, or surprising library behaviours, retrieving structured assertions rather than text snippets.
   - [[concepts/structured-agent-memory]]

2. **Architectural drift detection**—make the graph the ground truth and audit the actual code. A nightly diff between the graph’s `DependsOn` edges and actual code imports reveals unauthorized dependencies or orphans. Governance edges can surface incompatible changes, turning architecture rules into testable constraints.
   - [[concepts/architectural-drift-detection]]

3. **Decision provenance**—replace lost Slack threads with a queryable chain of decisions, incidents, and supersession. Each decision links to the component it governs, the post‑mortem that informed it, and the commits that implement it. A simple query answers “why did we do this?” and traces the entire history.
   - [[concepts/decision-provenance]]

4. **Speculative design on branches**—each design alternative lives on its own branch, adding its own decisions and components. Branches become comparable, testable, deletable futures. You can commit the one that wins and discard the rest.
   - [[concepts/speculative-design-branches]]

5. **Living documentation**—generate architecture overviews, ADR indexes, framework inventories, and dependency maps directly from the graph. The docs can’t rot because they are computed on read from the single source of truth.
   - [[concepts/generated-documentation]]

6. **Cross‑project memory**—multiple Omnigraph repos (project, infra, personal) can be accessed together. Personal learnings and past job decisions become portable engineering judgment available to the agent across contexts.
   - [[concepts/cross-project-memory-graph]]

7. **Additional graph‑enabled uses**: incident tracking, dependency license compliance, expertise mapping (who authored which decision), bus‑factor analysis, and even skill‑tree generation for onboarding. All collapse into the same typed graph substrate.

## Honest Limits

- **Not a database** for millions of nodes—the mental model of curated assertions breaks at scale.
- **Not automatic**—the graph stays useful only with disciplined updates.
- **Not a substitute for conversation**—it captures the outcome, not the debate.
- **Schema friction is real**—adding types or fields demands migrations, but that friction is also a feature.

## Proposed Next Steps

1. Ingest the existing `.agent/` folder (plans, ADRs) into Decisions and Components.
2. Add `Person` nodes and `Authored` edges for provenance.
3. Build the architecture‑drift check in CI.
4. Introduce `Paper`, `Article`, `Experiment` nodes for research traceability.
5. Generate a static documentation site from the graph.

## The Far Edge

Ultimately, the graph could become the design itself, with code generated as a projection. A decision node change triggers the agent to update relevant files and open a PR—the graph is the source of truth and the driver of implementation.

---
*The document’s core insight: the tool’s value grows with every new node type you’re willing to model—decisions, components, people, incidents, concepts, research—turning the graph into a multidimensional reasoning substrate for the agent.*

## Related Concepts
- [[concepts/architectural-fitness]]
- [[concepts/constraint-graph]]
- [[concepts/semantic-patterns]]
- [[concepts/sharedmem-cache-layer]]
