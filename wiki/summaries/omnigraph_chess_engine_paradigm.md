---
doc_type: short
full_text: sources/omnigraph_chess_engine_paradigm.md
---

The document introduces a method for learning chess engines by building a **structured, queryable knowledge graph** using Omnigraph, rather than linear note‑taking. This turns passive reading into active domain modelling.

### Key Ideas
- **Domain Schema**: A typed graph schema defines nodes (`Engine`, `Concept`, `Paper`, `Decision`) and edges (`Implements`, `Discusses`, `InformedBy`, `Contradicts`). This models the relationships between engines, underlying concepts, research papers, and design rationales.
- **Workflow Phases**:
  1. **Structured Ingestion**: As you read, insert nodes and edges directly into the graph—papers map to concepts, engines implement concepts, decisions link to papers.
  2. **Active Traversal**: Use graph queries to answer questions like “What concepts does Stockfish depend on?” (dependency discovery), “Which concepts have no engine implementing them?” (gap analysis), or “What design decisions led to NNUE?” (argument synthesis).
  3. **Speculative Design**: Model hypothetical architectures (e.g., a transformer‑based evaluation) by adding new `Decision` and `Concept` nodes on a separate branch. If the resulting dependency graph is inconsistent, the hypothesis may be flawed—allowing faster, visual testing of ideas.
- **Paradigm Shift**: Compared to traditional linear learning, Omnigraph provides a **relational, traversal‑based** substrate where context is preserved through explicit connections, and understanding emerges from structural exploration rather than fragmented search.

### Connections
This approach ties to broader ideas of [[concepts/graph-based-knowledge]], [[concepts/omnigraph]], and [[concepts/speculative-design]]. The chess engine focus connects to [[concepts/chess-engine-architecture]] and [[concepts/evaluation-functions]]. The workflow embodies [[concepts/structured-learning]] and [[concepts/knowledge-traversal]].