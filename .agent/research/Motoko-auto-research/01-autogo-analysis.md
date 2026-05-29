# AutoGo Analysis: What It Is and Why It Matters for Motoko

## Source

https://github.com/ericjang/autogo — Eric Jang, April 2026

## What AutoGo Is

AutoGo is a **minimal AlphaGo-from-scratch codebase**, but the README is explicit:
*"This repo is not really about Go. It is about automating the Go researcher."*

It's a sandbox for studying how an AI agent (Claude, via Claude Code) can
autonomously drive an ML research project — designing experiments, running
training loops, interpreting results, catching training instability, and
iterating on model architecture.

### Architectural Pieces

| Layer | Details |
|---|---|
| **Models** | `GoTransformer` (dual policy/value heads via CLS token) and `GoResNet` family (10M–1B params). Pure PyTorch. Uses `mup` (µP) for scaling. Tensor shape suffixes everywhere. |
| **Agents** | Pluggable agent system: `Random`, `NNAgent`, `NNMCTSAgent` (C++ MCTS via pybind11 exposed as `alpha_go_cpp`) |
| **Training loop** | Self-play → collect games on GPU workers → train on (state, move, winner) tuples. Synchronous iteration recommended over async RL for stability. |
| **Infra** | Dev container dispatches one-shot `docker run --rm` jobs over SSH to GPU workers. No Kubernetes — just SSH + Docker + rsync + NFS on one node. Deliberately minimal. |
| **Experiment system** | Self-contained folders `experiments/<timestamp>/` with scripts, `report.md`, `data/*.csv`, `figures/*.png` — explicitly designed to be *"easy for an AI to interpret results"* |
| **Claude skills** | `.claude/skills/autoresearch/` (autonomous metric optimization / hyperparameter tuning) and `experiment/` (one-off analysis) |

### Design Philosophy (from CLAUDE.md)

- *"prioritize simplicity and compactness of code over generality"*
- *"Always be trying to reduce complexity of the codebase, minimize if statements / branching"*
- *"Design the code to run on single GPU"*
- *"Code like how an effortlessly smart Anthropic engineer would do it"*
- Tensor shape suffixes on all tensors (B, L, D, H, K, etc.)
- Experimental scripts and result files must be *"self-contained, reproducible, and easy for an AI such as Claude to interpret results"*
- No torch wrapper frameworks — raw PyTorch only

### Why Go? (The Meta-Argument)

The README makes six points about why Go is a good domain for studying automated
research. They all apply with equal or greater force to the agent/meta-learning
domain:

1. **Simple algorithms + scaling systems engineering** — just like frontier LLM labs
2. **Scaling law properties** — Go exhibits train-time and test-time scaling laws
3. **De-correlated signal from LLMs** — techniques that help train Go networks transfer without being confounded by LLM-specific dynamics
4. **"Little bit of everything"** — logging, data collection, replay buffers, distributed RL, evaluation — a full ML stack in miniature
5. **Function approximation replaces simulation** — philosophically rich: can you predict macro outcomes without micro simulation?
6. **Self-play, Nash equilibria, recursive self-improvement** — top-of-mind for frontier labs

### Key Infra Lessons

From the README's "Infra Advice" section — these are battle-tested:

- **Have the agent "run the training loop by hand"** — stopping to remark when an iteration goes unstable helps catch problems early.
- **Start synchronous, then go async** — alternating synchronously between train and collect before maxing throughput ensures stability before scaling.
- **SSH + Docker over orchestration frameworks** — *"I wasted a lot of time wrangling distributed job orchestration frameworks. Falling back to docker exec calls over SSH ended up working best and being agent-friendly."*

---

## How AutoGo Relates to Motoko

### 1. Motoko as the autonomous researcher

AutoGo currently uses Claude Code as the driving agent. Motoko has the same
primitives: shell execution (`BashExec`), file I/O (`ReadFile`/`WriteFile`/
`EditFile`), search (`Search`), plus `CtxExecute` for analysis snippets and
context-mode indexing for maintaining state across a long research session.

The self-play training loop (`bash run_iteration.sh`) is entirely shell-invocable.
Results are markdown + CSV + PNG — perfectly parseable by an agent that can read
files and execute analysis code.

This makes AutoGo an ideal **benchmark harness** for Motoko's agentic capability
on a real, multi-turn, stateful ML research task.

### 2. Shared meta-problem

Both projects are about the **meta-layer**:

- AutoGo's thesis: techniques that help train Go networks transfer to LLMs and robotics.
- Motoko's thesis (by analogy): techniques that help an agent drive ML experiments transfer to any domain where an agent must plan, execute, observe, and iterate.

AutoGo's lessons about what makes code "agent-friendly" (simple orchestration,
self-contained experiments, markdown reports) are directly applicable to how
Motoko should design its own tools, protocols, and extension conventions.

### 3. Recursive self-improvement sandbox

The README lists *"self-play, Nash equilibria, mixed strategies, and recursive
self-improvement"* as topics of interest. Motoko's architecture — AILANG core,
extension hooks, policy gates, tool-handle hooks, runtime as child process —
makes it a candidate for the **agent version** of this: can Motoko modify its
own runtime (or train improved extensions) through an AutoGo-like loop of
experiment → evaluate → improve?

See: [02-recursive-self-improvement.md](./02-recursive-self-improvement.md)

### 4. Infrastructure alignment

AutoGo's SSH + Docker dispatch pattern aligns with how Motoko might scale.
Motoko's tool catalog maps naturally: `BashExec` for `docker run`, `WriteFile`/
`ReadFile` for config management, Ctx tools for result analysis. The experiment
folder convention is directly compatible with context-mode indexing for session
persistence.

### Concrete Integration Ideas

- **Port AutoGo's `autoresearch` skill to a Motoko task spec**: define the hyperparameter search as a Motoko-managed loop with context-mode tracking search history and results across sessions.
- **Use AutoGo as a benchmark harness**: measure how well Motoko can sustain a multi-iteration training loop — catching divergence, adjusting hyperparameters, writing reports — without human intervention.
- **Cross-pollinate the experiment format**: AutoGo's `report.md` convention could become a standard output format for Motoko-driven experiments in any domain.
