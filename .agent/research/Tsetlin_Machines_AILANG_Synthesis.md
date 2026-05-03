# Tsetlin Machines + AILANG: Synthesis

## Source Papers

1. **Granmo 2018** — *The Tsetlin Machine: A Game Theoretic Bandit Driven Approach to Optimal Pattern Recognition with Propositional Logic* (arXiv:1804.01508v15). Ole-Christoffer Granmo, University of Agder. The foundational paper.
2. **Gao et al. 2026** — *LLM-Guided Semantic Bootstrapping for Interpretable Text Classification with Tsetlin Machines* (arXiv:2604.12223v1). Stanford, UC Irvine, CAS. Extends TMs with LLM-derived symbolic scaffolding.

## What Tsetlin Machines Are

A TM is a pattern recognition model built on propositional logic. It uses teams of Tsetlin Automata (TAs) — finite-state machines that each control whether a literal (a feature or its negation) is included in a conjunctive clause. Clauses are AND-formulas over boolean inputs. Half the clauses vote for class 1 (positive polarity), half for class 0 (negative polarity). The final output is a majority vote.

### Core Components

- **Tsetlin Automaton**: A single integer state in [1, 2N]. States 1..N -> Exclude action. States N+1..2N -> Include action. Learning is increment/decrement driven by feedback.
- **Clause**: A conjunction of included literals. `C(X) = x1 AND NOT x3 AND x7`. Evaluates to 1 iff all included literals are 1 for a given input.
- **Type I Feedback** (y = omega): Reinforces true positives. Rewards Include of matching literals, penalizes Include of non-matching. Controlled by hyperparameter `s` (specificity).
- **Type II Feedback** (y != omega): Combats false positives. Penalizes Exclude of zero-valued literals when clause erroneously fires.
- **Resource Allocation**: Clauses receive feedback stochastically, with probability proportional to distance from a target margin T. Distributes clauses across sub-patterns.
- **Theoretical Guarantee**: Nash equilibria of the game align with optimal propositional formulas. Global optima only — no local optima.

### Key Hyperparameters

- `n`: number of clauses
- `s`: specificity (controls clause granularity)
- `T`: summation target (margin for resource allocation)
- `N`: number of TA states per action

### The NTM Variant (Paper 2)

The Non-Negated Tsetlin Machine modifies the standard TM:
- Eliminates negated literals — clauses are purely monotonic conjunctions
- Boosted Type I feedback: P(Reward) = 1.0, P(Penalty) = 0.0 for correct predictions
- Type II feedback unchanged (still suppresses false positives)
- Used as an intermediate module to extract high-confidence literals from LLM-guided synthetic data

### LLM-Guided Pipeline (Paper 2)

Three-stage pipeline that injects LLM semantic knowledge into TM clause logic:

1. **Sub-intent discovery**: Prompt GPT-4o to decompose class labels into fine-grained sub-intents (e.g., `positive_due_to_plot`, `immune_evasion_due_to_suppression`).
2. **Synthetic data generation** via curriculum: Seed (50 canonical samples) -> Core (50 structurally varied) -> Enriched (100 lexically expanded) per sub-intent.
3. **NTM pretraining**: Train NTM on synthetic data, extract literals with deepest TA states (confidence = max(0, phi - N) > delta) as semantic cues.
4. **Feature injection**: Append extracted literal indicators to real BoW data. Fine-tune standard TM on enriched input.

No LLM or embeddings at inference time. Fully symbolic pipeline.

### Results (Paper 2)

| Dataset | Vanilla TM | TM (GloVe) | LLM-Guided TM | BERT |
|---------|-----------|------------|----------------|------|
| AG-News | 88.34 | 90.12 | 93.10 +/- 0.96 | 94.75 |
| R8 | 96.16 | 97.50 | 97.88 +/- 0.29 | 97.49 |
| R52 | 84.62 | 89.14 | 94.45 +/- 0.33 | 94.26 |
| IMDb | 90.62 | 90.88 | 92.10 +/- 0.68 | 93.46 |
| SST-2 | 75.61 | 76.38 | 85.24 +/- 1.12 | 94.00 |
| HoC | 77.42 | 78.78 | 81.90 +/- 1.40 | 82.90 |

Narrows gap to BERT significantly. Surpasses BERT on R52. Fully symbolic and interpretable at inference.

---

## How Tsetlin Machines and AILANG Fit Together

### 1. Shared Foundation: Symbolic Computation

Both systems are fundamentally symbolic. TMs produce propositional logic formulas (conjunctions of literals). AILANG is a typed functional language whose core operations are pattern matching on algebraic data types and boolean/bitwise computation. This is not a superficial overlap — the entire TM inference path is expressible as pure AILANG without any escape hatches.

A clause is a conjunction of included literals. That is a `foldl` with `&&` over a filtered literal set. The final classification is a majority vote — a sum over clause evaluations, thresholded at zero. All of this is integer arithmetic and boolean logic, which is exactly the fragment AILANG's Z3 verification covers.

### 2. Natural ADT Encoding

The TM's conceptual vocabulary maps directly onto AILANG ADTs:

```ailang
type Action = Include | Exclude deriving (Eq)
type Feedback = Reward | Penalty | Inaction deriving (Eq)
type Polarity = Positive | Negative deriving (Eq)

type TAState = TAState({state: int, literal_idx: int})
type Clause = Clause({polarity: Polarity, automata: [TAState]})
type TsetlinMachine = TM({pos_clauses: [Clause], neg_clauses: [Clause], threshold: int, specificity: int})
```

The feedback tables (Type I and Type II) are pure functions of three inputs: clause output (bool), literal value (bool), and current action (Include/Exclude). That is a 2x2x2 table — eight cells — naturally expressed as nested pattern matching. The NTM variant from paper 2 is even simpler: it eliminates half the table by dropping negated literals entirely.

### 3. Z3 Verification — The Real Prize

The most compelling intersection is AILANG's contract verification applied to TM logic. What is provable:

**Clause evaluation correctness.** A clause must evaluate to 1 iff all included literals are 1. This is a pure function over boolean inputs — fully in Z3's decidable fragment.

**Feedback table invariants.** For any cell in the Type I/II tables, the three probabilities (Reward, Inaction, Penalty) must sum to 1.0. The probability values are functions of `s` — verifiable for all s >= 1.

**State bounds.** A TA state must always remain in [1, 2N]. After any feedback (increment or decrement), the state must be clipped:

```ailang
pure func applyFeedback(state: int, feedback: Feedback, n: int) -> int ! {}
  requires { state >= 1, state <= 2 * n, n >= 1 }
  ensures { result >= 1, result <= 2 * n }
{ ... }
```

Z3 proves this holds for all inputs — not just test cases.

**NTM monotonicity invariant.** The NTM from paper 2 guarantees no negated literals are ever included. This is a structural invariant on clause construction — expressible as a contract on the clause-building function.

**Resource allocation bounds.** The clip operation `clip(v, -T, T)` and the feedback probability `(T - clip(v, -T, T)) / (2T)` must always yield values in [0, 1]. Provable for all T > 0.

The pattern from the AILANG docs — **pure core + effectful shell** — maps perfectly here. All TM logic (evaluation, feedback lookup, state transitions, clause construction) is pure. Only training (random sampling, iteration) is effectful. This maximizes the verified surface area.

### 4. The LLM-Guided Pipeline as an AILANG Program

Paper 2's three-stage pipeline is essentially an orchestration program:

1. **Sub-intent discovery**: Prompt an LLM, parse structured output. AILANG has `callJson` with schema enforcement, JSON decode, and the AI effect.
2. **Synthetic data generation** (seed -> core -> enriched): Three sequential LLM calls per sub-intent, each feeding into the next. AILANG's effectful list combinators (`mapE`, `foldlE`) handle this — iterate over sub-intents, accumulate samples.
3. **NTM pretraining**: Train on synthetic data, extract high-confidence literals. The training loop is recursive with state threading — a `foldl` over training examples, carrying the TA state vector.
4. **Feature injection + TM fine-tuning**: Enrich real data with NTM literals, train standard TM. Same structure.

The entire pipeline could be a single AILANG program: AI effect for LLM calls, pure functions for TM logic (verified with Z3), IO for output, FS for dataset loading. The effect system forces you to declare exactly what each stage touches.

### 5. Bitwise Implementation

Granmo's paper (Section 3.4) describes a bitwise encoding where all TA states in a clause are stored as parallel bit sequences, and clause evaluation reduces to NOT + AND + comparison on bit vectors. AILANG has the exact operators needed: `&`, `^`, `~`, `<<`, `>>`. The signed 64-bit integer semantics are explicitly documented.

However, the bitwise parallelism that makes TMs fast on hardware is fundamentally an imperative optimization — operating on mutable bit arrays in-place. In AILANG, each "mutation" produces a new immutable value. For a production-speed TM implementation, this matters. For a reference implementation that is correct-by-construction and verifiable, it does not.

### 6. Where Tension Exists

**Training loop.** TM training is inherently iterative and stateful — you mutate TA states in-place across thousands of epochs. AILANG models this as a recursive function threading state, which Z3 cannot verify (recursive functions are skipped). The training loop itself is not provable — only the pure operations it calls on each step.

**Scale.** Granmo discusses millions of Tsetlin Automata. AILANG's immutable data structures mean each state update copies the relevant structure. For MNIST-scale problems (784 input bits x 2 literals x hundreds of clauses x 2 polarities = hundreds of thousands of TAs), a naive functional implementation will be slow. The `std/array` with O(1) access helps for reads, but updates are O(n) copies.

**Randomness.** TM learning requires stochastic feedback (probabilistic reward/penalty). AILANG has no built-in random number generation in its stdlib — you would need to pipe it through the Process or IO effect, or implement a PRNG as a pure function (LCG or xorshift, threading the seed state — actually a natural fit for functional style, and the PRNG itself is verifiable).

**Float probabilities vs. integer comparison.** The feedback tables use probabilities like (s-1)/s. In practice, you compare a random float against a threshold. AILANG's Z3 verification skips float parameters, so you would want to reformulate in integer arithmetic (e.g., compare `rand_int < (s-1)` for a random integer in [0, s)) to keep things verifiable.

### 7. The Meta-Level: TMs as a Learning Backend for AILANG

A more speculative direction: TMs could serve as AILANG's native learning primitive. Where neural networks are opaque, TMs produce propositional logic — the same symbolic language AILANG already speaks. Consider:

- An AILANG program that trains a TM, extracts its clauses, and emits those clauses as AILANG pattern-match expressions. The learned model becomes auditable source code.
- TM clauses over AILANG's own AST features — learning patterns about code structure, type errors, or effect violations, with the learned rules readable as propositional formulas.
- The AI effect currently calls external LLMs. A TM trained on domain data could serve as a local, interpretable, zero-latency alternative for classification tasks — no API key, no network, deterministic.

### 8. Synergy Map

| TM Property | AILANG Feature | Synergy |
|---|---|---|
| Propositional clauses | ADTs + pattern matching | Direct encoding, no impedance mismatch |
| Boolean/bitwise core | `&`, `^`, `~`, `<<`, `>>` operators | Hardware-level operations available |
| Feedback tables (pure lookup) | Pattern matching + contracts | Z3-provable correctness of learning rules |
| State bounds [1, 2N] | `requires`/`ensures` contracts | Formally verified TA state transitions |
| Interpretable output | Symbolic language | Learned clauses become readable code |
| NTM monotonicity | ADT invariants + contracts | Structural guarantee: no negated literals |
| LLM-guided pipeline | AI effect + JSON + effects | Full pipeline in one language, effects tracked |
| Resource allocation | Pure integer arithmetic | Verifiable probability/clipping logic |

---

## Assessment

The fit is strongest for a **reference implementation** that prioritizes correctness and interpretability over raw speed — which is exactly the positioning both TMs and AILANG claim. A TM implemented in AILANG, with contracts on its core logic verified by Z3, would be the first formally verified Tsetlin Machine implementation. The LLM-guided pipeline from paper 2 could orchestrate the full workflow end-to-end, with the AI effect handling LLM calls and the pure core handling all TM logic under proof.

The fit is weakest for production-scale training performance, where mutable in-place updates on large bit arrays matter. But the reference implementation could serve as the specification against which an optimized implementation is validated.

The most novel contribution would be: **a TM whose core logic is mathematically proven correct by Z3, whose LLM-guided semantic bootstrapping runs through AILANG's AI effect, and whose learned clauses are emitted as readable AILANG pattern-match code.** This closes the loop between learning and verification in a way neither system achieves alone.
