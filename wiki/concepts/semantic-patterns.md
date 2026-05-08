---
sources: [summaries/Omnigraph_Possibilities.md, summaries/omnigraph_ailang_improvement.md]
brief: Structured, queryable code patterns in Omnigraph that replace unreliable similarity-based search.
---

# Semantic Patterns

**Semantic Patterns** are a method for storing and retrieving verified, typed programming patterns within an [[omnigraph]] knowledge base. Unlike similarity-based retrieval-augmented generation (RAG) which may return outdated or incorrect code, semantic patterns encode:

- **Nodes** representing specific patterns (e.g., `Pattern: Recursive Filter`, `Pattern: Record Update`)
- **Typed edges** that link patterns to required effects (e.g., `Implements: Pattern → Effect(IO)`)

When a developer needs to implement a common operation—like mapping a list in [[ailang]]—they query the pattern graph for `list_map`. This returns the exact pattern node, which includes the correct primitives from `std/list` and the required `match` syntax, eliminating guesswork and the risk of pulling in incorrect snippets.

## Key Characteristics

- **Verification**: Patterns are curated and verified as correct before being stored, unlike generic code search.
- **Typed associations**: Each pattern is linked to its required effects, type constraints, and related rules from the [[constraint-graph]].
- **Living documentation**: As the language evolves, patterns can be updated in the graph, automatically propagating correctness checks via [[architectural-fitness]] tests.

## Relationship to Other Concepts

Semantic patterns complement the [[constraint-graph]] by providing not only what is forbidden (rules/anti-patterns) but also what are the canonical implementations. They underpin the **speculative implementation** workflow, allowing designers to reference known patterns when defining effect signatures in a design branch before writing any code (see [[speculative-implementation]]).

## Source

This concept originates from the proposal to use Omnigraph to improve AILANG development, as detailed in [[summaries/omnigraph_ailang_improvement]]. There, semantic patterns are presented as the replacement for "searching docs for 'how to map a list'"—a proactive, graph-enforced alternative to memory-based correctness.

See also: [[summaries/Omnigraph_Possibilities]]