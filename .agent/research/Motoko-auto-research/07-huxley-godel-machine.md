# Huxley-Gödel Machine: Non-Greedy Selection for the Autoresearch Loop

## Source

https://arxiv.org/pdf/2510.21614 — "Huxley-Gödel Machine: Human-Level Coding Agent
Development by an Approximation of the Optimal Self-Improving Machine." Wenyi Wang,
Piotr Piękos, Li Nanbo, Firas Laakom, Yimeng Chen, Mateusz Ostaszewski, Mingchen
Zhuge, Jürgen Schmidhuber (Oct 2025).

Code: https://github.com/metauto-ai/HGM — **forked from `jennyzzt/dgm`** (the Darwin
Gödel Machine, see [05-darwin-godel-machine.md](./05-darwin-godel-machine.md)). HGM
swaps DGM's parent-selection rule, reusing DGM's self-modification (patch-generation)
machinery in `coding_agent.py`.

## Why This Belongs in the Research

DGM ([05](./05-darwin-godel-machine.md)) is the closest prior art to the autoresearch
loop, and it already challenged the greedy-hill-climbing default. **HGM is the direct,
code-released successor that quantifies *why* greedy is wrong and offers a concrete,
Polyglot-validated replacement.** It is the strongest external evidence to date that
the loop's current keep/discard rule selects on a weak signal — and it lands on the
*same benchmark* Motoko's Phase 0.5a uses, where the binding constraint has been
**R-noise** (see `.agent/plans/Motoko-auto-research/autoresearch-loop.md` §6,
`handoff-autoresearch-loop-phase0.5a-continuation-2.md`).

## What HGM Is (grounded in the code)

The central empirical claim is the **Metaproductivity–Performance Mismatch**: an
agent's *own* benchmark score is a poor predictor of how good its *descendants* (the
self-modifications branching from it) will be. Greedy selection — expand whichever
node scores best now — is therefore myopic. Reported correlation of the selection
estimate with true clade outcomes (Pearson, weighted, SWE-Verified-60): greedy **DGM
0.285** vs **HGM 0.778**.

The fix is **Clade-Metaproductivity (CMP)** plus a bandit search. Grounded against
`hgm.py` / `config.yaml`:

| Mechanism | Concrete implementation | Default |
|---|---|---|
| **CMP estimate** | Each node stores `utility_measures = [1]*resolved + [0]*unresolved` (per-task pass/fail). `get_decendant_evals()` **concatenates these over the subtree**; CMP = Beta(1 + Σ clade successes, 1 + Σ clade failures) | — |
| **Expansion / evaluation selection** | `TS_sample()`: `alphas=1+Σpasses`, `betas=1+len−Σpasses`, then `np.random.beta(...)` + argmax (**Thompson sampling**) | — |
| **Expand vs. evaluate (UCB-Air)** | `if n_task_evals**alpha >= len(nodes)-1+pending_expands:` expand, else evaluate | `alpha=0.6` |
| **Budget** | Counted in **single task-evals**; each `eval_agent()` runs **one task** | `max_task_evals=800` |
| **Async** | Two `ThreadPoolExecutor`s, lock-guarded shared archive | `max_workers=20` |
| **Annealing scheduler τ** | Cooling term `max_task_evals^β/(max−n)^β`, applied **only if enabled** | `cool_down=false` (OFF) |
| **Models / infra** | `gpt-5-mini` (self-improve/downstream/diagnose), Docker, OpenAI | — |

Three sub-policies are **decoupled** (DGM/SICA conflate them by always
expand→create-child→evaluate-immediately): (i) a *selection* policy choosing
expand-vs-evaluate, (ii) an *expansion* policy choosing which node to branch, (iii)
an *evaluation* policy choosing which existing node to test. Clade aggregation gives
"more statistically robust estimates than single-node outcomes… particularly
important when evaluations are costly and benchmarks are only partially observed" —
verbatim the autoresearch situation.

### What grounding *corrected* vs. the paper's prose

- **The annealing scheduler τ is OFF by default** (`cool_down: false`). It is an
  optional knob, **not load-bearing** in the released runs. Do not over-weight it.
- **"Best-belief" final selection** (highest ε-percentile of a regularized incomplete
  beta posterior) is described in the **paper** but **not confirmed in the released
  code** — the public final selection looks like a Beta-posterior sample/argmax, and
  `epsilon` is absent from `config.yaml`. Treat best-belief as a paper idea, not a
  grounded one.
- **The stack is heavy**: DGM-derived patch machinery + gpt-5-mini + Docker + 20
  parallel workers + OpenAI. A *full* port is a real build; the *estimator* and
  *incremental-eval* ideas are independently portable.

## The Structural Map to the Autoresearch Loop

| HGM | Autoresearch loop (today) |
|---|---|
| Tree of self-modified agents; any node expandable | **Linear** `new_segment` (one per lever family) + within-segment iterations; a discarded candidate is **dead** |
| Atomic unit = one **(node, task)** eval; budget in task-evals | `ar_run` evaluates a candidate **atomically** (`samples` × whole TRAIN set); budget in *candidates* |
| Decision pools 0/1 outcomes **across the clade** (Beta posterior) | `ar_log` keep/discard on **that candidate's** median+MAD improvement test |
| Thompson-sampled node selection + UCB-Air expand/eval | Fixed `patience`/`max_iterations` stall rule |
| Selection final via posterior (best-belief, paper) | Median+MAD threshold in `metrics.ail` |

The loop *is* the greedy baseline HGM critiques, narrowed to candidate artifacts. A
discarded candidate that didn't beat its parent may still be the best *ancestor* in a
tree — the loop can never discover that today.

## The Sharpest Lesson: per-task Bernoulli outcomes + incremental clade-pooled eval

The single most relevant idea for the **R-noise wall** (at `samples=2` over 6 Polyglot
exercises, per-candidate variance ≈ candidate effect size, so keep/discard does **not**
transfer to held-out TEST — DoD #3 is still open) is the **unit of evaluation**:

- **Today:** spend a fixed `samples` on every candidate, decide on its own median+MAD.
- **HGM:** add **one (node, task) eval at a time**, **pool the 0/1 outcomes across the
  clade**, and let a Thompson policy spend the next eval where it most reduces decision
  uncertainty (UCB-Air picks expand-vs-evaluate).

On Polyglot this maps **verbatim** — each exercise is already a Bernoulli trial. The
minimal adoption:

1. **`db.ail`** — store **per-exercise 0/1** outcomes (not just an aggregate
   `pass_rate`), and add a **`parent_run`** edge so runs form a tree (the enabling
   prerequisite; turns the linear chain into HGM's archive).
2. **eval unit** — make `ar_run`'s atomic step one `(candidate, exercise)` rather than
   the whole TRAIN set × `samples`.
3. **selection** — a Beta-Thompson policy over **clade-pooled** (success, failure)
   counts to choose the next candidate to extend/expand, replacing the median+MAD-only
   keep/discard for this Bernoulli path.

This is a principled, published attack on the exact constraint that has held Phase
0.5a open — borrowing statistical strength from descendants instead of paying a flat
`samples` tax per candidate.

## Why HGM Assumes Binary Trials (the Beta-Bernoulli model)

The binary assumption is not incidental — it is the **generative model** the whole
estimator is built on, and it falls out of what HGM's benchmarks *are*. SWE-bench and
Polyglot are intrinsically **per-task pass/fail**, so HGM models an agent's quality as a
single scalar **p = "probability it solves a random task,"** with each task eval a
**Bernoulli(p)** draw. Conjugacy then forces the rest:

- **CMP** = `n_success / (n_success + n_failure)` — a ratio of *counts* (needs discrete
  successes/failures).
- **Selection** = Thompson sampling on **Beta(1+successes, 1+failures)** — Beta is *the*
  conjugate prior for Bernoulli (the canonical Beta-Bernoulli bandit); the posterior is
  a belief over `p`.
- **Clade pooling** = concatenate the `[1,0,1,…]` lists across descendants — coherent
  because every task, from any clade member, is another draw informing the same `p`.

Three properties make this the engine of HGM's **noise win**, and all three need binary
tasks drawn from a *task population*:

1. **The sufficient statistic is two integers** `(successes, failures)`. You can add
   *one task at a time, from any node*, and the running tally is *always* a valid Beta
   posterior — this is what makes the incremental, decoupled, "budget-in-task-evals"
   design work.
2. **Posterior width auto-encodes sample count.** A node at 3/5 and one at 30/50 are
   directly comparable, the latter automatically treated as more certain — no
   hand-tuned MAD threshold.
3. **There is a population of distinct tasks to pool over.** Polyglot has ~140
   exercises; "more evals" = *seeing more of the task distribution* = genuinely more
   information about `p`. Clade pooling borrows that information across descendants.

## Where the Mapping Breaks (code-confirmed) — and the tree-vs-estimator distinction

HGM has **two separable pieces**; only one is actually blocked for continuous-metric
fixtures (simdscan / crc / intcodec). The earlier framing ("HGM doesn't fit continuous
fixtures") was too strong — be precise:

- **(A) Tree / archive + non-greedy selection** — keep every candidate, branch from any
  node, pick parents by descendant promise instead of own score. This is
  **metric-agnostic.** You *can* run it on simdscan/crc by swapping the Beta-Bernoulli
  bandit for a **Gaussian (continuous) bandit** over GB/s. DGM (which HGM forks) already
  keeps a continuous-metric archive. So the *tree structure itself is not off-limits.*
- **(B) Clade-pooled, incremental, partial Bernoulli evaluation** — the part that
  actually beats R-noise. This needs binary tasks **and** a task population, and it does
  **not** port to a single continuous throughput. Two reasons:
  - **The metric is a continuous magnitude, not a success count.** GB/s has no
    `n_success/(n_success+n_failure)` and no Beta posterior — the estimator dissolves.
    Binarizing ("beats baseline: yes/no") would discard the magnitude that *is* the
    optimization target.
  - **Different noise, nothing to pool.** Polyglot noise comes from a **population of
    distinct tasks** (one more eval = a new exercise = real new information). simdscan
    noise is **measurement jitter on one number** (re-running the same function on the
    same data only denoises the same scalar). And each candidate is a *different
    function with its own true throughput*, so "the clade's pooled GB/s" isn't a
    meaningful single parameter — there is nothing coherent to borrow strength from.

| | Polyglot | simdscan / crc |
|---|---|---|
| Noise source | population of distinct tasks | measurement jitter on one number |
| "One more eval" means | a *new exercise* → more info about `p` | re-run *same* function on *same* data → denoise one scalar |
| Clade pooling | coherent (all draws inform one `p`) | incoherent (each candidate has its own true throughput) |

- **"Metaproductivity" is agent-specific (holds regardless of A/B).** A clade only has
  *meta*productivity when descendants are themselves **agents** (the candidate *is* the
  scaffolding). That fits the Polyglot warm-up (literally self-improvement) and the ARC
  bespoke-player. A C scan function has no self-improvement potential — only a number —
  so even a Gaussian-bandit tree over simdscan would be ordinary noisy tree-search, **not**
  Huxley-Gödel metaproductivity.
- **Cost / infra.** Tree search + async 20-worker parallelism + Docker is heavier than
  the single-process AILANG loop. Adopt incrementally (per-task outcomes + clade pooling
  first; tree edge next), not as a wholesale port.

**Net:** binary is the generative model that makes CMP a Beta ratio, makes evaluation
incrementally poolable, and lets the clade borrow strength from a task population. For
simdscan/crc you could still run piece (A) — a continuous-bandit tree — but you would get
neither HGM's noise-fighting payoff (B) nor its metaproductivity meaning. So HGM's
*distinctive value* remains a **Polyglot/scaffolding-warm-up technique**, while the bare
tree structure is reusable more broadly.

## Net Implications

1. **HGM is the anchor citation for "greedy keep/discard selects on a weak signal,"**
   succeeding DGM's intuition with a *quantified* mismatch (0.285 → 0.778) on the same
   benchmark. Pair it with [05](./05-darwin-godel-machine.md) when arguing the
   archive/tree case.
2. **Highest-leverage, lowest-cost first step:** a **Polyglot-only** variant with
   per-exercise Bernoulli outcomes pooled across a clade and incremental Thompson-sampled
   evaluation. Directly targets R-noise / DoD #3.
3. **Tree structure (`parent_run` edge in `db.ail`) is the enabling prerequisite** —
   without it there is no clade to pool over.
4. **Demote annealing and best-belief** to secondary/unconfirmed; do not build on them
   first.
5. **Evaluator-boundary rule still holds** (from DGM Appendix H): per-exercise sensors
   and the TEST grader stay immutable from — ideally invisible to — the optimizer. HGM
   does not change this; clade pooling adds samples but not integrity.

## References

- [Huxley-Gödel Machine (arXiv:2510.21614)](https://arxiv.org/pdf/2510.21614)
- [metauto-ai/HGM](https://github.com/metauto-ai/HGM) — code (forked from `jennyzzt/dgm`)
- [05-darwin-godel-machine.md](./05-darwin-godel-machine.md) — DGM, the direct predecessor
- [02-recursive-self-improvement.md](./02-recursive-self-improvement.md) — three-layer analysis
- `.agent/plans/Motoko-auto-research/autoresearch-loop.md` — the loop design (R-noise §6, Polyglot §5a)
- `.agent/plans/Motoko-auto-research/handoff-autoresearch-loop-phase0.5a-continuation-2.md` — the open DoD #3 / R-noise constraint
- `.agent/plans/Motoko-auto-research/known-issues.md` — KI-1 (max_output_tokens cap)
