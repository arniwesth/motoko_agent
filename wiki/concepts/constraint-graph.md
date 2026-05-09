---
sources: [summaries/2026-04-26-abort-history-and-omnigraph-delete.md, summaries/Omnigraph_Possibilities.md, summaries/AILANG_Agent.md, summaries/omnigraph_ailang_improvement.md]
brief: A queryable graph of AILANG rules, anti-patterns, and errors that enforces structural constraints
---

# Constraint Graph

A **Constraint Graph** is a formal, queryable representation of the rules and restrictions that govern a domain—in this case, the [[ailang]] programming language. Built on [[omnigraph]], it transforms static, prose-based documentation into a living knowledge base of structural constraints.

## Core Structures

The graph models three essential node types and their relationships:

- **Rule** – encapsulates a specific language rule, tagged with a `category` (`syntax`, `pattern`, `effect`, `type`) and a `slug` for machine-friendly identification.
- **AntiPattern** – captures known erroneous patterns (e.g., using `in` inside a block), each with a `severity` of `warning` or `error`.
- **Error** – stores human-readable messages that explain rule violations.

Edges express how rules interact with violations:
- `Prevents: Rule -> AntiPattern` – a rule directly forbids a specific anti-pattern.
- `Explains: Rule -> Error` – a rule is associated with the diagnostic message that fires when the rule is broken.

## How It Works

Instead of memorising language rules, a developer queries the graph at development time. For instance:
```
list_rules(category="syntax") → returns all syntax rules, including the restriction that `let x = e in` cannot appear inside `{}` blocks.
```
This shifts the developer's interaction from "hoping to remember" to "querying verified constraints."

The Constraint Graph also serves as the backbone for [[architectural-fitness]] checks: a script can parse `.ail` source code and compare it against the graph, automatically flagging any violation. Rules become not just documentation but active agents in code verification.

## Relationship to Other Concepts

- The graph is built on [[omnigraph]]'s schema and query capabilities, making it a practical example of how structured knowledge can improve language tooling.
- It directly supports [[semantic-patterns]] by storing verified `Pattern` nodes—correct implementations of common idioms that are linked to their required effects, enabling safer retrieval than generic RAG.
- In a [[speculative-implementation]] workflow, the Constraint Graph validates design decisions (e.g., no circular dependencies) before any code is written, anchoring the design phase in real constraints.

## Source
This concept is primarily derived from the approach described in [[summaries/omnigraph_ailang_improvement]], where Omnigraph is used to bridge the gap between AILANG's strict rules and correct implementation behaviour.

See also: [[summaries/AILANG_Agent]]

See also: [[summaries/Omnigraph_Possibilities]]

See also: [[summaries/2026-04-26-abort-history-and-omnigraph-delete]]