# Title: Expand on the subjects discussed in The Motoko Manifesto — self-modifying AI agent architectures

### Context

The Motoko Manifesto is a living document describing an experimental AI coding agent harness called "Motoko." The project explores what happens when software is no longer written by humans but by the AI systems that run it. The agent plans, executes, tests, and modifies code in a continuous loop, with the human's role shifting from author to steward. The implementation language is AILANG — a pure functional language with algebraic effects, Hindley-Milner type inference, and Z3 contract verification, designed specifically for machine authorship rather than human ergonomics.

The manifesto covers ten interconnected themes that together define the architecture and philosophy of self-modifying AI agent systems. The research below should expand on each of these subjects — finding deeper academic, industrial, and open-source context for the ideas presented.

### Research Targets

- **Building Evolutionary Architectures (Neal Ford, Rebecca Parsons, Patrick Kua):** https://evolutionaryarchitecture.com/precis.html — The manifesto's first principle (evolvable architecture) draws directly from this work on fitness functions and guided incremental change.
- **Chad Fowler's Phoenix Architecture:** https://aicoding.leaflet.pub/3majnyfydzs2y — The claim that code is disposable and intent is durable; that if design traces are preserved with sufficient fidelity, code is regenerable.
- **Antithesis — Deterministic Simulation Testing:** https://antithesis.com/docs/resources/deterministic_simulation_testing/ — The manifesto adapts DST concepts to AI agent systems, recording and replaying LLM responses for reproducible debugging.
- **The Tsetlin Machine (Ole-Christoffer Granmo):** https://en.wikipedia.org/wiki/Tsetlin_machine — A game-theoretic pattern recognition system based on propositional logic, producing interpretable and formally analyzable decisions. Explored as a neurosymbolic reasoning alternative to neural networks.
- **AILANG:** https://github.com/sunholo-data/ailang — Pure functional language with algebraic effects, Hindley-Milner inference, and Z3 contract verification, designed for machine-authored code.
- **Z3 Theorem Prover (Microsoft Research):** https://github.com/Z3Prover/z3 — Used for formal contract verification of pure functions; the mechanism that constrains self-modification to be provably correct.
- **SWE-Bench:** https://github.com/swe-bench/SWE-bench — Software engineering benchmark for evaluating AI coding agents.
- **Oh-My-Pi (Pi Coding Agent by Mario Zechner):** https://mariozechner.at/posts/2025-11-30-pi-coding-agent/ — Demonstrated that a lean core with well-defined tool interfaces can be remarkably capable; inspiration for Motoko's extension architecture.

### Research Questions

#### 1. Evolvable and Phoenix Architectures for AI-Authored Code
- What are the current best practices and academic literature on evolutionary/evolvable software architectures, particularly when applied to AI-generated or AI-maintained codebases?
- How does Chad Fowler's "Phoenix Architecture" concept (code is disposable, intent is durable) relate to established ideas in literate programming, specification-driven development, and formal methods?
- What existing systems or research projects have attempted "deletion tests" — verifying that a component can be deleted and regenerated purely from stored intent/specifications?
- What is the state of the art in "design provenance" vs "craft provenance" — preserving not just what was built but the tacit knowledge of how and why?

#### 2. Formal Verification and Self-Modifying Systems
- What is the current state of research on formal verification of self-modifying programs? Are there proof systems that can verify not just outputs but the *process* of self-modification?
- How are Z3 contracts, refinement types, and dependent types being used in practice to constrain AI-generated code?
- What research exists on "contract-preserving transformations" — ensuring that code rewrites maintain declared invariants?
- What is the state of property-based testing (QuickCheck/Hypothesis-style) applied to AI-generated code verification?

#### 3. Neurosymbolic Reasoning and Interpretable AI
- What is the current state of Tsetlin Machine research? What problems have they been successfully applied to, and what are their limitations compared to neural approaches?
- How are neurosymbolic systems (combining neural networks with symbolic logic/reasoning) being applied to code generation and verification?
- What research exists on making AI agent decisions interpretable and formally analyzable, beyond just neural attention visualization?

#### 4. Deterministic Simulation, Benchmarking, and Agent Evaluation
- How is deterministic simulation testing (Antithesis-style) being adapted for AI agent systems where the primary nondeterminism is the LLM itself?
- What are the limitations of current AI coding benchmarks (SWE-Bench, Terminal-Bench, Aider Polyglot) for evaluating multi-step, self-modifying agent sessions?
- What research exists on "adversarial benchmarks" — evaluation suites that co-evolve with the system being tested?
- How do we measure trajectory quality (the decisions made along the way) rather than just final output correctness?

#### 5. Human-AI Stewardship, Conservation Layers, and Agent Self-Awareness
- What frameworks exist for human oversight of autonomous AI systems that go beyond simple kill-switches? What does "stewardship" look like in practice?
- What research exists on the "observer effect" in AI systems — how does the knowledge of being monitored change an AI agent's behavior?
- How are AI agent systems being designed for self-awareness (knowing their own context limits, budget, capabilities) and what are the tradeoffs?
- What is the state of research on "soft refusal" mechanisms — agents that can challenge instructions they believe are harmful without overriding human authority?

#### 6. AI-Native Programming Languages and Extension Architectures
- What programming languages have been designed specifically for machine authorship rather than human ergonomics? What design choices do they make?
- How do modern agent harnesses (OpenHands, Aider, Cursor, Devon, SWE-agent) handle extensibility and plugin/tool architectures?
- What is the state of "hot-loading" extensions in agent systems — allowing the agent to write, verify, and load new capabilities mid-session?

### Desired Output Format

- **Per-theme sections** (matching the 6 research question groups above), each containing:
  - A synthesis of the current state of research and practice
  - Key papers, projects, and systems with brief descriptions
  - Open problems and frontier questions
  - How the findings relate back to the Motoko Manifesto's claims
- **A comparative landscape table** showing how different AI coding agent systems (OpenHands, Aider, Devon, SWE-agent, Motoko/Oh-My-Pi) approach the core architectural questions (extensibility, verification, self-modification, human oversight)
- **A "frontier questions" section** identifying the genuinely unsolved problems at the intersection of these themes
- **Full citations** with URLs where available
