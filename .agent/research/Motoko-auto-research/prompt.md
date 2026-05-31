# Title: Recursive Self-Improvement in AI Agent Systems — Safety, Feedback Loops, and Trainable Extension Architectures

### Context

Motoko is an experimental AI coding agent harness built on AILANG (a pure functional language with algebraic effects, Hindley-Milner type inference, and Z3 contract verification). Its extension system exposes seven hooks — pure functions that control tool policy, context compaction, budget allocation, and response handling. These hooks are the agent's "trainable parameters": they are loaded from AILANG source files at startup, and the agent has full tool access to read, edit, verify (`make check_core`), and reload them.

A proposal (https://github.com/arniwesth/motoko_agent/discussions/24) describes closing the loop: Motoko runs tasks → analyzes its own performance (success rate, token cost, step count) → edits its own hooks → verifies the changes compile → runs the same tasks again → compares before/after metrics. The hooks are analogous to neural network weights, but readable and editable as code — no gradient descent needed, just behavioral analysis and targeted rewrites.

The seven hooks in `src/core/ext/types.ail`:
- `on_tool_policy` — Allow/Deny/Defer individual tool calls (highest self-improvement amenability)
- `on_pre_step` — Compaction: trim context before each LLM call
- `on_budget_plan` — How many steps to allocate per task
- `on_tool_handle` — Intercept and directly handle tool calls
- `on_solver_candidate` — Accept/reject/feedback on final answer
- `on_build_system_prompt` — What the agent tells itself at startup
- `on_response_intercept` — Intercept model output mid-stream

The dispatch is wired in `src/core/agent_loop_v2.ail` (~68KB). Extensions are loaded from `.packages/` via `registry_generated.ail`. The AILANG type-checker acts as a "gradient guard" — broken edits are rejected before runtime.

The analogy drawn is to Eric Jang's AutoGo (https://github.com/ericjang/autogo), which automates the Go researcher rather than playing Go directly. But where AutoGo trains opaque neural network weights via self-play, Motoko's "weights" are readable AILANG functions — making the feedback loop faster and more interpretable.

Key unsolved problems from the proposal:
1. **Safe self-modification** — No rollback mechanism; a broken `on_tool_policy` that denies all tools (including the repair tools) strands the agent.
2. **Metric design** — Multi-dimensional improvement (cost vs success vs latency) requires a scalar composite score.
3. **State continuity** — Hook changes require restart; session state is lost.
4. **Bootstrapping** — Starting from no-op hooks and discovering the first useful policy rule.
5. **Blast radius containment** — Whether self-modification should be scoped to a single dedicated extension.

### Research Targets

- **AutoGo (Eric Jang):** https://github.com/ericjang/autogo — Self-play reinforcement learning for Go, but the real subject is automating the ML researcher. Demonstrates the "automate the researcher, not the task" paradigm. Key reference for the Layer-2 loop concept.
- **OpenAI's Alignment Research — Recursive Reward Modeling:** https://arxiv.org/abs/1811.07871 — Scalable agent oversight via recursive decomposition of evaluations. Directly relevant to the "who evaluates the self-improvement" question.
- **AIDE (Weco AI):** https://github.com/WecoAI/aideml — Autonomous ML engineering agent that iterates on experiments. Uses tree-search over solution space and automated evaluation. Close architectural cousin to the proposed Layer-2 loop.
- **DSPy (Stanford NLP):** https://github.com/stanfordnlp/dspy — Programmatic optimization of LLM prompts and pipelines via teleprompters/compilers. The closest existing system to "optimizing agent behavior through measured performance" without gradient descent on weights.
- **OpenHands (formerly OpenDevin):** https://github.com/All-Hands-AI/OpenHands — Agent framework with a sandboxed execution environment and configurable action space. Relevant for understanding how other agent systems handle tool policy and safety boundaries.
- **"Code as Agent Harness" Survey (Ning et al. 2026):** https://github.com/YennNing/Awesome-Code-as-Agent-Harness-Papers — Curated paper list accompanying the survey "Code as Agent Harness: Toward Executable, Verifiable, and Stateful Agent Systems" (arXiv:2605.18747). Organizes 200+ papers across three layers: Harness Interface (code for reasoning, acting, environment modeling), Harness Mechanisms (planning, memory/context engineering, tool usage, feedback-guided debugging), and Scaling the Harness (multi-agent coordination, shared-harness synchronization). Directly relevant as the taxonomic frame for understanding where Motoko's self-modifying hooks sit in the broader landscape of code-centric agent systems.
- **Motoko Agent Repository:** https://github.com/arniwesth/motoko_agent — The source codebase; extension system in `src/core/ext/`, agent loop in `src/core/agent_loop_v2.ail`, configuration in `.motoko/config/`.
- **AILANG Language:** https://github.com/sunholo-data/ailang — The implementation language; its type system and algebraic effect system are what make compile-time verification of self-modifications possible.
- **HuggingFace ML Intern:** https://github.com/huggingface/ml-intern — Open-source autonomous ML engineer agent that reads papers, trains models, and ships code. Notable for its doom-loop detection (`agent/core/doom_loop.py`), effort probing before execution, cost estimation, dynamic model switching, approval policy gates, and SFT trace tagging (`agent/sft/tagger.py`) for using session traces as fine-tuning data. Demonstrates a production-grade agent loop with built-in self-awareness of failure modes and cost — directly relevant to metric design, safety rails, and the "traces as training signal" pattern.

### Research Questions

#### 1. Recursive Self-Improvement Architectures in Practice
- What systems have demonstrated *genuine* recursive self-improvement (agent modifies its own decision-making substrate, not just its data)? What distinguishes successful from failed attempts?
- How does DSPy's teleprompter/compiler approach compare to directly editing executable policy code? What are the tradeoffs between optimizing prompts vs optimizing executable hooks?
- What role does AIDE's tree-search-over-solutions play compared to Motoko's proposed sequential edit-and-compare loop? Is branching exploration necessary, or does greedy hill-climbing suffice for a constrained hook space?
- What does the "Code as Agent Harness" survey taxonomy reveal about where self-modifying hook systems sit relative to other code-centric agent architectures? Which of the surveyed "Harness Mechanisms" (planning, memory, tool usage, feedback-guided debugging) are most amenable to runtime self-modification?
- How does ML Intern's architecture (doom-loop detection, effort probing, SFT trace tagging) compare to Motoko's proposed self-improvement loop? What can be learned from its approach to cost-aware self-monitoring and using session traces as a training signal for fine-tuning?

#### 2. Safety and Rollback in Self-Modifying Agent Systems
- What formal frameworks exist for ensuring self-modifying agents cannot enter irrecoverable states (the "stranded agent" problem where the agent breaks its own repair tools)?
- What formal frameworks or practical patterns exist for preventing self-modifying agents from learning to avoid their own rollback or interrupt mechanisms?
- What is the state of the art in "recovery partitions" — minimal immutable bootstrap layers that guarantee an agent can always be reset regardless of what modifications it has made to itself?
- How do containerization, snapshotting (git stash, filesystem checkpoints), and formal type-checking compare as safety mechanisms for self-modification? Which class of failures does each catch?
- What research exists on "capability preservation constraints" — ensuring that self-modification never removes the agent's ability to perform specific critical operations (file editing, tool invocation)?
- How does ML Intern's doom-loop detection work as a runtime safety mechanism, and how could similar cycle-detection be applied to a self-modifying agent that might enter repetitive failed-edit cycles?

#### 3. Metric Design and Multi-Objective Optimization for Agent Self-Evaluation
- What composite scoring functions have been used in agent self-evaluation? How do systems handle the tension between cost reduction and capability preservation?
- How does AIDE handle its evaluation signal? What metrics does it use, and how does it decide whether an iteration was an improvement?
- What research exists on Pareto-optimal self-improvement — agents that navigate tradeoff frontiers rather than optimizing a single scalar?
- How do bandit algorithms (UCB, Thompson sampling) apply to the "which hook to modify next" exploration/exploitation tradeoff?
- What is the minimum viable evaluation suite size for statistical significance when comparing before/after performance of an agent policy change?

#### 4. Bootstrapping and Curriculum Design for Self-Improving Agents
- How do self-play systems (AlphaGo, AutoGo) bootstrap from random/no-op initial policies? What principles transfer to the case where the "policy" is readable code rather than opaque weights?
- What curriculum strategies exist for ordering the difficulty of the tasks an agent trains on? What does the "Code as Agent Harness" literature say about feedback-guided iterative debugging as a curriculum signal?
- How should the initial task suite be designed — should tasks be adversarial (designed to expose hook weaknesses), representative (drawn from production workloads), or synthetic (generated to cover specific tool-policy scenarios)?
- What research exists on "self-curriculum" — agents that not only improve their policies but also improve their training tasks to be more informative?

#### 5. Extension/Plugin Architectures as Trainable Substrates
- How do modern AI agent systems (OpenHands, Aider, SWE-agent, Devon, Cursor) architect their tool-selection and action-filtering layers? Are any designed for runtime modification?
- What is the state of "hot-loading" extensions in production agent systems — loading new or modified extension code without full restart, preserving session context?
- How does the AILANG type system's compile-time verification compare to other approaches for validating agent plugins (sandboxing, capability-based security, formal methods)?
- What research exists on the expressiveness/safety tradeoff in agent extension languages — how much power can hooks have before the risk of catastrophic self-modification becomes unmanageable?

#### 6. Comparison to Neural Self-Improvement and Meta-Learning
- How does code-level self-improvement (editing readable policy functions) compare to neural meta-learning (MAML, Reptile, learned optimizers) in terms of sample efficiency, interpretability, and convergence?
- What advantages does a discrete, type-checked search space (seven hooks with defined signatures) have over continuous parameter spaces for self-improvement? What are the disadvantages?
- Does the "no gradient descent needed" claim hold up under scrutiny? Are there scenarios where gradient-free optimization of agent hooks would benefit from gradient-like signals (e.g., automatic differentiation of cost functions through traces)?
- What research connects program synthesis (generating programs that satisfy specifications) to agent self-improvement (generating policies that maximize performance metrics)?

### Desired Output Format

- **Per-theme sections** (matching the 6 research question groups above), each containing:
  - A synthesis of current state of research and deployed systems
  - Key papers, repos, and systems with brief descriptions and relevance to Motoko's proposal
  - Concrete architectural patterns that have been shown to work (not just theorized)
  - Open problems and failure modes observed in practice
  - Specific recommendations for Motoko's first experiment design

- **A comparative architecture table** with columns: System | Self-Modification Target | Feedback Signal | Safety Mechanism | Restart Required? | Interpretability — covering at minimum: AutoGo, DSPy, AIDE, OpenHands, ML Intern, Motoko (proposed)

- **A "first experiment design" section** synthesizing the research into concrete recommendations for:
  - Which hook to target first and why (based on evidence from analogous systems)
  - Minimum viable task suite size and composition
  - Rollback/safety mechanism that is implementable in < 1 day
  - Evaluation metric that balances simplicity with informativeness
  - Stop conditions (when to halt the self-improvement loop)

- **A "failure modes" section** cataloging how recursive self-improvement has failed in practice across the surveyed systems, with specific anti-patterns to avoid

- **Full citations** with URLs where available
