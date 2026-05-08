# TRM for Context Compression — Research Note

**Date:** 2026-05-02
**Paper:** "Less is More: Recursive Reasoning with Tiny Networks" (Jolicoeur-Martineau, 2025; arXiv:2510.04871)
**Reference implementation:** https://github.com/lucidrains/tiny-recursive-model
**Gemini transcript:** Tiny_Recursive_Models_with_LLMs_transcript.md

## Core Hypothesis

A TRM-style tiny recursive network (~7M params, 2 layers) could be trained to compress conversation context into a fixed-size latent state, replacing raw token accumulation in agent loops. The key bet: tiny networks + deep recursion avoid overfitting on small data, so a 7M-param recursive compressor might generalize better than fine-tuning a 100M-param summarizer.

## What TRM Actually Does (from the paper)

- Maintains three vectors: `x` (embedded input), `y` (current answer), `z` (latent reasoning state)
- A single 2-layer shared network recursively updates `z = f(x + y + z)` n times, then `y = f(y + z)` once
- This inner loop runs T times per deep supervision step (default: n=6, T=3 = 42 recursions)
- Deep supervision carries `(y, z)` forward across up to 16 improvement steps, with gradients detached between steps
- Key finding: 2 layers x many recursions >> 4 layers x few recursions (87.4% vs 79.5% on Sudoku-Extreme)
- z is a true latent — not decodable to tokens. y is the answer representation

## Mapping to Context Compression

| TRM (Puzzle) | TRM (Context Compression) |
|---|---|
| x = puzzle grid (fixed size) | x = conversation chunk (tokenized, padded to fixed window) |
| y = current solution | y = compressed fact/constraint set (fixed-size token grid) |
| z = latent reasoning | z = latent "what matters" representation |
| Deep supervision step = re-refine same puzzle | Deep supervision step = process next conversation chunk |
| Correct answer = solved grid | Correct answer = facts needed to answer downstream questions |
| Halt = "puzzle solved" | Halt = "this chunk adds no new information" |

The structural mapping is natural: deep supervision already does incremental state refinement. Each step takes previous `(y, z)`, processes new information, outputs updated state. That IS context compression.

## lucidrains Implementation Analysis

### Repo structure
```
tiny_recursive_model/
  trm.py              — original (gradients on last refinement block only)
  trm_dense_loss.py   — dense loss across ALL refinement blocks
  mlp_mixer_1d.py     — default 2-layer backbone
  trainer.py           — outer recurrence + EMA + adaptive halting
```

### Core loop (from trm.py)
```python
def refine_latent_then_output_once(self, inputs, outputs, latents):
    for _ in range(self.num_latent_refinements):  # n=6
        latents = self.network(outputs + latents + inputs)  # "think"
    outputs = self.network(outputs + latents)               # "commit"
    return outputs, latents
```

Single shared network for both operations. Distinguishes "thinking" from "committing" by whether `inputs` is in the sum. Trainer wraps this in up to 12 outer steps x 3 blocks x 6 latent refinements = 216 forward passes worst case.

### What transfers directly
- Inner refinement loop (6 latent updates + 1 output update per chunk)
- EMA for training stability on small data
- Halt mechanism (reinterpretable as "chunk adds nothing new")
- Separation of "reason with input" vs "crystallize output without input"
- Dense loss variant gives supervision signal at every refinement step

### What needs adaptation

**1. Asymmetric input/output lengths (BIGGEST CHANGE)**

Original assumes `len(input) == len(output)` and fuses via addition. For compression, input (512-token chunk) >> output (64-token fact grid). The additive fusion `outputs + latents + inputs` breaks.

Options (increasing capability):
- **Learned projection:** project input down to output length before adding. Minimal code change, lossy.
- **Cross-attention:** replace MLPMixer1D with encoder-decoder using cross-attention. Repo already supports x-transformers backend.
- **Two networks:** separate encoder for z and decoder for y. Breaks single-network elegance but natural for asymmetric lengths.

**2. Training loop: sequential chunks instead of repeated refinement**

```python
# Original: same input, refine answer
for step in range(max_recurrent_steps):
    loss, ..., outputs, latents = model(same_input, outputs, latents, labels=answer)

# Adapted: sequential chunks, carry state forward
for chunk, facts_so_far in conversation_chunks:
    loss, ..., outputs, latents = model(chunk, outputs, latents, labels=facts_so_far)
```

Deep supervision steps map to sequential conversation chunks. `outputs` (y) = evolving compressed facts. `latents` (z) = reasoning state deciding what to keep.

**3. Dataset creation**

Need conversations with ground-truth "facts at each point":
- Take agent transcripts (or synthetic conversations)
- For each chunk boundary, label the minimal fact set needed to answer downstream questions
- Facts as fixed-size token sequences (the "answer grid")

**4. Loss function options**
- Cross-entropy against fact tokens (if ground-truth facts available)
- Downstream task accuracy (can frozen LLM answer correctly given only y?)
- Reconstruction loss (can a decoder recover key information from y?)
- Hybrid: fact cross-entropy + auxiliary reconstruction

**5. Halt mechanism reinterpretation**
- Original: `is_correct = (pred == labels).all()` — "puzzle solved"
- Adapted: "compressed state unchanged after this chunk" or "chunk adds no new facts"
- Or remove halt entirely if all chunks must be processed

## Minimal Viable Experiment

1. **Collect** ~100 agent transcripts from this repo's runs
2. **Chunk** each into 16 fixed-size windows (512 tokens, padded)
3. **Label** 5-10 "must-remember" facts per transcript at each chunk boundary
4. **Fork** lucidrains repo, add projection layer for length mismatch
5. **Train** TRM: each chunk is one deep supervision step, carrying (y, z) forward
6. **Measure** fact recall at step 16 vs step 1 — does the compressed state hold information?
7. **Compare** against: naive truncation, LLM-generated summary, random baseline

If recall holds steady across 16 chunks, the recursive state is actually compressing. If it degrades, the architecture doesn't transfer from deterministic puzzles to natural language.

## The Fundamental Open Question

TRMs excel because puzzle tasks have **deterministic logical structure** — constraints that a fixed-point can capture losslessly. Natural language context has variable importance, ambiguity, and no single "correct" compressed form. The paper's 87.4% on Sudoku comes from the task structure. Whether recursive latent refinement helps for fuzzy natural language compression is genuinely unknown.

The strongest argument FOR: the tiny network + deep recursion avoids overfitting. With only ~100-1000 training conversations, a 7M-param TRM might generalize where a larger summarizer would memorize.

The strongest argument AGAINST: the additive fusion `x + y + z` is a very coarse information bottleneck. Natural language nuance may require richer attention-based fusion that the TRM architecture doesn't provide.

## Relevance to This Agent

The ailang agent runs a 50-step loop (`src/core/rpc.ail`) where observations accumulate in message history. By step 30-40, early observations degrade due to context window pressure. A TRM-based compressor could:
- Run as a background process, folding each observation into a fixed-size state
- Replace raw observation history with the compressed state every N steps
- Slot into the JSONL protocol as a `compact` event type
- Keep the expensive LLM focused on recent raw context + compressed history

This would require a new JSONL event and changes to the runtime loop, but the architecture is modular enough to support it.
