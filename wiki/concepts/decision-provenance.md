---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md, summaries/Omnigraph_Possibilities.md]
brief: Trace why a decision was made by querying typed nodes for governance, incidents, and supersession chains.
---

# Decision Provenance

**Decision provenance** is the ability to trace the full lineage and rationale of every architectural or technical decision—what problem it solved, which incident or argument informed it, what it replaced, and how it has been modified since. In an Omnigraph, it replaces scattered Slack threads, ADR markdown folders, and tribal memory with a queryable graph of typed nodes and edges.

## The Problem it Solves

Every team accumulates decisions that are discovered only by archaeology. The worst case is a single Slack message from 2023 buried under months of chatter, the only explanation for why the payment service retries seven times with exponential backoff. ADR folders help, but they are disconnected; they don’t compose, don’t diff across branches, and don’t let you ask “what does decision X depend on?” or “which later decisions override it?”

## How Omnigraph Captures Provenance

The core idea, drawn from [[summaries/Omnigraph_Possibilities]], is to model each decision as a typed node (`Decision`) and connect it with structured edges:

- `Governs` → the component the decision affects.
- `InformedBy` → the incident, post‑mortem, or research that motivated it.
- `Supersedes` → a previous decision that was replaced, creating a chain of evolution.
- `DependsOn` → other decisions that this one relies on.

When someone asks *“why did we do this?”*, a simple query like `decisions_governing("payment-service")` returns the entire chain: the current policy, the incident that triggered it, and the older policy it superseded. Because commits implementing a decision can reference its slug (e.g., `Governs: dst-shift`), the tie between code and decision becomes bidirectional: a `git log` finds every change justified by that decision, and the graph links back to the implementation.

## From ADR Files to Graph Traversal

Traditional ADRs create a folder of independent markdown files. The Omnigraph alternative is a graph‑structured, branch‑isolated, persistent record:

- **Queryable** — find all superseded decisions in a domain, or all decisions authored by a person.
- **Diffable** — compare decision chains across branches to evaluate design alternatives.
- **Self‑updating** — the generated ADR index ([[concepts/generated-documentation]]) stays in sync with the graph; a superseded decision drops out of the active index automatically.
- **Persistent** — the agent carries the memory across sessions, and it can even cross projects ([[concepts/cross-project-memory-graph]]).

## Connection to Other Omnigraph Features

Decision provenance is reinforced by several other concepts:

- It feeds **structured memory** ([[concepts/structured-agent-memory]]): the agent records failed approaches as superseded decisions, turning past experiments into a failure‑mode library for future tasks.
- It enables **architectural drift detection** ([[concepts/architectural-drift-detection]]): if a PR touches a component governed by a decision without referencing that decision, a tool can flag the change for review.
- It underlies **speculative design branches** ([[concepts/speculative-design-branches]]): each branch can have its own decision provenance chain, making it clear which alternatives were explored and why one won.

## Summary

Decision provenance transforms the messy oral history of a software system into a typed, queryable, diffable, and branch‑aware record. It turns “why did we do this?” from a forensic nightmare into a one‑edge traversal.

See also: [[summaries/2026-04-26-abort-history-and-omnigraph-delete]]