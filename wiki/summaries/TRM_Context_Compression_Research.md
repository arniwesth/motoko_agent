---
doc_type: short
full_text: sources/TRM_Context_Compression_Research.md
---

# TRM Context Compression Research Summary

This research note explores adapting the **Tiny Recursive Model (TRM)** — a ~7M-parameter, 2‑layer network with deep iterative refinement — from deterministic puzzle solving to **context compression** for agent conversations. The core hypothesis is that a tiny network with deep recursion avoids overfitting on small datasets and can generalize to compress conversational history into a fixed‑size latent representation, replacing raw token accumulation.

## TRM Architecture

The original TRM maintains three vectors: embedded input `x`, current answer `y`, and a latent reasoning state `z`. A shared 2‑layer network recursively updates `z = f(x + y + z)` multiple times, then produces `y = f(y + z)`. This inner loop runs `n` times per deep supervision step, with up to 16 improvement steps and gradient detachment between them. The key finding is that many recursions with 2 layers outperform fewer recursions with more layers (87.4% vs 79.5% on Sudoku).

## Mapping to Context Compression

The structural mapping is natural. Each deep supervision step becomes processing a new conversation chunk:
- `x` = a fixed‑size window of tokens (one chunk)
- `y` = a compressed fact/constraint set (fixed‑size token grid)
- `z` = a latent “what matters” representation
- The halt signal shifts from “puzzle solved” to “chunk adds no new information”

The loop carries `(y, z)` forward across chunks, incrementally refining the compressed state.

## Adaptation Challenges
- **Asymmetric lengths** – the biggest hurdle: input chunks (e.g., 512 tokens) are much larger than the output fact grid (e.g., 64 tokens). Additive fusion `x + y + z` fails. Solutions include learned projection, cross‑attention, or separate encoder‑decoder networks.
- **Training loop** – from repeated refinement on the same input to sequential chunks with state carried forward.
- **Dataset** – requiring conversations annotated with ground‑truth fact sets at each chunk boundary.
- **Loss function** – options span cross‑entropy against fact tokens, downstream task accuracy, reconstruction, or hybrid signals.
- **Halt mechanism** – reinterpret or remove it.

## Minimal Experiment Proposal
1. Collect ~100 agent transcripts and chunk into 16 windows.
2. Label 5–10 must‑remember facts per boundary.
3. Fork the TRM implementation, add a projection layer for length mismatch.
4. Train with each chunk as one deep supervision step.
5. Measure fact recall at step 16 vs. step 1.
6. Compare against truncation, LLM summary, and random baseline. If recall remains stable, the recursive state truly compresses information.

## Open Question
TRMs excel on tasks with deterministic logical structure (like Sudoku). Whether recursive latent refinement helps for fuzzy, ambiguous natural language context is unknown. The architecture’s additive fusion is a coarse bottleneck; nuances may demand richer attention mechanisms. However, the tiny network + deep recursion strategy might generalize well with limited training data.

## Relevance to the ailang Agent
The agent’s 50‑step loop accumulates observations that degrade after ~30 steps. A TRM‑based compressor running in the background could fold each observation into a fixed‑size state, replacing raw history via a new `compact` JSONL event. This would keep the LLM focused on recent context plus compressed history, requiring only minor runtime changes.

[[concepts/tiny_recursive_network]] [[concepts/context_compression]] [[concepts/deep_supervision]] [[concepts/adaptive_halt]] [[concepts/asymmetric_input_output]] [[concepts/conversation_chunking]]