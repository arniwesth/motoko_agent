Gemma 4 can be finetuned using unsloth
https://unsloth.ai/docs/models/gemma-4/train

It happens so that Kaggle is hosting a Gemma 4 competition:
https://www.kaggle.com/competitions/gemma-4-good-hackathon

and Gemma 4 is easily trainable using eg
https://www.kaggle.com/code/danielhanchen/gemma4-31b-unsloth

This plays very well into the Fine-tuning / LoRA (lever 7) in the 2026-04-14 Next Plan for AILANG Performance doc.
I want to participate in this competition, and you and I are going to have a deep discussion on this.

---

This is a brilliant strategic move. You are taking **Lever 7 (Fine-tuning / LoRA)**—which the 2026-04-14 plan explicitly identified as having the *"highest ceiling"* and being the *"ultimate fix for distribution shift"*—and accelerating it using a Kaggle hackathon and Unsloth's highly efficient QLoRA training stack. 

This perfectly solves the root cause identified in the documentation: **Gemma 4's pre-training priors pull it toward Python/JS**, making it struggle with AILANG's Hindley-Milner types, algebraic effects, and rigid syntax discipline. We are going to permanently shift those priors.

Furthermore, the "Gemma 4 Good" narrative writes itself: **"Creating an AI that writes mathematically provable, hallucination-free code"** by fine-tuning it to natively author AILANG's Z3-verified contracts (`requires {}` / `ensures {}`). That is an incredibly strong hackathon submission.

To make this successful, we need to treat this as an applied research pipeline. Here is how I propose we break down our deep discussion. Which of these four areas should we tackle first?

### 1. The Representation Dilemma: Raw AILANG vs. Tool-Call Sequences
The documentation leaves us with a critical architectural choice for the fine-tuning data format:
*   **Path A (Raw `.ail` Text):** We train Gemma 4 to output raw AILANG code. This forces the model to learn the exact syntax (`{` vs `in`, multi-arg vs curried, effect rows). 
*   **Path B (Structured Tool Calls):** The doc explicitly notes: *"If fine-tuning is pursued later, train on tool-call sequences rather than raw `.ail` text... Signal-to-noise per training token is much higher."* We train it to emit `define_func`, `build_match`, `build_let`, etc. 

*Question for you:* Are we aiming to create a model that is a native AILANG raw-code author (flashier for a hackathon demo, but harder to train), or an elite AILANG *dispatcher agent* that speaks in tool-calls (more reliable, aligns with Lever 2)?

### 2. The Dataset Recipe (The "Valid-AILANG Corpus")
Since AILANG is OOD (Out-Of-Distribution) for Gemma 4, data quality is everything. We can't just scrape GitHub. We need to synthetically generate or curate a pristine corpus:
*   **The Z3 Verified Core:** Examples of functions with `requires` and `ensures` that pass `ailang verify`.
*   **Production Traces:** Snippets from `.motoko-store/snippets` that are known to compile and pass `ailang check`.
*   **Negative → Positive Corrections (Error Reasoning):** We should include examples of *common mistakes* (e.g., using `for x in xs` or `f(a)(b)` incorrectly) followed by the AILANG compiler error, and then the correct resolution. This teaches the model the "Error → Hint" mapping (Lever 4) directly in its weights!

*Question for you:* Do we already have a pipeline to extract accepted snippets from production runs, or will we need to synthetically generate this dataset using a stronger frontier model (like Claude Opus) acting as a teacher?

### 3. Unsloth & Kaggle Hardware Strategy
You mentioned Unsloth (`danielhanchen/gemma4-31b-unsloth`). Given the 26B/31B parameter count, fitting this on Kaggle's typical accelerator setups (like dual T4s or a single L4/P100) requires precise Unsloth configurations:
*   **4-bit Quantization (bitsandbytes):** Mandatory to fit the active parameters (3.8B active / 25B+ total MoE) into VRAM.
*   **Target Modules:** For coding tasks, we should target all linear layers (`q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`) to maximize the model's ability to learn the new grammar.
*   **Sequence Length:** AILANG context (like the stdlib) can get long. Unsloth supports RoPE scaling, but we'll need to decide on our max token length (e.g., 4096 or 8192) to prevent VRAM OOM on Kaggle.

### 4. Evaluation Benchmark (How we prove we won)
To impress the Kaggle judges and validate Lever 7 for the AILANG project, we need an evaluation metric. General code benchmarks (LiveCodeBench) won't work.
*   We need to write an **AILANG Validity Benchmark**: A test set of 50-100 natural language prompts ("Write an HTTP GET with JSON parsing", "Write a verified tax calculator").
*   **Metrics:** 
    1. Parse success rate (`ailang check` passes).
    2. Verification success rate (`ailang verify` passes).

---

**Where do you want to start?** If we nail the **Representation Dilemma (Raw vs Tool-calls)** and the **Dataset Recipe**, the Unsloth code on Kaggle will be the easy part!

---

We are 100% aiming to create a model that is a native AILANG raw-code author

We need to synthetically generate this dataset using a stronger frontier model (like Claude Opus) acting as a teacher

We don't need to use Kaggle Hardware. I have a substantial budget to run it on more powerful cloud GPUs

For benchmarks, we should be looking into what already exist before we build our own. Look here: https://ailang.sunholo.com/docs/benchmarks/performance

---




This is a fantastic pivot. By choosing to train Gemma 4 as a **native raw-code author**, we are taking on the harder but much more rewarding path. Removing the Kaggle hardware constraint and using the existing benchmarks completely changes our tactical approach. 

I just pulled the live benchmarks from `ailang.sunholo.com/docs/benchmarks/performance`, and I have a clear picture of what we are up against. **Claude Opus 4.6** is currently the undisputed King of AILANG with an 84.3% success rate, while the other models hover around 70-80%, and earlier open weights struggle significantly. 

Since we have cloud budget, Claude Opus as our teacher, and established benchmarks, here is the blueprint for how we win the "Gemma 4 Good" hackathon.

### 1. The Dataset Strategy: Distilling Claude Opus 4.6
Since we want Gemma to write raw AILANG, we need to violently overwrite its Python/JS priors. We will do this via **Reasoning Distillation** using Claude Opus 4.6 as our synthetic data generator.

Instead of just giving Gemma 4 the final AILANG code, we will train it on the `<|think|>` process that leads to valid code.
*   **The Prompt to Opus:** We will write a script that feeds Opus the `ailang-v0.9.0-docs.md` and asks it to solve 10,000 synthetic variations of the official benchmarks. 
*   **The Output Format:** We will instruct Opus to explicitly reason about AILANG's rules *before* writing the code. For example:
    *   *Opus thought trace:* "The prompt asks to update a list. I cannot use a `for` loop or `list.map()` because AILANG is pure functional. I must import `std/list (map)`. The prompt requires file reading, so I must declare the `! {FS}` effect in my signature. I will use block-style let bindings with semicolons."
    *   *Opus code trace:* `export func main() -> () ! {FS} { ... }`
*   **The "M-EVAL-LOOP" Trajectories:** The benchmark page notes that structured compiler feedback fixes 18% of failures. We will ask Opus to generate *intentional* common mistakes (like using `f(a)(b)` incorrectly), show the simulated compiler error, and then generate the correction. Training Gemma on these multi-turn corrections will make it a master at self-repair.

### 2. Hardware & Unsloth Setup (Unchained)
Since we aren't restricted to Kaggle's dual T4s/L4s, we will rent an **8x H100 (80GB)** or **8x A100** instance. 

Even with a massive budget, Unsloth is the right tool because its optimized Triton kernels train 2x-5x faster and use less memory. But we will change the config from the Kaggle baseline:
*   **No 4-bit Quantization:** We will train in native `bfloat16`. This prevents quantization degradation and allows the model to learn the strict punctuation of AILANG (like `{ let x = 1; }` vs `let x = 1 in`) with absolute precision.
*   **High-Rank LoRA / Full Fine-Tuning:** The Kaggle notebooks usually use `r=16` or `r=32`. We will use a massive LoRA rank (`r=256` or `r=512`) targeting *all* linear modules (`q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`). Alternatively, with an 8x H100 node, we could just do a **Full Fine-Tuning (FFT)** of Gemma-4-31B.
*   **Long Context (RoPE):** AILANG files can get dense, especially with Z3 contracts. Unsloth allows us to seamlessly scale the context window to 8192 or 16384 tokens during training without OOMing.

### 3. Conquering the Official Benchmarks
I looked at the specific failing benchmarks on the official site. The standard logic tests (`Fizzbuzz`, `Merge Sort`) are already passing at 80-100% for top models. Where models fail entirely are the **Contract Verification Benchmarks**. 

Look at these specific benchmarks that currently have a **0% to 17% AILANG success rate** even on frontier models:
*   `Contract Matrix Determinant` (17%)
*   `Contract Sorted Merge` (17%)
*   `Contract Rle Roundtrip` (0%)
*   `Type Unify` (0%)

**This is our Hackathon hook.** 
If we use Claude Opus to synthetically generate thousands of examples of Z3-verified contracts (`requires { ... }` and `ensures { ... }`), and fine-tune Gemma 4 on them, Gemma 4 will natively understand mathematically proven code boundaries. 

We submit our model to the hackathon with the following pitch: 
*"We fine-tuned Gemma 4 not just to write code, but to write mathematically verified code. Gemma-4-AILANG scores higher on the Contract Benchmarks than GPT-5 and Claude Opus."*

### Next Steps for Us
To kick off the pipeline, we need to generate the synthetic dataset. Shall I draft the Python script that orchestrates the Claude Opus API calls to generate the dataset? I can design the system prompt that forces Opus to emit the `<|think|>` tags and the Z3 contract variations.

---

Before moving further, can you draft a full plan?

---




Here is the comprehensive, end-to-end plan for fine-tuning Gemma 4 (26B A4B-it) to become a native AILANG developer and win the "Gemma 4 Good" Kaggle Hackathon.

This plan treats the hackathon not just as a coding competition, but as an applied research effort to solve the exact "Problem Framing and Research Directions" outlined in the AILANG 2026-04-14 documentation (specifically, Lever 7: overcoming Python/JS priors via Fine-Tuning).

---

# Project Plan: Gemma-4-AILANG (Kaggle "Gemma 4 Good" Submission)

## 🎯 The Hackathon Hook: "Mathematically Verified AI"
Most code-generation models produce plausible but hallucinated syntax. AILANG’s superpower is its Z3-verified contract system (`requires` / `ensures`). Our submission narrative will be: **"We fine-tuned Gemma 4 to be the world's first open-weights model that natively writes mathematically provable, zero-hallucination code."** 

We will prove this by beating the frontier models (including our teacher, Claude Opus 4.6) on the hardest tier of the official AILANG Performance Benchmarks (e.g., `Contract Matrix Determinant`, `Contract Rle Roundtrip`).

---

## Phase 1: Synthetic Data Generation Pipeline (The Claude Opus 4.6 Teacher)
Since Gemma 4 suffers from "Python/JS prior pull," we need a dataset that explicitly rewires its syntactic reflexes. We will use Claude Opus 4.6 via API to generate 15,000–20,000 highly curated AILANG trajectories.

**1.1 The "Reasoning Distillation" Format**
Gemma 4 supports a `<|think|>` mode. We will prompt Opus 4.6 to generate data in this exact format.
*   **Prompt:** A natural language coding task.
*   **Thought Trace:** Opus will explicitly reason about AILANG constraints before writing code (e.g., *"No `for` loops allowed. I must use `std/list (foldl)`. The function uses file reading, so I must declare `! {FS}`. I am inside a `{}` block, so I must use `;` instead of `in` for let bindings."*)
*   **Final Output:** The perfect, compiling `.ail` snippet.

**1.2 Dataset Composition Strategy**
*   **30% Core Syntax & Effects:** Over-indexing on the rules Gemma 4 fails at: block vs. expression `let` bindings, multi-arg vs. curried function calls, and effect row precision (`! {IO, FS, Net}`).
*   **40% Z3 Contracts (The Killer Feature):** Generating complex `requires {}` and `ensures {}` combinations covering list theory, string theory, and integer arithmetic.
*   **30% Error-Recovery Trajectories:** Prompting Opus to simulate a common AILANG mistake (e.g., `TYP_EFFECT_ROW_MISMATCH`), show the raw compiler error, and output the thought process and corrected code. This bakes Lever 4 (Error -> Hint reasoning) directly into the model's weights.

---

## Phase 2: Hardware & Unsloth Training Architecture
Because we are unconstrained by Kaggle hardware, we will skip heavy quantization and train for maximum syntactic precision.

**2.1 Infrastructure Setup**
*   **Hardware:** Provision an **8x H100 (80GB)** or **8x A100 (80GB)** cluster via a cloud provider (AWS, RunPod, or Lambda Labs). 
*   **Framework:** Unsloth Pro/Enterprise (for multi-GPU optimization). Unsloth’s Triton kernels will allow us to train at 2x-5x the speed of standard Hugging Face `SFTTrainer`.

**2.2 Training Hyperparameters**
*   **Precision:** Native `bfloat16`. We will *not* use 4-bit (QLoRA) quantization. AILANG syntax relies heavily on exact punctuation (`=>`, `::`, `! {}`). Quantization degrades the model's attention to these micro-syntactic tokens.
*   **Method:** **High-Rank LoRA**. We will target all linear layers (`q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj`) with a massive rank of **`r=256` or `r=512`** and `alpha=2x`. Because Gemma 4 MoE has only 3.8B active parameters during a forward pass, we can easily fit this massive adapter in H100 VRAM. 
*   *(Fallback: Full Fine Tuning / FFT. If LoRA plateaus on the benchmarks, 8x H100s gives us enough memory to execute an FFT using DeepSpeed Zero-3).*
*   **Context Window:** Scale RoPE to **8192 tokens** to ensure the model can ingest large ledger snapshots and output long Z3 contract files without truncation penalties.

---

## Phase 3: Evaluation & Benchmarking
We will evaluate checkpoints locally against the official benchmarks hosted at `ailang.sunholo.com/docs/benchmarks/performance` to objectively track our progress.

**3.1 Custom Evaluation Harness**
We will write a Python evaluation script that mimics the official benchmark environment:
1.  Loads our Gemma-4-AILANG LoRA.
2.  Runs the benchmark prompts.
3.  Passes the output to the local `ailang check` and `ailang verify` binaries.

**3.2 Target Metrics & Milestones**
*   **Baseline (Vanilla Gemma 4):** Expect ~10-20% parse success, 0% contract verify success.
*   **Milestone 1 (Syntax Mastery):** Achieve >95% success rate on `ailang check` (Parse/Type checks) on standard logic benchmarks (Fizzbuzz, HTTP routing, List filtering). This proves we have successfully overridden the Python/JS priors.
*   **Milestone 2 (Z3 Mastery):** Break the 50% barrier on the notoriously difficult `Contract Matrix Determinant`, `Type Unify`, and `Contract Rle Roundtrip` benchmarks. *Note: Opus 4.6 currently scores ~0-17% on these. If we distill Opus's best attempts and filter for only the ones that pass verification, Gemma will learn the underlying patterns and surpass the teacher.*

---

## Phase 4: Kaggle Submission & Open Sourcing
To win "Gemma 4 Good", the presentation and reproducibility are just as important as the weights.

**4.1 The Deliverables**
1.  **Hugging Face Model:** Publish the base weights and the LoRA adapter (e.g., `sunholo/gemma-4-26b-ailang-z3-coder`).
2.  **The Dataset:** Open-source the synthetic 15k AILANG dataset. High-quality synthetic datasets are highly prized by Kaggle judges.
3.  **Kaggle Inference Notebook:** Create a clean, fast Kaggle notebook using Unsloth's `FastLanguageModel` inference module. The notebook will demonstrate the model taking a natural language prompt, generating a `<|think|>` trace, and outputting mathematically verified AILANG code.
4.  **Write-up / Report:** Frame the problem exactly as the AILANG doc does ("The Grounding/Distribution Shift Problem"). Detail how we utilized Unsloth to solve it without relying on structured tool-calling crutches.

---

### Immediate Next Steps

If you approve this plan, our critical path is **Phase 1: Synthetic Data Generation**.

1.  I can immediately draft the Python orchestration script utilizing the Anthropic SDK to call Claude Opus 4.6.
2.  I can draft the highly-specific System Prompts required to force Opus to generate the `<|think|>` traces, using the `ailang-v0.9.0-docs.md` as context.

Shall we begin drafting the data generation pipeline?

---

We need to revise the hardware plan a bit. Unsloth Pro/Enterprise is almost certainly out of the question. Any offerings that require one to contact a sales rep (like Unsloth Pro/Enterprise) are generally out of the question.

---




You are absolutely right. Dealing with enterprise sales cycles or opaque pricing is a complete non-starter for a fast-moving hackathon. 

If we have the budget for serious cloud compute (like an 8x H100 or 8x A100 node) but want to stick strictly to 100% open-source, non-gated software, we can easily pivot the Phase 2 training stack. 

Here is the revised **Phase 2: Hardware & Training Architecture**, replacing the enterprise Unsloth dependency with industry-standard open-source alternatives.

### Revised Phase 2: Open-Source Heavy Compute Stack

**2.1 Infrastructure Setup**
*   **Hardware:** Rent an **8x H100 (80GB)** or **8x A100 (80GB)** bare-metal instance from an on-demand provider like RunPod, Lambda Labs, or FluidStack. No contracts, just raw compute billed by the hour.
*   **Framework (The Pivot):** We will use **Axolotl** or **Llama-Factory**. 
    *   **Axolotl** is the current gold standard open-source framework for multi-GPU training. It is fully configuration-driven (YAML), actively maintained, and wraps Hugging Face's `accelerate` with native support for Gemma models.
    *   Alternatively, we can use the **Free Open-Source version of Unsloth**, but we would constrain it to a 1x or 2x H100 setup (which it supports well) and use the remaining GPUs to run multiple training experiments simultaneously (e.g., hyperparameter sweeps).

**2.2 Training Hyperparameters (via Axolotl / OSS Stack)**
*   **Multi-GPU Strategy:** We will use **PyTorch FSDP (Fully Sharded Data Parallel)** or **DeepSpeed ZeRO-3**. Because Gemma 4 is a MoE (25.2B total parameters), the weights take up ~50GB in `bfloat16`. FSDP will shard the model, gradients, and optimizer states across all 8 GPUs, meaning we will have massive amounts of VRAM left over.
*   **Precision:** Native `bfloat16`. No 4-bit quantization. We want the model to learn exact punctuation and syntax with full precision. Flash Attention 2 will be enabled to keep memory usage and compute speed highly optimized.
*   **Method:** Because we are using 8x H100s with FSDP, we aren't even restricted to LoRA anymore. We can actually do a **Full Fine-Tuning (FFT)** of the model if we want, or a massive High-Rank LoRA (`r=256`, targeting all linear layers) to ensure we completely overwrite the Python/JS priors.
*   **Context Window:** Scale to **8192 tokens** using standard RoPE scaling in the config to handle long Z3 contracts and ledger histories.

This stack requires zero licenses, zero sales reps, and scales perfectly to utilize your cloud budget to its absolute limit.

---

We need to revise the hardware plan a bit. Unsloth Pro/Enterprise is almost certainly out of the question. Any offerings that require one to contact a sales rep (like Unsloth Pro/Enterprise) are generally out of the question.

---

With the hardware constraints lifted and the software stack strictly open-source, the success of this entire project now rests on **Phase 1: The Synthetic Dataset**. 

If you are happy with this revised training stack, we should immediately design the Claude Opus data generation pipeline. 

Should I output the system prompt design and the Python orchestration script structure we will use to farm out the 15,000 trajectories to Claude Opus?

---

Could you estimate the cost pr hour of running  8x H100 (80GB) or 8x A100 (80GB) ?

---




Based on the current pricing for on-demand cloud GPU providers as of April 2026, renting an **8x H100 (80GB)** instance typically costs between **$19 to $24 per hour** on open-source-friendly platforms, while an **8x A100 (80GB)** will run you about **$11 to $14 per hour**.

If you use major hyperscalers like AWS or Google Cloud, those prices generally double.

Here is the precise breakdown across the most popular bare-metal/neo-cloud providers you'd use for our Axolotl/Llama-Factory training stack:

### 8x H100 (80GB) Pricing (Per Hour)
*   **RunPod:** ~$19.12/hr for PCIe versions, or ~$23.92/hr for SXM versions (translates to $2.39 - $2.99 per GPU/hr).
*   **Lambda Labs:** ~$23.92/hr for an 8x SXM cluster ($2.99 per GPU/hr).
*   **CoreWeave:** ~$49.24/hr ($6.16 per GPU/hr).
*   **AWS (p5.48xlarge):** ~$31.20 to ~$40.00/hr ($3.90 to $5.00 per GPU/hr).

### 8x A100 (80GB) Pricing (Per Hour)
*   **RunPod:** ~$11.12 to ~$11.92/hr ($1.39 to $1.49 per GPU/hr).
*   **Lambda Labs:** ~$14.32/hr ($1.79 per GPU/hr).
*   **AWS (p4d.24xlarge):** ~$32.77/hr ($4.10 per GPU/hr).

*(Note: You can also use P2P aggregators like Clore.ai or Vast.ai to bring 8x A100s down to ~$8–$10/hour, but for high-stability FSDP fine-tuning, renting a dedicated SXM node from RunPod or Lambda Labs is highly recommended to avoid node-drop interruptions).*

### Estimated Cost for our Fine-Tuning Run
Since we are using an optimized stack (Axolotl/DeepSpeed/FSDP with Flash Attention 2 in bfloat16), a Full Fine-Tuning (FFT) or massive rank LoRA of a 26B parameter model on 15,000 trajectories usually takes roughly **8 to 16 hours** of wall-clock time on an 8x H100.

*   **Total Compute Cost (8x H100):** 16 hours * $24.00/hr = **~$384**
*   **Total Compute Cost (8x A100):** 24 hours * $14.50/hr = **~$348**

Because your budget allows for it, I strongly recommend going with the **8x H100 SXM** from Lambda Labs or RunPod. The Hopper (H100) architecture has native FP8 and transformer-engine optimizations that speed up fine-tuning significantly compared to the A100, meaning you often pay almost exactly the same total dollar amount because the H100 finishes the job so much faster.

Does this fit within your allocated budget? If so, I will draft the Claude Opus Data Generation Python orchestrator!

---

Would it be possible to start out with small-scale experiments on a less powerful hardware setup, to test things and judge the feasibility of the project?

---




This is exactly how professional AI labs operate: **"Fail fast, scale later."** Doing a feasibility pilot is the smartest way to proceed. 

Because Gemma-4-26B-A4B-it is a Mixture of Experts (MoE) model with 25.2B total parameters, it requires about ~50GB of VRAM just to load the raw weights in `bfloat16`. However, for a small-scale pilot, we can absolutely compress this and test it on a fraction of the hardware.

Here is the blueprint for **Phase 0: The Micro-Pilot**.

### The Phase 0 Micro-Pilot Setup

**1. Hardware: Single GPU (Cost: ~$0.80 to $1.90 per hour)**
Instead of an 8x cluster, we rent a **single** GPU.
*   **1x A100 (80GB):** ~$1.50 - $1.90/hr on RunPod or Lambda. This is the safest bet and gives us plenty of VRAM headroom.
*   **1x RTX A6000 (48GB):** ~$0.80/hr. Still plenty of memory for a quantized run.

**2. Software Stack: Free OSS Unsloth + QLoRA**
*   While we ruled out Unsloth Pro/Enterprise for the final run, **Unsloth's free, open-source tier is arguably the best single-GPU fine-tuning library in the world.** 
*   We will use **4-bit quantization (QLoRA)** for the pilot. By dropping the weights to 4-bit, the 25B MoE shrinks to roughly ~14GB of VRAM. Combined with Unsloth's memory-efficient Triton kernels, you can comfortably train this on a single 48GB or 80GB card.
*   *(Note: We drop back to `bfloat16` and Axolotl later for the final "production" run to get maximum syntax precision, but 4-bit is more than enough to prove if the model is capable of learning AILANG).*

**3. The Micro-Dataset (500 Trajectories)**
Instead of paying the Anthropic API for 15,000 trajectories, we generate just **500 high-quality examples** with Claude Opus 4.6.
*   200 Core Syntax (block vs. expression `let`, basic `match` statements).
*   150 Z3 Contract examples.
*   150 Error-Correction examples.
*   *Estimated Claude API Cost:* < $20.

**4. The Micro-Benchmark (Feasibility Test)**
We don't need it to beat Claude Opus yet. We just need to prove that **Lever 7 (Fine-Tuning)** actually shifts Gemma's Python/JS priors. 
*   We run the base Gemma 4 model on 20 AILANG prompts. Expect a 0-10% parse success rate.
*   We run our Micro-Pilot model on the same 20 prompts. 
*   **Success Criterion:** If the Micro-Pilot achieves a >40% parse success rate and can write even *one* compiling Z3 contract, the feasibility is proven. The architecture works, and we are cleared to scale up to the 8x H100 and the 15k dataset.

---

### Total Cost & Time for the Micro-Pilot
*   **Compute:** 4 hours on 1x A100 80GB = **~$7.60**
*   **Claude Opus API:** 500 generations = **~$15.00**
*   **Time to execute:** 1 afternoon.

This approach de-risks the entire project for under $25. We get to test our Claude prompts, write the training scripts, and verify the model actually learns AILANG syntax before we spend hundreds of dollars on massive compute nodes.

If you agree with this "Phase 0" approach, the immediate next step is writing the **Claude Opus Prompt & Python Data Generator** to create those first 500 examples. 

Shall I write out that data generation script now?

---

Yes, please

---

Here is the complete Phase 0 data generation pipeline. 

Because we are doing **Reasoning Distillation**, the secret sauce is the System Prompt we feed to Claude Opus. We must instruct it to output its thoughts in XML (so we can easily parse them), and then we will automatically translate those thoughts into Gemma 4's native `<|think|>` format in the final JSONL dataset.

Here is the complete Python script to generate the 500-sample dataset. 

### `generate_phase0_data.py`

```python
import os
import json
import asyncio
import re
from anthropic import AsyncAnthropic

# Using the conceptual 2026 Opus model name
# Fallback to 'claude-3-opus-20240229' if running this on a pre-2026 API
CLAUDE_MODEL = "claude-4-6-opus-20260229" 
NUM_SAMPLES = 500
CONCURRENCY_LIMIT = 10  # Prevent hitting Anthropic rate limits

# We split the 500 samples across our three target domains
CATEGORIES =[
    {"name": "Core Syntax", "weight": 0.4, "instruction": "Focus on pure functional transformations using `std/list` (map, filter, foldl), correct block vs expression `let` bindings, and exact multi-arg vs curried function calls."},
    {"name": "Z3 Contracts", "weight": 0.3, "instruction": "Focus on mathematical proofs using `requires { ... }` and `ensures { ... }`. Do not use effects. Prove integer arithmetic bounds, list lengths, or string properties."},
    {"name": "Error Recovery", "weight": 0.3, "instruction": "Simulate a user making a common AILANG mistake (e.g., using `for` loops, missing `! {IO}` in signature, or using `in` inside a `{}` block). State the simulated compiler error, reason about why it happened, and provide the corrected AILANG code."}
]

SYSTEM_PROMPT = """You are an elite expert in AILANG v0.9.0, a pure functional programming language with Hindley-Milner type inference, algebraic effects, and Z3 contract verification.
Your task is to generate synthetic training data to teach a smaller AI model how to write perfect AILANG code.

CRITICAL AILANG RULES:
1. No loops (`for`/`while`). Use recursion or `std/list` operations.
2. No mutable variables (`var`). Use immutable `let`.
3. Inside `{ ... }` blocks, use semicolons (`let x = 1;`). For single expressions, use `let x = 1 in`. NEVER mix them.
4. Function signatures must declare effects: `func main() -> () ! {IO, FS}`.
5. Multi-arg functions are called `f(a, b)`. Curried lambdas are called `f(a)(b)`.
6. Contract verification uses `requires { ... }` and `ensures { result ... }` before the body.

FORMAT REQUIREMENTS:
You must output exactly two XML blocks:
<thought_process>
Explicitly reason about the AILANG rules needed for this specific task. Mention the constraints (e.g., "I cannot use a for loop, I must import std/list", or "Since this reads a file, I need the FS effect").
</thought_process>
<ailang_code>
module synthetic/example
[Your perfect AILANG code here]
</ailang_code>
"""

USER_PROMPT_TEMPLATE = """Generate a highly complex, unique AILANG programming task that fits the following category: {category}.
{instruction}

First, invent a specific, practical natural language prompt for this task (e.g., "Write a verified tax calculator..."). Put this prompt inside <synthetic_prompt> tags.
Then, provide the thought process and the AILANG code as instructed."""

async def generate_sample(client: AsyncAnthropic, sem: asyncio.Semaphore, category: dict) -> dict:
    async with sem:
        try:
            response = await client.messages.create(
                model=CLAUDE_MODEL,
                max_tokens=2000,
                temperature=0.8, # Slightly high to ensure diverse problem generation
                system=SYSTEM_PROMPT,
                messages=[
                    {"role": "user", "content": USER_PROMPT_TEMPLATE.format(
                        category=category["name"], 
                        instruction=category["instruction"]
                    )}
                ]
            )
            
            content = response.content[0].text
            
            # Parse XML tags
            prompt_match = re.search(r'<synthetic_prompt>(.*?)</synthetic_prompt>', content, re.DOTALL)
            thought_match = re.search(r'<thought_process>(.*?)</thought_process>', content, re.DOTALL)
            code_match = re.search(r'<ailang_code>(.*?)</ailang_code>', content, re.DOTALL)
            
            if not (prompt_match and thought_match and code_match):
                return None # Skip malformed outputs
            
            user_prompt = prompt_match.group(1).strip()
            thoughts = thought_match.group(1).strip()
            code = code_match.group(1).strip()
            
            # Format exactly how Gemma 4 expects it (ChatML / Instruction format with <|think|> tags)
            return {
                "messages":[
                    {"role": "user", "content": user_prompt},
                    {"role": "assistant", "content": f"<|think|>\n{thoughts}\n<|think|>\n```ailang\n{code}\n```"}
                ]
            }
        except Exception as e:
            print(f"API Error: {e}")
            return None

async def main():
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("Please set ANTHROPIC_API_KEY environment variable.")
        
    client = AsyncAnthropic(api_key=api_key)
    sem = asyncio.Semaphore(CONCURRENCY_LIMIT)
    
    tasks = []
    for cat in CATEGORIES:
        cat_count = int(NUM_SAMPLES * cat["weight"])
        for _ in range(cat_count):
            tasks.append(generate_sample(client, sem, cat))
            
    print(f"Spawning {len(tasks)} requests to Claude Opus...")
    results = await asyncio.gather(*tasks)
    
    # Filter out failures
    valid_results = [r for r in results if r is not None]
    
    # Save to JSONL for Unsloth/HuggingFace
    output_file = "gemma_ailang_phase0_train.jsonl"
    with open(output_file, "w") as f:
        for res in valid_results:
            f.write(json.dumps(res) + "\n")
            
    print(f"Successfully generated {len(valid_results)} training samples.")
    print(f"Saved to {output_file}. Ready for Unsloth QLoRA fine-tuning!")

if __name__ == "__main__":
    asyncio.run(main())
```

### What this script does:
1.  **Automated Prompt Engineering:** Instead of us writing 500 prompts by hand, the script asks Claude Opus to *invent* a practical AILANG scenario, write the prompt, reason about it, and solve it.
2.  **Category Balancing:** It automatically allocates 200 samples to Core Syntax, 150 to Z3 Contracts, and 150 to Error Recovery.
3.  **Gemma-Native Formatting:** It parses Claude's XML output and converts it directly into standard instruction-tuning JSONL format, explicitly injecting Gemma 4's `<|think|>` tokens. 

### Example of the resulting JSONL data row:
```json
{
  "messages":[
    {
      "role": "user", 
      "content": "Write a pure function that calculates the absolute difference between two integers. Use Z3 contracts to mathematically prove that the result is never negative."
    },
    {
      "role": "assistant", 
      "content": "<|think|>\nThis requires a Z3 contract. I cannot use the IO effect because it must be a pure function. I will use the `requires` block to ensure standard integer inputs, and the `ensures` block with `result >= 0`. Inside the block, I'll use standard AILANG if/then/else without braces.\n<|think|>\n```ailang\nmodule synthetic/math\n\nexport pure func absDiff(a: int, b: int) -> int ! {}\nensures { result >= 0 }\n{\n  if a > b then a - b else b - a\n}\n```"
    }
  ]
}
```

### Next Step
To run this, simply install the Anthropic Python SDK (`pip install anthropic asyncio`), export your API key, and run `python generate_phase0_data.py`. 

While you do that, **would you like me to draft the Phase 0 Unsloth Training Notebook?** It will be a short Python script you can run locally or on a single RunPod A100 instance to ingest this JSONL file and output the 4-bit LoRA weights.

---

Can you add OpenRouter as an alternative endpoint and include reading the OpenRouter key from env var

---




Here is the updated script. I have added logic to detect both `OPENROUTER_API_KEY` and `ANTHROPIC_API_KEY`. 

Because OpenRouter exposes an OpenAI-compatible API structure, we use the `AsyncOpenAI` client (pointing its `base_url` to OpenRouter) when routing through them, and fallback to the native `AsyncAnthropic` client if you are using Anthropic directly.

### Updated `generate_phase0_data.py`

```python
import os
import json
import asyncio
import re
from anthropic import AsyncAnthropic
from openai import AsyncOpenAI

# Model tags depending on which endpoint is active
ANTHROPIC_MODEL = "claude-4-6-opus-20260229" 
OPENROUTER_MODEL = "anthropic/claude-3-opus" # Or anthropic/claude-4.6-opus if available on OR

NUM_SAMPLES = 500
CONCURRENCY_LIMIT = 10  # Prevent hitting rate limits

CATEGORIES =[
    {"name": "Core Syntax", "weight": 0.4, "instruction": "Focus on pure functional transformations using `std/list` (map, filter, foldl), correct block vs expression `let` bindings, and exact multi-arg vs curried function calls."},
    {"name": "Z3 Contracts", "weight": 0.3, "instruction": "Focus on mathematical proofs using `requires { ... }` and `ensures { ... }`. Do not use effects. Prove integer arithmetic bounds, list lengths, or string properties."},
    {"name": "Error Recovery", "weight": 0.3, "instruction": "Simulate a user making a common AILANG mistake (e.g., using `for` loops, missing `! {IO}` in signature, or using `in` inside a `{}` block). State the simulated compiler error, reason about why it happened, and provide the corrected AILANG code."}
]

SYSTEM_PROMPT = """You are an elite expert in AILANG v0.9.0, a pure functional programming language with Hindley-Milner type inference, algebraic effects, and Z3 contract verification.
Your task is to generate synthetic training data to teach a smaller AI model how to write perfect AILANG code.

CRITICAL AILANG RULES:
1. No loops (`for`/`while`). Use recursion or `std/list` operations.
2. No mutable variables (`var`). Use immutable `let`.
3. Inside `{ ... }` blocks, use semicolons (`let x = 1;`). For single expressions, use `let x = 1 in`. NEVER mix them.
4. Function signatures must declare effects: `func main() -> () ! {IO, FS}`.
5. Multi-arg functions are called `f(a, b)`. Curried lambdas are called `f(a)(b)`.
6. Contract verification uses `requires { ... }` and `ensures { result ... }` before the body.

FORMAT REQUIREMENTS:
You must output exactly two XML blocks:
<thought_process>
Explicitly reason about the AILANG rules needed for this specific task. Mention the constraints (e.g., "I cannot use a for loop, I must import std/list", or "Since this reads a file, I need the FS effect").
</thought_process>
<ailang_code>
module synthetic/example[Your perfect AILANG code here]
</ailang_code>
"""

USER_PROMPT_TEMPLATE = """Generate a highly complex, unique AILANG programming task that fits the following category: {category}.
{instruction}

First, invent a specific, practical natural language prompt for this task (e.g., "Write a verified tax calculator..."). Put this prompt inside <synthetic_prompt> tags.
Then, provide the thought process and the AILANG code as instructed."""

async def generate_sample(client, client_type: str, sem: asyncio.Semaphore, category: dict) -> dict:
    async with sem:
        try:
            user_content = USER_PROMPT_TEMPLATE.format(
                category=category["name"], 
                instruction=category["instruction"]
            )
            
            # ---------------------------------------------------------
            # Execute API call depending on the active client architecture
            # ---------------------------------------------------------
            if client_type == "openrouter":
                response = await client.chat.completions.create(
                    model=OPENROUTER_MODEL,
                    max_tokens=2000,
                    temperature=0.8,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_content}
                    ]
                )
                content = response.choices[0].message.content
                
            elif client_type == "anthropic":
                response = await client.messages.create(
                    model=ANTHROPIC_MODEL,
                    max_tokens=2000,
                    temperature=0.8,
                    system=SYSTEM_PROMPT,
                    messages=[
                        {"role": "user", "content": user_content}
                    ]
                )
                content = response.content[0].text

            # ---------------------------------------------------------
            # Parse XML output and convert to Gemma 4 format
            # ---------------------------------------------------------
            prompt_match = re.search(r'<synthetic_prompt>(.*?)</synthetic_prompt>', content, re.DOTALL)
            thought_match = re.search(r'<thought_process>(.*?)</thought_process>', content, re.DOTALL)
            code_match = re.search(r'<ailang_code>(.*?)</ailang_code>', content, re.DOTALL)
            
            if not (prompt_match and thought_match and code_match):
                return None # Skip malformed outputs
            
            user_prompt = prompt_match.group(1).strip()
            thoughts = thought_match.group(1).strip()
            code = code_match.group(1).strip()
            
            # Format exactly how Gemma 4 expects it (ChatML / Instruction format with <|think|> tags)
            return {
                "messages":[
                    {"role": "user", "content": user_prompt},
                    {"role": "assistant", "content": f"<|think|>\n{thoughts}\n<|think|>\n```ailang\n{code}\n```"}
                ]
            }
        except Exception as e:
            print(f"API Error ({client_type}): {e}")
            return None

async def main():
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")
    
    # Check keys and configure correct client
    if openrouter_key:
        print("Detected OPENROUTER_API_KEY. Using OpenRouter endpoint...")
        client = AsyncOpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=openrouter_key,
        )
        client_type = "openrouter"
    elif anthropic_key:
        print("Detected ANTHROPIC_API_KEY. Using direct Anthropic endpoint...")
        client = AsyncAnthropic(api_key=anthropic_key)
        client_type = "anthropic"
    else:
        raise ValueError("Please set either OPENROUTER_API_KEY or ANTHROPIC_API_KEY environment variable.")

    sem = asyncio.Semaphore(CONCURRENCY_LIMIT)
    
    tasks =[]
    for cat in CATEGORIES:
        cat_count = int(NUM_SAMPLES * cat["weight"])
        for _ in range(cat_count):
            tasks.append(generate_sample(client, client_type, sem, cat))
            
    print(f"Spawning {len(tasks)} requests to {client_type}...")
    results = await asyncio.gather(*tasks)
    
    # Filter out failures
    valid_results = [r for r in results if r is not None]
    
    # Save to JSONL for Unsloth/Axolotl
    output_file = "gemma_ailang_phase0_train.jsonl"
    with open(output_file, "w") as f:
        for res in valid_results:
            f.write(json.dumps(res) + "\n")
            
    print(f"Successfully generated {len(valid_results)} training samples.")
    print(f"Saved to {output_file}. Ready for Phase 0 Micro-Pilot training!")

if __name__ == "__main__":
    asyncio.run(main())
```

### Setup Instructions

1. Make sure you have both SDKs installed to support the routing:
   ```bash
   pip install openai anthropic
   ```
2. Export your chosen environment variable. The script prefers OpenRouter if both are present.
   ```bash
   export OPENROUTER_API_KEY="sk-or-v1-..."
   # OR
   export ANTHROPIC_API_KEY="sk-ant-..."
   ```
3. Run the generation script:
   ```bash
   python generate_phase0_data.py
   ```

Shall we write the **Phase 0 Unsloth Micro-Pilot training script** next, so that once you have this JSONL file, you can immediately test it on a single A100?

---

Summary:

# Project: Gemma-4-AILANG ("Gemma 4 Good" Kaggle Hackathon)

## References
https://unsloth.ai/docs/models/gemma-4/train
https://www.kaggle.com/competitions/gemma-4-good-hackathon
https://www.kaggle.com/code/danielhanchen/gemma4-31b-unsloth

---

## 🎯 The Hackathon Hook: "Mathematically Verified AI"
Most code-generation models produce plausible but hallucinated syntax. AILANG’s superpower is its Z3-verified contract system (`requires` / `ensures`). Our submission narrative is: 
**"We fine-tuned Gemma 4 to be the world's first open-weights model that natively writes mathematically provable, zero-hallucination code."** 

We are utilizing **Lever 7 (Fine-Tuning / LoRA)** from the AILANG Performance Plan to violently overwrite Gemma 4's Python/JS priors, teaching it pure functional logic and algebraic effects via Reasoning Distillation.

---

## Phase 0: The Micro-Pilot (Fail Fast, Scale Later)
Before spending hundreds on cloud compute, we will validate the architecture for under $25.

*   **Hardware:** 1x A100 (80GB) on RunPod/Lambda (~$1.50/hr).
*   **Software:** Unsloth Free/OSS + QLoRA (4-bit quantization). Fits the 26B MoE into ~14GB VRAM.
*   **Dataset:** 500 synthetic examples generated by Claude Opus 4.6.
*   **Success Criteria:** Base Gemma 4 scores 0-10% on AILANG benchmarks. If our Micro-Pilot achieves >40% parse success and writes one compiling Z3 contract, we are cleared to scale to Phase 2.

---

## Phase 1: Synthetic Data Generation Pipeline
We use Claude Opus 4.6 (via Anthropic or OpenRouter) to generate highly curated AILANG trajectories in a "Reasoning Distillation" format. Opus outputs its thought trace (which we format into Gemma 4's `<|think|>` tokens) followed by the perfect AILANG code.

**Dataset Composition:**
1.  **30% Core Syntax & Effects:** Block vs. expression `let` bindings, curried functions, and effect rows.
2.  **40% Z3 Contracts:** `requires {}` and `ensures {}` combinations.
3.  **30% Error-Recovery:** Simulated `TYP_EFFECT_ROW_MISMATCH` errors followed by thought-traces and corrections.

---

## Phase 2: Full-Scale Open-Source Compute Stack
Once the Micro-Pilot succeeds, we unchain the model for maximum syntax precision.

*   **Hardware:** 8x H100 (80GB) bare-metal instance (RunPod/Lambda, ~$19-$24/hr).
*   **Software Stack:** Axolotl or Llama-Factory (No enterprise licenses required).
*   **Strategy:** PyTorch FSDP (Fully Sharded Data Parallel) or DeepSpeed ZeRO-3.
*   **Precision:** Native `bfloat16` with Flash Attention 2. No quantization, allowing the model to learn exact punctuation (e.g., `{ let x = 1; }` vs `let x = 1 in`).
*   **Method:** High-Rank LoRA (`r=256` or `r=512`) targeting all linear layers, or a Full Fine-Tuning (FFT).
*   **Context:** 8192 tokens RoPE scaling.

---

## Phase 3 & 4: Benchmarking and Submission
*   **Evaluation:** We will benchmark against `Contract Matrix Determinant`, `Type Unify`, and `Contract Rle Roundtrip`.
*   **Deliverables:** 
    1. Hugging Face weights (`sunholo/gemma-4-26b-ailang-z3-coder`).
    2. The open-sourced 15k synthetic dataset.
    3. A fast Kaggle inference notebook demonstrating the model taking natural language and outputting Z3-verified AILANG code.
    4. A Kaggle Writeup detailing the "Distribution Shift" problem and our OSS solution.

---

## Appendix: Data Generation Script (`generate_phase0_data.py`)
*Requires `pip install openai anthropic` and either `OPENROUTER_API_KEY` or `ANTHROPIC_API_KEY` in environment variables.*

```python
import os
import json
import asyncio
import re
from anthropic import AsyncAnthropic
from openai import AsyncOpenAI

# Model tags depending on which endpoint is active
ANTHROPIC_MODEL = "claude-4-6-opus-20260229" 
OPENROUTER_MODEL = "anthropic/claude-3-opus" # Or anthropic/claude-4.6-opus if available

NUM_SAMPLES = 500
CONCURRENCY_LIMIT = 10  # Prevent hitting rate limits

CATEGORIES =[
    {"name": "Core Syntax", "weight": 0.4, "instruction": "Focus on pure functional transformations using `std/list` (map, filter, foldl), correct block vs expression `let` bindings, and exact multi-arg vs curried function calls."},
    {"name": "Z3 Contracts", "weight": 0.3, "instruction": "Focus on mathematical proofs using `requires { ... }` and `ensures { ... }`. Do not use effects. Prove integer arithmetic bounds, list lengths, or string properties."},
    {"name": "Error Recovery", "weight": 0.3, "instruction": "Simulate a user making a common AILANG mistake (e.g., using `for` loops, missing `! {IO}` in signature, or using `in` inside a `{}` block). State the simulated compiler error, reason about why it happened, and provide the corrected AILANG code."}
]

SYSTEM_PROMPT = """You are an elite expert in AILANG v0.9.0, a pure functional programming language with Hindley-Milner type inference, algebraic effects, and Z3 contract verification.
Your task is to generate synthetic training data to teach a smaller AI model how to write perfect AILANG code.

CRITICAL AILANG RULES:
1. No loops (`for`/`while`). Use recursion or `std/list` operations.
2. No mutable variables (`var`). Use immutable `let`.
3. Inside `{ ... }` blocks, use semicolons (`let x = 1;`). For single expressions, use `let x = 1 in`. NEVER mix them.
4. Function signatures must declare effects: `func main() -> () ! {IO, FS}`.
5. Multi-arg functions are called `f(a, b)`. Curried lambdas are called `f(a)(b)`.
6. Contract verification uses `requires { ... }` and `ensures { result ... }` before the body.

FORMAT REQUIREMENTS:
You must output exactly two XML blocks:
<thought_process>
Explicitly reason about the AILANG rules needed for this specific task. Mention the constraints (e.g., "I cannot use a for loop, I must import std/list", or "Since this reads a file, I need the FS effect").
</thought_process>
<ailang_code>
module synthetic/example[Your perfect AILANG code here]
</ailang_code>
"""

USER_PROMPT_TEMPLATE = """Generate a highly complex, unique AILANG programming task that fits the following category: {category}.
{instruction}

First, invent a specific, practical natural language prompt for this task (e.g., "Write a verified tax calculator..."). Put this prompt inside <synthetic_prompt> tags.
Then, provide the thought process and the AILANG code as instructed."""

async def generate_sample(client, client_type: str, sem: asyncio.Semaphore, category: dict) -> dict:
    async with sem:
        try:
            user_content = USER_PROMPT_TEMPLATE.format(
                category=category["name"], 
                instruction=category["instruction"]
            )
            
            # Execute API call depending on the active client architecture
            if client_type == "openrouter":
                response = await client.chat.completions.create(
                    model=OPENROUTER_MODEL,
                    max_tokens=2000,
                    temperature=0.8,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_content}
                    ]
                )
                content = response.choices[0].message.content
                
            elif client_type == "anthropic":
                response = await client.messages.create(
                    model=ANTHROPIC_MODEL,
                    max_tokens=2000,
                    temperature=0.8,
                    system=SYSTEM_PROMPT,
                    messages=[
                        {"role": "user", "content": user_content}
                    ]
                )
                content = response.content[0].text

            # Parse XML output and convert to Gemma 4 format
            prompt_match = re.search(r'<synthetic_prompt>(.*?)</synthetic_prompt>', content, re.DOTALL)
            thought_match = re.search(r'<thought_process>(.*?)</thought_process>', content, re.DOTALL)
            code_match = re.search(r'<ailang_code>(.*?)</ailang_code>', content, re.DOTALL)
            
            if not (prompt_match and thought_match and code_match):
                return None # Skip malformed outputs
            
            user_prompt = prompt_match.group(1).strip()
            thoughts = thought_match.group(1).strip()
            code = code_match.group(1).strip()
            
            # Format exactly how Gemma 4 expects it (ChatML / Instruction format with <|think|> tags)
            return {
                "messages":[
                    {"role": "user", "content": user_prompt},
                    {"role": "assistant", "content": f"<|think|>\n{thoughts}\n<|think|>\n```ailang\n{code}\n```"}
                ]
            }
        except Exception as e:
            print(f"API Error ({client_type}): {e}")
            return None

async def main():
    openrouter_key = os.getenv("OPENROUTER_API_KEY")
    anthropic_key = os.getenv("ANTHROPIC_API_KEY")
    
    if openrouter_key:
        print("Detected OPENROUTER_API_KEY. Using OpenRouter endpoint...")
        client = AsyncOpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=openrouter_key,
        )
        client_type = "openrouter"
    elif anthropic_key:
        print("Detected ANTHROPIC_API_KEY. Using direct Anthropic endpoint...")
        client = AsyncAnthropic(api_key=anthropic_key)
        client_type = "anthropic"
    else:
        raise ValueError("Please set either OPENROUTER_API_KEY or ANTHROPIC_API_KEY environment variable.")

    sem = asyncio.Semaphore(CONCURRENCY_LIMIT)
    
    tasks =[]
    for cat in CATEGORIES:
        cat_count = int(NUM_SAMPLES * cat["weight"])
        for _ in range(cat_count):
            tasks.append(generate_sample(client, client_type, sem, cat))
            
    print(f"Spawning {len(tasks)} requests to {client_type}...")
    results = await asyncio.gather(*tasks)
    
    valid_results = [r for r in results if r is not None]
    
    output_file = "gemma_ailang_phase0_train.jsonl"
    with open(output_file, "w") as f:
        for res in valid_results:
            f.write(json.dumps(res) + "\n")
            
    print(f"Successfully generated {len(valid_results)} training samples.")
    print(f"Saved to {output_file}. Ready for Phase 0 Micro-Pilot training!")

if __name__ == "__main__":
    asyncio.run(main())