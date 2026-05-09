# Learning Chess Engines via Omnigraph

Using Omnigraph to learn chess engines transforms the process from "reading articles" to "modeling a domain." Instead of just gathering information, you are building a **structured, queryable knowledge substrate** that can evolve as you deepen your understanding.

## 1. Specialized Schema

A domain-specific schema models the entities of chess engine development:

```pg
node Engine {
    slug: String @key
    name: String @index
    language: String
    architecture: enum(bitboard, mailstep, etc)
}

node Concept {
    slug: String @key
    name: String @index
    description: String
}

node Paper {
    slug: String @key
    title: String
    url: String
}

node Decision {
    slug: String @key
    title: String
    rationale: String
    status: enum(proposed, accepted, superseded)
}

edge Implements: Engine -> Concept
edge Discusses: Paper -> Concept
edge InformedBy: Decision -> Paper
edge Contradicts: Decision -> Decision
```

## 2. The Workflow

### Phase A: Research Branching
Create a dedicated learning journey to isolate your notes from your main knowledge base:
`omnigraph branch create feature/learning-chess-engines`

### Phase B: Structured Ingestion (Memory)
As you read, mutate the graph rather than just taking prose notes:
- **Paper:** `insert_paper(slug="stockfish-nnue", title="NNUE in Stockfish", ...)`
- **Concept:** `insert_concept(slug="bitboards", name="Bitboards", ...)`
- **Connection:** `insert_edge(from="stockfish", to="bitboards", type="Implements")`

### Phase C: Active Traversal (Understanding)
Use queries to move from passive reading to active synthesis:
- **Discovery of Dependencies:** *"What concepts are required to understand Stockfish?"* $\to$ `component_dependencies("stockfish")`.
- **Identifying Gaps:** *"What concepts exist in the domain that I haven't linked to an engine yet?"* $\to$ Query `Concept` nodes with zero incoming `Implements` edges.
- **Synthesizing Arguments:** *"Why did the community move from traditional evaluation to NNUE?"* $\to$ `decisions_governing("evaluation-function")`.

## 3. Speculative Learning

The "killer feature" is **Speculative Design**. You can model hypothetical architectures:

1. Create a branch: `feature/theory-transformer-eval`.
2. Add a `Decision` node: `slug: "transformer-eval-adoption"`.
3. Add a `Concept` node: `slug: "transformer-architecture"`.
4. Add edges to see how this would re-map the dependency tree of an engine.

If the graph looks "broken" (e.g., impossible implementation paths), your theory may be flawed. You can visualize and test architectural hypotheses before writing code.

## Summary: The Paradigm Shift

| Feature | Traditional Learning | Omnigraph Learning |
| :--- | :--- | :--- |
| **Storage** | Markdown / Notion | Typed, relational graph |
| **Search** | Keyword / RAG | Structural / Traversal |
| **Context** | Disconnected snippets | Integrated hierarchy |
| **Thinking** | Linear (Book A $\to$ B) | Multidimensional (Node $\to$ Edge $\to$ Concept) |
