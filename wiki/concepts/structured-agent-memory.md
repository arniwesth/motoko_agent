---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md, summaries/Omnigraph_Possibilities.md]
brief: Agent memory as a typed, queryable graph of structured assertions surviving sessions, not text snippets.
---

# Structured Agent Memory

**Structured Agent Memory** is a pattern where an AI agent records its experiences, failures, and learnings as **typed nodes** in a persistent graph, rather than relying on traditional text‑based retrieval (RAG). The memory is durable across sessions, queryable by structured traversal, and exists outside any single conversation window.

## Core Idea

Instead of storing prose in a vector database, the agent commits **structured assertions** to a graph. Each fact has a type (e.g., `Decision`, `Constraint`, `Framework`) and relationships (e.g., `Governs`, `DependsOn`, `InformedBy`). This allows the agent to query patterns like “what are all superseded decisions in this domain?” or “which components are flaky due to a particular timing assumption?” with exact answers, not approximate similarity.

## Key Advantages over RAG

- **Precision**: graph traversal returns exact matches against typed predicates, not guesswork from embeddings.
- **Composability**: facts link to each other. A flaky test can link to the constraint that explains the assumption that causes the flake. Next‑session agents see the whole chain.
- **Portability**: the graph is a directory that can be moved across projects or jobs, accumulating engineering judgment over time (see [[concepts/cross-project-memory-graph]]).

## How It Works in Omnigraph

As described in [[summaries/Omnigraph_Possibilities]], the agent uses the typed schema as a design‑thinking forcing function:

- A failed approach becomes a `Decision` with `status=superseded` and a rationale describing the failure mode. Future sessions query `decisions_by_status("superseded")` before tackling similar problems.
- A library footgun becomes a `Framework` node linked to a `Decision` describing the surprise. Later library choices check for existing warnings.
- Flaky tests get a `Constraint` node that encodes the timing assumption—any agent that touches that test file sees it automatically.

This turns the agent’s working memory into a **structured knowledge base** that compounds with every learn‑from‑failure cycle.

## Relationship to Other Concepts

- **[[concepts/decision-provenance]]** structures the “why” of past choices. Structured memory stores the “what went wrong” alongside it, forming a full history.
- **[[concepts/architectural-drift-detection]]** checks the code against memory. Structured memory provides the ground truth of what *should* be, making drift detectable.
- **[[concepts/cross-project-memory-graph]]** shows how personal learnings stored as structured nodes remain accessible across employers and projects.

## Limits

- The graph is only as good as the discipline of recording. If the agent stops writing decisions, memory becomes a time capsule.
- The typed schema imposes friction (migrations, node‑type design), but that friction preserves integrity.

## Summary

Structured agent memory replaces fragile, text‑based recall with a durable, typed graph. It enables the agent to ask *structured questions* about its own past and get trustworthy answers—turning experience into an asset that grows, sessions after session.


See also: [[summaries/2026-04-26-abort-history-and-omnigraph-delete]]